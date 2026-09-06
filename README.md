# 발표자료

권규상(충북대학교 도시공학과)의 학술대회·세미나·자문 발표자료를 HTML 슬라이드로 만들고
웹으로 배포하는 저장소다. 원본이 HTML이고 PDF는 그 산출물이다.

**사이트** — https://cbnu-uesa.github.io/presentations/

만드는 방식은 강의노트 저장소([cbnu-uesa/lecture-notes](https://github.com/cbnu-uesa/lecture-notes))에서
그대로 가져왔다. 디자인 시스템·빌드 스크립트·배포 절차가 같다.

## 구조

```
presentations/
├── CLAUDE.md      프로젝트 규범
├── design.md      디자인 시스템 (§12가 발표 전용)
├── index.html     전체 발표 목록
├── _shared/       테마 · 폰트 · Reveal.js
├── _templates/    발표 스캐폴드
├── _scripts/      빌드 · 검사 · 배포
└── YYYY-MM-DD_행사명_발표내용/
    ├── talk.json  발표 메타의 유일한 원천
    ├── slides/    슬라이드 HTML
    ├── assets/    이 발표 전용 그림
    ├── source/    비공개 (커밋하지 않는다)
    └── private/   비공개 (커밋하지 않는다)
```

`.gitignore`가 `*/source/`와 `*/private/`를 막는다. 원고·미공표 자료가 공개 저장소로
나가는 것을 막는 장치다.

## 쓰는 법

```bash
_scripts/serve.sh          # 미리보기 http://localhost:8180
_scripts/check-figures.sh  # 그림·넘침 검사 (0건이어야 PDF를 뽑는다)
_scripts/build-pdf.sh      # 슬라이드 → PDF
_scripts/check-links.sh    # 목록 ↔ 실제 파일 대조
_scripts/build-site.sh     # 배포 번들 생성
```

자세한 규범과 배포 절차는 `CLAUDE.md`에 있다.

## 저작권

각 발표의 `assets/ex-*`는 외부에서 가져온 그림이다(화면캡처·상표·문헌 인용).
배포 전 전수 확인 대상이며, 확인이 끝나지 않은 항목은 해당 발표의
`private/확인-필요-사항.md`에 적어 둔다.
