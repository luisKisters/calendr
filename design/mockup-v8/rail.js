// Calendr v8: the picker rail (outside the app). The Dark/Paper preview switch sits on top of every tab; the combination lives in the URL hash.
// D3 "Graphite timetable" is the design (locked 5 Nov); there is no pack switch any more.
'use strict';

const TABS = [['feedback', 'Feedback'], ['preview', 'Preview']];
const TOGGLES = { preview: [['google', 'Google connected', 'On: replies, guests, Meet links and "Send update" work. Off: what the user has today; every place says why and offers Connect.'], ['hasg', 'Has Google calendars', 'Whether Apple Calendar on this Mac already has the Google calendars. Changes the "Choose your calendars" onboarding step.']] };
const V = {};
const DEFAULTS = { appear: 'dark', tabnums: '0', rowgrid: '0', dock: '0', google: '1', hasg: '1' }; // tabnums, rowgrid, dock: set by scenes only
const CHOICES = { appear: ['dark', 'paper'] };
Object.assign(V, DEFAULTS);
let TAB = 'feedback';

// Round 2026-11-05 (user test, voice note): A–H. Scene keys N + letter.
const ROUND5 = [
  ['A', 'p1', 'Now line goes under events', 'Drawn above every event: 2 px red across today with a dot, a faint line across the other days, the time on a red pill.', 'NA'],
  ['B', 'p1', 'Everything too big, too strong', 'Calmer and denser: smaller title and type, lighter weights, 44 px hours, quieter half hours; hour lines stay clear.', 'NB'],
  ['C', 'p2', '"Useful shortcuts" list is clutter', 'Gone from the right column; ? , ⌘K and Help still list them.', 'NC'],
  ['D', 'p2', 'Calendar groups cannot fold', 'Hover a group header: a chevron; click folds it. A folded group shows its count.', 'ND'],
  ['E', 'p1', 'Hiding calendars is not discoverable', 'Row hover shows an eye (click hides). Hidden rows stay, dimmed, with an eye-slash (click shows). Hover fixed.', 'NE'],
  ['F', 'p1', 'Location hover menu is noisy', 'A set place is text; hover underlines it, a click opens the default maps app (asks once). Copy icon beside it.', 'NF'],
  ['G', 'p1', 'Conferencing click opens Meet', 'Click = paste-link field; "Create Google Meet" separately below. A set link is a call row; only Join opens it.', 'NG'],
  ['H', 'p2', 'Mail icon next to Join is unclear', 'Removed. "Email guests" is the first item of the guest "…" menu.', 'NH'],
];
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
  ['C3', 'p1', 'Overlap "+N" stack reaches outside the column', 'No "+N" anywhere. Overlaps draw as a cascade (decided 5 Nov).', 'C3'],
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
  NA: ['Now (Wed 18:15) runs through "Design review" and its neighbours: the line is drawn above every event, 2 px red with a dot on today, faint on the other days, the time on a red pill.', () => { base(); A.reveal = { from: 16.5 * 60, to: 20 * 60 }; }],
  NB: ['The calmer, denser week: 18 px title, 12 px events at weight 500 → 450, 44 px hours with clear hour lines and quiet half hours, smaller chrome.', () => { base(); A.gridScroll = 8 * H; }],
  NC: ['The right column: Now and Up next, then Later today. No shortcut list (press ? or ⌘K).', () => { base(); A.reveal = { from: 17 * 60, to: 20 * 60 }; }],
  ND: ['"Subscribed calendars" is folded (it shows how many it holds). Point at any group header: the chevron appears; click to fold or unfold.', () => { base(); A.grpClosed = ['subs']; }],
  NE: ['Point at a calendar row: an eye at the right hides it. "Family" is hidden: it stays in the list, dimmed, with an eye-slash that shows it again. The colour square toggles too.', () => { base(); A.hidden = ['family']; }],
  NF: ['The place is plain text. Point at it: it underlines. Click it: the first time Calendr asks which maps app to use ("Remember my choice"). The copy icon copies the address; the pencil edits it.', () => { base(); openEv(find('Long walk', 6), { locHot: true }); }],
  NF2: ['The one-time question after the first click on a location. With "Remember my choice" on, later clicks open the app directly; Settings → General → Default maps app changes it.', () => { base(); openEv(find('Long walk', 6), { locHot: true }); A.pop = { k: 'maps', id: find('Long walk', 6).id }; }],
  NG: ['"Add conferencing" was clicked: a paste field that names the service (Zoom, Teams, Meet), and separately "Create Google Meet". Turn Google off in the Preview tab to see the explanation instead.', () => { base(); openEv(find('Build: search v2', 2), { confOpen: true, focusKey: 'link' }); }],
  NG2: ['An event with a call: the call row shows the service and the link as text, with Join (⌘J). Join is the only way to open the link.', () => { base(); openEv(find('Founder circle', 3)); }],
  NH: ['No mail icon next to Join any more. Guest actions sit in the "…" menu of Participants, "Email guests" first.', () => { base(); openEv(find('Design review')); A.pop = { k: 'guestmore' }; }],
  A1: ['Founder circle is open. Press Tab and Shift-Tab: the numbers show the order, the yellow one has the focus. Tab never leaves the editor.', () => { base({ tabnums: '1' }); openEv(find('Founder circle', 3), { focusKey: 'title' }); }],
  A2: ['Type in Notes or Location. Nothing blocks; saving runs in the background (no status line, by decision).', () => { base(); openEv(find('Founders Conference'), { focusKey: 'notes' }); }],
  A3: ['The caret is in Location. Click "Add reminder", "Busy" or the calendar: the focus ring moves to what you clicked.', () => { base({ tabnums: '1' }); openEv(find('Founders Conference'), { focusKey: 'loc' }); }],
  A4: ['A real link field: paste or type a link, it names the service. "Create Google Meet" below makes one (turn Google off in the Preview tab to see the hint).', () => { base(); openEv(find('Build: search v2', 2), { confOpen: true, focusKey: 'link' }); A.q.link = 'zoom.us/j/123456789'; }],
  F4: ['Click "Create Google Meet": the link is made with the save and the Join button appears.', () => { base(); openEv(find('Build: search v2', 2), { confOpen: true }); }],
  B1: ['Design review already has guests. Type a name in "Add guests": contacts from Apple Contacts and Google. Return adds. Turn Google off in the Preview tab to see the explanation.', () => { base(); openEv(find('Design review'), { focusKey: 'guest' }); A.q.guest = 'an'; A.pop = { k: 'guest' }; }],
  B2: ['The repeat row opens a menu; "Custom…" sets an interval, weekdays and an end.', () => { base(); openEv(find('Founder circle', 3)); A.pop = { k: 'repeat' }; }],
  B3: ['The "…" button opens the guest actions, "Email guests" first.', () => { base(); openEv(find('Design review')); A.pop = { k: 'guestmore' }; }],
  B4: ['Every row is 32 px with the text on the icon line. Green: icon and text columns; blue: one row each.', () => { base({ rowgrid: '1' }); openEv(find('Founders Conference')); }],
  B5: ['The Zoom invitation block is gone from the notes; only your own text stays. The Join button has the link.', () => { base(); openEv(find('Founder circle', 3)); }],
  B6: ['A set location is text: a click opens the default maps app (see F). The pencil edits it; typing suggests places from the first letter.', () => { base(); openEv(find('Long walk', 6), { locHot: true }); }],
  B7: ['Start and end each have a date. The event runs Fri 10:00 → Sat 16:00 and sits in the top lane. Click a date for the month picker.', () => { base(); openEv(find('Team offsite')); A.adOpen = true; A.gridScroll = 7 * H; }],
  C1: ['The new Day view (Fri 6 Nov): timeline left, the chosen event big on the right, the day as a list under it.', () => { base(); A.view = 'day'; A.anchor = 4; A.gridScroll = 7.5 * H; }],
  C2: ['Team offsite (Fri 10:00 → Sat 16:00) is in the top lane with "10:00" (lane opened).', () => { base(); A.adOpen = true; A.gridScroll = 7 * H; }],
  OV: ['Thu 5 Nov, 18:00–21:30: five events and a task overlap; 23:00 has two tasks and a short event every day. Cascade (decided): every title stays readable, nothing is folded into "+N"; tasks are markers at the right. Hover only lightens; a click brings an event to the front.', () => { base(); A.gridScroll = 16.5 * H; A.reveal = { from: 17.5 * 60, to: 21 * 60 }; }],
  OVD: ['Day view of Thu 5 Nov evening, overlaps as a cascade.', () => { base(); A.view = 'day'; A.anchor = 3; A.gridScroll = 16.5 * H; }],
  C3: ['Thu evening: five events overlap and draw as a cascade (decided 5 Nov); nothing folds into "+N". Hover only lightens; a click brings an event to the front.', () => { base(); A.gridScroll = 16.5 * H; A.reveal = { from: 17.5 * 60, to: 21 * 60 }; }],
  C4: ['Thu 18:30 Neighbourhood meetup is declined: visible, faded and struck. Settings → General → "Show declined events" hides it.', () => { base(); A.gridScroll = 16.5 * H; A.reveal = { from: 18 * 60, to: 20 * 60, under: '.modal' }; A.pin = find('Neighbourhood meetup').id; A.modal = 'settings'; A.settingsTab = 'general'; A.hlSetting = 'declined'; }],
  C5: ['The all-day lane is open (Wed has five items). The chevron and "Show less" close it with an animation.', () => { base(); A.adOpen = true; }],
  C6: ['The right column is hidden. The button at the top right or ⌥⌘I brings it back; selecting an event opens it too.', () => { base(); A.right = false; }],
  C7: ['Clear hour labels and hour lines, sidebars in their own shade.', () => { base(); A.gridScroll = 8 * H; }],
  C9: ['Paper: the light theme, with the same event marks, lines and fonts as Dark.', () => { base({ appear: 'paper' }); A.settings.appearance = 'paper'; A.gridScroll = 8 * H; }],
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
  Object.keys(DEFAULTS).forEach(k => { if (h[k] != null && (!CHOICES[k] || CHOICES[k].includes(h[k]))) V[k] = h[k]; });
  if (h.tab && TABS.some(t => t[0] === h.tab)) TAB = h.tab;
  return h;
}

