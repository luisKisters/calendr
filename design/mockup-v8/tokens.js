// Calendr v8 · the one theme: D3 "Graphite timetable", Dark and Paper. One source for the page (app.js reads THEME through PK()
// for CSS variables, event colours and structure flags) and for the contrast check (node design/mockup-v8/contrast.mjs).
// Locked 2026-11-05: D3 is the design. The other v7 packs (A, B, C, D1, D2, D4) and the pack switch are gone.
//   Dark  = graphite canvas #131315, darker sidebars #0E0E10 with hairline pane edges, timetable lines (hour + quiet half hour),
//           no event bar, titles tinted with the calendar hue on a soft fill. Inter.
//   Paper = warm paper #F7F4EC, rail #F0ECE3, the same mark and lines, clear pastel fills of the calendar hue, hue-dark titles.
// v8 density pass: quieter half-hour line, hour line kept clearly visible, live red also as a pill colour (--on-live).
'use strict';
const THEME = (() => {
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
    id: 'D3', name: 'Graphite timetable', darkName: 'Dark (graphite)', H: 44, icStroke: 1.5, T, mix: mx,
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
if (typeof module !== 'undefined') module.exports = THEME;
