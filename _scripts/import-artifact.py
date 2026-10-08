#!/usr/bin/env python3
"""claude.ai 슬라이드 아티팩트 → <발표폴더>/slides/deck.html

    python3 _scripts/import-artifact.py <내려받은 폴더> <발표폴더>

아티팩트를 고친 뒤 이 덱을 다시 만들 때 쓴다. 덱을 통째로 새로 쓰므로
deck.html 을 손으로 고쳤다면 그 수정은 사라진다. 고칠 것은 아티팩트에서 고친다.

<내려받은 폴더> 는 Claude 가 Artifact 도구로 받아 둔 것이다 (셸에서는 못 받는다).
  project/deck.json            슬라이드 순서
  project/slides/<id>.html     한 장에 한 파일
  <blob id>.jpg|.png           이미지 (자산 목록의 id 그대로)
이 폴더는 시스템 임시 디렉터리에 둔다. Drive 폴더 안에 두지 않는다.

<발표폴더>/talk.json 의 "artifact" 가 원본 주소와 이미지 이름표다.
  "artifact": {
    "url": "https://claude.ai/artifact/…",
    "assets": { "<blob id>": "ex-alonso-portrait.jpg", … }
  }
아티팩트에 이미지를 새로 넣었으면 이 표에 한 줄을 더한다. 표에 없는 이미지가
나오면 멈춘다. 외부 출처면 ex- 를 붙인다 (CLAUDE.md §1).

하는 일
  · 각 장을 <section><div class="canvas" style="원래 section 스타일"> 로 감싼다.
    1920 캔버스 규칙은 _shared/theme/talk.css 에 있다
  · 각 장에 박힌 푸터(talk.json 의 footer 문구 + 쪽번호)를 지운다. talk-init.js 가
    다시 그린다. 그래서 footer 는 아티팩트 푸터 문구와 한 글자도 다르면 안 된다. 푸터가 없던 장은 표지(deck.json 의 cover)면 .s-cover,
    아니면 .s-closing 으로 두어 푸터를 넣지 않는다
  · 푸터 없는 장에서 행사명·"YYYY년 M월 D일"·"YYYY-MM-DD"·발표자+소속 줄을 찾아
    data-talk-event / data-talk-date / data-talk-byline 으로 바꾼다
  · <x-connector>(아티팩트 전용 화살표)를 같은 자리의 인라인 SVG 로 바꾼다.
    route straight·hv·vh·elbow, head none·end·start·both 를 그린다
  · display:flex 인 <p> 의 내용을 <span style="display:block"> 하나로 감싼다.
    브라우저에서는 flex 상자 안의 글과 <span> 이 따로따로 가로로 늘어서고 <br> 이
    먹지 않는다. 아티팩트는 그 내용을 한 덩어리 글로 그린다
  · <aside>(발표자 노트)를 Reveal 노트(<aside class="notes">)로 바꾼다
  · /_blob/<id> 를 ../assets/<이름> 으로 바꾸고 이미지를 assets/ 에 복사한다.
    600KB 가 넘으면 긴 변 1800px 로 줄인다 (sips). PNG 사진을 .jpg 이름으로 적으면
    JPEG 로 바꾼다
"""
import json
import os
import re
import shutil
import subprocess
import sys

if len(sys.argv) != 3:
    sys.exit(__doc__)
SRC, TALK = (os.path.abspath(p) for p in sys.argv[1:])

talk = json.load(open(f'{TALK}/talk.json', encoding='utf-8'))
ASSETS = talk.get('artifact', {}).get('assets', {})
deck = json.load(open(f'{SRC}/project/deck.json', encoding='utf-8'))
order = deck['order']

os.makedirs(f'{TALK}/slides', exist_ok=True)
os.makedirs(f'{TALK}/assets', exist_ok=True)

# ── 슬라이드 ───────────────────────────────────────────────────
# 푸터 모양은 아티팩트마다 다르다. 문구로 찾는다.
#   <div …><p …>문구</p><p …>12</p></div>      (차용규모)
#   <div …>문구<span …>12</span></div>          (연구위키)
if not talk.get('footer'):
    sys.exit('talk.json 에 footer 가 없습니다 — 아티팩트 푸터 문구를 그대로 적으십시오')
FT = re.escape(talk['footer'])
FOOTER = re.compile(
    r'<div[^>]*>\s*(?:<p[^>]*>)?\s*' + FT + r'\s*(?:</p>)?\s*<(span|p)\b[^>]*>\d+</\1>\s*</div>\s*')

