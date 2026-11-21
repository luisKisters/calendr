// Calendr v10 · the Designer tab in the picker rail (round 2026-11-20 c). Sections with headings, one row per control: label, current value,
// "changed from preset" dot, lock (Randomize skips locked controls), a one-line hint, and the widget that fits the control:
//   swatch  colour chips drawn with the real tokens (canvas = sidebar | canvas | surface stripes of the current mode + the other mode's corner)
//   preview a tiny mock event / chip / date / grid drawn with the real tokens of that option
//   seg     segmented buttons · step  − value + with a row of steps
// Unreadable options stay visible, struck through, with the reason as tooltip. A focused row steps with the arrow keys.
'use strict';
const DZUI = (() => {
  const D = DESIGNER, OPEN = { theme: true, events: true, text: true, layout: false, grid: false, states: false }, ADV = {};
  const SAMPLE = ['#5B8DEF', '#F2884B'], PALROW = ['#5B8DEF', '#E5674F', '#3FA36B', '#E9B949', '#8F86E8', '#C04BD8', '#5DADE2'];
  const curCode = () => V.look === 'D' ? D.normal(V.d) : (D.PRESETS.find(p => p.look === V.look) || D.PRESETS[1]).eq;
  const baseOf = () => { const p = D.PRESETS.find(x => x.id === V.dzb) || D.PRESETS.find(x => x.look === V.look) || D.PRESETS[1]; return p; };
  const baseCode = () => { const p = baseOf(); return p.d || p.eq; };
  const locks = () => new Set((V.dzl || '').split('.').filter(Boolean));
  const variant = (o, k, i) => D.encode({ ...o, [k]: i });
  const esc2 = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');

  // ---------------------------------------------------------------- previews (real tokens of that option, current mode)
  function mini(L, th, opts = {}) {
    const o = L.o, t = L.T[th], hexes = opts.hexes || SAMPLE;
    const blocks = hexes.map(h0 => {
      const N = L.check(th), e = opts.chip && N.ad ? N.ad(h0) : N.ev(h0), past = opts.past;
      const fill = past ? e.fillPast : e.fill, tc = past ? e.titlePast : e.title, mc = past ? e.metaPast : e.meta;
      const sh = [];
      if (o.fill === 0 || o.edge === 1) sh.push(`inset 0 0 0 1px ${e.edge2}`);
      if (o.fill === 9) sh.push(`inset 0 0 0 1.5px ${e.edge2}`);
      if (o.edge === 2) sh.push(`0 0 0 1px ${t.bg}`);
      if (o.edge === 3) sh.push(th === 'dark' ? '0 1px 2px rgba(0,0,0,.5)' : '0 0 0 1px rgba(20,20,30,.07), 0 1px 3px rgba(20,20,30,.12)');
      const bar = o.bar === 0 ? '' : o.bar === 5 ? `<i class="dot" style="background:${past ? e.barPast : e.bar}"></i>` : `<i class="bar b${o.bar}" style="background:${past ? e.barPast : e.bar}"></i>`;
      let bgi = o.fill === 10 && !past ? `linear-gradient(90deg, ${e.fill}, ${e.fill2})` : 'none';
      if (opts.maybe === 0) bgi = `repeating-linear-gradient(135deg, ${e.fillH} 0 4px, transparent 4px 8px)`;
      const fa = opts.maybe === 3 ? { fill: e.fillPast, tc: e.titlePast, mc: e.metaPast } : { fill, tc, mc };
      const out = opts.maybe === 1 ? `outline:1px dashed ${e.edge};outline-offset:-1px;` : '';
      const sbar = opts.maybe === 2 ? `<i class="bar b2" style="background:repeating-linear-gradient(180deg, ${e.bar} 0 3px, transparent 3px 5px)"></i>` : bar;
      if (opts.chip) {
        const ad = o.allday, chipBg = ad === 2 || ad === 5 ? 'transparent' : fa.fill;
        const mark = ad === 2 ? `<i class="dot" style="background:${L.calDot(h0)}"></i>` : ad === 5 ? `<i class="bar b4" style="background:${L.calDot(h0)}"></i>` : ad === 3 ? '' : bar;
        return `<span class="mchip" style="background:${chipBg};color:${fa.tc};border-radius:${Math.min(+D.CONTROLS[D.KI.radius].o[o.radius], 6)}px;${ad === 3 ? `box-shadow:inset 0 0 0 1px ${e.edge2};` : ''}font-weight:${D.CONTROLS[D.KI.weight].o[o.weight]}">${mark}Aa</span>`;
      }
      return `<span class="mev" style="background-color:${fa.fill};background-image:${bgi};color:${fa.tc};border-radius:${D.CONTROLS[D.KI.radius].o[o.radius]}px;box-shadow:${sh.join(',') || 'none'};${out}">${sbar}<b style="font-weight:${D.CONTROLS[D.KI.weight].o[o.weight]}">Aa</b><i class="tm" style="color:${fa.mc}">9:00</i></span>`;
    }).join('');
    return `<span class="mcan" style="background:${t.bg}">${blocks}</span>`;
  }
  function swatch(c, L, th, i) {
    const t = L.T[th], o2 = th === 'dark' ? 'paper' : 'dark', u = L.T[o2];
    if (c.k === 'canvas') { const half = x => `<span class="h"><i style="background:${x.rail}"></i><b style="background:${x.bg};color:${x.fg1}">Aa<em style="color:${x.fg3}">9</em></b></span>`; return `<span class="sw can">${half(t)}${half(u)}</span>`; }
    if (c.k === 'palette') return `<span class="sw pal" style="background:${t.bg}">${PALROW.map(h => `<i style="background:${L.calDot(h)}"></i>`).join('')}</span>`;
    if (c.k === 'accent') return `<span class="sw acc" style="background:${t.bg}"><i style="background:${t.accent};color:${t.onAccent}">4</i><em style="background:${u.accent}"></em></span>`;
    if (c.k === 'sideBg' || c.k === 'rightBg' || c.k === 'headBg') return `<span class="sw wn"><span class="p" style="background:${t.rail};flex:.8"></span><span class="p" style="background:${t.bg};flex:2;box-shadow:inset 1px 0 0 ${t.hair}, inset -1px 0 0 ${t.hair}"><span class="hd" style="background:${t.hdrbg};color:${t.fg1}">Nov</span></span><span class="p" style="background:${t.rcol};flex:1"></span></span>`;
    return '';
  }
  function preview(c, L, th, i) {
    const t = L.T[th], o = L.o;
    switch (c.k) {
      case 'fill': case 'bar': case 'edge': case 'title': case 'tcol': case 'radius': return mini(L, th);
      case 'past': return mini(L, th, { past: true });
      case 'maybe': return mini(L, th, { maybe: i, hexes: [SAMPLE[0]] });
      case 'allday': return `<span class="mcan" style="background:${t.bg}">${[SAMPLE[0], SAMPLE[1]].map(h => mini(L, th, { chip: true, hexes: [h] }).replace(/^<span class="mcan"[^>]*>|<\/span>$/g, '')).join('')}</span>`;
      case 'today': {
        const st = [`background:${t.accent};color:${t.onAccent};border-radius:999px`, `background:${t.live};color:${t.onLive};border-radius:4px`, `background:${t.live};color:${t.onLive};border-radius:999px`,
          `color:${t.fg1};box-shadow:inset 0 0 0 1.5px ${t.accent};border-radius:999px`, `color:${t.fg1};font-weight:700`, `background:${t.accent};color:${t.onAccent};border-radius:4px`,
          `color:${t.fg1};font-weight:700;box-shadow:inset 0 -2px 0 ${t.accent}`, `color:${t.fg1};font-weight:700`][i];
        return `<span class="mcan day" style="background:${t.bg};color:${t.fg3}">Wed <b style="${st}">4</b>${i === 7 ? `<i class="rdot" style="background:${t.live}"></i>` : ''}</span>`;
      }
      case 'head': return `<span class="mcan day ${i ? 'stk' : ''}" style="background:${t.bg};color:${t.fg3}">${i ? 'WED' : 'Wed'} <b style="color:${t.fg1}">4</b></span>`;
      case 'grid': return `<span class="mcan grid" style="background:${t.bg}">${[0, 1, 2].map(() => `<i style="border-top-color:${t.grid}"></i><i class="h ${i === 6 ? 'dash' : ''}" style="border-top-color:${t.gridHalf}"></i>`).join('')}</span>`;
      case 'hourc': return `<span class="mcan hl" style="background:${t.bg};color:${t.hourc}">09:00</span>`;
      default: return '';
    }
  }
  // ---------------------------------------------------------------- one control row
  function row(c, o, code, th, base, lk) {
    const val = o[c.k], changed = base[c.k] !== val, locked = lk.has(c.k);
    const allowed = i => c.k !== 'title' || D.titleAllowed(o.fill, i, th);
    const reason = i => c.k === 'title' && !D.titleAllowed(o.fill, i, th) ? `${c.o[i]}: not readable with this fill (Paper falls back to Auto)` : c.k === 'title' && !D.titleAllowed(o.fill, i, th === 'dark' ? 'paper' : 'dark') ? `${c.o[i]}: in Paper not readable with this fill (falls back to Auto)` : c.o[i];
    let w = '';
    if (c.w === 'step') {
      const n = c.o.length;
      w = `<div class="dzstep"><button class="sb" data-r="dz" data-k="${c.k}" data-v="${Math.max(0, val - 1)}" ${val === 0 ? 'disabled' : ''} title="Smaller">−</button>` +
        `<div class="ticks">${c.o.map((lab, i) => `<button class="${i === val ? 'on' : ''} ${i <= val ? 'lit' : ''}" data-r="dz" data-k="${c.k}" data-v="${i}" title="${esc2(lab)}"><i></i></button>`).join('')}</div>` +
        `<button class="sb" data-r="dz" data-k="${c.k}" data-v="${Math.min(n - 1, val + 1)}" ${val === n - 1 ? 'disabled' : ''} title="Larger">+</button><span class="sv">${esc2(c.o[val])}</span></div>`;
    } else if (c.w === 'seg') {
      w = `<div class="dzseg">${c.o.map((lab, i) => `<button class="${i === val ? 'on' : ''}" data-r="dz" data-k="${c.k}" data-v="${i}" title="${esc2(lab)}" ${c.k === 'font' ? `style="font-family:${["'Inter'", '-apple-system', "'Geist'", "'Instrument Sans'"][i]}"` : ''}>${esc2(lab)}</button>`).join('')}</div>`;
    } else {
      w = `<div class="dzgrid ${c.w}">${c.o.map((lab, i) => {
        const L = D.look(variant(o, c.k, i)), dis = !allowed(i), part = !dis && c.k === 'title' && !D.titleAllowed(o.fill, i, th === 'dark' ? 'paper' : 'dark');
        return `<button class="dzopt ${i === val ? 'on' : ''} ${dis ? 'dis' : ''} ${part ? 'part' : ''}" data-r="dz" data-k="${c.k}" data-v="${i}" title="${esc2(reason(i))}" ${dis ? 'aria-disabled="true"' : ''}>${c.w === 'swatch' ? swatch(c, L, th, i) : preview(c, L, th, i)}<span class="ol">${esc2(lab)}</span></button>`;
      }).join('')}</div>`;
    }
    return `<div class="dzrow" tabindex="0" data-dzk="${c.k}" title="${esc2(c.l)}: arrow keys step through the options">
      <div class="dzh"><span class="dzl">${esc2(c.l)}${c.c ? '<i class="cdot" title="Changes colours: contrast.mjs crosses it with every other colour control"></i>' : ''}</span><span class="dzv">${esc2(c.o[val])}</span>${changed ? '<i class="chg" title="Changed from the preset"></i>' : ''}
      <button class="lk ${locked ? 'on' : ''}" data-r="dzlock" data-k="${c.k}" title="${locked ? 'Locked: Randomize keeps it' : 'Lock for Randomize'}">${locked ? '🔒︎' : '🔓︎'}</button></div>
      <div class="dzhint">${esc2(c.h)}</div>${w}</div>`;
  }
  // ---------------------------------------------------------------- the tab
  function body(liveCheck) {
    const code = curCode(), o = D.decode(code), th = V.appear, base = D.decode(baseCode()), lk = locks(), all = V.dzall === '1';
    const cur = p => p.look ? V.look === p.look : V.look === 'D' && D.normal(V.d) === p.d;
    const L = D.look(code), chk = liveCheck(L), nChanged = D.CONTROLS.filter(c => base[c.k] !== o[c.k]).length;
    let h = `<div class="rel"><div class="nm">Presets</div><div class="why">L0–L4 are the v9 looks as built; the others are made from the controls. Change anything: the dot marks what differs from the preset.</div>
      <div class="dzp">${D.PRESETS.map(p => `<button class="rbtn ${cur(p) ? 'key' : ''}" data-r="dzpreset" data-k="${p.id}">${esc2(p.l)}</button>`).join('')}</div>
      <div class="rscenes"><button class="rbtn" data-r="dzreset" ${nChanged ? '' : 'disabled'}>Reset to ${esc2(baseOf().l)}${nChanged ? ` (${nChanged})` : ''}</button><button class="rbtn" data-r="dzrand">Randomize${lk.size ? ` (${lk.size} locked)` : ''}</button><button class="rbtn" data-r="copy">Copy link</button><button class="rbtn" data-r="dzall">${all ? 'Collapse' : 'Expand'} all</button></div></div>`;
    h += `<div class="dzok ${chk.bad ? 'bad' : ''}"><b>${chk.bad ? `${chk.bad} pairs below the floors` : 'Readable'}</b> · ${chk.n} pairs checked live (Dark + Paper, every calendar colour, every state${L.o.allday ? ', all-day chips' : ''}); tightest: ${esc2(chk.worst.what)} ${chk.worst.R.toFixed(2)}:1, Lc ${chk.worst.a.toFixed(0)}. Every combination of every colour control is proven by <code>contrast.mjs</code>.</div>`;
    for (const [s, title] of D.SECTIONS) {
      const cs = D.CONTROLS.filter(c => c.s === s), main = cs.filter(c => !c.a), adv = cs.filter(c => c.a), open = all || OPEN[s], advOpen = all || ADV[s];
      const ch = cs.filter(c => base[c.k] !== o[c.k]).length;
      h += `<div class="dzsec ${open ? 'open' : ''}"><button class="dzsh" data-r="dzsec" data-k="${s}"><span class="cv">▸</span>${title}<span class="cnt">${cs.length} controls${ch ? ` · <b>${ch} changed</b>` : ''}</span></button>`;
      if (open) {
        h += main.map(c => row(c, o, code, th, base, lk)).join('');
        if (adv.length) h += `<button class="dzadv ${advOpen ? 'open' : ''}" data-r="dzadv" data-k="${s}"><span class="cv">▸</span>Advanced · ${adv.length}${adv.some(c => base[c.k] !== o[c.k]) ? ' <i class="chg"></i>' : ''}</button>` + (advOpen ? `<div class="dzadvb">${adv.map(c => row(c, o, code, th, base, lk)).join('')}</div>` : '');
      }
      h += '</div>';
    }
    h += `<div class="rnote">Hash: <code>look=D&amp;d=${esc2(code)}</code>, one base-36 character per control in this order (round-b links with 24 digits still open). <i class="cdot"></i> = changes colours.</div>`;
    return h;
  }
  // ---------------------------------------------------------------- actions
  function set(k, v) {
    if (V.look !== 'D') { V.dzb = (D.PRESETS.find(p => p.look === V.look) || D.PRESETS[1]).id; V.d = curCode(); V.look = 'D'; }
    const o = D.decode(V.d); o[k] = v; V.d = D.encode(o);
    if (k === 'first' && o.first) A.gridScroll = (+D.CONTROLS[D.KI.first].o[o.first]) * D.look(V.d).H;
  }
  function act(r, b) {
    const k = b.dataset.k;
    if (r === 'dzpreset') { const p = D.PRESETS.find(x => x.id === k); V.dzb = p.id; if (p.look) V.look = p.look; else { V.look = 'D'; V.d = p.d; } return true; }
    if (r === 'dz') { if (b.getAttribute('aria-disabled') === 'true' || b.disabled) return false; set(k, +b.dataset.v); return true; }
    if (r === 'dzlock') { const l = locks(); l.has(k) ? l.delete(k) : l.add(k); V.dzl = [...l].join('.'); return true; }
    if (r === 'dzsec') { OPEN[k] = !OPEN[k]; if (V.dzall === '1') { V.dzall = '0'; D.SECTIONS.forEach(([s]) => { OPEN[s] = s !== k; }); } return 'rail'; }
    if (r === 'dzadv') { ADV[k] = !ADV[k]; if (V.dzall === '1') V.dzall = '0'; return 'rail'; }
    if (r === 'dzall') { V.dzall = V.dzall === '1' ? '0' : '1'; return 'rail'; }
    if (r === 'dzreset') { const p = baseOf(); if (p.look) V.look = p.look; else { V.look = 'D'; V.d = p.d; } return true; }
    if (r === 'dzrand') {
      const l = locks(), o = D.decode(curCode());
      D.CONTROLS.forEach(c => { if (l.has(c.k)) return; o[c.k] = c.a ? (Math.random() < .7 ? c.def || 0 : Math.floor(Math.random() * c.o.length)) : Math.floor(Math.random() * c.o.length); });
      V.look = 'D'; V.d = D.encode(o); return true;
    }
    return false;
  }
  // arrow keys on a focused row: the next readable option
  function key(ev) {
    const rw = ev.target.closest && ev.target.closest('.dzrow'); if (!rw) return false;
    const dir = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[ev.key]; if (!dir) return false;
    const k = rw.dataset.dzk, c = D.CONTROLS[D.KI[k]], o = D.decode(curCode()), th = V.appear;
    let i = o[k];
    do { i += dir; } while (i >= 0 && i < c.o.length && k === 'title' && !D.titleAllowed(o.fill, i, th));
    if (i < 0 || i >= c.o.length) return true;
    set(k, i); return k;
  }
  return { body, act, key, curCode };
})();
