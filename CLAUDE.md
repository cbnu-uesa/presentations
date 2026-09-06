# 발표자료 프로젝트

권규상 교수가 학술대회·세미나·자문회의에서 쓰는 발표자료를 **HTML 슬라이드**로 만들고,
웹으로 배포하며, 페이지에서 **슬라이드 형식 PDF**를 내려받게 하는 프로젝트다.

만드는 방식과 배포 방식은 `../200_education`(강의노트)에서 그대로 가져왔다.
디자인 시스템·스크립트·배포 절차가 같고, 다른 것은 셋뿐이다 —
메타 파일 이름(`talk.json`), 표지 구성(발표자·행사가 들어간다), 공개 판단의 기준.

---

## 반드시 먼저 지킬 것

### 1. 공개/비공개 경계

발표자료에는 아직 세상에 내놓지 않은 것이 섞인다. 웹에 올라가면 되돌릴 수 없다.

| 폴더 | 공개 | 내용 |
|---|---|---|
| `slides/` | 공개 | 발표 슬라이드 HTML |
| `pdf/` | 공개 | 빌드된 PDF |
| `assets/` | 공개 | 발표용 이미지 |
| `source/` | **비공개** | 초록, 원고, 받은 pptx·템플릿, 참고문헌 스캔 |
| `private/` | **비공개** | 미공표 데이터, 심사 중 논문 그림, 자문 대상 기관이 준 자료 |

- 배포 산출물에는 `slides/`, `pdf/`, `assets/`, `index.html`, `talk.json`, `_shared/`만 담는다.
  화이트리스트 방식이며, 제외 목록으로 관리하지 않는다.
- 새 파일을 만들 때 이 파일이 어느 칸에 속하는지 먼저 정한다.

**발표자료에만 있는 위험 둘.** 강의노트에는 없던 것이라 따로 적어 둔다.

1. **미공표 연구 결과.** 학술대회 발표는 논문 게재 전인 경우가 많다. 발표를 공개 번들에
   넣기 전에 `talk.json`의 `public`을 **사람이 판단한다.** 기본값은 `false`다.
   판단 근거는 `private/공개-판단.md`에 남긴다.
2. **제3자가 준 자료.** 자문·용역에서 받은 자료는 출처를 적었다고 배포가 정당화되지 않는다.
   외부 출처 이미지는 `assets/ex-*` 접두사로 두고, **배포 직전 `ls */assets/ex-*`로
   전수 확인해 판단을 받는다.** (강의노트의 `tb-` 규칙과 같은 장치다)

### 2. Google Drive 동기화 폴더다

작업 폴더가 Google Drive 동기화 대상이다. 파일 수가 폭증하면 동기화가 망가진다.

- **`npm install`을 이 폴더에서 실행하지 않는다.** `node_modules`를 만들지 않는다.
- 라이브러리는 필요한 dist 파일만 `_shared/vendor/`에 직접 둔다. 강의노트와 같은 규모를 유지한다.
- 일회성 도구는 `npx`로 실행한다. 캐시가 `~/.npm`(Drive 밖)에 남는다.
- 임시 파일은 이 폴더가 아니라 시스템 임시 디렉터리에 만든다.

**셸에서 한글 파일명을 glob으로 매칭하지 않는다.** macOS는 파일명을 NFD(자모 분리)로
저장하는데 스크립트에 적는 한글 리터럴은 NFC라서 패턴이 아무것도 못 잡고 조용히 넘어간다.
폴더를 찾을 때는 이름 대신 **`talk.json`이 있는지**로 판별한다.
URL에 쓸 때도 한글 경로는 `urllib.parse.quote`로 인코딩한다.

### 3. 슬라이드를 만들거나 고치기 전에 `design.md`를 읽는다

색·치수·슬라이드 유형이 전부 거기 있다. §1~§11은 강의노트 디자인 시스템과 같고,
**발표에만 해당하는 것은 §12에 있다.**

테마 파일은 다섯이고 읽는 순서가 곧 덮어쓰는 순서다.

```
tokens.css → cbnu.css → components.css → print.css → talk.css
└──────────── 강의노트에서 복사 ────────────┘   └ 발표 전용 ┘
```

