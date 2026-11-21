// Horion v6 · A "Calm graphite": the design tokens. One source for the page (app.js turns them into CSS
// custom properties) and for contrast.mjs (node design/mockup-v6-a/contrast.mjs prints WCAG + APCA for every pair).
// Brief: design/mockup-v5/READABILITY-BRIEF.md §5 and §6 A.
'use strict';

const hex2 = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const mix = (a, b, t) => { const x = hex2(a), y = hex2(b); return '#' + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, '0')).join('').toUpperCase(); };

const TOKENS = {
  dark: {
    dark: true,
    bg: '#111113',        // canvas: grid, header, all-day lane
    side: '#0D0D0F',      // both sidebars: their own shade (C8), one step darker than the canvas, so no pane hairline is needed
    surface: '#18181B',   // cards, segmented track, settings groups
    raised: '#202024',    // fields, buttons, menus, popovers, dialogs
    hair: '#232327',      // pane edges where scrolling meets fixed chrome (decorative, Lc < 15)
    line: '#252529',      // hour grid and day columns: same strength as the C8 decision (13 % on black)
    hairStrong: '#3A3A40',// all-day lane edge (C8: 22 %), paper field outline
    fg1: '#EDEDEF', fg2: '#C4C4CA', fg3: '#A6A6AE', fg4: '#62626A',
    accent: '#EDEDEF', onAccent: '#111113',
    segRing: '#76767E',   // selected segment ring: ≥ 3:1 against the track
    focus: '#6E9BF5', live: '#FF5A4F', danger: '#C8463C', onDanger: '#FFFFFF',
    hoverA: 5, selA: 9,   // fg1 mixed over the surface below, in %
    scrim: 'rgba(0,0,0,.5)', shadow: '0 8px 24px rgba(0,0,0,.5)', shadowBig: '0 24px 64px rgba(0,0,0,.55)',
  },
  paper: {
    dark: false,
    bg: '#FAF9F6',
    side: '#F4F2EE',
    surface: '#F2F0EB',
    raised: '#FFFFFF',
    hair: '#E6E3DC',
    line: '#E3E0D9',      // C8: 14 % on paper
    hairStrong: '#CFCBC2',
    fg1: '#1C1B20', fg2: '#4B4952', fg3: '#625F69', fg4: '#A3A0A8',
    accent: '#1C1B20', onAccent: '#FAF9F6',
    segRing: '#86828D',
    focus: '#2F6BDC', live: '#D93A2F', danger: '#C23B31', onDanger: '#FFFFFF',
    hoverA: 3.5, selA: 5,
    scrim: 'rgba(40,36,30,.24)', shadow: '0 1px 2px rgba(0,0,0,.06), 0 8px 24px rgba(0,0,0,.08)', shadowBig: '0 2px 6px rgba(0,0,0,.06), 0 24px 64px rgba(40,34,20,.16)',
  },
};

// Event block recipe (brief §5): one decoration per state; text greys are mixed toward the fill, never opacity.
function evColors(hex, theme, task) {
  const T = TOKENS[theme], dark = T.dark;
  const base = task ? T.fg1 : hex;
  const fill = mix(T.bg, base, task ? (dark ? .13 : .075) : dark ? .24 : .16);
  const title = task || dark ? T.fg1 : mix(hex, '#0B0B10', .72);
  const meta = mix(title, fill, dark ? .18 : .15);
  const fillPast = mix(fill, T.bg, .55);
  const fillSel = task ? mix(T.bg, base, dark ? .2 : .12) : mix(T.bg, hex, dark ? .34 : .26);
  return {
    fill, title, meta,
    fillH: dark ? mix(fill, '#FFFFFF', .05) : mix(fill, '#FFFFFF', .35),   // hover: only lighter
    fillSel, metaSel: mix(title, fillSel, dark ? .06 : .08),   // selected: one step stronger fill + a 1.5 px fg1 ring
    fillPast, titlePast: T.fg2, metaPast: T.fg3,
    fillDec: mix(fill, T.bg, .5), titleDec: T.fg2,
    bar: dark ? 'transparent' : hex, barPast: dark ? 'transparent' : mix(hex, T.bg, .5),
    edge: dark ? mix(hex, T.fg1, .1) : mix(hex, '#0B0B10', .38), // "needs reply" outline, maybe dots: ≥ 3:1 on the canvas
    mark: dark ? hex : mix(hex, '#0B0B10', .12),                   // the one colour mark in lists, dots and bars
  };
}

if (typeof module !== 'undefined') module.exports = { TOKENS, evColors, mix, hex2 };
