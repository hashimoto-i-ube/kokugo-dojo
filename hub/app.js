'use strict';
// 国語道場 ULSハブ版。画面は #ルート で切り替える。学習記録は ToolStorage（ハブのブリッジ）に保存。
const SUBJECTS = [
  { id: 'kanji', pack: 'kanji', title: '漢字', icon: '漢' },
  { id: 'vocabulary', pack: 'vocabulary', title: '語彙', icon: '語' },
  { id: 'modernReading', pack: 'reading', title: '現代文読解', icon: '読' },
  { id: 'kobunWords', pack: 'kobun-words', title: '古文単語', icon: '古' },
  { id: 'kobunGrammar', pack: 'kobun-grammar', title: '古典文法', icon: '文' },
  { id: 'kanbun', pack: 'kanbun', title: '漢文句法', icon: '漢文' },
  { id: 'knowledge', pack: 'knowledge', title: '基礎知識・文学史', icon: '知' },
];
const LEVELS = ['', 'Lv.1 高校入門', 'Lv.2 高校基礎', 'Lv.3 共通テスト', 'Lv.4 難関大', 'Lv.5 旧帝大・医学部'];
const DAY = 86400000, NEW_PER_SESSION = 10, MAX_SESSION = 30;

const $app = document.getElementById('app'), $title = document.getElementById('title'), $back = document.getElementById('back');
const M = Markup;
let packs = {}, progress = {}, log = {}, prefs = { level: 0 };
let saveTimer = null;