**앞의 넷을 고치지 않는다.** 그 넷은 `../200_education/_shared/theme`의 복사본이고
`_scripts/sync-shared.sh`로 언제든 덮어써야 한다. 발표에 필요한 것은 `talk.css`에만 적는다.
반대로 앞의 넷을 고쳐야 할 규범이라면 200_education 쪽을 고치고 여기로 끌어온다.

`talk.css`를 고친 뒤에는 **CSS 가중치부터 확인한다.** 선택자에 `.reveal`을 붙여
강의 규칙과 같은 층위를 유지한다.

---

## 폴더 구조

```
800_presentation/
├── CLAUDE.md              이 파일
├── design.md              디자인 시스템 — 슬라이드 작업 전 필독 (§12가 발표 전용)
├── index.html             전체 발표 목록 — TALKS 배열이 수동 등록 지점
├── _shared/               공용 자산 (200_education 복사본 + 발표용 둘)
│   ├── theme/             tokens · cbnu · components · print + **talk.css**
│   ├── js/                charts.js + **talk-init.js**
│   ├── fonts/             Pretendard woff2 3종 · BookkMyungjo (제목 명조)
│   ├── img/               cbnu-logo.jpg
│   └── vendor/            reveal · chartjs · mathjax-tex-svg.js
├── _templates/            talk.html · talk.json · talk-index.html
├── _scripts/              serve.sh · build-pdf.sh · build-site.sh
│                          check-figures.sh · check-links.sh · sync-shared.sh
└── 2026-09-05_충북대학교_논문작성법과연구윤리/     ← 발표 하나
    ├── talk.json          행사·날짜·발표자·푸터·덱 목록의 유일한 원천
    ├── index.html         이 발표 안내 (_templates/talk-index.html 복사)
    ├── slides/deck.html
    ├── pdf/deck.pdf       빌드 산출물
    ├── assets/            이 발표 전용 이미지
    ├── source/            비공개 — 초록·원고·받은 원본
    └── private/           비공개 — 미공표 데이터
```

새 발표를 열 때: `talk.json`만 만들면 빌드·검사 스크립트가 자동 인식한다.
수동 등록은 **루트 `index.html`의 `TALKS` 배열** 한 곳뿐이다.
발표 `index.html`은 `_templates/talk-index.html`을 그대로 복사하면 된다
(발표명이 하드코딩돼 있지 않다).

### 명명 규칙

- 발표 폴더: `YYYY-MM-DD_행사명_발표내용`
  (예: `2026-09-05_충북대학교_논문작성법과연구윤리`)
  - 날짜가 앞이라 문자열 정렬이 곧 날짜 정렬이다. 루트 목록이 이것에 기댄다
  - 행사명·발표내용은 **공백 없이** 붙여 쓴다
- 슬라이드 파일: `deck.html` 하나가 기본. 폴더 이름이 이미 날짜·행사·주제를 담고 있어
  파일명에 다시 적지 않는다. 15분판·30분판처럼 변형이 생기면 `deck-15min.html`
- PDF: 슬라이드와 같은 이름 (`deck.pdf`). 내려받는 이름은 `talk-init.js`가
  **폴더명**으로 바꿔 준다

### `talk.json`

발표 메타는 여기 한 곳에만 둔다. 표지 넉 줄(행사명·제목·발표자·날짜), 푸터 문구,
쪽번호, 다운로드 버튼, 덱 목록, 공개 여부가 전부 이 파일에서 나온다.
**슬라이드 HTML에 행사명·날짜·발표자를 하드코딩하지 않는다.**

규격은 `_templates/talk.json`에 주석과 함께 있다. `course.json`의 `lectures` 자리를
`decks`가 대신하며 구조는 같다.

---

## 발표자료 작성 워크플로

입력은 보통 **발표 개요를 대화로 전달**받거나 **기존 pptx**를 받는 형태다. 순서를 지킨다.

**0) 시간 예산을 먼저 정한다.** 발표는 강의와 달리 시간이 잘려 있다.
`talk.json`의 `minutes`를 먼저 적고 장수를 거기서 역산한다.
**분당 1~1.5장이 기준이다** — 20분 발표면 15~25장. 40장은 실패다.
`talk-init.js`가 슬라이드를 열 때 장당 초를 콘솔에 찍는다.

