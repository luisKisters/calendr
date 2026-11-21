// Calendr v6 · C "Warm editorial": the design tokens and the event colour recipe.
// One source for the page (index.html loads it before app.js) and for the contrast check (node contrast.mjs).
// Rules: READABILITY-BRIEF.md §5 and direction C. Neutrals are warm, colour means calendar only,
// one alert hue (live), one focus blue. Paper is the default; Dark is "warm night", first-class too.
'use strict';
const TOK = (() => {
  const hex2 = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
  // mix(a, b, t): t = 0 gives a, t = 1 gives b (sRGB, like the brief)
  const mix = (a, b, t) => { const x = hex2(a), y = hex2(b); return '#' + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, '0')).join('').toUpperCase(); };

  const THEMES = {
    paper: {
      dark: false,
      bg: '#F7F4EC',       // canvas and grid
      rail: '#F0ECE3',     // sidebars: their own shade (C8, locked)
      surface: '#ECE7DC',  // cards on the canvas, segmented track, chips
      raised: '#FFFDF8',   // fields, menus, popovers, dialogs, selected segment (with hair + soft shadow)
      fg1: '#211E19',      // titles, values
      fg2: '#47423A',      // times, secondary rows, inactive segments
      fg3: '#5B554C',      // labels, hints, placeholders, icons, hour labels
      fg4: '#A29C90',      // disabled only
      accent: '#211E19',   // ink: primary button, today pill
      onAccent: '#F7F4EC',
      focus: '#2F6BDC',
      live: '#C2362B',     // now line and "starting now" only
      ok: '#2F7A4B', warn: '#8A5A00', danger: '#B4382D',
      inkTitle: '#1A140C', // events: hue-dark titles mix toward this
    },
    dark: {
      dark: true,
      bg: '#151412',
      rail: '#1A1917',
      surface: '#201F1C',
      raised: '#292724',
      fg1: '#EEEAE2',
      fg2: '#CCC6BA',
      fg3: '#AAA498',
      fg4: '#67625A',
      accent: '#EEEAE2',
      onAccent: '#151412',
      focus: '#7AA2F7',
      live: '#FF6B5C',
      ok: '#7FCB98', warn: '#E9B949', danger: '#F28B7F',
      inkTitle: null,
    },
  };
  // neutral steps that are derived, not picked: hover lightens on dark and darkens on paper, never a hue
  for (const t of Object.values(THEMES)) {
    t.hover = mix(t.bg, t.fg1, t.dark ? .05 : .04);
    t.hoverRail = mix(t.rail, t.fg1, t.dark ? .05 : .05);
    t.selected = mix(t.bg, t.fg1, t.dark ? .09 : .07);
    t.hair = mix(t.bg, t.fg1, t.dark ? .075 : .085);        // pane edges: decorative, Lc < 15
    t.grid = mix(t.bg, t.fg1, t.dark ? .11 : .11);          // hour lines (C8 asked for visible ones; still below Lc 15)
    t.gridV = mix(t.bg, t.fg1, t.dark ? .08 : .08);         // day separators, softer than the hour lines
    t.hairStrong = mix(t.bg, t.fg1, t.dark ? .2 : .22);     // all-day lane edge (C8), field outline on paper
    t.segRing = mix(t.surface, t.fg1, t.dark ? .38 : .5);   // selected segment edge: 3:1 against the track (WCAG 1.4.11)
  }

  // Event recipe (brief §5 + direction C). One decoration per state.
  //   paper: pale tint 0.18, hue-dark title, 3 px bar.   dark: tint 0.22, light title, no bar.
  function ev(hex, th) {
    const t = typeof th === 'string' ? THEMES[th] : th, bg = t.bg;
    if (t.dark) {
      const fill = mix(bg, hex, .22), tc = t.fg1;
      return {
        cc: hex, bar: 'transparent', fill, tc, mc: mix(tc, fill, .18),
        fillh: mix(fill, t.fg1, .06),                 // hover: lighter only
        fills: mix(bg, hex, .32), tcs: tc,            // selected: one step stronger + ring
        get mcs() { return mix(tc, this.fills, .06); },
        fillp: mix(bg, fill, .45), tcp: t.fg2, mcp: t.fg3,   // past: fill 55 % toward bg, text at full opacity
        decfill: mix(bg, fill, .5), dectc: t.fg2,     // declined: half fill, struck fg2
        line: mix(hex, t.fg1, .15),                   // needs-reply outline, maybe dots
        dot: hex,
      };
    }
    const fill = mix(bg, hex, .18), tc = mix(hex, t.inkTitle, .80);
    return {
      cc: hex, bar: mix(hex, t.inkTitle, .12), fill, tc, mc: mix(tc, fill, .14),
      fillh: mix(fill, '#FFFFFF', .45),
      fills: mix(bg, hex, .20), tcs: mix(hex, t.inkTitle, .88),
      get mcs() { return mix(this.tcs, this.fills, .12); },
      fillp: mix(bg, fill, .45), tcp: t.fg2, mcp: t.fg3,
      decfill: mix(bg, fill, .5), dectc: t.fg2,
      line: mix(hex, t.inkTitle, .38),
      dot: mix(hex, t.inkTitle, .12),
    };
  }

  // type scale: 5 sizes, weights 400 / 500 (+600 for the one dominant title per area)
  const TYPE = {
    title: { size: 22, line: 28, weight: 600, family: 'serif' }, // view title, editor title (Newsreader)
    heading: { size: 15, line: 20, weight: 600 },                // "Now" title, settings and dialog headings
    body: { size: 13, line: 18, weight: 400 },                   // rows, fields, menus (500 when selected)
    event: { size: 12, line: 15, weight: 500 },                  // event titles
    small: { size: 11, line: 14, weight: 400 },                  // times, labels, hints, mini month, hour labels
  };
  const SPACE = [4, 8, 12, 16, 24, 32];
  const RADIUS = { sm: 6, md: 10, lg: 14 };
  return { THEMES, ev, mix, TYPE, SPACE, RADIUS };
})();
if (typeof module !== 'undefined') module.exports = TOK;
