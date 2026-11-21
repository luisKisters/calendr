// Calendr v11 · the Readability designer (round 2026-11-20 d). Dark only; Paper stays the v10 Designer output.
// 18 levers in six groups (Background · Text levels · Events · Type · Lines · States), each a short list of options built from
// READABILITY-BRIEF.md (v10). A design is one base-36 character per lever, kept in the hash (look=R&r=…).
// READ.look(code) returns a look with the interface of DESIGNER.look (vars, ev, evVars, adVars, calDot, check, gap, H, cls, geo, o):
// the shape (bar, radius, gaps, type sizes, today marker, tentative style …) comes from a DESIGNER option set, the Dark colours come
// from this file. Every Dark pair READ.pairs() lists is checked against the floors of contrast.mjs (FLOORS below = contrast.mjs T.dark,
// unchanged). A design that misses one floor is not reachable: the rail disables the option that would lead there, and a hash that
// asks for one falls back to the first preset. contrast.mjs proves it over every combination of the colour levers.
'use strict';
const READ = (() => {
  const TH = typeof THEME !== 'undefined' ? THEME : require('./tokens.js');
  const DZ = typeof DESIGNER !== 'undefined' ? DESIGNER : require('./designer.js');
  const { mx, css, relL, wcag, apca, oklch, fromOklch, fit } = TH.util;
  const W = '#FFFFFF';
  // contrast.mjs T.dark, unchanged: [min ratio, min |Lc|, max |Lc|]
  const FLOORS = {
    fg1: [12, 88, 96], fg1soft: [12, 85], fg2: [7, 68], fg2soft: [7, 63], fg3: [6.5, 48], fg3soft: [5.5, 45],
    accent: [12, 85], live: [4.5, 45], status: [4.5, 45], nontext: [3, 0],
    evTitle: [7, 75], evMeta: [6.5, 60], evSelMeta: [5.5, 55], evPastTitle: [7, 65], evPastMeta: [5.7, 48], evDecl: [6, 55],
    decor: [1, 0, 15], decorMin: [1.15, 0, 15], structure: [1.15, 0, 35],
  };
  // contrast.mjs T.paper, unchanged (round h: Paper is derived from the locked Dark rules and checked too)
  const FLOORS_P = {
    fg1: [12, 95], fg1soft: [12, 88], fg2: [7, 80], fg2soft: [7, 75], fg3: [5, 70], fg3soft: [5, 65],
    accent: [12, 90], live: [4.5, 60], status: [4.5, 60], nontext: [3, 0],
    evTitle: [7, 75], evMeta: [5.9, 70], evSelMeta: [5.5, 65], evPastTitle: [7, 75], evPastMeta: [5, 65], evDecl: [6.5, 75],
    decor: [1, 0, 15], decorMin: [1.15, 0, 15], structure: [1.15, 0, 35],
  };
  const DECOR = new Set(['decor', 'decorMin', 'structure']);
  // m = margin over the floor (1 = on the floor); a cap counts as a floor from above (near when within ~2 Lc of it)
  const grade = (fg, bg, key, th = 'dark') => {
    const [r0, l0, lmax] = (th === 'paper' ? FLOORS_P : FLOORS)[key], r = wcag(fg, bg), a = Math.abs(apca(fg, bg));
    const ok = r >= r0 - 1e-9 && a >= l0 - 0.05 && (lmax == null || a <= lmax + 0.05);
    let m = key === 'decor' ? Infinity : Math.min(r / r0, l0 ? a / l0 : Infinity);
    if (lmax != null) m = Math.min(m, 1 + (lmax - a) / 40);
    return { r, a, ok, m };
  };
  const C3 = (L, C, H) => fromOklch([L, C, H]);
  const deg = H => ((H * 180 / Math.PI) + 360) % 360;

  // ---------------------------------------------------------------- levers
  // g: group · k: key · l: label · why: the research rule (brief section) · c: changes a colour (crossed by the proof) · o: options [name, note]
  const GROUPS = [['bg', 'Background'], ['text', 'Text levels'], ['ev', 'Events'], ['type', 'Type'], ['lines', 'Lines'], ['states', 'States']];
  const LEVERS = [
    { g: 'bg', k: 'canvas', l: 'Canvas', c: 1, p: 'canvas', why: '§1 · pure #000 with light text halates for the ~1 in 3 with astigmatism; graphite (#11) or stepped surfaces on OLED avoid it.',
      o: [['Graphite', '#111113 · brief A'], ['Ink', '#0A0A0B'], ['OLED black', '#000 + stepped surfaces · brief B'], ['Notion', '#191919'], ['Dim grey', '#1C1C1E · Apple'], ['Charcoal', '#222224']] },
    { g: 'bg', k: 'panes', l: 'Panes', c: 1, p: 'panes', why: '§3.3 · separate panes by a 3–6 % surface step before a line; quieter sidebars let the grid lead.',
      o: [['One surface', 'hairline only'], ['Darker sidebars', 'step down'], ['Lighter sidebars', 'step up']] },
    { g: 'text', k: 'steps', l: 'Text steps', c: 1, p: 'steps', why: '§1 · fg1 Lc 88–96 (cap 96 on near-black), fg2 ≥ Lc 68, fg3 ≥ Lc 48; greys tuned by APCA because WCAG overrates dark pairs.',
      o: [['Soft', 'Lc 89 / 68 / 49'], ['Brief', 'Lc 93 / 71 / 51'], ['Crisp', 'Lc 95 / 75 / 55'], ['Two greys', 'Lc 92 / 72 · §3.4'], ['Max', 'Lc 98 / 78 / 56']] },
    { g: 'text', k: 'hourc', l: 'Hour labels', c: 1, p: 'hour', why: '§6 B · hour labels in fg2 read at a glance; fg3 keeps them behind the events (§3.1 one dominant element).',
      o: [['Quiet', 'fg3'], ['Medium', 'fg2 ↔ fg3'], ['Clear', 'fg2']] },
    { g: 'ev', k: 'recipe', l: 'Event recipe', c: 1, p: 'event', why: '§5 · one decoration per state; the calendar colour appears once per event, as fill or bar, never both at full strength (§3.2).',
      o: [['Tint', 'fill only · brief A'], ['Bar + tint', 'soft fill, 3 px bar · B'], ['Muted solid', 'deep fill, light title'], ['Outline', '1 px hue edge'], ['Card + bar', 'neutral card, hue bar']] },
    { g: 'ev', k: 'chroma', l: 'Colour strength', c: 1, p: 'event', why: '§0 · the 34 % tint was a navy wall. Fills are mixed in OKLCH at one lightness per strength, so no calendar shouts and nothing turns muddy.',
      o: [['Whisper', 'C .028'], ['Calm', 'C .042'], ['Balanced', 'C .058'], ['Rich', 'C .08']] },
    { g: 'ev', k: 'evtext', l: 'Event text', c: 1, p: 'event', why: '§5 · title fg1 at 12/500, time mixed toward the fill; hue-tinted text only as far as it keeps Lc 75 / 60.',
      o: [['Neutral', 'fg1 title, grey time'], ['Hue title', 'tinted title, grey time'], ['Hue both', 'tinted title and time']] },
    { g: 'ev', k: 'allday', l: 'All-day lane', c: 1, p: 'chip', why: '§3.2 · colour means calendar, once; in the all-day lane a dot or a bar is enough and the band stays light.',
      o: [['As events', 'same fill'], ['Dot + text', 'no fill'], ['Bar + text', 'no fill']] },
    { g: 'type', k: 'size', l: 'Event type', p: 'type', why: '§2 · Apple body 13, callout 12, subheadline 11; Notion sets events at ~11–12 px. Smaller reads calmer; the floors stay the same.',
      o: [['11 / 10.5', 'Notion-like'], ['11.5 / 10.5', ''], ['12 / 11', 'brief event'], ['12.5 / 11', ''], ['13 / 11', 'brief body']] },
    { g: 'type', k: 'weight', l: 'Title weight', p: 'type', why: '§2 · 500 for event titles; light text on dark looks bolder (irradiation), so 600 everywhere means nothing stands out.',
      o: [['400', ''], ['450', ''], ['500', 'brief'], ['560', ''], ['600', '']] },
    { g: 'type', k: 'font', l: 'Font', p: 'font', why: '§2 · one family. SF is native, Inter reads larger at 11 px (tall x-height), Geist is narrower. No serif.',
      o: [['Inter', 'bundled'], ['System', 'SF Pro'], ['Geist', 'bundled']] },
    { g: 'type', k: 'chrome', l: 'Chrome type', p: 'chrome', why: '§2 / §5 · five sizes in all; a smaller month title and day header (Notion-like) let the grid lead.',
      o: [['Calm', '16 · 12 · 10.5'], ['Mid', '18 · 12 · 11'], ['Brief', '20 · 13 · 11']] },
    { g: 'lines', k: 'hourLine', l: 'Hour line', c: 1, p: 'lines', why: '§3.3 · the hour line is the one grid line that must stay visible (≥ 1.15:1, user ask); everything else sits below Lc 15.',
      o: [['Hairline', '7 %'], ['Quiet', '10 %'], ['Clear', '14 %'], ['Strong', '19 %'], ['Ruled', '25 %']] },
    { g: 'lines', k: 'minor', l: 'Minor lines', c: 1, p: 'lines', why: '§3.3 · drop or dot the half hour; day dividers only where columns blur. Both stay decoration (≤ Lc 15).',
      o: [['None', 'hours only'], ['Day dividers', ''], ['Dotted half hours', ''], ['Both', '']] },
    { g: 'states', k: 'past', l: 'Past events', c: 1, p: 'past', why: '§5 states · step the fill back, never fade the whole block: 55 % opacity drops the time to 3.6:1.',
      o: [['Fade', 'fill → canvas 55 %'], ['Ghost', 'fill → canvas 85 %'], ['Grey', 'neutral fill'], ['Text only', 'fill kept, grey text']] },
    { g: 'states', k: 'today', l: 'Today', c: 1, p: 'today', why: '§3.6 · show today once, strongly. A 3 % column tint makes the column obvious without adding a hue.',
      o: [['Filled date', 'ink circle'], ['Date + column', 'ink circle, 3 % tint'], ['Red date', 'live red'], ['Red + column', ''], ['Bold + column', 'no marker']] },
    { g: 'states', k: 'now', l: 'Now & next', c: 1, p: 'now', why: '§3.2 · one alert hue for now. Past / now / next should read without thinking: shade what is over, ring what comes next.',
      o: [['Today line', ''], ['Week line', 'faint on other days'], ['Line + elapsed', 'shade before now'], ['Line + next', 'ring on next event'], ['Elapsed + next', '']] },
    { g: 'states', k: 'tent', l: 'Maybe / declined', p: 'maybe', why: '§3.7 · one mark per state: dashed = maybe, strike = declined; no stripes on top of a fill.',
      o: [['Dashed', 'declined struck + faded'], ['Hatch', 'stripes in hover fill'], ['Striped bar', ''], ['Faded', 'declined: strike only']] },
  ];
  const KI = Object.fromEntries(LEVERS.map((x, i) => [x.k, i]));
  const COLOUR = LEVERS.filter(x => x.c).map(x => x.k);
  const CHROME_K = ['canvas', 'panes', 'steps', 'hourc', 'hourLine', 'minor', 'today', 'now'];
  const EVENT_K = ['canvas', 'steps', 'recipe', 'chroma', 'evtext', 'past', 'allday'];
  const decode = code => Object.fromEntries(LEVERS.map((x, i) => { const v = parseInt(String(code || '')[i], 36); return [x.k, Number.isInteger(v) && v < x.o.length ? v : 0]; }));
  const encode = s => LEVERS.map(x => (s[x.k] || 0).toString(36)).join('');
  const valid = code => typeof code === 'string' && code.length === LEVERS.length && LEVERS.every((x, i) => parseInt(code[i], 36) < x.o.length);

  // ---------------------------------------------------------------- values
  const CANV = [
    { bg: '#111113', dk: '#0C0C0E', lt: '#17171A', surface: '#1A1A1D', raised: '#222226' },
    { bg: '#0A0A0B', dk: '#060607', lt: '#111113', surface: '#141416', raised: '#1C1C1F' },
    { bg: '#000000', dk: '#000000', lt: '#0E0E10', surface: '#111113', raised: '#1A1A1D' },
    { bg: '#191919', dk: '#141414', lt: '#202020', surface: '#232323', raised: '#2A2A2A' },
    { bg: '#1C1C1E', dk: '#161618', lt: '#232325', surface: '#262628', raised: '#2C2C2E' },
    { bg: '#222224', dk: '#1B1B1D', lt: '#29292B', surface: '#2B2B2E', raised: '#323235' },
  ];
  const STEPS = [[89, 68, 49], [93, 71, 51], [94.6, 75, 55], [92, 72, 72], [98, 78, 56]];
  const HOURK = [.07, .1, .14, .19, .25];
  const CHROMA = [{ c: .028, dl: .055 }, { c: .042, dl: .07 }, { c: .058, dl: .085 }, { c: .08, dl: .1 }];
  const SIZE = [[11, 10.5], [11.5, 10.5], [12, 11], [12.5, 11], [13, 11]];
  const WEIGHT = [400, 450, 500, 560, 600];
  // chrome type → DESIGNER fs* option indexes: fsTitle, fsDay, fsHour, fsSide, fsGroup, fsMini, fsRight, fsPanel
  const CHROME = [[1, 1, 1, 0, 1, 1, 0, 1], [2, 1, 2, 1, 1, 1, 1, 1], [3, 2, 2, 1, 1, 1, 1, 1]];

  // a neutral grey whose |Lc| on bg is at least lc (binary search on the grey level; a hair of blue keeps it from looking warm)
  const grey = v => '#' + [v, v, Math.min(255, v + 2)].map(x => x.toString(16).padStart(2, '0')).join('').toUpperCase();
  function greyFor(bg, lc) { let lo = 0, hi = 253; while (lo < hi) { const m = (lo + hi) >> 1; if (Math.abs(apca(grey(m), bg)) >= lc) hi = m; else lo = m + 1; } return grey(lo); }
  const ok2 = (fg, bg, f) => wcag(fg, bg) >= f[0] + .05 && Math.abs(apca(fg, bg)) >= f[1] + .6;

  // ---------------------------------------------------------------- sliders (round e): continuous values on top of the levers
  // [id, group, label, min, max, step, unit, colour?] — a slider that is not set follows its lever ("auto"). Values live in s.K.
  const SLIDERS = [
    ['sc', 'scale', 'UI scale', 70, 120, 1, '%'],
    // round g: one slider per role step (type scale); the per-place sliders below are overrides ("Advanced: per place")
    ['rD', 'font', 'Title · month', 12, 28, .5, 'px'], ['rH', 'font', 'Heading · day header, mini-month title', 10, 18, .5, 'px'],
    ['rB', 'font', 'Body · events, sidebar, right column', 10, 15, .5, 'px'], ['rL', 'font', 'Label · group headers', 9, 15, .5, 'px'],
    ['rM', 'font', 'Secondary · times, hour labels, mini month', 8.5, 13, .5, 'px'],
    ['fb', 'fontp', 'Base text', 10, 15, .5, 'px'], ['ft', 'fontp', 'Event title', 9, 15, .5, 'px'], ['fm', 'fontp', 'Event time', 8.5, 13, .5, 'px'],
    ['fh', 'fontp', 'Hour labels', 8, 13, .5, 'px'], ['fd', 'fontp', 'Day header', 9, 16, .5, 'px'], ['fT', 'fontp', 'Month title', 12, 28, .5, 'px'],
    ['fs', 'fontp', 'Sidebar rows', 10, 15, .5, 'px'], ['fr', 'fontp', 'Right column', 10, 15, .5, 'px'], ['fg', 'fontp', 'Group headers', 9, 15, .5, 'px'],
    ['fn', 'fontp', 'Mini-month title', 9, 18, .5, 'px'], ['fi', 'fontp', 'Mini-month days', 9, 13, .5, 'px'],
    ['px', 'space', 'Event padding x', 2, 12, .5, 'px'], ['py', 'space', 'Event padding y', 0, 8, .5, 'px'], ['gp', 'space', 'Gap between events', 0, 8, .5, 'px'],
    ['hr', 'space', 'Hour height', 28, 96, 1, 'px'], ['rs', 'space', 'Sidebar row height', 18, 36, 1, 'px'], ['hh', 'space', 'Header height', 32, 64, 1, 'px'],
    ['dh', 'space', 'Day header height', 20, 48, 1, 'px'], ['ac', 'space', 'All-day chip height', 14, 28, 1, 'px'], ['gu', 'space', 'Hour gutter', 36, 72, 1, 'px'],
    ['pp', 'space', 'Pane padding', 4, 24, 1, 'px'], ['sw', 'space', 'Sidebar width', 160, 320, 1, 'px'], ['rw', 'space', 'Right column width', 220, 420, 1, 'px'],
    ['rd', 'space', 'Corner radius', 0, 12, .5, 'px'],
    ['oh', 'evc', 'One hue for all', 0, 1, 1, '', 1], ['ou', 'evc', 'Hue (one for all)', 0, 359, 1, '°', 1],
    ['eh', 'evc', 'Fill hue shift', -180, 180, 1, '°', 1], ['ec', 'evc', 'Fill chroma', 0, .16, .002, '', 1], ['el', 'evc', 'Fill lightness', .12, .92, .005, '', 1],
    ['es', 'evc', 'Fill strength', 0, 100, 1, '%', 1], ['bh', 'evc', 'Bar hue shift', -180, 180, 1, '°', 1], ['bc', 'evc', 'Bar chroma', 0, .25, .002, '', 1],
    ['bl', 'evc', 'Bar lightness', .3, .95, .005, '', 1], ['bw', 'evc', 'Bar width', 0, 6, .5, 'px'], ['tl', 'evc', 'Title lightness', .5, 1, .005, '', 1],
    ['ml', 'evc', 'Time lightness', .4, 1, .005, '', 1], ['mc', 'evc', 'Time chroma', 0, .12, .002, '', 1],
    ['cl', 'canvas', 'Canvas lightness', 0, .34, .005, '', 1], ['ch', 'canvas', 'Canvas hue', 0, 359, 1, '°', 1], ['cc', 'canvas', 'Canvas chroma', 0, .04, .001, '', 1],
    ['so', 'canvas', 'Sidebar / right offset', -.06, .06, .002, '', 1],
    ['ty', 'canvas', 'Today column lightness', 0, 12, .25, '%', 1], ['yc', 'canvas', 'Today column chroma', 0, .04, .001, '', 1], ['yh', 'canvas', 'Today column hue', 0, 359, 1, '°', 1], ['hl', 'canvas', 'Hour line', 0, 30, .5, '%', 1], ['hm', 'canvas', 'Half-hour line', 0, 12, .5, '%', 1],
    ['tw', 'tent', 'Hatch stripe width', 1, 10, .5, 'px'], ['ta', 'tent', 'Hatch angle', 0, 180, 1, '°'], ['to', 'tent', 'Hatch opacity', 0, 100, 1, '%'],
    ['do', 'tent', 'Dashed outline opacity', 0, 100, 1, '%', 1],
    ['wt', 'weights', 'Weights', 0, 2, 1, ''],
    // round h (Paper polish): pf = Paper event colours option (0 Clear tint, 1 Rich tint, 2 Tint + stronger bar, 3 round h as first shown); ps = Paper fill strength
    ['pf', 'paperopt', 'Paper colours', 0, 3, 1, '', 1], ['ps', 'paper', 'Paper fill strength', 50, 150, 1, '%', 1], // round g: 0 = 400/500/600, 1 = 400/500 only (set by the Weights decision, not shown as a slider)
  ];
  const SGROUPS = [['paper', 'Paper colours'], ['scale', 'Scale'], ['font', 'Type scale (roles)'], ['fontp', 'Advanced: per place'], ['space', 'Spacing'], ['evc', 'Event colour'], ['canvas', 'Canvas colour'], ['tent', 'Tentative']];
  const SI = Object.fromEntries(SLIDERS.map((x, i) => [x[0], i]));
  const CSL = SLIDERS.filter(x => x[7]).map(x => x[0]); // colour sliders (they change pairs)
  const EV_SL = ['oh', 'ou', 'eh', 'ec', 'el', 'es', 'bh', 'bc', 'bl', 'tl', 'ml', 'mc', 'do', 'pf', 'ps'], CAN_SL = ['cl', 'ch', 'cc', 'so', 'hl', 'hm', 'ty', 'yc', 'yh'];
  // which role step drives a place (a set per-place slider wins)
  const ROLE = { fT: 'rD', fd: 'rH', fn: 'rH', ft: 'rB', fs: 'rB', fr: 'rB', fb: 'rB', fg: 'rL', fm: 'rM', fh: 'rM', fi: 'rM' };
  const snap = (id, v) => { const [, , , lo, hi, st] = SLIDERS[SI[id]]; v = Math.min(hi, Math.max(lo, +v)); return +(Math.round((v - lo) / st) * st + lo).toFixed(4); };
  // hash form: id + value, e.g. "sc85ft11.5el.36" (ids are letters, values numbers); unknown ids are ignored
  const decodeK = str => { const K = {}; String(str || '').replace(/([a-zA-Z]+)(-?\d*\.?\d+)/g, (_, id, v) => { if (id in SI && isFinite(+v)) K[id] = snap(id, v); return ''; }); return K; };
  const encodeK = K => SLIDERS.filter(x => K[x[0]] != null).map(x => x[0] + String(+(+K[x[0]]).toFixed(4)).replace(/^(-?)0\./, '$1.')).join('');
  const kKey = (K, ids) => ids.map(i => K && K[i] != null ? K[i] : '').join(',');
  const has = (K, id) => K && K[id] != null;

  // ---------------------------------------------------------------- chrome tokens (Dark)
  const tMemo = new Map();
  function base(s) {
    const K = s.K || {}, key = [s.canvas, s.panes, s.steps, kKey(K, ['cl', 'ch', 'cc', 'so'])].join(); if (tMemo.has(key)) return tMemo.get(key);
    let c = CANV[s.canvas];
    if (has(K, 'cl') || has(K, 'ch') || has(K, 'cc') || has(K, 'so')) {
      // a slider canvas: the lever canvas's surface steps (OKLCH lightness offsets) on a new lightness / hue / chroma
      const [L0, C0, H0] = oklch(c.bg), Lc = has(K, 'cl') ? K.cl : L0, Cc = has(K, 'cc') ? K.cc : C0, Hc = has(K, 'ch') ? K.ch * Math.PI / 180 : H0;
      const at = x => C3(Math.max(0, Lc + oklch(x)[0] - L0), Cc, Hc);
      c = { bg: C3(Lc, Cc, Hc), dk: at(c.dk), lt: at(c.lt), surface: at(c.surface), raised: at(c.raised) };
      if (has(K, 'so')) c.so = C3(Math.max(0, Lc + K.so), Cc, Hc);
    }
    const t = { dark: true, bg: c.bg, surface: c.surface, raised: c.raised };
    t.rail = c.so || (s.panes === 1 ? c.dk : s.panes === 2 ? c.lt : c.bg);
    const [l1, l2, l3] = STEPS[s.steps];
    // fg1 is set by its target only (lifted to the floor where a canvas needs it, never pulled down: the cap is a real limit)
    t.fg1 = fit(greyFor(t.bg, l1), [t.bg, t.rail], W, [12, 88]);
    const L = x => mx(t.bg, t.fg1, x);
    t.hover = L(.05); t.selected = L(.085); t.hoverRail = mx(t.rail, t.fg1, .05);
    // a soft surface the main text misses on steps back toward the canvas (keeps the cap on near-black)
    for (const k of ['surface', 'raised', 'hover', 'selected', 'hoverRail']) { let q = 0, x = t[k]; const home = k === 'hoverRail' ? t.rail : t.bg; while (q < 1 && !ok2(t.fg1, x, [12, 85])) { q += .05; x = mx(t[k], home, q); } t[k] = x; }
    t.rcol = t.rail; t.hoverR = t.hoverRail; t.hdrbg = t.bg;
    const canv = [t.bg, t.rail], soft = [t.surface, t.raised, t.hover, t.selected, t.hoverRail];
    t.fg2 = fit(fit(greyFor(t.bg, l2), canv, W, [7, 68]), soft, W, [7, 63]);
    t.fg3 = l3 === l2 ? t.fg2 : fit(fit(greyFor(t.bg, l3), canv, W, [6.5, 48]), soft, W, [5.5, 45]);
    t.fg4 = mx(t.bg, t.fg1, .3);
    t.live = fit('#FF6B5F', [t.bg, t.rail, t.surface], W, [4.5, 45.5]); t.onLive = t.bg;
    t.focus = fit('#6E9BF5', [t.bg, t.raised], W, [3, 0]);
    t.ok = fit('#6CC58A', t.bg, W, [4.5, 45.5]); t.warn = fit('#E5B44A', t.bg, W, [4.5, 45.5]); t.danger = fit('#FF7B72', t.bg, W, [4.5, 45.5]);
    t.accent = t.fg1; t.onAccent = t.bg; t.ink = W;
    t.segRing = mx(t.surface, t.fg1, .4);
    t.hairStrong = (() => { let k = .14; while (wcag(L(k), t.bg) < 1.17 && k < .4) k += .01; return L(k); })();
    const cap = x => { while (x > .015 && Math.abs(apca(L(x), t.bg)) > 14.5) x -= .005; return x; };
    t.hair = L(cap(s.panes === 0 ? .1 : .075));
    t.joinBg = t.raised; t.joinFg = t.fg1;
    t.Lb = Math.max(oklch(t.bg)[0], .17);
    if (tMemo.size > 5000) tMemo.clear(); tMemo.set(key, t); return t;
  }
  function tokens(s) {
    const t = Object.assign({}, base(s)), L = x => mx(t.bg, t.fg1, x);
    t.hourc = s.hourc === 0 ? t.fg3 : s.hourc === 1 ? mx(t.fg2, t.fg3, .5) : t.fg2;
    const K = s.K || {};
    t.grid = L(has(K, 'hl') ? K.hl / 100 : HOURK[s.hourLine]);
    const cap = x => { while (x > .015 && Math.abs(apca(L(x), t.bg)) > 14.5) x -= .005; return x; };
    t.gridV = s.minor === 1 || s.minor === 3 ? L(cap(.07)) : 'transparent';
    t.gridHalf = has(K, 'hm') ? (K.hm > 0 ? L(K.hm / 100) : 'transparent') : s.minor >= 2 ? L(cap(.06)) : 'transparent';
    t.tcol = has(K, 'ty') ? K.ty > 0 : [1, 3, 4].includes(s.today);
    t.todayTint = t.tcol ? L(has(K, 'ty') ? K.ty / 100 : .035) : t.bg;
    if (t.tcol && (has(K, 'yc') || has(K, 'yh'))) { const [lt, ct, ht] = oklch(t.todayTint); t.todayTint = C3(lt, has(K, 'yc') ? K.yc : ct, has(K, 'yh') ? K.yh * Math.PI / 180 : ht); }
    t.shade = s.now === 2 || s.now === 4;
    // elapsed time: a step darker; on pure black (nothing darker exists) a step lighter
    t.elapsed = t.shade ? (relL(t.bg) < .001 ? L(.03) : mx(t.bg, '#000000', .42)) : t.bg;
    t.next = s.now >= 3;
    return t;
  }

  // ---------------------------------------------------------------- event recipe (Dark)
  // The calendar colour goes in as an OKLCH hue. Fills sit at one lightness per strength (no calendar louder than another);
  // yellows get a little more lightness and less chroma (dark yellow turns olive otherwise). Every text colour is then fitted
  // against the fills it sits on, toward white, only as far as the floors need.
  const eMemo = new Map();
  function recipe(hex, s, t) {
    const K = s.K || {}, key = [hex, s.canvas, s.steps, s.recipe, s.chroma, s.evtext, s.past, kKey(K, ['cl', 'ch', 'cc', ...EV_SL, 'bw'])].join(); if (eMemo.has(key)) return eMemo.get(key);
    let [, C0, H] = oklch(hex);
    const Hcal = H; // the calendar's own hue (the bar shift starts here too)
    if (K.oh) { H = (K.ou || 0) * Math.PI / 180; C0 = Math.max(C0, .12); } else if (has(K, 'eh')) H += K.eh * Math.PI / 180;
    const d = deg(H), yel = d > 60 && d < 118, { c, dl } = CHROMA[s.chroma];
    const CC = x => Math.min(C0, x) * (yel ? .85 : 1), Lf = t.Lb + dl + (yel ? .015 : 0);
    const F = FLOORS, rec = s.recipe;
    let fill, fillH, fillSel, bar = 'transparent', edge2 = 'transparent';
    const Hb = (K.oh ? (K.ou || 0) * Math.PI / 180 : Hcal) + (has(K, 'bh') ? K.bh * Math.PI / 180 : 0), yb = deg(Hb) > 60 && deg(Hb) < 118;
    const barC = C3(has(K, 'bl') ? K.bl : .72 + (yb ? .04 : 0), has(K, 'bc') ? Math.min(K.bc, C0 * 2.5) : CC(.07 + c * 1.1), Hb);
    if (rec === 0) { fill = C3(Lf, CC(c), H); fillH = C3(Lf + .025, CC(c * 1.1), H); fillSel = C3(Lf + .05, CC(c * 1.35), H); }
    else if (rec === 1) { fill = C3(Lf - dl * .3, CC(c * .7), H); fillH = C3(Lf - dl * .3 + .025, CC(c * .8), H); fillSel = C3(Lf + .03, CC(c * 1.1), H); bar = barC; }
    else if (rec === 2) {
      let l = .42 + (yel ? .03 : 0); const cs = CC(c * 1.5 + .02) * (yel ? .7 : 1);
      const pass = y => ok2(W, y, F.evTitle) && ok2(mx(W, y, .3), y, F.evMeta) && ok2(W, C3(oklch(y)[0] - .05, cs * 1.1, H), F.evTitle);
      fill = C3(l, cs, H); while (l > .1 && !pass(fill)) { l -= .005; fill = C3(l, cs, H); }
      fillH = C3(l + .025, cs, H); fillSel = C3(l - .05, cs * 1.1, H);
      if (!ok2(W, fillH, F.evTitle)) fillH = C3(l - .025, cs, H);
    } else if (rec === 3) { fill = t.bg; fillH = C3(t.Lb + .03, CC(c * .6), H); fillSel = C3(t.Lb + .06, CC(c * .9), H); edge2 = C3(.6 + (yel ? .04 : 0), CC(.05 + c), H); }
    else { fill = mx(t.bg, t.fg1, .075); fillH = mx(t.bg, t.fg1, .1); fillSel = C3(Lf, CC(c), H); bar = barC; edge2 = mx(t.bg, t.fg1, .12); }
    // sliders on the fill: lightness and chroma replace the normal state's (hover / selected keep their offsets), strength mixes toward the canvas
    if (has(K, 'el') || has(K, 'ec')) {
      const [Lf0, Cf0] = oklch(fill), sc = Math.min(1, Math.max(C0, .005) / .1);
      const Lt = has(K, 'el') ? K.el : Lf0, Ct = has(K, 'ec') ? K.ec * sc : Cf0;
      const re = x => { const [l, cc] = oklch(x); return C3(Math.max(0, Lt + l - Lf0), Cf0 > .002 ? Ct * cc / Cf0 : Ct, H); };
      if (rec !== 3 || has(K, 'el')) { const f0 = fill; fill = re(f0); fillH = re(fillH); fillSel = re(fillSel); }
    }
    if (has(K, 'es') && K.es < 100) { const q = K.es / 100; fill = mx(t.bg, fill, q); fillH = mx(t.bg, fillH, q); fillSel = mx(t.bg, fillSel, q); }
    if (has(K, 'bw')) bar = K.bw > 0 ? barC : 'transparent';
    // text goes toward white on dark fills and toward black on light ones (the better of the two)
    const dir = b => wcag(W, b) >= wcag('#000000', b) ? W : '#000000', TO = dir(fill);
    const on = [fill, fillH];
    let tc = s.evtext === 0 ? (rec === 2 ? mx(t.fg1, W, .4) : t.fg1) : s.evtext === 1 ? C3(.94, CC(.03), H) : C3(.92, CC(.05), H);
    if (has(K, 'tl')) tc = C3(K.tl, s.evtext === 0 ? 0 : CC(.04), H);
    if (TO !== W && !has(K, 'tl')) tc = C3(.25, CC(.05), H);
    const title = fit(tc, on, TO, F.evTitle), titleSel = fit(title, fillSel, dir(fillSel), F.evTitle);
    let meta = s.evtext === 2 ? C3(.82, CC(.07), H) : mx(title, fill, rec === 2 ? .22 : .3);
    if (has(K, 'ml') || has(K, 'mc')) { const [lm, cm] = oklch(meta); meta = C3(has(K, 'ml') ? K.ml : lm, has(K, 'mc') ? Math.min(K.mc, Math.max(C0, .01) * 2) : cm, H); }
    // design targets a little above the floors: time Lc ≥ 63 (brief §5 measured 63–70), past time Lc ≥ 50
    const TM = [6.5, 63], TP = [5.7, 58], TPT = [9, 72]; // round g: past text a clear step above the floors ("the contrast is really bad on some things")
    const TMk = has(K, 'ml') || has(K, 'mc') ? [6.55, 60.6] : TM; // a slider time colour only moves as far as the floor needs
    meta = fit(fit(meta, on, s.evtext === 2 || has(K, 'ml') || has(K, 'mc') ? TO : title, TMk), on, TO, TMk);
    const metaSel = fit(fit(mx(meta, fillSel, .04), fillSel, title, [5.5, 58]), fillSel, dir(fillSel), [5.5, 58]);
    // past and declined
    const fillPast = s.past === 0 ? mx(fill, t.bg, .55) : s.past === 1 ? mx(fill, t.bg, .85) : s.past === 2 ? mx(t.bg, t.fg1, .05) : fill;
    const pd = dir(fillPast), titlePast = fit(pd === W ? mx(t.fg2, title, .1) : mx('#3A3A40', title, .1), fillPast, pd, TPT), metaPast = fit(pd === W ? t.fg3 : '#55555C', fillPast, pd, TP);
    const fillDec = mx(fill, t.bg, .5), dd = dir(fillDec), titleDec = fit(dd === W ? t.fg2 : '#3A3A40', fillDec, dd, F.evDecl);
    const yc = deg(Hcal) > 60 && deg(Hcal) < 118, mark = C3(.7 + (yc ? .05 : 0), Math.min(oklch(hex)[1], .14) * (yc ? .85 : 1), Hcal);
    const edge = fit(C3(.68 + (yel ? .04 : 0), CC(.12), H), t.bg, W, [3, 0]);
    const dash = has(K, 'do') ? mx(t.bg, edge, K.do / 100) : edge;
    const r = { dash, cc: rec === 3 ? edge2 : bar !== 'transparent' ? bar : mark, mark, fill, fill2: fill, fillH, fillSel, title, titleSel, meta, metaSel,
      fillPast, titlePast, metaPast, fillDec, titleDec, bar, barPast: bar === 'transparent' ? bar : mx(bar, fillPast, .55), edge, edge2, edge2Past: edge2 === 'transparent' ? edge2 : mx(edge2, t.bg, .55) };
    if (eMemo.size > 400000) eMemo.clear(); eMemo.set(key, r); return r;
  }
  // all-day chips without a fill (Dot + text, Bar + text): text on the canvas
  const aMemo = new Map();
  function chip(hex, s, t) {
    const e = recipe(hex, s, t); if (!s.allday) return e;
    const key = [hex, s.canvas, s.steps, s.evtext, s.allday, kKey(s.K, ['cl', 'ch', 'cc', ...EV_SL, 'bw'])].join(); if (aMemo.has(key)) return aMemo.get(key);
    const F = FLOORS, fill = t.bg, fillH = t.hover;
    const tc = s.evtext === 0 ? t.fg1 : e.title;
    const title = fit(tc, [fill, fillH], W, F.evTitle), meta = fit(t.fg2, [fill, fillH], W, [6.5, 63]);
    const r = { ...e, fill, fill2: fill, fillH, fillSel: t.selected, title, titleSel: fit(title, t.selected, W, F.evTitle), meta, metaSel: fit(meta, t.selected, W, F.evSelMeta),
      fillPast: fill, titlePast: fit(t.fg2, fill, W, [9, 72]), metaPast: fit(t.fg3, fill, W, [5.7, 58]), fillDec: fill, titleDec: fit(t.fg2, fill, W, F.evDecl), bar: e.mark, barPast: mx(e.mark, t.bg, .5) };
    if (aMemo.size > 100000) aMemo.clear(); aMemo.set(key, r); return r;
  }

  // ---------------------------------------------------------------- every Dark pair of a design (the proof and the rail use the same list)
  // which: 'chrome' (canvas, panes, steps, hour labels, lines, today, now) · 'events' (canvas, steps, recipe, strength, text, past, all-day) · 'all'
  function pairs(s, hues, which = 'all', th = 'dark') {
    if (th === 'paper') return pairsP(s, hues, which);
    const t = tokens(s), P = [], A = (what, fg, bg, key) => P.push([what, fg, bg, key, 'dark']);
    if (which !== 'events') {
      for (const [n, b] of [['bg', t.bg], ['rail', t.rail]]) { A(`fg1 on ${n}`, t.fg1, b, relL(b) < .01 ? 'fg1' : 'fg1soft'); A(`fg2 on ${n}`, t.fg2, b, 'fg2'); A(`fg3 on ${n}`, t.fg3, b, 'fg3'); }
      const soft = [['surface', t.surface], ['raised', t.raised], ['hover', t.hover], ['hover on rail', t.hoverRail], ['selected', t.selected]];
      if (t.tcol) soft.push(['today column', t.todayTint]);
      for (const [n, b] of soft) { A(`fg1 on ${n}`, t.fg1, b, 'fg1soft'); A(`fg2 on ${n}`, t.fg2, b, 'fg2soft'); A(`fg3 on ${n}`, t.fg3, b, 'fg3soft'); }
      A('hour labels on bg', t.hourc, t.bg, 'fg3');
      A('today date / primary button', t.onAccent, t.accent, 'accent');
      A('now pill text on live red', t.onLive, t.live, 'live');
      for (const [n, b] of [['bg', t.bg], ['rail', t.rail], ['card', t.surface]]) A(`live text on ${n}`, t.live, b, 'live');
      A('now line vs bg', t.live, t.bg, 'nontext');
      if (t.shade) A('now line vs elapsed shade', t.live, t.elapsed, 'nontext');
      A('focus ring vs bg', t.focus, t.bg, 'nontext'); A('focus ring vs raised', t.focus, t.raised, 'nontext');
      A('selected segment edge vs track', t.segRing, t.surface, 'nontext');
      for (const [n, h] of [['ok', t.ok], ['warn', t.warn], ['danger', t.danger]]) A(`${n} text on bg`, h, t.bg, 'status');
      A('hour line on bg', t.grid, t.bg, 'structure');
      if (t.tcol) A('hour line on today column', t.grid, t.todayTint, 'structure');
      if (t.shade) A('hour line on elapsed shade', t.grid, t.elapsed, 'structure');
      if (t.gridHalf !== 'transparent') A('half-hour line', t.gridHalf, t.bg, 'decor');
      if (t.gridV !== 'transparent') A('day divider', t.gridV, t.bg, 'decor');
      A('all-day edge', t.hairStrong, t.bg, 'structure'); A('pane edge', t.hair, t.bg, 'decor');
      A('Join button text', t.joinFg, t.joinBg, 'accent');
    }
    if (which !== 'chrome') for (const h of hues) {
      const list = [['', recipe(h, s, t)]]; if (s.allday) list.push(['all-day ', chip(h, s, t)]);
      for (const [pre, e] of list) {
        A(`${pre}event title · ${h}`, e.title, e.fill, 'evTitle'); A(`${pre}event time · ${h}`, e.meta, e.fill, 'evMeta');
        A(`${pre}title on hover · ${h}`, e.title, e.fillH, 'evTitle'); A(`${pre}time on hover / hatch · ${h}`, e.meta, e.fillH, 'evMeta');
        A(`${pre}selected title · ${h}`, e.titleSel, e.fillSel, 'evTitle'); A(`${pre}selected time · ${h}`, e.metaSel, e.fillSel, 'evSelMeta');
        A(`${pre}past title · ${h}`, e.titlePast, e.fillPast, 'evPastTitle'); A(`${pre}past time · ${h}`, e.metaPast, e.fillPast, 'evPastMeta');
        A(`${pre}declined title · ${h}`, e.titleDec, e.fillDec, 'evDecl');
        if (!pre) A(`needs-reply outline / next ring vs bg · ${h}`, e.edge, t.bg, 'nontext');
        if (!pre && has(s.K, 'do')) A(`maybe dashed outline vs bg · ${h}`, e.dash, t.bg, 'nontext');
      }
    }
    return P;
  }
  // the guard (same floors as contrast.mjs): a design is reachable only if every pair passes
  // ---------------------------------------------------------------- Paper (round h): derived from the locked Dark rules
  // A neutral near-white canvas (no cast), the same structure: panes step, today column (fg tint), lines as bg → fg1 mixes, hatch.
  // Events: the Dark event's hue and chroma as a light tint at one lightness; titles neutral (fg1) or a deep hue, times a mid hue,
  // every text colour fitted toward black only as far as the Paper floors need (a little above them).
  const BK = '#000000', okP = (fg, bg, f) => wcag(fg, bg) >= f[0] + .05 && Math.abs(apca(fg, bg)) >= f[1] + .6;
  const pMemo = new Map();
  function tokensP(s) {
    const K = s.K || {}, key = [s.panes, s.steps, s.hourc, s.hourLine, s.minor, s.today, s.now, kKey(K, ['hl', 'hm', 'ty', 'yc', 'yh'])].join();
    if (pMemo.has(key)) return pMemo.get(key);
    const t = { dark: false, bg: '#FBFBFB', surface: '#F1F1F2', raised: '#FFFFFF', ink: BK };
    t.rail = s.panes === 1 ? '#F4F4F5' : s.panes === 2 ? '#FFFFFF' : t.bg;
    const canv = [t.bg, t.rail, t.raised];
    t.fg1 = fit('#1D1D20', canv, BK, [12, 95]);
    const L = x => mx(t.bg, t.fg1, x);
    t.hover = L(.045); t.selected = L(.075); t.hoverRail = mx(t.rail, t.fg1, .045);
    const soft = [t.surface, t.hover, t.selected, t.hoverRail];
    t.fg1 = fit(t.fg1, soft, BK, [12, 88]);
    t.fg2 = fit(fit('#4A4A50', canv, BK, [7, 80]), soft, BK, [7, 75]);
    t.fg3 = s.steps === 3 ? t.fg2 : fit(fit('#606067', canv, BK, [5, 70]), soft, BK, [5, 65]);
    t.fg4 = mx(t.bg, t.fg1, .3);
    t.live = fit('#C9372C', [t.bg, t.rail, t.surface], BK, [4.5, 60]); t.onLive = '#FFFFFF';
    while (!okP(t.onLive, t.live, [4.5, 60])) t.live = mx(t.live, BK, .03);
    t.focus = fit('#2F6BDC', [t.bg, t.raised], BK, [3, 0]);
    t.ok = fit('#2F7A4B', t.bg, BK, [4.5, 60]); t.warn = fit('#8A5A00', t.bg, BK, [4.5, 60]); t.danger = fit('#B4382D', t.bg, BK, [4.5, 60]);
    t.accent = t.fg1; t.onAccent = t.bg;
    t.segRing = mx(t.surface, t.fg1, .5);
    const raise = k => { while (wcag(L(k), t.bg) < 1.17 && k < .4) k += .005; return L(k); };
    const cap = x => { while (x > .015 && Math.abs(apca(L(x), t.bg)) > 14.5) x -= .005; return x; };
    t.hairStrong = raise(.14); t.hair = L(cap(.085));
    t.hourc = s.hourc === 0 ? t.fg3 : s.hourc === 1 ? mx(t.fg2, t.fg3, .5) : t.fg2;
    t.tcol = has(K, 'ty') ? K.ty > 0 : [1, 3, 4].includes(s.today);
    t.todayTint = t.tcol ? L(has(K, 'ty') ? Math.min(K.ty, 8) / 100 : .035) : t.bg;
    if (t.tcol && (has(K, 'yc') || has(K, 'yh'))) { const [lt, ct, ht] = oklch(t.todayTint); t.todayTint = C3(lt, Math.min(has(K, 'yc') ? K.yc : ct, .03), has(K, 'yh') ? K.yh * Math.PI / 180 : ht); }
    t.shade = s.now === 2 || s.now === 4; t.elapsed = t.shade ? mx(t.bg, BK, .035) : t.bg; t.next = s.now >= 3;
    // the hour line is raised until it reads on every ground it crosses (canvas, today column, elapsed shade)
    const gk = has(K, 'hl') ? K.hl / 100 : HOURK[s.hourLine], gOk = k => [t.bg, t.todayTint, t.elapsed].every(b => wcag(L(k), b) >= 1.17);
    let kk = gk; while (!gOk(kk) && kk < .4) kk += .005; t.grid = L(kk);
    t.gridV = s.minor === 1 || s.minor === 3 ? L(cap(.07)) : 'transparent';
    t.gridHalf = has(K, 'hm') ? (K.hm > 0 ? L(cap(K.hm / 100)) : 'transparent') : s.minor >= 2 ? L(cap(.06)) : 'transparent';
    t.joinBg = '#FFFFFF'; t.joinFg = t.fg1; t.rcol = t.rail; t.hoverR = t.hoverRail; t.hdrbg = t.bg;
    if (pMemo.size > 5000) pMemo.clear(); pMemo.set(key, t); return t;
  }
  // Paper event-colour options (round h polish); v = minimum ΔE_OK of the fill against the canvas (×100), bl / bc / bw = bar lightness, chroma factor, width
  const PF = [{ id: 'clear', l: 'Clear tint', v: 9, bl: .57, bc: 1.15, bw: 4 }, { id: 'rich', l: 'Rich tint', v: 13, bl: .58, bc: 1.05, bw: 3.5 },
    { id: 'bar', l: 'Tint + stronger bar', v: 6.5, bl: .5, bc: 1.3, bw: 5 }, null];
  const pfOf = K => K && K.pf != null ? K.pf : 0;
  const lab = h => { const [L, C, H] = oklch(h); return [L, C * Math.cos(H), C * Math.sin(H)]; };
  const deOK = (a, b) => { const x = lab(a), y = lab(b); return Math.hypot(x[0] - y[0], x[1] - y[1], x[2] - y[2]) * 100; };
  const rpMemo = new Map();
  function recipeP(hex, s, tp) {
    const K = s.K || {}, key = [hex, s.canvas, s.steps, s.recipe, s.chroma, s.evtext, s.past, s.panes, kKey(K, ['cl', 'ch', 'cc', ...EV_SL, 'bw'])].join();
    if (rpMemo.has(key)) return rpMemo.get(key);
    const td = tokens(s), d = recipe(hex, s, td), rec = s.recipe;
    const [, C0, Hcal] = oklch(hex), dfill = rec === 3 || rec === 4 ? d.fillSel : d.fill, [, Cd, Hd] = oklch(dfill);
    const yel = deg(Hd) > 60 && deg(Hd) < 118, C = Math.min(Cd * 1.1, .075) * (yel ? .9 : 1), Lf = rec === 1 ? .95 : rec === 2 ? .9 : .935;
    let fill, fillH, fillSel, edge2 = 'transparent';
    if (rec === 3) { fill = tp.bg; fillH = C3(.955, C * .6, Hd); fillSel = C3(.93, C * .8, Hd); }
    else if (rec === 4) { fill = '#FFFFFF'; fillH = mx('#FFFFFF', tp.fg1, .03); fillSel = C3(.94, C, Hd); edge2 = mx(tp.bg, tp.fg1, .12); }
    else if (!PF[pfOf(K)]) { fill = C3(Lf, C, Hd); fillH = C3(Lf - .02, C * 1.1, Hd); fillSel = C3(Lf - .045, C * 1.25, Hd); }
    else {
      // round h polish: every hue gets the same visibility against the canvas (ΔE_OK ≥ V), reached by lowering L and raising chroma together,
      // so pale hues (lavender, grape, graphite) get more ink and saturated ones (yellow, tangerine) stay light
      const o = PF[pfOf(K)], V = o.v * (has(K, 'ps') ? K.ps / 100 : 1), Cc = Math.min(K.oh ? .16 : C0 < .015 ? C0 : Math.max(C0 * 1.25, .075), .16), Hf = Hd; // muted hues (Slate, Lavender) get chroma enough to read as their hue
      // a share of the calendar's own lightness is kept, so neighbours of one hue (Basil / Sage, Tomato / Flamingo) stay apart
      const L0 = oklch(hex)[0], off = Math.max(-.03, Math.min(.03, (L0 - .66) * .45)), Vh = V * Math.max(.85, Math.min(1.25, 1 + (.66 - L0) * 2.2));
      let t = 0, x; do { x = C3(Math.min(.975, .975 - .25 * t + off), Cc * (.12 + .62 * t), Hf); t += .01; } while (t < 1.6 && deOK(x, tp.bg) < Vh);
      fill = x; const [lf, cf] = oklch(fill);
      fillH = C3(lf - .022, cf * 1.08, Hf); fillSel = C3(lf - .05, cf * 1.22, Hf);
      // a fill never gets so dark that near-black text misses the Paper floors (Lc 75 needs a light ground): lift L until it passes
      const lift = y => { let [l, c] = oklch(y); while (l < .99 && !okP(BK, y, [7.4, 78.5])) { l += .005; y = C3(l, c, Hf); } return y; };
      fill = lift(fill); fillH = lift(fillH); fillSel = lift(fillSel);
    }
    if (has(K, 'es') && K.es < 100) { const q = K.es / 100; fill = mx(tp.bg, fill, q); fillH = mx(tp.bg, fillH, q); fillSel = mx(tp.bg, fillSel, q); }
    const barD = d.bar !== 'transparent' ? d.bar : null, po = PF[pfOf(K)];
    const bar = barD ? (() => { const [, cb, hb] = oklch(barD); if (!po) return C3(.6, Math.min(cb, .17), hb);
      const yb = deg(hb) > 60 && deg(hb) < 118; return C3(po.bl + (yb ? .1 : 0), Math.min(Math.max(C0, cb) * po.bc, .22), hb); })() : 'transparent';
    if (rec === 3) edge2 = C3(.62, Math.min(C0, .05 + CHROMA[s.chroma].c), Hd);
    const on = [fill, fillH];
    const tc = s.evtext === 0 ? tp.fg1 : C3(.3, Math.min(C * 1.4, .08), Hd);
    const title = fit(tc, on, BK, [7.4, 78]), titleSel = fit(title, fillSel, BK, [7.4, 78]);
    const meta = fit(fit(s.evtext === 2 || has(K, 'mc') ? C3(.45, Math.min(C * 1.2, .07), Hd) : mx(title, fill, .3), on, title, [6.1, 71]), on, BK, [6.1, 71]);
    const metaSel = fit(mx(meta, fillSel, .04), fillSel, BK, [5.7, 66]);
    const fillPast = s.past === 0 ? mx(fill, tp.bg, .6) : s.past === 1 ? mx(fill, tp.bg, .85) : s.past === 2 ? mx(tp.bg, tp.fg1, .04) : fill;
    const titlePast = fit(mx(tp.fg2, title, .15), fillPast, BK, [8, 78]), metaPast = fit(tp.fg3, fillPast, BK, [5.4, 68]);
    const fillDec = mx(fill, tp.bg, .45), titleDec = fit(tp.fg2, fillDec, BK, [6.8, 76]);
    const mark = C3(.6, Math.min(C0, .14), Hcal), edge = fit(C3(.56, Math.min(C0, .13), Hd), tp.bg, BK, [3, 0]);
    const dash = has(K, 'do') ? mx(tp.bg, edge, K.do / 100) : edge;
    const r = { dash, cc: rec === 3 ? edge2 : bar !== 'transparent' ? bar : mark, mark, fill, fill2: fill, fillH, fillSel, title, titleSel, meta, metaSel, fillPast, titlePast, metaPast, fillDec, titleDec,
      bar, barPast: bar === 'transparent' ? bar : mx(bar, fillPast, .5), edge, edge2, edge2Past: edge2 === 'transparent' ? edge2 : mx(edge2, tp.bg, .55) };
    if (rpMemo.size > 200000) rpMemo.clear(); rpMemo.set(key, r); return r;
  }
  function chipP(hex, s, tp) {
    const e = recipeP(hex, s, tp); if (!s.allday) return e;
    const fill = tp.bg, fillH = tp.hover, title = fit(tp.fg1, [fill, fillH], BK, [7.4, 78]), meta = fit(tp.fg2, [fill, fillH], BK, [6.1, 71]);
    return { ...e, fill, fill2: fill, fillH, fillSel: tp.selected, title, titleSel: fit(title, tp.selected, BK, [7.4, 78]), meta, metaSel: fit(meta, tp.selected, BK, [5.7, 66]),
      fillPast: fill, titlePast: fit(tp.fg2, fill, BK, [8, 78]), metaPast: fit(tp.fg3, fill, BK, [5.4, 68]), fillDec: fill, titleDec: fit(tp.fg2, fill, BK, [6.8, 76]), bar: e.mark, barPast: mx(e.mark, tp.bg, .5) };
  }
  function pairsP(s, hues, which) {
    const t = tokensP(s), P = [], A = (what, fg, bg, key) => P.push([what, fg, bg, key, 'paper']);
    if (which !== 'events') {
      for (const [n, b] of [['bg', t.bg], ['rail', t.rail], ['raised', t.raised]]) { A(`fg1 on ${n}`, t.fg1, b, 'fg1'); A(`fg2 on ${n}`, t.fg2, b, 'fg2'); A(`fg3 on ${n}`, t.fg3, b, 'fg3'); }
      const soft = [['surface', t.surface], ['hover', t.hover], ['hover on rail', t.hoverRail], ['selected', t.selected]];
      if (t.tcol) soft.push(['today column', t.todayTint]);
      for (const [n, b] of soft) { A(`fg1 on ${n}`, t.fg1, b, 'fg1soft'); A(`fg2 on ${n}`, t.fg2, b, 'fg2soft'); A(`fg3 on ${n}`, t.fg3, b, 'fg3soft'); }
      A('hour labels on bg', t.hourc, t.bg, 'fg3');
      A('today date / primary button', t.onAccent, t.accent, 'accent');
      A('now pill text on live red', t.onLive, t.live, 'live');
      for (const [n, b] of [['bg', t.bg], ['rail', t.rail], ['card', t.surface]]) A(`live text on ${n}`, t.live, b, 'live');
      A('now line vs bg', t.live, t.bg, 'nontext'); if (t.shade) A('now line vs elapsed shade', t.live, t.elapsed, 'nontext');
      A('focus ring vs bg', t.focus, t.bg, 'nontext'); A('focus ring vs raised', t.focus, t.raised, 'nontext');
      A('selected segment edge vs track', t.segRing, t.surface, 'nontext');
      for (const [n, h] of [['ok', t.ok], ['warn', t.warn], ['danger', t.danger]]) A(`${n} text on bg`, h, t.bg, 'status');
      A('hour line on bg', t.grid, t.bg, 'structure');
      if (t.tcol) A('hour line on today column', t.grid, t.todayTint, 'structure');
      if (t.shade) A('hour line on elapsed shade', t.grid, t.elapsed, 'structure');
      if (t.gridHalf !== 'transparent') A('half-hour line', t.gridHalf, t.bg, 'decor');
      if (t.gridV !== 'transparent') A('day divider', t.gridV, t.bg, 'decor');
      A('all-day edge', t.hairStrong, t.bg, 'structure'); A('pane edge', t.hair, t.bg, 'decor');
      A('Join button text', t.joinFg, t.joinBg, 'accent');
    }
    if (which !== 'chrome') for (const h of hues) {
      const list = [['', recipeP(h, s, t)]]; if (s.allday) list.push(['all-day ', chipP(h, s, t)]);
      for (const [pre, e] of list) {
        A(`${pre}event title · ${h}`, e.title, e.fill, 'evTitle'); A(`${pre}event time · ${h}`, e.meta, e.fill, 'evMeta');
        A(`${pre}title on hover · ${h}`, e.title, e.fillH, 'evTitle'); A(`${pre}time on hover / hatch · ${h}`, e.meta, e.fillH, 'evMeta');
        A(`${pre}selected title · ${h}`, e.titleSel, e.fillSel, 'evTitle'); A(`${pre}selected time · ${h}`, e.metaSel, e.fillSel, 'evSelMeta');
        A(`${pre}past title · ${h}`, e.titlePast, e.fillPast, 'evPastTitle'); A(`${pre}past time · ${h}`, e.metaPast, e.fillPast, 'evPastMeta');
        A(`${pre}declined title · ${h}`, e.titleDec, e.fillDec, 'evDecl');
        if (!pre) A(`needs-reply outline / next ring vs bg · ${h}`, e.edge, t.bg, 'nontext');
        if (!pre && has(s.K, 'do')) A(`maybe dashed outline vs bg · ${h}`, e.dash, t.bg, 'nontext');
      }
    }
    return P;
  }
  let HUE0 = null; const setHues = h => { HUE0 = h; gMemo.clear(); };
  const HUES = () => HUE0 ? HUE0 : typeof CALS0 !== 'undefined' ? [...new Set([...Object.values(CALS0).map(c => c.hex.toUpperCase()), ...SWATCHES.map(x => x[0].toUpperCase())])] : [];
  const gMemo = new Map();
  function verdict(s, which = 'all', hues = HUES()) {
    const key = (which === 'chrome' ? CHROME_K : which === 'events' ? EVENT_K : LEVERS.map(x => x.k)).map(k => s[k]).join() + which + '|' + kKey(s.K, CSL) + '|' + hues.length;
    if (gMemo.has(key)) return gMemo.get(key);
    let worst = null, fail = null, n = 0;
    for (const th of ['dark', 'paper']) for (const [what0, fg, bg, k] of pairs(s, hues, which, th)) { const what = th === 'paper' ? 'Paper · ' + what0 : what0; n++; const g = grade(fg, bg, k, th); if (!g.ok && !fail) fail = { what, fg, bg, k, th, ...g }; if (th === 'dark' && (!worst || g.m < worst.m)) worst = { what, fg, bg, k, th, ...g }; }
    const v = { ok: !fail, fail, worst, n }; if (gMemo.size > 30000) gMemo.clear(); gMemo.set(key, v); return v;
  }
  const passes = (code, K) => { const s = typeof code === 'string' ? { ...decode(code), K: K || {} } : code; return verdict(s, 'chrome').ok && verdict(s, 'events').ok; };

  // ---------------------------------------------------------------- presets (the iterations; each names the rules it applies)
  const P = (o) => encode(Object.assign(decode(''), o));
  const PRESETS = [
    { id: 'R1', l: 'Graphite calm', idea: 'Brief direction A: graphite canvas, one surface, soft tint without a bar, three APCA greys, quiet chrome.',
      rules: '§1 dark targets · §5 recipe (tint, no bar in dark) · §6 A · §3.3 one surface',
      s: { canvas: 0, panes: 0, steps: 1, hourc: 0, recipe: 0, chroma: 1, evtext: 1, allday: 0, size: 2, weight: 2, font: 0, chrome: 1, hourLine: 1, minor: 0, past: 0, today: 0, now: 0, tent: 0 } },
    { id: 'R2', l: 'OLED stepped', idea: 'Brief direction B: true black, surfaces step up for sidebars, fg1 held at Lc 92 against halation, bar + soft tint, clear hour labels.',
      rules: '§1 halation (OLED with fg1 ≈ #E6) · §6 B structured contrast · §3.3 surface step',
      s: { canvas: 2, panes: 2, steps: 1, hourc: 2, recipe: 1, chroma: 2, evtext: 0, allday: 2, size: 2, weight: 2, font: 0, chrome: 1, hourLine: 2, minor: 0, past: 0, today: 1, now: 1, tent: 0 } },
    { id: 'R3', l: 'Dim solid', idea: 'Dim grey (#1C1C1E) leaves room for crisper text (no cap) and carries muted solid fills with near-white titles; red today.',
      rules: '§1 (dim grey: no halation cap) · §5 recipe (muted solid) · §3.2 colour once',
      s: { canvas: 4, panes: 1, steps: 1, hourc: 1, recipe: 2, chroma: 1, evtext: 0, allday: 0, size: 2, weight: 2, font: 1, chrome: 1, hourLine: 1, minor: 0, past: 1, today: 2, now: 0, tent: 1 } },
    { id: 'R4', l: 'Notion quiet', idea: 'Notion-sized type (11 / 10.5 events, 16 px title), #191919, darker sidebars, dot chips in the all-day lane, red date; the calmest page.',
      rules: '§2 small dense type · §3 reference apps (Notion: soft fill, faint grid) · §3.2 dot chips',
      s: { canvas: 3, panes: 1, steps: 0, hourc: 0, recipe: 0, chroma: 1, evtext: 0, allday: 1, size: 0, weight: 2, font: 0, chrome: 0, hourLine: 1, minor: 0, past: 0, today: 2, now: 0, tent: 0 } },
    { id: 'R5', l: 'Two greys', idea: 'Fewer text levels: fg1 for what you read, one grey (Lc 72) for everything else; system font, calm chrome, bar + tint.',
      rules: '§3.4 at most 3 greys (here 2) · §1 fg2 ≥ Lc 68 doubles as label grey · §2 one family (SF)',
      s: { canvas: 0, panes: 1, steps: 3, hourc: 0, recipe: 1, chroma: 1, evtext: 1, allday: 1, size: 1, weight: 2, font: 1, chrome: 0, hourLine: 1, minor: 0, past: 0, today: 0, now: 0, tent: 0 } },
    { id: 'R6', l: 'Timetable', idea: 'For reading at a glance: ink canvas, strong hour lines, dotted half hours and day dividers, fg2 hour labels, crisp text, brief type scale.',
      rules: '§6 B (visible grid, strong time column) · §3.3 lines (half hours dotted, decor ≤ Lc 15) · §1 crisp step',
      s: { canvas: 1, panes: 1, steps: 2, hourc: 2, recipe: 1, chroma: 2, evtext: 0, allday: 0, size: 2, weight: 2, font: 0, chrome: 2, hourLine: 3, minor: 3, past: 0, today: 0, now: 1, tent: 0 } },
    { id: 'R7', l: 'Colour once', idea: 'Calendar identity without colour overload: neutral cards, the hue only as a 3 px bar; past events turn grey, all-day chips are dots.',
      rules: '§3.2 colour means calendar, once · §5 states (past = neutral fill) · §3.1 events lead, chrome grey',
      s: { canvas: 0, panes: 0, steps: 1, hourc: 0, recipe: 4, chroma: 2, evtext: 0, allday: 1, size: 2, weight: 2, font: 0, chrome: 1, hourLine: 1, minor: 0, past: 2, today: 0, now: 0, tent: 0 } },
    { id: 'R8', l: 'Now & next', idea: 'Easy to understand: today\'s column is tinted, time already gone is shaded, the next event has a ring, past events ghost out.',
      rules: '§3.6 today once, strongly · §3.2 one alert hue · §5 states (past fill steps back) · user: clear past / now / next',
      s: { canvas: 0, panes: 1, steps: 1, hourc: 1, recipe: 0, chroma: 2, evtext: 1, allday: 0, size: 2, weight: 2, font: 0, chrome: 1, hourLine: 2, minor: 0, past: 1, today: 1, now: 4, tent: 0 } },
    { id: 'R9', l: 'Outline airy', idea: 'Lowest ink: events as 1 px hue outlines on dim grey with hue text, Geist, dotted half hours, bold today on a tinted column.',
      rules: '§5 recipe (outline; needs reply becomes dashed) · §2 Geist narrower · §3.3 dotted half hour',
      s: { canvas: 4, panes: 0, steps: 1, hourc: 0, recipe: 3, chroma: 2, evtext: 2, allday: 1, size: 1, weight: 2, font: 2, chrome: 0, hourLine: 1, minor: 2, past: 0, today: 4, now: 3, tent: 3 } },
    // round e: the user's pick (link of 2026-11-20: R6 edited) and a slider-tuned variant that matches their Notion-like close-up
    { id: 'R10p', l: 'R10 (previous)', idea: 'Your pick: ink canvas, darker sidebars, crisp text and clear hour labels, bar + rich tint, Notion-sized Geist type, calm chrome, day dividers, today column, week line, hatch.',
      rules: '§1 crisp step · §6 B hour labels · §2 small type, one family · §3.6 today column · §3.7 hatch',
      s: { canvas: 1, panes: 1, steps: 2, hourc: 2, recipe: 1, chroma: 3, evtext: 0, allday: 0, size: 0, weight: 2, font: 2, chrome: 0, hourLine: 1, minor: 1, past: 0, today: 1, now: 1, tent: 1 } },
    { id: 'R10', l: 'Mine', idea: 'Your current link (round g): R10 levers with your sliders: 12 / 10.5 px events, 18.5 px title, a deeper navy fill (L .29, C .074), a 3.5 px bright bar, white titles, light blue-grey times, a near-black canvas (OKLCH L .15).',
      rules: '§5 recipe (fill + bar) · §1 title Lc ≥ 75 / time Lc ≥ 60 fitted · §0 OKLCH fills · §2 Geist',
      s: { canvas: 1, panes: 1, steps: 2, hourc: 2, recipe: 1, chroma: 3, evtext: 0, allday: 0, size: 0, weight: 2, font: 2, chrome: 0, hourLine: 1, minor: 1, past: 0, today: 1, now: 1, tent: 1 },
      k: 'ft12fm10.5fh11fd12.5fT18.5rd4.5ec.074el.29bc.25bl.7bw3.5tl1ml.89mc.062cl.15' },
    { id: 'R11', l: 'Muted navy', idea: 'R10 tuned with the sliders to your close-up: a muted navy fill (OKLCH L .37, C .045), a 3 px flush bright bar (L .65, C .15), white title, blue-grey time, radius 6, #1A1A1A canvas.',
      rules: '§5 recipe (fill + bar, one decoration) · §1 title Lc ≥ 75 / time Lc ≥ 60 fitted · §0 OKLCH, one lightness for every calendar',
      s: { canvas: 1, panes: 1, steps: 2, hourc: 2, recipe: 1, chroma: 3, evtext: 0, allday: 0, size: 0, weight: 2, font: 2, chrome: 0, hourLine: 1, minor: 1, past: 0, today: 1, now: 1, tent: 1 },
      k: 'el.37ec.046bl.65bc.15bw3tl.955ml.685mc.044rd6cl.215cc0' },
  ].map(p => ({ ...p, code: P(p.s), k: p.k ? encodeK(decodeK(p.k)) : '' }));
  // round h (2026-11-20): LOCKED. R10 · Mine with the type scale "Three sizes, weight for rank" (15 / 12 / 12 / 12 / 11) and weights 400 / 500 / 600.
  // The round-g link stays as "R10 (round g link)" for Unlock to compare.
  const LOCKED = { preset: 'R10', scale: 'three', weights: 0, date: '2026-11-20',
    quote: 'calm 3 sizes lgtm. now lets lock these in', picked: 'Three sizes, weight for rank · 15 / 12 / 12 / 11', paper: 'derived from the locked Dark rules' };

  // ---------------------------------------------------------------- the DESIGNER options that give the shape
  function dzOpts(s) {
    const o = DZ.decode('-');
    Object.assign(o, { canvas: s.canvas === 2 ? 4 : s.canvas === 4 ? 6 : 0, palette: 0, accent: 0, fill: s.recipe === 3 ? 0 : s.recipe === 4 ? 7 : s.recipe === 2 ? 5 : 2,
      bar: s.recipe === 1 ? 4 : s.recipe === 4 ? 2 : 0, edge: s.recipe === 4 ? 1 : 0, radius: s.recipe === 4 ? 3 : 2, title: 0, tcol: 0, weight: 2, size: 1,
      font: s.font, time: 0, extras: 0, gap: 2, density: 1, head: 0, grid: s.minor >= 2 ? 2 : 0, div: s.minor === 1 || s.minor === 3 ? 0 : 1,
      today: [0, 0, 2, 2, 4][s.today], now: s.now === 1 ? 0 : 1, past: 1, maybe: [1, 0, 2, 3][s.tent], decl: s.tent === 3 ? 1 : 0, allday: [0, 2, 5][s.allday],
      halfStyle: 1, hourc: 0 });
    if (s.K && s.K.bw > 0) o.bar = 2;
    if (s.K && s.K.hm > 0 && o.grid !== 2) o.grid = 2;
    const [a, b, c, d, e, f, g, h] = CHROME[s.chrome];
    Object.assign(o, { fsTitle: a, fsDay: b, fsHour: c, fsSide: d, fsGroup: e, fsMini: f, fsRight: g, fsPanel: h });
    return o;
  }
  const evVars = c => `--dash:${c.dash || c.edge};--cc:${c.cc};--bar:${c.bar};--barp:${c.barPast};--dot:${c.mark};--fill:${c.fill};--fill2:${c.fill2};--fillh:${c.fillH};--fills:${c.fillSel};--fillp:${c.fillPast};` +
    `--tc:${c.title};--tcs:${c.titleSel};--mc:${c.meta};--mcs:${c.metaSel};--tcp:${c.titlePast};--mcp:${c.metaPast};--decfill:${c.fillDec};--dectc:${c.titleDec};--line:${c.edge};--edge2:${c.edge2};--edge2p:${c.edge2Past || c.edge2}`;

  // the value a slider shows while it follows its lever ("auto"); colour autos are read off the Personal blue sample
  const FS = { fsTitle: [15, 16, 18, 20, 22, 24], fsDay: [11, 12, 13, 14], fsHour: [10, 10.5, 11, 12], fsSide: [12, 13, 14], fsRight: [12, 13, 14] };
  function auto(id, s) {
    const ch = CHROME[s.chrome], [fs, fsm] = SIZE[s.size];
    const fixed = { sc: 100, fb: 13, ft: fs, fm: fsm, fg: 11, fn: 11, fi: 11, rD: FS.fsTitle[ch[0]], rH: FS.fsDay[ch[1]], rB: fs, rL: 11, rM: fsm, ty: [1, 3, 4].includes(s.today) ? 3.5 : 0, yc: 0, yh: 0, fh: FS.fsHour[ch[2]], fd: FS.fsDay[ch[1]], fT: FS.fsTitle[ch[0]], fs: FS.fsSide[ch[3]], fr: FS.fsRight[ch[6]],
      px: 6, py: 3, gp: 2, hr: 44, rs: 26, hh: 48, dh: 32, ac: 19, gu: 56, pp: 12, sw: 236, rw: 320, rd: s.recipe === 4 ? 6 : 4,
      oh: 0, ou: 260, eh: 0, es: 100, pf: 0, ps: 100, bh: 0, bw: s.recipe === 1 || s.recipe === 4 ? 3 : 0, tw: 5, ta: 135, to: 100, do: 100 };
    if (id in fixed) return fixed[id];
    const s0 = { ...s, K: {} }, t = tokens(s0), e = recipe('#5B8DEF', s0, t);
    const [fl, fc] = oklch(e.fill), [bl, bc] = oklch(e.bar === 'transparent' ? e.mark : e.bar), [tl] = oklch(e.title), [ml, mc] = oklch(e.meta), [cl, cc, chh] = oklch(t.bg);
    const v = { ec: fc, el: fl, bc, bl, tl, ml, mc, cl, cc, ch: deg(chh), so: oklch(t.rail)[0] - cl, hl: HOURK[s.hourLine] * 100, hm: s.minor >= 2 ? 6 : 0 }[id];
    return snap(id, v);
  }

  const cache = new Map();
  function look(code, kstr = '') {
    let K = typeof kstr === 'string' ? decodeK(kstr) : kstr || {};
    if (!valid(code)) { code = PRESETS[0].code; K = decodeK(PRESETS[0].k); }
    if (!passes(code, K)) K = {};
    if (!passes(code, K)) { code = PRESETS[0].code; K = decodeK(PRESETS[0].k); }
    const ck = code + '|' + encodeK(K);
    if (cache.has(ck)) return cache.get(ck);
    const s = { ...decode(code), K }, o = dzOpts(s), B = DZ.look(DZ.encode(o)), t = tokens(s), td = t, tp = tokensP(s);
    const v = id => has(K, id) ? K[id] : ROLE[id] && has(K, ROLE[id]) ? K[ROLE[id]] : auto(id, s);
    const fs = v('ft'), fsm = v('fm'), gp = v('gp'), gl = Math.min(2, gp);
    const typeVars = css({ 'fs-ev': fs + 'px', 'fs-evm': fsm + 'px', 'lh-ev': (fs + 3.5) + 'px', 'lh-evm': (fsm + 3) + 'px', 'ev-w': WEIGHT[s.weight], 'fs-chip': fs + 'px',
      fs: v('fb') + 'px', 'fs-s': (has(K, 'rM') ? K.rM : Math.max(9, v('fb') - 2)) + 'px', 'fs-h': (has(K, 'rH') ? K.rH : v('fb') + 1) + 'px', 'fs-hour': v('fh') + 'px', 'fs-day': v('fd') + 'px', 'fs-dayw': (has(K, 'rB') && !has(K, 'fd') ? K.rB : v('fd') - 1) + 'px',
      'fs-title': v('fT') + 'px', 'fs-side': v('fs') + 'px', 'fs-right': v('fr') + 'px', 'ev-px': v('px') + 'px', 'ev-pt': v('py') + 'px', 'r-ev': v('rd') + 'px',
      'hdr-h': v('hh') + 'px', 'dh-h': v('dh') + 'px', 'ad-row': v('ac') + 'px', 'gut-w': v('gu') + 'px', 'side-w': v('sw') + 'px', 'right-w': v('rw') + 'px',
      'cal-h': v('rs') + 'px', 'fs-grp': v('fg') + 'px', 'fs-mini': v('fi') + 'px', 'fs-mmh': v('fn') + 'px', 'pane-p': v('pp') + 'px', 'bar-w': (v('bw') || 3) + 'px', 'hatch-w': v('tw') + 'px', 'hatch-a': v('ta') + 'deg', 'hatch-o': v('to') + '%' });
    const ev = (hex, th) => th === 'dark' ? recipe(hex, s, t) : recipeP(hex, s, tp);
    const cls = [B.cls, 'rd', `rd-rec-${s.recipe}`, t.tcol ? 'rd-tcol' : '', t.shade ? 'rd-shade' : '', t.next ? 'rd-next' : '', `rd-past-${s.past}`, `rd-chrome-${s.chrome}`,
      has(K, 'do') ? 'rd-dash' : '', has(K, 'wt') ? `rd-w${K.wt}` : '', has(K, 'tw') || has(K, 'ta') || has(K, 'to') ? 'rd-hatch' : ''].filter(Boolean).join(' ');
    const geo = { ...B.geo, sideW: v('sw'), rightW: v('rw'), gutW: v('gu'), adRow: v('ac'), dhH: v('dh') };
    const L = {
      ...B, id: 'R', name: 'Readability', code, s, K, v, minTwo: v('py') + (v('ft') + 3.5) + (v('fm') + 3) + 2, lhEv: v('ft') + 3.5, lhEvm: v('fm') + 3, kstr: encodeK(K), T: { dark: t, paper: tp }, cls, geo, H: v('hr'), gap: { l: gl, r: gl + gp, b: gp }, scale: v('sc') / 100,
      vars(th) {
        const t = th === 'dark' ? td : tp;
        return B.vars(th) + ';' + typeVars + ';' + css({
          bg: t.bg, rail: t.rail, surface: t.surface, raised: t.raised, fg1: t.fg1, fg2: t.fg2, fg3: t.fg3, fg4: t.fg4,
          accent: t.accent, 'on-accent': t.onAccent, focus: t.focus, live: t.live, 'on-live': t.onLive, ok: t.ok, warn: t.warn, danger: t.danger,
          hover: t.hover, 'hover-rail': t.hoverRail, 'seg-ring': t.segRing, selected: t.selected, hair: t.hair, grid: t.grid, 'grid-v': t.gridV, 'grid-half': t.gridHalf,
          'hair-strong': t.hairStrong, hourc: t.hourc, macbar: mx(t.rail, W, .05), fg: t.fg1, ph: t.fg3, bg2: t.surface, pop: t.raised,
          rcol: t.rcol, 'hover-r': t.hoverR, hdrbg: t.hdrbg, 'join-bg': t.joinBg, 'join-fg': t.joinFg, 'today-tint': t.todayTint, elapsed: t.elapsed,
          'shadow-pop': th === 'dark' ? '0 0 0 1px rgba(255,255,255,.07), 0 12px 32px rgba(0,0,0,.55)' : '0 0 0 1px rgba(20,20,30,.08), 0 1px 2px rgba(20,20,30,.05), 0 8px 24px rgba(20,20,30,.10)',
          macbar: th === 'dark' ? mx(t.rail, W, .05) : mx(t.rail, BK, .05),
          ...(th === 'paper' && PF[pfOf(K)] && !has(K, 'bw') ? { 'bar-w': PF[pfOf(K)].bw + 'px' } : {}),
        });
      },
      ev, evVars: (hex, th) => evVars(th === 'dark' ? recipe(hex, s, t) : recipeP(hex, s, tp)),
      adVars: (hex, th) => evVars(th === 'dark' ? chip(hex, s, t) : chipP(hex, s, tp)),
      calDot: (hex, th) => th === 'dark' ? recipe(hex, s, t).mark : recipeP(hex, s, tp).mark,
      check(th) {
        if (th !== 'dark') { const t = tp; return { dark: false, canvas: [['bg', t.bg], ['raised', t.raised], ['rail', t.rail]], soft: [['surface', t.surface], ['hover', t.hover], ['hover on rail', t.hoverRail], ['selected', t.selected]],
          fg1: t.fg1, fg2: t.fg2, fg3: t.fg3, hourc: t.hourc, accent: t.accent, onAccent: t.onAccent, focus: t.focus, live: t.live, liveText: t.live, onLive: t.onLive,
          liveOn: [['bg', t.bg], ['rail', t.rail], ['card', t.surface]], segRing: t.segRing, track: t.surface,
          lines: [['hour line', t.grid, 'structure'], ['all-day edge', t.hairStrong, 'structure'], ['pane edge', t.hair, 'decor']],
          status: [['ok', t.ok], ['warn', t.warn], ['danger', t.danger]], ev: hex => recipeP(hex, s, tp), ad: s.allday ? hex => chipP(hex, s, tp) : null, join: { fg: t.joinFg, bg: t.joinBg } }; }
        return { dark: true, canvas: [['bg', t.bg], ['rail', t.rail]], soft: [['raised', t.raised], ['surface', t.surface], ['hover', t.hover], ['hover on rail', t.hoverRail], ['selected', t.selected]],
          fg1: t.fg1, fg2: t.fg2, fg3: t.fg3, hourc: t.hourc, accent: t.accent, onAccent: t.onAccent, focus: t.focus, live: t.live, liveText: t.live, onLive: t.onLive,
          liveOn: [['bg', t.bg], ['rail', t.rail], ['card', t.surface]], segRing: t.segRing, track: t.surface,
          lines: [['hour line', t.grid, 'structure'], ['all-day edge', t.hairStrong, 'structure'], ['pane edge', t.hair, 'decor']],
          status: [['ok', t.ok], ['warn', t.warn], ['danger', t.danger]], ev: hex => recipe(hex, s, t), ad: s.allday ? hex => chip(hex, s, t) : null, join: { fg: t.joinFg, bg: t.joinBg } };
      },
    };
    cache.set(ck, L); if (cache.size > 400) cache.delete(cache.keys().next().value);
    return L;
  }
  // round g: type-scale options (role sizes); the first is the recommendation. "Current" keeps the per-place sizes of the user's link.
  const SCALES = [
    { id: 'calm', l: 'Calm 4 sizes · 18 / 13 / 12 / 11', r: { rD: 18, rH: 13, rB: 12, rL: 12, rM: 11 },
      q: 'Four sizes, each with one job: 18 month title, 13 headings (day header, mini-month title), 12 for everything you read (events, sidebar rows, right column, group headers in fg3 / 500), 11 for times, hour labels and mini-month days. Group headers and the mini-month title get bigger, the 10.5 and 12.5 steps go.' },
    { id: 'apple', l: 'Apple-like · 20 / 13 / 13 / 11', r: { rD: 20, rH: 13, rB: 13, rL: 12, rM: 11 },
      q: 'macOS text styles: Title 1-ish month title, body 13 for events, rows and headings (headings by weight 600), callout-free 11 for times. Roomier; long titles wrap sooner in week columns.' },
    { id: 'notion', l: 'Notion compact · 16 / 12 / 11.5 / 10.5', r: { rD: 16, rH: 12, rB: 11.5, rL: 11.5, rM: 10.5 },
      q: 'Small and calm like Notion Calendar: 16 month title, 12 headings, 11.5 body, 10.5 times. Most fits on screen; times sit at the bottom of the comfortable range.' },
    { id: 'three', l: 'Three sizes, weight for rank · 15 / 12 / 12 / 11', r: { rD: 15, rH: 12, rB: 12, rL: 12, rM: 11 },
      q: 'Only 15, 12 and 11. Headings differ from body by weight (600 vs 400 / 500) and colour, not size. The quietest hierarchy; the month title is less dominant.' },
    { id: 'current', l: 'Current (yours) · 6 sizes', r: null, p: { ft: 12, fm: 10.5, fh: 11, fd: 12.5, fT: 18.5, fs: 12, fr: 12, fb: 13, fg: 11, fn: 11, fi: 11 },
      q: 'Your link as it is: 18.5 title, 13 base, 12.5 day header, 12 events / sidebar / right column, 11 hour labels, group headers and mini month, 10.5 event times. Six sizes, two of them half steps.' },
  ];
  const FONT_IDS = SLIDERS.filter(x => x[1] === 'font' || x[1] === 'fontp').map(x => x[0]);
  const applyScale = (K, id) => { const o = SCALES.find(x => x.id === id), K2 = { ...K }; FONT_IDS.forEach(i => delete K2[i]); Object.assign(K2, o.r || o.p); return K2; };
  const scaleOf = K => (SCALES.find(o => FONT_IDS.every(i => (K[i] != null ? K[i] : null) === ((o.r || o.p)[i] != null ? (o.r || o.p)[i] : null))) || {}).id || null;
  {
    const r10 = PRESETS.find(p => p.id === 'R10'), old = { ...r10, id: 'R10g', l: 'R10 (round g link)', idea: 'Your link before the lock: 8 text sizes (per place).' };
    r10.k = encodeK({ ...applyScale(decodeK(r10.k), LOCKED.scale), wt: LOCKED.weights });
    r10.idea = 'LOCKED 2026-11-20. ' + r10.idea + ' Type: three sizes 15 / 12 / 11 (title / body + headings / secondary), weights 400 / 500 / 600.';
    PRESETS.splice(PRESETS.indexOf(r10), 0, old);
  }
  const presetOf = (code, k = '') => PRESETS.find(p => p.code === code && (p.k || '') === encodeK(decodeK(k)));
  return { GROUPS, LEVERS, KI, COLOUR, CHROME_K, EVENT_K, FLOORS, PRESETS, SIZE, WEIGHT, decode, encode, valid, passes, verdict, pairs, grade, tokens, recipe, chip, tokensP, recipeP, FLOORS_P, PF, deOK, look, presetOf, HUES, setHues, SCALES, applyScale, scaleOf, ROLE, LOCKED, SLIDERS, SGROUPS, SI, CSL, EV_SL, CAN_SL, decodeK, encodeK, snap, auto };
})();
if (typeof module !== 'undefined') module.exports = READ;