**1) 구성안을 먼저 제시하고 확인받는다.**
슬라이드를 바로 쓰지 않는다. 아래 형식으로 목록을 만들어 확인을 받는다.

```
1. [T1 표지] 논문작성법과 연구윤리
2. [T12 섹션] 1. 논문이란 무엇인가
3. [T3 정의] 학술논문 — 검증 가능한 주장을 공적으로 내놓는 형식
4. [T4 2단] 구조(IMRaD) — 좌: 절별 역할 / 우: 흐름도
```

유형 표기(`T1`~`T12`)는 `design.md` §5의 카탈로그를 따른다.

**2) `_templates/talk.html`을 복사해 시작한다.** 빈 파일에서 쓰지 않는다.

**3) 슬라이드를 쓴다.**
- 개념 그래프는 `_shared/js/charts.js`의 함수를 먼저 찾아 쓴다. 없으면 새로 만들되
  재사용 가능하게 `charts.js`에 추가한다.
- 실측 데이터 그래프만 Chart.js를 쓴다.
- 누적 공개는 `.fragment`로 한다. 슬라이드를 복제하지 않는다.

**4) 미리보기로 확인한다.** `_scripts/serve.sh` (포트 8180 — 강의노트와 겹치지 않는다)

**5) 그래프를 검사한다.** `_scripts/check-figures.sh` — 좌표점이 곡선을 벗어났는지,
글자가 캔버스 밖으로 잘렸는지, **표·그림이 푸터를 넘었는지** 기계로 잡아낸다.
**문제가 0건이 될 때까지 PDF를 뽑지 않는다.**

푸터를 넘으면 순서대로 시도한다: 그림 상한 → `<div class="body tight">` →
`tighter` → 그림·표 자체를 줄인다.

검사기가 못 잡는 것은 **라벨끼리의 겹침과 논리의 정합성**이다. 눈으로 확인한다.

**6) PDF를 빌드한다.** `_scripts/build-pdf.sh`

### 내용에 관한 규칙

- **발표 내용을 임의로 창작하지 않는다.** 사용자가 준 원고·개요에 없는 사실, 수치,
  사례를 지어내지 않는다. 원본 그림을 다른 것으로 바꾸는 것도 창작이다.
- **강의노트에서 슬라이드를 가져올 때 출처를 지운 채 옮기지 않는다.**
  200_education의 `assets/tb-*`는 교재 유래이므로 발표 자료로 그대로 옮길 수 없다.
- 그림은 좌표를 손으로 찍지 않고 관계식에서 유도한다 (`design.md` §6.4).
- 근거가 불명확하거나 여러 해석이 가능하면 슬라이드에 채워 넣지 말고 **물어본다.**
- 사용자가 쓴 표현이 있으면 그대로 쓴다. 매끄럽게 다듬는다며 바꾸지 않는다.

---

## 기존 PPT 변환 워크플로

받은 pptx를 HTML로 옮길 때의 순서다. 강의노트에서 1학기 아홉 강을 옮기며 정리한 것이다.

1. **원본을 먼저 `source/`로 옮긴다.** 루트에 던져 둔 pptx·pdf는 `.gitignore`가 막고 있지만,
   발표 폴더의 `source/`가 제자리다.
2. `source/`의 pdf를 읽어 슬라이드 순서와 내용을 파악한다. pptx를 풀면(`unzip`)
   정확한 좌표·색·글자를 잴 수 있다.
3. **누적 공개로 복제된 슬라이드를 하나로 합친다.** 원본에서 같은 제목이 연속 3~4장 나오고
   요소만 늘어나면, 그것은 한 슬라이드의 fragment 단계다.
4. 그래프·도식은 이미지로 캡처하지 말고 SVG로 다시 그린다. 확대해도 깨지지 않고
   색을 토큰으로 관리할 수 있다. 재작도가 불가능한 것(사진, 3D 렌더링)만 잘라
   `assets/`에 두고, 외부 유래면 `ex-` 접두사를 붙인다.
