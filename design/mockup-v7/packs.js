// Calendr v7 · Packs: every theme pack in one file. One source for the page (app.js asks PK() for CSS variables,
// event colours and structure flags) and for the contrast check (node design/mockup-v7/contrast.mjs).
// A pack = a coherent pair: a Dark theme and a Paper theme that share fonts, event marks, lines, radii and spacing.
//   A, B, C   reference packs, ported unchanged from design/mockup-v6-a, -b, -c (tokens.js of each).
//   D1–D4     new: dark = a mix of A and B; paper = C's warm paper, adapted per pack; body SF Pro or Inter,
//             page titles in the body font (year in fg3), times in the body font's tabular figures.
'use strict';
const PACKS = (() => {
  const hx = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
  const mx = (a, b, t) => { const x = hx(a), y = hx(b); return '#' + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, '0')).join('').toUpperCase(); };
  const css = o => Object.entries(o).map(([k, x]) => `--${k}:${x}`).join(';');
  // single quotes inside: the values end up in a style="" attribute
  const SF = "-apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif";
  const INTER = "'Inter', -apple-system, 'SF Pro Text', system-ui, sans-serif";

  // ================================================================ A "Calm graphite" (v6-a tokens.js, unchanged)
  const TA = {
    dark: {
      dark: true, bg: '#111113', side: '#0D0D0F', surface: '#18181B', raised: '#202024', hair: '#232327', line: '#252529', hairStrong: '#3A3A40',
      fg1: '#EDEDEF', fg2: '#C4C4CA', fg3: '#A6A6AE', fg4: '#62626A', accent: '#EDEDEF', onAccent: '#111113', segRing: '#76767E',
      focus: '#6E9BF5', live: '#FF5A4F', danger: '#C8463C', onDanger: '#FFFFFF', hoverA: 5, selA: 9,
      scrim: 'rgba(0,0,0,.5)', shadow: '0 8px 24px rgba(0,0,0,.5)', shadowBig: '0 24px 64px rgba(0,0,0,.55)',
    },
    paper: {
      dark: false, bg: '#FAF9F6', side: '#F4F2EE', surface: '#F2F0EB', raised: '#FFFFFF', hair: '#E6E3DC', line: '#E3E0D9', hairStrong: '#CFCBC2',
      fg1: '#1C1B20', fg2: '#4B4952', fg3: '#625F69', fg4: '#A3A0A8', accent: '#1C1B20', onAccent: '#FAF9F6', segRing: '#86828D',
      focus: '#2F6BDC', live: '#D93A2F', danger: '#C23B31', onDanger: '#FFFFFF', hoverA: 3.5, selA: 5,
      scrim: 'rgba(40,36,30,.24)', shadow: '0 1px 2px rgba(0,0,0,.06), 0 8px 24px rgba(0,0,0,.08)', shadowBig: '0 2px 6px rgba(0,0,0,.06), 0 24px 64px rgba(40,34,20,.16)',
    },
  };
  function evA(hex, theme, task) {
    const T = TA[theme], dark = T.dark, base = task ? T.fg1 : hex;
    const fill = mx(T.bg, base, task ? (dark ? .13 : .075) : dark ? .24 : .16);
    const title = task || dark ? T.fg1 : mx(hex, '#0B0B10', .72);
    const meta = mx(title, fill, dark ? .18 : .15);
    const fillSel = task ? mx(T.bg, base, dark ? .2 : .12) : mx(T.bg, hex, dark ? .34 : .26);
    return {
      fill, title, meta, fillH: dark ? mx(fill, '#FFFFFF', .05) : mx(fill, '#FFFFFF', .35),
      fillSel, titleSel: title, metaSel: mx(title, fillSel, dark ? .06 : .08),
      fillPast: mx(fill, T.bg, .55), titlePast: T.fg2, metaPast: T.fg3, fillDec: mx(fill, T.bg, .5), titleDec: T.fg2,
      bar: dark ? 'transparent' : hex, barPast: dark ? 'transparent' : mx(hex, T.bg, .5),
      edge: dark ? mx(hex, T.fg1, .1) : mx(hex, '#0B0B10', .38), mark: dark ? hex : mx(hex, '#0B0B10', .12),
    };
  }
  const packA = {
    id: 'A', name: 'A · Calm graphite', blurb: 'v6 A: SF Pro, graphite #111113, no event bar in dark, very calm chrome.',
    css: 'a', ui: 'A', H: 48, icStroke: 1.5, darkName: 'Dark (graphite)',
    vars(th) {
      const T = TA[th], d = T.dark, a = (h, x) => `color-mix(in srgb, ${h} ${x}%, transparent)`;
      return css({
        bg: T.bg, side: T.side, surface: T.surface, raised: T.raised, hair: T.hair, line: T.line, 'hair-strong': T.hairStrong,
        fg1: T.fg1, fg2: T.fg2, fg3: T.fg3, fg4: T.fg4, accent: T.accent, 'on-accent': T.onAccent, 'seg-ring': T.segRing,
        focus: T.focus, live: T.live, danger: T.danger, 'on-danger': T.onDanger,
        hover: a(T.fg1, T.hoverA), selected: a(T.fg1, T.selA), scrim: T.scrim, shadow: T.shadow, 'shadow-big': T.shadowBig,
        'pop-ring': d ? 'rgba(255,255,255,.08)' : 'rgba(0,0,0,.08)', 'hov-ov': d ? 'rgba(255,255,255,.05)' : 'rgba(255,255,255,.35)',
        'btn-ov': d ? 'rgba(255,255,255,.06)' : 'rgba(0,0,0,.035)', 'menu-hi': '#2F6BDC',
      });
    },
    ev: evA,
    evVars(hex, th, task) {
      const c = evA(hex, th, task);
      return `--cc:${c.mark};--bar:${c.bar};--fill:${c.fill};--fillsel:${c.fillSel};--fillp:${c.fillPast};--barp:${c.barPast};--filldec:${c.fillDec};` +
        `--tc:${c.title};--mc:${c.meta};--mcsel:${c.metaSel};--tcp:${c.titlePast};--mcp:${c.metaPast};--edge:${c.edge}`;
    },
    calDot: hex => hex,
    check(th) {
      const T = TA[th];
      return {
        dark: T.dark, canvas: [['bg', T.bg], ['side', T.side]],
        soft: [['surface', T.surface], ['raised', T.raised], ['hover', mx(T.bg, T.fg1, T.hoverA / 100)], ['selected', mx(T.bg, T.fg1, T.selA / 100)]],
        fg1: T.fg1, fg2: T.fg2, fg3: T.fg3, accent: T.accent, onAccent: T.onAccent, focus: T.focus,
        live: T.live, liveText: null, segRing: T.segRing, track: T.surface,
        lines: [['hour line', T.line, 'decorMin'], ['pane edge', T.hair, 'decor'], ['all-day edge', T.hairStrong, 'structure']],
        status: [], ev: hex => evA(hex, th, false),
      };
    },
  };

  // ================================================================ B "Structured contrast" (v6-b tokens.js, unchanged)
  const TB = {
    dark: {
      bg: '#000000', surface: '#0E0E10', raised: '#18181B', raised2: '#232327', track: '#161618', thumb: '#2C2C31', segRing: '#6E6E76',
      fg1: '#E6E6E8', fg2: '#C8C8CE', fg3: '#A4A4AC', fg4: '#5E5E66', hourLabel: '#C8C8CE',
      lineHalf: '#151518', lineDay: '#1C1C1F', lineHour: '#28282C', lineEdge: '#36363C', hairStrong: '#3A3A40', hover: 7, selected: 11,
      accent: '#E6E6E8', onAccent: '#000000', focus: '#6E9BF5', live: '#FF5A4F', liveText: '#FF8075',
      ok: '#6CC58A', warn: '#E5B44A', danger: '#FF7B72', dangerFill: '#C62F28', scrim: 'rgba(0,0,0,.6)', shadowPop: '0 8px 24px rgba(0,0,0,.5)',
    },
    paper: {
      bg: '#FFFFFF', surface: '#F4F4F6', raised: '#FFFFFF', raised2: '#EDEDF0', track: '#EBEBEE', thumb: '#FFFFFF', segRing: '#7A7A83',
      fg1: '#111114', fg2: '#3E3E46', fg3: '#5A5A63', fg4: '#A3A3AB', hourLabel: '#3E3E46',
      lineHalf: '#F2F2F4', lineDay: '#E6E6EA', lineHour: '#D9D9DE', lineEdge: '#C4C4CB', hairStrong: '#C4C4CB', hover: 5, selected: 7,
      accent: '#111114', onAccent: '#FFFFFF', focus: '#2F6BDC', live: '#E0362B', liveText: '#BF2A20',
      ok: '#1E7B43', warn: '#8A5A00', danger: '#BF2A20', dangerFill: '#C62F28', scrim: 'rgba(20,20,24,.28)', shadowPop: '0 1px 2px rgba(0,0,0,.06), 0 8px 24px rgba(0,0,0,.10)',
    },
  };
  function evB(cc, th) {
    const T = TB[th], d = th === 'dark', bg = T.bg, fill = mx(bg, cc, d ? 0.30 : 0.20), title = d ? '#FFFFFF' : T.fg1;
    const fillSel = mx(bg, cc, d ? 0.42 : 0.28);
    return {
      cc, fill, fillH: mx(bg, cc, d ? 0.35 : 0.14), fillSel, titleSel: title, metaSel: mx(title, fill, d ? 0.18 : 0.22),
      fillPast: mx(fill, bg, 0.55), fillDec: mx(fill, bg, 0.50),
      bar: d ? cc : mx(cc, '#000000', 0.12), barPast: mx(d ? cc : mx(cc, '#000000', 0.12), bg, 0.5),
      title, meta: mx(title, fill, d ? 0.18 : 0.22), titlePast: T.fg2, metaPast: T.fg3, titleDec: T.fg2,
      edge: d ? mx(cc, '#FFFFFF', 0.15) : mx(cc, '#000000', 0.32), mark: d ? cc : mx(cc, '#000000', 0.12),
    };
  }
  const packB = {
    id: 'B', name: 'B · Structured contrast', blurb: 'v6 B: Inter, OLED black, 3 px bar + white titles, timetable grid, one right-aligned time column.',
    css: 'b', ui: 'B', H: 48, icStroke: 1.35, darkName: 'Dark (OLED black)',
    vars(th) {
      const T = TB[th], d = th === 'dark', tint = x => `color-mix(in srgb, ${T.fg1} ${x}%, transparent)`;
      return `--bg:${T.bg};--surface:${T.surface};--raised:${T.raised};--raised2:${T.raised2};--track:${T.track};--thumb:${T.thumb};` +
        `--fg1:${T.fg1};--fg:${T.fg1};--fg2:${T.fg2};--fg3:${T.fg3};--fg4:${T.fg4};--ph:${T.fg3};--hourc:${T.hourLabel};` +
        `--line-half:${T.lineHalf};--line-day:${T.lineDay};--line-hour:${T.lineHour};--line-edge:${T.lineEdge};--hair:${T.lineDay};--hair-strong:${T.hairStrong};--seg-ring:${T.segRing};` +
        `--hover:${tint(T.hover)};--selected:${tint(T.selected)};--accent:${T.accent};--on-accent:${T.onAccent};--focus:${T.focus};` +
        `--live:${T.live};--live-text:${T.liveText};--ok:${T.ok};--warn:${T.warn};--danger:${T.danger};--danger-fill:${T.dangerFill};` +
        `--scrim:${T.scrim};--shadow-pop:${T.shadowPop};--mark:${d ? 'rgba(233,185,73,.34)' : 'rgba(255,205,40,.45)'};` +
        `--pillbg:${mx(T.bg, T.fg1, d ? .16 : .09)};--pillbgp:${mx(T.bg, T.fg1, d ? .08 : .05)};` +
        `--bg1:${T.surface};--bg2:${T.raised2};--bg3:${T.thumb};--pop:${T.raised};--rail:${T.surface}`;
    },
    ev: (hex, th) => evB(hex, th),
    evVars(hex, th) {
      const c = evB(hex, th);
      return `--cc:${c.cc};--bar:${c.bar};--barp:${c.barPast};--fill:${c.fill};--fillh:${c.fillH};--fills:${c.fillSel};--fillp:${c.fillPast};--decfill:${c.fillDec};` +
        `--tc:${c.title};--mc:${c.meta};--tcp:${c.titlePast};--mcp:${c.metaPast};--dectc:${c.titleDec};--ol:${c.edge}`;
    },
    calDot: hex => hex,
    check(th) {
      const T = TB[th];
      return {
        dark: th === 'dark', canvas: [['bg', T.bg], ['surface (sidebars)', T.surface]],
        soft: [['raised', T.raised], ['raised2', T.raised2], ['hover', mx(T.bg, T.fg1, T.hover / 100)], ['selected', mx(T.bg, T.fg1, T.selected / 100)], ['hover on raised', mx(T.raised, T.fg1, T.hover / 100)]],
        fg1: T.fg1, fg2: T.fg2, fg3: T.fg3, accent: T.accent, onAccent: T.onAccent, focus: T.focus,
        live: T.live, liveText: T.liveText, segRing: T.segRing, track: T.track,
        lines: [['hour line (timetable)', T.lineHour, 'structure'], ['half-hour line', T.lineHalf, 'decor'], ['day divider', T.lineDay, 'decor'], ['all-day / header edge', T.lineEdge, 'structure']],
        status: [['ok', T.ok], ['warn', T.warn], ['danger', T.danger]], ev: hex => evB(hex, th),
      };
    },
  };

  // ================================================================ C "Warm editorial" (v6-c tokens.js, unchanged)
  const TC = {
    paper: { dark: false, bg: '#F7F4EC', rail: '#F0ECE3', surface: '#ECE7DC', raised: '#FFFDF8', fg1: '#211E19', fg2: '#47423A', fg3: '#5B554C', fg4: '#A29C90',
      accent: '#211E19', onAccent: '#F7F4EC', focus: '#2F6BDC', live: '#C2362B', ok: '#2F7A4B', warn: '#8A5A00', danger: '#B4382D', inkTitle: '#1A140C' },
    dark: { dark: true, bg: '#151412', rail: '#1A1917', surface: '#201F1C', raised: '#292724', fg1: '#EEEAE2', fg2: '#CCC6BA', fg3: '#AAA498', fg4: '#67625A',
      accent: '#EEEAE2', onAccent: '#151412', focus: '#7AA2F7', live: '#FF6B5C', ok: '#7FCB98', warn: '#E9B949', danger: '#F28B7F', inkTitle: null },
  };
  for (const t of Object.values(TC)) {
    t.hover = mx(t.bg, t.fg1, t.dark ? .05 : .04); t.hoverRail = mx(t.rail, t.fg1, .05); t.selected = mx(t.bg, t.fg1, t.dark ? .09 : .07);
    t.hair = mx(t.bg, t.fg1, t.dark ? .075 : .085); t.grid = mx(t.bg, t.fg1, .11); t.gridV = mx(t.bg, t.fg1, .08);
    t.hairStrong = mx(t.bg, t.fg1, t.dark ? .2 : .22); t.segRing = mx(t.surface, t.fg1, t.dark ? .38 : .5);
  }
  function evC(hex, th) {
    const t = TC[th], bg = t.bg;
    if (t.dark) {
      const fill = mx(bg, hex, .22), tc = t.fg1, fills = mx(bg, hex, .32);
      return { cc: hex, bar: 'transparent', barPast: 'transparent', fill, title: tc, meta: mx(tc, fill, .18), fillH: mx(fill, t.fg1, .06),
        fillSel: fills, titleSel: tc, metaSel: mx(tc, fills, .06), fillPast: mx(bg, fill, .45), titlePast: t.fg2, metaPast: t.fg3,
        fillDec: mx(bg, fill, .5), titleDec: t.fg2, edge: mx(hex, t.fg1, .15), mark: hex };
    }
    const fill = mx(bg, hex, .18), tc = mx(hex, t.inkTitle, .80), fills = mx(bg, hex, .20), tcs = mx(hex, t.inkTitle, .88);
    return { cc: hex, bar: mx(hex, t.inkTitle, .12), barPast: mx(hex, t.inkTitle, .12), fill, title: tc, meta: mx(tc, fill, .14), fillH: mx(fill, '#FFFFFF', .45),
      fillSel: fills, titleSel: tcs, metaSel: mx(tcs, fills, .12), fillPast: mx(bg, fill, .45), titlePast: t.fg2, metaPast: t.fg3,
      fillDec: mx(bg, fill, .5), titleDec: t.fg2, edge: mx(hex, t.inkTitle, .38), mark: mx(hex, t.inkTitle, .12) };
  }
  // the variable names app.css reads for events (shared by C and D)
  const evVarsC = c => `--cc:${c.cc || c.mark};--bar:${c.bar};--barp:${c.barPast};--dot:${c.mark};--fill:${c.fill};--fillh:${c.fillH};--fills:${c.fillSel};--fillp:${c.fillPast};` +
    `--tc:${c.title};--tcs:${c.titleSel};--mc:${c.meta};--mcs:${c.metaSel};--tcp:${c.titlePast};--mcp:${c.metaPast};--decfill:${c.fillDec};--dectc:${c.titleDec};--line:${c.edge}`;
  const packC = {
    id: 'C', name: 'C · Warm editorial', blurb: 'v6 C: Geist + Geist Mono times, warm cream Paper, "warm night" dark.',
    css: 'c', ui: 'C', H: 52, icStroke: 1.35, darkName: 'Dark (warm night)',
    vars(th) {
      const t = TC[th], d = t.dark;
      return css({
        bg: t.bg, rail: t.rail, surface: t.surface, raised: t.raised, fg1: t.fg1, fg2: t.fg2, fg3: t.fg3, fg4: t.fg4,
        accent: t.accent, 'on-accent': t.onAccent, focus: t.focus, live: t.live, ok: t.ok, warn: t.warn, danger: t.danger,
        hover: t.hover, 'hover-rail': t.hoverRail, 'seg-ring': t.segRing, selected: t.selected, hair: t.hair, grid: t.grid, 'grid-v': t.gridV, 'hair-strong': t.hairStrong,
        scrim: d ? 'rgba(10,9,8,.6)' : 'rgba(60,50,35,.22)',
        'shadow-pop': d ? '0 0 0 1px rgba(255,248,235,.07), 0 12px 32px rgba(0,0,0,.5)' : '0 0 0 1px rgba(60,50,35,.10), 0 1px 2px rgba(60,50,35,.06), 0 8px 24px rgba(60,50,35,.10)',
        'shadow-dialog': d ? '0 0 0 1px rgba(255,248,235,.07), 0 24px 64px rgba(0,0,0,.6)' : '0 0 0 1px rgba(60,50,35,.10), 0 2px 4px rgba(60,50,35,.06), 0 24px 64px rgba(60,50,35,.16)',
        fg: t.fg1, ph: t.fg3, bg2: t.surface, pop: t.raised,
      });
    },
    ev: (hex, th) => evC(hex, th),
    evVars: (hex, th) => evVarsC(evC(hex, th)),
    calDot: (hex, th) => evC(hex, th).mark,
    check(th) {
      const t = TC[th];
      return {
        dark: t.dark, canvas: t.dark ? [['bg', t.bg], ['rail', t.rail]] : [['bg', t.bg], ['raised', t.raised]],
        soft: t.dark ? [['surface', t.surface], ['raised', t.raised], ['hover', t.hover], ['selected', t.selected]] : [['rail', t.rail], ['surface', t.surface], ['hover', t.hover], ['selected', t.selected]],
        fg1: t.fg1, fg2: t.fg2, fg3: t.fg3, accent: t.accent, onAccent: t.onAccent, focus: t.focus,
        live: t.live, liveText: t.live, liveOn: [['bg', t.bg], ['rail', t.rail]], segRing: t.segRing, track: t.surface,
        lines: [['hour line', t.grid, 'decorMin'], ['day separator', t.gridV, 'decor'], ['pane edge', t.hair, 'decor'], ['all-day edge', t.hairStrong, 'structure']],
        status: [['ok', t.ok], ['warn', t.warn], ['danger', t.danger]], ev: hex => evC(hex, th),
      };
    },
  };

  // ================================================================ D1–D4: new packs
  // Shared by every D pack: page titles in the body font (22/600, year 400 in fg3), 5 sizes (22 · 15 · 13 · 12 · 11), weights 400/500 (+600 for one
  // title per area), spacing 4/8, radius 4 events · 6 rows · 8 fields and buttons · 12 menus and cards, hour 48 px, times in the body font's
  // tabular figures. Paper = C's warm paper, adapted per pack so it keeps the dark theme's event mark, lines and panes.
  const PAPER = { bg: '#F7F4EC', rail: '#F0ECE3', surface: '#ECE7DC', raised: '#FFFDF8', fg1: '#211E19', fg2: '#47423A', fg3: '#5B554C', fg4: '#A29C90',
    focus: '#2F6BDC', live: '#C2362B', ok: '#2F7A4B', warn: '#8A5A00', danger: '#B4382D', ink: '#1A140C' };
  const DARK_STATUS = { focus: '#6E9BF5', ok: '#6CC58A', warn: '#E5B44A', danger: '#FF7B72' };

  function themeD(spec, th) {
    const p = spec[th], d = th === 'dark';
    const t = Object.assign({ dark: d }, d ? DARK_STATUS : PAPER, p);
    t.accent = t.accent || t.fg1; t.onAccent = t.onAccent || t.bg;
    const L = (x) => mx(t.bg, t.fg1, x);
    t.hover = mx(t.bg, t.fg1, t.hoverA ?? (d ? .05 : .04)); t.hoverRail = mx(t.rail, t.fg1, t.hoverRailA ?? t.hoverA ?? (d ? .05 : .035)); t.selected = mx(t.bg, t.fg1, t.selA ?? (d ? .09 : .07));
    t.grid = t.grid || L(t.lineHour); t.gridV = t.gridV || L(t.lineDay); t.gridHalf = t.gridHalf || L(t.lineHalf ?? 0);
    t.hair = t.hair || L(t.lineHair ?? (d ? .08 : .085)); t.hairStrong = t.hairStrong || L(d ? .2 : .22);
    t.segRing = t.segRing || mx(t.surface, t.fg1, d ? .4 : .5);
    t.hourc = t[spec.hourLabel || 'fg3'];
    return t;
  }
  function evD(spec, th, hex) {
    const t = spec.T[th], d = t.dark, e = spec.ev[th], bg = t.bg;
    const fill = mx(bg, hex, e.fill), fillSel = mx(bg, hex, e.fill + e.sel);
    let title, titleSel;
    if (spec.title === 'white') { title = titleSel = d ? '#FFFFFF' : t.fg1; }
    else if (spec.title === 'hue') { title = d ? mx(hex, '#FFFFFF', e.hue) : mx(hex, PAPER.ink, e.hue); titleSel = d ? mx(hex, '#FFFFFF', e.hue + .06) : mx(hex, PAPER.ink, Math.min(.92, e.hue + .06)); }
    else { title = titleSel = t.fg1; }
    const mark = d ? hex : mx(hex, PAPER.ink, .12);
    return {
      cc: mark, mark, fill, title, meta: mx(title, fill, e.meta), fillH: d ? mx(fill, '#FFFFFF', .05) : mx(fill, '#FFFFFF', .4),
      fillSel, titleSel, metaSel: mx(titleSel, fillSel, Math.max(.04, e.meta - .08)),
      fillPast: mx(fill, bg, .55), titlePast: t.fg2, metaPast: t.fg3, fillDec: mx(fill, bg, .5), titleDec: t.fg2,
      bar: spec.bar ? mark : 'transparent', barPast: spec.bar ? mx(mark, bg, .5) : 'transparent',
      edge: d ? mx(hex, t.fg1, .15) : mx(hex, PAPER.ink, .38),
    };
  }
  function makeD(spec) {
    spec.T = { dark: themeD(spec, 'dark'), paper: themeD(spec, 'paper') };
    const font = spec.font === 'inter'
      ? { sans: INTER, ff: "'cv05' 1, 'cv08' 1", trS: '.004em', trB: '-.004em', trH: '-.01em' }
      : { sans: SF, ff: 'normal', trS: '.006em', trB: '-.006em', trH: '-.015em' };
    return {
      id: spec.id, name: spec.name, blurb: spec.blurb, css: 'd', ui: 'D', H: 48, icStroke: 1.5, darkName: spec.darkName,
      spec, flags: spec.flags,
      attrs: { 'data-pack': spec.id, 'data-bar': spec.bar ? '1' : '0', 'data-grid': spec.grid, 'data-edges': spec.edges ? '1' : '0', 'data-ad': spec.adDots ? 'dots' : 'tint', 'data-font': spec.font, 'data-tcol': spec.flags.tcol },
      vars(th) {
        const t = spec.T[th], d = t.dark;
        return css({
          bg: t.bg, rail: t.rail, surface: t.surface, raised: t.raised, fg1: t.fg1, fg2: t.fg2, fg3: t.fg3, fg4: t.fg4,
          accent: t.accent, 'on-accent': t.onAccent, focus: t.focus, live: t.live, ok: t.ok, warn: t.warn, danger: t.danger,
          hover: t.hover, 'hover-rail': t.hoverRail, 'seg-ring': t.segRing, selected: t.selected, hair: t.hair, grid: t.grid, 'grid-v': t.gridV, 'grid-half': t.gridHalf,
          'hair-strong': t.hairStrong, hourc: t.hourc, macbar: t.macbar || (d ? '#1E1E21' : '#E7E2D7'),
          scrim: d ? 'rgba(0,0,0,.6)' : 'rgba(60,50,35,.22)',
          'shadow-pop': d ? '0 0 0 1px rgba(255,255,255,.07), 0 12px 32px rgba(0,0,0,.55)' : '0 0 0 1px rgba(60,50,35,.10), 0 1px 2px rgba(60,50,35,.06), 0 8px 24px rgba(60,50,35,.10)',
          'shadow-dialog': d ? '0 0 0 1px rgba(255,255,255,.08), 0 24px 64px rgba(0,0,0,.65)' : '0 0 0 1px rgba(60,50,35,.10), 0 2px 4px rgba(60,50,35,.06), 0 24px 64px rgba(60,50,35,.16)',
          fg: t.fg1, ph: t.fg3, bg2: t.surface, pop: t.raised,
          sans: font.sans, mono: font.sans, ff: font.ff, 'tr-s': font.trS, 'tr-b': font.trB, 'tr-h': font.trH,
          'r-ev': '4px', 'r-sm': '6px', 'r-md': '8px', 'r-lg': '12px',
        });
      },
      ev: (hex, th) => evD(spec, th, hex),
      evVars: (hex, th) => evVarsC(evD(spec, th, hex)),
      calDot: (hex, th) => evD(spec, th, hex).mark,
      check(th) {
        const t = spec.T[th];
        const lines = [spec.grid === 'timetable' ? ['hour line (timetable)', t.grid, 'structure'] : ['hour line', t.grid, 'decorMin'], ['day divider', t.gridV, 'decor'], ['all-day edge', t.hairStrong, 'structure']];
        if (spec.grid === 'timetable') lines.splice(1, 0, ['half-hour line', t.gridHalf, 'decor']);
        if (spec.edges) lines.push(['pane edge', t.hair, 'decor']);
        return {
          dark: t.dark, canvas: t.dark ? [['bg', t.bg], ['rail', t.rail]] : [['bg', t.bg], ['raised', t.raised]],
          soft: [t.dark ? ['raised', t.raised] : ['rail', t.rail], ['surface', t.surface], ['hover', t.hover], ['hover on rail', t.hoverRail], ['selected', t.selected]],
          fg1: t.fg1, fg2: t.fg2, fg3: t.fg3, hourc: t.hourc, accent: t.accent, onAccent: t.onAccent, focus: t.focus,
          live: t.live, liveText: t.live, liveOn: [['bg', t.bg], ['rail', t.rail], ['card', t.dark ? t.surface : t.raised]], segRing: t.segRing, track: t.surface,
          lines, status: [['ok', t.ok], ['warn', t.warn], ['danger', t.danger]], ev: hex => evD(spec, th, hex),
          chip: spec.adDots ? { bg: t.dark ? t.surface : t.raised, fg: t.fg1 } : null,
        };
      },
    };
  }

  const D1 = makeD({
    id: 'D1', name: 'D1 · Graphite, bar', darkName: 'Dark (graphite)', font: 'sf', bar: true, title: 'white', grid: 'calm', edges: false, adDots: false, hourLabel: 'fg3',
    blurb: "A's graphite canvas, darker sidebars and calm grid; B's 3 px bar and white titles on a firmer tint. SF Pro.",
    flags: { tcol: 'single', shortcuts: false, half: false, oneUnder45: false },
    dark: { bg: '#111113', rail: '#0C0C0E', surface: '#19191C', raised: '#212125', fg1: '#EDEDEF', fg2: '#C4C4CA', fg3: '#A6A6AE', fg4: '#62626A',
      live: '#FF6B5F', lineHour: .11, lineDay: .065, hairStrong: '#3A3A40' },
    paper: { lineHour: .11, lineDay: .08 },
    ev: { dark: { fill: .28, sel: .08, meta: .18 }, paper: { fill: .18, sel: .06, meta: .2 } },
  });
  const D2 = makeD({
    id: 'D2', name: 'D2 · OLED, soft', darkName: 'Dark (OLED black)', font: 'sf', bar: false, title: 'fg1', grid: 'calm', edges: false, adDots: false, hourLabel: 'fg3',
    blurb: "B's OLED black with sidebars one step up; A's soft tint without a bar, off-white titles and minimal chrome. SF Pro.",
    flags: { tcol: 'single', shortcuts: false, half: false, oneUnder45: false },
    dark: { bg: '#000000', rail: '#0E0E10', surface: '#151517', raised: '#1D1D20', fg1: '#E6E6E8', fg2: '#C8C8CE', fg3: '#A4A4AC', fg4: '#5E5E66',
      live: '#FF6B5F', lineHour: .1, lineDay: .06, hoverA: .07, selA: .11, hairStrong: '#36363C' },
    paper: { bg: '#FAF8F3', rail: '#F2EFE8', surface: '#EEEAE1', raised: '#FFFFFF', lineHour: .1, lineDay: .07 },
    ev: { dark: { fill: .28, sel: .08, meta: .18 }, paper: { fill: .22, sel: .06, meta: .17 } },
  });
  const D3 = makeD({
    id: 'D3', name: 'D3 · Graphite timetable', darkName: 'Dark (graphite)', font: 'inter', bar: false, title: 'hue', grid: 'timetable', edges: true, adDots: false, hourLabel: 'fg2',
    blurb: "A's graphite and darker sidebars, but B's timetable: hairline pane edges, half-hour lines, fg2 hour labels, start over end in one right-aligned time column; titles tinted with the calendar hue, no bar. Inter.",
    flags: { tcol: 'stack', shortcuts: true, half: true, oneUnder45: true },
    dark: { bg: '#131315', rail: '#0E0E10', surface: '#1C1C20', raised: '#242428', fg1: '#EDEDEF', fg2: '#C8C8CE', fg3: '#A8A8B0', fg4: '#62626A',
      live: '#FF6B5F', lineHour: .15, lineHalf: .075, lineDay: .1, lineHair: .1, hairStrong: '#3E3E44' },
    paper: { lineHour: .15, lineHalf: .065, lineDay: .1, lineHair: .1 },
    ev: { dark: { fill: .2, sel: .08, meta: .14, hue: .74 }, paper: { fill: .18, sel: .04, meta: .14, hue: .8 } },
  });
  const D4 = makeD({
    id: 'D4', name: 'D4 · Black, graphite panes', darkName: 'Dark (black, graphite panes)', font: 'inter', bar: true, title: 'fg1', grid: 'timetable', edges: false, adDots: true, hourLabel: 'fg2',
    blurb: "Black canvas between lighter graphite sidebars; B's structure (half-hour ticks, start over end, neutral all-day chips with a dot) with A's calm: soft tint, off-white titles, 3 px bar. Inter.",
    flags: { tcol: 'stack', shortcuts: true, half: true, oneUnder45: false },
    dark: { bg: '#000000', rail: '#1C1C1F', surface: '#232327', raised: '#26262A', fg1: '#E8E8EA', fg2: '#C8C8CE', fg3: '#AAAAB2', fg4: '#5E5E66',
      live: '#FF6B5F', lineHour: .12, lineHalf: .055, lineDay: .08, hoverA: .07, hoverRailA: .045, selA: .11, hairStrong: '#36363C', macbar: '#1C1C1F' },
    paper: { bg: '#F3F0E7', rail: '#FBF9F4', surface: '#E9E4D9', raised: '#FFFEFA', fg1: '#1B1814', fg2: '#433E36', lineHour: .11, lineHalf: .05, lineDay: .075, selA: .055, macbar: '#E7E2D7' },
    ev: { dark: { fill: .24, sel: .08, meta: .18 }, paper: { fill: .16, sel: .06, meta: .2 } },
  });

  const list = [D1, D2, D3, D4, packA, packB, packC];
  const byId = Object.fromEntries(list.map(p => [p.id, p]));
  return { list, byId, order: ['D1', 'D2', 'D3', 'D4', 'A', 'B', 'C'], mix: mx };
})();
if (typeof module !== 'undefined') module.exports = PACKS;