const todayKey = () => { const d = new Date(); return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`; };
const shuffle = a => { a = a.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };

// ---- 保存 ----
async function load() {
  await ToolStorage.ready;
  const read = async (k, d) => { try { const v = await ToolStorage.getItem(k); return v ? JSON.parse(v) : d; } catch { return d; } };
  progress = await read('progress', {}); log = await read('log', {}); prefs = Object.assign(prefs, await read('prefs', {}));
}
function save() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(async () => {
    try {
      await ToolStorage.setItem('progress', JSON.stringify(progress));
      await ToolStorage.setItem('log', JSON.stringify(log));
      await ToolStorage.setItem('prefs', JSON.stringify(prefs));
    } catch (e) { console.error('保存に失敗', e); }
  }, 200);
}
window.addEventListener('pagehide', () => { clearTimeout(saveTimer); ['progress', 'log', 'prefs'].forEach(k => ToolStorage.setItem(k, JSON.stringify({ progress, log, prefs }[k]))); });

// ---- 間隔反復（SRS.swift の簡略移植）----
function review(id, grade) { // 0=もう一度 1=あいまい 2=覚えた 3=簡単
  const now = Date.now();
  const s = Object.assign({ ease: 2.5, interval: 0, due: 0, reps: 0, lapses: 0, correct: 0, wrong: 0 }, progress[id]);
  if (grade === 0) {
    if (s.reps > 0) s.lapses++;
    s.reps = 0; s.interval = 0; s.ease = Math.max(1.3, s.ease - 0.2); s.wrong++; s.due = now + 60000; s.seen = 1; progress[id] = s;
  } else {
    if (grade === 1) { s.ease = Math.max(1.3, s.ease - 0.15); s.interval = s.reps === 0 ? 1 : Math.max(1, s.interval * 1.2); }
    else if (grade === 2) s.interval = s.reps === 0 ? 1 : s.reps === 1 ? 3 : Math.max(s.interval + 1, s.interval * s.ease);
    else { s.ease += 0.15; s.interval = s.reps === 0 ? 4 : Math.max(s.interval + 1, s.interval * s.ease * 1.3); }
    s.reps++; s.correct++; s.interval = Math.min(s.interval, 365);
    const d = new Date(); d.setHours(0, 0, 0, 0); s.due = d.getTime() + s.interval * DAY; s.seen = 1; progress[id] = s;
  }
  log[todayKey()] = (log[todayKey()] || 0) + 1;
  save();
}
const isNew = id => !progress[id] || !progress[id].seen;
const isDue = id => { const s = progress[id]; return !!(s && s.seen && s.due <= Date.now()); };

// ---- コンテンツ ----
async function loadContent() {
  const man = await (await fetch('content/manifest.json')).json();
  for (const p of man.packs) packs[p.id] = await (await fetch('content/' + p.file)).json();
}
const allDecks = () => Object.values(packs).flatMap(p => p.decks.map(d => Object.assign({ pack: p.id, subject: p.subject }, d)));
const findDeck = id => allDecks().find(d => d.id === id);
const lvItems = d => d.items.filter(i => !prefs.level || i.level === prefs.level);
const dueCount = ds => ds.reduce((n, d) => n + lvItems(d).filter(i => isDue(i.id)).length, 0);
const decksOf = sid => { const s = SUBJECTS.find(x => x.id === sid); return packs[s.pack] ? packs[s.pack].decks.map(d => Object.assign({ pack: s.pack }, d)) : []; };

// ---- 描画の部品 ----
const h = (s) => M.esc(String(s));
function textBox(src, { vertical, kanbun, cls = '' } = {}) {
  return `<div class="jtext ${vertical ? 'v' : 'h'} ${kanbun ? 'kanbun' : ''} ${cls}">${M.html(src, kanbun)}</div>`;
}
function setHeader(title, backTo) {
  $title.textContent = title; document.title = title + ' - 国語道場';
  $back.hidden = !backTo; $back.onclick = () => { location.hash = backTo; };
}
function levelChips(rerender) {
  const html = `<div class="chips">${LEVELS.map((l, i) => `<button class="chip ${prefs.level === i ? 'on' : ''}" data-lv="${i}">${i ? l.split(' ')[0] : 'すべて'}</button>`).join('')}</div>`;
  setTimeout(() => $app.querySelectorAll('[data-lv]').forEach(b => b.onclick = () => { prefs.level = +b.dataset.lv; save(); rerender(); }));
  return html;
}

// ---- ホーム ----
function home() {
  setHeader('国語道場');
  const ds = allDecks(), due = dueCount(ds), today = log[todayKey()] || 0;
  const cards = SUBJECTS.map(s => {
    const d = decksOf(s.id), n = d.reduce((a, x) => a + x.items.length, 0) + (packs[s.pack] && packs[s.pack].passages && s.id !== 'kanbun' ? 0 : 0);
    const du = dueCount(d), np = (packs[s.pack] && packs[s.pack].passages || []).length;
    return `<a class="card subj" href="#/s/${s.id}"><span class="ico">${s.icon}</span><b>${s.title}</b>
      <small>${n}問${np ? `・読解${np}本` : ''}</small>${du ? `<span class="badge">復習 ${du}</span>` : ''}</a>`;
  }).join('');
  $app.innerHTML = `<section class="hero"><div><div class="big">${due}</div><div class="muted">今日の復習</div></div>
    <div><div class="big sm">${today}</div><div class="muted">今日の学習数</div></div>
    <a class="btn primary" href="#/study/all" ${due ? '' : 'aria-disabled="true"'}>復習をはじめる</a></section>
    <h2>分野</h2><div class="grid">${cards}</div>`;
}

// ---- 分野 ----
function subject(sid) {
  const s = SUBJECTS.find(x => x.id === sid); if (!s) return home();
  setHeader(s.title, '#/');
  const pack = packs[s.pack], decks = decksOf(sid);
  const deckHtml = decks.map(d => {
    const it = lvItems(d), due = it.filter(i => isDue(i.id)).length, nw = it.filter(i => isNew(i.id)).length, mature = it.filter(i => progress[i.id] && progress[i.id].interval >= 21).length;
    return `<div class="card deck"><div class="deckhead"><b>${h(d.title)}</b><small class="muted">${h(d.description || d.instruction || '')}</small></div>
      <div class="stats"><span>全${it.length}</span><span>新規${nw}</span><span class="${due ? 'due' : ''}">復習${due}</span><span>定着${mature}</span></div>
      <div class="row"><a class="btn primary" href="#/study/${d.id}">学習</a>
      <a class="btn" href="#/quiz/${d.id}">4択テスト</a></div></div>`;
  }).join('');
  const ps = (pack.passages || []).filter(p => !prefs.level || p.level === prefs.level).map(p =>
    `<a class="card row link" href="#/p/${p.id}"><span><b>${h(p.title)}</b><small class="muted"> ${h(p.genre)}・Lv.${p.level}・${p.questions.length}問</small></span><span>›</span></a>`).join('');
  const ls = (pack.lessons || []).map(l => `<a class="card row link" href="#/l/${l.id}"><b>${h(l.title)}</b><span>›</span></a>`).join('');
  $app.innerHTML = levelChips(() => subject(sid)) + `<h2>問題集</h2>${deckHtml}` +
    (ps ? `<h2>読解演習</h2>${ps}` : '') + (ls ? `<h2>解説</h2>${ls}` : '');
}

// ---- 学習 ----
let S = null; // セッション
function buildQueue(decks) {
  const due = [], nw = [];
  for (const d of decks) for (const i of lvItems(d)) {
    const c = { item: i, deck: d };
    if (isDue(i.id)) due.push(c); else if (isNew(i.id)) nw.push(c);
  }
  return shuffle(due).slice(0, MAX_SESSION).concat(shuffle(nw).slice(0, NEW_PER_SESSION));
}
function study(id, mode) {
  const decks = id === 'all' ? allDecks() : [findDeck(id)].filter(Boolean);
  if (!decks.length) return home();
  const sub = id === 'all' ? null : SUBJECTS.find(s => s.pack === decks[0].pack);
  const backTo = sub ? `#/s/${sub.id}` : '#/';
  setHeader(id === 'all' ? '今日の復習' : decks[0].title, backTo);
  let queue = buildQueue(decks);
  if (mode === 'quiz') queue = shuffle(lvItems(decks[0])).slice(0, 10).map(i => ({ item: i, deck: decks[0] }));
  S = { queue, total: queue.length, done: 0, correct: 0, mode, backTo, pool: decks };
  card();
}
function choicesFor(c) {
  const { item, deck } = c;
  let wrong = item.distractors && item.distractors.length ? item.distractors : shuffle(lvItems(deck).map(i => i.answer).filter(a => a !== item.answer)).slice(0, 3);
  wrong = shuffle(wrong).slice(0, 3);
  return shuffle([item.answer].concat(wrong));
}
function card() {
  if (!S.queue.length) {
    $app.innerHTML = `<section class="hero col"><div class="big sm">おつかれさま！</div><p>${S.done}問 学習しました${S.mode === 'quiz' ? `（正解 ${S.correct}）` : ''}</p>
      <a class="btn primary" href="${S.backTo}">戻る</a></section>`;
    return;
  }
  const c = S.queue[0], { item, deck } = c;
  const quiz = S.mode === 'quiz' || deck.kind === 'choice';
  const vertical = deck.writing !== 'horizontal';
  const choices = quiz ? choicesFor(c) : null;
  const left = S.queue.length, pct = Math.round(S.done / (S.done + left) * 100);
  const lv = item.level ? `<span class="tag">Lv.${item.level}</span>` : '';
  $app.innerHTML = `<div class="progress"><i style="width:${pct}%"></i></div>
    <p class="muted instr">${lv} ${h(deck.instruction || '')}　<span>残り${left}</span></p>
    <div class="card prompt ${vertical ? 'vwrap' : ''}">${textBox(item.prompt, { vertical, kanbun: !!deck.kanbun })}</div>
    <div id="ans"></div>
    ${quiz ? `<div class="choices">${choices.map((a, i) => `<button class="choice" data-i="${i}">${M.inline(a)}</button>`).join('')}</div>`
           : `<button class="btn primary wide" id="show">答えを見る</button>`}`;
  const reveal = (grade) => {
    $app.querySelector('.choices, #show') && ($app.querySelector('.choices, #show').style.display = 'none');
    document.getElementById('ans').innerHTML = `<div class="card answer"><div class="a">${M.inline(item.answer)}</div>
      ${item.note ? `<div class="muted">${M.inline(item.note)}</div>` : ''}</div>
      <div class="grades">${grade !== undefined ? '<button class="btn primary wide" data-g="next">つぎへ</button>' :
      ['もう一度', 'あいまい', '覚えた', '簡単'].map((t, i) => `<button class="btn g${i}" data-g="${i}">${t}</button>`).join('')}</div>`;
    document.querySelectorAll('[data-g]').forEach(b => b.onclick = () => {
      const g = b.dataset.g === 'next' ? grade : +b.dataset.g;
      S.queue.shift(); review(item.id, g); S.done++; if (g > 0) S.correct++;
      if (g === 0 && S.mode !== 'quiz') S.queue.push(c);
      card();
    });
  };
  if (quiz) $app.querySelectorAll('.choice').forEach(b => b.onclick = () => {
    const ok = choices[+b.dataset.i] === item.answer;
    $app.querySelectorAll('.choice').forEach(x => { x.disabled = true; x.classList.add(choices[+x.dataset.i] === item.answer ? 'ok' : (x === b ? 'ng' : '')); });
    $app.querySelector('.choices').style.display = '';
    document.getElementById('ans').innerHTML = '';
    reveal(ok ? 2 : 0); $app.querySelector('.choices').style.display = '';
    document.getElementById('ans').insertAdjacentHTML('afterbegin', `<p class="verdict ${ok ? 'ok' : 'ng'}">${ok ? '正解！' : '不正解'}</p>`);
  });
  else document.getElementById('show').onclick = () => reveal();
}