5. 변환 후 원본 PDF와 나란히 놓고 대조한다. 누락된 슬라이드가 없는지, 문구가
   바뀌지 않았는지 본다.

---

## 명령어

```bash
# 로컬 미리보기 (http://localhost:8180)
_scripts/serve.sh

# 그래프 검사 — 점이 곡선을 벗어났는지, 글자가 잘렸는지, 푸터를 넘었는지
_scripts/check-figures.sh
_scripts/check-figures.sh 2026-09-05_.../slides/deck.html

# PDF 빌드 — 인자 없으면 전체, 있으면 해당 파일만
_scripts/build-pdf.sh
_scripts/build-pdf.sh 2026-09-05_.../slides/deck.html

# 링크 검사 — 발표 목록이 가리키는 슬라이드·PDF 가 실제로 열리는지
_scripts/check-links.sh                       # 배포 전에 로컬로 돌린다

# 배포용 정적 사이트 생성 (화이트리스트 복사)
_scripts/build-site.sh                        # 전체 (Access 로 잠긴 사이트용)
PUBLIC_ONLY=1 _scripts/build-site.sh          # public: true 인 발표만

# 강의노트의 테마·폰트·vendor 갱신분 끌어오기
_scripts/sync-shared.sh                       # 무엇이 달라지는지만 본다
_scripts/sync-shared.sh --apply               # 덮어쓴다
```

`check-figures.sh`가 슬라이드 **안**을 본다면 `check-links.sh`는 슬라이드 **사이**를 본다.
`talk.json`의 `file` 결손·오타, 등록하지 않은 슬라이드, 루트 `TALKS` 누락을 잡는다.
**한 발표의 결손이 목록 전체를 죽이게 두지 않는다** — 강의노트에서 실제로 겪은 사고다.

PDF는 `npx decktape`가 헤드리스 Chrome으로 만든다. 브라우저 인쇄 대화상자에 의존하지
않는다 — 사용자 환경마다 결과가 달라지기 때문이다.
`check-figures.sh`는 decktape이 받아 둔 puppeteer를 재사용하므로
**`build-pdf.sh`를 한 번 돌린 뒤에 쓸 수 있다.**

---

## 배포

**GitHub Pages로 개통했다 (2026-09-06).** https://cbnu-uesa.github.io/presentations/

| | 지금 상태 |
|---|---|
| 저장소 | `cbnu-uesa/presentations` **공개** 저장소, 브랜치 둘 |
| `main` | 원본 — 슬라이드 HTML·talk.json·문서 |
| `gh-pages` | 배포본 — `build-site.sh` 산출물을 통째로 |
| 호스팅 | GitHub Pages (`gh-pages` 브랜치, 루트) |
| 접근 | **잠겨 있지 않다. 누구나 볼 수 있다** |

**지금은 사이트 전체가 공개다.** GitHub Free는 공개 저장소에서만 Pages가 되고,
공개 저장소면 `main`의 슬라이드 원본도 github.com에서 그대로 읽힌다.
사용자가 이 상태로 개통을 결정했다 (2026-09-06).

그래서 **`talk.json`의 `public`은 지금 실효가 없다.** 새 발표를 올릴 때
"이것이 오늘부터 전 세계에 공개돼도 되는가"를 반드시 먼저 묻는다.
미공표 연구 결과나 제3자 제공 자료가 섞였다면 커밋하기 전에 판단을 받는다.

**나중에 Cloudflare를 붙일 때 알아 둘 것.** Cloudflare Workers + Access는
Workers 주소만 잠근다. github.io 주소는 그대로 열려 있으므로, 정말 닫으려면
GitHub Pages를 끄거나 저장소를 비공개로 돌려야 한다 (비공개 저장소는 Free에서
Pages가 안 되지만 Cloudflare Workers는 배포된다). 강의노트도 같은 상태다.

`.gitignore`가 `*/private/`·`*/source/`·`*/pdf/`·`dist/`를 막는다. **이 네 줄을 지우지 않는다** —
미공표 자료가 공개 저장소로 나가는 것을 막는 유일한 장치다.

### 배포 절차

