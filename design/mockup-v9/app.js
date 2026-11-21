// Horion v9: state, theme, layout, views. Every colour and font comes from the chosen look (tokens.js, PK(): L0 = v8, L1–L4).
// Editor/search/menus live in panel.js, input in input.js, the picker rail in rail.js.
'use strict';

// ================================================================ icons (from mockup v4)
const P = {
  search: '<circle cx="7" cy="7" r="4.5"/><path d="M10.5 10.5 14 14"/>',
  sideL: '<rect x="2" y="3" width="12" height="10" rx="2"/><path d="M6 3v10"/>',
  sideR: '<rect x="2" y="3" width="12" height="10" rx="2"/><path d="M10 3v10"/>',
  users: '<circle cx="6" cy="5.5" r="2.5"/><path d="M1.5 13.5c.5-2.5 2.3-4 4.5-4s4 1.5 4.5 4"/><path d="M10.5 3.2a2.4 2.4 0 0 1 0 4.6M12 9.8c1.3.5 2.2 1.8 2.5 3.7"/>',
  video: '<rect x="1.5" y="4" width="9" height="8" rx="2"/><path d="m10.5 7 4-2.5v7l-4-2.5"/>',
  pin: '<path d="M8 14.5s-4.5-4.2-4.5-7.7a4.5 4.5 0 0 1 9 0c0 3.5-4.5 7.7-4.5 7.7Z"/><circle cx="8" cy="6.8" r="1.6"/>',
  notes: '<path d="M3 4h10M3 8h10M3 12h6"/>',
  clock: '<circle cx="8" cy="8" r="6"/><path d="M8 4.8V8l2.2 1.4"/>',
  repeat: '<path d="M2.5 7a5 5 0 0 1 9-2.6M13.5 9a5 5 0 0 1-9 2.6"/><path d="M11.8 1.8v2.8H9M4.2 14.2v-2.8H7"/>',
  bell: '<path d="M4 11V7a4 4 0 0 1 8 0v4l1.2 1.5H2.8Z"/><path d="M6.5 14a1.6 1.6 0 0 0 3 0"/>',
  calendar: '<rect x="2" y="3" width="12" height="11" rx="2"/><path d="M2 6.5h12M5.5 1.5v3M10.5 1.5v3"/>',
  q: '<path d="M5.6 5.6a2.4 2.4 0 0 1 4.7.7c0 1.7-2.3 2-2.3 3.4"/><circle cx="8" cy="12.6" r=".5" fill="currentColor"/>',
  reply: '<circle cx="6.5" cy="5.3" r="2.6"/><path d="M1.8 13.6c.5-2.6 2.3-4.1 4.7-4.1 1 0 1.9.2 2.7.7"/><path d="m10.2 12.3 1.6 1.6 3-3.3"/>',
  trash: '<path d="M2.5 4.5h11M6 4.5V3h4v1.5M4 4.5l.7 9h6.6l.7-9"/>',
  x: '<path d="m4 4 8 8M12 4l-8 8"/>',
  down: '<path d="m4.5 6.5 3.5 3.5 3.5-3.5"/>',
  left: '<path d="M10 3.5 5.5 8l4.5 4.5"/>',
  right: '<path d="M6 3.5 10.5 8 6 12.5"/>',
  plus: '<path d="M8 3v10M3 8h10"/>',
  mail: '<rect x="1.8" y="3.5" width="12.4" height="9" rx="1.5"/><path d="m2.3 4.3 5.7 4.5 5.7-4.5"/>',
  more: '<circle cx="3.5" cy="8" r=".9" fill="currentColor"/><circle cx="8" cy="8" r=".9" fill="currentColor"/><circle cx="12.5" cy="8" r=".9" fill="currentColor"/>',
  copy: '<rect x="5" y="5" width="8.5" height="8.5" rx="1.8"/><path d="M11 5V3.8A1.3 1.3 0 0 0 9.7 2.5H3.8a1.3 1.3 0 0 0-1.3 1.3v5.9A1.3 1.3 0 0 0 3.8 11H5"/>',
  check: '<path d="m3.5 8.3 3 3 6-6.6"/>',
  arrow: '<path d="M3 8h10M9.5 4.5 13 8l-3.5 3.5"/>',
  link: '<path d="M7 9a3 3 0 0 0 4.2 0l2-2a3 3 0 0 0-4.2-4.2L8 3.8"/><path d="M9 7a3 3 0 0 0-4.2 0l-2 2A3 3 0 0 0 7 13.2l1-1"/>',
  info: '<circle cx="8" cy="8" r="6"/><path d="M8 7.3v4"/><circle cx="8" cy="5" r=".5" fill="currentColor"/>',
  lock: '<rect x="3" y="7" width="10" height="7" rx="1.5"/><path d="M5 7V5a3 3 0 0 1 6 0v2"/>',
  gear: '<circle cx="8" cy="8" r="2"/><path d="M8 1.5v2M8 12.5v2M1.5 8h2M12.5 8h2M3.4 3.4l1.4 1.4M11.2 11.2l1.4 1.4M3.4 12.6l1.4-1.4M11.2 4.8l1.4-1.4"/>',
  keyboard: '<rect x="1.5" y="4" width="13" height="8.5" rx="1.5"/><path d="M4 6.7h.1M6.5 6.7h.1M9 6.7h.1M11.5 6.7h.1M4.5 9.7h7"/>',
  moon: '<path d="M13 9.5A5.5 5.5 0 0 1 6.5 3a5.5 5.5 0 1 0 6.5 6.5Z"/>',
  sun: '<circle cx="8" cy="8" r="2.8"/><path d="M8 1.5v1.6M8 12.9v1.6M1.5 8h1.6M12.9 8h1.6M3.4 3.4l1.1 1.1M11.5 11.5l1.1 1.1M3.4 12.6l1.1-1.1M11.5 4.5l1.1-1.1"/>',
  menubar: '<rect x="1.5" y="2.5" width="13" height="11" rx="2"/><path d="M1.5 5.5h13"/>',
  person: '<circle cx="8" cy="5.5" r="2.7"/><path d="M3 14c.6-2.8 2.6-4.3 5-4.3s4.4 1.5 5 4.3"/>',
  palette: '<path d="M8 1.8a6.2 6.2 0 0 0 0 12.4c1 0 1.4-.7 1.1-1.5-.4-1 .2-1.9 1.3-1.9h1.4a2.4 2.4 0 0 0 2.4-2.4A6.4 6.4 0 0 0 8 1.8Z"/><circle cx="5" cy="7" r=".8" fill="currentColor"/><circle cx="8" cy="4.8" r=".8" fill="currentColor"/><circle cx="11" cy="7" r=".8" fill="currentColor"/>',
  globe: '<circle cx="8" cy="8" r="6"/><path d="M2 8h12M8 2c1.8 2 2.5 4 2.5 6S9.8 12 8 14c-1.8-2-2.5-4-2.5-6S6.2 4 8 2Z"/>',
  expand: '<path d="m5 6 3-3 3 3M5 10l3 3 3-3"/>',
  open: '<path d="M9 2.5h4.5V7M13.5 2.5 7.5 8.5"/><path d="M12 9.5v3a1 1 0 0 1-1 1H3.5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h3"/>',
  undo: '<path d="M5.5 3 2.5 6l3 3"/><path d="M2.5 6h7a4 4 0 0 1 0 8H7"/>',
  history: '<path d="M2.5 8a5.5 5.5 0 1 0 1.7-4"/><path d="M2 2.5v3h3"/><path d="M8 5v3.2l2 1.3"/>',
  tag: '<path d="M2.5 2.5h5l6 6-5 5-6-6Z"/><circle cx="5.3" cy="5.3" r=".9" fill="currentColor"/>',
  eye: '<path d="M1.5 8S4 3.5 8 3.5 14.5 8 14.5 8 12 12.5 8 12.5 1.5 8 1.5 8Z"/><circle cx="8" cy="8" r="2"/>',
  eyeOff: '<path d="M6.3 3.8A6.6 6.6 0 0 1 8 3.5C12 3.5 14.5 8 14.5 8a11 11 0 0 1-1.8 2.4M10.2 11.9A5.6 5.6 0 0 1 8 12.5C4 12.5 1.5 8 1.5 8a11.5 11.5 0 0 1 2.6-3.1"/><path d="M6.6 6.6a2 2 0 0 0 2.8 2.8M2 2l12 12"/>',
  pencil: '<path d="M10.8 2.7a1.6 1.6 0 0 1 2.3 2.3L5.5 12.6 2.5 13.5l.9-3Z"/>',
  osm: '<circle cx="8" cy="8" r="6"/><path d="M5 5.5 7 7l2-1.5 2 2M5.5 10.5 8 9l2.5 1.5"/>',
  map: '<path d="M1.8 4 5.6 2.5l4.8 1.6 3.8-1.5v9.4l-3.8 1.5-4.8-1.6-3.8 1.5Z"/><path d="M5.6 2.5v9.4M10.4 4.1v9.4"/>',
};
const ic = (n, s = 16, extra = '') => `<svg class="ic" width="${s}" height="${s}" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="${PK().icStroke}" stroke-linecap="round" stroke-linejoin="round" ${extra}>${P[n] || ''}</svg>`;
const meetLogo = (s = 16) => `<svg class="ic" width="${s}" height="${s * .82}" viewBox="0 0 22 18"><path fill="#00832d" d="M12.4 9 14.5 11.4 17.4 13.2 17.9 9 17.4 4.9 14.6 6.5z"/><path fill="#0066da" d="M0 12.8v3.6C0 17.3.7 18 1.6 18h3.6l.7-2.6-.7-2.6-2.5-.7z"/><path fill="#e94235" d="M5.2 0 0 5.2l2.6.7 2.6-.7.8-2.4z"/><path fill="#2684fc" d="M5.2 5.2H0v7.6h5.2z"/><path fill="#00ac47" d="M20.9 2.2 17.4 4.9v8.3l3.5 2.7c.5.4 1.3 0 1.3-.7V2.9c0-.7-.8-1.1-1.3-.7zM12.4 9v3.8H5.2V18h10.6c.9 0 1.6-.7 1.6-1.6v-3.2z"/><path fill="#ffba00" d="M15.8 0H5.2v5.2h7.2V9l5-4.1V1.6C17.4.7 16.7 0 15.8 0z"/></svg>`;
const zoomLogo = (s = 16) => `<svg class="ic" width="${s}" height="${s}" viewBox="0 0 16 16"><rect width="16" height="16" rx="4" fill="#2D8CFF"/><path fill="#fff" d="M3.5 5.5h5.2c.7 0 1.3.6 1.3 1.3v3.7H4.8c-.7 0-1.3-.6-1.3-1.3zM10.5 7.2l2-1.5v4.6l-2-1.5z"/></svg>`;
const teamsLogo = (s = 16) => `<svg class="ic" width="${s}" height="${s}" viewBox="0 0 16 16"><rect width="16" height="16" rx="4" fill="#5B5FC7"/><path fill="#fff" d="M4 5h6v1.4H7.8V12H6.2V6.4H4z"/><circle cx="12" cy="5.6" r="1.4" fill="#fff" opacity=".8"/></svg>`;
const appleMaps = (s = 16) => `<svg class="ic" width="${s}" height="${s}" viewBox="0 0 16 16"><rect width="16" height="16" rx="3.6" fill="#f4f4f1"/><path d="M0 10 16 4.4v5L0 15z" fill="#93d36f"/><path d="M5.2 0h3L4.4 16h-3z" fill="#f6c443"/><path d="M8.6 3.6a2.6 2.6 0 0 1 2.6 2.6c0 1.9-2.6 4.6-2.6 4.6S6 8.1 6 6.2a2.6 2.6 0 0 1 2.6-2.6z" fill="#ff4b3e"/><circle cx="8.6" cy="6.2" r="1" fill="#fff"/></svg>`;
const gMaps = (s = 16) => `<svg class="ic" width="${s}" height="${s}" viewBox="0 0 16 16"><path d="M8 .8A5.2 5.2 0 0 0 2.8 6c0 3.7 5.2 9.2 5.2 9.2s5.2-5.5 5.2-9.2A5.2 5.2 0 0 0 8 .8z" fill="#34a853"/><path d="M4.3 2.3 8 6 3.3 8.4A5 5 0 0 1 2.8 6c0-1.4.6-2.7 1.5-3.7z" fill="#fbbc04"/><path d="M4.3 2.3A5.2 5.2 0 0 1 11.7 2.3L8 6z" fill="#ea4335"/><path d="M11.7 2.3A5.2 5.2 0 0 1 13.2 6c0 1-.3 2-.8 3L8 6z" fill="#4285f4"/><circle cx="8" cy="6" r="1.9" fill="#fff"/></svg>`;
const gLogo = (s = 16) => `<svg class="ic" width="${s}" height="${s}" viewBox="0 0 16 16"><path fill="#4285F4" d="M15.5 8.2c0-.6 0-1.1-.1-1.6H8v3h4.2a3.6 3.6 0 0 1-1.6 2.4v2h2.6c1.5-1.4 2.3-3.4 2.3-5.8z"/><path fill="#34A853" d="M8 16c2.2 0 4-.7 5.3-1.9l-2.6-2c-.7.5-1.6.8-2.7.8-2.1 0-3.9-1.4-4.5-3.3H.8v2.1A8 8 0 0 0 8 16z"/><path fill="#FBBC05" d="M3.5 9.6a4.8 4.8 0 0 1 0-3.1V4.4H.8a8 8 0 0 0 0 7.2z"/><path fill="#EA4335" d="M8 3.2c1.2 0 2.2.4 3.1 1.2l2.3-2.3A8 8 0 0 0 .8 4.4l2.7 2.1C4.1 4.6 5.9 3.2 8 3.2z"/></svg>`;
const osmLogo = (s = 16) => `<svg class="ic" width="${s}" height="${s}" viewBox="0 0 16 16"><rect width="16" height="16" rx="3.6" fill="#7EBC6F"/><path d="M3 5.2 6.2 4l3.6 1.2L13 4v6.8l-3.2 1.2-3.6-1.2L3 12Z" fill="#F4F1E8"/><path d="M6.2 4v6.8M9.8 5.2V12" stroke="#7EBC6F" stroke-width="1"/></svg>`;
// F: the maps apps a location can open in (Settings → General → Default maps app)
const MAPAPPS = { apple: ['Apple Maps', appleMaps], google: ['Google Maps', gMaps], osm: ['OpenStreetMap', osmLogo] };
const CALLNAME = { meet: 'Google Meet', zoom: 'Zoom', teams: 'Teams', webex: 'Webex', link: 'call' };
const callLogo = (c, s = 16) => !c ? ic('video', s) : c.kind === 'zoom' ? zoomLogo(s) : c.kind === 'teams' ? teamsLogo(s) : c.kind === 'meet' ? meetLogo(s) : ic('link', s);
// the app icon (DECISIONS.md: "Now line"), and the installed v1 ring for the before state
function appIcon(id, s = 52) {
  const gid = 'g' + Math.random().toString(36).slice(2, 7);
  const tile = (a, b) => `<defs><linearGradient id="${gid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient></defs><rect x="100" y="100" width="824" height="824" rx="185" fill="url(#${gid})"/><rect x="101.5" y="101.5" width="821" height="821" rx="183.5" fill="none" stroke="#fff" stroke-opacity=".12" stroke-width="3"/>`;
  const body = id === 'ring' ? tile('#1B1926', '#0F0E14') + '<circle cx="512" cy="512" r="232" fill="none" stroke="#9b7bf8" stroke-width="52"/><circle cx="667" cy="340" r="46" fill="#FF453A"/>'
    : tile('#23232b', '#0e0e11') + [0, 1, 2, 3, 4, 5].map(i => `<path d="M${218 + i * 118} 100V924" stroke="#fff" stroke-opacity=".05" stroke-width="4"/>`).join('') +
      '<rect x="230" y="250" width="200" height="250" rx="34" fill="#5B8DEF" fill-opacity=".9"/><rect x="474" y="360" width="200" height="330" rx="34" fill="#5FB97E" fill-opacity=".9"/><rect x="474" y="360" width="200" height="330" rx="34" fill="none" stroke="#141418" stroke-width="16"/><rect x="718" y="220" width="120" height="170" rx="30" fill="#F2884B" fill-opacity=".85"/><path d="M180 560H850" stroke="#FF453A" stroke-width="30" stroke-linecap="round"/><circle cx="196" cy="560" r="42" fill="#FF453A"/>';
  return `<svg width="${s}" height="${s}" viewBox="100 100 824 824">${body}</svg>`;
}
const menuGlyph = (s = 15) => `<svg class="ic" width="${s}" height="${s}" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"><rect x="2" y="2.5" width="12" height="11" rx="2.5"/><path d="M3.5 9h9"/><circle cx="4" cy="9" r="1.2" fill="currentColor"/></svg>`;

