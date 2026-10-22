// 記法変換（Sources/KokugoCore/Markup.swift の移植）。仕様は docs/CONTENT_FORMAT.md。
const Markup = (() => {
  const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  const isKana = ch => { const c = ch.codePointAt(0); return (c >= 0x30A0 && c <= 0x30FF) || (c >= 0x3040 && c <= 0x309F); };
  const isBase = ch => { const c = ch.codePointAt(0); return (c >= 0x3400 && c <= 0x9FFF) || (c >= 0xF900 && c <= 0xFAFF) || ch === '々' || ch === '〇'; };

  function parse(c, kanbun, plain) {
    let i = 0;
    const peek = (s, j = i) => c.slice(j, j + s.length).join('') === s;
    const find = (close, from) => { for (let k = from; k < c.length; k++) if (peek(close, k)) return k; return -1; };
    function marks() {
      let okuri = null, kaeri = null, go = true;
      while (go) {
        go = false;
        if (okuri === null && c[i] === '（') {
          const e = find('）', i + 1);
          if (e > 0 && c.slice(i + 1, e).every(isKana)) { okuri = c.slice(i + 1, e).join(''); i = e + 1; go = true; }
        }
        if (kaeri === null && c[i] === '〔') {
          const e = find('〕', i + 1);
          if (e > 0) { kaeri = c.slice(i + 1, e).join(''); i = e + 1; go = true; }
        }
      }
      return (okuri ? `<span class="okuri">${esc(okuri)}</span>` : '') + (kaeri ? `<span class="kaeri">${esc(kaeri)}</span>` : '');
    }
    function run(term) {
      let out = '';
      while (i < c.length) {
        if (term && peek(term)) return out;
        if (peek('[[')) {
          i += 2; const inner = run(']]'); i = Math.min(i + 2, c.length);
          let body = inner, label = null, depth = 0, bar = -1;
          for (let k = 0; k < inner.length; k++) { const ch = inner[k]; if (ch === '<') depth++; else if (ch === '>') depth--; else if (ch === '|' && depth === 0) bar = k; }
          if (bar >= 0) { body = inner.slice(0, bar); label = inner.slice(bar + 1); }
          out += plain ? body : label !== null ? `<span class="bosen">${body}</span><span class="bosen-label">${label}</span>` : `<span class="bosen">${body}</span>`;
          continue;
        }
        if (peek('**')) { i += 2; const inner = run('**'); i = Math.min(i + 2, c.length); out += plain ? inner : `<em class="boten">${inner}</em>`; continue; }
        if (peek('__')) { const e = find('__', i + 2); if (e > i + 2) { const l = c.slice(i + 2, e).join(''); i = e + 2; out += plain ? `（${l}）` : `<span class="blank">${esc(l)}</span>`; continue; } }
        if (c[i] === '{') {
          const bar = find('|', i + 1), end = bar > 0 ? find('}', bar + 1) : -1;
          if (bar > 0 && end > 0 && !c.slice(i + 1, bar).includes('}')) {
            const base = c.slice(i + 1, bar).join(''), ruby = c.slice(bar + 1, end).join('');
            i = end + 1;
            out += plain ? base : `<ruby>${esc(base)}<rt>${esc(ruby)}</rt></ruby>` + (kanbun ? marks() : '');
            continue;
          }
        }
        if (c[i] === '\n') { i++; out += plain ? '\n' : '<br>'; continue; }
        const ch = c[i++];
        if (plain) out += ch;
        else if (kanbun && isBase(ch)) {
          const start = i, m = marks();
          if (!m) out += esc(ch);
          else {
            let n = 0;
            if (c[start] === '（') { const e = find('）', start + 1); if (e > 0) n = e - start - 1; }
            const sp = n >= 3 ? ` style="margin-bottom:${(n * 0.48 - 0.55).toFixed(2)}em"` : '';
            out += `<span class="kb"${sp}>${esc(ch)}${m}</span>`;
          }
        } else out += esc(ch);
      }
      return out;
    }
    return run(null);
  }
  const inline = (s, kanbun = false) => parse([...s], kanbun, false);
  const plain = s => parse([...s], false, true);
  const html = (s, kanbun = false) => {
    const n = s.replace(/\r\n/g, '\n');
    const ps = n.split('\n\n').map(p => p.replace(/^\n+|\n+$/g, '')).filter(Boolean);
    return ps.length <= 1 ? inline(n.replace(/^\n+|\n+$/g, ''), kanbun) : ps.map(p => `<p>${inline(p, kanbun)}</p>`).join('');
  };
  return { html, inline, plain, esc };
})();
