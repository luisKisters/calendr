// Calendr mockup v5: the picker rail (outside the app). Tabs by app area, 2-4 variants per open choice,
// REC on the recommended one, WAS on what the installed v4 build does. The combination lives in the URL hash.
'use strict';

const TABS = [['feedback', 'Feedback'], ['preview', 'Preview']];
// [key, ids, name, why, scene, options: [value, label, help, flag]]  flag: 'rec' | 'was'
// only open choices stay here; every decided item is simply the mockup now (decision record: FEEDBACK.md)
const ELEMENTS = [
  ['preview', 'appear', '', 'Preview theme', 'Only a preview switch. The app keeps both themes: Settings → Appearance offers Dark, Paper and Auto (follows macOS).', 'C9', [['dark', 'Dark (OLED black)', ''], ['paper', 'Paper', '']]],
];
const TOGGLES = { preview: [['hasg', 'Has Google calendars', 'Whether Apple Calendar on this Mac already has the Google calendars. Changes the "Choose your calendars" onboarding step.'], ['google', 'Google connected', 'On: replies, guests, Meet links and "Send update" work. Off: what the user has today; every place says why and offers Connect.']] };
const V = {};
const DEFAULTS = {};
ELEMENTS.forEach(el => { DEFAULTS[el[1]] = (el[6].find(o => o[3] === 'rec') || el[6][0])[0]; });
Object.assign(DEFAULTS, { tabnums: '0', rowgrid: '0', dock: '0', google: '1', hasg: '1' }); // tabnums, rowgrid, dock: set by scenes only
Object.assign(V, DEFAULTS);
let TAB = 'feedback';

const FEEDBACK = [
  ['A1', 'p0', 'Tab through editor fields crashes', 'Own Tab order top to bottom, visible focus ring, no hidden notes field.', 'A1'],
  ['A2', 'p0', 'Editor fields freeze the app', 'Saves and reloads leave the main thread; typing never waits.', 'A2'],
  ['A3', 'p1', 'Caret stays in the old field', 'A click on any control takes the focus.', 'A3'],
  ['A4', 'p1', 'Conferencing field is broken', 'Full-width link field that detects Zoom/Teams/Meet; Create Meet.', 'A4'],
  ['B1', 'p1', 'Participants row not clickable', 'Guest field with contacts; without Google it explains and connects.', 'B1'],
  ['B2', 'p1', '"Does not repeat" not clickable', 'Repeat menu with Custom… (interval, days, end).', 'B2'],
  ['B3', 'p2', '"…" next to participants does nothing', 'Menu: email guests, copy emails, open in Google.', 'B3'],
  ['B4', 'p2', 'Editor spacing is off', 'One row metric: 32 px rows, text on the icon line.', 'B4'],
  ['B5', 'p2', 'Raw Zoom invitation in notes', 'Stripped silently; the Join button has the link.', 'B5'],
  ['B6', 'p2', 'Location suggestions slow / missing', 'Suggestions while typing; hover a set place for the maps actions.', 'B6'],
  ['B7', 'p1', 'Multi-day events cannot be created', 'End date picker; all-day keeps the days.', 'B7'],
  ['C1', 'p2', 'Day view is not useful', 'New Day view: timeline + focus panel (3 variants).', 'C1'],
  ['C2', 'p1', 'Multi-day timed events are tall columns', 'Top lane with the start time, like Notion.', 'C2'],
  ['C3', 'p1', 'Overlap "+N" stack reaches outside the column', 'Stack removed. Side by side with hover-grow, cascade, or Google columns.', 'C3'],
  ['C4', 'p1', 'Declined events are invisible', 'Visible, struck; Settings → Show declined events.', 'C4'],
  ['C5', 'p2', 'All-day lane collapse UX is poor', 'Chevron always there, "Show less", animated.', 'C5'],
  ['C6', 'p2', 'Right sidebar cannot be closed', 'Button top right + ⌥⌘I; left ⌃⌘S.', 'C6'],
  ['C7', 'p2', 'Hour labels too dark', '#8A8A8A instead of #6A6A6A.', 'C7'],
  ['C8', 'p2', 'Grid lines too low contrast', 'Stronger lines; optional own sidebar shade.', 'C7'],
  ['C9', 'p2', 'Paper theme too pale', 'Paper+: darker greys, more colour.', 'C9'],
  ['D1', 'p1', 'Search covers only ~Oct–Nov', '"Search earlier" loads 6 more months back.', 'D1'],
  ['D2', 'p1', 'Result list capped (~5)', 'No cap; ⌘K has "Show all N results".', 'D2'],
  ['D3', 'p1', 'First search incomplete', '"Searching…" while loading, then it refreshes.', 'D3'],
  ['D4', 'p1', 'Typing in search lags', 'Debounced 150 ms, off the main thread.', 'D4'],
  ['D5', 'p2', 'Results start at old dates', 'Upcoming first; earlier results above it with sticky headers.', 'D5'],
  ['D6', 'f', 'Search participants', 'Guest names and emails match; "Guest: …" line.', 'D6'],
  ['E1', 'p0', 'Cannot decline or answer "maybe"', 'Yes/Maybe/No with Google; clearly disabled + Connect without.', 'E1'],
  ['E2', 'p2', 'Menu bar menu too wide and too tall', 'Native, 300 pt, today + tomorrow, all-day folded, fixed height that scrolls.', 'E2'],
  ['E3', 'q', 'Is the Google connection needed?', 'Optional; Settings → Accounts says what it adds.', 'E3'],
  ['O1', 'f', 'Onboarding (decided)', 'First launch explains Google and offers Connect or Skip.', 'O1'],
  ['E4', 'p2', 'App icon is old', 'Now line icon, shown in a Dock.', 'E4'],
  ['F1', 'f', 'Create events from the menu bar', 'New event… ⌘N with a quick-add window.', 'F1'],
  ['F2', 'f', 'Join shortcut', '⌘J joins the current call; shown on every Join.', 'F2'],
  ['F3', 'f', 'Create multi-day events', 'End date + top lane.', 'B7'],
  ['F4', 'f', 'Create a Google Meet link', '"Create Google Meet link" in the editor.', 'F4'],
  ['F5', 'f', 'Redesign the Day view', 'See C1.', 'C1'],
];