// ================================================================ colour (tokens.js: the chosen look's tokens and event recipe, Dark and Paper)
const hex2 = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const mix = (a, b, t) => { const x = hex2(a), y = hex2(b); return '#' + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, '0')).join(''); };
const isLight = () => { const ap = (A && A.settings.appearance) || V.appear; return ap === 'auto' ? matchMedia('(prefers-color-scheme: light)').matches : ap === 'paper'; };
const PK = () => THEME.look(V.look); // v9: the Look switch in the rail (hash key look)
const theme = () => isLight() ? 'paper' : 'dark';
const pal = () => ({ dark: !isLight() });
function themeVars() { return PK().vars(theme()); }
function evVars(hex, task = false) { return PK().evVars(hex, theme(), task); }
const evv = e => evVars(colorOf(e), !!calOf(e).task);
const deskAttrs = () => `data-pack="${PK().id}"`;

// ================================================================ state
let A;
let H = THEME.H; // hour height: 44 px (v8 density pass; v7 48)
const clone = x => JSON.parse(JSON.stringify(x));
function fresh() {
  return {
    events: seedEvents(), cals: clone(CALS0), hidden: [],
    view: 'week', anchor: TODAY, mmOff: 0,
    sel: null, base: {}, pop: null, modal: null, settingsTab: 'general', toast: null, undo: null,
    left: true, right: true, mb: false, qadd: false, adOpen: false, gridScroll: 15.7 * H, dayFocus: null,
    q: { search: '', cmd: '', guest: '', link: '', qadd: '' }, cmdHi: 0,
    search: { phase: 'idle', from: TODAY - 92, to: TODAY + 275, shown: 40, shownE: 3, jump: true, warm: false, tab: 'up' },
    settings: { weekNo: true, declined: true, appearance: null, weekStart: 'Mon', mbDays: '2', mbRows: 8, maps: 'ask' },
    mbHidden: [], grpClosed: [], mapsRemember: true, locEdit: false, obCals: {}, confOpen: false, showBoiler: false, savest: 'saved', guestHint: false, nextId: 1, focusKey: null,
  };
}
const get = id => A.events.find(e => e.id === id);
const selEv = () => (A.sel && get(A.sel)) || null;
const calOf = e => A.cals[e.cal] || { name: 'Calendar', hex: '#999', g: 'google' };
const colorOf = e => e.color || calOf(e).hex;
const person = id => PEOPLE[id] || { name: '', email: id };
const nameOf = id => person(id).name || person(id).email;
const others = e => e.guests.filter(g => g.id !== 'me');
const myResp = e => { if (e.organizer) return null; const me = e.guests.find(g => g.id === 'me'); return me ? me.resp : null; };
const durOf = e => e.allDay ? (e.ed - e.d + 1) * 1440 : (e.ed - e.d) * 1440 + e.e - e.s;
const isShort = e => !e.allDay && durOf(e) <= 15;
const google = () => V.google === '1';
const isGoogleCal = e => calOf(e).g === 'google';
const visible = e => !A.hidden.includes(e.cal) && (A.settings.declined || myResp(e) !== 'no');
const endDay = e => (!e.allDay && e.ed > e.d && e.e === 0) ? e.ed - 1 : e.ed;
// C2: which events go to the top lane
function inLane(e) {
  if (e.allDay) return true;
  const spans = endDay(e) > e.d, len = durOf(e);
  return spans && len >= 720; // decided: crosses midnight and lasts 12 h or more
}
const isPast = e => e.allDay ? e.ed < TODAY : (e.ed < TODAY || (e.ed === TODAY && (isShort(e) ? e.s : e.e) <= NOW));
const isNow = e => !e.allDay && !isShort(e) && (e.d < TODAY || (e.d === TODAY && e.s <= NOW)) && (e.ed > TODAY || (e.ed === TODAY && e.e > NOW));
const weekStart = d => d - dow(d);
const esc = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
const kb = (...k) => `<span class="kbdc">${k.map(x => `<i class="kbd">${x}</i>`).join('')}</span>`;
const isOpen = k => !!A.pop && A.pop.k === k;
const hl = (text, q) => { if (!q) return esc(text); const words = q.toLowerCase().split(/\s+/).filter(Boolean); let out = esc(text); words.forEach(w => { const i = out.toLowerCase().indexOf(esc(w)); if (i >= 0 && !out.slice(0, i).includes('<mark')) out = out.slice(0, i) + '<mark>' + out.slice(i, i + esc(w).length) + '</mark>' + out.slice(i + esc(w).length); }); return out; };
const avc = id => AVC[[...id].reduce((a, c) => a + c.charCodeAt(0), 0) % AVC.length];
const initials = id => { const p = person(id); return (p.name || p.email).split(/[\s.@+]/).filter(Boolean).slice(0, p.name ? 2 : 1).map(w => w[0].toUpperCase()).join(''); };
function toast(t, s, opts = {}) {
  A.toast = { t, s, undo: !!opts.undo, icon: opts.icon || 'info', logo: opts.logo || null, id: Math.random() };
  const id = A.toast.id;
  setTimeout(() => { if (A.toast && A.toast.id === id) { A.toast = null; render(); } }, opts.ms || 6000);
}
function snapshot() { A.undo = clone(A.events); }

