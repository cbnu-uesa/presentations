#!/usr/bin/env bash
# 링크 검사 — 발표 목록이 가리키는 슬라이드·PDF 가 실제로 열리는지 본다
#
#   _scripts/check-links.sh                                   로컬 (임시 서버를 띄운다)
#
# **배포 전에 로컬로 돌린다.** 배포본은 Cloudflare Access 가 로그인 없는 요청을
# 403 으로 막아 그냥은 못 본다. 그래도 배포본을 확인해야 하면 Zero Trust 에서
# 서비스 토큰을 만들어 환경변수로 넘긴다.
#
#   CF_ACCESS_CLIENT_ID=... CF_ACCESS_CLIENT_SECRET=... \
#     _scripts/check-links.sh https://presentations.kks1104.workers.dev
#
# 토큰을 쓰려면 Access 정책에 그 토큰을 Include 로 넣어 두어야 한다.
#
# 왜 필요한가. 강의노트에서 course.json 의 file 결손 하나가 목록 렌더링 루프를
# TypeError 로 죽여 과목 목록이 통째로 비었다. 슬라이드는 멀쩡했고 직접 주소로는
# 열렸기 때문에 배포 후에야 드러났다. 그 종류의 결함을 기계로 잡는다.
#
# check-figures.sh 가 슬라이드 '안'을 본다면 이 스크립트는 슬라이드 '사이'를 본다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-8197}"
cd "$ROOT"

if [ "$#" -gt 0 ]; then
  BASE="${1%/}"
else
  python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1 &
  SERVER_PID=$!
  trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
  for _ in $(seq 1 40); do
    curl -sf -o /dev/null "http://127.0.0.1:${PORT}/" && break || sleep 0.25
  done
  BASE="http://127.0.0.1:${PORT}"
fi

BASE="$BASE" python3 - "$ROOT" <<'PYEOF'
import json, os, re, sys, unicodedata, urllib.error, urllib.parse, urllib.request

BASE = os.environ['BASE'].rstrip('/')
ROOT = sys.argv[1]
LOCAL = BASE.startswith('http://127.0.0.1')

# Cloudflare Access 서비스 토큰. 없으면 헤더를 붙이지 않는다 (로컬은 필요 없다).
CF = {}
if os.environ.get('CF_ACCESS_CLIENT_ID') and os.environ.get('CF_ACCESS_CLIENT_SECRET'):
    CF = {'CF-Access-Client-Id': os.environ['CF_ACCESS_CLIENT_ID'],
          'CF-Access-Client-Secret': os.environ['CF_ACCESS_CLIENT_SECRET']}

def request(path, method='GET'):
    url = f"{BASE}/{urllib.parse.quote(path)}"
    return urllib.request.urlopen(
        urllib.request.Request(url, headers=CF, method=method), timeout=30)

def fetch(path):
    try:
        with request(path) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, b''
    except Exception as e:
        return str(e), b''

def head(path):
    try:
        return request(path, 'HEAD').status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception as e:
        return str(e)

norm = lambda s: unicodedata.normalize('NFC', s)
errors, warns = [], []

# ── 루트 허브의 TALKS 배열 ──────────────────────────────────
status, body = fetch('index.html')
if status == 403 and not LOCAL:
    print("중단: Cloudflare Access 가 막았습니다 (403).", file=sys.stderr)
    print("      배포본은 로그인해야 열립니다. 링크 검사는 배포 전에 인자 없이 돌리세요:",
          file=sys.stderr)
    print("        _scripts/check-links.sh", file=sys.stderr)
    if not CF:
        print("      배포본을 꼭 봐야 하면 Zero Trust 서비스 토큰을", file=sys.stderr)
        print("      CF_ACCESS_CLIENT_ID · CF_ACCESS_CLIENT_SECRET 로 넘기세요 (스크립트 앞머리 참조).",
              file=sys.stderr)
    else:
        print("      토큰을 넘겼는데도 막혔습니다. Access 정책 Include 에 그 토큰이 있는지 확인하세요.",
              file=sys.stderr)
    sys.exit(2)
if status != 200:
    print(f"중단: 루트 index.html 을 열 수 없습니다 ({status})", file=sys.stderr)
    sys.exit(2)
m = re.search(r'const TALKS\s*=\s*\[(.*?)\]', body.decode('utf-8'), re.S)
if not m:
    print("중단: 루트 index.html 에서 TALKS 배열을 찾지 못했습니다", file=sys.stderr)
    sys.exit(2)
listed = re.findall(r"'([^']+)'", m.group(1))

# 폴더는 있는데 배열에 없으면 사이트에 아예 안 뜬다 (수동 등록 지점은 여기뿐)
# _templates/ 같은 밑줄 폴더는 발표가 아니다 (build-site.sh 와 같은 규칙)
on_disk = sorted(d for d in os.listdir(ROOT)
                 if not d.startswith('_')
                 and os.path.isfile(os.path.join(ROOT, d, 'talk.json')))
listed_n = [norm(x) for x in listed]
for d in on_disk:
    if norm(d) not in listed_n:
        warns.append(f"{d} — talk.json 이 있으나 루트 index.html 의 TALKS 에 없다")

total = 0
for talk in listed:
    status, body = fetch(f'{talk}/talk.json')
    if status != 200:
        errors.append(f"{talk}/talk.json → {status}")
        continue
    try:
        t = json.loads(body.decode('utf-8'))
    except json.JSONDecodeError as e:
        errors.append(f"{talk}/talk.json — JSON 문법 오류: {e}")
        continue

    name = t.get('title', talk)

    # 공개 판단이 빠진 발표는 사고의 씨앗이다. 없으면 반드시 알린다.
    if 'public' not in t:
        warns.append(f"{name} — talk.json 에 public 이 없다 (기본은 비공개로 본다)")

    done = 0
    seen = set()
    for d in t.get('decks', []):
        label = d.get('label') or f"덱 {d.get('no', '?')}"
        if d.get('status') != 'done':
            continue
        done += 1
        total += 1
        f = d.get('file')
        if not f:
            # 바로 이 결함이 강의노트에서 목록을 통째로 비웠다
            errors.append(f"{name} · {label} — talk.json 에 file 이 없다")
            continue
        seen.add(f)
        s = head(f'{talk}/slides/{f}')
        if s != 200:
            errors.append(f"{name} · {label} 슬라이드 → {s}  ({f})")
        pdf = f[:-5] + '.pdf' if f.endswith('.html') else f
        p = head(f'{talk}/pdf/{pdf}')
        if p != 200:
            warns.append(f"{name} · {label} PDF 없음 "
                         f"({'build-pdf.sh 를 돌리면 된다' if LOCAL else '배포본에 빠졌다'})")

    # talk.json 이 모르는 슬라이드 — 만들어 놓고 등록을 잊은 것
    sdir = os.path.join(ROOT, talk, 'slides')
    if os.path.isdir(sdir):
        seen_n = [norm(x) for x in seen]
        for f in sorted(os.listdir(sdir)):
            if f.endswith('.html') and norm(f) not in seen_n:
                warns.append(f"{name} — slides/{f} 가 talk.json 에 없다")

    print(f"  {name}: 덱 {done}건")

print()
for w in warns:
    print(f"  ! {w}")
for e in errors:
    print(f"  ✗ {e}")
print()
if errors:
    print(f"총 {total}덱 · 오류 {len(errors)}건 · 경고 {len(warns)}건")
    sys.exit(1)
print(f"총 {total}덱 · 문제 없음" + (f" (경고 {len(warns)}건)" if warns else ""))
PYEOF