# ── x-connector → SVG ─────────────────────────────────────────
def connector(m):
    tag = m.group(0)
    a = dict(re.findall(r'([a-z][a-z0-9-]*)="([^"]*)"', tag))
    try:
        x1, y1, x2, y2 = (float(a[k].replace('px', '')) for k in ('x1', 'y1', 'x2', 'y2'))
    except (KeyError, ValueError):
        sys.exit(f'x-connector 좌표를 읽지 못했습니다 (px 만 지원): {tag}')
    st = a.get('style', '')
    color = (re.search(r'(?<![-\w])color:\s*([^;]+)', st) or [None, '#000'])[1].strip()
    w = float((re.search(r'border-width:\s*([0-9.]+)', st) or [None, '2'])[1])
    dash = (re.search(r'border-style:\s*(dashed|dotted)', st) or [None, None])[1]
    route = a.get('route', 'straight')
    if route == 'hv':
        pts = [(x1, y1), (x2, y1), (x2, y2)]
    elif route == 'vh':
        pts = [(x1, y1), (x1, y2), (x2, y2)]
    elif route == 'elbow':
        mx = (x1 + x2) / 2
        pts = [(x1, y1), (mx, y1), (mx, y2), (x2, y2)]
    else:
        pts = [(x1, y1), (x2, y2)]
    head = a.get('head', 'end')
    ends = {'start': head in ('start', 'both'), 'end': head in ('end', 'both')}
    if 'head-start' in a: ends['start'] = a['head-start'] != 'none'
    if 'head-end' in a: ends['end'] = a['head-end'] != 'none'
    L, H = 4 * w + 6, 2 * w + 3          # 머리 길이·반폭 — 선 굵기에 비례, 크기 일정
    heads = []
    def cut(tip, prev):                  # 끝 선분을 머리 밑동까지 줄이고 머리를 그린다
        dx, dy = tip[0] - prev[0], tip[1] - prev[1]
        n = (dx * dx + dy * dy) ** .5 or 1
        ux, uy = dx / n, dy / n
        bx, by = tip[0] - ux * L, tip[1] - uy * L
        heads.append(f'<polygon points="{tip[0]:g},{tip[1]:g} {bx - uy * H:g},{by + ux * H:g} {bx + uy * H:g},{by - ux * H:g}" fill="{color}"/>')
        return (bx, by)
    if ends['end']:   pts[-1] = cut(pts[-1], pts[-2])
    if ends['start']: pts[0] = cut(pts[0], pts[1])
    d = ' '.join(f'{x:g},{y:g}' for x, y in pts)
    da = {'dashed': f' stroke-dasharray="{3 * w:g} {2 * w:g}"', 'dotted': f' stroke-dasharray="{w:g} {w:g}"'}.get(dash, '')
    return ('<svg aria-hidden="true" style="position:absolute; left:0; top:0; width:1px; height:1px; overflow:visible">'
            f'<polyline points="{d}" fill="none" stroke="{color}" stroke-width="{w:g}"{da}/>' + ''.join(heads) + '</svg>')

used, out = set(), []
for sid in order:
    html = open(f'{SRC}/project/slides/{sid}.html', encoding='utf-8').read().strip()
    m = re.match(r'<section\b([^>]*)>(.*)</section>\s*$', html, re.S)
    if not m:
        sys.exit(f'{sid}: <section> 하나로 된 파일이 아닙니다')
    attrs, inner = m.group(1), m.group(2)
    style = re.search(r'style="([^"]*)"', attrs).group(1)

    inner, n = FOOTER.subn('', inner)
    if n > 1:
        sys.exit(f'{sid}: 푸터로 보이는 줄이 {n}개입니다')

    def asset(mm):
        bid = mm.group(1)
        if bid not in ASSETS:
            sys.exit(f'{sid}: talk.json 의 artifact.assets 에 없는 이미지 {bid}')
        used.add(bid)
        return '../assets/' + ASSETS[bid]
    inner = re.sub(r'/_blob/([0-9a-f]{32})', asset, inner)
    inner = re.sub(r'<x-connector\b[^>]*>(?:</x-connector>)?', connector, inner)
    inner = inner.replace('<aside>', '<aside class="notes">')
    inner = re.sub(r'(<p\b[^>]*display:\s*flex[^>]*>)(.*?)(</p>)',
                   r'\1<span style="display:block">\2</span>\3', inner, flags=re.S)
    left = re.findall(r'<x-[a-z]+', inner)
    if left:
        sys.exit(f'{sid}: 아직 옮기지 못하는 아티팩트 전용 태그 {sorted(set(left))}')

    cls = ''
    if n == 0:
        cls = ' class="s-cover"' if sid == deck.get('cover') else ' class="s-closing"'
        # 행사명·날짜·발표자는 talk.json 에서 들어온다 (CLAUDE.md)
        if talk.get('event'):
            inner = re.sub(r'(<p [^>]*)>' + re.escape(talk['event']) + '</p>',
                           r'\1 data-talk-event>&nbsp;</p>', inner)
        inner = re.sub(r'(<p [^>]*)>(?:<br>)?(?:\d{4}년 \d{1,2}월 \d{1,2}일|\d{4}-\d{2}-\d{2})</p>',
                       r'\1 data-talk-date>&nbsp;</p>', inner)
        if talk.get('authors') and talk.get('affiliation'):
            inner = re.sub(r'(<p [^>]*)>' + re.escape(talk['authors'][0]) + r'</p>\s*<p [^>]*>'
                           + re.escape(talk['affiliation']) + '</p>',
                           r'\1 data-talk-byline>&nbsp;</p>', inner)

    inner = '\n'.join('    ' + ln if ln.strip() else '' for ln in inner.strip('\n').splitlines())
    out.append(f'  <section id="{sid}"{cls}>\n  <div class="canvas" style="{style}">\n{inner}\n  </div>\n  </section>')

