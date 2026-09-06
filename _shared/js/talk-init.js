/* Reveal 초기화 + 슬라이드 크롬(푸터바·페이지번호·다운로드) 주입
 *
 * 200_education/_shared/js/deck-init.js 를 발표용으로 고친 것이다. 바꾼 곳은 넷:
 *   1) course.json → talk.json
 *   2) 자기 항목을 찾는 방법 — 파일명 앞 두 자리(강 번호)가 아니라 파일명 전체로
 *      decks 에서 찾는다. 발표 슬라이드는 deck.html 이라 앞 두 자리가 숫자가 아니다
 *   3) kicker 는 talk.json 에 kicker 가 있을 때만 넣는다. 발표에는 강 번호가 없다
 *   4) 다운로드 파일명 = 발표 폴더명. pdf/deck.pdf 가 "deck.pdf" 로 저장되면 곤란하다
 *
 * 그 밖(Reveal 설정, 쪽번호 누적 계산, MathJax, PDF fragment 분리)은 그대로다.
 * 발표 슬라이드 HTML 은 이 파일 하나만 부르면 된다. 행사명·날짜·발표자를
 * 슬라이드에 하드코딩하지 않는다 (CLAUDE.md 참조).
 */

(async function () {
  const root = document.currentScript
    ? new URL('..', document.currentScript.src)
    : new URL('../', location.href);

  // ── 발표 메타 ──────────────────────────────────────────────
  // slides/deck.html 기준으로 ../talk.json. file://에서는 fetch가 막히므로
  // 실패해도 슬라이드 자체는 뜨게 둔다.
  let talk = {};
  try {
    const res = await fetch('../talk.json');
    if (res.ok) talk = await res.json();
  } catch (e) {
    console.warn('[talk] talk.json을 읽지 못했습니다. _scripts/serve.sh로 여십시오.', e);
  }

  const deck = document.querySelector('.reveal');
  const sections = deck.querySelectorAll('.slides > section');

  // 경로에서 이 덱이 누구인지 알아낸다.
  //   .../<발표폴더>/slides/<파일명>
  const parts = location.pathname.split('/').filter(Boolean);
  const fileName = decodeURIComponent(parts[parts.length - 1] || '');
  const folder = decodeURIComponent(parts[parts.length - 3] || '');
  const me = (talk.decks || []).find((d) => d.file === fileName) || {};

  // ── 표지 채우기 ────────────────────────────────────────────
  // 값이 없으면 그 자리를 지운다. 빈 요소가 남아 여백만 먹는 것을 막는다.
  const fill = (sel, text) => {
    document.querySelectorAll(sel).forEach((el) => {
      if (text) el.textContent = text;
      else el.remove();
    });
  };

  fill('[data-talk-event]', talk.event || talk.label);

  // 날짜 · 장소를 한 줄로 — "2026. 9. 15. · 충북대학교 개신문화관"
  fill('[data-talk-date]', [talk.date, talk.venue].filter(Boolean).join(' · '));

  // 발표자 · 소속. authors 가 여럿이면 첫 사람을 발표자로 굵게 둔다.
  document.querySelectorAll('[data-talk-byline]').forEach((el) => {
    const authors = talk.authors || [];
    if (!authors.length && !talk.affiliation) { el.remove(); return; }
    el.textContent = '';
    authors.forEach((name, i) => {
      const span = document.createElement('span');
      if (i === 0) span.className = 'speaker';
      span.textContent = name;
      el.append(span);
      if (i < authors.length - 1) el.append(document.createTextNode(' · '));
    });
    if (talk.affiliation) {
      const a = document.createElement('span');
      a.className = 'affil';
      a.textContent = talk.affiliation;
      el.append(a);
    }
  });

  // ── kicker 주입 ────────────────────────────────────────────
  // 강의노트는 "03. 집적의 경제" 를 모든 본문 슬라이드에 얹는다. 발표는 한 덱이
  // 한 주제라 대개 필요 없다. talk.json 에 kicker 를 적었을 때만 넣는다.
  if (talk.kicker) {
    sections.forEach((sec) => {
      if (sec.matches('.s-cover, .s-closing, .s-section')) return;
      if (!sec.querySelector('h2')) return;
      const k = document.createElement('p');
      k.className = 'kicker';
      k.textContent = talk.kicker;
      sec.insertBefore(k, sec.firstChild);
    });
  }

  // ── 푸터바 주입 ────────────────────────────────────────────
  // 표지(.s-cover)에는 넣지 않는다.
  const footerText = talk.footer || '';
  sections.forEach((sec) => {
    if (sec.classList.contains('s-cover')) return;
    const bar = document.createElement('div');
    bar.className = 'deck-footer';
    bar.innerHTML = '<span class="ft-text"></span><span class="ft-num"></span>';
    bar.querySelector('.ft-text').textContent = footerText;
    sec.appendChild(bar);
  });

  // ── 페이지 번호 ────────────────────────────────────────────
  // 슬라이드가 아니라 "단계"를 센다. 누적 공개 한 단계가 PDF 한 쪽이 되므로
  // (design.md §8) 이렇게 해야 화면 번호와 PDF 쪽 번호가 일치한다.
  const stepOffset = [];
  let acc = 0;
  sections.forEach((sec, i) => {
    stepOffset[i] = acc;
    const idx = [...sec.querySelectorAll('.fragment')].map((f) =>
      f.hasAttribute('data-fragment-index') ? +f.dataset.fragmentIndex : null
    );
    // 인덱스가 붙은 것은 같은 값끼리 한 단계, 안 붙은 것은 각자 한 단계
    const numbered = new Set(idx.filter((v) => v !== null));
    const unnumbered = idx.filter((v) => v === null).length;
    acc += 1 + numbered.size + unnumbered;
  });

  function paintPageNumber() {
    const { h, f } = Reveal.getIndices();
    const n = stepOffset[h] + (f === undefined || f < 0 ? 0 : f + 1) + 1;
    const el = Reveal.getCurrentSlide().querySelector('.ft-num');
    if (el) el.textContent = String(n);
  }

  // ── 다운로드 버튼 ──────────────────────────────────────────
  // slides/deck.html → pdf/deck.pdf 를 가리킨다.
  // 내려받는 이름은 발표 폴더명으로 준다. 덱이 여럿이면 뒤에 파일명을 붙인다.
  // ?export=1 은 PDF 빌드용 헤드리스 브라우저가 붙이는 표시다. 그때는 만들지 않는다
  // (안 그러면 버튼이 PDF 모든 쪽에 찍힌다).
  const exporting = new URLSearchParams(location.search).has('export');
  const base = (parts[parts.length - 1] || '').replace(/\.html?$/, '');
  if (base && !exporting) {
    const stem = fileName.replace(/\.html?$/, '');
    const many = (talk.decks || []).length > 1;
    const saveAs = (folder || stem) + (many ? '_' + stem : '') + '.pdf';

    const a = document.createElement('a');
    a.className = 'deck-download';
    a.href = '../pdf/' + base + '.pdf';   // base는 URL 인코딩된 상태 — href에는 그대로
    a.setAttribute('download', saveAs);
    a.textContent = 'PDF 내려받기';
    document.body.appendChild(a);
    // PDF가 아직 빌드되지 않았으면 버튼을 감춘다
    fetch(a.href, { method: 'HEAD' })
      .then((r) => { if (!r.ok) a.hidden = true; })
      .catch(() => { a.hidden = true; });
  }

  // 발표 시간 예산을 콘솔에 찍는다. 20분에 40장이면 그 자리에서 알아야 한다.
  if (me.minutes) {
    console.info(`[talk] ${sections.length}장 / ${me.minutes}분 — ` +
      `장당 ${(me.minutes * 60 / sections.length).toFixed(0)}초`);
  }

  // ── Reveal ────────────────────────────────────────────────
  Reveal.initialize({
    // design.md §2.1 — PPT의 pt와 CSS px를 1:1로 맞춘다
    width: 960,
    height: 540,
    margin: 0,
    minScale: 0.2,
    maxScale: 2.0,

    hash: true,
    controls: false,
    progress: false,
    slideNumber: false,        // 푸터바에서 직접 그린다
    transition: 'none',        // design.md §11
    backgroundTransition: 'none',
    fragmentInURL: true,

    // PDF: fragment 단계마다 페이지를 분리한다 (design.md §8)
    pdfSeparateFragments: true,
    pdfMaxPagesPerSlide: 1,

    plugins: [RevealNotes, RevealMath.MathJax3],

    // MathJax 3의 tex-svg 번들은 파일 하나로 완결된다.
    // SVG 출력이라 PDF에서 벡터로 남는다 (design.md §7).
    mathjax3: {
      mathjax: root.href + 'vendor/mathjax-tex-svg.js',
      tex: {
        inlineMath: [['$', '$'], ['\\(', '\\)']],
        displayMath: [['$$', '$$'], ['\\[', '\\]']],
      },
      options: {
        // 개념도 SVG 안의 텍스트는 수식으로 처리하지 않는다
        skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code', 'svg'],
      },
    },
  });

  // 번호는 초기 표시 후 슬라이드·단계가 바뀔 때마다 다시 그린다
  ['ready', 'slidechanged', 'fragmentshown', 'fragmenthidden'].forEach((ev) =>
    Reveal.on(ev, paintPageNumber)
  );
})();