// ---- 読解演習 ----
function passage(id) {
  const p = Object.values(packs).flatMap(x => x.passages || []).find(x => x.id === id); if (!p) return home();
  const owner = SUBJECTS.find(s => (packs[s.pack].passages || []).includes(p));
  setHeader(p.title, `#/s/${owner.id}`);
  const vertical = p.genre !== '漢文' && !p.kanbun ? true : true;
  const qs = p.questions.map((q, qi) => {
    const order = shuffle(q.choices.map((c, i) => i));
    return `<div class="card q" data-q="${qi}"><p><b>問${qi + 1}</b> ${M.inline(q.prompt)}</p>
      ${order.map(i => `<button class="choice" data-c="${i}">${M.inline(q.choices[i])}</button>`).join('')}<div class="exp"></div></div>`;
  }).join('');
  $app.innerHTML = `<p class="muted">${h(p.genre)}・Lv.${p.level}${p.source ? '・' + h(p.source) : ''}　<small>（左へスクロールして読む）</small></p>
    <div class="card vbox">${textBox(p.text, { vertical, kanbun: !!p.kanbun, cls: 'long' })}</div>${qs}
    <div id="comm"></div>`;
  let answered = 0;
  $app.querySelectorAll('.q').forEach(el => {
    const q = p.questions[+el.dataset.q];
    el.querySelectorAll('.choice').forEach(b => b.onclick = () => {
      const ok = +b.dataset.c === q.answer;
      el.querySelectorAll('.choice').forEach(x => { x.disabled = true; if (+x.dataset.c === q.answer) x.classList.add('ok'); else if (x === b) x.classList.add('ng'); });
      el.querySelector('.exp').innerHTML = `<p class="verdict ${ok ? 'ok' : 'ng'}">${ok ? '正解！' : '不正解'}</p><div class="muted">${M.inline(q.explanation || '')}</div>`;
      if (q.id) { const s = progress['q:' + q.id] || { correct: 0, wrong: 0 }; s[ok ? 'correct' : 'wrong']++; progress['q:' + q.id] = s; log[todayKey()] = (log[todayKey()] || 0) + 1; save(); }
      if (++answered === p.questions.length && p.commentary) document.getElementById('comm').innerHTML = `<div class="card"><h2>解説</h2><p>${M.inline(p.commentary)}</p></div>`;
    });
  });
}