// ================================================================ geometry
const centerW = () => 1440 - (A.left ? 236 : 0) - (A.right ? 320 : 0);
const DAYTL = 430; // Day view, timeline + focus panel: width of the timeline
function gridCols() {
  if (A.view === 'day') {
    return { days: [A.anchor], colW: DAYTL - 56 };
  }
  const ws = weekStart(A.anchor);
  return { days: [0, 1, 2, 3, 4, 5, 6].map(i => ws + i), colW: (centerW() - 56) / 7 };
}

// ================================================================ layout of one day column
function segsFor(d) {
  return A.events.filter(e => !e.allDay && e.d <= d && d <= endDay(e) && visible(e) && !inLane(e)).map(e => {
    const s = e.d === d ? e.s : 0, en0 = e.ed === d ? e.e : 1440, short = isShort(e);
    return { e, s, en: short ? s + 22 : Math.max(en0, s + 15), short, ct: e.d < d, cb: endDay(e) > d };
  }).sort((a, b) => a.s - b.s || (b.en - b.s) - (a.en - a.s));
}
// Overlaps: cascade (decided 2026-11-05; the cols / lanes variants are gone). Nothing is ever folded into "+N".
//   Google-like. Each event indents one step (<= 12 px) from the deepest event still running at its start, near full width,
//   the later one on top. An event that starts within one title line (22 min) of one below moves to the right half and
//   that one ends at its edge, so no title is covered.
// Tasks (calendar "Tasks", 15 min or less) never take a place in the cascade: they are markers on their time (taskMarks).
// Hover only lightens a block; a click selects it and brings it to the front (.sel z 40).
const isTaskItem = e => !!calOf(e).task && !e.allDay && durOf(e) <= 15;
const MK_H = 14, TITLE_MIN = 22; // marker height (px); minutes one title line covers at 44 px per hour
function clustersOf(items) {
  const out = []; let cur = [], end = -1;
  items.forEach(it => { if (it.s >= end && cur.length) { out.push(cur); cur = []; } if (!cur.length) end = -1; cur.push(it); end = Math.max(end, it.en); });
  if (cur.length) out.push(cur);
  return out;
}
function cascade(cluster, colW) {
  cluster.forEach((it, i) => {
    const under = cluster.slice(0, i).filter(o => o.en > it.s);
    it.lvl = under.length ? 1 + Math.max(...under.map(o => o.lvl)) : 0;
    it.near = under.filter(o => it.s - o.s < TITLE_MIN);
  });
  const maxL = Math.max(...cluster.map(it => it.lvl)), step = maxL ? Math.min(12, colW * .36 / maxL) : 0;
  cluster.forEach((it, i) => { it.left = it.lvl * step / colW; it.width = 1 - it.left; it.z = 1 + i; it.stk = i > 0; });
  // a block covered by a later one within 40 min keeps one line (title, time if it fits) so nothing peeks out half-hidden
  cluster.forEach((it, i) => { const c = cluster.slice(i + 1).find(o => o.s < it.en); if (c && c.s - it.s < 40) it.cut = true; });
  cluster.forEach(it => {
    if (!it.near.length) return;
    const x = Math.max(it.left, ...it.near.map(o => o.left + (1 - o.left) / 2));
    it.left = x; it.width = 1 - x;
    it.near.forEach(o => { o.width = Math.min(o.width, x - o.left); });
  });
}
function taskMarks(tasks, blocks, colW) {
  // stacked downwards so two tasks close in time never sit on each other
  const out = [], mkMin = MK_H / H * 60; let low = -1;
  tasks.forEach(it => {
    const s = Math.max(it.s, low), en = s + mkMin; low = en + 60 / H;
    const hit = blocks.filter(b => b.s < en && b.en > s), m = { e: it.e, s, past: isPast(it.e) };
    const edge = hit.length ? Math.max(...hit.map(b => b.left + b.width - (b.pr || 0) / colW)) : 0;
    if ((1 - edge) * colW >= 58) { m.x = edge; m.label = true; }
    else { m.x = 1 - 18 / colW; m.icon = true; hit.forEach(b => { if (b.left + b.width > 1 - 18 / colW) b.pr = Math.max(b.pr || 0, 17); }); }
    out.push(m);
  });
  return out;
}
function layoutDay(items, colW) {
  const tasks = items.filter(it => isTaskItem(it.e));
  const blocks = items.filter(it => !tasks.includes(it));
  clustersOf(blocks).forEach(c => cascade(c, colW));
  const marks = taskMarks(tasks, blocks, colW);
  const out = blocks;
  const g = PK().gap;
  out.forEach(it => { it.px = it.px || 0; it.pr = it.pr || 0; it.squeezed = it.width * colW - g.r - it.px - it.pr < 66; });
  out.marks = marks;
  return out;
}
function taskMark(m, colW) {
  const e = m.e, L = `calc(${m.x * 100}% + ${m.icon ? 0 : 2}px)`;
  const W = m.icon ? '16px' : `calc(${(1 - m.x) * 100}% - 5px)`;
  const cls = ['tmk', m.icon ? 'icon' : '', m.past ? 'past' : '', A.sel === e.id ? 'sel' : ''].filter(Boolean).join(' ');
  const tip = `Task · ${e.t || '(No title)'} · ${fmtDay(e.d)} ${fmt(e.s)}`;
  return `<button class="${cls}" data-a="select" data-id="${e.id}" data-drag="${e.id}" title="${esc(tip)}" style="top:${m.s / 60 * H + 1}px;height:${MK_H}px;left:${L};width:${W};${evv(e)}"><i class="cb"></i>${m.label ? `<span class="tl">${esc(e.t)}</span>` : ''}</button>`;
}

