// Calendr v8: actions, pointer, keyboard. v8 adds: sidebar group fold (D), eye toggles (E), location → default maps app (F).
'use strict';

function select(id, opts = {}) {
  const prev = selEv();
  if (prev && prev.draft && prev.id !== id) A.events = A.events.filter(x => x.id !== prev.id);
  A.sel = id; A.pop = null; A.locEdit = false; A.locHot = false; A.confOpen = false; A.confPaste = false; A.showBoiler = false; A.guestHint = false; A.q.guest = ''; A.q.link = ''; A.custom = null;
  if (!A.right) A.right = true; // the editor lives in the right column, so selecting re-opens it (C6)
  if (opts.search !== true) A.q.search = '';
  A.panelTop = 0;
}
function deselect() { const e = selEv(); if (e && e.draft) A.events = A.events.filter(x => x.id !== e.id); A.sel = null; A.pop = null; A.confOpen = false; A.custom = null; }
function newEvent(d, s, e) {
  deselect();
  if (d == null) { // next free half hour today
    d = TODAY; s = Math.ceil((NOW + 1) / 30) * 30;
    const busy = A.events.filter(x => visible(x) && !x.allDay && x.d === TODAY && !isShort(x));
    while (busy.some(x => x.s < s + 60 && x.e > s)) s += 30;
    e = s + 60;
  }
  const ev = { id: 'n' + (A.nextId++), d, s, ed: d, e: Math.min(e, 1440), allDay: false, t: '', cal: 'personal', guests: [], call: null, location: '', notes: '', repeat: null, organizer: true, reminders: [10], busy: 'Busy', vis: 'Default visibility', color: null, draft: true };
  if (ev.e === 1440) { ev.ed = d + 1; ev.e = 0; }
  A.events.push(ev); A.sel = ev.id; A.right = true; A.q.search = ''; A.focusKey = 'title';
  if (A.view === 'month') { A.view = 'week'; A.anchor = d; }
}
// edits: shared fields on an event with guests wait for "Send update"; the save itself runs in the background (A2)
let saveTimer;
function edit(fn, shared = true) {
  const e = selEv(); if (!e) return;
  if (shared && !e.draft && google() && !A.base[e.id]) A.base[e.id] = clone(e);
  fn(e);
  const b = A.base[e.id]; if (b && sharedOf(b) === sharedOf(e)) delete A.base[e.id];
  render();
}
const setEnd = (e, ed, en) => { if (ed * 1440 + en <= e.d * 1440 + e.s) { toast('The end must be after the start', `${fmtDay(e.d)} ${fmt(e.s)}`, { icon: 'info' }); return false; } e.ed = ed; e.e = en; return true; };
function parseTime(v) { const t = String(v).replace(/[^0-9]/g, ''); if (!t) return null; let h, mi; if (t.length <= 2) { h = +t; mi = 0; } else { h = +t.slice(0, -2); mi = +t.slice(-2); } return h < 24 && mi < 60 ? h * 60 + mi : null; }
function copied(what) { toast('Copied', what, { icon: 'copy' }); }
function connectGoogle() { A.modal = 'oauth'; A.pop = null; }
function openInMaps(k, e, remembered) { const [n, logo] = MAPAPPS[k]; toast(`Opened in ${n}`, `${e.location.split(',')[0]}${remembered ? ' · remembered as default (Settings → General)' : ''}`, { logo: logo(18) }); }

