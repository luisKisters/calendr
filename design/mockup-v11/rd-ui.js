// Calendr v11 · the Readability tab in the picker rail (round 2026-11-20 d). Dark only.
// Top: the presets (the iterations), Copy link, Reset, and the live result of the current design (every Dark pair, all calendar colours).
// Then six groups of levers. Each lever: its name, the chosen option, one line of research (READABILITY-BRIEF.md section), and its
// options as tiles: a preview drawn with that option's real tokens, the live WCAG ratio and APCA Lc of the tightest affected pair,
// and a pass / near / fail badge against that pair's floor. An option that would break any floor anywhere is disabled, with the reason.
'use strict';
const RDUI = (() => {
  const R = READ;
  const esc2 = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
  const cur = () => ({ ...R.decode(V.r), K: R.decodeK(V.k) });
  // round f: "default" = the value of the preset the design started from (V.rp); a reset brings one option back to it
  const baseP = () => R.PRESETS.find(p => p.id === V.rp) || R.PRESETS.find(p => p.id === 'R10') || R.PRESETS[0];
  const baseK = () => R.decodeK(baseP().k);
  const RST = (r, k, tip) => `<button class="rst" data-r="${r}" data-k="${k}" title="${esc2(tip)}" aria-label="Reset to default">↺</button>`;
  const sChanged = (id, K, pK) => (K[id] != null ? K[id] : null) !== (pK[id] != null ? pK[id] : null);
  const TAG = { R1: 'graphite · tint · 3 greys', R2: 'true black · stepped panes · bar', R3: 'dim grey · muted solid', R4: 'small type · darker sidebars',
    R5: 'fg1 + one grey', R6: 'strong hours · dotted halves', R7: 'neutral cards · hue bar', R8: 'today tint · elapsed · next ring', R9: 'hue outlines · Geist', R10p: 'R10 before round g', R10g: 'round g link · 8 sizes', R10: 'LOCKED · navy fill · 15/12/11', R11: 'R10 + sliders · muted navy' };
  const SHORT = { evTitle: 'title', evMeta: 'time', evSelMeta: 'sel. time', evPastTitle: 'past title', evPastMeta: 'past time', evDecl: 'declined', fg1: 'fg1', fg1soft: 'fg1', fg2: 'fg2', fg2soft: 'fg2', fg3: 'fg3', fg3soft: 'fg3',
    accent: 'date', live: 'live', nontext: 'ring', structure: 'line', decor: 'line', status: 'status' };
  // which pairs a lever affects (badge) and which one it shows (the tightest of them)
  const AFF = {
    canvas: /^fg[123] on |^live text/, panes: /on (rail|hover on rail)$/, steps: /^fg[123] on /, hourc: /^hour labels/,
    recipe: /^(event |title on|time on|selected|needs-reply)/, chroma: /^(event |title on|time on|selected|needs-reply)/, evtext: /^(event |title on|time on|selected)/,
    allday: /^all-day /, size: /^event title/, weight: /^event title/, font: /^event title/, chrome: /^fg[123] on bg$/,
    hourLine: /^hour line/, minor: /^(half-hour line|day divider|hour line on bg)/, past: /^(past|declined)/,
    today: /^(today date|now pill|fg. on today column|hour line on today)/, now: /^(now line|hour line on elapsed|needs-reply)/, tent: /^(time on hover|title on hover)/,
  };
  const SHOW = { canvas: /^fg1 on bg$/, panes: /^fg3 on rail$/, hourc: /^hour labels/, recipe: /^event (title|time)/, chroma: /^event (title|time)/, evtext: /^event (title|time)/,
    allday: /^all-day event (title|time)/, size: /^event title/, weight: /^event title/, font: /^event title/, chrome: /^fg3 on bg$/, hourLine: /^hour line/, minor: /^(half-hour line|day divider)/,
    past: /^past (title|time)/, today: /^(today date|now pill)/, now: /^(hour line on elapsed|now line vs elapsed|needs-reply)/, tent: /^time on hover/ };
  const groupOf = k => R.EVENT_K.includes(k) && !R.CHROME_K.includes(k) ? 'events' : R.CHROME_K.includes(k) && !R.EVENT_K.includes(k) ? 'chrome' : 'all';

  function rate(s, k) {
    const g = ['size', 'weight', 'font', 'tent'].includes(k) ? 'events' : groupOf(k);
    const P = R.pairs(s, R.HUES(), g).map(([what, fg, bg, key]) => ({ what, fg, bg, key, ...R.grade(fg, bg, key) }));
    let aff = P.filter(p => AFF[k].test(p.what)); if (k === 'allday' && !s.allday) aff = P.filter(p => /^event (title|time)/.test(p.what));
    let show = aff.filter(p => SHOW[k] && SHOW[k].test(p.what)); if (!show.length) show = k === 'allday' ? aff : aff.length ? aff : [];
    if (k === 'minor' && !show.length) show = P.filter(p => /^hour line on bg/.test(p.what));
    if (k === 'now' && !show.length) show = P.filter(p => /^now line vs bg/.test(p.what));
    const worst = a => a.slice().sort((x, y) => x.m - y.m)[0];
    const w = worst(aff.length ? aff : show), sh = worst(show) || w;
    const badge = !w ? '' : !aff.every(p => p.ok) ? 'fail' : w.m < 1.03 ? 'near' : 'pass';
    return { sh, w, badge, aff };
  }
  const floorTxt = k => { const [r, l, x] = R.FLOORS[k]; return `≥ ${r}:1${l ? ` · Lc ≥ ${l}` : ''}${x != null ? ` · Lc ≤ ${x}` : ''}`; };
  const num = p => p ? `${p.r.toFixed(p.r < 2 ? 2 : 1)}:1 Lc ${p.a < 1 ? '<8' : p.a.toFixed(0)}` : '';
  const reason = v => { const f = v.fail; if (!f) return ''; const [r, l, x] = R.FLOORS[f.k];
    const why = x != null && f.a > x ? `Lc ${f.a.toFixed(1)} > ${x} (halation cap)` : f.r < r ? `${f.r.toFixed(2)}:1 < ${r}:1` : `Lc ${f.a.toFixed(1)} < ${l}`;
    return `${f.what.replace(/ · #\w+$/, '')}: ${why}`; };

  // ---------------------------------------------------------------- previews (real tokens of the option, Dark)
  const HX = { b: '#5B8DEF', y: '#E9B949', r: '#E5674F', g: '#3FA36B', v: '#8F86E8' };
  function evBox(e, s, x, y, w, h, title, time, st = {}) {
    const past = st.past, fill = past ? e.fillPast : st.dec ? e.fillDec : e.fill, tc = past ? e.titlePast : st.dec ? e.titleDec : e.title, mc = past ? e.metaPast : e.meta;
    const sh = []; if (s.recipe === 3) sh.push(`inset 0 0 0 1px ${past ? e.edge2Past : e.edge2}`); if (s.recipe === 4 && !past) sh.push(`inset 0 0 0 1px ${e.edge2}`);
    let bgi = 'none', out = '';
    if (st.maybe) { if (s.tent === 0) out = `outline:1px dashed ${e.edge};outline-offset:-1px;`; if (s.tent === 1) bgi = `repeating-linear-gradient(135deg, ${e.fillH} 0 4px, transparent 4px 8px)`; }
    if (st.next) out = `outline:1px solid ${e.edge};outline-offset:1px;`;
    const fa = st.maybe && s.tent === 3 ? { fill: e.fillPast, tc: e.titlePast, mc: e.metaPast } : { fill, tc, mc };
    const bar = st.maybe && s.tent === 2 ? `<i class="p-br" style="background:repeating-linear-gradient(180deg, ${e.bar === 'transparent' ? e.mark : e.bar} 0 3px, transparent 3px 5px)"></i>`
      : e.bar !== 'transparent' ? `<i class="p-br" style="background:${past ? e.barPast : e.bar}${s.recipe === 4 ? ';left:0;top:0;bottom:0;width:2.5px;border-radius:0' : ''}"></i>` : '';
    const strike = st.dec && s.tent !== 3 ? 'text-decoration:line-through;' : st.dec ? 'text-decoration:line-through;' : '';
    return `<span class="p-ev" style="left:${x}%;top:${y}px;width:${w}%;height:${h}px;background-color:${fa.fill};background-image:${bgi};color:${fa.tc};box-shadow:${sh.join(',') || 'none'};${out}${st.fs ? `font-size:${st.fs}px;line-height:${st.fs + 3}px;` : ''}${st.font ? `font-family:${st.font};` : ''}">${bar}<b style="font-weight:${st.w || R.WEIGHT[s.weight]};${strike}">${title}</b>${time ? `<i style="color:${fa.mc};${st.fsm ? `font-size:${st.fsm}px;line-height:${st.fsm + 3}px;` : ''}">${time}</i>` : ''}</span>`;
  }
  const FONTS = ["'Inter', -apple-system, system-ui, sans-serif", "-apple-system, 'SF Pro Text', system-ui, sans-serif", "'Geist', -apple-system, system-ui, sans-serif"];
  function preview(k, s) {
    const t = R.tokens(s), E = h => R.recipe(h, s, t), wrap = (inner, extra = '') => `<span class="rpv" style="background:${t.bg};${extra}">${inner}</span>`;
    const lev = R.LEVERS[R.KI[k]];
    switch (lev.p) {
      case 'canvas': case 'panes':
        return wrap(`<span class="p-sd" style="background:${t.rail};box-shadow:inset -1px 0 0 ${t.hair}"></span><span class="p-tx" style="left:6%;top:6px;color:${t.fg3};font-size:9.5px">Cal</span>` +
          `<span class="p-tx" style="left:28%;top:5px;color:${t.fg1};font-weight:500">Standup</span><span class="p-tx" style="left:28%;top:18px;color:${t.fg2}">09:30</span>` +
          `<span class="p-tx" style="left:28%;top:31px;color:${t.fg3};font-size:9.5px">all-day</span><span class="p-ln" style="top:44px;left:22%;border-color:${t.grid}"></span>`);
      case 'steps':
        return wrap(`<span class="p-tx" style="top:3px;color:${t.fg1};font-weight:500">Event title</span><span class="p-tx" style="top:17px;color:${t.fg2}">09:30–10:00</span><span class="p-tx" style="top:31px;color:${t.fg3};font-size:9.5px">Week 47 · label</span>`);
      case 'hour':
        return wrap(`<span class="p-tx" style="top:2px;left:4px;color:${t.hourc};font-size:9.5px">09:00</span><span class="p-ln" style="top:9px;left:34%;border-color:${t.grid}"></span>` +
          `<span class="p-tx" style="top:24px;left:4px;color:${t.hourc};font-size:9.5px">10:00</span><span class="p-ln" style="top:31px;left:34%;border-color:${t.grid}"></span>` +
          `<span class="p-ev" style="left:38%;top:11px;width:58%;height:17px;background:${E(HX.b).fill};color:${E(HX.b).title}"><b>Standup</b></span>`);
      case 'event':
        return wrap(evBox(E(HX.b), s, 3, 3, 46, 40, 'Standup', '09:30') + evBox(E(HX.y), s, 51, 3, 46, 19, 'Lunch', '') + evBox(E(HX.r), s, 51, 24, 46, 19, 'Gym', ''));
      case 'chip': {
        const chipOf = (h, x, w, nm) => { const e = R.chip(h, s, t), mark = s.allday === 1 ? `<i class="p-br" style="left:4px;top:6px;bottom:auto;width:5px;height:5px;border-radius:50%;background:${e.mark}"></i>` : s.allday === 2 ? `<i class="p-br" style="left:1px;background:${e.mark}"></i>` : '';
          return `<span class="p-ev" style="left:${x}%;top:VAR;width:${w}%;height:15px;background:${s.allday ? 'transparent' : e.fill};color:${e.title};padding-left:${s.allday ? 11 : 6}px">${mark}<b>${nm}</b></span>`; };
        return wrap(chipOf(HX.g, 3, 60, 'Holiday').replace('VAR', '6px') + chipOf(HX.v, 30, 67, 'Conference').replace('VAR', '25px') + `<span class="p-ln" style="top:44px;border-color:${t.hairStrong}"></span>`);
      }
      case 'type': case 'font': {
        const [fs, fsm] = R.SIZE[s.size];
        return wrap(evBox(E(HX.b), s, 3, 3, 94, 40, 'Weekly standup', '09:30–10:00', { fs, fsm, font: FONTS[s.font] }));
      }
      case 'chrome': {
        const sz = [[13, 10.5, 9.5], [14.5, 11, 10], [16, 11.5, 10]][s.chrome];
        return wrap(`<span class="p-tx" style="top:3px;color:${t.fg1};font-weight:600;font-size:${sz[0]}px;line-height:${sz[0] + 3}px">November</span>` +
          `<span class="p-tx" style="top:24px;color:${t.fg2};font-size:${sz[1]}px">Wed <b style="color:${t.fg1};font-weight:600">18</b></span><span class="p-tx" style="top:24px;left:auto;right:6px;color:${t.hourc};font-size:${sz[2]}px">09:00</span>`);
      }
      case 'lines':
        return wrap(`<span class="p-ln" style="top:10px;border-color:${t.grid}"></span><span class="p-ln" style="top:34px;border-color:${t.grid}"></span>` +
          (t.gridHalf !== 'transparent' ? `<span class="p-ln" style="top:22px;border-top:1px dotted ${t.gridHalf}"></span><span class="p-ln" style="top:46px;border-top:1px dotted ${t.gridHalf}"></span>` : '') +
          (t.gridV !== 'transparent' ? `<span class="p-vl" style="left:33%;border-color:${t.gridV}"></span><span class="p-vl" style="left:66%;border-color:${t.gridV}"></span>` : ''));
      case 'past':
        return wrap(evBox(E(HX.b), s, 3, 3, 46, 40, 'Done', '08:00', { past: 1 }) + evBox(E(HX.b), s, 51, 3, 46, 40, 'Next', '19:00'));
      case 'today': {
        const mk = s.today === 0 || s.today === 1 ? `background:${t.accent};color:${t.onAccent};font-weight:600` : s.today === 2 || s.today === 3 ? `background:${t.live};color:${t.onLive};font-weight:600` : `color:${t.fg1};font-weight:700`;
        return wrap(`<span class="p-sd" style="left:50%;width:50%;background:${t.todayTint}"></span><span class="p-vl" style="left:50%;border-color:${t.grid}"></span>` +
          `<span class="p-dt" style="left:5px;top:3px;color:${t.fg2}">Tue <span class="p-nn">17</span></span><span class="p-dt" style="left:calc(50% + 5px);top:3px;color:${t.fg1}">Wed <span class="p-nn" style="${mk}">18</span></span>` +
          `<span class="p-ln" style="top:23px;border-color:${t.hairStrong}"></span><span class="p-ln" style="top:36px;border-color:${t.grid}"></span>`);
      }
      case 'now': {
        const e = E(HX.b), e2 = E(HX.g);
        return wrap((t.shade ? `<span class="p-sd" style="width:100%;height:24px;bottom:auto;background:${t.elapsed}"></span>` : '') + `<span class="p-ln" style="top:12px;border-color:${t.grid}"></span>` +
          evBox(e, s, 4, 2, 44, 18, 'Done', '', { past: 1 }) + evBox(e2, s, 52, 29, 44, 15, 'Next', '', { next: t.next }) +
          `<span class="p-ln" style="top:24px;border-top:2px solid ${t.live}"></span><span class="p-ln" style="top:23px;left:0;width:6px;height:6px;border:0;border-radius:50%;background:${t.live};margin-top:-2px"></span>`);
      }
      case 'maybe':
        return wrap(evBox(E(HX.b), s, 3, 3, 46, 40, 'Maybe', '14:00', { maybe: 1 }) + evBox(E(HX.r), s, 51, 3, 46, 40, 'Declined', '15:00', { dec: 1 }));
    }
    return wrap('');
  }

  // ---------------------------------------------------------------- the tab
  function body() {
    const s = cur(), code = R.encode(s), pre = R.presetOf(code, V.k), bP0 = baseP();
    const vc = R.verdict(s, 'chrome'), ve = R.verdict(s, 'events'), n = vc.n + ve.n, w = [vc.worst, ve.worst].filter(Boolean).sort((a, b) => a.m - b.m)[0];
    const okAll = vc.ok && ve.ok;
    let h = '';
    if (V.appear !== 'dark') h += `<div class="rdsum">Paper view: Paper is derived from the Dark rules (round h). The numbers below are Dark's. <button class="rbtn" data-r="rddark">Show Dark</button></div>`;
    h += `<div class="rdhead"><span class="nm2">${esc2(pre ? pre.l : bP0.l)} <em>${pre ? pre.id : 'edited'}</em></span><button class="rbtn" data-r="rdcopy">Copy link</button><button class="rbtn" data-r="rdreset" ${pre ? 'disabled' : ''} title="Back to ${esc2(bP0.l)}">Reset</button></div>`;
    const P0 = pre || bP0;
    h += `<div class="rdidea">${esc2(P0.idea)}<span class="rules">Applies: ${esc2(P0.rules)}</span></div>`;
    h += `<div class="rdp">${R.PRESETS.map(p => `<button class="${pre && p.id === pre.id ? 'on' : ''}" data-r="rdpre" data-k="${p.id}" title="${esc2(p.idea)}"><b><i>${p.id}</i>${esc2(p.l)}</b><small>${esc2(TAG[p.id] || '')}</small></button>`).join('')}</div>`;
    h += `<div class="rdsum ${okAll ? '' : 'bad'}">${okAll ? '✓' : '✕'} ${n.toLocaleString('en')} pairs, Dark + Paper (${R.HUES().length} calendar colours × every state), ${okAll ? '0 below target' : 'below target'} · tightest: ${esc2(w.what.replace(/ · #\w+$/, ''))} ${num(w)} (floor ${floorTxt(w.k)})</div>`;
    h += paperBlock(s);
    h += typeBlock(s);
    h += sliders(s);
    for (const [g, gl] of R.GROUPS) {
      const bp = baseP(), chg = R.LEVERS.filter(x => x.g === g && s[x.k] !== (bp.s[x.k] || 0));
      h += `<div class="rdg"><h4>${gl}${chg.length ? `<button class="rbtn sm" data-r="rdlgrp" data-k="${g}" title="Reset ${chg.map(x => x.l).join(', ')} to ${esc2(bp.id)}">Reset ${chg.length}</button>` : ''}</h4>`;
      for (const lev of R.LEVERS.filter(x => x.g === g)) {
        const wide = ['event', 'chrome', 'type', 'font', 'past', 'maybe', 'now', 'today'].includes(lev.p) && lev.o.length <= 4 || lev.p === 'type' || lev.p === 'chrome';
        const lch = s[lev.k] !== (bp.s[lev.k] || 0);
        h += `<div class="rdl ${lch ? 'rchg' : ''}" tabindex="0" data-rkind="lever" data-rkey="${lev.k}"><div class="lh"><span class="ln">${lev.l}</span>${lch ? '<i class="ch" title="Changed from the preset"></i>' : ''}<span class="lv">${esc2(lev.o[s[lev.k]][0])}</span>${lch ? RST('rdlone', lev.k, `Reset to default · Default: ${lev.o[bp.s[lev.k] || 0][0]} (${bp.id})`) : ''}</div><div class="wy">${esc2(lev.why)}</div><div class="rdo ${wide ? 'wide' : ''}">`;
        lev.o.forEach(([nm, note], i) => {
          const sv = { ...s, [lev.k]: i }, ok = R.passes(sv), on = s[lev.k] === i;
          const rt = rate(sv, lev.k), v = ok ? null : { fail: (R.verdict(sv, 'chrome').fail || R.verdict(sv, 'events').fail) };
          const tip = rt.aff.length ? rt.aff.slice().sort((a, b) => a.m - b.m).slice(0, 4).map(p => `${p.what.replace(/ · #\w+$/, '')}: ${num(p)} (floor ${floorTxt(p.key)})`).join('\n') : '';
          h += `<button class="${on ? 'on' : ''}" data-r="rdopt" data-k="${lev.k}" data-v="${i}" ${ok ? '' : 'disabled'} title="${esc2((ok ? '' : 'Not reachable: ' + reason(v) + '\n') + tip)}">${preview(lev.k, sv)}` +
            `<span class="on2">${esc2(nm)}</span>${note ? `<span class="nt">${esc2(note)}</span>` : ''}` +
            (rt.sh ? `<span class="num"><span class="bd ${ok ? rt.badge : 'fail'}" title="${ok ? rt.badge : 'off'}"></span><i>${SHORT[rt.sh.key] || ''}</i> ${num(rt.sh)}</span>` : '') +
            (ok ? '' : `<span class="why2">${esc2(reason(v))}</span>`) + `</button>`;
        });
        h += `</div></div>`;
      }
      h += `</div>`;
    }
    h += `<div class="rnote" style="margin-top:14px">Floors are the brief's §1 targets as checked by <code>contrast.mjs</code> (unchanged). Dots: <b style="color:#6FCF8E">green</b> ≥ 3 % above the floor, <b style="color:#F0C060">amber</b> within 3 % (or within ~1 Lc of the halation cap), <b style="color:#FF7B6E">red</b> = the option would break a floor somewhere in this design, so it cannot be picked. Proof over every combination: <code>node design/mockup-v11/contrast.mjs --rd</code>.</div>`;
    return h;
  }
  function act(r, b) {
    const k = b.dataset.k;
    const go = () => { V.look = 'R'; }; // round h: Paper is derived for look R, so a change no longer forces Dark
    if (r === 'rddark') { go(); return true; }
    if (r === 'rdpre') { const p = R.PRESETS.find(x => x.id === k); if (!p) return false; V.r = p.code; V.k = p.k || ''; V.rp = p.id; go(); return true; }
    if (r === 'rdopt') { const s = cur(); s[k] = +b.dataset.v; if (!R.passes(s)) return false; V.r = R.encode(s); const p = R.presetOf(V.r, V.k); if (p) V.rp = p.id; go(); return true; }
    if (r === 'rdreset') { const p = R.PRESETS.find(x => x.id === V.rp) || R.PRESETS[0]; V.r = p.code; V.k = p.k || ''; go(); return true; }
    if (r === 'rdsreset') { V.k = baseP().k || ''; go(); return true; }
    if (r === 'rdpaper') { V.look = 'R'; V.appear = 'paper'; A.settings.appearance = 'paper'; return true; }
    if (r === 'rdpf') { const K = { ...cur().K, pf: +k }; if (!R.passes({ ...cur(), K })) return false; V.k = R.encodeK(K); V.look = 'R'; if (V.appear !== 'paper') { V.appear = 'paper'; A.settings.appearance = 'paper'; } return true; }
    if (r === 'rdtool') { V[k] = k === 'ba' ? (V.ba === 'a' ? 'b' : 'a') : V[k] === '1' ? '0' : '1'; return true; }
    if (r === 'rdq') { QOPEN[k] = !QOPEN[k]; return 'rail'; }
    if (r === 'rdscale') { const K = R.applyScale(cur().K, k); if (!R.passes({ ...cur(), K })) return false; V.k = R.encodeK(K); V.ba = 'a'; go(); return true; }
    if (r === 'rdwt') { const K = { ...cur().K }; if (k === '') delete K.wt; else K.wt = +k; V.k = R.encodeK(K); V.ba = 'a'; go(); return true; }
    if (r === 'rdsone') { resetOne('slider', k); return false; }
    if (r === 'rdlone') { resetOne('lever', k); return false; }
    if (r === 'rdsgrp' || r === 'rdlgrp') {
      const s = cur(), pK = baseK(), bp = baseP(), K = { ...s.K };
      if (r === 'rdsgrp') R.SLIDERS.filter(x => x[1] === k).forEach(([id]) => { if (pK[id] != null) K[id] = pK[id]; else delete K[id]; });
      else R.LEVERS.filter(x => x.g === k).forEach(x => { s[x.k] = bp.s[x.k] || 0; });
      if (!R.passes({ ...s, K })) return false;
      V.r = R.encode(s); V.k = R.encodeK(K); go(); return true;
    }
    if (r === 'rdgroup') { OPEN[k] = !OPEN[k]; return 'rail'; }
    if (r === 'rdcopy') { navigator.clipboard && navigator.clipboard.writeText(location.href); b.textContent = 'Copied'; setTimeout(() => { b.textContent = 'Copy link'; }, 1200); return false; }
    return false;
  }
  const name = () => { const p = R.presetOf(R.encode(cur()), V.k); if (p) return p.l; const b = R.PRESETS.find(x => x.id === V.rp) || R.PRESETS[0]; return b.l + ' (edited)'; };

  // ---------------------------------------------------------------- sliders (round e)
  const OPEN = { scale: true, font: true, fontp: false, space: true, evc: true, canvas: true, tent: false };
  const QOPEN = {};
  const dec = st => st < .01 ? 3 : st < 1 ? 1 : 0;
  const fmtv = (id, v) => { const x = R.SLIDERS[R.SI[id]]; return (+v).toFixed(dec(x[5])) + (x[6] || ''); };
  const live = s => { const vc = R.verdict(s, 'chrome'), ve = R.verdict(s, 'events'), w = [vc.worst, ve.worst].sort((a, b) => a.m - b.m)[0], ok = vc.ok && ve.ok;
    return `<span class="bd2 ${ok ? (w.m < 1.03 ? 'near' : 'pass') : 'fail'}"></span><b>${ok ? '0 below target' : 'below target'}</b> · ${vc.n + ve.n} pairs · tightest ${esc2(w.what.replace(/ · #\w+$/, ''))} <span class="mono">${num(w)}</span> <i>(floor ${floorTxt(w.k)})</i>`; };
  // round g (designr step 4): the type-scale and weight decisions, and the tools (counter, guides, design-system sheet, before / after)
  const WEIGHTS = [[0, '400 / 500 / 600', '600 only for the month title and today\'s date; 500 for event titles, group headers and the mini-month title; 400 for the rest. Day-header weekdays go from 450 to 400.'],
    [1, '400 / 500 only', 'No semibold anywhere: the month title and today\'s date drop to 500. The calmest; the month title leans on size alone.'],
    [null, 'Current (yours)', 'As your link: 400, 450 (day headers), 500 and 600.']];
  function typeBlock(s) {
    const K = s.K, cur0 = R.scaleOf(K) || (['rD', 'rH', 'rB', 'rL', 'rM'].some(i => K[i] != null) ? null : 'current'), tw = K.wt != null ? K.wt : null;
    const tb = (r, k, on, lbl) => `<button class="rbtn ${on ? 'on' : ''}" data-r="${r}" data-k="${k}">${lbl}</button>`;
    const LK = R.LOCKED, isLocked = cur0 === LK.scale && tw === LK.weights, open = QOPEN.unlock || !isLocked;
    let h = `<div class="rdg"><h4>Design system · type <span class="sct">${isLocked ? 'locked ' + LK.date : 'round g'}</span></h4>` +
      `<div class="rdlock"><b>Locked</b> ${esc2(LK.date)}: type scale <b>${esc2(LK.picked)}</b>, weights <b>400 / 500 / 600</b>; Paper ${esc2(LK.paper)}. You said: "${esc2(LK.quote)}". ` +
      `<button class="rbtn sm" data-r="rdq" data-k="unlock">${QOPEN.unlock ? 'Hide options' : 'Unlock to compare'}</button>${isLocked ? '' : ' <i>(changed from the lock)</i>'}</div>` +
      `<div class="rdtools">${tb('rdtool', 'cnt', V.cnt === '1', 'Counter (X)')}${tb('rdtool', 'gd', V.gd === '1', 'Alignment guides (G)')}${tb('rdtool', 'ds', V.ds === '1', 'Design system sheet')}${tb('rdtool', 'ba', V.ba === 'a', V.ba === 'b' ? 'Before · round g link (B)' : 'After · locked (B)')}</div>` +
      `<div class="wy">You said: "generally make sure my font sizes somehow make sense … they need to be coherent … to preserve visual hierarchy. there need to be different consistent sizes". Pick a type scale: it sets the role sliders below (one size per role); "Advanced: per place" keeps per-place overrides.</div>` +
      (open ? '' : '<!--') + `<div class="rdl"><div class="lh"><span class="ln">Type scale</span><span class="lv">${esc2((R.SCALES.find(x => x.id === cur0) || { l: 'Custom' }).l.split(' · ')[0])}</span></div><div class="rdts">` +
      R.SCALES.map((o, i) => `<button class="o ${cur0 === o.id ? 'on' : ''}" data-r="rdscale" data-k="${o.id}"><span class="tx">${esc2(o.l.split(' · ')[0])}<small>${esc2(o.l.split(' · ')[1] || '')}${o.r ? ' px · title / heading / body / secondary' : ''}</small></span>${o.id === R.LOCKED.scale ? '<span class="rec">locked</span>' : i === 0 ? '<span class="rec rc2">round g rec.</span>' : ''}<span class="q" data-r="rdq" data-k="s${o.id}" title="${esc2(o.q)}">?</span></button><div class="qt ${QOPEN['s' + o.id] ? 'show' : ''}">${esc2(o.q)}</div>`).join('') + `</div></div>` +
      `<div class="rdl"><div class="lh"><span class="ln">Weights</span><span class="lv">${esc2((WEIGHTS.find(w => w[0] === tw) || WEIGHTS[2])[1])}</span></div><div class="rdts">` +
      WEIGHTS.map(([v, l, q], i) => `<button class="o ${tw === v ? 'on' : ''}" data-r="rdwt" data-k="${v == null ? '' : v}"><span class="tx">${esc2(l)}</span>${i === 0 ? '<span class="rec">locked</span>' : ''}<span class="q" data-r="rdq" data-k="w${i}" title="${esc2(q)}">?</span></button><div class="qt ${QOPEN['w' + i] ? 'show' : ''}">${esc2(q)}</div>`).join('') + `</div></div>` + (open ? '' : '-->') + `</div>`;
    return h;
  }
  // round h polish: Paper event colours (Dark is not affected)
  const PFQ = ['Every calendar gets the same visibility against the canvas (fill ΔE_OK ≥ 9 × a per-hue factor, min 7.7), lavender / grape / graphite get more chroma or a lower L, yellow stays light; a 4 px bar at L .57 in the calendar hue. Calm and clearly coloured.',
    'Fuller tints (ΔE_OK ≥ 13, min 11): every calendar reads from across the room; the week looks more colourful.',
    'Light tints (ΔE_OK ≥ 6.5) and a 5 px deep bar (L .50): the colour lives mostly in the bar.',
    'As first shown in round h: one L .95 / chroma ≤ .075 tint for all, 3.5 px bar at L .60 (fill ΔE_OK 3.8–8.4; lavender, grape and graphite nearly vanish).'];
  function paperBlock(s) {
    const pf = s.K.pf != null ? s.K.pf : 0, opts = [...R.PF.filter(Boolean).map(o => o.l), 'Round h (before)'];
    return `<div class="rdg"><h4>Paper colours <span class="sct">round h polish</span></h4><div class="wy">You said: "paper needs some polish where the colors arent like as good visible". Dark is unchanged. ${V.appear !== 'paper' ? '<button class="rbtn sm" data-r="rdpaper">Show Paper</button>' : ''}</div>` +
      `<div class="rdts">${opts.map((l, i) => `<button class="o ${pf === i ? 'on' : ''}" data-r="rdpf" data-k="${i}"><span class="tx">${esc2(l)}</span>${i === 0 ? '<span class="rec">recommended</span>' : ''}<span class="q" data-r="rdq" data-k="p${i}" title="${esc2(PFQ[i])}">?</span></button><div class="qt ${QOPEN['p' + i] ? 'show' : ''}">${esc2(PFQ[i])}</div>`).join('')}</div></div>`;
  }
  function sliders(s) {
    const K = s.K, n = Object.keys(K).length;
    let h = `<div class="rdg rdsl"><h4>Sliders <span class="sct">${n ? n + ' set' : 'all follow the levers'}</span>${n ? '<button class="rbtn sm" data-r="rdsreset">Reset sliders</button>' : ''}</h4>` +
      `<div class="rdlive" id="rdlive">${live(s)}</div><div class="wy">Drag, or type a value. ↺ (or double-click, or Backspace on a focused row) resets one option to the preset's value; "Reset n" resets a section. Colour sliders are limited to the range where every pair still passes; text colours are refitted live.</div>`;
    const pK = baseK(), bp = baseP(), sP = { ...s, K: pK };
    for (const [g, gl] of R.SGROUPS) {
      const chg = R.SLIDERS.filter(x => x[1] === g && sChanged(x[0], K, pK));
      h += `<div class="sgrp ${OPEN[g] ? 'open' : ''}"><div class="sghr"><button class="sgh" data-r="rdgroup" data-k="${g}">${OPEN[g] ? '▾' : '▸'} ${gl}</button>${chg.length ? `<button class="rbtn sm" data-r="rdsgrp" data-k="${g}" title="Reset ${chg.map(x => x[2]).join(', ')} to ${bp.id}">Reset ${chg.length}</button>` : ''}</div>`;
      if (OPEN[g]) for (const [id, , label, lo, hi, st, unit, col] of R.SLIDERS.filter(x => x[1] === g)) {
        const set = K[id] != null, v = set ? K[id] : R.auto(id, s), chd = sChanged(id, K, pK);
        const dv = pK[id] != null ? pK[id] : R.auto(id, sP), rb = chd ? RST('rdsone', id, `Reset to default · Default: ${fmtv(id, dv)}${pK[id] != null ? '' : ' (auto)'} (${bp.id})`) : '';
        if (id === 'oh') { h += `<div class="rds tog ${chd ? 'rchg' : ''}" tabindex="0" data-sid="oh"><label><input type="checkbox" data-rs="oh" ${K.oh ? 'checked' : ''}> One hue for all calendars <i class="nt">(off = shift each calendar's own hue)</i></label>${rb}</div>`; continue; }
        const dis = id === 'ou' && !K.oh;
        h += `<div class="rds ${set ? 'set' : ''} ${chd ? 'rchg' : ''} ${dis ? 'dis' : ''}" tabindex="0" data-sid="${id}"><div class="sh"><span class="sl">${label}</span>${col ? '<i class="cdot" title="Changes colours: guarded"></i>' : ''}<span class="sv" data-sv="${id}">${fmtv(id, v)}</span><i class="auto">${set ? '' : 'auto'}</i>${rb}</div>` +
          `<div class="sr"><input type="range" data-rs="${id}" min="${lo}" max="${hi}" step="${st}" value="${v}" ${dis ? 'disabled' : ''}><input type="number" class="snum" data-rn="${id}" min="${lo}" max="${hi}" step="${st}" value="${(+v).toFixed(dec(st))}" ${dis ? 'disabled' : ''}></div><div class="snote" data-sn="${id}"></div></div>`;
      }
      h += `</div>`;
    }
    return h + '</div>';
  }
  // the guarded range of a colour slider: sample it, keep the passing run around the current value, refine both edges
  function range(id, s) {
    const [, , , lo, hi, st] = R.SLIDERS[R.SI[id]], cur0 = s.K[id] != null ? s.K[id] : R.auto(id, s);
    const ok = x => { const K = { ...s.K, [id]: R.snap(id, x) }; return R.passes({ ...s, K }); };
    const N = 16, xs = Array.from({ length: N + 1 }, (_, i) => lo + (hi - lo) * i / N), pass = xs.map(ok);
    let i0 = xs.reduce((b, x, i) => Math.abs(x - cur0) < Math.abs(xs[b] - cur0) ? i : b, 0); if (!pass[i0]) return { lo: cur0, hi: cur0 };
    let a = i0, b = i0; while (a > 0 && pass[a - 1]) a--; while (b < N && pass[b + 1]) b++;
    const edge = (good, bad) => { for (let k = 0; k < 7; k++) { const m = (good + bad) / 2; if (ok(m)) good = m; else bad = m; } return R.snap(id, good + (good < bad ? 0 : 0)); };
    const L = a > 0 ? Math.min(cur0, edge(xs[a], xs[a - 1])) : lo, H = b < N ? Math.max(cur0, edge(xs[b], xs[b + 1])) : hi;
    const why = x => { const K = { ...s.K, [id]: R.snap(id, x) }, s2 = { ...s, K }, v = R.verdict(s2, 'chrome').ok ? R.verdict(s2, 'events') : R.verdict(s2, 'chrome'); return v.fail ? reason(v) : ''; };
    return { lo: L, hi: H, wlo: a > 0 ? why(xs[a - 1]) : '', whi: b < N ? why(xs[b + 1]) : '' };
  }
  let rangeJob = 0;
  function after() {
    const job = ++rangeJob, s = cur(), ids = R.CSL.filter(id => id !== 'oh' && document.querySelector(`#rail [data-rs="${id}"]:not([disabled])`));
    const step = () => {
      if (job !== rangeJob || !ids.length) return;
      const id = ids.shift(), r = range(id, s), inp = document.querySelector(`#rail [data-rs="${id}"]`), nb = document.querySelector(`#rail [data-rn="${id}"]`), note = document.querySelector(`#rail [data-sn="${id}"]`);
      if (inp) { const [, , , lo, hi] = R.SLIDERS[R.SI[id]]; inp.min = r.lo; inp.max = r.hi; if (nb) { nb.min = r.lo; nb.max = r.hi; }
        const parts = []; if (r.lo > lo + 1e-9) parts.push(`min ${fmtv(id, r.lo)}: ${r.wlo}`); if (r.hi < hi - 1e-9) parts.push(`max ${fmtv(id, r.hi)}: ${r.whi}`);
        if (note) note.textContent = parts.length ? 'Range limited · ' + parts.join(' · ') : ''; }
      setTimeout(step, 0);
    };
    setTimeout(step, 30);
  }
  // live: apply while dragging (app re-renders on the next frame; the rail is rebuilt on release)
  let raf = 0;
  function setK(id, val, final) {
    const s = cur(), K = { ...s.K };
    if (val == null) delete K[id]; else K[id] = R.snap(id, val);
    if (R.CSL.includes(id) && !R.passes({ ...s, K })) {
      const note = document.querySelector(`#rail [data-sn="${id}"]`), v = R.verdict({ ...s, K }, 'chrome').ok ? R.verdict({ ...s, K }, 'events') : R.verdict({ ...s, K }, 'chrome');
      if (note) note.textContent = 'Blocked · ' + reason(v);
      const inp = document.querySelector(`#rail [data-rs="${id}"]`); if (inp) inp.value = s.K[id] != null ? s.K[id] : R.auto(id, s);
      return;
    }
    V.k = R.encodeK(K); V.look = 'R';
    const sv = document.querySelector(`#rail [data-sv="${id}"]`); if (sv && val != null) sv.textContent = fmtv(id, K[id]);
    const nb = document.querySelector(`#rail [data-rn="${id}"]`); if (nb && val != null && document.activeElement !== nb) nb.value = (+K[id]).toFixed(dec(R.SLIDERS[R.SI[id]][5]));
    const row = document.querySelector(`#rail .rds[data-sid="${id}"]`); if (row) { row.classList.toggle('set', val != null); const a = row.querySelector('.auto'); if (a) a.textContent = val != null ? '' : 'auto'; }
    const lv = document.getElementById('rdlive'); if (lv) lv.innerHTML = live({ ...s, K });
    window.saveHash && saveHash();
    cancelAnimationFrame(raf); raf = requestAnimationFrame(() => render());
    if (final) setTimeout(() => window.rdRerail && rdRerail(), 0);
  }
  function resetOne(kind, k) {
    const s = cur(), bp = baseP(), pK = baseK();
    if (kind === 'slider') { setK(k, pK[k] != null ? pK[k] : null, true); return; }
    s[k] = bp.s[k] || 0; if (!R.passes(s)) return;
    V.r = R.encode(s); V.look = 'R'; window.saveHash && saveHash(); render(); window.rdRerail && rdRerail();
  }
  function bind(rail) {
    rail.addEventListener('keydown', ev => {
      if (ev.key !== 'Backspace' && ev.key !== 'Delete') return;
      const t = ev.target; if (t.matches('input[type=number], input[type=text], textarea')) return;
      const row = t.closest('[data-sid], [data-rkey]'); if (!row) return;
      ev.preventDefault(); ev.stopPropagation();
      if (row.dataset.sid) resetOne('slider', row.dataset.sid); else resetOne('lever', row.dataset.rkey);
    }, true);
    rail.addEventListener('input', ev => { const t = ev.target; if (t.dataset.rs && t.type === 'range') setK(t.dataset.rs, +t.value, false); });
    rail.addEventListener('change', ev => { const t = ev.target;
      if (t.dataset.rs === 'oh') { setK('oh', t.checked ? 1 : null, true); return; }
      if (t.dataset.rs) setK(t.dataset.rs, +t.value, true);
      if (t.dataset.rn) { const v = Math.min(+t.max, Math.max(+t.min, +t.value)); setK(t.dataset.rn, v, true); } });
    rail.addEventListener('dblclick', ev => { const row = ev.target.closest('.rds[data-sid]'); if (row && !ev.target.matches('input[type=number], .rst')) resetOne('slider', row.dataset.sid); });
  }
  return { body, act, name, preview, rate, after, bind };
})();