// ================================================================ render pieces
function evBlock(it, colW, d) {
  // v9: the gaps come from the look (L0 = v8: 2 px left, 3 px right, 2 px between stacked blocks)
  const g = PK().gap, e = it.e, top = it.s / 60 * H, h = Math.max((it.en - it.s) / 60 * H - g.b, 16);
  const bw = it.width * colW - g.r - it.px - it.pr;
  const one = (it.en - it.s) < 45 || h < 26 || !!it.cut, narrow = bw < 46, thin = bw < 30;
  const endM = it.cb ? null : e.e;
  const time = it.ct ? `→ ${fmt(e.e)}` : (one || bw < 84 || isShort(e)) ? fmt(e.s) : `${fmt(e.s)}–${fmt(endM == null ? e.e : endM)}`;
  const st = myResp(e) && myResp(e) !== 'yes' ? `st-${myResp(e)}` : '';
  const cls = ['ev', one ? 'one' : '', one && bw < 120 ? 'notime' : '', !one && h < 50 ? 't1' : '', narrow ? 'narrow' : '', thin ? 'thin' : '', isPast(e) ? 'past' : '', calOf(e).task ? 'task' : '', st,
    it.stk ? 'stk' : '', it.cut ? 'cut' : '', A.sel === e.id ? 'sel' : '', e.draft ? 'draft' : '', it.squeezed ? 'squeezed' : '', it.ct ? 'cont-top' : '', it.cb ? 'cont-bot' : ''].filter(Boolean).join(' ');
  const L = `calc(${it.left * 100}% + ${g.l + it.px}px)`, W = `calc(${it.width * 100}% - ${g.r + it.px + it.pr}px)`;
  const tip = `${e.t || 'New event'} · ${e.allDay ? 'all day' : `${fmtDay(e.d)} ${fmt(e.s)}–${e.ed !== e.d ? fmtDay(e.ed) + ' ' : ''}${fmt(e.e)}`}${st === 'st-no' ? ' · declined' : st === 'st-none' ? ' · not answered' : st === 'st-maybe' ? ' · maybe' : ''}`;
  return `<button class="${cls}" data-a="select" data-id="${e.id}" data-drag="${e.id}" title="${esc(tip)}" style="top:${top + 1}px;height:${h}px;left:${L};width:${W};z-index:${it.z};${evv(e)}"><div class="t">${esc(e.t || (e.draft ? 'New event' : '(No title)'))}</div><div class="m tab">${time}</div></button>`;
}
function dayColumn(d, colW) {
  const hours = Array.from({ length: 24 }, (_, h) => h);
  const lines = hours.map(h => `<div class="hl" style="top:${h * H}px"></div><div class="hh" style="top:${(h + .5) * H}px"></div>`).join('');
  const laid = layoutDay(segsFor(d), colW);
  const marks = laid.marks.map(m => taskMark(m, colW)).join('');
  const now = d === TODAY ? `<div class="nowl today" style="top:${NOW / 60 * H}px"></div>` : (A.view === 'week' ? `<div class="nowl" style="top:${NOW / 60 * H}px"></div>` : '');
  return `<div class="day" data-day="${d}">${lines}${laid.map(it => evBlock(it, colW, d)).join('')}${marks}${now}</div>`;
}
function timeGrid(days, colW) {
  const gut = Array.from({ length: 24 }, (_, h) => h).map(h => h && Math.abs(h * 60 - NOW) > 20 ? `<span class="h tab" style="top:${h * H}px">${String(h).padStart(2, '0')}:00</span>` : '').join('') +
    (days.includes(TODAY) || A.view === 'week' ? `<span class="now tab" style="top:${NOW / 60 * H}px">${fmt(NOW)}</span>` : '');
  return `<div class="gridwrap"><div class="grid" style="height:${24 * H}px"><div class="gut">${gut}</div><div class="days">${days.map(d => dayColumn(d, colW)).join('')}</div></div></div>`;
}
function dayHeaders(days) {
  return `<div class="dh"><div class="g"></div>${days.map(d => `<div class="c ${d < TODAY ? 'past' : ''} ${d === TODAY ? 'today' : ''}" data-a="gotoDay" data-d="${d}" title="Open ${fmtDay(d)} in Day view">${WDS[dow(d)]} <span class="n tab">${dnum(d)}</span></div>`).join('')}</div>`;
}

