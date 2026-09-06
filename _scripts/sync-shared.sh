#!/usr/bin/env bash
# 강의노트(200_education)의 공용 자산을 여기로 끌어온다.
#
#   _scripts/sync-shared.sh          무엇이 달라지는지만 보여준다
#   _scripts/sync-shared.sh --apply  실제로 덮어쓴다
#
# 두 프로젝트는 같은 디자인 시스템을 쓰지만 별개의 Drive 폴더다. 심볼릭 링크는
# Drive 동기화에서 깨지므로 복사로 나눠 갖고, 갱신은 이 스크립트로 한 방향으로만 한다.
#
#   200_education/_shared  ──▶  800_presentation/_shared     (이 방향만)
#
# 발표 전용 두 파일은 건드리지 않는다:
#   _shared/theme/talk.css      강의 테마 넷 뒤에 얹는 발표 층
#   _shared/js/talk-init.js     talk.json 을 읽는 초기화 스크립트
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${SRC:-$(dirname "$ROOT")/200_education}"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

if [ ! -d "$SRC/_shared" ]; then
  echo "원본을 찾지 못했습니다: $SRC/_shared" >&2
  echo "다른 곳에 있으면 SRC 로 넘기세요:  SRC=/경로/200_education $0" >&2
  exit 2
fi

# 가져올 것만 적는다. 화이트리스트다.
ITEMS=(
  "theme/tokens.css"
  "theme/cbnu.css"
  "theme/components.css"
  "theme/print.css"
  "js/charts.js"
  "fonts"
  "img"
  "vendor"
)

CHANGED=0
for item in "${ITEMS[@]}"; do
  a="$SRC/_shared/$item"
  b="$ROOT/_shared/$item"
  [ -e "$a" ] || { echo "  ? 원본 없음: $item"; continue; }

  if diff -rq "$a" "$b" >/dev/null 2>&1; then
    continue
  fi
  CHANGED=1
  echo "── $item"
  if [ -f "$a" ]; then
    diff -u "$b" "$a" | sed -n '1,40p' || true
  else
    diff -rq "$b" "$a" 2>&1 | sed 's/^/   /' || true
  fi

  if [ "$APPLY" = "1" ]; then
    mkdir -p "$(dirname "$b")"
    cp -R "$a" "$b"
    echo "   → 덮어썼다"
  fi
done

if [ "$CHANGED" = "0" ]; then
  echo "같다. 가져올 것이 없다."
elif [ "$APPLY" != "1" ]; then
  echo
  echo "적용하려면:  $0 --apply"
  echo "덮어쓴 뒤에는 슬라이드를 열어 색·치수가 뒤집히지 않았는지 눈으로 확인한다."
fi
