#!/usr/bin/env bash
# 배포용 정적 사이트 생성 → dist/
#
#   _scripts/build-site.sh              전체 발표 (Access 로 잠긴 사이트용)
#   PUBLIC_ONLY=1 _scripts/build-site.sh  talk.json 의 public: true 인 발표만
#
# 화이트리스트 방식이다. 여기 명시된 것만 복사한다.
# source/ 와 private/ (초록·원고·미공표 데이터)는 절대 담기지 않는다 — CLAUDE.md 참조.
#
# dist/ 는 Drive 동기화 대상 밖(시스템 임시 디렉터리)에 만든다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLIC_ONLY="${PUBLIC_ONLY:-0}"
if [ "$PUBLIC_ONLY" = "1" ]; then
  OUT="${OUT:-${TMPDIR:-/tmp}}/talk-site-public"
else
  OUT="${OUT:-${TMPDIR:-/tmp}}/talk-site"
fi

cd "$ROOT"
rm -rf "$OUT"
mkdir -p "$OUT"

# ── 공용 자산 ────────────────────────────────────────────────
mkdir -p "$OUT/_shared"
cp -R _shared/theme _shared/js _shared/fonts _shared/img _shared/vendor "$OUT/_shared/"

# ── 루트 허브 ────────────────────────────────────────────────
[ -f index.html ] && cp index.html "$OUT/"

# ── 발표 폴더: slides/ pdf/ assets/ index.html talk.json 만 ──
# 폴더 이름(한글)으로 glob하지 않는다. macOS는 파일명을 NFD로 저장하는데
# 스크립트 안의 한글 리터럴은 NFC라서 패턴이 영영 안 맞는다.
# 대신 talk.json이 있는 디렉터리를 발표 폴더로 본다.
TALKS=0
# bash 3.2(macOS 기본)에서는 set -u 아래 빈 배열의 ${#arr[@]} 가 죽는다. 문자열로 모은다.
SKIPPED=""
while IFS= read -r meta; do
  name="$(basename "$(dirname "$meta")")"
  case "$name" in _*) continue;; esac

  # 공개 번들이면 public: true 만 담는다. 판단은 사람이 talk.json 에 적어 둔 것을 따른다.
  if [ "$PUBLIC_ONLY" = "1" ]; then
    is_public="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("public") is True)' "$meta" 2>/dev/null || echo False)"
    if [ "$is_public" != "True" ]; then
      SKIPPED="${SKIPPED}  - ${name}
"
      continue
    fi
  fi

  mkdir -p "$OUT/$name"
  for sub in slides pdf assets; do
    [ -d "$name/$sub" ] && cp -R "$name/$sub" "$OUT/$name/"
  done
  [ -f "$name/index.html" ] && cp "$name/index.html" "$OUT/$name/"
  cp "$meta" "$OUT/$name/"
  TALKS=$((TALKS + 1))
done < <(find . -mindepth 2 -maxdepth 2 -name talk.json -not -path './_*')

if [ "$TALKS" -eq 0 ]; then
  echo "경고: 담을 발표를 찾지 못했습니다." >&2
fi

# 무엇이 빠졌는지 반드시 찍는다. 조용히 빠지면 "다 올라갔다"고 착각한다.
if [ -n "$SKIPPED" ]; then
  echo "공개 번들에서 제외 (public: true 아님):"
  printf '%s' "$SKIPPED"
  echo
fi

# ── GitHub Pages 대비 ────────────────────────────────────────
# Jekyll 은 밑줄로 시작하는 최상위 폴더를 무시한다. _shared/ 가 통째로 빠지면
# 모든 슬라이드의 CSS·폰트·JS 가 404 가 된다. 빈 .nojekyll 하나로 막는다.
touch "$OUT/.nojekyll"

# ── Cloudflare Workers 대비 ──────────────────────────────────
# 깃 연동 배포는 저장소 폴더를 통째로 자산으로 올린다. 파일 하나당 25MiB 제한이
# 있는데 .git/objects 의 팩 파일이 이를 넘어 배포가 실패한다 (200_education 에서 겪음).
# .assetsignore 는 업로드되지 않으며 여기 적힌 것을 자산에서 뺀다.
printf '.git\n.git/**\nwrangler.jsonc\n' > "$OUT/.assetsignore"

# Workers 배포는 wrangler 가 무엇을 올릴지 알려 주는 설정 파일을 찾는다.
# 이 파일이 없으면 "Missing entry-point to Worker script or to assets directory" 로 죽는다.
cat > "$OUT/wrangler.jsonc" <<'JSON'
{
  "name": "presentations",
  "compatibility_date": "2026-09-05",
  "assets": { "directory": "./" }
}
JSON

# ── 안전 점검 ────────────────────────────────────────────────
# 발표 맥락의 원고·문서 확장자를 강의노트 목록에 더했다.
LEAK="$(find "$OUT" \( -name '*.hwp' -o -name '*.hwpx' -o -name '*.xlsx' \
        -o -name '*.pptx' -o -name '*.docx' -o -name '*.key' \) -print)"
if [ -n "$LEAK" ]; then
  echo "중단: 비공개 파일이 배포 대상에 섞였습니다." >&2
  echo "$LEAK" >&2
  exit 1
fi

# source/ · private/ 가 통째로 끼어들지 않았는지도 본다 (화이트리스트가 뚫린 경우)
STRAY="$(find "$OUT" \( -path '*/source/*' -o -path '*/private/*' \) -print)"
if [ -n "$STRAY" ]; then
  echo "중단: source/ 또는 private/ 가 배포 대상에 섞였습니다." >&2
  echo "$STRAY" >&2
  exit 1
fi

echo "생성 완료: $OUT  (발표 ${TALKS}건)"
find "$OUT" -maxdepth 2 -mindepth 1 -not -path '*/_shared/*' | sed "s|$OUT|  dist|"
echo
echo "미리보기:  (cd '$OUT' && python3 -m http.server 8181)"