// ---------- all-day lane (C2 long events with start time, C5 expand/collapse)
function laneItems(d0, n) {
  const d1 = d0 + n - 1;
  const items = A.events.filter(e => inLane(e) && visible(e) && e.d <= d1 && endDay(e) >= d0)
    .map(e => ({ e, a: Math.max(e.d, d0), b: Math.min(endDay(e), d1), cl: e.d < d0, cr: endDay(e) > d1 }))
    .sort((x, y) => (y.b - y.a) - (x.b - x.a) || x.e.d - y.e.d || (x.e.allDay === y.e.allDay ? 0 : x.e.allDay ? 1 : -1) || x.e.s - y.e.s);
  const rows = [];
  items.forEach(it => { let r = 0; while ((rows[r] || []).some(o => o.a <= it.b && it.a <= o.b)) r++; (rows[r] = rows[r] || []).push(it); it.row = r; });
  return { items, rows: rows.length };
}
function laneChip(it, d0, extra = '') {
  const e = it.e, st = myResp(e) && myResp(e) !== 'yes' ? `st-${myResp(e)}` : '';
  const time = !e.allDay ? `<span class="tm tab">${it.cl ? `→ ${fmt(e.e)}` : fmt(e.s)}</span>` : '';
  const cls = ['adi', isPast(e) ? 'past' : '', calOf(e).task ? 'task' : '', st, A.sel === e.id ? 'sel' : '', it.cl ? 'cont' : '', it.cr ? 'cont2' : ''].filter(Boolean).join(' ');
  const tip = e.allDay ? `${e.t} · ${e.ed > e.d ? `${fmtDay(e.d)} – ${fmtDay(e.ed)}` : 'all day'}` : `${e.t} · ${fmtDay(e.d)} ${fmt(e.s)} → ${fmtDay(e.ed)} ${fmt(e.e)} (${dur(durOf(e))})`;
  return `<button class="${cls}" data-a="select" data-id="${e.id}" title="${esc(tip)}" style="grid-column:${it.a - d0 + 1} / span ${it.b - it.a + 1};grid-row:${it.row + 1};${evv(e)};${extra}"><span class="t">${esc(e.t)}</span>${time}</button>`;
}
function allDayLane(days) {
  const d0 = days[0], n = days.length, { items, rows } = laneItems(d0, n);
  const tpl = `grid-template-columns:repeat(${n}, minmax(0, 1fr));`;
  const cols = `<div class="cols" style="${tpl}">${days.map(() => '<i></i>').join('')}</div>`;
  const RH = 22; // v8: 19 px chips + 3 px gap
  if (!items.length) return `<div class="ad"><div class="g"><span class="lbl">all-day</span></div><div class="body" style="height:24px"><div class="gridN" style="${tpl}">${cols}</div></div></div>`;
  const open = A.adOpen, can = rows > 2;
  const limit = open || !can ? rows : 2;
  const shown = items.filter(it => it.row < limit);
  const hidden = days.map(d => items.filter(it => it.row >= limit && it.a <= d && d <= it.b).length);
  let extraRow = '';
  if (!open && can) extraRow = hidden.map((k, i) => k ? `<button class="more tab" data-a="adToggle" style="grid-column:${i + 1};grid-row:${limit + 1}">+${k} more</button>` : '').join('');
  if (open && can) extraRow = `<button class="less" data-a="adToggle" style="grid-column:1 / span ${Math.min(2, n)};grid-row:${rows + 1}">${ic('down', 12, 'style="transform:rotate(180deg)"')} Show less</button>`;
  const lines = limit + (extraRow ? 1 : 0);
  const maxH = 6.5 * RH + 9, h = Math.min(lines * RH + 8, maxH);
  const tog = can ? `<button class="tog ${open ? 'up' : ''}" data-a="adToggle" title="${open ? 'Collapse' : 'Expand'} all-day section">${ic('down', 14)}</button>` : '';
  return `<div class="ad"><div class="g">${tog}<span class="lbl">all-day</span></div>
    <div class="body ${lines * RH + 8 > maxH ? 'scroll' : ''}" data-h="${h}" style="height:${h}px"><div class="gridN" style="${tpl}">${cols}${shown.map(it => laneChip(it, d0)).join('')}${extraRow}</div></div></div>`;
}