// ---------------------------------------------------------------- scenes ("Show me")
const find = (t, d) => A.events.find(e => e.t === t && (d == null || e.d === d));
function base(v = {}) {
  const keepAppear = V.appear;
  Object.assign(V, DEFAULTS, { appear: keepAppear }, v);
  A = Object.assign(fresh(), { left: A.left });
  A.settings.appearance = V.appear;
}
function openEv(e, extra = {}) { A.anchor = e.d; A.sel = e.id; A.gridScroll = Math.max(0, (e.s / 60 - 2) * H); Object.assign(A, extra); }
const SCENES = {
  A1: ['Founder circle is open. Press Tab and Shift-Tab: the numbers show the order, the yellow one has the focus. Tab never leaves the editor.', () => { base({ tabnums: '1' }); openEv(find('Founder circle', 3), { focusKey: 'title' }); }],
  A2: ['Type in Notes or Location. Nothing blocks; saving runs in the background (no status line, by decision).', () => { base(); openEv(find('Founders Conference'), { focusKey: 'notes' }); }],
  A3: ['The caret is in Location. Click "Add reminder", "Busy" or the calendar: the focus ring moves to what you clicked.', () => { base({ tabnums: '1' }); openEv(find('Founders Conference'), { focusKey: 'loc' }); }],
  A4: ['A real link field: paste or type a link, it names the service. "Create Google Meet link" makes one (turn Google off in the Preview tab to see the hint).', () => { base(); openEv(find('Build: search v2', 2), { confOpen: true, focusKey: 'link' }); A.q.link = 'zoom.us/j/123456789'; }],
  F4: ['Click "Create Google Meet link": the link is made with the save and the Join button appears.', () => { base(); openEv(find('Build: search v2', 2), { confOpen: true }); }],
  B1: ['Design review already has guests. Type a name in "Add guests": contacts from Apple Contacts and Google. Return adds. Turn Google off in the Preview tab to see the explanation.', () => { base(); openEv(find('Design review'), { focusKey: 'guest' }); A.q.guest = 'an'; A.pop = { k: 'guest' }; }],
  B2: ['The repeat row opens a menu; "Custom…" sets an interval, weekdays and an end.', () => { base(); openEv(find('Founder circle', 3)); A.pop = { k: 'repeat' }; }],
  B3: ['The "…" button opens real actions.', () => { base(); openEv(find('Design review')); A.pop = { k: 'guestmore' }; }],
  B4: ['Every row is 32 px with the text on the icon line. Green: icon and text columns; blue: one row each.', () => { base({ rowgrid: '1' }); openEv(find('Founders Conference')); }],
  B5: ['The Zoom invitation block is gone from the notes; only your own text stays. The Join button has the link.', () => { base(); openEv(find('Founder circle', 3)); }],
  B6: ['Point at the set location: Open in Google Maps, Open in Apple Maps, Copy address. Click into it and type: places from the first letter.', () => { base(); openEv(find('Long walk', 6), { locHot: true }); }],
  B7: ['Start and end each have a date. The event runs Fri 10:00 → Sat 16:00 and sits in the top lane. Click a date for the month picker.', () => { base(); openEv(find('Team offsite')); A.adOpen = true; A.gridScroll = 7 * H; }],
  C1: ['The new Day view (Fri 6 Nov): timeline left, the chosen event big on the right, the day as a list under it.', () => { base(); A.view = 'day'; A.anchor = 4; A.gridScroll = 7.5 * H; }],
  C2: ['Team offsite (Fri 10:00 → Sat 16:00) is in the top lane with "10:00" (lane opened).', () => { base(); A.adOpen = true; A.gridScroll = 7 * H; }],
  C3: ['Thu evening: five events overlap. No "+N" stack any more: each has its own column. Hover only lightens; a click brings an event to the front.', () => { base(); A.gridScroll = 16.5 * H; }],
  C4: ['Thu 18:30 Neighbourhood meetup is declined: visible, faded and struck. Settings → General → "Show declined events" hides it.', () => { base(); A.gridScroll = 16.5 * H; A.modal = 'settings'; A.settingsTab = 'general'; A.hlSetting = 'declined'; }],
  C5: ['The all-day lane is open (Wed has five items). The chevron and "Show less" close it with an animation.', () => { base(); A.adOpen = true; }],
  C6: ['The right column is hidden. The button at the top right or ⌥⌘I brings it back; selecting an event opens it too.', () => { base(); A.right = false; }],
  C7: ['Brighter hour labels, stronger lines, sidebars in their own shade.', () => { base(); A.gridScroll = 8 * H; }],
  C9: ['Paper+: darker greys, deeper surfaces, more colour in the events.', () => { base({ appear: 'paper' }); A.settings.appearance = 'paper'; A.gridScroll = 8 * H; }],
  D1: ['"sam" finds every day since September. Scroll up: "Load earlier results" at the top of Earlier loads more, then six more months at a time.', () => { base(); A.search.warm = true; A.q.search = 'sam'; runSearch(true); }],
  D2: ['⌘K shows five events and "Show all N results in the sidebar".', () => { base(); A.search.warm = true; A.modal = 'cmd'; A.q.cmd = 'sam'; A.focusKey = 'cmd'; }],
  D3: ['The first search runs while the calendars still load: "Searching…", then the list fills in by itself.', () => { base(); A.search.warm = false; A.q.search = 'sam'; A.focusKey = 'search'; runSearch(true); }],
  D4: ['Type fast in the search field: typing never waits; the list follows 150 ms after the last key.', () => { base(); A.search.warm = true; A.focusKey = 'search'; }],
  D5: ['The list opens at "Upcoming"; the last 3 earlier results sit just above it. Scroll up: the sticky header turns from "Upcoming" to "Earlier".', () => { base(); A.search.warm = true; A.q.search = 'sam'; runSearch(true); }],
  D6: ['"mailbox" is only in Sam\'s address: the guest line says why each result matched.', () => { base(); A.search.warm = true; A.q.search = 'mailbox'; runSearch(true); }],
  E1: ['Without Google the reply control is visibly off, with "Connect Google to reply" and "Open in Google Calendar". Turn Google on in the Preview tab: Yes / Maybe / No work.', () => { base({ google: '0' }); openEv(find('Hiring sync')); }],
  E2: ['Decided: the compact native menu. Today and Tomorrow, all-day folded, a fixed height that scrolls, Join on every call.', () => { base(); A.mb = true; }],
  E3: ['Settings → Accounts: Apple Calendar stays the source; Google only adds replies, guests, update emails and Meet links.', () => { base(); A.modal = 'settings'; A.settingsTab = 'accounts'; }],
  E4: ['The Now line icon in the Dock.', () => { base({ dock: '1' }); }],
  F1: ['"New event…" in the menu bar opens quick add: day and time come from the text.', () => { base(); A.mb = true; A.qadd = true; A.q.qadd = 'Kaffee mit Sam morgen 15 uhr'; A.focusKey = 'qadd'; }],
  O1cal: ['The "Choose your calendars" step. Flip "Has Google calendars" in the Preview tab to see the case without them.', () => { base({ google: '0' }); A.modal = 'onboard'; A.obStep = 2; }],
  O1: ['First launch. Continue through the steps: Connect Google shows the sign-in; "Skip, use Apple Calendar only" works too.', () => { base({ google: '0' }); A.modal = 'onboard'; A.obStep = 0; }],
  F2: ['Press ⌘J: it joins Design review (running now). Every Join button shows ⌘J.', () => { base(); }],
};
function scene(id) {
  const s = SCENES[id]; if (!s) return;
  s[1](); TAB = TAB || 'feedback'; A.sceneId = id;
  saveHash(); render(); banner(s[0]);
  if (id === 'D4') setTimeout(() => { const i = document.querySelector('[data-k="search"]'); if (i) i.focus(); }, 50);
}
function banner(t) {
  const st = document.getElementById('stage'); let b = st.querySelector('.banner');
  if (!b) { b = document.createElement('div'); b.className = 'banner'; st.appendChild(b); }
  b.textContent = t; b.style.display = 'block'; clearTimeout(b._t); b._t = setTimeout(() => { b.style.display = 'none'; }, 9000);
}