const ACT = {
  noop() { },
  select(t) {
    const id = t.dataset.id;
    if (A.view === 'day') A.dayFocus = id;
    select(id);
  },
  dayFocus(t) { A.dayFocus = t.dataset.id; },
  // v7 fix (a): "+N" in a crowded column selects the folded events in turn; the selected one swaps into view (layoutDay)
  evMore(t) { const ids = t.dataset.ids.split(','), i = ids.indexOf(A.sel); const id = ids[(i + 1) % ids.length]; if (A.view === 'day') A.dayFocus = id; select(id); },
  close() { deselect(); },
  closePop() { A.pop = null; },
  closeToast() { A.toast = null; },
  closeModal() { A.modal = null; A.obAuthOpen = false; A.q.cmd = ''; A.hlSetting = null; },
  view(t) { A.view = t.dataset.k; A.pop = null; if (A.view === 'week') A.gridScroll = Math.max(A.gridScroll, 7.5 * H); },
  viewDay() { A.view = 'day'; }, viewWeek() { A.view = 'week'; }, viewMonth() { A.view = 'month'; },
  step(t) { const k = +t.dataset.k; if (A.view === 'day') A.anchor += k; else if (A.view === 'week') A.anchor += 7 * k; else { const b = dd(A.anchor); A.anchor = di(b.getUTCFullYear(), b.getUTCMonth() + 1 + k, 1); } A.mmOff = 0; A.dayFocus = null; },
  goToday() { A.anchor = TODAY; A.mmOff = 0; A.dayFocus = null; A.gridScroll = 15.7 * H; },
  gotoDate(t) { A.anchor = +t.dataset.d; A.mmOff = 0; A.dayFocus = null; },
  gotoDay(t) { A.anchor = +t.dataset.d; A.view = 'day'; A.dayFocus = null; },
  mm(t) { A.mmOff += +t.dataset.k; },
  togCal(t) { const k = t.dataset.k; A.hidden = A.hidden.includes(k) ? A.hidden.filter(x => x !== k) : [...A.hidden, k]; if (A.search.res) A.search.res = searchHits(A.q.search.trim()); },
  // D: fold a calendar group in the sidebar (kept in the mockup state)
  togGrp(t) { const k = t.dataset.k; A.grpClosed = A.grpClosed.includes(k) ? A.grpClosed.filter(x => x !== k) : [...A.grpClosed, k]; },
  togLeft() { A.left = !A.left; },
  togRight() { A.right = !A.right; },
  adToggle() { A.adOpen = !A.adOpen; A.animAd = true; },
  newEvent() { newEvent(); },
  cmd() { A.modal = 'cmd'; A.q.cmd = ''; A.cmdHi = 0; A.focusKey = 'cmd'; },
  runCmd(t) { A.modal = null; const f = ACT[t.dataset.k]; A.q.cmd = ''; if (f) f(t); },
  shortcuts() { A.modal = 'shortcuts'; },
  openSettings(t) { A.modal = 'settings'; A.settingsTab = (t && t.dataset && t.dataset.k) || 'general'; A.mb = false; },
  focusSearch() { A.right = true; A.focusKey = 'search'; },
  togDeclined() { A.settings.declined = !A.settings.declined; toast(A.settings.declined ? 'Declined events are shown' : 'Declined events are hidden', 'Settings → General', { icon: 'check' }); },
  togWeekNo() { A.settings.weekNo = !A.settings.weekNo; },
  togAppearance() { setV('appear', isLight() ? 'dark' : 'paper'); },
  setAppearance(t) { if (t.dataset.k === 'auto') A.settings.appearance = 'auto'; else setV('appear', t.dataset.k); },
  setWeekStart(t) { A.settings.weekStart = t.dataset.k; toast('Shown as Monday-first in this mockup', '', { icon: 'info' }); },
  setMb(t) { A.settings[t.dataset.k] = t.dataset.k === 'mbRows' ? +t.dataset.v : t.dataset.v; },
  togMenubar() { A.mb = !A.mb; A.qadd = false; A.mbAllOpen = null; },
  // ---------- joining (F2)
  join(t) { const e = get(t.dataset.id); if (!e || !e.call) return; A.mb = false; toast(`Opening ${CALLNAME[e.call.kind]}`, `${e.t} · ${e.call.url}`, { logo: callLogo(e.call, 18) }); },
  joinNext() { const e = joinTarget(); if (!e) { toast('No call to join', 'Nothing with a call is running or starts in the next 15 min'); return; } ACT.join({ dataset: { id: e.id } }); },
  mailGuests(t) { const e = get(t.dataset.id) || selEv(); A.pop = null; if (!e) return; const list = others(e).filter(g => t.dataset.k !== 'open' || g.resp === 'none'); toast('New email in Mail', `To: ${list.map(g => person(g.id).email).join(', ') || 'nobody'}`, { icon: 'mail' }); },
  mailOne(t) { toast('New email in Mail', `To: ${person(t.dataset.i).email}`, { icon: 'mail' }); },
  copyEmails(t) { const e = selEv(); A.pop = null; const l = others(e).map(g => t.dataset.k === 'names' ? `${nameOf(g.id)} <${person(g.id).email}>` : person(g.id).email); copied(`${l.length} address${l.length > 1 ? 'es' : ''}: ${l.join(', ')}`); },
  openGcal() { A.pop = null; toast('Opened in Google Calendar', 'calendar.google.com · Wed 4 Nov', { icon: 'open' }); },
  openCal() { toast('Opened in Calendar', 'macOS Calendar shows the event', { icon: 'open' }); },
  connect() { connectGoogle(); },
  obGo(t) { A.obStep = t.dataset.k === 'back' ? Math.max(0, (A.obStep || 0) - 1) : +t.dataset.k; return obSync(); },
  obSkip() { setV('google', '0', true); A.obStep = 4; return obSync(); },
  obAuth() { A.obAuthFrom = A.obStep; A.obAuthOpen = true; return obSync(); },
  obAuthCancel() { A.obAuthOpen = false; return obSync(); },
  obAuthOk() { A.obAuthOpen = false; setV('google', '1', true); A.obStep = A.obAuthFrom === 2 ? 2 : 4; return obSync(); },
  obCal(t) {
    const id = t.dataset.k, w = t.dataset.w, c = A.obCals[id] = A.obCals[id] || {}, on = !t.classList.contains('on');
    c[w] = on; t.classList.toggle('on', on);
    const list = w === 'app' ? 'hidden' : 'mbHidden';
    A[list] = on ? A[list].filter(x => x !== id) : [...A[list], id];
    return false;
  },
  obSysSettings() { toast('System Settings → Internet Accounts', 'Add your Google account there; its calendars then show in Calendr', { icon: 'open' }); },
  oauthOk() { A.modal = null; setV('google', '1', true); toast('Google connected', `${ME} · replies, guests and Meet links now work`, { logo: gLogo(18) }); },
  disconnect() { setV('google', '0', true); toast('Google disconnected', 'Events still show through macOS Calendar'); },
  // ---------- editor
  del() { const e = selEv(); if (!e) return; if (e.organizer && others(e).length) { A.modal = 'delete'; return; } ACT.doDelete({ dataset: {} }); },
  doDelete(t) { const e = selEv(); if (!e) return; snapshot(); A.events = A.events.filter(x => x.id !== e.id); A.sel = null; A.modal = null; toast(`Deleted “${e.t}”`, t.dataset.k === 'quiet' ? 'No email sent' : others(e).length && google() ? `${others(e).length} guests notified` : '', { undo: true, icon: 'trash' }); },
  undo() { if (!A.undo) return; A.events = A.undo; A.undo = null; A.toast = null; },
  commitDraft() { const e = selEv(); if (!e) return; delete e.draft; if (!e.t) e.t = 'New event'; A.sel = null; toast(`Created “${e.t}”`, `${fmtDay(e.d)} ${fmt(e.s)} · ${calOf(e).name}`, { undo: true, icon: 'check' }); A.undo = clone(A.events.filter(x => x.id !== e.id)); },
  discard() { const e = selEv(); const b = A.base[e.id]; if (b) { Object.assign(e, b); delete A.base[e.id]; } },
  sendUpdate(t) { const e = selEv(); delete A.base[e.id]; toast(t.dataset.k === 'quiet' ? 'Saved, no email' : 'Update sent', `${others(e).length} guests`, { icon: 'check' }); },
  allDay() { edit(e => { if (e.allDay) { e.allDay = false; e.s = 9 * 60; e.e = 10 * 60; e.busy = 'Busy'; } else { e.ed = endDay(e); e.allDay = true; e.s = e.e = 0; e.busy = 'Free'; } }); },
  setRepeat(t) { A.pop = null; edit(e => { e.repeat = t.dataset.v === 'Does not repeat' ? null : t.dataset.v; }); },
  customRepeat() { A.pop = { k: 'custom' }; A.custom = null; },
  cunit(t) { A.custom.unit = t.dataset.k; }, cends(t) { A.custom.ends = t.dataset.k; },
  cday(t) { const i = +t.dataset.i, c = A.custom; c.days = c.days.includes(i) ? c.days.filter(x => x !== i) : [...c.days, i].sort(); },
  applyCustom() { const c = A.custom, n = c.n; const label = `Every ${n > 1 ? n + ' ' : ''}${c.unit}${n > 1 ? 's' : ''}${c.unit === 'week' ? ' on ' + c.days.map(i => WDS[i]).join(', ') : ''}${c.ends === 'date' ? ', until 31 Dec' : c.ends === 'count' ? ', 10 times' : ''}`; A.pop = null; edit(e => { e.repeat = label; }); },
  guestHint() { A.guestHint = !A.guestHint; },
  addGuest(t) { const id = t.dataset.i; if (!PEOPLE[id]) PEOPLE[id] = { name: '', email: id, src: 'new' }; A.q.guest = ''; A.pop = null; A.focusKey = 'guest'; edit(e => { if (!e.guests.length) e.guests.push({ id: 'me', resp: 'yes', org: true }); e.guests.push({ id, resp: 'none' }); }); },
  rmGuest(t) { edit(e => { e.guests = e.guests.filter(g => g.id !== t.dataset.i); if (e.guests.length === 1) e.guests = []; }); },
  rsvp(t) {
    const e = get(t.dataset.id) || selEv(); if (!e) return;
    if (!(google() && isGoogleCal(e))) { toast('Replies need Google', 'Connect Google in Settings → Accounts, or reply in Google Calendar', { icon: 'lock' }); return; }
    const me = e.guests.find(g => g.id === 'me'); me.resp = t.dataset.k;
    const org = e.guests.find(g => g.org);
    toast(`Replied “${{ yes: 'Yes', maybe: 'Maybe', no: 'No' }[t.dataset.k]}”`, `${org ? nameOf(org.id) : 'The organizer'} gets an email${t.dataset.k === 'no' ? ' · the event stays visible, struck through' : ''}`, { icon: 'check' });
  },
  confOpen() { A.confOpen = true; A.focusKey = 'link'; },
  pasteLink() { A.pop = null; A.confPaste = true; A.confOpen = true; A.focusKey = 'link'; },
  makeMeet() {
    A.pop = null; A.confOpen = false;
    const id = A.sel; edit(e => { e.call = { kind: 'meet', url: 'meet.google.com/new', pending: true }; });
    setTimeout(() => { const e = get(id); if (e && e.call && e.call.pending) { e.call = { kind: 'meet', url: 'meet.google.com/vxa-pdtq-kre' }; toast('Google Meet link created', 'meet.google.com/vxa-pdtq-kre', { logo: meetLogo(18) }); render(); } }, 1100);
  },
  rmCall() { edit(e => { e.call = null; }); A.confOpen = false; },
  copyLink() { copied(selEv().call.url); },
  togBoiler() { A.showBoiler = !A.showBoiler; A.focusKey = 'fold'; },
  pickPlace(t) { A.pop = null; A.locTyped = false; edit(e => { e.location = t.dataset.v; }); },
  // F: a click on a set location opens the default maps app; with no default yet it asks once ("Remember my choice")
  openMap(t) { const e = get(t.dataset.id) || selEv(); if (!e || !e.location) return; if (A.settings.maps === 'ask') { A.pop = { k: 'maps', id: e.id, anchor: `[data-k="${t.dataset.k || 'locopen'}"]` }; return; } openInMaps(A.settings.maps, e); },
  pickMaps(t) { const e = get(t.dataset.id) || selEv(), k = t.dataset.k; A.pop = null; if (A.mapsRemember) A.settings.maps = k; openInMaps(k, e, A.mapsRemember); },
  togRemember() { A.mapsRemember = !A.mapsRemember; },
  setMaps(t) { A.settings.maps = t.dataset.k; },
  copyLoc() { const e = selEv(); if (e) copied(e.location); },
  editLoc() { A.locEdit = true; A.locHot = false; A.focusKey = 'loc'; },
  maps(t) { const e = get(t.dataset.id) || selEv(); A.pop = null; const k = t.dataset.k; if (k === 'copy') copied(e.location); else toast(k === 'apple' ? 'Opened in Apple Maps' : 'Opened in Google Maps', e.location.split(',')[0], { logo: k === 'apple' ? appleMaps(18) : gMaps(18) }); },
  setCal(t) { A.pop = null; edit(e => { e.cal = t.dataset.k; }, false); },
  setColor(t) { A.pop = null; edit(e => { e.color = t.dataset.k; }, false); },
  setBusy(t) { A.pop = null; edit(e => { e.busy = t.dataset.v; }, false); },
  setVis(t) { A.pop = null; edit(e => { e.vis = t.dataset.v; }, false); },
  addRem(t) { A.pop = null; A.focusKey = 'addrem'; edit(e => { const v = +t.dataset.v; if (!e.reminders.includes(v)) e.reminders.push(v); e.reminders.sort((a, b) => a - b); }, false); },
  rmRem(t) { A.focusKey = 'addrem'; edit(e => { e.reminders.splice(+t.dataset.i, 1); }, false); },
  pickTime(t) { A.pop = null; const v = +t.dataset.v; edit(e => { if (t.dataset.i === 's') { const len = durOf(e); e.s = v; const end = e.d * 1440 + v + len; e.ed = Math.floor(end / 1440); e.e = end % 1440; } else setEnd(e, e.ed, v); }); },
  pickDate(t) { A.pop = null; const d = +t.dataset.d; edit(e => { if (t.dataset.i === 's') { const sh = d - e.d; e.d += sh; e.ed += sh; } else { if (e.allDay) { if (d < e.d) toast('The end must be after the start'); else e.ed = d; } else setEnd(e, d, e.e); } }); },
  calOff(t) { A.pop.off = (A.pop.off || 0) + +t.dataset.k; },
  // ---------- search (D)
  clearSearch() { A.q.search = ''; runSearch(); A.focusKey = 'search'; },
  openResult(t) { const e = get(t.dataset.id); A.modal = null; A.anchor = e.d; if (A.view === 'month') A.view = 'week'; A.gridScroll = Math.max(0, (e.s / 60 - 1.5) * H); select(e.id, { search: true }); A.q.search = ''; A.search.res = null; },
  showMore(t) { const k = t.dataset.k || 'shown'; A.search[k] += k === 'shownE' ? 20 : 40; },
  openEarly() { A.search.earlyOpen = true; },
  scrollUp() { const sc = document.querySelector('.right .scroll'); if (sc) sc.scrollBy({ top: -260, behavior: 'smooth' }); return false; },
  stab(t) { A.search.tab = t.dataset.k; A.search.shown = 40; },
  searchEarlier() { A.search.phase = 'more'; setTimeout(() => { A.search.from -= 183; A.search.phase = 'ready'; A.search.res = searchHits(A.q.search.trim()); render(); }, 600); },
  showAllResults() { A.q.search = A.q.cmd; A.modal = null; A.q.cmd = ''; A.right = true; A.sel = null; runSearch(true); A.focusKey = 'search'; },
  // ---------- menu bar (E2 / F1)
  mbAll(t) { const d = +t.dataset.d; A.mbAllOpen = A.mbAllOpen === d ? null : d; },
  mbOpen(t) { A.mb = false; const e = get(t.dataset.id); A.anchor = e.d; select(e.id); },
  mbMore(t) { A.mb = false; A.anchor = +t.dataset.d; A.view = 'day'; },
  mbOpenApp() { A.mb = false; },
  mbNew() { A.qadd = true; A.q.qadd = ''; A.qaddDay = null; A.qaddTime = null; A.focusKey = 'qadd'; },
  qaDay(t) { A.qaddDay = +t.dataset.d; A.focusKey = 'qadd'; },
  qaTime(t) { A.qaddTime = +t.dataset.v; A.focusKey = 'qadd'; },
  qaddOk() { const p = parseQuick(A.q.qadd); snapshot(); const ev = { id: 'n' + (A.nextId++), d: p.d, s: p.s, ed: p.d, e: p.e, allDay: false, t: p.title || 'New event', cal: 'personal', guests: [], call: null, location: '', notes: '', repeat: null, organizer: true, reminders: [10], busy: 'Busy', vis: 'Default visibility', color: null }; A.events.push(ev); A.qadd = false; A.mb = false; toast(`Added “${ev.t}”`, `${fmtDay(ev.d)} ${fmt(ev.s)}–${fmt(ev.e)} · Personal`, { undo: true, icon: 'check' }); },
  openFull() { const p = parseQuick(A.q.qadd); A.qadd = false; A.mb = false; newEvent(p.d, p.s, p.e); selEv().t = p.title; },
};