// ---------- window chrome
function miniMonth() {
  const base = dd(A.anchor); const y = base.getUTCFullYear(), mo = base.getUTCMonth() + A.mmOff;
  const first = di(y + Math.floor(mo / 12), ((mo % 12) + 12) % 12 + 1, 1), ws = weekStart(first);
  const md = dmon(first), wsel = weekStart(A.anchor);
  let cells = '';
  const wn = A.settings.weekNo;
  for (let w = 0; w < 6; w++) {
    if (wn) cells += `<span class="wkn tab">${weekNo(ws + w * 7)}</span>`;
    for (let i = 0; i < 7; i++) {
      const d = ws + w * 7 + i, inW = A.view === 'week' && weekStart(d) === wsel;
      cells += `<button class="d tab ${dmon(d) !== md ? 'o' : ''} ${inW ? 'wk' : ''} ${inW && i === 0 ? 'first' : ''} ${inW && i === 6 ? 'last' : ''} ${d === TODAY ? 'today' : ''} ${A.view !== 'week' && d === A.anchor && d !== TODAY ? 'picked' : ''}" data-a="gotoDate" data-d="${d}">${dnum(d)}</button>`;
    }
  }
  return `<div class="mm-h"><div>${MONL[md]} <span>${dyear(first)}</span></div><div style="display:flex;gap:2px"><button class="ibtn sm" data-a="mm" data-k="-1" title="Previous month">${ic('left', 14)}</button><button class="ibtn sm" data-a="mm" data-k="1" title="Next month">${ic('right', 14)}</button></div></div>
    <div class="mm ${wn ? 'wn' : ''}">${wn ? '<span class="wd"></span>' : ''}${['M', 'T', 'W', 'T', 'F', 'S', 'S'].map(w => `<span class="wd">${w}</span>`).join('')}${cells}</div>`;
}
// D (5 Nov): a group header shows a chevron on hover; a click folds the group (A.grpClosed). A folded group keeps its chevron visible.
// E (5 Nov): hiding is explicit. Row hover shows an eye at the right (click = hide); a hidden calendar stays in the list, dimmed,
// with an eye-slash that is always shown (click = show). The colour square toggles too; the name itself does nothing.
function sidebar(cls) {
  const groups = GROUPS.map(g => {
    const cs = Object.entries(A.cals).filter(([, c]) => c.g === g.id), closed = A.grpClosed.includes(g.id);
    const nHidden = cs.filter(([k]) => A.hidden.includes(k)).length;
    return `<button class="grp ${closed ? 'closed' : ''}" data-a="togGrp" data-k="${g.id}" title="${closed ? 'Expand' : 'Collapse'} ${esc(g.name)} · ${esc(g.sub)}"><span class="gn">${g.name}</span>${closed ? `<span class="gc tab">${cs.length}${nHidden ? ` · ${nHidden} hidden` : ''}</span>` : ''}<span class="chev">${ic('down', 12)}</span></button>` +
      `<div class="grpbody ${closed ? 'closed' : ''}">` + cs.map(([k, c]) => {
        const off = A.hidden.includes(k);
        return `<div class="cal ${off ? 'off' : ''}" style="--cc:${PK().calDot(c.hex, theme())}"><button class="cb" data-a="togCal" data-k="${k}" title="${off ? 'Show' : 'Hide'} ${esc(c.name)}"></button><span class="nm" title="${esc(c.name)}${off ? ' · hidden' : ''}">${esc(c.name)}</span><button class="eye" data-a="togCal" data-k="${k}" title="${off ? 'Show' : 'Hide'} ${esc(c.name)}">${ic(off ? 'eyeOff' : 'eye', 15)}</button></div>`;
      }).join('') + '</div>';
  }).join('');
  return `<aside class="side ${cls}"><div class="wtop"><div class="lights"><i></i><i></i><i></i></div><div class="sp"></div><button class="ibtn sm" data-a="togLeft" title="Hide sidebar  ⌃⌘S">${ic('sideL', 14)}</button></div>
    ${miniMonth()}<div class="calscroll">${groups}</div>
    <button class="foot" data-a="openSettings" data-k="general">Settings <span style="margin-left:auto">${kb('⌘', ',')}</span></button></aside>`;
}
function headerTitle() {
  const yr = y => ` <span>${y}</span>`;
  if (A.view === 'day') { const d = A.anchor; return `${WDL[dow(d)]}, ${dnum(d)} ${MONL[dmon(d)]}${yr(dyear(d))}`; }
  if (A.view === 'month') { const b = dd(A.anchor); return `${MONL[b.getUTCMonth()]}${yr(b.getUTCFullYear())}`; }
  const ws = weekStart(A.anchor), we = ws + 6;
  return dmon(ws) === dmon(we) ? `${MONL[dmon(ws)]}${yr(dyear(ws))}` : `${MONS[dmon(ws)]} – ${MONS[dmon(we)]}${yr(dyear(we))}`;
}
function hdrTitle() {
  const wk = A.settings.weekNo && A.view !== 'month';
  return `<h2 ${wk ? `title="Week ${weekNo(A.anchor)}"` : ''}>${headerTitle()}</h2>`;
}
function hdr() {
  const unit = A.view === 'day' ? 'day' : A.view === 'month' ? 'month' : 'week';
  return `<div class="hdr">${A.left ? '' : `<div class="lights" style="margin-right:4px"><i></i><i></i><i></i></div><button class="ibtn" data-a="togLeft" title="Show sidebar  ⌃⌘S">${ic('sideL')}</button>`}
    ${hdrTitle()}<div class="sp"></div>
    <div class="segc">${['day', 'week', 'month'].map(v => `<button class="${A.view === v ? 'on' : ''}" data-a="view" data-k="${v}" title="${v[0].toUpperCase() + v.slice(1)} view  ${v[0].toUpperCase()}">${v[0].toUpperCase() + v.slice(1)}</button>`).join('')}</div>
    <div class="nav"><button class="ibtn" data-a="step" data-k="-1" title="Previous ${unit}  K">${ic('left')}</button><button class="btn-line" data-a="goToday" title="Go to today  T">Today</button><button class="ibtn" data-a="step" data-k="1" title="Next ${unit}  J">${ic('right')}</button></div>
    <button class="ibtn ${A.right ? '' : 'on'}" data-a="togRight" title="${A.right ? 'Hide' : 'Show'} right column  ⌥⌘I">${ic('sideR')}</button></div>`;
}

