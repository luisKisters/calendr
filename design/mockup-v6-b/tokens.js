// Calendr v6 · B "Structured contrast": the design tokens. One source for the app (app.js themeVars / evVars)
// and for the contrast check (node design/mockup-v6-b/contrast.mjs). Values follow READABILITY-BRIEF.md §5–6 (direction B).
'use strict';

const TOKENS = {
  // OLED black, off-white text (no halation), surfaces step up in lightness, hues only on events
  dark: {
    bg: '#000000',        // canvas, grid
    surface: '#0E0E10',   // sidebars (own shade, locked C8), all-day lane, cards at rest
    raised: '#18181B',    // fields, buttons, menus, popovers, dialogs, the "Now" card
    raised2: '#232327',   // hover on raised, grouped boxes inside dialogs, secondary buttons in dialogs
    track: '#161618',     // segmented-control track
    thumb: '#2C2C31',     // selected segment
    segRing: '#6E6E76',   // 1 px ring on the selected segment: ≥ 3:1 against the track (fill alone is 1.3:1)
    fg1: '#E6E6E8',       // titles, values           target ≥ 12:1, Lc 88–96
    fg2: '#C8C8CE',       // times, secondary rows   target ≥ 7:1,  Lc ≥ 68
    fg3: '#A4A4AC',       // labels, hints, icons    target ≥ 6.5:1, Lc ≥ 48 (weight ≥ 500 or icons)
    fg4: '#5E5E66',       // disabled only (exempt)
    hourLabel: '#C8C8CE', // B: hour labels in fg2
    lineHalf: '#151518',  // half-hour tick, decoration (Lc < 15 on purpose)
    lineDay: '#1C1C1F',   // day column divider
    lineHour: '#28282C',  // full hour
    lineEdge: '#36363C',  // where scrolling content meets fixed chrome (header, all-day lane)
    hairStrong: '#3A3A40',// field outline where a field has no fill
    hover: 7,             // % of fg1 over the surface below (lighter only)
    selected: 11,         // % of fg1
    accent: '#E6E6E8', onAccent: '#000000',
    focus: '#6E9BF5',
    live: '#FF5A4F', liveText: '#FF8075',
    ok: '#6CC58A', warn: '#E5B44A', danger: '#FF7B72', dangerFill: '#C62F28',
    scrim: 'rgba(0,0,0,.6)',
    shadowPop: '0 8px 24px rgba(0,0,0,.5)',
  },
  // pure white canvas, near-black ink, neutral (cool) greys
  paper: {
    bg: '#FFFFFF',
    surface: '#F4F4F6',
    raised: '#FFFFFF',
    raised2: '#EDEDF0',
    track: '#EBEBEE',
    thumb: '#FFFFFF',
    segRing: '#7A7A83',
    fg1: '#111114',       // target ≥ 12:1, Lc ≥ 95
    fg2: '#3E3E46',       // target ≥ 7:1, Lc ≥ 80
    fg3: '#5A5A63',       // target ≥ 5:1, Lc ≥ 70
    fg4: '#A3A3AB',
    hourLabel: '#3E3E46',
    lineHalf: '#F2F2F4',
    lineDay: '#E6E6EA',
    lineHour: '#D9D9DE',
    lineEdge: '#C4C4CB',
    hairStrong: '#C4C4CB',
    hover: 5,
    selected: 7,
    accent: '#111114', onAccent: '#FFFFFF',
    focus: '#2F6BDC',
    live: '#E0362B', liveText: '#BF2A20',
    ok: '#1E7B43', warn: '#8A5A00', danger: '#BF2A20', dangerFill: '#C62F28',
    scrim: 'rgba(20,20,24,.28)',
    shadowPop: '0 1px 2px rgba(0,0,0,.06), 0 8px 24px rgba(0,0,0,.10)',
  },
};

// ---------------------------------------------------------------- colour helpers
const tHex = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const tMix = (a, b, t) => { const x = tHex(a), y = tHex(b); return '#' + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, '0')).join(''); };

// Event block recipe (brief §5 + direction B). One decoration per state.
//   dark:  fill mix 0.30 + 3 px bar, title #FFFFFF, meta mix(title, fill, 0.18)
//   paper: fill mix 0.20 + 3 px bar, title fg1,     meta mix(title, fill, 0.22)
function eventColors(cc, theme) {
  const T = TOKENS[theme], d = theme === 'dark', bg = T.bg;
  const fill = tMix(bg, cc, d ? 0.30 : 0.20);
  const title = d ? '#FFFFFF' : T.fg1;
  return {
    cc,
    fill,
    fillHover: tMix(bg, cc, d ? 0.35 : 0.14),   // lighter only, both themes
    fillSel: tMix(bg, cc, d ? 0.42 : 0.28),     // selected: one step stronger + fg1 ring
    fillPast: tMix(fill, bg, 0.55),             // past: fill 55 % toward bg, text stays opaque
    fillDec: tMix(fill, bg, 0.50),              // declined: fill at 50 %
    bar: d ? cc : tMix(cc, '#000000', 0.12),
    barPast: tMix(d ? cc : tMix(cc, '#000000', 0.12), bg, 0.5),
    title,
    meta: tMix(title, fill, d ? 0.18 : 0.22),
    titlePast: T.fg2, metaPast: T.fg3,
    titleDec: T.fg2,
    outline: d ? tMix(cc, '#FFFFFF', 0.15) : tMix(cc, '#000000', 0.32), // needs reply (solid) / maybe (dotted)
  };
}

if (typeof module !== 'undefined') module.exports = { TOKENS, eventColors, tMix };
