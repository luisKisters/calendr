// Horion v9 · looks. One source for the page (app.js reads the chosen look through PK() for CSS variables, event colours
// and geometry) and for the contrast check (node design/mockup-v9/contrast.mjs).
// Round 2026-11-20: "readability looks good now but it looks overall bad and not nice to look at". Readability stays (same floors);
// the skin is now a choice of looks, picked in the rail (hash key look, default L1):
//   L0 · v8          the v8 D3 "Graphite timetable" output, unchanged (the code below is v8's tokens.js verbatim)
//   L1 · Clean bar   neutral canvas, light hue tint + 3 px saturated bar, near-fg1 title
//   L2 · Soft solid  cool neutral canvas, tinted fill + faint 1 px hue edge, deep / bright hue title
//   L3 · Vivid       solid hue fills (darkened only as far as the floors need), white titles
//   L4 · Cards       raised neutral cards on a darker canvas, colour only as a 3 px bar
// Shape per look lives in looks.css under .pk-L1 … .pk-L4; L0 has no rules there.
'use strict';
// ================================================================ L0 = v8 (D3 Graphite timetable), unchanged
const THEME_L0 = (() => {
  const hx = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
  const mx = (a, b, t) => { const x = hx(a), y = hx(b); return '#' + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, '0')).join('').toUpperCase(); };
  const css = o => Object.entries(o).map(([k, x]) => `--${k}:${x}`).join(';');
  // single quotes inside: the values end up in a style="" attribute
  const INTER = "'Inter', -apple-system, 'SF Pro Text', system-ui, sans-serif";

  const PAPER = { bg: '#F7F4EC', rail: '#F0ECE3', surface: '#ECE7DC', raised: '#FFFDF8', fg1: '#211E19', fg2: '#47423A', fg3: '#5B554C', fg4: '#A29C90',
    focus: '#2F6BDC', live: '#C2362B', ok: '#2F7A4B', warn: '#8A5A00', danger: '#B4382D', ink: '#1A140C', onLive: '#FFFFFF' };
  const DARK = { focus: '#6E9BF5', ok: '#6CC58A', warn: '#E5B44A', danger: '#FF7B72',
    bg: '#131315', rail: '#0E0E10', surface: '#1C1C20', raised: '#242428', fg1: '#EDEDEF', fg2: '#C8C8CE', fg3: '#A8A8B0', fg4: '#62626A',
    live: '#FF6B5F', onLive: '#131315', hairStrong: '#3E3E44' };
  // lines as a mix of bg toward fg1: the hour line stays clearly visible (user, 5 Nov), the half-hour line is quieter than in v7
  const LINES = { dark: { lineHour: .15, lineHalf: .05, lineDay: .1, lineHair: .1 }, paper: { lineHour: .15, lineHalf: .045, lineDay: .1, lineHair: .1 } };
  // event recipe. Dark: fill = bg mixed toward the calendar hue; title = hue mixed toward white.
  // Paper (2026-11-05, "too light, hurts readability"): the fill is a clear pastel of the calendar hue on warm white (raised),
  // up to 44 % hue, but never darker than relative luminance .71 so the hue-dark title and time keep APCA Lc 75 / 70 (strong hues
  // such as Tomato or Grape stop earlier, light ones such as Banana or Lavender take more). Selected = 8 points more hue, floor .65.
  // Title = hue mixed toward ink (deep, in the event's hue), time one step lighter (12 % toward the fill).
  const EV = { dark: { fill: .2, sel: .08, meta: .14, hue: .74 },
    paper: { fill: .44, fillY: .71, sel: .08, selY: .65, meta: .12, hue: .8, hover: .3, past: .6, dec: .45 } };
  const relL = h => hx(h).map(v => { v /= 255; return v <= .04045 ? v / 12.92 : ((v + .055) / 1.055) ** 2.4; }).reduce((a, v, i) => a + v * [.2126, .7152, .0722][i], 0);
  // the most hue (≤ tMax, in steps of .005) whose mix with base stays at or above luminance yMin
  const tint = (base, hex, tMax, yMin) => { let t = tMax; while (t > .05 && relL(mx(base, hex, t)) < yMin) t -= .005; return mx(base, hex, t); };

  function themeOf(th) {
    const d = th === 'dark';
    const t = Object.assign({ dark: d }, d ? DARK : PAPER, LINES[th]);
    t.accent = t.fg1; t.onAccent = t.bg;
    const L = x => mx(t.bg, t.fg1, x);
    t.hover = L(d ? .05 : .04); t.hoverRail = mx(t.rail, t.fg1, d ? .05 : .035); t.selected = L(d ? .09 : .07);
    t.grid = L(t.lineHour); t.gridV = L(t.lineDay); t.gridHalf = L(t.lineHalf);
    t.hair = L(t.lineHair); t.hairStrong = t.hairStrong || L(d ? .2 : .22);
    t.segRing = mx(t.surface, t.fg1, d ? .4 : .5);
    t.hourc = t.fg2;
    return t;
  }
  const T = { dark: themeOf('dark'), paper: themeOf('paper') };

  function ev(hex, th) {
    const t = T[th], d = t.dark, e = EV[th], bg = t.bg;
    const fill = d ? mx(bg, hex, e.fill) : tint(t.raised, hex, e.fill, e.fillY);
    const fillSel = d ? mx(bg, hex, e.fill + e.sel) : tint(t.raised, hex, e.fill + e.sel, e.selY);
    const title = d ? mx(hex, '#FFFFFF', e.hue) : mx(hex, PAPER.ink, e.hue);
    const titleSel = d ? mx(hex, '#FFFFFF', e.hue + .06) : mx(hex, PAPER.ink, Math.min(.92, e.hue + .06));
    const mark = d ? hex : mx(hex, PAPER.ink, .12);
    return {
      cc: mark, mark, fill, title, meta: mx(title, fill, e.meta), fillH: d ? mx(fill, '#FFFFFF', .05) : mx(fill, '#FFFFFF', e.hover),
      fillSel, titleSel, metaSel: mx(titleSel, fillSel, Math.max(.04, e.meta - .08)),
      fillPast: mx(fill, bg, d ? .55 : e.past), titlePast: t.fg2, metaPast: t.fg3, fillDec: mx(fill, bg, d ? .5 : e.dec), titleDec: t.fg2,
      bar: 'transparent', barPast: 'transparent',
      edge: d ? mx(hex, t.fg1, .15) : mx(hex, PAPER.ink, .38),
    };
  }
  // the variable names app.css reads for events
  const evVars = c => `--cc:${c.cc};--bar:${c.bar};--barp:${c.barPast};--dot:${c.mark};--fill:${c.fill};--fillh:${c.fillH};--fills:${c.fillSel};--fillp:${c.fillPast};` +
    `--tc:${c.title};--tcs:${c.titleSel};--mc:${c.meta};--mcs:${c.metaSel};--tcp:${c.titlePast};--mcp:${c.metaPast};--decfill:${c.fillDec};--dectc:${c.titleDec};--line:${c.edge}`;

  return {
    id: 'L0', name: 'v8', darkName: 'Dark (graphite)', H: 44, gap: { l: 2, r: 5, b: 2 }, icStroke: 1.5, T, mix: mx,
    vars(th) {
      const t = T[th], d = t.dark;
      return css({
        bg: t.bg, rail: t.rail, surface: t.surface, raised: t.raised, fg1: t.fg1, fg2: t.fg2, fg3: t.fg3, fg4: t.fg4,
        accent: t.accent, 'on-accent': t.onAccent, focus: t.focus, live: t.live, 'on-live': t.onLive, ok: t.ok, warn: t.warn, danger: t.danger,
        hover: t.hover, 'hover-rail': t.hoverRail, 'seg-ring': t.segRing, selected: t.selected, hair: t.hair, grid: t.grid, 'grid-v': t.gridV, 'grid-half': t.gridHalf,
        'hair-strong': t.hairStrong, hourc: t.hourc, macbar: d ? '#1E1E21' : '#E7E2D7',
        scrim: d ? 'rgba(0,0,0,.6)' : 'rgba(60,50,35,.22)',
        'shadow-pop': d ? '0 0 0 1px rgba(255,255,255,.07), 0 12px 32px rgba(0,0,0,.55)' : '0 0 0 1px rgba(60,50,35,.10), 0 1px 2px rgba(60,50,35,.06), 0 8px 24px rgba(60,50,35,.10)',
        'shadow-dialog': d ? '0 0 0 1px rgba(255,255,255,.08), 0 24px 64px rgba(0,0,0,.65)' : '0 0 0 1px rgba(60,50,35,.10), 0 2px 4px rgba(60,50,35,.06), 0 24px 64px rgba(60,50,35,.16)',
        fg: t.fg1, ph: t.fg3, bg2: t.surface, pop: t.raised,
        sans: INTER, mono: INTER, ff: "'cv05' 1, 'cv08' 1", 'tr-s': '.004em', 'tr-b': '-.004em', 'tr-h': '-.01em',
        'r-ev': '4px', 'r-sm': '6px', 'r-md': '8px', 'r-lg': '12px',
      });
    },
    ev,
    evVars: (hex, th) => evVars(ev(hex, th)),
    calDot: (hex, th) => ev(hex, th).mark,
    // pairs for contrast.mjs
    check(th) {
      const t = T[th];
      return {
        dark: t.dark, canvas: t.dark ? [['bg', t.bg], ['rail', t.rail]] : [['bg', t.bg], ['raised', t.raised]],
        soft: [t.dark ? ['raised', t.raised] : ['rail', t.rail], ['surface', t.surface], ['hover', t.hover], ['hover on rail', t.hoverRail], ['selected', t.selected]],
        fg1: t.fg1, fg2: t.fg2, fg3: t.fg3, hourc: t.hourc, accent: t.accent, onAccent: t.onAccent, focus: t.focus,
        live: t.live, liveText: t.live, onLive: t.onLive, liveOn: [['bg', t.bg], ['rail', t.rail], ['card', t.dark ? t.surface : t.raised]], segRing: t.segRing, track: t.surface,
        lines: [['hour line (timetable)', t.grid, 'structure'], ['half-hour line', t.gridHalf, 'decor'], ['day divider', t.gridV, 'decor'], ['all-day edge', t.hairStrong, 'structure'], ['pane edge', t.hair, 'decor']],
        status: [['ok', t.ok], ['warn', t.warn], ['danger', t.danger]], ev: hex => ev(hex, th),
      };
    },
  };
})();