// ---------- views
function weekView() {
  const { days, colW } = gridCols();
  return dayHeaders(days) + allDayLane(days) + timeGrid(days, colW);
}
function dayEvents(d) {
  return A.events.filter(e => visible(e) && e.d <= d && d <= endDay(e)).sort((a, b) => (a.allDay === b.allDay ? 0 : a.allDay ? -1 : 1) || (a.d === d ? a.s : 0) - (b.d === d ? b.s : 0));
}
function focusEvent(d) {
  const f = A.dayFocus && get(A.dayFocus);
  if (f && f.d <= d && d <= endDay(f)) return f;
  const s = selEv(); if (s && s.d <= d && d <= endDay(s)) return s;
  const list = dayEvents(d).filter(e => !e.allDay && !isShort(e) && !inLane(e));
  if (d === TODAY) return list.find(isNow) || list.find(e => e.s > NOW) || list[0];
  return list[0] || dayEvents(d)[0];
}
function restList(d, opts = {}) {
  const list = dayEvents(d).filter(e => !e.allDay && !inLane(e));
  let out = '', cursor = d === TODAY ? null : 8 * 60, nowDone = d !== TODAY;
  const stack = true;
  const nowRow = () => stack ? `<div class="nowrow"><span class="tcol tab">${fmt(NOW)}</span><span class="ln"></span></div>` : `<div class="nowrow">${fmt(NOW)} now</div>`;
  list.forEach(e => {
    const s = e.d === d ? e.s : 0, en = e.ed === d ? e.e : 1440;
    if (!nowDone && s >= NOW) { out += nowRow(); nowDone = true; }
    if (cursor != null && s - cursor >= 90 && !isShort(e)) out += stack ? `<div class="free"><span class="tcol"></span><span></span><span class="tab">Free ${fmt(cursor)}–${fmt(s)} · ${dur(s - cursor)}</span></div>` : `<div class="free">Free ${fmt(cursor)}–${fmt(s)} · ${dur(s - cursor)}</div>`;
    const st = myResp(e) && myResp(e) !== 'yes' ? `st-${myResp(e)}` : '';
    const sub = [e.location ? e.location.split(',')[0] : '', others(e).length ? `${e.guests.length} people` : '', e.call ? CALLNAME[e.call.kind] : '', st === 'st-no' ? 'declined' : st === 'st-none' ? 'not answered' : st === 'st-maybe' ? 'maybe' : ''].filter(Boolean).join(' · ');
    out += `<button class="row ${isPast(e) ? 'past' : ''} ${st} ${opts.focus && opts.focus.id === e.id ? 'hi' : ''}" data-a="${opts.pick ? 'dayFocus' : 'select'}" data-id="${e.id}" style="${evVars(colorOf(e))}${opts.focus && opts.focus.id === e.id ? ';background:var(--hover)' : ''}">
      ${stack ? `<span class="tcol tab"><span>${fmt(s)}</span>${isShort(e) ? '' : `<span class="end">${fmt(en)}</span>`}</span>` : `<span class="tm tab">${isShort(e) ? fmt(s) : `${fmt(s)}–${fmt(en)}`}</span>`}<span class="b"></span><span class="tt" style="min-width:0">${opts.big ? `<b>${esc(e.t)}</b>${sub ? `<small>${esc(sub)}</small>` : ''}` : esc(e.t)}</span>${e.call && !isPast(e) ? `<span class="vid">${callLogo(e.call, 14)}</span>` : '<span></span>'}</button>`;
    cursor = Math.max(cursor == null ? NOW : cursor, isShort(e) ? s : en);
  });
  if (!nowDone) out += nowRow();
  return out || '<div class="empty">Nothing on this day.</div>';
}
function focusCard(e) {
  if (!e) return '<div class="empty">Nothing on this day.</div>';
  const now = isNow(e), soon = !now && e.d === TODAY && e.s > NOW;
  const lab = now ? `Now <span class="cd tab">${(e.ed > TODAY ? 1440 : e.e) - NOW} min left</span>` : soon ? `Up next <span class="cd tab" style="color:var(--fg2)">in ${dur(e.s - NOW)}</span>` : isPast(e) ? 'Earlier' : 'Selected';
  const when = e.allDay ? (e.ed > e.d ? `${fmtDay(e.d)} – ${fmtDay(e.ed)}` : 'All day') : e.ed > e.d ? `${fmtDay(e.d)} ${fmt(e.s)} → ${fmtDay(e.ed)} ${fmt(e.e)} · ${dur(durOf(e))}` : `${fmt(e.s)}–${fmt(e.e)} · ${dur(durOf(e))}`;
  const r = myResp(e);
  return `<div class="lab">${lab}</div><div class="fcard" style="${evVars(colorOf(e))}"><h3><span class="bar"></span><span>${esc(e.t)}</span></h3>
    <div class="meta"><span>${ic('clock', 14)} ${when}</span>${e.location ? `<span>${ic('pin', 14)} ${esc(e.location.split(',')[0])}</span>` : ''}<span>${ic('calendar', 14)} ${esc(calOf(e).name)}</span></div>
    ${others(e).length ? `<div class="people">${e.guests.map(g => `<span class="pchip"><i style="background:${avc(g.id)}">${initials(g.id)}</i>${esc(g.id === 'me' ? 'You' : nameOf(g.id))}${g.resp === 'yes' ? ' ✓' : g.resp === 'no' ? ' ✕' : g.resp === 'maybe' ? ' ?' : ''}</span>`).join('')}</div>` : ''}
    <div class="acts">${e.call ? `<button class="join" style="flex:none;padding:0 16px" data-a="join" data-id="${e.id}">${callLogo(e.call, 15)} Join ${CALLNAME[e.call.kind]} <span class="kh">⌘J</span></button>` : ''}
      ${r ? `<div class="segc ${google() ? '' : 'off'}" title="${google() ? 'Your reply' : 'Connect Google to reply'}">${['yes', 'maybe', 'no'].map(k => `<button class="${r === k ? 'on' : ''}" data-a="rsvp" data-k="${k}" data-id="${e.id}">${{ yes: 'Going', maybe: 'Maybe', no: 'Decline' }[k]}</button>`).join('')}</div>` : ''}
      ${e.location ? `<button class="btn sm" data-a="openMap" data-k="dirbtn" data-id="${e.id}">${ic('map', 14)} Directions</button>` : ''}
      <button class="btn sm ghost" data-a="select" data-id="${e.id}">${ic('notes', 14)} Edit</button></div>
    ${userNotes(e.notes) ? `<div class="notes">${esc(userNotes(e.notes))}</div>` : ''}</div>`;
}
function dayView() {
  const d = A.anchor, { days, colW } = gridCols();
  const tl = `<div class="tl">${dayHeaders(days)}${allDayLane(days)}${timeGrid(days, colW)}</div>`;
  const f = focusEvent(d);
  return `<div class="dayv split">${tl}<div class="focus">${focusCard(f)}<div class="lab" style="margin-top:4px">${d === TODAY ? 'Rest of today' : 'The whole day'}</div><div class="restlist">${restList(d, { pick: true, focus: f })}</div></div></div>`;
}
function monthView() {
  const b = dd(A.anchor), first = di(b.getUTCFullYear(), b.getUTCMonth() + 1, 1), ws = weekStart(first), md = b.getUTCMonth();
  const head = `<div class="mh">${WDS.map(w => `<span>${w}</span>`).join('')}</div>`;
  const MAXR = 4;
  const weeks = Array.from({ length: 6 }, (_, w) => {
    const d0 = ws + w * 7, { items, rows } = laneItems(d0, 7);
    const lane = items.filter(it => it.row < MAXR);
    const used = Array.from({ length: 7 }, (_, i) => items.filter(it => it.a <= d0 + i && d0 + i <= it.b).length);
    let lines = '';
    for (let i = 0; i < 7; i++) {
      const d = d0 + i, timed = A.events.filter(e => !inLane(e) && visible(e) && e.d === d).sort((x, y) => x.s - y.s);
      const free = Math.max(0, MAXR - Math.min(rows, MAXR)), take = timed.slice(0, free);
      const hiddenN = timed.length - take.length + Math.max(0, used[i] - lane.filter(it => it.a <= d && d <= it.b).length);
      take.forEach((e, k) => { const st = myResp(e) && myResp(e) !== 'yes' ? `st-${myResp(e)}` : ''; lines += `<button class="mline ${isPast(e) ? 'past' : ''} ${st}" data-a="select" data-id="${e.id}" style="grid-column:${i + 1};grid-row:${Math.min(rows, MAXR) + k + 1};${evVars(colorOf(e))}"><span class="dt"></span><span class="tm tab">${fmt(e.s)}</span><span class="t">${esc(e.t)}</span></button>`; });
      if (hiddenN > 0) lines += `<button class="mmore tab" data-a="gotoDay" data-d="${d}" style="grid-column:${i + 1};grid-row:${MAXR + 1}">+${hiddenN} more</button>`;
    }
    const cells = Array.from({ length: 7 }, (_, i) => { const d = d0 + i; return `<div class="cell ${dmon(d) !== md ? 'o' : ''} ${d === TODAY ? 'today' : ''}" data-a="gotoDay" data-d="${d}" style="left:${i / 7 * 100}%;width:${100 / 7}%"><span class="num tab">${dnum(d) === 1 ? MONS[dmon(d)] + ' ' : ''}${dnum(d)}</span></div>`; }).join('');
    return `<div class="mweek">${cells}${lane.map(it => laneChip(it, d0)).join('')}${lines}</div>`;
  }).join('');
  return `<div class="month">${head}${weeks}</div>`;
}
const viewBody = () => A.view === 'day' ? dayView() : A.view === 'month' ? monthView() : weekView();