function lesson(id) {
  const l = Object.values(packs).flatMap(x => x.lessons || []).find(x => x.id === id); if (!l) return home();
  const owner = SUBJECTS.find(s => (packs[s.pack].lessons || []).includes(l));
  setHeader(l.title, `#/s/${owner.id}`);
  $app.innerHTML = `<div class="card lesson">${l.body}</div>`;
}

function route() {
  S = null; window.scrollTo(0, 0);
  const [, k, a, b] = location.hash.split('/');
  try {
    if (k === 's') subject(a); else if (k === 'study') study(a); else if (k === 'quiz') study(a, 'quiz');
    else if (k === 'p') passage(a); else if (k === 'l') lesson(a); else home();
  } catch (e) { $app.innerHTML = `<p class="muted">表示に失敗しました：${h(e.message)}</p>`; console.error(e); }
}
document.addEventListener('click', e => {
  const a = e.target.closest('a[href^="http"]'); if (a) { e.preventDefault(); openExternal(a.href); }
  const d = e.target.closest('[aria-disabled="true"]'); if (d) e.preventDefault();
});
window.addEventListener('hashchange', route);
(async () => {
  try { await load(); await loadContent(); route(); }
  catch (e) { $app.innerHTML = `<p class="muted">読み込みに失敗しました：${h(e.message)}</p>`; console.error(e); }
})();