// ---------------------------------------------------------------- hash
function saveHash() {
  const parts = [`tab=${TAB}`, ...Object.keys(DEFAULTS).map(k => `${k}=${encodeURIComponent(V[k])}`)];
  if (A && A.sceneId) parts.push(`scene=${A.sceneId}`);
  history.replaceState(null, '', '#' + parts.join('&'));
  const c = document.getElementById('rcode'); if (c) c.textContent = location.hash;
}
function readHash() {
  const h = {}; location.hash.slice(1).split('&').filter(Boolean).forEach(x => { const [k, v] = x.split('='); h[k] = decodeURIComponent(v || ''); });
  Object.keys(DEFAULTS).forEach(k => { const el = ELEMENTS.find(x => x[1] === k); if (h[k] != null && (!el || el[6].some(o => o[0] === h[k]))) V[k] = h[k]; });
  if (h.tab && TABS.some(t => t[0] === h.tab)) TAB = h.tab;
  return h;
}

// ---------------------------------------------------------------- rail UI
function optHTML(el) {
  const [, key, , , , , opts] = el;
  return opts.map(([v, label, help, flag]) => `<button class="ropt ${V[key] === v ? 'on' : ''}" data-r="opt" data-k="${key}" data-v="${v}"><span class="r"></span><span class="tx">${esc(label)}${help ? `<small>${esc(help)}</small>` : ''}</span>${flag === 'rec' ? '<span class="rec">REC</span>' : flag === 'was' ? '<span class="was">WAS</span>' : ''}</button>`).join('');
}
function togHTML(t) { return `<button class="rtog ${V[t[0]] === '1' ? 'on' : ''}" data-r="tog" data-k="${t[0]}"><i></i><span class="tx">${esc(t[1])}<small>${esc(t[2])}</small></span></button>`; }
function railBody() {
  if (TAB === 'feedback') {
    return `<div class="rnote">Every decision is built in; no choices are open. Every item from the test on 4 Nov (<code>BUGS.md</code>). <b>Show me</b> puts the app into the state that shows the fix, with a hint at the top. Everything stays clickable; the other tabs switch variants. Full report: <code>design/mockup-v5/FEEDBACK.md</code>.<div class="rscenes"><button class="rbtn key" data-r="scene" data-k="O1">Show onboarding</button></div></div>` +
      FEEDBACK.map(([id, sev, title, fix, sc]) => `<div class="fb ${A.sceneId === sc ? 'cur' : ''}"><span class="id">${id}</span><span class="ti">${esc(title)}<span class="sev ${sev}">${sev === 'q' ? '?' : sev.toUpperCase()}</span></span><span class="fx">${esc(fix)}</span><button class="rbtn go ${A.sceneId === sc ? 'key' : ''}" data-r="scene" data-k="${sc}">Show me</button></div>`).join('') +
      `<div class="rnote" style="margin-top:14px"><b>Keys</b>: ⌘K commands · / search · C new event · ⌘J join · T today · J/K next/previous · D/W/M views · ⌃⌘S sidebar · ⌥⌘I right column · ⌃⌘K menu bar · ⌘, settings · ? shortcuts · ⌫ delete · ⌘Z undo · esc close. Drag on the grid to create; drag an event to move it.</div>`;
  }
  let h = '';
  ELEMENTS.filter(el => el[0] === TAB).forEach(el => {
    h += `<div class="rel"><div class="nm">${esc(el[3])}${el[2] ? `<span class="ids">${el[2]}</span>` : ''}</div><div class="why">${esc(el[4])}</div>${optHTML(el)}</div>`;
  });
  if (TAB === 'preview') {
    h += `<div class="rel">${TOGGLES.preview.map(togHTML).join('')}</div>`;
    h += `<div class="rnote"><b>E3: why Google at all?</b> Apple Calendar shows and edits everything, Google calendars included, and stays the default. Its API cannot reply to invitations, add guests, send invitations or create Meet links; connecting Google adds exactly those.</div>`;
    h += `<div class="rscenes"><button class="rbtn key" data-r="scene" data-k="O1">Show onboarding</button><button class="rbtn" data-r="scene" data-k="O1cal">Choose calendars step</button><button class="rbtn" data-r="scene" data-k="E3">Settings → Accounts</button></div>`;
  }
  return h;
}
function renderRail() {
  const r = document.getElementById('rail');
  r.innerHTML = `<div class="rh"><span class="tt">Calendr <em>v5</em> · test feedback</span><button class="x" data-r="hide" title="Hide the picker">${ic('x', 14)}</button></div>
    <div class="rtabs">${TABS.map(([k, l]) => `<button class="${TAB === k ? 'on' : ''}" data-r="tab" data-k="${k}">${l}</button>`).join('')}</div>
    <div class="rbody">${railBody()}</div>
    <div class="rstat"><code id="rcode">${esc(location.hash)}</code><button class="rbtn" data-r="copy">Copy link</button><button class="rbtn" data-r="reset">Reset</button></div>`;
  railFocus();
}
function railFocus() {
  const f = document.getElementById('rfocus'); if (!f) return;
  const ae = document.activeElement, k = ae && ae.dataset && (ae.dataset.k || ae.dataset.k2);
  const names = { title: 'Title', sdate: 'Start date', edate: 'End date', stime: 'Start time', etime: 'End time', allday: 'All day', repeat: 'Repeat', guestmore: 'Participants menu', guest: 'Add guests', going: 'Going?', conf: 'Add conferencing', meet: 'Create Google Meet link', link: 'Link field', join: 'Join', linkedit: 'Meeting link', loc: 'Location', notes: 'Notes', fold: 'Invitation text', cal: 'Calendar', busy: 'Busy', vis: 'Visibility', addrem: 'Add reminder', search: 'Search', cmd: 'Command menu', qadd: 'Quick add' };
  f.innerHTML = `<b>Focus now</b>: ${k ? esc(names[k] || (k.startsWith('rem') ? 'Remove reminder' : k)) : ae && ae.closest && ae.closest('.pfoot') ? 'Footer button' : '—'}`;
}
window.railFocus = railFocus;
window.railAfterRender = () => { const c = document.getElementById('rcode'); if (c) c.textContent = location.hash; };
window.saveHash = saveHash;
document.getElementById('rail').addEventListener('click', ev => {
  const b = ev.target.closest('[data-r]'); if (!b) return;
  const r = b.dataset.r, k = b.dataset.k;
  if (r === 'tab') { TAB = k; saveHash(); renderRail(); return; }
  if (r === 'opt') { V[k] = b.dataset.v; if (k === 'appear') A.settings.appearance = V.appear; saveHash(); renderRail(); render(); return; }
  if (r === 'tog') { V[k] = V[k] === '1' ? '0' : '1'; saveHash(); renderRail(); render(); return; }
  if (r === 'scene') { scene(k); renderRail(); return; }
  if (r === 'sceneToday') { base(); A.view = 'day'; A.anchor = TODAY; A.gridScroll = 15 * H; saveHash(); render(); renderRail(); return; }
  if (r === 'copy') { navigator.clipboard && navigator.clipboard.writeText(location.href); b.textContent = 'Copied'; setTimeout(() => { b.textContent = 'Copy link'; }, 1200); return; }
  if (r === 'reset') { Object.assign(V, DEFAULTS); A = fresh(); A.sceneId = null; saveHash(); render(); renderRail(); return; }
  if (r === 'hide') { document.getElementById('page').classList.add('norail'); fit(); return; }
});
document.getElementById('fab').addEventListener('click', () => { document.getElementById('page').classList.remove('norail'); fit(); });

// ---------------------------------------------------------------- boot
(function boot() {
  const h = readHash();
  bootApp();
  if (h.scene && SCENES[h.scene]) { SCENES[h.scene][1](); readHash(); A.settings.appearance = V.appear; A.sceneId = h.scene; }
  saveHash(); render();
  renderRail();
})();