// ---------- Today column
// v8: Now / Up next lead, then "Later today". The "Useful shortcuts" list is gone (C, 5 Nov): shortcuts live under ?, ⌘K and Help.
// The mail button beside Join is gone too (H): "Email guests" is the first item of the guest "…" menu in the editor.
function joinBtn(e, cls = 'join') { return `<button class="${cls}" data-a="join" data-id="${e.id}">${callLogo(e.call, 14)} Join ${CALLNAME[e.call.kind]} <span class="kh">⌘J</span></button>`; }
function todayParts() {
  const todays = A.events.filter(e => visible(e) && !e.allDay && !inLane(e) && e.d <= TODAY && TODAY <= endDay(e)).sort((a, b) => a.s - b.s);
  const now = todays.find(isNow), next = todays.find(e => !isShort(e) && e.d === TODAY && e.s > NOW && myResp(e) !== 'no');
  const later = todays.filter(e => e.d === TODAY && e.s > NOW && e !== next);
  return { now, next, later };
}
const guestsTxt = e => others(e).length ? ` · ${others(e).length} guest${others(e).length > 1 ? 's' : ''}` : '';
const cardActs = (e, live) => e.call ? `<div class="acts">${joinBtn(e, live ? 'join' : 'join ghost')}</div>` : '';
const laterRow = e => `<button class="later ${myResp(e) && myResp(e) !== 'yes' ? `st-${myResp(e)}` : ''}" data-a="select" data-id="${e.id}" style="${evv(e)}"><span class="tm tab">${fmt(e.s)}</span><span class="b"></span><span class="ttl">${esc(e.t)}</span></button>`;
function todayCol() {
  const { now, next, later } = todayParts();
  const card = (e, lab, cd, live, lead) => `<div class="card dc ${lead ? 'lead' : ''} ${live ? 'now' : 'next'}" style="${evv(e)}"><div class="lab">${lab} <span class="cd tab ${live ? 'live' : ''}">${cd}</span></div>
    <button class="ttl" data-a="select" data-id="${e.id}"><span class="tcol tab"><span>${fmt(e.s)}</span><span class="end">${fmt(e.e)}</span></span><span class="b"></span><span class="tx"><b>${esc(e.t)}</b><small class="tab">${dur(durOf(e))}${guestsTxt(e)}${e.location ? ` · ${esc(e.location.split(',')[0])}` : ''}</small></span></button>
    ${cardActs(e, live)}</div>`;
  return `${now ? card(now, 'Now', `${now.e - NOW} min left`, true, true) : ''}
    ${next ? card(next, 'Up next', `in ${dur(next.s - NOW)}`, false, !now) : ''}
    ${later.length ? `<div class="lab2">Later today</div>${later.map(laterRow).join('')}` : ''}
    ${!now && !next && !later.length ? '<div class="empty">Nothing else today.</div>' : ''}`;
}