# ── 이미지 ─────────────────────────────────────────────────────
for bid in sorted(used):
    name = ASSETS[bid]
    ext = os.path.splitext(name)[1]
    src = next((f'{SRC}/{bid}{e}' for e in ('.jpg', '.png', '.jpeg', '.webp', '.gif')
                if os.path.exists(f'{SRC}/{bid}{e}')), None)
    if not src:
        sys.exit(f'이미지 파일이 없습니다: {SRC}/{bid}.*  (Artifact 도구로 받아 두십시오)')
    dst = f'{TALK}/assets/{name}'
    if ext == '.jpg' and not src.endswith(('.jpg', '.jpeg')):
        subprocess.run(['sips', '-s', 'format', 'jpeg', src, '--out', dst], check=True, capture_output=True)
    else:
        shutil.copyfile(src, dst)
    if os.path.getsize(dst) > 600_000:
        subprocess.run(['sips', '-Z', '1800', dst], check=True, capture_output=True)
        if ext == '.jpg':
            subprocess.run(['sips', '-s', 'formatOptions', '82', dst], check=True, capture_output=True)

unused = sorted(set(ASSETS) - used)
if unused:
    print('표에는 있으나 슬라이드에서 안 쓰는 이미지:', ', '.join(ASSETS[b] for b in unused))

# ── 덱 ────────────────────────────────────────────────────────
title = talk.get('title') or deck.get('title', '')
page = f'''<!doctype html>
<!--
  {title}
  이 파일은 _scripts/import-artifact.py 가 만든다. 손으로 고치지 않는다.
  원본: {talk.get('artifact', {}).get('url', 'claude.ai 슬라이드 아티팩트')}

  아티팩트(1920×1080, 인라인 스타일)를 모양 그대로 옮긴 덱이라 design.md 의
  960×540 유형 클래스를 쓰지 않는다. 각 장을 .canvas 하나에 담고, talk.css 의
  "1920 캔버스" 층이 강의 테마의 제목·문단 규칙을 걷어낸다.
  행사명·날짜·발표자·푸터는 ../talk.json 에서 들어온다.
-->
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title}</title>

  <link rel="stylesheet" href="../../_shared/vendor/reveal/reset.css">
  <link rel="stylesheet" href="../../_shared/vendor/reveal/reveal.css">
  <link rel="stylesheet" href="../../_shared/theme/tokens.css">
  <link rel="stylesheet" href="../../_shared/theme/cbnu.css">
  <link rel="stylesheet" href="../../_shared/theme/components.css">
  <link rel="stylesheet" href="../../_shared/theme/print.css">
  <link rel="stylesheet" href="../../_shared/theme/talk.css">
</head>
<body>
<div class="reveal canvas-1920" data-width="1920" data-height="1080"><div class="slides">

{chr(10).join(out)}

</div></div>

<script src="../../_shared/vendor/reveal/reveal.js"></script>
<script src="../../_shared/vendor/reveal/plugin/notes.js"></script>
<script src="../../_shared/vendor/reveal/plugin/math.js"></script>
<script src="../../_shared/js/talk-init.js"></script>
</body>
</html>
'''
open(f'{TALK}/slides/deck.html', 'w', encoding='utf-8').write(page)
print(f'{len(order)}장 → {TALK}/slides/deck.html')