// picker-facing helper (rail.js sets V and the hash)
function setV(k, v, silent) { V[k] = v; if (k === 'appear') A.settings.appearance = v; if (window.saveHash) saveHash(); if (!silent) { } }

// ================================================================ pointer
function onClick(ev) {
  const host = document.getElementById('host');
  if (!host.contains(ev.target)) return;
  if (dragState && dragState.moved) return;
  const pt = ev.target.closest('[data-pop]');
  const at = ev.target.closest('[data-a]');
  // a click inside an open popover or modal does not close it
  const inPop = ev.target.closest('.pop, .modal, .mbmenu, .mbpop, .qadd');
  if (pt && (!at || at.contains(pt))) {
    const k = pt.dataset.pop, i = pt.dataset.i;
    if (A.pop && A.pop.k === k && A.pop.i === i) A.pop = null;
    else A.pop = { k, i, ids: pt.dataset.ids ? pt.dataset.ids.split(',') : null };
    render(); return;
  }
  if (at) {
    if (at.getAttribute('aria-disabled') === 'true' && at.dataset.a === 'rsvp') { ACT.rsvp(at); render(); return; }
    const f = ACT[at.dataset.a];
    if (f) {
      if (!inPop && !['closePop'].includes(at.dataset.a)) { if (A.pop && !at.closest('.pd') ) A.pop = null; }
      if (!at.closest('.mbmenu, .mbpop, .qadd, #statusitem') && at.dataset.a !== 'join') { if (A.mb && !at.closest('[data-mb]')) A.mb = false; if (A.qadd && !at.closest('.qadd')) A.qadd = false; }
      ev.stopPropagation(); if (f(at) !== false) render(); return;
    }
  }
  // click on empty space: close menus first, then the editor
  if (ev.target.closest('input, textarea, label')) return;
  if (A.pop || A.mb || A.qadd) { if (!inPop) { A.pop = null; A.mb = false; A.qadd = false; render(); } return; }
}
// A3: a click on any control in the editor moves the focus to it
function onMouseDown(ev) {
  const el = ev.target.closest('.pd [data-k], .pd [data-k2], .pfoot button');
  if (el && el.tagName === 'BUTTON') { el.focus({ preventScroll: true }); }
  const t = ev.target;
  // drag to create (on empty grid) or to move (on a block)
  const dayEl = t.closest('.day');
  if (!dayEl || ev.button !== 0 || t.closest('.evx')) return;
  const evEl = t.closest('.ev, .tmk');
  const k = scale(), r = dayEl.getBoundingClientRect();
  const minute = Math.max(0, Math.min(1425, Math.round(((ev.clientY - r.top) / k) / H * 60 / 15) * 15));
  dragState = { day: +dayEl.dataset.day, start: minute, x0: ev.clientX, y0: ev.clientY, moved: false, id: evEl ? evEl.dataset.drag : null, el: evEl, dayEl };
}
let dragState = null;
function onMouseMove(ev) {
  if (!dragState) return;
  const ds = dragState, k = scale();
  if (!ds.moved && Math.hypot(ev.clientX - ds.x0, ev.clientY - ds.y0) < 5) return;
  ds.moved = true;
  const dy = (ev.clientY - ds.y0) / k, dm = Math.round(dy / H * 60 / 15) * 15;
  if (ds.id) {
    const e = get(ds.id); if (!e || e.allDay || calOf(e).ro || !e.organizer) { ds.blocked = true; return; }
    const colW = ds.dayEl.getBoundingClientRect().width;
    const dd2 = Math.round((ev.clientX - ds.x0) / colW);
    ds.dm = dm; ds.dd = A.view === 'week' ? dd2 : 0;
    ds.el.classList.add('drag');
    ds.el.style.transform = `translate(${ds.dd * colW / k}px, ${dm / 60 * H}px)`;
  } else {
    const a = Math.min(ds.start, ds.start + dm), b = Math.max(ds.start, ds.start + dm) + 15;
    ds.s = a; ds.e = Math.min(b, 1440);
    let rect = ds.dayEl.querySelector('.sel-rect');
    if (!rect) { rect = document.createElement('div'); rect.className = 'sel-rect tab'; ds.dayEl.appendChild(rect); }
    Object.assign(rect.style, { top: (ds.s / 60 * H) + 'px', height: ((ds.e - ds.s) / 60 * H - 2) + 'px' });
    rect.textContent = `${fmt(ds.s)}–${fmt(ds.e)}`;
  }
}
function onMouseUp() {
  const ds = dragState; if (!ds) return;
  setTimeout(() => { dragState = null; }, 0);
  if (!ds.moved) return;
  if (ds.id && !ds.blocked && (ds.dm || ds.dd)) {
    snapshot();
    const e = get(ds.id), shift = (ds.dd || 0) * 1440 + (ds.dm || 0);
    const st = e.d * 1440 + e.s + shift, en = e.ed * 1440 + e.e + shift;
    e.d = Math.floor(st / 1440); e.s = ((st % 1440) + 1440) % 1440; e.ed = Math.floor(en / 1440); e.e = ((en % 1440) + 1440) % 1440;
    toast(`Moved “${e.t}”`, `${fmtDay(e.d)} ${fmt(e.s)}–${fmt(e.e)}`, { undo: true, icon: 'check' });
    render(); return;
  }
  if (ds.id && ds.blocked) { toast('This event cannot be moved here', 'You are not the organizer, or the calendar is read-only', { icon: 'lock' }); render(); return; }
  if (!ds.id && ds.e - ds.s >= 15) { newEvent(ds.day, ds.s, ds.e); render(); }
}
function onDblClick(ev) {
  const dayEl = ev.target.closest('.day'); if (!dayEl || ev.target.closest('.ev, .evx, .tmk')) return;
  const k = scale(), r = dayEl.getBoundingClientRect();
  const s = Math.max(0, Math.min(1380, Math.floor(((ev.clientY - r.top) / k) / H * 60 / 30) * 30));
  newEvent(+dayEl.dataset.day, s, s + 60); render();
}