// ---------------------------------------------------------------- rail UI
function togHTML(t) { return `<button class="rtog ${V[t[0]] === '1' ? 'on' : ''}" data-r="tog" data-k="${t[0]}"><i></i><span class="tx">${esc(t[1])}<small>${esc(t[2])}</small></span></button>`; }
function themeStrip() {
  const b = (v, l) => `<button class="${V.appear === v ? 'on' : ''}" data-r="opt" data-k="appear" data-v="${v}">${l}</button>`;
  return `<div class="rpacks"><div class="rseg">${b('dark', 'Dark')}${b('paper', 'Paper')}</div><span class="rpk1">Graphite timetable · preview switch; the app also has Auto in Settings → Appearance</span></div>`;
}
const fbRow = ([id, sev, title, fix, sc]) => `<div class="fb ${A.sceneId === sc ? 'cur' : ''}"><span class="id">${id}</span><span class="ti">${esc(title)}<span class="sev ${sev}">${sev === 'q' ? '?' : sev.toUpperCase()}</span></span><span class="fx">${esc(fix)}</span><button class="rbtn go ${A.sceneId === sc ? 'key' : ''}" data-r="scene" data-k="${sc}">Show me</button></div>`;
function overlapsPick() {
  return `<div class="rel"><div class="nm">Overlaps: cascade <span class="ids">decided 5 Nov</span></div><div class="why">Google-like: each overlapping event steps in about 12 px and sits on top of the earlier one at near full width; one that starts within 20 min of another takes the right half. Tasks are a small marker at the right edge. Nothing folds into "+N".</div>` +
    `<div class="rscenes"><button class="rbtn ${A.sceneId === 'OV' ? 'key' : ''}" data-r="scene" data-k="OV">Show Thu evening</button><button class="rbtn ${A.sceneId === 'OVD' ? 'key' : ''}" data-r="scene" data-k="OVD">Day view</button></div></div>`;
}
function railBody() {
  if (TAB === 'feedback') {
    return `<div class="rnote"><b>Round 2026-11-05</b> (user test, voice note). <b>Show me</b> puts the app into the state that shows the change, with a hint at the top; everything stays clickable. Decision record: <code>design/mockup-v8/FEEDBACK.md</code>. Visual system: <code>design/mockup-v8/NOTES.md</code>.</div>` +
      overlapsPick() +
      ROUND5.map(fbRow).join('') +
      `<div class="rscenes" style="margin:6px 0 4px"><button class="rbtn" data-r="scene" data-k="NF2">F: first-click chooser</button><button class="rbtn" data-r="scene" data-k="NG2">G: call row with Join</button></div>` +
      `<div class="rnote" style="margin-top:16px"><b>Earlier rounds</b>: every item from the test on 4 Nov (<code>BUGS.md</code>), all built in.</div>` +
      FEEDBACK.map(fbRow).join('') +
      `<div class="rnote" style="margin-top:14px"><b>Keys</b>: ⌘K commands · / search · C new event · ⌘J join · T today · J/K next/previous · D/W/M views · ⌃⌘S sidebar · ⌥⌘I right column · ⌃⌘K menu bar · ⌘, settings · ? shortcuts · ⌫ delete · ⌘Z undo · esc close. Drag on the grid to create; drag an event to move it.</div>`;
  }
  let h = `<div class="rel"><div class="nm">Theme</div><div class="why">Only a preview switch. The app keeps both themes: Settings → Appearance offers Dark, Paper and Auto (follows macOS).</div>
    <div class="rseg" style="margin-top:4px"><button class="${V.appear === 'dark' ? 'on' : ''}" data-r="opt" data-k="appear" data-v="dark">Dark</button><button class="${V.appear === 'paper' ? 'on' : ''}" data-r="opt" data-k="appear" data-v="paper">Paper</button></div></div>`;
  h += `<div class="rel">${TOGGLES.preview.map(togHTML).join('')}</div>`;
  h += `<div class="rel"><div class="nm">Show onboarding</div><div class="why">First launch: explains Google and offers Connect or Skip.</div><div class="rscenes"><button class="rbtn key" data-r="scene" data-k="O1">Show onboarding</button><button class="rbtn" data-r="scene" data-k="O1cal">Choose calendars step</button><button class="rbtn" data-r="scene" data-k="E3">Settings → Accounts</button></div></div>`;
  h += `<div class="rnote"><b>E3: why Google at all?</b> Apple Calendar shows and edits everything, Google calendars included, and stays the default. Its API cannot reply to invitations, add guests, send invitations or create Meet links; connecting Google adds exactly those.</div>`;
  return h;
}
function renderRail() {
  const r = document.getElementById('rail');
  r.innerHTML = `<div class="rh"><span class="tt">Calendr <em>v8</em></span><button class="x" data-r="hide" title="Hide the picker">${ic('x', 14)}</button></div>
    ${themeStrip()}
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