```bash
_scripts/build-pdf.sh                     # pdf/ 는 git 에 없다. 먼저 뽑아야 버튼이 산다
_scripts/check-links.sh                   # 배포 전에 로컬로. 오류 0건이어야 한다
_scripts/build-site.sh                    # 산출물을 시스템 임시 폴더에 만든다
DIST="$TMPDIR/talk-site"

# 비공개가 섞이지 않았는지 눈으로 한 번 더 (build-site.sh 도 스스로 막지만)
find "$DIST" \( -path '*/source/*' -o -path '*/private/*' \) -print   # 아무것도 안 나와야 한다
ls */assets/ex-* 2>/dev/null                                          # 외부 출처 전수 확인

cd "$DIST" && rm -rf .git && git init -q -b gh-pages
git config user.name "권규상" && git config user.email "kks1104@gmail.com"
git add -A && git commit -q -m "배포 산출물 $(date +%F)"
git push --force https://github.com/cbnu-uesa/presentations.git gh-pages
```

원본(`main`)도 잊지 말고 따로 커밋한다 — `gh-pages` 는 산출물만 담는 별개의 이력이다.
푸시 뒤 Pages 빌드는 1~2분 걸린다.

```bash
gh api repos/cbnu-uesa/presentations/pages --jq '.status'   # built 가 되면 반영됐다
```

### 강의노트에서 이미 겪은 것 (같은 실수를 반복하지 않는다)

- **`.nojekyll`이 없으면 사이트가 통째로 깨진다.** Jekyll이 밑줄로 시작하는 최상위 폴더를
  무시해 `_shared/`가 빠지고 전 슬라이드의 CSS·폰트·JS가 404가 된다.
  `build-site.sh`가 자동으로 만든다.
- Workers 프로젝트는 배포본에 **`wrangler.jsonc`**가 있어야 뜬다 — 없으면
  `Missing entry-point to Worker script or to assets directory`로 죽는다.
- 자산은 **파일 하나당 25MiB**가 한도다. `.git`의 팩 파일이 걸리므로
  **`.assetsignore`**로 뺀다. 위 둘 다 `build-site.sh`가 만든다. 손으로 만들지 않는다.
- **Production branch를 `gh-pages`로** 놓는다. `main`으로 두면 사이트는 뜨지만
  `pdf/`가 깃에 없어 PDF만 빠진다.
- **Builds for non-production branches는 끈다.** 켜 두면 `main`에 커밋할 때마다
  헛도는 빌드가 실패로 쌓인다.
- 한글 폴더명은 퍼센트 인코딩으로 잘 열린다. 별도 처리가 필요 없었다.
- Free 계정은 **공개 저장소에서만** Pages가 된다.
- **링크 검사는 배포 전에 로컬로 돌린다.** 지금은 배포본도 열려 있어 주소를 넘겨 검사할 수
  있지만, Cloudflare Access를 붙이면 로그인 없는 요청이 403으로 막힌다.
- **`gh-pages` 를 강제 푸시하면 그 브랜치의 이력이 통째로 갈린다.** 산출물 전용이므로
  의도된 것이다. 원본 이력은 `main` 에 있다.
- 배포 직후 몇 분간은 CDN이 옛 응답을 준다. 새로 올린 파일이 404로 보이면 잠시 기다린다.
- 헤드리스 브라우저로 배포본을 볼 때 PDF HEAD 요청이 `net::ERR_ABORTED` 로 찍힌다.
  본문 없는 응답을 Chrome이 끊는 것이고 실제로는 200이다 — 다운로드 버튼은 정상이다.
- github.io 루트에 `favicon.ico` 가 없어 404가 하나 남는다. 화면에는 영향이 없다.

**나중에 Cloudflare Access를 붙일 때**는 강의노트와 같은 Zero Trust 계정(50명까지 무료)에
application을 하나 더 만든다. Include를 본인 이메일로 시작하고, 특정 발표를 청중에게 열 때
Identity provider를 **One-time PIN**으로 두면 상대는 계정 없이 메일로 온 코드만 넣으면 된다.
다만 위에 적었듯 그것만으로는 github.io 주소가 닫히지 않는다.