// ================================================================ text input
function onInput(ev) {
  const t = ev.target, k = t.dataset.k; if (!k) return;
  const e = selEv();
  if (k === 'search') { A.q.search = t.value; A.search.shown = 40; A.search.shownE = 3; A.search.jump = true; if (!t.value.trim()) A.search.res = null; runSearch(); render(); return; }
  if (k === 'cmd') { A.q.cmd = t.value; A.cmdHi = 0; render(); return; }
  if (k === 'qadd') { A.q.qadd = t.value; render(); return; }
  if (k === 'guest') { A.q.guest = t.value; A.hi = 0; A.pop = { k: 'guest' }; render(); return; }
  if (k === 'link') { A.q.link = t.value; render(); return; }
  if (k === 'cnum') { A.custom.n = Math.max(1, parseInt(t.value) || 1); return; }
  if (!e) return;
  if (k === 'title') { edit(x => { x.t = t.value; }); return; }
  if (k === 'loc') { A.locTyped = true; A.hi = 0; A.pop = { k: 'loc' }; edit(x => { x.location = t.value; }); return; }
  if (k === 'notes') {
    const sn = splitNotes(e.notes);
    edit(x => { x.notes = false ? t.value : (t.value + (sn.boiler ? '\n\n' + sn.boiler : '')); });
    t.style.height = 'auto'; t.style.height = t.scrollHeight + 'px'; return;
  }
}
function commitTime(t) {
  const e = selEv(); if (!e) return;
  const v = parseTime(t.value);
  if (v == null) { render(); return; }
  if (t.dataset.k === 'stime' && v !== e.s) ACT.pickTime({ dataset: { i: 's', v } });
  else if (t.dataset.k === 'etime' && v !== e.e) ACT.pickTime({ dataset: { i: 'e', v } });
}
function onFocusIn(ev) {
  const t = ev.target, k = t.dataset && t.dataset.k;
  if (k === 'loc') { A.locTyped = false; A.hi = 0; A.locEdit = true; }
  if (k === 'guest' && t.tagName === 'INPUT' && !isOpen('guest')) { A.pop = { k: 'guest' }; A.hi = 0; render(); }
  if ((k === 'stime' || k === 'etime') && !isOpen('time')) { A.pop = { k: 'time', i: k[0] }; render(); }
  if (window.railFocus) railFocus();
  tabNumbers();
}
function onFocusOut(ev) {
  const t = ev.target, k = t.dataset && t.dataset.k;
  if ((k === 'stime' || k === 'etime')) setTimeout(() => { if (document.activeElement !== t) commitTime(t); }, 120);
  // F: leaving the location field shows the place as text again
  if (k === 'loc') setTimeout(() => { const ae = document.activeElement; if (ae && ae.dataset && ae.dataset.k === 'loc') return; if (!A.locEdit) return; A.locEdit = false; if (A.pop && A.pop.k === 'loc') A.pop = null; render(); }, 200);
  if (k === 'link' && A.q.link.trim()) { const d = detectLink(A.q.link); if (d && d.ok) setTimeout(() => acceptLink(), 0); }
  setTimeout(() => { if (window.railFocus) railFocus(); tabNumbers(); }, 0);
}
function acceptLink() {
  const d = detectLink(A.q.link); if (!d || !d.ok) { toast('That is not a meeting link yet', 'Paste a Zoom, Teams, Meet or other https link', { icon: 'info' }); render(); return; }
  const url = A.q.link.trim().replace(/^https?:\/\//, ''); A.q.link = ''; A.confOpen = false; A.confPaste = false; A.focusKey = 'join';
  edit(e => { e.call = { kind: d.kind, url }; });
}

// ================================================================ keyboard
function onKey(ev) {
  const t = ev.target, inField = t.matches && t.matches('input, textarea'), k = t.dataset && t.dataset.k;
  const cmd = ev.metaKey || ev.ctrlKey;
  // A1: Tab walks the editor from top to bottom and never leaves it
  if (ev.key === 'Tab' && t.closest && t.closest('.right .pd, .right .pfoot')) {
    ev.preventDefault();
    if (inField && (k === 'stime' || k === 'etime')) commitTime(t);
    if (A.pop) { A.pop = null; document.querySelectorAll('.desk > .pop').forEach(p => p.remove()); }
    const stops = tabStops(); if (!stops.length) return;
    let i = stops.indexOf(document.activeElement);
    if (i < 0 && k) i = stops.findIndex(s2 => (s2.dataset.k || s2.dataset.k2) === k);
    stops[(i + (ev.shiftKey ? -1 : 1) + stops.length) % stops.length].focus();
    tabNumbers(); if (window.railFocus) railFocus();
    return;
  }
  if (cmd && ev.key.toLowerCase() === 'k' && !ev.ctrlKey) { ev.preventDefault(); if (A.modal === 'cmd') ACT.closeModal(); else ACT.cmd(); render(); return; }
  if (ev.metaKey && ev.ctrlKey && ev.key.toLowerCase() === 'k') { ev.preventDefault(); ACT.togMenubar(); render(); return; }
  if (ev.metaKey && ev.ctrlKey && ev.key.toLowerCase() === 's') { ev.preventDefault(); ACT.togLeft(); render(); return; }
  if (ev.metaKey && ev.altKey && (ev.key.toLowerCase() === 'i' || ev.code === 'KeyI')) { ev.preventDefault(); ACT.togRight(); render(); return; }
  if (cmd && ev.key.toLowerCase() === 'j') { ev.preventDefault(); ACT.joinNext(); render(); return; }
  if (cmd && ev.key.toLowerCase() === 'z' && !inField) { ev.preventDefault(); ACT.undo(); render(); return; }
  if (cmd && ev.key === ',') { ev.preventDefault(); ACT.openSettings({ dataset: {} }); render(); return; }
  if (cmd && ev.key.toLowerCase() === 'n' && (A.mb || A.qadd)) { ev.preventDefault(); ACT.mbNew(); render(); return; }
  if (cmd && ev.key === 'Enter') {
    ev.preventDefault();
    if (A.modal === 'cmd') { const rows = cmdList().filter(r => !r.sec); if (rows.some(r => r.all)) { ACT.showAllResults(); render(); } return; }
    const e = selEv(); if (e && pending(e)) { ACT.sendUpdate({ dataset: {} }); render(); } return;
  }
  if (ev.key === 'Escape') {
    if (A.qadd) { A.qadd = false; render(); return; }
    if (A.mb) { A.mb = false; render(); return; }
    if (A.modal) { ACT.closeModal(); render(); return; }
    if (A.pop) { A.pop = null; render(); return; }
    if (k === 'search') { if (A.q.search) ACT.clearSearch(); else t.blur(); render(); return; }
    if (inField) { t.blur(); return; }
    if (A.sel) { deselect(); render(); return; }
    if (window.fsExit && window.fsExit()) return;
    return;
  }
  // popover lists: arrows and return
  if ((k === 'guest' || k === 'loc') && ['ArrowDown', 'ArrowUp', 'Enter'].includes(ev.key)) {
    const items = [...document.querySelectorAll('.pop .it')];
    if (ev.key === 'Enter') { ev.preventDefault(); const it = items[A.hi || 0]; if (it) { it.click(); } else if (k === 'loc') { A.pop = null; render(); } return; }
    ev.preventDefault(); A.hi = Math.max(0, Math.min(items.length - 1, (A.hi || 0) + (ev.key === 'ArrowDown' ? 1 : -1))); render(); return;
  }
  if (k === 'cmd' && ['ArrowDown', 'ArrowUp', 'Enter'].includes(ev.key)) {
    ev.preventDefault(); const items = [...document.querySelectorAll('.cmd .it')];
    if (ev.key === 'Enter') { const it = items[A.cmdHi]; if (it) it.click(); return; }
    A.cmdHi = Math.max(0, Math.min(items.length - 1, A.cmdHi + (ev.key === 'ArrowDown' ? 1 : -1))); render(); return;
  }
  if (k === 'search' && ev.key === 'Enter') { const r = A.search.res; const first = r && (r.up[0] || r.early[0]); if (first) { ACT.openResult({ dataset: { id: first.e.id } }); render(); } return; }
  if (k === 'qadd' && ev.key === 'Enter') { ACT.qaddOk(); render(); return; }
  if (k === 'link' && ev.key === 'Enter') { ev.preventDefault(); acceptLink(); return; }
  if (k === 'title' && ev.key === 'Enter') { const e = selEv(); if (e && e.draft) { ACT.commitDraft(); render(); } else t.blur(); return; }
  if ((k === 'stime' || k === 'etime') && ev.key === 'Enter') { ev.preventDefault(); commitTime(t); return; }
  if (inField) return;
  if (ev.key === 'Enter' && t.matches('.pd button, .pd [data-k]')) return; // native button press
  const key = ev.key.toLowerCase();
  if (ev.altKey || cmd) return;
  const map = { t: 'goToday', c: 'newEvent', d: 'viewDay', w: 'viewWeek', m: 'viewMonth', '?': 'shortcuts', '/': 'focusSearch', '`': 'togLeft' };
  if (key === 'f' && window.fsToggle && !inField) { ev.preventDefault(); fsToggle(); return; } // round e: full screen
  if (key === 'j' || key === 'arrowright') { ACT.step({ dataset: { k: 1 } }); render(); return; }
  if (key === 'k' || key === 'arrowleft') { ACT.step({ dataset: { k: -1 } }); render(); return; }
  if ((key === 'backspace' || key === 'delete') && A.sel) { ev.preventDefault(); ACT.del(); render(); return; }
  if (map[ev.key] || map[key]) { ev.preventDefault(); ACT[map[ev.key] || map[key]]({ dataset: {} }); render(); }
}

function bootApp() {
  A = fresh();
  if (V.appear) A.settings.appearance = V.appear;
  const host = document.getElementById('host');
  document.addEventListener('click', onClick);
  host.addEventListener('mousedown', onMouseDown);
  document.addEventListener('mousemove', onMouseMove);
  document.addEventListener('mouseup', onMouseUp);
  host.addEventListener('dblclick', onDblClick);
  host.addEventListener('input', onInput);
  host.addEventListener('focusin', onFocusIn);
  host.addEventListener('focusout', onFocusOut);
  document.addEventListener('keydown', onKey);
  window.addEventListener('resize', () => { fit(); place(); tabNumbers(); });
}