// ================================================================ v9 looks L1–L4 (round 2026-11-20)
// Each look = a palette per mode, line mixes, an event recipe and a few CSS variables; looks.css adds the shape under .pk-Lx.
// Every text colour an event recipe makes goes through fit(): it starts from the colour the design wants and moves toward
// ink (Paper) or white (Dark) only as far as the floors of contrast.mjs need (plus a small margin), so nothing is darkened blindly.
const LOOKS9 = (() => {
  const hx = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
  const mx = (a, b, t) => { const x = hx(a), y = hx(b); return '#' + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, '0')).join('').toUpperCase(); };
  const css = o => Object.entries(o).map(([k, x]) => `--${k}:${x}`).join(';');
  const INTER = "'Inter', -apple-system, 'SF Pro Text', system-ui, sans-serif";
  const lin = c => c <= .04045 ? c / 12.92 : ((c + .055) / 1.055) ** 2.4;
  const relL = h => hx(h).map(v => lin(v / 255)).reduce((a, v, i) => a + v * [.2126, .7152, .0722][i], 0);
  const wcag = (a, b) => { const x = relL(a), y = relL(b); return (Math.max(x, y) + .05) / (Math.min(x, y) + .05); };
  function apca(txt, bg) {
    const Y = h => { const [r, g, b] = hx(h).map(c => (c / 255) ** 2.4); return .2126729 * r + .7151522 * g + .072175 * b; };
    const cl = y => y > .022 ? y : y + (.022 - y) ** 1.414;
    const t = cl(Y(txt)), b = cl(Y(bg));
    if (Math.abs(b - t) < .0005) return 0;
    if (b > t) { const s = (b ** .56 - t ** .57) * 1.14; return s < .1 ? 0 : (s - .027) * 100; }
    const s = (b ** .65 - t ** .62) * 1.14; return s > -.1 ? 0 : (s + .027) * 100;
  }
  // the event floors of contrast.mjs ([ratio, |Lc|]) with a small margin
  const F = {
    dark: { title: [7, 75], meta: [6.5, 60], selMeta: [5.5, 55], pastTitle: [7, 65], pastMeta: [5.7, 48], decl: [6, 55] },
    paper: { title: [7, 75], meta: [5.9, 70], selMeta: [5.5, 65], pastTitle: [7, 75], pastMeta: [5, 65], decl: [6.5, 75] },
  };
  // the most hue (≤ tMax) whose mix with base stays at or above luminance yMin (Paper) / at or below yMax (Dark)
  const tintUp = (base, h, tMax, yMin) => { let t = tMax; while (t > .03 && relL(mx(base, h, t)) < yMin) t -= .005; return mx(base, h, t); };
  const tintDn = (base, h, tMax, yMax) => { let t = tMax; while (t > .03 && relL(mx(base, h, t)) > yMax) t -= .005; return mx(base, h, t); };
  const ok = (fg, bg, [r, lc]) => wcag(fg, bg) >= r + .05 && Math.abs(apca(fg, bg)) >= lc + .6;
  // move fg toward `to` until it passes on every background in bgs
  const fit = (fg, bgs, to, floor) => { let t = 0, c = fg; const B = [].concat(bgs); while (t < 1 && !B.every(b => ok(c, b, floor))) { t += .01; c = mx(fg, to, t); } return c; };
  // OKLCH, for L3: darken a hue by perceptual lightness, keep its hue, and give up only the chroma sRGB cannot show
  const toLin = h => hx(h).map(v => lin(v / 255)), toS = v => { v = Math.max(0, Math.min(1, v)); return v <= .0031308 ? 12.92 * v : 1.055 * v ** (1 / 2.4) - .055; };
  function oklch(h) {
    const [r, g, b] = toLin(h);
    const l = Math.cbrt(.4122214708 * r + .5363325363 * g + .0514459929 * b), m = Math.cbrt(.2119034982 * r + .6806995451 * g + .1073969566 * b), q = Math.cbrt(.0883024619 * r + .2817188376 * g + .6299787005 * b);
    const L = .2104542553 * l + .793617785 * m - .0040720468 * q, A = 1.9779984951 * l - 2.428592205 * m + .4505937099 * q, B = .0259040371 * l + .7827717662 * m - .808675766 * q;
    return [L, Math.hypot(A, B), Math.atan2(B, A)];
  }
  function rgbOf([L, C, H]) {
    const A = C * Math.cos(H), B = C * Math.sin(H);
    const l = (L + .3963377774 * A + .2158037573 * B) ** 3, m = (L - .1055613458 * A - .0638541728 * B) ** 3, q = (L - .0894841775 * A - 1.291485548 * B) ** 3;
    return [4.0767416621 * l - 3.3077115913 * m + .2309699292 * q, -1.2684380046 * l + 2.6097574011 * m - .3413193965 * q, -.0041960863 * l - .7034186147 * m + 1.707614701 * q];
  }
  function fromOklch([L, C, H]) {
    let c = C, v = rgbOf([L, c, H]);
    while (c > 0 && v.some(x => x < -1e-4 || x > 1 + 1e-4)) { c -= .002; v = rgbOf([L, c, H]); }
    return '#' + v.map(x => Math.round(toS(x) * 255).toString(16).padStart(2, '0')).join('').toUpperCase();
  }

  // ---------------------------------------------------------------- neutral palettes
  const NEUTRAL = {
    // L1: near-white / #191919, no warm or blue cast
    L1: {
      paper: { bg: '#FFFFFF', rail: '#F8F8F7', surface: '#F0F0EF', raised: '#FFFFFF', fg1: '#1D1D1F', fg2: '#45454A', fg3: '#5C5C62', fg4: '#A3A3A8',
        focus: '#2F6BDC', live: '#C2362B', ok: '#2F7A4B', warn: '#8A5A00', danger: '#B4382D', onLive: '#FFFFFF', ink: '#141416' },
      dark: { bg: '#191919', rail: '#141414', surface: '#222222', raised: '#252525', fg1: '#ECECEC', fg2: '#C9C9C9', fg3: '#A8A8A8', fg4: '#5E5E5E',
        focus: '#6E9BF5', live: '#FF6B5F', ok: '#6CC58A', warn: '#E5B44A', danger: '#FF7B72', onLive: '#191919', ink: '#FFFFFF' },
    },
    // L2: cool neutral (Apple-like)
    L2: {
      paper: { bg: '#FCFCFD', rail: '#F4F5F7', surface: '#ECEDF0', raised: '#FFFFFF', fg1: '#1C1D21', fg2: '#44464D', fg3: '#5A5C64', fg4: '#A2A4AB',
        focus: '#2F6BDC', live: '#C2362B', ok: '#2F7A4B', warn: '#8A5A00', danger: '#B4382D', onLive: '#FFFFFF', ink: '#12141A' },
      dark: { bg: '#1C1C1F', rail: '#1A1A1D', surface: '#252529', raised: '#29292D', fg1: '#F0F0F2', fg2: '#C9CAD0', fg3: '#A9AAB2', fg4: '#5F6068',
        focus: '#6E9BF5', live: '#FF6B5F', ok: '#6CC58A', warn: '#E5B44A', danger: '#FF7B72', onLive: '#1C1C1F', ink: '#FFFFFF' },
    },
    // L3: white / near-black so the solid colours carry the page
    L3: {
      paper: { bg: '#FFFFFF', rail: '#F7F7F8', surface: '#EFEFF1', raised: '#FFFFFF', fg1: '#1B1B1F', fg2: '#44444B', fg3: '#5B5B63', fg4: '#A2A2A9',
        focus: '#2F6BDC', live: '#C2362B', ok: '#2F7A4B', warn: '#8A5A00', danger: '#B4382D', onLive: '#FFFFFF', ink: '#121216' },
      dark: { bg: '#17171A', rail: '#151518', surface: '#212125', raised: '#27272B', fg1: '#EEEEF0', fg2: '#C9C9CF', fg3: '#A9A9B1', fg4: '#5E5E66',
        focus: '#6E9BF5', live: '#FF6B5F', ok: '#6CC58A', warn: '#E5B44A', danger: '#FF7B72', onLive: '#17171A', ink: '#FFFFFF' },
    },
    // L4: cards on a slightly darker canvas (raised = the card)
    L4: {
      paper: { bg: '#EFEFF2', rail: '#FAFAFB', surface: '#E6E6EA', raised: '#FFFFFF', fg1: '#141417', fg2: '#414148', fg3: '#55555D', fg4: '#9E9EA6',
        focus: '#2F6BDC', live: '#C8362B', ok: '#2D7548', warn: '#855700', danger: '#B0372C', onLive: '#FFFFFF', ink: '#121216' },
      dark: { bg: '#161618', rail: '#111113', surface: '#1F1F22', raised: '#26262A', fg1: '#EDEDF0', fg2: '#C8C8CF', fg3: '#A8A8B1', fg4: '#5C5C64',
        focus: '#6E9BF5', live: '#FF6B5F', ok: '#6CC58A', warn: '#E5B44A', danger: '#FF7B72', onLive: '#161618', ink: '#FFFFFF' },
    },
  };
  // grid lines as a mix of bg toward fg1: quieter than v8 (.15 / .05 / .10) but the hour line stays visible (≥ 1.15:1)
  const LINES = {
    L1: { dark: { lineHour: .12, lineHalf: .035, lineDay: .075, lineHair: .085, lineAd: .14 }, paper: { lineHour: .1, lineHalf: .03, lineDay: .07, lineHair: .08, lineAd: .12 } },
    L2: { dark: { lineHour: .12, lineHalf: .035, lineDay: .075, lineHair: .085, lineAd: .14 }, paper: { lineHour: .1, lineHalf: .03, lineDay: .07, lineHair: .08, lineAd: .12 } },
    L3: { dark: { lineHour: .12, lineHalf: .035, lineDay: .07, lineHair: .085, lineAd: .14 }, paper: { lineHour: .1, lineHalf: .03, lineDay: .065, lineHair: .08, lineAd: .12 } },
    L4: { dark: { lineHour: .11, lineHalf: .03, lineDay: .07, lineHair: .08, lineAd: .13 }, paper: { lineHour: .1, lineHalf: .03, lineDay: .075, lineHair: .08, lineAd: .12 } },
  };

  function themeOf(id, th) {
    const d = th === 'dark';
    const t = Object.assign({ dark: d }, NEUTRAL[id][th], LINES[id][th]);
    t.accent = t.fg1; t.onAccent = t.bg;
    const L = x => mx(t.bg, t.fg1, x);
    t.hover = L(d ? .05 : .04); t.hoverRail = mx(t.rail, t.fg1, d ? .05 : .04); t.selected = L(d ? .08 : .055);
    t.grid = L(t.lineHour); t.gridV = L(t.lineDay); t.gridHalf = L(t.lineHalf);
    t.hair = L(t.lineHair); t.hairStrong = L(t.lineAd);
    t.segRing = mx(t.surface, t.fg1, d ? .4 : .5);
    t.hourc = t.fg2;
    // Join: a calm raised neutral button (the call logo carries the colour), not a black or white slab
    t.joinBg = d ? t.raised : '#FFFFFF'; t.joinFg = t.fg1;
    return t;
  }

  // ---------------------------------------------------------------- event recipes
  // out: the same keys as v8 (app.css reads them through evVars), plus bar (L1, L4) and edge2 (L2 hue edge)
  const W = '#FFFFFF';
  const R = {
    // L1 · Clean bar: light hue tint, a 3 px saturated bar, near-fg1 title, muted smaller time
    L1(hex, t, th) {
      const d = t.dark, f = F[th], to = d ? W : t.ink;
      const fill = d ? mx(t.bg, hex, .2) : mx(W, hex, .17);
      const fillH = d ? mx(t.bg, hex, .26) : mx(W, hex, .23);
      const fillSel = d ? mx(t.bg, hex, .32) : mx(W, hex, .3);
      const title = fit(d ? mx(t.fg1, hex, .12) : mx(t.fg1, hex, .18), [fill, fillH], to, f.title);
      const titleSel = fit(title, fillSel, to, f.title);
      const meta = fit(mx(title, fill, d ? .32 : .36), fill, title, f.meta);
      const metaSel = fit(mx(titleSel, fillSel, .3), fillSel, titleSel, f.selMeta);
      const fillPast = d ? mx(t.bg, hex, .1) : mx(W, hex, .085);
      const titlePast = fit(t.fg2, fillPast, to, f.pastTitle), metaPast = fit(t.fg3, fillPast, to, f.pastMeta);
      const fillDec = d ? mx(t.bg, hex, .1) : mx(W, hex, .08);
      const bar = d ? mx(hex, W, .08) : mx(hex, t.ink, .06);
      return { cc: bar, mark: bar, fill, fillH, fillSel, title, titleSel, meta, metaSel, fillPast, titlePast, metaPast,
        fillDec, titleDec: fit(t.fg2, fillDec, to, f.decl), bar, barPast: mx(bar, t.bg, .38), edge: fit(bar, t.bg, d ? W : t.ink, [3, 0]) };
    },
    // L2 · Soft solid: a clearly tinted fill with a faint 1 px hue edge, title in the deep (Paper) / bright (Dark) hue, no bar
    L2(hex, t, th) {
      const d = t.dark, f = F[th], to = d ? W : t.ink;
      const fill = d ? tintDn(t.bg, hex, .3, .045) : tintUp(W, hex, .26, .7);
      const fillH = d ? tintDn(t.bg, hex, .36, .055) : tintUp(W, hex, .32, .64);
      const fillSel = d ? tintDn(t.bg, hex, .42, .065) : tintUp(W, hex, .38, .6);
      const title = fit(d ? mx(hex, W, .5) : mx(hex, t.ink, .55), [fill, fillH], to, f.title);
      const titleSel = fit(title, fillSel, to, f.title);
      const meta = fit(mx(title, fill, .22), fill, title, f.meta);
      const metaSel = fit(mx(titleSel, fillSel, .2), fillSel, titleSel, f.selMeta);
      const fillPast = d ? mx(t.bg, hex, .14) : mx(W, hex, .1);
      const titlePast = fit(d ? mx(hex, W, .62) : mx(hex, t.ink, .6), fillPast, to, f.pastTitle);
      const metaPast = fit(mx(titlePast, fillPast, .3), fillPast, titlePast, f.pastMeta);
      const fillDec = d ? mx(t.bg, hex, .14) : mx(W, hex, .1);
      const mark = d ? hex : mx(hex, t.ink, .08);
      return { cc: mark, mark, fill, fillH, fillSel, title, titleSel, meta, metaSel, fillPast, titlePast, metaPast,
        fillDec, titleDec: fit(t.fg2, fillDec, to, f.decl), bar: 'transparent', barPast: 'transparent',
        edge: fit(mark, t.bg, d ? W : t.ink, [3, 0]), edge2: d ? mx(fill, hex, .2) : mx(fill, hex, .26) };
    },
    // L3 · Vivid: the hue as a solid fill with a white title; the hue is darkened (HSL lightness only, saturation kept)
    // just until the white title, its time, hover and selected pass. Past: a light tint with a hue-dark title (clearly lighter).
    L3(hex, t, th) {
      const d = t.dark, f = F[th];
      const [L0, C0, H] = oklch(hex);
      const meta0 = c => mx(W, c, .1);
      let l = L0, fill = hex;
      const pass = c => ok(W, c, f.title) && ok(meta0(c), c, f.meta) && ok(W, mx(c, '#000000', .06), f.title);
      while (l > .1 && !pass(fill)) { l -= .004; fill = fromOklch([l, C0, H]); }
      const fillH = mx(fill, '#000000', .08), fillSel = mx(fill, '#000000', .14);
      const title = W, titleSel = W, meta = fit(meta0(fill), fill, W, f.meta), metaSel = fit(mx(W, fillSel, .1), fillSel, W, f.selMeta);
      const fillPast = d ? mx(t.bg, fill, .3) : mx(W, hex, .16);
      const titlePast = d ? fit(mx(t.fg2, hex, .1), fillPast, W, f.pastTitle) : fit(mx(fill, t.ink, .2), fillPast, t.ink, f.pastTitle);
      const metaPast = fit(mx(titlePast, fillPast, .3), fillPast, titlePast, f.pastMeta);
      const fillDec = d ? mx(t.bg, fill, .3) : mx(W, hex, .16);
      const titleDec = d ? fit(t.fg2, fillDec, W, f.decl) : fit(mx(fill, t.ink, .2), fillDec, t.ink, f.decl);
      const mark = hex; // the sidebar square and the right-column bars keep the calendar colour itself
      return { cc: mark, mark, fill, fillH, fillSel, title, titleSel, meta, metaSel, fillPast, titlePast, metaPast, fillDec, titleDec,
        bar: 'transparent', barPast: 'transparent', edge: fit(d ? mx(hex, W, .1) : fill, t.bg, d ? W : t.ink, [3, 0]) };
    },
    // L4 · Cards: neutral raised cards, colour only as the 3 px bar, title fg1
    L4(hex, t, th) {
      const d = t.dark, f = F[th], to = d ? W : t.ink;
      const fill = t.raised, fillH = d ? mx(t.raised, t.fg1, .04) : mx(W, hex, .035);
      const fillSel = d ? mx(t.raised, hex, .12) : mx(W, hex, .09);
      const title = fit(t.fg1, [fill, fillH], to, f.title), titleSel = fit(t.fg1, fillSel, to, f.title);
      const meta = fit(t.fg2, [fill, fillH], to, f.meta), metaSel = fit(t.fg2, fillSel, to, f.selMeta);
      const fillPast = d ? mx(t.raised, t.bg, .55) : mx(W, t.bg, .5);
      const titlePast = fit(t.fg2, fillPast, to, f.pastTitle), metaPast = fit(t.fg3, fillPast, to, f.pastMeta);
      const fillDec = fillPast, bar = d ? hex : mx(hex, t.ink, .04);
      return { cc: bar, mark: bar, fill, fillH, fillSel, title, titleSel, meta, metaSel, fillPast, titlePast, metaPast,
        fillDec, titleDec: fit(t.fg2, fillDec, to, f.decl), bar, barPast: mx(bar, fillPast, .55), edge: fit(bar, t.bg, d ? W : t.ink, [3, 0]) };
    },
  };
  const evVars = c => `--cc:${c.cc};--bar:${c.bar};--barp:${c.barPast};--dot:${c.mark};--fill:${c.fill};--fillh:${c.fillH};--fills:${c.fillSel};--fillp:${c.fillPast};` +
    `--tc:${c.title};--tcs:${c.titleSel};--mc:${c.meta};--mcs:${c.metaSel};--tcp:${c.titlePast};--mcp:${c.metaPast};--decfill:${c.fillDec};--dectc:${c.titleDec};--line:${c.edge}` +
    (c.edge2 ? `;--edge2:${c.edge2}` : '');

  const META = {
    L1: { name: 'Clean bar', ew: 560, r: '6px', note: 'light hue tint, 3 px bar, near-fg1 title' },
    L2: { name: 'Soft solid', ew: 600, r: '6px', note: 'tinted fill, 1 px hue edge, deep-hue title' },
    L3: { name: 'Vivid', ew: 600, r: '5px', note: 'solid hue, white title' },
    L4: { name: 'Cards', ew: 560, r: '6px', note: 'raised neutral cards, 3 px bar' },
  };
  function make(id) {
    const T = { dark: themeOf(id, 'dark'), paper: themeOf(id, 'paper') }, m = META[id];
    const cache = {};
    const ev = (hex, th) => cache[th + hex] || (cache[th + hex] = R[id](hex, T[th], th));
    const sh = d => d ? 'rgba(0,0,0' : 'rgba(20,20,30';
    return {
      id, name: m.name, darkName: 'Dark', H: 44, icStroke: 1.5, T, mix: mx, gap: { l: 2, r: 6, b: 3 },
      vars(th) {
        const t = T[th], d = t.dark, s = sh(d);
        return css({
          bg: t.bg, rail: t.rail, surface: t.surface, raised: t.raised, fg1: t.fg1, fg2: t.fg2, fg3: t.fg3, fg4: t.fg4,
          accent: t.accent, 'on-accent': t.onAccent, focus: t.focus, live: t.live, 'on-live': t.onLive, ok: t.ok, warn: t.warn, danger: t.danger,
          hover: t.hover, 'hover-rail': t.hoverRail, 'seg-ring': t.segRing, selected: t.selected, hair: t.hair, grid: t.grid, 'grid-v': t.gridV, 'grid-half': t.gridHalf,
          'hair-strong': t.hairStrong, hourc: t.hourc, macbar: d ? '#1E1E20' : '#E9E9EB',
          scrim: d ? 'rgba(0,0,0,.6)' : 'rgba(20,20,30,.2)',
          'shadow-pop': d ? '0 0 0 1px rgba(255,255,255,.07), 0 12px 32px rgba(0,0,0,.55)' : `0 0 0 1px ${s},.08), 0 1px 2px ${s},.05), 0 8px 24px ${s},.10)`,
          'shadow-dialog': d ? '0 0 0 1px rgba(255,255,255,.08), 0 24px 64px rgba(0,0,0,.65)' : `0 0 0 1px ${s},.08), 0 2px 4px ${s},.05), 0 24px 64px ${s},.15)`,
          'shadow-card': d ? 'inset 0 0 0 1px rgba(255,255,255,.055), 0 1px 2px rgba(0,0,0,.35)' : `0 0 0 1px ${s},.07), 0 1px 2px ${s},.07)`,
          'join-bg': t.joinBg, 'join-fg': t.joinFg,
          'join-sh': d ? 'inset 0 0 0 1px rgba(255,255,255,.09), 0 1px 1px rgba(0,0,0,.3)' : `0 0 0 1px ${s},.12), 0 1px 2px ${s},.08)`,
          fg: t.fg1, ph: t.fg3, bg2: t.surface, pop: t.raised,
          sans: INTER, mono: INTER, ff: "'cv05' 1, 'cv08' 1", 'tr-s': '.004em', 'tr-b': '-.004em', 'tr-h': '-.01em',
          'r-ev': m.r, 'r-sm': '6px', 'r-md': '8px', 'r-lg': '12px', 'ev-w': m.ew,
        });
      },
      ev,
      evVars: (hex, th) => evVars(ev(hex, th)),
      calDot: (hex, th) => ev(hex, th).mark,
      check(th) {
        const t = T[th];
        return {
          dark: t.dark, canvas: t.dark ? [['bg', t.bg], ['rail', t.rail]] : [['bg', t.bg], ['raised', t.raised], ['rail', t.rail]],
          soft: [t.dark ? ['raised', t.raised] : ['surface', t.surface], ['surface', t.surface], ['hover', t.hover], ['hover on rail', t.hoverRail], ['selected', t.selected]],
          fg1: t.fg1, fg2: t.fg2, fg3: t.fg3, hourc: t.hourc, accent: t.accent, onAccent: t.onAccent, focus: t.focus,
          live: t.live, liveText: t.live, onLive: t.onLive, liveOn: [['bg', t.bg], ['rail', t.rail], ['card', t.dark ? t.surface : t.raised]], segRing: t.segRing, track: t.surface,
          lines: [['hour line (timetable)', t.grid, 'structure'], ['half-hour line', t.gridHalf, 'decor'], ['day divider', t.gridV, 'decor'], ['all-day edge', t.hairStrong, 'structure'], ['pane edge', t.hair, 'decor']],
          status: [['ok', t.ok], ['warn', t.warn], ['danger', t.danger]], ev: hex => ev(hex, th),
          join: { fg: t.joinFg, bg: t.joinBg },
        };
      },
    };
  }
  return { L1: make('L1'), L2: make('L2'), L3: make('L3'), L4: make('L4') };
})();

const THEME = {
  H: 44, ids: ['L0', 'L1', 'L2', 'L3', 'L4'], def: 'L1',
  looks: Object.assign({ L0: THEME_L0 }, LOOKS9),
  look(id) { return this.looks[id] || this.looks[this.def]; },
};
if (typeof module !== 'undefined') module.exports = THEME;
