// Calendr v11 · round g (designr step 4 and 5): the counter (X), the alignment guides (G), the "Design system" sheet and Before / After (B).
// Hash keys: cnt=1 counter, gd=1 guides, ds=1 design-system sheet, ba=a (after: the recommended type scale) or b / empty (before: your link).
'use strict';
const DSYS = (() => {
  const desk = () => document.querySelector('#host .desk');
  // where a text element sits (first match wins); used to say where a size / weight / colour is used
  const PLACES = [['.hdr h2', 'month title'], ['.hdr', 'header controls'], ['.dh .c .n', 'day header date'], ['.dh .c', 'day header weekday'], ['.gut .now', 'now label'],
    ['.gut', 'hour labels'], ['.ev .m', 'event time'], ['.ev .t', 'event title'], ['.adi .tm', 'all-day time'], ['.adi', 'all-day chip'], ['.ad .more, .ad .less', 'all-day more'],
    ['.ad .g', 'all-day label'], ['.tmk', 'task marker'], ['.mm-h', 'mini-month title'], ['.mm', 'mini-month days'], ['.grp', 'group header'], ['.cal', 'sidebar row'],
    ['.side .foot', 'sidebar footer'], ['.right .srch', 'search'], ['.right .lab, .right .lab2, .right .card .lab', 'right column label'], ['.right .card.lead, .right .lead', 'right column lead'],
    ['.right .tcol, .right .tm', 'right column time'], ['.right', 'right column'], ['.side', 'sidebar'], ['.pop, .modal', 'menu / dialog'], ['.toast', 'toast']];
  const placeOf = el => { for (const [sel, n] of PLACES) if (el.closest(sel)) return n; return 'other'; };
  const hex = c => { const m = c.match(/[\d.]+/g); if (!m) return c; const [r, g, b] = m.map(Number); return '#' + [r, g, b].map(x => Math.round(x).toString(16).padStart(2, '0')).join('').toUpperCase(); };
  function scan() {
    const d = desk(); if (!d) return null;
    const sizes = new Map(), weights = new Map(), colours = new Map(), tokens = new Map();
    for (const el of d.querySelectorAll('*')) {
      if (el.closest('#dguides, #dcount, #dsys, [data-os]')) continue;
      const own = [...el.childNodes].some(x => x.nodeType === 3 && x.textContent.trim()) || (el.matches('input, textarea') && (el.value || el.placeholder));
      if (!own) continue;
      const r = el.getBoundingClientRect(); if (!r.width || !r.height) continue;
      const dr = d.getBoundingClientRect(); if (r.right < dr.left || r.left > dr.right || r.bottom < dr.top || r.top > dr.bottom) continue;
      const cs = getComputedStyle(el); if (cs.visibility === 'hidden' || +cs.opacity === 0) continue;
      const f = parseFloat(cs.fontSize), w = cs.fontWeight, c = hex(cs.color), p = placeOf(el), lh = cs.lineHeight === 'normal' ? Math.round(f * 1.2) : parseFloat(cs.lineHeight);
      const add = (m, k) => { const o = m.get(k) || { n: 0, at: new Set() }; o.n++; o.at.add(p); m.set(k, o); };
      add(sizes, f); add(weights, w); add(colours, c); add(tokens, `${f}|${lh}|${w}|${c}`);
    }
    return { sizes, weights, colours, tokens };
  }
  const list = (m, fmt, sort) => [...m.entries()].sort(sort).map(([k, o]) => `<tr><td>${fmt(k)}</td><td>×${o.n}</td><td>${[...o.at].slice(0, 6).join(', ')}${o.at.size > 6 ? ' …' : ''}</td></tr>`).join('');
  function counter() {
    const d = desk(); if (!d) return; d.querySelector('#dcount')?.remove(); if (V.cnt !== '1') return;
    const s = scan(); window.__count = { sizes: s.sizes.size, weights: s.weights.size, colours: s.colours.size, list: [...s.sizes.keys()].sort((a, b) => b - a) };
    d.insertAdjacentHTML('beforeend', `<div id="dcount"><div class="big">In view: <b>${s.sizes.size}</b> text sizes · <b>${s.weights.size}</b> weights · <b>${s.colours.size}</b> text colours <span style="color:#888">(X hides)</span></div>` +
      `<table>${list(s.sizes, k => k + ' px', (a, b) => b[0] - a[0])}</table><table>${list(s.weights, k => k, (a, b) => a[0] - b[0])}</table>` +
      `<table>${list(s.colours, k => `<i class="sw" style="background:${k}"></i>${k}`, (a, b) => b[1].n - a[1].n)}</table></div>`);
  }
  // alignment guides (G), as designr's template: green = a left edge 3+ items share, blue = a shared right edge, red = 1–5 px off a line
  function guides() {
    const d = desk(); if (!d) return; d.querySelector('#dguides')?.remove(); window.__guides = null; if (V.gd !== '1') return;
    const k = d.getBoundingClientRect().width / d.offsetWidth, dr = d.getBoundingClientRect(), X = x => (x - dr.left) / k, Y = y => (y - dr.top) / k;
    let out = '', misses = [], cols = 0;
    d.querySelectorAll('[data-area]').forEach(area => {
      if (area.classList.contains('gone')) return;
      const ar = area.getBoundingClientRect(), L = [], R = [];
      const vis = r => r.width > 0 && r.height > 0 && r.bottom > ar.top && r.top < ar.bottom && r.right > ar.left && r.left < ar.right;
      const push = (arr, x, r, what) => arr.push({ x: Math.round(X(x) * 2) / 2, t: Y(r.top), b: Y(r.bottom), l: X(r.left), w: r.width / k, what });
      const tw = document.createTreeWalker(area, NodeFilter.SHOW_TEXT, { acceptNode: x => x.textContent.trim() ? 1 : 2 });
      for (let t; (t = tw.nextNode());) {
        const el = t.parentElement; if (!el || el.closest('[data-centred], .btn, .seg, .segc, .mm .d, .mm .wd, .mm .wkn, .gut, .dh .c, .kbd, .kbdc')) continue;
        const cs = getComputedStyle(el); if (cs.textAlign === 'center' || cs.textAlign === 'right' || cs.marginLeft === 'auto') continue;
        const rg = document.createRange(); rg.selectNodeContents(t); const r = rg.getClientRects()[0];
        if (r && vis(r)) push(L, r.left, r, t.textContent.trim().slice(0, 24));
      }
      const group = arr => { const g = []; arr.sort((a, b) => a.x - b.x).forEach(e => { const last = g[g.length - 1]; if (last && e.x - last.x0 <= .75) last.items.push(e); else g.push({ x0: e.x, items: [e] }); }); g.forEach(c => { c.x = c.items.reduce((a, b) => a + b.x, 0) / c.items.length; }); return g; };
      const lines = (arr, cls) => {
        const g = group(arr), strong = g.filter(c => c.items.length >= 3);
        strong.forEach(c => { cols++; out += `<div class="gv ${cls}" style="left:${c.x}px;top:${Y(ar.top)}px;height:${ar.height / k}px"><span>${Math.round(c.x - X(ar.left))}</span></div>`; });
        g.filter(c => c.items.length < 3).forEach(c => {
          const near = strong.find(s2 => Math.abs(s2.x - c.x) >= 1 && Math.abs(s2.x - c.x) <= 5); if (!near) return;
          c.items.forEach(it => { const dd = (it.x - near.x).toFixed(1); misses.push({ area: area.dataset.area, what: it.what, x: it.x, off: +dd }); out += `<div class="bx" style="left:${it.l}px;top:${it.t}px;width:${Math.max(it.w, 2)}px;height:${it.b - it.t}px"><span>${dd > 0 ? '+' : ''}${dd}</span></div>`; });
        });
      };
      lines(L, ''); lines(R, 'r');
    });
    window.__guides = misses;
    d.insertAdjacentHTML('beforeend', `<div id="dguides">${out}<div class="legend"><b>Alignment guides</b> · G to hide<br>green: shared left edge (3+) · red: ${misses.length} item${misses.length === 1 ? '' : 's'} 1 to 5 px off a line · ${cols} lines</div></div>`);
  }
  // the "Design system" sheet: role sizes, every text token in view (size / line height / weight / colour, where used), colour tokens
  function sheet() {
    const d = desk(); if (!d) return; d.querySelector('#dsys')?.remove(); if (V.ds !== '1') return;
    const L = PK(), t = L.T && L.T.dark, s = scan(), v = L.v || (() => '');
    const roles = [['Title', 'rD', 'month title'], ['Heading', 'rH', 'day header date, mini-month title'], ['Body', 'rB', 'event title, sidebar rows, right column, base text'],
      ['Label', 'rL', 'sidebar group headers'], ['Secondary', 'rM', 'event time, hour labels, mini-month days']];
    const pl = { rD: 'fT', rH: 'fd', rB: 'ft', rL: 'fg', rM: 'fm' };
    const toks = [...s.tokens.entries()].map(([k, o]) => { const [f, lh, w, c] = k.split('|'); return { f: +f, lh, w, c, o }; }).sort((a, b) => b.f - a.f || a.w - b.w);
    const tp = L.T && L.T.paper, EV = h => [L.ev(h, 'dark'), L.ev(h, 'paper')];
    const col = t && tp ? [['bg', 'bg', 'app canvas, grid'], ['rail', 'rail', 'sidebar, right column'], ['surface', 'surface', 'cards, all-day lane'], ['raised', 'raised', 'fields, buttons, menus'],
      ['hover', 'hover', 'row hover'], ['selected', 'selected', 'selected row'], ['fg1', 'fg1', 'titles, values, event titles'], ['fg2', 'fg2', 'times, secondary rows'], ['fg3', 'fg3', 'labels, hints, group headers'],
      ['hourc', 'hourc', 'hour labels'], ['live', 'live', 'now line, countdown'], ['today tint', 'todayTint', 'today column'], ['hour line', 'grid', 'hour line'],
      ['all-day edge', 'hairStrong', 'line under the all-day lane'], ['pane edge', 'hair', 'pane edges'], ['day divider', 'gridV', 'between days'], ['focus', 'focus', 'focus ring']].map(([n, k, u]) => [n, t[k], tp[k], u]) : [];
    const sw = h => h && h !== 'transparent' ? `<i class="sw" style="background:${h}"></i>${h}` : '—';
    const evs = [['Personal', '#5B8DEF'], ['Team', '#E9B949'], ['Family', '#E5674F'], ['Holidays', '#3FA36B'], ['Work', '#8F86E8']];
    const evRows = evs.map(([n, h]) => { const [a, b] = EV(h); return `<tr><td>${n}</td>${[a, b].map((e, j) => `<td class="evc ${j ? 'p' : 'd'}"><span style="display:inline-block;padding:2px 6px 2px 8px;border-radius:4px;background:${e.fill};color:${e.title};box-shadow:inset 3px 0 0 ${e.bar === 'transparent' ? e.fill : e.bar};font-size:12px">Title <span style="color:${e.meta}">09:30</span></span> <span style="display:inline-block;padding:2px 6px 2px 8px;border-radius:4px;background:${e.fillPast};color:${e.titlePast};font-size:12px">Past <span style="color:${e.metaPast}">08:00</span></span></td>`).join('')}</tr>`; }).join('');
    const ba = V.ba === 'b' ? 'before' : 'after';
    d.insertAdjacentHTML('beforeend', `<div id="dsys"><button class="x" data-dsx="1">Close</button><h2>Design system · locked 2026-11-20</h2>` +
      `<div class="sub">Live from the app as it is drawn now. ${ba === 'after' ? 'After: the locked design (R10 · three sizes 15 / 12 / 11, weights 400 / 500 / 600).' : 'Before: your round-g link (8 sizes).'} B switches. Dark / Paper: the switch at the top of the rail.</div>` +
      `<div class="ba"><button class="${ba === 'before' ? 'on' : ''}" data-dsba="b">Before · round g link</button><button class="${ba === 'after' ? 'on' : ''}" data-dsba="a">After · locked</button></div>` +
      `<div class="cols"><div><h3>Roles</h3><table><tr><th>Role</th><th>Size</th><th>Used for</th></tr>${roles.map(([n, id, at]) => `<tr><td>${n}</td><td class="mono">${v(pl[id])} px</td><td>${at}</td></tr>`).join('')}</table>` +
      `<h3 style="margin-top:20px">Counter</h3><div>${s.sizes.size} sizes (${[...s.sizes.keys()].sort((a, b) => b - a).join(', ')}) · ${s.weights.size} weights (${[...s.weights.keys()].sort().join(', ')}) · ${s.colours.size} text colours</div>` +
      `<h3 style="margin-top:20px">Event recipe (bar + tint; title, time · past)</h3><table><tr><th>Calendar</th><th>Dark</th><th>Paper</th></tr>${evRows}</table></div>` +
      `<div><h3>Colour tokens</h3><table><tr><th>Token</th><th>Dark</th><th>Paper</th><th>Use</th></tr>${col.map(([n, d, p, u]) => `<tr><td>${n}</td><td class="mono">${sw(d)}</td><td class="mono">${sw(p)}</td><td>${u}</td></tr>`).join('')}</table></div>` +
      `<div><h3>Text tokens in view</h3><table><tr><th>Sample</th><th>Size / line</th><th>Weight</th><th>Colour</th><th>Where</th></tr>${toks.map(x => `<tr><td style="font-size:${x.f}px;font-weight:${x.w};color:${x.c};line-height:1.2">Aa 09:30</td><td class="mono">${x.f} / ${x.lh}</td><td class="mono">${x.w}</td><td class="mono"><i class="sw" style="background:${x.c}"></i>${x.c}</td><td>${[...x.o.at].slice(0, 4).join(', ')}</td></tr>`).join('')}</table></div></div></div>`);
  }
  function after() { counter(); guides(); sheet(); }
  const set = (k, v) => { V[k] = v; window.saveHash && saveHash(); render(); window.rdRerail && rdRerail(); };
  document.addEventListener('keydown', ev => {
    const t = ev.target; if (ev.metaKey || ev.ctrlKey || ev.altKey || (t.matches && t.matches('input, textarea, select'))) return;
    const k = ev.key.toLowerCase();
    if (k === 'x') { set('cnt', V.cnt === '1' ? '0' : '1'); ev.stopImmediatePropagation(); }
    else if (k === 'g') { set('gd', V.gd === '1' ? '0' : '1'); ev.stopImmediatePropagation(); }
    else if (k === 'b') { set('ba', V.ba === 'a' ? 'b' : 'a'); ev.stopImmediatePropagation(); }
  }, true);
  document.addEventListener('click', ev => {
    const x = ev.target.closest('[data-dsx], [data-dsba]'); if (!x) return; ev.stopPropagation();
    if (x.dataset.dsx) set('ds', '0'); else set('ba', x.dataset.dsba);
  }, true);
  return { after, scan, set };
})();
window.dsysAfter = DSYS.after;
