// Horion v10 · the Designer (rounds 2026-11-20 b and c). One control per style dimension; a design is the list of chosen option indexes,
// kept in the URL hash as one base-36 character per control (look=D&d=…). Old links (round b: 24 digits in the old control order) still work:
// DESIGNER.decode maps them (every option kept its index; new options were added at the end).
// DESIGNER.look(code) builds a look with the interface of THEME.look(id) (vars, ev, evVars, calDot, check, gap, H) plus adVars (all-day chips),
// cls (desk classes for designer.css), o (the options) and pal (the event palette).
// Readability by construction: every text colour is derived with fit() against the fill it sits on. Fills under dark text keep luminance
// ≥ .69 (Paper), fills under light text ≤ .045 (Dark), and solid fills are darkened (OKLCH lightness only) until the hardest light title and
// time pass, so a passing text colour always exists. The event palettes only remap the calendar hue that goes into this recipe.
// The only impossible pairing is a White title on a light fill in Paper; the title then falls back to Auto and the rail strikes it through.
// contrast.mjs checks every combination of the colour controls (see the groups there) for both modes and every calendar colour × palette.
'use strict';
const DESIGNER = (() => {
  const T = typeof THEME !== 'undefined' ? THEME : require('./tokens.js');
  const { mx, css, INTER, relL, wcag, F, ok, fit, tintUp, tintDn, oklch, fromOklch } = T.util;
  const W = '#FFFFFF';

  // ---------------------------------------------------------------- controls
  // s: section · k: key · l: label · h: one-line hint · c: changes a colour (contrast.mjs crosses it) · w: widget
  // (swatch = colour swatches, preview = a tiny mock drawn with the real tokens, seg = segmented, step = numeric steps) · o: options
  const SECTIONS = [['theme', 'Theme'], ['events', 'Events'], ['text', 'Text'], ['layout', 'Layout'], ['grid', 'Grid & time'], ['states', 'States']];
  const CONTROLS = [
    { s: 'theme', k: 'canvas', l: 'Canvas', h: 'Background, sidebars and text greys (a Dark + Paper pair)', c: 1, w: 'swatch',
      o: ['Neutral', 'Warm', 'Cool', 'Graphite', 'OLED black', 'Soft black', 'Apple grey', 'Slate', 'Card canvas', 'Stone', 'Mocha', 'Sage', 'Deep navy', 'Plum grey', 'High contrast', 'Nord'] },
    { s: 'theme', k: 'palette', l: 'Event colours', h: 'Remaps every calendar colour (text is refitted)', c: 1, w: 'swatch',
      o: ['Default', 'Pastel', 'Vivid', 'Earthy', 'Muted', 'Jewel', 'Mono'] },
    { s: 'theme', k: 'accent', l: 'Accent', h: 'Today marker, focus ring', c: 1, w: 'swatch',
      o: ['Ink', 'Blue', 'Red', 'Green', 'Violet', 'Indigo', 'Pink', 'Orange', 'Amber', 'Teal', 'Graphite', 'Cyan'] },
    { s: 'events', k: 'fill', l: 'Event fill', h: 'How a block carries its calendar colour', c: 1, w: 'preview',
      o: ['Outline', 'Faint tint', 'Soft tint', 'Medium tint', 'Strong tint', 'Muted solid', 'Solid', 'Raised card', 'Glass', 'Inked', 'Tint fade', 'Deep solid'] },
    { s: 'events', k: 'bar', l: 'Left bar', h: 'The colour mark at the left edge', w: 'preview', o: ['None', '2 px', '3 px', '4 px', 'Inset rounded', 'Dot'] },
    { s: 'events', k: 'edge', l: 'Edge', h: 'Outline of a block (overlaps always keep a canvas ring)', w: 'preview', o: ['None', 'Hue line', 'Canvas ring', 'Soft shadow'] },
    { s: 'events', k: 'radius', l: 'Corner radius', h: 'px', w: 'step', o: ['0', '2', '4', '6', '8', '10'] },
    { s: 'text', k: 'title', l: 'Title colour', h: 'Colour of the event title', c: 1, w: 'preview', o: ['Auto', 'Neutral', 'Hue tint', 'Strong hue', 'White', 'Soft neutral'] },
    { s: 'text', k: 'tcol', l: 'Time colour', h: 'Colour of the time line', c: 1, w: 'preview', o: ['Muted', 'Hue', 'As title', 'Grey', 'Faint'] },
    { s: 'text', k: 'weight', l: 'Title weight', h: 'Font weight of the title', w: 'step', o: ['400', '450', '500', '560', '600', '700'] },
    { s: 'text', k: 'size', l: 'Event text', h: 'Title size in px', w: 'step', o: ['11', '12', '13'] },
    { s: 'text', k: 'font', l: 'Font', h: 'Typeface of the whole app (bundled, OFL)', w: 'seg', o: ['Inter', 'System', 'Geist', 'Instrument Sans'] },
    { s: 'layout', k: 'time', l: 'Time', h: 'Where the time goes inside a block', w: 'seg', o: ['Start–end below', 'Start below', 'Inline after title', 'Hide on short'] },
    { s: 'layout', k: 'extras', l: 'Extras', h: 'Location line, repeat and guest icons', w: 'seg', o: ['None', 'Location', 'Icons', 'Location + icons'] },
    { s: 'layout', k: 'gap', l: 'Gap', h: 'px between blocks', w: 'step', o: ['0', '1', '2', '3', '4'] },
    { s: 'layout', k: 'density', l: 'Hour height', h: 'px per hour', w: 'step', o: ['40', '44', '48', '52', '56', '64'] },
    { s: 'layout', k: 'head', l: 'Day header', h: 'Weekday and date above each column', w: 'preview', o: ['Inline · Wed 4', 'Stacked · WED / 4'] },
    { s: 'grid', k: 'grid', l: 'Grid lines', h: 'Hour line strength (always visible) and half hours', c: 1, w: 'preview',
      o: ['Hour, quiet', 'Hour', 'Hour + half, quiet', 'Hour + half', 'Strong', 'Hairline', 'Hour + dashed half', 'Strong hour, faint half'] },
    { s: 'grid', k: 'div', l: 'Day dividers', h: 'Vertical lines between days', w: 'seg', o: ['On', 'Off'] },
    { s: 'grid', k: 'today', l: 'Today marker', h: 'How today\'s date is marked', c: 1, w: 'preview',
      o: ['Filled circle', 'Red pill', 'Red circle', 'Outline', 'Bold only', 'Accent pill', 'Underline', 'Red dot'] },
    { s: 'grid', k: 'now', l: 'Now line', h: 'Across the week or today only; time as pill or text', w: 'seg', o: ['Week · pill', 'Today · pill', 'Week · text', 'Today · text'] },
    { s: 'states', k: 'past', l: 'Past events', h: 'How finished events step back', c: 1, w: 'preview', o: ['Light fade', 'Medium fade', 'Strong fade', 'Text only', 'Grey out'] },
    { s: 'states', k: 'maybe', l: 'Tentative', h: 'Events you answered "maybe"', w: 'preview', o: ['Hatch', 'Dashed outline', 'Striped bar', 'Faded'] },
    { s: 'states', k: 'decl', l: 'Declined', h: 'Events you declined', w: 'seg', o: ['Strike + fade', 'Strike only'] },
    { s: 'states', k: 'allday', l: 'All-day chips', h: 'Chips in the all-day lane', c: 1, w: 'preview', o: ['As events', 'Solid', 'Dot + text', 'Outline', 'Soft tint', 'Bar + text'] },
    // ---------------- Advanced (round c: "tweak everything"); def = the option that reproduces the default look
    { s: 'theme', a: 1, k: 'sideBg', l: 'Sidebar shade', h: 'Left sidebar against the canvas', c: 1, w: 'swatch', o: ['As canvas pair', 'Same as canvas', 'Darker', 'Lighter'] },
    { s: 'theme', a: 1, k: 'rightBg', l: 'Right column', h: 'Background of the right column', c: 1, w: 'swatch', o: ['As sidebar', 'Same as canvas', 'Darker', 'Lighter'] },
    { s: 'theme', a: 1, k: 'headBg', l: 'Header', h: 'Background behind the month title and view switch', c: 1, w: 'swatch', o: ['Canvas', 'Sidebar shade', 'Raised'] },
    { s: 'theme', a: 1, k: 'hoverK', l: 'Hover & selected', h: 'Strength of row hover and selection', c: 1, w: 'seg', o: ['Subtle', 'Normal', 'Strong'], def: 1 },
    { s: 'text', a: 1, k: 'fsTitle', l: 'Month title', h: 'px', w: 'step', o: ['15', '16', '18', '20', '22', '24'], def: 2 },
    { s: 'text', a: 1, k: 'fsDay', l: 'Day header', h: 'Date size in px (weekday 1 px smaller)', w: 'step', o: ['11', '12', '13', '14'], def: 1 },
    { s: 'text', a: 1, k: 'fsHour', l: 'Hour labels', h: 'px', w: 'step', o: ['10', '10.5', '11', '12'], def: 2 },
    { s: 'text', a: 1, k: 'hourc', l: 'Hour label colour', h: 'From the second grey to the third', c: 1, w: 'preview', o: ['Strong', 'Medium', 'Quiet'] },
    { s: 'text', a: 1, k: 'fsTime', l: 'Event time', h: 'px (Auto follows the title size)', w: 'step', o: ['Auto', '10', '10.5', '11', '11.5', '12'] },
    { s: 'text', a: 1, k: 'fsChip', l: 'All-day chips', h: 'px (Auto = event text)', w: 'step', o: ['Auto', '11', '12', '13'] },
    { s: 'text', a: 1, k: 'lh', l: 'Event line height', h: 'Title and time lines', w: 'seg', o: ['Tight', 'Normal', 'Relaxed'], def: 1 },
    { s: 'text', a: 1, k: 'track', l: 'Letter spacing', h: 'Event and chip text', w: 'seg', o: ['Tight', 'Normal', 'Loose'], def: 1 },
    { s: 'text', a: 1, k: 'fsSide', l: 'Sidebar rows', h: 'Calendar names, px', w: 'step', o: ['12', '13', '14'], def: 1 },
    { s: 'text', a: 1, k: 'fsGroup', l: 'Sidebar headers', h: 'Group names, px', w: 'step', o: ['10.5', '11', '12'], def: 1 },
    { s: 'text', a: 1, k: 'fsMini', l: 'Mini month text', h: 'px', w: 'step', o: ['10', '11', '12'], def: 1 },
    { s: 'text', a: 1, k: 'fsRight', l: 'Right column text', h: 'Now / Up next / Later, px', w: 'step', o: ['12', '13', '14'], def: 1 },
    { s: 'text', a: 1, k: 'fsPanel', l: 'Editor text', h: 'Event editor in the right column, px', w: 'step', o: ['12', '13', '14'], def: 1 },
    { s: 'layout', a: 1, k: 'sideW', l: 'Sidebar width', h: 'px', w: 'step', o: ['208', '220', '236', '260', '280'], def: 2 },
    { s: 'layout', a: 1, k: 'rightW', l: 'Right column width', h: 'px (hide it with ⌥⌘I or the header button)', w: 'step', o: ['280', '300', '320', '340', '360'], def: 2 },
    { s: 'layout', a: 1, k: 'hdrH', l: 'Header height', h: 'px', w: 'step', o: ['40', '44', '48', '52', '56'], def: 2 },
    { s: 'layout', a: 1, k: 'dhH', l: 'Day header height', h: 'px (inline header)', w: 'step', o: ['28', '32', '36', '40'], def: 1 },
    { s: 'layout', a: 1, k: 'adRow', l: 'All-day chip height', h: 'px', w: 'step', o: ['17', '19', '21', '23'], def: 1 },
    { s: 'layout', a: 1, k: 'adMax', l: 'All-day rows shown', h: 'before "+N more"', w: 'step', o: ['1', '2', '3', '4'], def: 1 },
    { s: 'layout', a: 1, k: 'evPad', l: 'Event padding', h: 'Inside a block', w: 'seg', o: ['Tight', 'Normal', 'Roomy'], def: 1 },
    { s: 'layout', a: 1, k: 'mini', l: 'Mini month', h: 'Size, or off', w: 'seg', o: ['Normal', 'Compact', 'Large', 'Off'] },
    { s: 'layout', a: 1, k: 'weekno', l: 'Week numbers', h: 'In the mini month', w: 'seg', o: ['As settings', 'On', 'Off'] },
    { s: 'layout', a: 1, k: 'weekend', l: 'Weekend', h: 'Saturday and Sunday columns', w: 'seg', o: ['Normal', 'Tinted', 'Narrower'] },
    { s: 'layout', a: 1, k: 'first', l: 'First hour shown', h: 'Where the grid opens', w: 'step', o: ['Now', '6', '7', '8', '9'] },
    { s: 'layout', a: 1, k: 'gutter', l: 'Hour gutter', h: 'px', w: 'step', o: ['48', '52', '56', '64'], def: 2 },
    { s: 'layout', a: 1, k: 'oneline', l: 'One-line below', h: 'minutes: shorter blocks drop the time line', w: 'step', o: ['30', '45', '60'], def: 1 },
    { s: 'layout', a: 1, k: 'indent', l: 'Overlap indent', h: 'px per cascade step', w: 'step', o: ['6', '9', '12', '16'], def: 2 },
    { s: 'layout', a: 1, k: 'scroll', l: 'Scrollbars', h: 'Grid and lists', w: 'seg', o: ['Hidden', 'Thin', 'Normal'] },
    { s: 'layout', a: 1, k: 'motion', l: 'Motion', h: 'Hover and panel transitions', w: 'seg', o: ['On', 'Off'] },
    { s: 'grid', a: 1, k: 'lHour', l: 'Hour line', h: 'bg → text mix; never below 1.17:1', c: 1, w: 'step', o: ['Auto', '8 %', '11 %', '14 %', '18 %', '22 %'] },
    { s: 'grid', a: 1, k: 'lHalf', l: 'Half-hour line', h: 'Strength, or off', c: 1, w: 'step', o: ['Auto', 'Off', '2.5 %', '4 %', '6 %'] },
    { s: 'grid', a: 1, k: 'halfStyle', l: 'Half-hour style', h: 'Line style', w: 'seg', o: ['Solid', 'Dotted', 'Dashed'] },
    { s: 'grid', a: 1, k: 'lDay', l: 'Day divider strength', h: 'When dividers are on', c: 1, w: 'step', o: ['Auto', '4 %', '7 %', '10 %', '14 %'] },
    { s: 'grid', a: 1, k: 'lAd', l: 'All-day separator', h: 'Line under the all-day lane', c: 1, w: 'step', o: ['8 %', '12 %', '16 %', '22 %'], def: 1 },
    { s: 'grid', a: 1, k: 'lPane', l: 'Pane edges', h: 'Lines between sidebar, grid and right column', c: 1, w: 'step', o: ['5 %', '8.5 %', '12 %', '16 %'], def: 1 },
    { s: 'grid', a: 1, k: 'nowW', l: 'Now line thickness', h: 'px on today', w: 'step', o: ['1', '1.5', '2', '3'], def: 2 },
  ];
  const KI = Object.fromEntries(CONTROLS.map((c, i) => [c.k, i]));
  // round b's order (24 controls, digits); used to read old links
  const LEGACY = ['canvas', 'fill', 'bar', 'title', 'weight', 'size', 'font', 'time', 'tcol', 'extras', 'radius', 'gap', 'edge', 'grid', 'div', 'head', 'today', 'now', 'maybe', 'past', 'decl', 'allday', 'density', 'accent'];
  const isLegacy = s => typeof s === 'string' && s.length === LEGACY.length && /^\d+$/.test(s);
  const decode = code => {
    const s = String(code || '');
    if (isLegacy(s)) { const o = Object.fromEntries(CONTROLS.map(c => [c.k, c.def || 0])); LEGACY.forEach((k, i) => { const v = +s[i]; if (v < CONTROLS[KI[k]].o.length) o[k] = v; }); return o; }
    return Object.fromEntries(CONTROLS.map((c, i) => { const v = s[i] == null ? NaN : parseInt(s[i], 36); return [c.k, Number.isInteger(v) && v < c.o.length ? v : c.def || 0]; }));
  };
  const encode = o => CONTROLS.map(c => (o[c.k] == null ? c.def || 0 : o[c.k]).toString(36)).join('');
  const valid = code => typeof code === 'string' && (isLegacy(code) || (code.length === CONTROLS.length && CONTROLS.every((c, i) => parseInt(code[i], 36) < c.o.length)));
  const normal = code => encode(decode(code)); // legacy → current format

  // ---------------------------------------------------------------- presets (built from the controls)
  const P = o => encode(Object.assign(decode('-'), o));
  const BASE = { canvas: 0, palette: 0, accent: 0, fill: 2, bar: 2, edge: 0, radius: 3, title: 2, tcol: 0, weight: 3, size: 1, font: 0, time: 0, extras: 0, gap: 4, density: 1, head: 0, grid: 2, div: 0, today: 0, now: 0, past: 1, maybe: 1, decl: 0, allday: 0 };
  const PRESETS = [
    // L0–L4 select the v9 looks verbatim; `eq` is the nearest control setting, used when a control is changed from that look
    { id: 'L0', l: 'L0 · v8', look: 'L0', eq: P({ ...BASE, canvas: 3, fill: 2, bar: 0, title: 2, weight: 1, radius: 2, gap: 2, grid: 4, maybe: 1 }) },
    { id: 'L1', l: 'L1 · Clean bar', look: 'L1', eq: P(BASE) },
    { id: 'L2', l: 'L2 · Soft solid', look: 'L2', eq: P({ ...BASE, canvas: 2, fill: 3, bar: 0, title: 3, weight: 4, edge: 1 }) },
    { id: 'L3', l: 'L3 · Vivid', look: 'L3', eq: P({ ...BASE, fill: 6, bar: 0, title: 4, weight: 4, radius: 2 }) },
    { id: 'L4', l: 'L4 · Cards', look: 'L4', eq: P({ ...BASE, canvas: 8, fill: 7, bar: 2, title: 1, edge: 3 }) },
    { id: 'P1', l: 'Solid bright', d: P({ ...BASE, canvas: 5, fill: 6, bar: 0, title: 4, weight: 2, extras: 1, radius: 3, gap: 2, edge: 2, grid: 1, head: 1, today: 0, now: 3, maybe: 0, allday: 1, density: 2, accent: 1 }) },
    { id: 'P2', l: 'Muted solid', d: P({ ...BASE, canvas: 0, fill: 5, bar: 0, title: 1, weight: 2, radius: 2, gap: 2, grid: 0, today: 1, now: 0, maybe: 2, past: 2 }) },
    { id: 'P3', l: 'Tinted bar', d: P({ ...BASE, canvas: 6, fill: 3, bar: 2, title: 3, weight: 4, tcol: 1, extras: 3, radius: 2, gap: 2, grid: 1, today: 2, maybe: 0, allday: 2, density: 3 }) },
    { id: 'P4', l: 'Mono hue', d: P({ ...BASE, canvas: 5, fill: 2, bar: 2, title: 3, weight: 2, time: 1, tcol: 1, radius: 2, gap: 2, edge: 1, accent: 1, density: 2 }) },
  ];

  // ---------------------------------------------------------------- canvases (Dark + Paper pairs); the first nine are hand-tuned (round b)
  const CANVAS = [
    { paper: { bg: '#FFFFFF', rail: '#F8F8F7', surface: '#F0F0EF', raised: '#FFFFFF', fg1: '#1D1D1F', fg2: '#45454A', fg3: '#5C5C62', fg4: '#A3A3A8' },
      dark: { bg: '#191919', rail: '#141414', surface: '#222222', raised: '#252525', fg1: '#ECECEC', fg2: '#C9C9C9', fg3: '#A8A8A8', fg4: '#5E5E5E' } },
    { paper: { bg: '#FBF9F5', rail: '#F4F1EA', surface: '#EDE9E0', raised: '#FFFFFF', fg1: '#1F1C18', fg2: '#47423A', fg3: '#5B554C', fg4: '#A29C90' },
      dark: { bg: '#1A1816', rail: '#151311', surface: '#24211E', raised: '#2A2724', fg1: '#EEEBE6', fg2: '#CBC6BE', fg3: '#ABA59B', fg4: '#615C55' } },
    { paper: { bg: '#FCFCFD', rail: '#F4F5F7', surface: '#ECEDF0', raised: '#FFFFFF', fg1: '#1C1D21', fg2: '#44464D', fg3: '#5A5C64', fg4: '#A2A4AB' },
      dark: { bg: '#1C1C1F', rail: '#1A1A1D', surface: '#252529', raised: '#29292D', fg1: '#F0F0F2', fg2: '#C9CAD0', fg3: '#A9AAB2', fg4: '#5F6068' } },
    { paper: { bg: '#F7F4EC', rail: '#F3F0E8', surface: '#ECE7DC', raised: '#FFFDF8', fg1: '#15120E', fg2: '#47423A', fg3: '#5B554C', fg4: '#A29C90' },
      dark: { bg: '#131315', rail: '#0E0E10', surface: '#1C1C20', raised: '#242428', fg1: '#EDEDEF', fg2: '#C8C8CE', fg3: '#A8A8B0', fg4: '#62626A' } },
    { paper: { bg: '#FFFFFF', rail: '#FFFFFF', surface: '#F2F2F2', raised: '#FFFFFF', fg1: '#111111', fg2: '#3E3E3E', fg3: '#565656', fg4: '#A0A0A0' },
      dark: { bg: '#000000', rail: '#000000', surface: '#141414', raised: '#1A1A1A', fg1: '#E2E2E2', fg2: '#C8C8C8', fg3: '#9E9E9E', fg4: '#555555' } },
    { paper: { bg: '#FAFAFA', rail: '#F3F3F3', surface: '#EBEBEB', raised: '#FFFFFF', fg1: '#1A1A1A', fg2: '#424242', fg3: '#585858', fg4: '#A0A0A0' },
      dark: { bg: '#1F1F1F', rail: '#1A1A1A', surface: '#282828', raised: '#2C2C2C', fg1: '#F5F5F5', fg2: '#CACACA', fg3: '#ABABAB', fg4: '#606060' } },
    { paper: { bg: '#FFFFFF', rail: '#F5F5F5', surface: '#EDEDED', raised: '#FFFFFF', fg1: '#1D1D1F', fg2: '#434345', fg3: '#5A5A5D', fg4: '#A1A1A4' },
      dark: { bg: '#1E1E1E', rail: '#242424', surface: '#272727', raised: '#2C2C2C', fg1: '#F7F7F7', fg2: '#CFCFCF', fg3: '#B0B0B0', fg4: '#646464' } },
    { paper: { bg: '#F6F8FA', rail: '#EEF1F5', surface: '#E5E9EE', raised: '#FFFFFF', fg1: '#151A21', fg2: '#3D4651', fg3: '#525C68', fg4: '#9AA3AE' },
      dark: { bg: '#161B22', rail: '#141920', surface: '#1F252E', raised: '#232A33', fg1: '#EBEFF3', fg2: '#C5CDD6', fg3: '#A4AEBA', fg4: '#5A6470' } },
    { paper: { bg: '#EFEFF2', rail: '#FAFAFB', surface: '#E6E6EA', raised: '#FFFFFF', fg1: '#141417', fg2: '#414148', fg3: '#55555D', fg4: '#9E9EA6' },
      dark: { bg: '#161618', rail: '#111113', surface: '#1F1F22', raised: '#26262A', fg1: '#EDEDF0', fg2: '#C8C8CF', fg3: '#A8A8B1', fg4: '#5C5C64' } },
  ];
  // round c: seven more pairs. Their text greys are derived (autoFg) so they pass the canvas floors on every surface.
  const AUTO = [
    { tn: '#8A8070', paper: { bg: '#F6F5F3', rail: '#EFEDEA', surface: '#E7E5E1', raised: '#FFFFFF' }, dark: { bg: '#1C1B1A', rail: '#171615', surface: '#252423', raised: '#2A2928' } }, // Stone
    { tn: '#8A6A50', paper: { bg: '#F8F3EF', rail: '#F5F0EB', surface: '#E9E0D8', raised: '#FFFCFA' }, dark: { bg: '#1E1915', rail: '#19140F', surface: '#28211B', raised: '#2D251F' } }, // Mocha
    { tn: '#6E8A72', paper: { bg: '#F4F6F3', rail: '#ECF0EA', surface: '#E3E8E0', raised: '#FFFFFF' }, dark: { bg: '#171B18', rail: '#131714', surface: '#202621', raised: '#252B26' } }, // Sage
    { tn: '#5A6E96', paper: { bg: '#F5F7FB', rail: '#ECF0F7', surface: '#E2E8F2', raised: '#FFFFFF' }, dark: { bg: '#141A28', rail: '#111622', surface: '#1C2334', raised: '#202839' } }, // Deep navy
    { tn: '#86708A', paper: { bg: '#F8F5F8', rail: '#F1ECF1', surface: '#E8E1E8', raised: '#FFFFFF' }, dark: { bg: '#1C181D', rail: '#171318', surface: '#251F26', raised: '#2A232B' } }, // Plum grey
    { tn: '#000000', paper: { bg: '#FFFFFF', rail: '#FFFFFF', surface: '#EBEBEB', raised: '#FFFFFF' }, dark: { bg: '#0B0B0B', rail: '#0B0B0B', surface: '#161616', raised: '#1B1B1B' }, hc: true }, // High contrast
    { tn: '#5E6B85', paper: { bg: '#ECEFF4', rail: '#F3F5F8', surface: '#DDE2EB', raised: '#F8F9FB' }, dark: { bg: '#242933', rail: '#1F232B', surface: '#292E38', raised: '#2B303B' } }, // Nord
  ];
  const FG = { paper: { c1: [12, 95], s1: [12, 88], c2: [7, 80], s2: [7, 75], c3: [5, 70], s3: [5, 65] }, dark: { c1: [12, 88], s1: [12, 85], c2: [7, 68], s2: [7, 63], c3: [6.5, 48], s3: [5.5, 45] } };
  function autoFg(p, th, tn, hc) {
    const d = th === 'dark', to = d ? W : '#000000', f = FG[th], canv = d ? [p.bg, p.rail] : [p.bg, p.raised, p.rail];
    let fg1 = d ? mx('#E6E6E6', tn, .06) : mx('#202020', tn, .12);
    if (hc) fg1 = d ? '#E4E4E4' : '#000000';
    for (let i = 0; i < 2; i++) {
      const L = x => mx(p.bg, fg1, x), soft = [p.surface, p.raised, L(d ? .05 : .04), mx(p.rail, fg1, d ? .05 : .04), L(d ? .08 : .055)];
      fg1 = fit(fg1, canv, to, f.c1); // soft surfaces are pulled toward the canvas in canvasOf instead (keeps the near-black cap)
      p.fg2 = fit(fit(d ? mx('#B8B8B8', tn, .12) : mx('#4A4A4A', tn, .2), canv, to, f.c2), soft, to, f.s2);
      p.fg3 = fit(fit(d ? mx('#9A9A9A', tn, .12) : mx('#606060', tn, .2), canv, to, f.c3), soft, to, f.s3);
    }
    if (hc) { p.fg2 = d ? '#CFCFCF' : '#1E1E1E'; p.fg3 = d ? '#B5B5B5' : '#303030'; }
    p.fg1 = fg1; p.fg4 = mx(p.bg, fg1, d ? .3 : .38);
    return p;
  }
  AUTO.forEach(a => CANVAS.push({ paper: autoFg({ ...a.paper }, 'paper', a.tn, a.hc), dark: autoFg({ ...a.dark }, 'dark', a.tn, a.hc) }));

  const STATUS = { paper: { focus: '#2F6BDC', live: '#C2362B', ok: '#2F7A4B', warn: '#8A5A00', danger: '#B4382D', onLive: '#FFFFFF', ink: '#121216' },
    dark: { focus: '#6E9BF5', live: '#FF6B5F', ok: '#6CC58A', warn: '#E5B44A', danger: '#FF7B72', ink: '#FFFFFF' } };
  // grid: [hour, half (0 = not drawn), day divider] as bg → fg1 mixes. The hour line is always drawn and raised until it reaches 1.17:1.
  const GRID = [[.1, 0, .06], [.14, 0, .08], [.1, .03, .065], [.13, .045, .08], [.18, .06, .11], [.08, 0, .05], [.12, .05, .07], [.18, .03, .08]];
  const ACCENT = [null, '#3B6FE0', '#D64545', '#2F8F5B', '#7C5CD6', '#4F55D9', '#D94C8C', '#E06A2C', '#D49A1A', '#1F9A94', '#6B7280', '#1A9FC9'];
  const FILLK = { 1: [.08, .12], 2: [.15, .2], 3: [.22, .28], 4: [.3, .36], 8: [.12, .16], 9: [.04, .07], 10: [.26, .32] }; // tint strength [paper, dark]
  const PASTK = [.45, .62, .78];

  // ---------------------------------------------------------------- event palettes: remap a calendar colour (OKLCH)
  const PALETTES = [
    null,
    ([l, c, h]) => [Math.max(l, .8), c * .55, h],                                   // Pastel
    ([l, c, h]) => [Math.min(.7, Math.max(.55, l)), c * 1.35, h],                   // Vivid
    ([l, c, h]) => { const d = ((55 * Math.PI / 180 - h + 3 * Math.PI) % (2 * Math.PI)) - Math.PI; return [l * .92, c * .72, h + d * .35]; }, // Earthy
    ([l, c, h]) => [l, c * .45, h],                                                 // Muted
    ([l, c, h]) => [.52, c * 1.2, h],                                               // Jewel
    ([l, c, h]) => [l, Math.min(c, .03), h],                                        // Mono
  ];
  const palCache = {};
  const palHex = (hex, p) => !p ? hex : palCache[p + hex] || (palCache[p + hex] = fromOklch(PALETTES[p](oklch(hex))));

  // ---------------------------------------------------------------- the canvas tokens for one design and mode
  function canvasOf(o, th) {
    const d = th === 'dark', t = Object.assign({ dark: d }, CANVAS[o.canvas][th], STATUS[th]);
    if (d) t.onLive = t.bg;
    // chrome shades: sidebar, right column, header
    // a shade steps back toward the canvas until the current text still fits on it (Dark: 12.15:1; Paper: Lc 95.5 on the sidebar, 88.5 elsewhere)
    const fits = (x, rail) => d ? wcag(t.fg1, x) >= 12.15 && (relL(x) >= .01 || Math.abs(T.util.apca(t.fg1, x)) <= 95.5) : wcag(t.fg1, x) >= 12.15 && Math.abs(T.util.apca(t.fg1, x)) >= (rail ? 95.5 : 88.5);
    const shade = (k, base, rail) => { if (k === 0) return base; if (k === 1) return t.bg; let q = k === 2 ? (d ? .22 : .035) : (d ? .045 : .6), x;
      do { x = k === 2 ? mx(t.bg, '#000000', q) : mx(t.bg, W, q); q -= d && k === 3 ? .005 : k === 2 && !d ? .005 : .02; } while (q > 0 && !fits(x, rail)); return x; };
    t.rail = shade(o.sideBg, t.rail, true);
    t.rcol = o.rightBg === 0 ? t.rail : shade(o.rightBg, t.rail, false);
    t.hdrbg = o.headBg === 1 ? t.rail : o.headBg === 2 ? (d ? t.raised : W) : t.bg;
    const HK = d ? [[.035, .06], [.05, .08], [.075, .11]] : [[.03, .04], [.04, .055], [.06, .08]], [hk, sk] = HK[o.hoverK];
    // the text greys are checked on every surface of this design, so a shade or a stronger hover can never break a floor
    const f = FG[th], to = d ? W : '#000000';
    {
      const L = x => mx(t.bg, t.fg1, x), canv = d ? [t.bg, t.rail] : [t.bg, t.raised, t.rail];
      t.fg1 = fit(t.fg1, canv, to, f.c1);
      t.hover = L(hk); t.hoverRail = mx(t.rail, t.fg1, d ? .05 : .04); t.hoverR = mx(t.rcol, t.fg1, d ? .05 : .04); t.selected = L(sk);
      // the main text stays put; a soft surface it misses on steps back toward the canvas until it fits (never the other way round,
      // so the cap on near-black canvases holds)
      for (const k of ['rcol', 'hdrbg', 'surface', 'raised', 'hover', 'selected', 'hoverRail', 'hoverR']) {
        if (k === 'hoverR') t.hoverR = mx(t.rcol, t.fg1, d ? .05 : .04);
        let home = k === 'hoverRail' ? t.rail : k === 'hoverR' ? t.rcol : t.bg; if (!ok(t.fg1, home, f.s1)) home = t.bg; let q = 0, x = t[k];
        while (q < 1 && !ok(t.fg1, x, f.s1)) { q += .05; x = mx(t[k], home, q); }
        t[k] = x;
      }
      const soft = [t.surface, t.raised, t.hover, t.hoverRail, t.selected, t.rcol, t.hoverR, t.hdrbg];
      t.fg2 = fit(fit(t.fg2, canv, to, f.c2), soft, to, f.s2); t.fg3 = fit(fit(t.fg3, canv, to, f.c3), soft, to, f.s3);
    }
    // live red is text too ('30 min left'): fitted on every pane it can sit on (the pill text on it only gets stronger)
    t.live = fit(t.live, [t.bg, t.rail, d ? t.surface : t.raised, t.rcol], d ? W : '#000000', d ? [4.5, 45.5] : [4.5, 60.5]);
    linesOf(t, o); accentOf(t, o);
    return t;
  }
  // lines: they depend only on bg, fg1 and the line options (proven per canvas × distinct fg1 × line option)
  function linesOf(t, o) {
    const d = t.dark, L = x => mx(t.bg, t.fg1, x);
    // the grid preset, or the advanced overrides; the hour line is raised until it reaches 1.17:1, the pane edge kept ≤ Lc 15
    const [gh, gm, gd] = GRID[o.grid];
    const hv = [gh, .08, .11, .14, .18, .22][o.lHour], mv = [gm, 0, .025, .04, .06][o.lHalf], dv = [gd, .04, .07, .1, .14][o.lDay];
    let k = hv; while (wcag(L(k), t.bg) < 1.17 && k < .4) k += .01;
    // decor lines (half hour, day divider, pane edge) stay ≤ Lc 15
    const lcap = x => { while (x > .015 && Math.abs(T.util.apca(L(x), t.bg)) > 14.5) x -= .005; return x; };
    t.grid = L(k); t.gridHalf = mv ? L(lcap(mv)) : 'transparent'; t.gridV = o.div ? 'transparent' : L(lcap(dv));
    let ka = [.08, .12, .16, .22][o.lAd]; while (wcag(L(ka), t.bg) < 1.17 && ka < .4) ka += .01;
    t.hairStrong = L(ka);
    t.hair = L(lcap([.05, .085, .12, .16][o.lPane]));
    t.segRing = mx(t.surface, t.fg1, d ? .4 : .5);
    t.hourc = o.hourc === 0 ? t.fg2 : o.hourc === 1 ? mx(t.fg2, t.fg3, .5) : t.fg3;
    t.joinBg = d ? t.raised : '#FFFFFF'; t.joinFg = t.fg1;
    return t;
  }
  function accentOf(t, o) {
    const d = t.dark;
    // accent (filled circle, accent pill, outline, underline, focus): Ink = fg1 on bg; a hue is darkened (Paper, white text) or
    // lightened (Dark, canvas-coloured text) until the text on it reaches the primary-button target
    const a = ACCENT[o.accent];
    if (!a) { t.accent = t.fg1; t.onAccent = t.bg; }
    else if (!d) { t.onAccent = W; const [l0, c, h] = oklch(a); let l = l0, x = a; while (l > .05 && !ok(W, x, [12, 90])) { l -= .004; x = fromOklch([l, c, h]); } t.accent = x; }
    else { t.onAccent = t.bg; let q = 0, x = a; while (q < 1 && !ok(t.bg, x, [12, 85])) { q += .01; x = mx(a, W, q); } t.accent = x; }
    t.accentHue = a || t.fg1;
    if (a) t.focus = fit(a, [t.bg, t.raised], d ? W : t.ink, [3, 0]);
    return t;
  }

  // ---------------------------------------------------------------- the event recipe
  const solidish = f => f === 5 || f === 6 || f === 11;
  const titleAllowed = (fill, title, th) => !(title === 4 && th === 'paper' && !solidish(fill));
  const titleUsed = (fill, title, th) => titleAllowed(fill, title, th) ? title : 0;
  // keep a fill light enough for dark text (Paper) / dark enough for light text (Dark)
  const YP = .69, YD = .045; // Paper: an ink title reaches Lc 75 from luminance ≈ .68; Dark: white reaches its floors below ≈ .06
  const clampL = (c, t) => { let x = c, k = 0; if (!t.dark) { while (relL(x) < YP && k < 1) { k += .04; x = mx(c, W, k); } } else { while (relL(x) > YD && k < 1) { k += .04; x = mx(c, t.bg, k); } } return x; };
  // a text colour for a past / declined fill: dark text on a light fill, light text on a dark one
  const textOn = (bg, hex, floor, ink) => relL(bg) > .25 ? fit(mx('#4A4A4F', hex, .18), bg, ink, floor) : fit(mx('#C8C8CC', hex, .12), bg, W, floor);

  // the fill alone (independent of the title and time options, so past / declined pairs can be proven per fill)
  const fillMemo = new Map();
  function fillsOf(hex, fill0, t, th) {
    const key = th + t.bg + t.raised + t.fg1 + hex + fill0;
    let r = fillMemo.get(key); if (!r) { r = fillsOf0(hex, fill0, t, th); if (fillMemo.size > 200000) fillMemo.clear(); fillMemo.set(key, r); }
    return r;
  }
  function fillsOf0(hex, fill0, t, th) {
    const d = t.dark, f = F[th];
    if (solidish(fill0)) {
      // darken until white text passes as title and time on fill, hover (7 % darker) and selected (14 % darker)
      const [l0, c0, h] = oklch(hex);
      let l = fill0 === 5 ? (d ? .4 : .5) : fill0 === 11 ? Math.min(l0, d ? .42 : .4) : l0, c = fill0 === 5 ? Math.min(c0, d ? .06 : .075) : c0;
      let x = fromOklch([l, c, h]);
      // (white text sets the darkening; a light-hue title or time is then fitted toward white, which always passes here)
      const hard = y => { const dk = mx(y, '#000000', .14), hv = mx(y, '#000000', .07);
        return [y, hv].every(b => ok(W, b, f.title) && ok(mx(W, y, .1), b, f.meta)) && ok(W, dk, f.title) && ok(mx(W, dk, .1), dk, f.selMeta); };
      while (l > .08 && !hard(x)) { l -= .004; x = fromOklch([l, c, h]); }
      return { fill: x, fillH: mx(x, '#000000', .07), fillSel: mx(x, '#000000', .14) };
    }
    if (fill0 === 0) return { fill: t.bg, fillH: d ? tintDn(t.bg, hex, .1, YD) : tintUp(t.bg, hex, .07, YP), fillSel: d ? tintDn(t.bg, hex, .16, YD) : tintUp(t.bg, hex, .12, YP) };
    if (fill0 === 7) return { fill: t.raised, fillH: d ? mx(t.raised, t.fg1, .04) : mx(W, hex, .04), fillSel: d ? tintDn(t.raised, hex, .12, YD) : tintUp(W, hex, .1, YP) };
    const k = FILLK[fill0][d ? 1 : 0], base = fill0 === 8 ? (d ? t.raised : W) : t.bg;
    const cap = (kk, b = base) => d ? tintDn(b, hex, kk, YD) : tintUp(b, hex, kk, YP);
    const r = { fill: cap(k), fillH: cap(k + .06), fillSel: cap(k + .12) };
    if (fill0 === 10) r.fill2 = t.bg; // Tint fade: tint at the left, the canvas at the right
    return r;
  }

  function recipe(hex0, o, t, th) {
    const hex = palHex(hex0, o.palette), d = t.dark, f = F[th], to = d ? W : t.ink, fill0 = o.fill, ti = titleUsed(fill0, o.title, th);
    const { fill, fillH, fillSel, fill2 } = fillsOf(hex, fill0, t, th), on = fill2 ? [fill, fill2, fillH] : [fill, fillH];
    let title, titleSel, meta, metaSel;
    if (solidish(fill0)) {
      const tc = ti === 2 ? mx(W, hex, .12) : ti === 3 ? mx(W, hex, .24) : ti === 5 ? mx(W, '#808080', .12) : W;
      title = fit(tc, on, W, f.title); titleSel = fit(title, fillSel, W, f.title);
      const mc = b => o.tcol === 2 ? title : o.tcol === 1 ? mx(W, hex, .38) : o.tcol === 3 ? mx(W, '#808080', .2) : o.tcol === 4 ? mx(title, b, .24) : mx(title, b, .12);
      meta = o.tcol === 2 ? title : fit(mc(fill), on, W, f.meta);
      metaSel = o.tcol === 2 ? titleSel : fit(mc(fillSel), fillSel, W, f.selMeta);
    } else {
      const want = ti === 0 ? (fill0 === 7 ? 1 : fill0 === 9 ? 3 : 2) : ti === 4 ? 1 : ti;
      const cand = want === 1 ? t.fg1 : want === 5 ? t.fg2 : want === 2 ? mx(t.fg1, hex, d ? .15 : .2) : d ? mx(hex, W, .45) : mx(hex, t.ink, .5);
      title = fit(cand, on, to, f.title); titleSel = fit(title, fillSel, to, f.title);
      const mcand = o.tcol === 2 ? title : o.tcol === 1 ? (d ? mx(hex, W, .3) : mx(hex, t.ink, .32)) : o.tcol === 3 ? t.fg3 : o.tcol === 4 ? mx(title, fill, d ? .48 : .52) : mx(title, fill, d ? .32 : .36);
      meta = o.tcol === 2 ? title : fit(mcand, on, o.tcol === 0 || o.tcol === 4 ? title : to, f.meta);
      metaSel = o.tcol === 2 ? titleSel : fit(mx(meta, fillSel, .05), fillSel, o.tcol === 0 || o.tcol === 4 ? titleSel : to, f.selMeta);
      if (!on.every(b => ok(meta, b, f.meta))) meta = fit(meta, on, to, f.meta);
      if (!ok(metaSel, fillSel, f.selMeta)) metaSel = fit(metaSel, fillSel, to, f.selMeta);
    }
    const p = pastOf(hex, fill0, o.past, t, th, fill);
    const bar = solidish(fill0) ? (d ? mx(hex, W, .25) : mx(fill, t.ink, .35)) : d ? hex : mx(hex, t.ink, .06);
    const edge = fit(d ? hex : mx(hex, t.ink, .1), t.bg, to, [3, 0]);
    const edge2 = solidish(fill0) ? mx(fill, '#000000', .18) : fill0 === 9 ? (d ? mx(hex, W, .1) : mx(hex, t.ink, .12)) : fill0 === 0 ? (d ? mx(t.bg, hex, .6) : mx(t.bg, hex, .55)) : mx(fill, hex, d ? .3 : .35);
    return { cc: hex, mark: hex, fill, fill2: fill2 || fill, fillH, fillSel, title, titleSel, meta, metaSel, ...p,
      bar, barPast: mx(bar, p.fillPast, .5), edge, edge2, fallback: ti !== o.title };
  }
  // past and declined depend on the fill and the past option only (proven per canvas × fill × past × hue)
  function pastOf(hex, fill0, past, t, th, fill) {
    const d = t.dark, f = F[th], ink = t.ink;
    const fillPast = past === 3 ? fill : past === 4 ? clampL(mx(mx(fill, mx(t.bg, t.fg1, .12), .7), t.bg, .35), t) : clampL(mx(fill, t.bg, PASTK[past]), t);
    const titlePast = textOn(fillPast, hex, f.pastTitle, ink);
    const metaPast = fit(mx(titlePast, fillPast, .3), fillPast, titlePast, f.pastMeta);
    const fillDec = clampL(mx(fill, t.bg, .5), t), titleDec = textOn(fillDec, hex, f.decl, ink);
    return { fillPast, titlePast, metaPast, fillDec, titleDec };
  }
  const evVars = c => `--cc:${c.cc};--bar:${c.bar};--barp:${c.barPast};--dot:${c.mark};--fill:${c.fill};--fill2:${c.fill2};--fillh:${c.fillH};--fills:${c.fillSel};--fillp:${c.fillPast};` +
    `--tc:${c.title};--tcs:${c.titleSel};--mc:${c.meta};--mcs:${c.metaSel};--tcp:${c.titlePast};--mcp:${c.metaPast};--decfill:${c.fillDec};--dectc:${c.titleDec};--line:${c.edge};--edge2:${c.edge2}`;
  // all-day chips: As events / Solid / Dot + text / Outline / Soft tint / Bar + text
  const adOpts = o => o.allday === 1 ? { ...o, fill: 6 } : o.allday === 2 ? { ...o, fill: 0, title: 1 } : o.allday === 3 ? { ...o, fill: 0, title: 3 } : o.allday === 4 ? { ...o, fill: 2 } : o.allday === 5 ? { ...o, fill: 0, title: 1 } : o;

  // ---------------------------------------------------------------- the look object
  const FONTS = [INTER, "-apple-system, 'SF Pro Text', system-ui, sans-serif", "'Geist', -apple-system, system-ui, sans-serif", "'Instrument Sans', -apple-system, system-ui, sans-serif"];
  const cache = new Map();
  function look(code) {
    code = valid(code) ? normal(code) : PRESETS[1].eq;
    if (cache.has(code)) return cache.get(code);
    const o = decode(code), TT = { dark: canvasOf(o, 'dark'), paper: canvasOf(o, 'paper') }, rc = {};
    const ev = (hex, th, oo = o, key = '') => rc[key + th + hex] || (rc[key + th + hex] = recipe(hex, oo, TT[th], th));
    const gv = +CONTROLS[KI.gap].o[o.gap], gl = gv > 1 ? 2 : 1, rad = +CONTROLS[KI.radius].o[o.radius];
    const fs = +CONTROLS[KI.size].o[o.size], V = k => +CONTROLS[KI[k]].o[o[k]];
    const fsm = o.fsTime ? V('fsTime') : fs === 13 ? 11.5 : fs === 11 ? 10.5 : 11, lhk = [2, 3, 4.5][o.lh];
    const geo = { sideW: V('sideW'), rightW: V('rightW'), gutW: V('gutter'), adRow: V('adRow'), adMax: V('adMax'), one: V('oneline'), indent: V('indent'),
      weekend: o.weekend, first: o.first ? V('first') : null, mini: o.mini, weekno: o.weekno, dhH: o.head ? 54 : V('dhH') };
    const cls = ['dz', ...CONTROLS.filter(c => !c.c || ['fill', 'today', 'allday', 'grid'].includes(c.k)).map(c => `d-${c.k}-${o[c.k]}`)].join(' ');
    const L = {
      id: 'D', name: 'Designer', darkName: 'Dark', icStroke: 1.5, T: TT, mix: mx, code, o, pal: h => palHex(h, o.palette),
      H: +CONTROLS[KI.density].o[o.density], gap: { l: gl, r: gl + gv, b: gv }, cls, geo,
      vars(th) {
        const t = TT[th], dk = t.dark, s = dk ? 'rgba(0,0,0' : 'rgba(20,20,30';
        const evsh = [o.fill === 0 ? 'inset 0 0 0 1px var(--edge2)' : '', o.fill === 9 ? 'inset 0 0 0 1.5px var(--edge2)' : '', o.fill === 8 ? (dk ? 'inset 0 1px 0 rgba(255,255,255,.07), inset 0 0 0 1px var(--edge2)' : 'inset 0 1px 0 rgba(255,255,255,.9), inset 0 0 0 1px var(--edge2)') : '',
          o.edge === 1 ? 'inset 0 0 0 1px var(--edge2)' : '', o.edge === 2 ? '0 0 0 1px var(--bg)' : '',
          o.edge === 3 ? (dk ? '0 1px 2px rgba(0,0,0,.45), inset 0 0 0 1px rgba(255,255,255,.05)' : `0 0 0 1px ${s},.06), 0 1px 3px ${s},.10)`) : ''].filter(Boolean).join(', ') || '0 0 0 0 transparent';
        return css({
          bg: t.bg, rail: t.rail, surface: t.surface, raised: t.raised, fg1: t.fg1, fg2: t.fg2, fg3: t.fg3, fg4: t.fg4,
          accent: t.accent, 'on-accent': t.onAccent, focus: t.focus, live: t.live, 'on-live': t.onLive, ok: t.ok, warn: t.warn, danger: t.danger,
          hover: t.hover, 'hover-rail': t.hoverRail, 'seg-ring': t.segRing, selected: t.selected, hair: t.hair, grid: t.grid, 'grid-v': t.gridV, 'grid-half': t.gridHalf,
          'hair-strong': t.hairStrong, hourc: t.hourc, macbar: dk ? mx(t.rail, '#FFFFFF', .05) : mx(t.rail, '#000000', .05),
          scrim: dk ? 'rgba(0,0,0,.6)' : 'rgba(20,20,30,.2)',
          'shadow-pop': dk ? '0 0 0 1px rgba(255,255,255,.07), 0 12px 32px rgba(0,0,0,.55)' : `0 0 0 1px ${s},.08), 0 1px 2px ${s},.05), 0 8px 24px ${s},.10)`,
          'shadow-dialog': dk ? '0 0 0 1px rgba(255,255,255,.08), 0 24px 64px rgba(0,0,0,.65)' : `0 0 0 1px ${s},.08), 0 2px 4px ${s},.05), 0 24px 64px ${s},.15)`,
          'shadow-card': dk ? 'inset 0 0 0 1px rgba(255,255,255,.055), 0 1px 2px rgba(0,0,0,.35)' : `0 0 0 1px ${s},.07), 0 1px 2px ${s},.07)`,
          'join-bg': t.joinBg, 'join-fg': t.joinFg, 'join-sh': dk ? 'inset 0 0 0 1px rgba(255,255,255,.09), 0 1px 1px rgba(0,0,0,.3)' : `0 0 0 1px ${s},.12), 0 1px 2px ${s},.08)`,
          fg: t.fg1, ph: t.fg3, bg2: t.surface, pop: t.raised,
          sans: FONTS[o.font], mono: FONTS[o.font], ff: o.font === 0 ? "'cv05' 1, 'cv08' 1" : 'normal', 'tr-s': '.004em', 'tr-b': '-.004em', 'tr-h': '-.01em',
          'r-ev': rad + 'px', 'r-sm': '6px', 'r-md': '8px', 'r-lg': '12px', 'ev-w': CONTROLS[KI.weight].o[o.weight],
          'fs-ev': fs + 'px', 'fs-evm': fsm + 'px', 'lh-ev': (fs + lhk) + 'px', 'lh-evm': (fsm + lhk - 1) + 'px', evsh,
          'tr-ev': ['-.012em', '0em', '.012em'][o.track], 'fs-chip': (o.fsChip ? V('fsChip') : fs) + 'px', 'ev-pt': ['1px', '3px', '5px'][o.evPad], 'ev-px': ['5px', '6px', '8px'][o.evPad],
          'fs-title': V('fsTitle') + 'px', 'fs-day': V('fsDay') + 'px', 'fs-dayw': (V('fsDay') - 1) + 'px', 'fs-hour': V('fsHour') + 'px', 'fs-side': V('fsSide') + 'px',
          'fs-grp': V('fsGroup') + 'px', 'fs-mini': V('fsMini') + 'px', 'fs-right': V('fsRight') + 'px', 'fs-panel': V('fsPanel') + 'px',
          'side-w': geo.sideW + 'px', 'right-w': geo.rightW + 'px', 'gut-w': geo.gutW + 'px', 'hdr-h': V('hdrH') + 'px', 'dh-h': geo.dhH + 'px', 'ad-row': geo.adRow + 'px',
          'now-w': V('nowW') + 'px', 'mm-d': ['24px', '21px', '28px', '24px'][o.mini], rcol: t.rcol, 'hover-r': t.hoverR, hdrbg: t.hdrbg,
          'we-tint': o.weekend === 1 ? mx(t.bg, t.fg1, dk ? .03 : .025) : 'transparent',
        });
      },
      ev, evVars: (hex, th) => evVars(ev(hex, th)),
      adVars: (hex, th) => evVars(o.allday ? ev(hex, th, adOpts(o), 'ad' + o.allday) : ev(hex, th)),
      calDot: hex => palHex(hex, o.palette),
      check(th) {
        const t = TT[th];
        return {
          dark: t.dark, canvas: t.dark ? [['bg', t.bg], ['rail', t.rail]] : [['bg', t.bg], ['raised', t.raised], ['rail', t.rail]],
          soft: [t.dark ? ['raised', t.raised] : ['surface', t.surface], ['surface', t.surface], ['hover', t.hover], ['hover on rail', t.hoverRail], ['selected', t.selected], ['right column', t.rcol], ['hover in right column', t.hoverR], ['header', t.hdrbg]],
          fg1: t.fg1, fg2: t.fg2, fg3: t.fg3, hourc: t.hourc, hourcOn: [['bg', t.bg]], accent: t.accent, onAccent: t.onAccent, focus: t.focus,
          live: t.live, liveText: t.live, onLive: t.onLive, liveOn: [['bg', t.bg], ['rail', t.rail], ['card', t.dark ? t.surface : t.raised]], segRing: t.segRing, track: t.surface,
          lines: [['hour line', t.grid, 'structure'], ...(t.gridHalf !== 'transparent' ? [['half-hour line', t.gridHalf, 'decor']] : []), ...(t.gridV !== 'transparent' ? [['day divider', t.gridV, 'decor']] : []), ['all-day edge', t.hairStrong, 'structure'], ['pane edge', t.hair, 'decor']],
          status: [['ok', t.ok], ['warn', t.warn], ['danger', t.danger]], ev: hex => ev(hex, th),
          ad: o.allday ? hex => ev(hex, th, adOpts(o), 'ad' + o.allday) : null,
          join: { fg: t.joinFg, bg: t.joinBg },
        };
      },
    };
    cache.set(code, L);
    if (cache.size > 3000) cache.delete(cache.keys().next().value);
    return L;
  }

  // the proof hooks for contrast.mjs: the event recipe and the past states for any options, without building a whole look
  const probe = { canvasOf, linesOf, accentOf, recipe, pastOf, fillsOf, palHex, adOpts, PALETTES };
  return { SECTIONS, CONTROLS, KI, PRESETS, LEGACY, decode, encode, valid, normal, look, titleAllowed, solidish, palHex, probe,
    colour: CONTROLS.filter(c => c.c).map(c => c.k) };
})();
if (typeof module !== 'undefined') module.exports = DESIGNER;
