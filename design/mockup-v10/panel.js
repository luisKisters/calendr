// Calendr v10 (from v8): editor, popovers, search, command menu, settings, menu bar, render.
'use strict';

// ================================================================ notes: fold call invitation text (B5)
function splitNotes(t) {
  t = t || '';
  const fences = [...t.matchAll(/-::~[~:]*::-/g)];
  if (fences.length < 2) return { user: t.trim(), boiler: '', kind: null };
  const a = fences[0].index, b = fences[1].index + fences[1][0].length;
  const boiler = t.slice(a, b), user = (t.slice(0, a) + t.slice(b)).trim();
  const kind = /zoom\.us/.test(boiler) ? 'zoom' : /meet\.google/.test(boiler) ? 'meet' : /teams\./.test(boiler) ? 'teams' : 'link';
  return { user, boiler, kind };
}
const userNotes = t => splitNotes(t).user;
// A4: what kind of link was pasted
function detectLink(v) {
  const s = (v || '').trim().toLowerCase();
  if (!s) return null;
  if (/zoom\.us\/(j|my|w)\//.test(s)) return { kind: 'zoom', ok: true };
  if (/meet\.google\.com\/[a-z]{3}-[a-z]{4}-[a-z]{3}/.test(s)) return { kind: 'meet', ok: true };
  if (/teams\.(microsoft|live)\.com\//.test(s)) return { kind: 'teams', ok: true };
  if (/webex\.com\//.test(s)) return { kind: 'webex', ok: true };
  if (/^(https?:\/\/)?[\w-]+(\.[\w-]+)+\/?\S*$/.test(s)) return { kind: 'link', ok: true };
  return { kind: null, ok: false };
}

// ================================================================ editor (right column)
const REPEAT_OPTS = e => {
  const w = WDS[dow(e.d)], n = dnum(e.d), nth = Math.ceil(n / 7), ord = ['first', 'second', 'third', 'fourth', 'last'][nth - 1];
  return ['Does not repeat', 'Every day', 'Every weekday (Mon–Fri)', `Every week on ${w}`, `Every 2 weeks on ${w}`, `Every month on the ${n}${n === 1 ? 'st' : n === 2 ? 'nd' : n === 3 ? 'rd' : 'th'}`, `Every month on the ${ord} ${WDL[dow(e.d)]}`, `Every year on ${n} ${MONS[dmon(e.d)]}`];
};
const remLabel = r => r === 0 ? 'At start' : r < 60 ? `${r} min` : r < 1440 ? `${r / 60} hour${r > 60 ? 's' : ''}` : `${r / 1440} day${r > 1440 ? 's' : ''}`;
const prow = (icon, html, cls = '', attrs = '') => `<div class="prow ${cls}" ${attrs}>${ic(icon)}<div class="pc">${html}</div></div>`;
// guest replies: status tokens
const RESPMARK = { yes: ['check', 'var(--ok)', 'Going'], maybe: ['q', 'var(--warn)', 'Maybe'], no: ['x', 'var(--danger)', 'Declined'], none: ['clock', 'var(--fg3)', 'Awaiting'] };
function guestRow(e, g, canEdit) {
  const [icn, col] = RESPMARK[g.resp] || RESPMARK.none, p = person(g.id);
  const role = [g.org ? 'organizer' : '', g.id === 'me' ? 'you' : '', g.opt ? 'optional' : ''].filter(Boolean).join(' · ');
  return `<div class="gr" title="${esc(p.email)} · ${RESPMARK[g.resp][2]}"><span class="rm" style="color:${col}">${ic(icn, 13, 'stroke-width="1.8"')}</span><span class="nm1"><b>${esc(g.id === 'me' ? p.email : (p.name || p.email))}</b>${role ? `<span class="role">${role}</span>` : ''}</span>
    <span class="acts"><button class="ibtn sm" data-a="mailOne" data-i="${g.id}" title="Email ${esc(p.name || p.email)}">${ic('mail', 13)}</button>${canEdit && g.id !== 'me' ? `<button class="ibtn sm" data-a="rmGuest" data-i="${g.id}" title="Remove">${ic('x', 13)}</button>` : ''}</span></div>`;
}
function detail(e) {
  const canEdit = (e.organizer || e.draft) && !calOf(e).ro;
  const sn = splitNotes(e.notes), oth = others(e);
  let h = `<div class="pd" style="${evVars(colorOf(e))}">`;
  h += `<div class="pd-top"><span class="bar"></span><input class="title" data-k="title" value="${esc(e.t)}" placeholder="${e.draft ? 'New event' : '(No title)'}" ${canEdit ? '' : 'readonly'} autocomplete="off">
    ${e.draft ? '' : `<button class="ibtn" data-a="del" title="Delete event  ⌫">${ic('trash')}</button>`}<button class="ibtn" data-a="close" title="Close  esc">${ic('x')}</button></div>`;
  // when (B7 / F3)
  const endShown = e.ed, multi = endDay(e) > e.d;
  const sdate = `<button class="df tab" data-k="sdate" data-pop="date" data-i="s" title="Start date">${fmtDayY(e.d)}</button>`;
  const edate = `<button class="df tab" data-k="edate" data-pop="date" data-i="e" title="End date" ${!multi && !e.allDay ? 'style="color:var(--fg3)"' : ''}>${fmtDayY(endShown)}</button>`;
  const stime = `<input class="tf tab" data-k="stime" value="${fmt(e.s)}" title="Start time" autocomplete="off">`;
  const etime = `<input class="tf tab" data-k="etime" value="${fmt(e.e)}" title="End time" autocomplete="off">`;
  const len = e.allDay ? `${e.ed - e.d + 1} day${e.ed > e.d ? 's' : ''}` : dur(durOf(e));
  const arrow = `<span class="ar">${ic('arrow', 13)}</span>`;
  // decided (B7): times on one line, dates under them
  const when0 = e.allDay ? `<div class="when2">${sdate}${arrow}${edate}<span class="dur tab">${len}</span></div>`
    : `<div class="when2">${stime}${arrow}${etime}<span class="dur tab">${len}</span>${sdate}<span></span>${edate}<span></span></div>`;
  let when = when0;
  when += `<div class="subrow"><button class="sw ${e.allDay ? 'on' : ''}" data-k="allday" data-a="allDay"><i></i>All day</button>${multi && !e.allDay ? `<span class="sub" style="color:var(--fg3);font-size:var(--fs-s)">Shows in the top lane</span>` : ''}</div>`;
  h += prow('clock', when);
  h += prow('repeat', `<button class="fld ${e.repeat ? '' : 'ph'}" data-k="repeat" data-pop="repeat">${esc(e.repeat || 'Does not repeat')}</button>`);
  // participants (B1, B3)
  let ph = '';
  if (oth.length) {
    const t = { yes: 0, maybe: 0, no: 0, none: 0 }; e.guests.forEach(g => t[g.resp] = (t[g.resp] || 0) + 1);
    const tally = [t.yes && `${t.yes} yes`, t.maybe && `${t.maybe} maybe`, t.no && `${t.no} no`, t.none && `${t.none} awaiting`].filter(Boolean).join(', ');
    ph += `<div class="gsum"><div class="tx"><b>${e.guests.length} participants</b><span>${tally}</span></div><button class="ibtn sm ${isOpen('guestmore') ? 'on' : ''}" data-k="guestmore" data-pop="guestmore" title="Guest actions: email guests, copy addresses">${ic('more', 14)}</button></div>`;
    ph += `<div class="gl">${e.guests.map(g => guestRow(e, g, canEdit && google())).join('')}</div>`;
  }
  if (canEdit) {
    if (google()) ph += `<input class="in" data-k="guest" placeholder="${oth.length ? 'Add guests' : 'Add participants'}" value="${esc(A.q.guest)}" autocomplete="off" ${oth.length ? 'style="margin-top:2px"' : ''}>`;
    else {
      ph += `<button class="fld ph" data-k="guest" data-a="guestHint" ${oth.length ? 'style="margin-top:2px"' : ''}>${oth.length ? 'Add guests' : 'Add participants'}</button>`;
      if (A.guestHint) ph += `<div class="hintrow">${ic('lock', 13)}<span>macOS Calendar cannot add guests or send invitations. Connect Google to invite people from Calendr.</span><div class="acts"><button class="btn sm act" data-a="connect">${gLogo(13)} Connect Google</button><button class="btn sm" data-a="mailGuests" data-id="${e.id}">Email instead</button><button class="btn sm ghost" data-a="openCal">Open in Calendar</button></div></div>`;
    }
  }
  if (ph) h += prow('users', ph);
  // my reply (E1)
  const r = myResp(e);
  if (r) {
    const g = google() && isGoogleCal(e);
    h += prow('reply', `<div class="going"><span class="lbl">Going?</span><div class="segc ${g ? '' : 'off'}" title="${g ? 'Your reply' : 'Connect Google to reply'}">${['yes', 'maybe', 'no'].map((k, i) => `<button class="${r === k ? 'on' : ''}" data-a="rsvp" data-k="${k}" ${i === 0 ? 'data-k2="going"' : ''} ${g ? '' : 'aria-disabled="true"'}>${{ yes: 'Yes', maybe: 'Maybe', no: 'No' }[k]}</button>`).join('')}</div></div>
      ${g ? '' : `<div class="hintrow" style="flex-direction:row;align-items:center;gap:8px;background:none;padding:6px 8px 0;">${ic('lock', 13)}<span style="flex:1">Replies need Google.</span><button class="btn sm" data-a="connect">Connect Google to reply</button></div><div style="margin:4px 0 0"><button class="btn sm ghost" style="margin-left:-10px" data-a="openGcal">${ic('open', 13)} Open in Google Calendar</button></div>`}`);
  }
  // conferencing (A4 / F4 / F2; G, 5 Nov). An existing link is the call row: service, the link as plain text, Join (the only way to open it),
  // copy and remove. No call: "Add conferencing" opens a paste field (detects Zoom / Teams / Meet / Webex); under it, separately,
  // "Create Google Meet" (Google connected, Google calendar) or why it is not available, with Connect.
  let ch = '';
  if (e.call && e.call.pending) ch = `<div class="callrow pending">${meetLogo(15)}<span class="cn">Google Meet link is made when you save…</span></div>`;
  else if (e.call) ch = `<div class="callrow"><span class="lg">${callLogo(e.call, 15)}</span><span class="cn"><b>${CALLNAME[e.call.kind]}</b><span class="url tab" title="${esc(e.call.url)}">${esc(e.call.url)}</span></span>
      <span class="ca"><button class="ibtn sm" data-a="copyLink" title="Copy link">${ic('copy', 13)}</button>${canEdit ? `<button class="ibtn sm" data-a="rmCall" title="Remove call">${ic('x', 13)}</button>` : ''}</span>
      <button class="joinsm" data-k="join" data-a="join" data-id="${e.id}">Join <span class="kh">⌘J</span></button></div>`;
  else if (!canEdit) ch = `<span class="ph">No call</span>`;
  else if (!A.confOpen) ch = `<button class="fld ph" data-k="conf" data-a="confOpen">Add conferencing</button>`;
  else {
    const det = detectLink(A.q.link);
    const field = `<label class="boxf">${det && det.kind ? callLogo({ kind: det.kind }, 15) : ic('link', 15)}<input data-k="link" placeholder="Paste link (Zoom, Teams, Meet…)" value="${esc(A.q.link)}" autocomplete="off">${det ? `<span class="det">${det.ok ? (det.kind === 'link' ? 'Link' : CALLNAME[det.kind]) + ' · ↩' : 'Not a link yet'}</span>` : ''}</label>`;
    const gcal = isGoogleCal(e);
    const meet = google() && gcal
      ? `<button class="confopt" data-k="meet" data-a="makeMeet">${meetLogo(15)}<span>Create Google Meet</span></button>`
      : `<div class="confnote">${meetLogo(15)}<span>${!gcal ? 'Google Meet links can only be added to events in a Google calendar.' : 'Creating a Google Meet link needs your Google account.'}</span>${gcal ? `<button class="btn sm" data-k="meet" data-a="connect">Connect Google</button>` : ''}</div>`;
    ch = `<div class="confacts">${field}<div class="confor">or</div>${meet}</div>`;
  }
  h += prow('video', ch);
  // location (B6; F, 5 Nov): empty = "Add location" field with suggestions while typing. A set place is text: hover underlines it,
  // a click opens it in the default maps app (first time: ask once, "Remember"); a copy icon beside it; the pencil edits it.
  if (e.location && !A.locEdit) {
    h += prow('pin', `<div class="locset"><button class="loclink" data-k="locopen" data-a="openMap" data-id="${e.id}" title="Open in ${A.settings.maps === 'ask' ? 'maps' : MAPAPPS[A.settings.maps][0]}">${esc(e.location)}</button>
      <span class="la"><button class="ibtn sm" data-a="copyLoc" title="Copy address">${ic('copy', 13)}</button>${canEdit ? `<button class="ibtn sm edit" data-k="locedit" data-a="editLoc" title="Edit location">${ic('pencil', 13)}</button>` : ''}</span></div>`, `locrow ${A.locHot ? 'hot' : ''}`);
  } else {
    h += prow('pin', `<input class="in" data-k="loc" value="${esc(e.location)}" placeholder="Add location" ${canEdit ? '' : 'readonly'} autocomplete="off">`, 'locrow');
  }
  // notes (B5)
  // B5 (decided): the call invitation text is stripped silently; the Join button has the link
  const nh = `<textarea class="notes" data-k="notes" rows="1" placeholder="Add notes" ${canEdit ? '' : 'readonly'}>${esc(sn.user)}</textarea>`;
  h += prow('notes', nh);
  // calendar, busy, visibility, reminders
  h += prow('calendar', `<button class="calsel" data-k="cal" data-pop="cal" ${calOf(e).ro ? 'disabled' : ''}><span class="d"></span><span class="n">${esc(calOf(e).name)} <span style="color:var(--fg3)">· ${GROUPS.find(g => g.id === calOf(e).g).name}</span></span>${ic('down', 12)}</button>
    <div class="pair"><button data-k="busy" data-pop="busy">${e.busy} ${ic('down', 12)}</button><button data-k="vis" data-pop="vis">${e.vis} ${ic('down', 12)}</button></div>`);
  h += prow('bell', `${e.reminders.map((r, i) => `<div class="rem"><span>${remLabel(r)} <span class="u">${r === 0 ? '' : 'before'}</span></span><button class="ibtn sm" data-k="rem${i}" data-a="rmRem" data-i="${i}" title="Remove reminder">${ic('x', 12)}</button></div>`).join('')}
    <button class="fld ph" data-k="addrem" data-pop="rem">Add reminder</button>`);
  h += '</div>';
  // footer
  let foot = '';
  if (e.draft) foot = `<div class="pfoot"><button class="btn ghost" data-a="close">Cancel</button><button class="btn act" data-a="commitDraft">Create event <span class="kh">↩</span></button></div>`;
  else if (pending(e)) foot = `<div class="pfoot"><span class="note">${oth.length} guest${oth.length > 1 ? 's' : ''} see the old version</span><button class="btn ghost" data-a="discard">Discard</button><button class="btn" data-a="sendUpdate" data-k="quiet">Save only</button><button class="btn act" data-a="sendUpdate">Send update <span class="kh">⌘↩</span></button></div>`;
  return { body: h, foot };
}
const SHARED = ['t', 'd', 's', 'ed', 'e', 'allDay', 'repeat', 'guests', 'call', 'location', 'notes'];
const sharedOf = e => JSON.stringify(SHARED.map(k => e[k]));
const pending = e => { const b = A.base[e.id]; return !!b && google() && !e.draft && e.organizer && sharedOf(b) !== sharedOf(e) && (others(b).length > 0 || others(e).length > 0); };
// ================================================================ search (D1-D6)
const SEARCH_FLOOR = () => Math.min(...A.events.map(e => e.d));
function searchHits(q, scoped = true) {
  const words = q.toLowerCase().split(/\s+/).filter(Boolean); if (!words.length) return { up: [], early: [] };
  const from = A.search.warm || !scoped ? A.search.from : TODAY - 14, to = A.search.warm || !scoped ? A.search.to : TODAY + 14;
  const res = [];
  A.events.forEach(e => {
    if (e.draft || !visible(e) || e.d < from || e.d > to) return;
    const base = [e.t, e.location, userNotes(e.notes), calOf(e).name].join(' ').toLowerCase();
    const gs = e.guests.map(g => ({ id: g.id, s: (nameOf(g.id) + ' ' + person(g.id).email).toLowerCase() }));
    if (!words.every(w => base.includes(w) || gs.some(x => x.s.includes(w)))) return;
    const via = words.every(w => base.includes(w)) ? null : gs.find(x => words.some(w => !base.includes(w) && x.s.includes(w)));
    res.push({ e, via: via ? via.id : null });
  });
  const key = e => e.d * 1440 + e.s, nowK = TODAY * 1440 + NOW;
  const up = res.filter(r => endDay(r.e) * 1440 + (r.e.allDay ? 1440 : r.e.e) >= nowK).sort((a, b) => key(a.e) - key(b.e));
  const early = res.filter(r => !up.includes(r)).sort((a, b) => key(b.e) - key(a.e));
  return { up, early };
}
function runSearch(immediate) {
  clearTimeout(A.search.timer);
  const q = A.q.search.trim();
  if (!q) { A.search.phase = 'idle'; A.search.res = null; return; }
  const go = () => {
    if (!A.search.warm) {
      // D3: the first search runs while the calendars still load; it shows what it has and refreshes by itself
      A.search.phase = 'warming'; A.search.res = searchHits(q); render();
      A.search.timer = setTimeout(() => { A.search.warm = true; A.search.phase = 'ready'; A.search.res = searchHits(A.q.search.trim()); render(); }, 900);
      return;
    }
    A.search.phase = 'ready'; A.search.res = searchHits(q); render();
  };
  // D4: typing is never blocked; the search runs 150 ms after the last key
  if (immediate) go(); else { A.search.phase = A.search.res ? 'typing' : 'searching'; A.search.timer = setTimeout(go, 150); }
}
function resultRow(r, q) {
  const e = r.e, st = myResp(e) && myResp(e) !== 'yes' ? `st-${myResp(e)}` : '';
  const sub = r.via ? `Guest: ${esc(nameOf(r.via))}` : '';
  return `<button class="later ${sub ? 'two' : ''} ${st}" data-a="openResult" data-id="${e.id}" style="${evVars(colorOf(e))}"><span class="tm tab">${e.allDay ? 'all day' : fmt(e.s)}</span><span class="b"></span><span class="ttl">${hl(e.t, q)}${sub ? `<span class="sub">${hl(sub, q)}</span>` : ''}</span></button>`;
}
function groupByDay(list, q) {
  let out = '', last = null;
  list.forEach(r => { if (r.e.d !== last) { last = r.e.d; out += `<div class="sh">${r.e.d === TODAY ? 'Today · ' : r.e.d === TODAY + 1 ? 'Tomorrow · ' : ''}${fmtDayY(r.e.d)}</div>`; } out += resultRow(r, q); });
  return out;
}
function searchCol() {
  const q = A.q.search.trim(), S = A.search, res = S.res || { up: [], early: [] };
  const total = res.up.length + res.early.length;
  const floor = SEARCH_FLOOR(), exhausted = S.from <= floor;
  // D5 (locked): earlier results above "Upcoming", oldest at the top; the list opens scrolled to "Upcoming".
  // "Earlier" and "Upcoming" are sticky section headers; "Load earlier results" sits at the top of "Earlier".
  const more = (arr, key) => arr.length > S[key] ? `<div style="padding:8px 8px 0"><button class="btn sm ghost" data-a="showMore" data-k="${key}">Show ${Math.min(40, arr.length - S[key])} more · ${arr.length - S[key]} left</button></div>` : '';
  const range = `${fmtMonY(S.from)} – ${fmtMonY(S.to)}`;
  const busy = S.phase === 'warming' || S.phase === 'searching' || S.phase === 'more';
  let topRow;
  if (busy) topRow = `<div class="srow2"><span class="spin"></span>${S.phase === 'warming' ? 'Searching… calendars are still loading' : S.phase === 'more' ? `Searching ${fmtMonY(S.from - 183)} – ${fmtMonY(S.from)}…` : 'Searching…'}</div>`;
  else if (res.early.length > S.shownE) topRow = `<button class="srow2 act" data-a="showMore" data-k="shownE">${ic('history', 14)} Load earlier results <span class="tab">${res.early.length - S.shownE} more</span></button>`;
  else if (!exhausted) topRow = `<button class="srow2 act" data-a="searchEarlier">${ic('history', 14)} Load earlier results <span class="tab">before ${fmtMonY(S.from)}</span></button>`;
  else topRow = `<div class="srow2">${ic('check', 13)} Searched everything back to ${fmtMonY(floor)}</div>`;
  const early = res.early.slice(0, S.shownE).reverse();
  const earlySec = `<section class="ssec"><div class="sec">Earlier${res.early.length ? ` <span class="tab">${res.early.length}</span>` : ''}</div>${topRow}${groupByDay(early, q)}</section>`;
  const upSec = `<section class="ssec up" id="upanchor"><div class="sec">Upcoming <span class="tab">${res.up.length}</span></div>${res.up.length ? groupByDay(res.up.slice(0, S.shown), q) + more(res.up, 'shown') : '<div class="empty" style="padding:6px 20px">Nothing upcoming.</div>'}</section>`;
  const empty = !total && !busy ? `<div class="empty">No events match “${esc(q)}” in ${range}.</div>` : '';
  return `<div class="sres">${empty}${earlySec}${upSec}</div>`;
}

// ================================================================ popovers
function popHTML() {
  if (!A.pop) return '';
  const k = A.pop.k, e = selEv();
  const wrap = (html, anchor, extra = '', cls = '') => `<div class="pop ${cls}" data-anchor='${anchor}' ${extra}>${html}</div>`;
  const item = (label, act, attrs = '', on = false, sub = '', end = '') => `<button class="it" data-a="${act}" ${attrs}><span class="ck">${on ? ic('check', 14) : ''}</span><span style="flex:1;min-width:0">${label}${sub ? `<span class="sub2">${sub}</span>` : ''}</span>${end ? `<span class="end">${end}</span>` : ''}</button>`;
  if (k === 'repeat' && e) {
    return wrap(REPEAT_OPTS(e).map(o => item(esc(o), 'setRepeat', `data-v="${esc(o)}"`, (e.repeat || 'Does not repeat') === o)).join('') + '<div class="sep"></div>' + item('Custom…', 'customRepeat', '', false, 'Every N days, weeks, months; ends on a date'), '[data-k="repeat"]', 'style="width:280px"');
  }
  if (k === 'custom' && e) {
    const c = A.custom || (A.custom = { n: 1, unit: 'week', days: [dow(e.d)], ends: 'never' });
    return wrap(`<div class="custom"><b>Custom repeat</b>
      <div class="r">Every <input class="num tab" data-k="cnum" value="${c.n}"> <div class="segc">${['day', 'week', 'month', 'year'].map(u => `<button class="${c.unit === u ? 'on' : ''}" data-a="cunit" data-k="${u}">${u}${c.n > 1 ? 's' : ''}</button>`).join('')}</div></div>
      ${c.unit === 'week' ? `<div class="r">On <div class="days7">${['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((w, i) => `<button class="${c.days.includes(i) ? 'on' : ''}" data-a="cday" data-i="${i}">${w}</button>`).join('')}</div></div>` : ''}
      <div class="r">Ends <div class="segc">${[['never', 'Never'], ['date', 'On 31 Dec'], ['count', 'After 10']].map(([v, l]) => `<button class="${c.ends === v ? 'on' : ''}" data-a="cends" data-k="${v}">${l}</button>`).join('')}</div></div>
      <div class="r" style="justify-content:flex-end"><button class="btn sm ghost" data-a="closePop">Cancel</button><button class="btn sm act" data-a="applyCustom">Done</button></div></div>`, '[data-k="repeat"]');
  }
  if (k === 'maps') {
    // F: the first click on a location (no default yet) asks once
    const ev = get(A.pop.id) || e; if (!ev) return '';
    return wrap(`<div class="sec">Open “${esc(ev.location.split(',')[0])}” in</div>` + Object.entries(MAPAPPS).map(([id, [n, logo]]) => `<button class="it" data-a="pickMaps" data-k="${id}" data-id="${ev.id}"><span class="mlogo">${logo(15)}</span><span style="flex:1">${n}</span></button>`).join('') +
      `<div class="sep"></div><button class="it remember" data-a="togRemember"><span class="ck">${A.mapsRemember ? ic('check', 14) : ''}</span><span style="flex:1">Remember my choice<span class="sub2">Change it in Settings → General</span></span></button>`, A.pop.anchor || '[data-k="locopen"]', 'style="width:250px"');
  }
  if (k === 'guestmore' && e) {
    const n = others(e).length, open = e.guests.filter(g => g.resp === 'none' && g.id !== 'me').length;
    return wrap(item('Email guests', 'mailGuests', `data-id="${e.id}"`, false, `${n} people`) + item('Email guests who have not replied', 'mailGuests', `data-id="${e.id}" data-k="open"`, false, open ? `${open} people` : 'everyone replied') +
      '<div class="sep"></div>' + item('Copy email addresses', 'copyEmails', '', false, others(e).map(g => person(g.id).email).slice(0, 2).join(', ') + (n > 2 ? ', …' : '')) + item('Copy names and emails', 'copyEmails', 'data-k="names"') +
      '<div class="sep"></div>' + item('Open in Google Calendar', 'openGcal', '', false, '', ic('open', 13)), '[data-k="guestmore"]', 'style="width:290px"');
  }
  if (k === 'guest' && e) {
    const q = A.q.guest.trim().toLowerCase(), have = e.guests.map(g => g.id);
    const list = Object.keys(PEOPLE).filter(id => id !== 'me' && !have.includes(id) && (!q || (PEOPLE[id].name + ' ' + PEOPLE[id].email).toLowerCase().includes(q))).slice(0, 6);
    const isMail = /^[^@\s]+@[^@\s]+\.[a-z]{2,}$/i.test(A.q.guest.trim());
    if (!list.length && !isMail) return '';
    return wrap(`<div class="sec">${q ? 'Contacts' : 'Suggested'}</div>` + list.map((id, i) => `<button class="it ${A.hi === i ? 'hi' : ''}" data-a="addGuest" data-i="${id}"><span class="av" style="background:${avc(id)}">${initials(id)}</span><span style="flex:1;min-width:0">${hl(PEOPLE[id].name || PEOPLE[id].email, A.q.guest.trim())}<span class="sub2">${hl(PEOPLE[id].email, A.q.guest.trim())}</span></span><span class="end">${PEOPLE[id].src}</span></button>`).join('') +
      (isMail && !list.length ? `<button class="it hi" data-a="addGuest" data-i="${esc(A.q.guest.trim())}"><span class="av" style="background:#6b6b70">@</span><span>Invite ${esc(A.q.guest.trim())}</span></button>` : ''), '[data-k="guest"]', 'style="width:290px"');
  }
  if (k === 'loc' && e) {
    const q = (e.location || '').trim(), ql = q.toLowerCase();
    if (!A.locTyped) return '';
    const list = (ql ? PLACES.filter(([n, a]) => (n + ' ' + a).toLowerCase().includes(ql)) : PLACES.slice(0, 4)).slice(0, 6);
    if (!list.length) return '';
    return wrap(`<div class="sec">${ql ? 'Places' : 'Recent places'}</div>` + list.map(([n, a], i) => `<button class="it ${A.hi === i ? 'hi' : ''}" data-a="pickPlace" data-v="${esc(n + ', ' + a)}"><span style="color:var(--fg3)">${ic('pin', 15)}</span><span style="flex:1;min-width:0">${hl(n, q)}<span class="sub2">${hl(a, q)}</span></span></button>`).join(''), '[data-k="loc"]', 'style="width:290px"');
  }
  if (k === 'cal' && e) {
    const groups = GROUPS.map(g => { const cs = Object.entries(A.cals).filter(([, c]) => c.g === g.id && !c.ro); return cs.length ? `<div class="sec">${g.name}</div>` + cs.map(([id, c]) => `<button class="it" data-a="setCal" data-k="${id}"><span class="ck">${e.cal === id ? ic('check', 14) : ''}</span><span style="width:10px;height:10px;border-radius:3px;background:${c.hex};flex:none"></span><span>${esc(c.name)}</span></button>`).join('') : ''; }).join('');
    return wrap(groups + `<div class="sep"></div><div class="sec">Event colour</div><div class="sw12">${SWATCHES.map(([hex, n]) => `<button class="${(e.color || '') === hex ? 'on' : ''}" style="background:${hex}" data-a="setColor" data-k="${hex}" title="${n}"></button>`).join('')}</div>`, '[data-k="cal"]', 'style="width:236px"');
  }
  if (k === 'busy' && e) return wrap(['Busy', 'Free'].map(o => item(o, 'setBusy', `data-v="${o}"`, e.busy === o)).join(''), '[data-k="busy"]', 'style="width:160px"');
  if (k === 'vis' && e) return wrap(['Default visibility', 'Public', 'Private'].map(o => item(o, 'setVis', `data-v="${o}"`, e.vis === o)).join(''), '[data-k="vis"]', 'style="width:200px"');
  if (k === 'rem' && e) return wrap([0, 5, 10, 15, 30, 60, 1440].map(r => item(r === 0 ? 'At start' : remLabel(r) + ' before', 'addRem', `data-v="${r}"`, e.reminders.includes(r))).join(''), '[data-k="addrem"]', 'style="width:190px"');
  if (k === 'time' && e) {
    const which = A.pop.i, cur = which === 's' ? e.s : e.e, base = which === 'e' && e.ed === e.d ? e.s : null;
    const opts = []; for (let t = Math.max(0, cur - 120); t <= Math.min(1425, cur + 180); t += 15) opts.push(t);
    return wrap(opts.map(t => item(`<span class="tab">${fmt(t)}</span>`, 'pickTime', `data-i="${which}" data-v="${t}"`, t === cur, '', base != null && t > base ? dur(t - base) : '')).join(''), `[data-k="${which === 's' ? 'stime' : 'etime'}"]`, 'style="width:170px;max-height:260px"');
  }
  if (k === 'date' && e) {
    const which = A.pop.i, cur = which === 's' ? e.d : e.ed;
    const b = dd(cur + (A.pop.off || 0) * 31); const first = di(b.getUTCFullYear(), b.getUTCMonth() + 1, 1), ws = weekStart(first), md = dmon(first);
    let cells = WDS.map(w => `<span>${w[0]}</span>`).join('');
    for (let i = 0; i < 42; i++) { const d = ws + i; cells += `<button class="tab ${dmon(d) !== md ? 'o' : ''} ${d === cur ? 'on' : ''} ${d > e.d && d < e.ed ? 'rng' : ''}" data-a="pickDate" data-i="${which}" data-d="${d}">${dnum(d)}</button>`; }
    return wrap(`<div class="minical"><div class="mh2"><span>${which === 's' ? 'Starts' : 'Ends'} · ${MONL[md]} ${dyear(first)}</span><span><button class="ibtn sm" data-a="calOff" data-k="-1">${ic('left', 13)}</button><button class="ibtn sm" data-a="calOff" data-k="1">${ic('right', 13)}</button></span></div><div class="g7">${cells}</div></div>`, `[data-k="${which === 's' ? 'sdate' : 'edate'}"]`);
  }
  return '';
}

// ================================================================ command menu, settings, dialogs
function commands() {
  const j = joinTarget();
  return [
    ['New event', 'plus', ['C'], 'newEvent'], ['Go to today', 'calendar', ['T'], 'goToday'],
    ...(j ? [[`Join ${j.t} (${CALLNAME[j.call.kind]})`, 'video', ['⌘', 'J'], 'joinNext']] : []),
    ['Search events', 'search', ['/'], 'focusSearch'], ['Day view', 'calendar', ['D'], 'viewDay'], ['Week view', 'calendar', ['W'], 'viewWeek'], ['Month view', 'calendar', ['M'], 'viewMonth'],
    ['Toggle sidebar', 'sideL', ['⌃', '⌘', 'S'], 'togLeft'], ['Toggle right column', 'sideR', ['⌥', '⌘', 'I'], 'togRight'],
    [`${A.settings.declined ? 'Hide' : 'Show'} declined events`, 'x', [], 'togDeclined'], [`${A.settings.weekNo ? 'Hide' : 'Show'} week numbers`, 'calendar', [], 'togWeekNo'],
    [`Appearance: ${isLight() ? 'Dark' : 'Paper'}`, isLight() ? 'moon' : 'sun', [], 'togAppearance'],
    ['Menu bar calendar', 'menubar', ['⌃', '⌘', 'K'], 'togMenubar'], ['Settings', 'gear', ['⌘', ','], 'openSettings'], ['Keyboard shortcuts', 'keyboard', ['?'], 'shortcuts'],
  ];
}
function cmdList() {
  const q = A.q.cmd.trim().toLowerCase();
  const cs = commands().filter(c => !q || c[0].toLowerCase().includes(q));
  let ev = null;
  if (q.length >= 2) { const r = searchHits(q, false); ev = [...r.up, ...r.early]; }
  const rows = [];
  if (cs.length) { rows.push({ sec: 'Commands' }); cs.slice(0, q ? 5 : 20).forEach(c => rows.push({ c })); }
  if (ev) { rows.push({ sec: 'Events', n: ev.length }); ev.slice(0, 5).forEach(r => rows.push({ r })); if (ev.length > 5) rows.push({ all: ev.length }); }
  return rows;
}
function cmdHTML() {
  const rows = cmdList(); let i = -1;
  const q = A.q.cmd.trim();
  const body = rows.map(row => {
    if (row.sec) return `<div class="sec"><span>${row.sec}</span>${row.n != null ? `<span class="tab" style="font-weight:400">${row.n} found</span>` : ''}</div>`;
    i++;
    const hi = i === A.cmdHi ? 'hi' : '';
    if (row.c) return `<button class="it ${hi}" data-a="runCmd" data-k="${row.c[3]}">${ic(row.c[1])}<span>${esc(row.c[0])}</span><span class="end">${row.c[2].length ? kb(...row.c[2]) : ''}</span></button>`;
    if (row.r) { const e = row.r.e; return `<button class="it ${hi}" data-a="openResult" data-id="${e.id}" style="${evVars(colorOf(e))}"><span class="b"></span><span class="tm2 tab">${fmtDay(e.d)}${e.allDay ? '' : ' · ' + fmt(e.s)}</span><span class="tt">${hl(e.t, q)}${row.r.via ? ` <span style="color:var(--fg3)">· guest ${hl(nameOf(row.r.via), q)}</span>` : ''}</span></button>`; }
    return `<button class="it all ${hi}" data-a="showAllResults">${ic('search')}<span>Show all ${row.all} results in the sidebar</span><span class="end">${kb('⌘', '↩')}</span></button>`;
  }).join('');
  return `<div class="scrim" data-a="closeModal"></div><div class="modal cmd"><div class="q">${ic('search', 16)}<input data-k="cmd" placeholder="Type a command or search events…" value="${esc(A.q.cmd)}" autocomplete="off"><span class="kbd">esc</span></div><div class="list">${body || '<div class="empty">Nothing found.</div>'}</div></div>`;
}
const swt = (on, act, extra = '') => `<button class="sw ${on ? 'on' : ''}" data-a="${act}" ${extra}><i></i></button>`;
function settingsHTML() {
  const t = A.settingsTab;
  const nav = [['general', 'General', 'gear'], ['appearance', 'Appearance', 'palette'], ['calendars', 'Calendars', 'calendar'], ['accounts', 'Accounts', 'person'], ['menubar', 'Menu bar', 'menubar'], ['keys', 'Shortcuts', 'keyboard']];
  let c = '';
  if (t === 'general') c = `<h3>General</h3><p class="lede2">How the calendar grid looks and behaves.</p><div class="sbox">
    <div class="srow"><div class="grow">Week starts on</div><div class="segc">${['Mon', 'Sun'].map(v => `<button class="${A.settings.weekStart === v ? 'on' : ''}" data-a="setWeekStart" data-k="${v}">${v === 'Mon' ? 'Monday' : 'Sunday'}</button>`).join('')}</div></div>
    <div class="srow"><div class="grow">Show week numbers<small>In the mini month; point at the title to see this week's number.</small></div>${swt(A.settings.weekNo, 'togWeekNo')}</div>
    <div class="srow ${A.hlSetting === 'maps' ? 'hl2' : ''}"><div class="grow">Default maps app<small>A click on a location opens it here.</small></div><div class="segc">${[['ask', 'Ask'], ['apple', 'Apple Maps'], ['google', 'Google Maps'], ['osm', 'OpenStreetMap']].map(([v, l]) => `<button class="${A.settings.maps === v ? 'on' : ''}" data-a="setMaps" data-k="${v}">${l}</button>`).join('')}</div></div>
    <div class="srow ${A.hlSetting === 'declined' ? 'hl2' : ''}"><div class="grow">Show declined events<small>Declined invitations stay in the grid, faded and struck through. (C4)</small></div>${swt(A.settings.declined, 'togDeclined')}</div></div>`;
  if (t === 'appearance') c = `<h3>Appearance</h3><p class="lede2">Calendr has both themes: ${PK().darkName} and Paper (light). Auto follows macOS.</p><div class="sbox">
    <div class="srow"><div class="grow">Theme</div><div class="segc">${[['dark', 'Dark', 'moon'], ['paper', 'Paper', 'sun'], ['auto', 'Auto', 'palette']].map(([v, l, i]) => `<button class="${(A.settings.appearance === 'auto' ? 'auto' : isLight() ? 'paper' : 'dark') === v ? 'on' : ''}" data-a="setAppearance" data-k="${v}">${ic(i, 13)} ${l}</button>`).join('')}</div></div>
    <div class="srow"><div class="grow">App icon</div><span style="display:flex;gap:8px;align-items:center">${appIcon('nowline', 34)} Now line</span></div></div>`;
  if (t === 'calendars') c = `<h3>Calendars</h3><p class="lede2">Hidden calendars stay hidden in search and the menu bar too.</p>` + GROUPS.map(g => `<div class="sbox"><div class="srow"><div class="grow"><b>${g.name}</b><small>${esc(g.sub)}</small></div></div>${Object.entries(A.cals).filter(([, cc]) => cc.g === g.id).map(([id, cc]) => `<div class="srow"><span style="width:12px;height:12px;border-radius:3px;background:${cc.hex}"></span><div class="grow">${esc(cc.name)}${cc.ro ? '<small>read-only</small>' : ''}</div>${swt(!A.hidden.includes(id), 'togCal', `data-k="${id}"`)}</div>`).join('')}</div>`).join('');
  if (t === 'accounts') {
    const on = google();
    c = `<h3>Accounts</h3><p class="lede2">Apple Calendar stays the source: everything in macOS Calendar shows here, Google included. Connecting Google is optional. It adds only what Apple's calendar API cannot do. (E3)</p>
    <div class="sbox"><div class="srow"><span class="pv">${gLogo(15)}</span><div class="grow"><b>Google</b><small>${on ? `${ME} · connected · synced ${fmt(NOW - 1)}` : 'Not connected · your Google calendars still show through macOS Calendar'}</small></div>${on ? '<button class="btn sm" data-a="disconnect">Disconnect</button>' : `<button class="btn sm act" data-a="connect">Connect Google</button>`}</div>
      <div class="srow"><span class="pv">${ic('calendar', 15)}</span><div class="grow"><b>macOS Calendar</b><small>iCloud, Google (CalDAV), subscriptions, birthdays · access granted</small></div><span style="color:var(--ok)">${ic('check', 15)}</span></div></div>
    <div class="sbox"><table class="captab"><tr><th>What</th><th>macOS Calendar</th><th>With Google</th></tr>${[['See, create, move, delete events', 1, 1], ['Title, time, place, notes, reminders, repeat', 1, 1], ['Reply Yes / Maybe / No', 0, 1], ['Add and remove guests, send invitations', 0, 1], ['Choose "send update" or "save only"', 0, 1], ['Create a Google Meet link', 0, 1], ['Names from Google contacts', 0, 1]].map(([w, a, b]) => `<tr><td>${w}</td><td class="${a ? 'y' : 'n'}">${a ? '✓' : '—'}</td><td class="${b ? 'y' : 'n'}">${b ? '✓' : '—'}</td></tr>`).join('')}</table></div>
    <p class="lede2" style="font-size:var(--fs-s)">Status of the real app: the Google sign-in is built and tested against a fake server only. The installed build has no Google client ID, so "Connect" cannot work yet.</p>`;
  }
  if (t === 'menubar') c = `<h3>Menu bar</h3><p class="lede2">The calendar in the menu bar. (E2, F1, F2)</p><div class="sbox">
    <div class="srow"><div class="grow">Days</div><div class="segc">${[['2', 'Today and tomorrow'], ['3', 'Three days']].map(([v, l]) => `<button class="${A.settings.mbDays === v ? 'on' : ''}" data-a="setMb" data-k="mbDays" data-v="${v}">${l}</button>`).join('')}</div></div>
    <div class="srow"><div class="grow">Visible rows<small>The menu stops at this height and scrolls.</small></div><div class="segc">${[6, 8, 12].map(v => `<button class="${A.settings.mbRows === v ? 'on' : ''}" data-a="setMb" data-k="mbRows" data-v="${v}">${v}</button>`).join('')}</div></div>
    <div class="srow"><div class="grow">Join the current call from anywhere<small>⌘J in the app; ⌃⌘J works even when Calendr is in the background.</small></div>${swt(true, 'noop')}</div>
    <div class="srow"><div class="grow">New event from the menu bar<small>⌘N while the menu is open.</small></div>${swt(true, 'noop')}</div></div>`;
  if (t === 'keys') c = `<h3>Shortcuts</h3><p class="lede2">Every shortcut, also under ? in the app.</p>${shortcutTable()}`;
  return `<div class="scrim" data-a="closeModal"></div><div class="modal sheet"><nav><b>Settings</b>${nav.map(([k, l, i]) => `<button class="${t === k ? 'on' : ''}" data-a="openSettings" data-k="${k}">${ic(i, 15)} ${l}</button>`).join('')}</nav><div class="sc">${c}</div><button class="ibtn" style="position:absolute;right:12px;top:12px" data-a="closeModal">${ic('x')}</button></div>`;
}
const SHORTCUTS = [['Command menu', ['⌘', 'K']], ['Search events', ['/']], ['New event', ['C']], ['Join the current call', ['⌘', 'J']], ['Go to today', ['T']], ['Next / previous', ['J', 'K']], ['Day, week, month', ['D', 'W', 'M']], ['Toggle sidebar', ['⌃', '⌘', 'S']], ['Toggle right column', ['⌥', '⌘', 'I']], ['Next field in the editor', ['⇥']], ['Previous field', ['⇧', '⇥']], ['Delete the event', ['⌫']], ['Undo', ['⌘', 'Z']], ['Send update', ['⌘', '↩']], ['Close', ['esc']], ['Menu bar calendar', ['⌃', '⌘', 'K']], ['Settings', ['⌘', ',']]];
const shortcutTable = () => `<div class="sbox">${SHORTCUTS.map(([l, k]) => `<div class="srow" style="min-height:34px"><div class="grow">${l}</div>${kb(...k)}</div>`).join('')}</div>`;
function modalHTML() {
  const m = A.modal; if (!m) return '';
  if (m === 'cmd') return cmdHTML();
  if (m === 'settings') return settingsHTML();
  if (m === 'shortcuts') return `<div class="scrim" data-a="closeModal"></div><div class="modal" style="width:460px"><div class="mh"><b>Keyboard shortcuts</b></div><div class="mb" style="max-height:560px;overflow:auto">${shortcutTable()}</div></div>`;
  if (m === 'onboard') return onboardHTML();
  if (m === 'oauth') return `<div class="scrim" data-a="closeModal"></div><div class="modal oauth">${gLogo(30)}<div class="gl2">Sign in with Google</div><p>Calendr wants to access your Google Account<br><b>${ME}</b></p><ul><li>See and edit events in your calendars</li><li>See your calendar list</li><li>See your contacts and "other contacts"</li></ul><div style="display:flex;gap:8px;justify-content:center"><button class="btn" data-a="closeModal">Cancel</button><button class="btn act" data-a="oauthOk">Continue</button></div></div>`;
  if (m === 'delete') {
    const e = selEv(); if (!e) return '';
    return `<div class="scrim" data-a="closeModal"></div><div class="modal"><div class="mh"><b>Delete “${esc(e.t)}”?</b><p>${others(e).map(g => esc(nameOf(g.id))).join(', ')} ${google() ? 'get a cancellation email.' : 'keep the event until macOS Calendar syncs the change.'}</p></div><div class="mf"><button class="btn ghost" data-a="closeModal">Cancel</button>${google() ? '<button class="btn" data-a="doDelete" data-k="quiet">Delete without email</button>' : ''}<button class="btn red" data-a="doDelete">Delete${google() ? ' and notify' : ''}</button></div></div>`;
  }
  return '';
}

// ================================================================ onboarding (decided after the test): first launch
function onboardHTML() {
  // fixed-size dialog over the blurred app; steps crossfade in place (obSync toggles classes, no re-render)
  const s = A.obStep || 0, hasg = V.hasg !== '0';
  const chip = (icon, label, sub) => `<div class="src"><span class="pv">${icon}</span><span>${label}<small>${sub}</small></span></div>`;
  const cloud = '<svg width="16" height="16" viewBox="0 0 16 16"><path d="M4.5 12.5h7.2a2.8 2.8 0 0 0 .4-5.6 3.8 3.8 0 0 0-7.3-.6A3.1 3.1 0 0 0 4.5 12.5Z" fill="#5AC8FA"/></svg>';
  const arts = [
    `<div class="a0"><div class="halo"></div>${appIcon('nowline', 128)}<div class="mini">${[['#5B8DEF', 10, 22], ['#5FB97E', 38, 30], ['#E9B949', 64, 16], ['#E5674F', 24, 54], ['#A9A6F5', 52, 60]].map(([c, x, y]) => `<i style="background:${c};left:${x}%;top:${y}%"></i>`).join('')}<b></b></div></div>`,
    `<div class="aacc"><div class="calbig">${ic('calendar', 60)}</div><span class="okb">${ic('check', 22, 'stroke-width="2.4"')}</span></div>`,
    `<div class="a1">${chip(cloud, 'iCloud', '2 calendars')}${hasg ? chip(gLogo(15), 'Google', '9 calendars') : `<div class="src dashed"><span class="pv">${gLogo(15)}</span><span>Google<small>not on this Mac yet</small></span></div>`}${chip(ic('link', 15), 'Subscribed', '1 calendar')}${chip(ic('person', 15), 'Birthdays', 'from Contacts')}<div class="flow">${ic('down', 18)}</div><div class="into">${appIcon('nowline', 44)}<span>Calendr</span></div></div>`,
    `<div class="a2"><div class="ring"></div><div class="g">${gLogo(46)}</div>${[['reply', 'b1'], ['users', 'b2'], ['mail', 'b3'], ['', 'b4']].map(([i, c]) => `<span class="badge ${c}">${i ? ic(i, 18) : meetLogo(18)}</span>`).join('')}</div>`,
    `<div class="a3"><div class="ok">${ic('check', 40, 'stroke-width="2.2"')}</div><div class="keys"><span><i>⌘</i><i>K</i></span><span><i>⌘</i><i>J</i></span><span><i>⌃</i><i>⌘</i><i>K</i></span></div></div>`,
  ];
  const cb = (id, w) => { const on = !(A.obCals[id] && A.obCals[id][w] === false); return `<button class="obcb ${on ? 'on' : ''}" data-a="obCal" data-k="${id}" data-w="${w}" title="${w === 'app' ? 'Show in Calendr' : 'Show in the menu bar'}">${ic('check', 11, 'stroke-width="2.4"')}</button>`; };
  const rows = g => Object.entries(CALS0).filter(([, c]) => c.g === g).map(([id, c]) => `<div class="crow"><span class="dot" style="background:${c.hex}"></span><span class="nm">${esc(c.name)}</span>${cb(id, 'app')}${cb(id, 'mb')}</div>`).join('');
  const gHead = `<div class="cgrp">Google <span class="acc">${ME}</span><span class="only-a gact"><button class="btn sm" data-a="obAuth">${gLogo(13)} Connect</button><small>to reply and invite</small></span><span class="only-g gact ok">${ic('check', 13)} Connected</span></div>`;
  const googleBlock = hasg ? gHead + rows('google')
    : `<div class="nog only-ab"><div class="cgrp" style="padding:0 0 4px">Google</div><b>No Google calendars on this Mac yet</b><p>Your Google account is not added to Apple Calendar here, so its calendars cannot show.</p>
        <div class="acts2"><button class="btn sm act" data-a="obAuth">${gLogo(13)} Connect Google account</button><button class="btn sm ghost" data-a="obSysSettings">Add in System Settings → Internet Accounts</button></div></div>
       <div class="only-gb"><div class="cgrp">Google <span class="acc">connected directly</span><span class="gact ok">${ic('check', 13)} Connected</span></div>${rows('google')}</div>`;
  const panes = [
    `<span class="kick">Welcome</span><h3>Your calendars, calmer</h3><p>Calendr shows the calendars you already have in Apple Calendar: iCloud, Google, subscriptions and birthdays. Nothing to import.</p>
      <div class="cta"><button class="btn act" data-a="obGo" data-k="1">Get started</button></div>`,
    `<span class="kick">Step 1 of 3</span><h3>Allow access to your calendars</h3><p>macOS asks once. Calendr reads and edits your events through Apple Calendar, so they stay in sync on every device.</p>
      <div class="perm"><span class="pv" style="color:var(--ok)">${ic('check', 15)}</span><div>Calendars<small>Allowed</small></div></div>
      <div class="perm"><span class="pv">${ic('person', 15)}</span><div>Contacts <span style="color:var(--fg3)">· optional</span><small>Shows names instead of bare email addresses</small></div><button class="btn sm" data-a="noop">Allow</button></div>
      <div class="cta"><button class="btn act" data-a="obGo" data-k="2">Continue</button></div>`,
    `<span class="kick">Step 2 of 3</span><h3>Choose your calendars</h3><p>Tick what shows in Calendr and in the menu bar. You can change it later in Settings.</p>
      <div class="callist"><div class="chead"><span></span><span>Calendr</span><span>Menu bar</span></div>${googleBlock}
        ${['icloud', 'subs', 'bday'].map(g => `<div class="cgrp">${GROUPS.find(x => x.id === g).name}</div>${rows(g)}`).join('')}</div>
      <div class="cta"><button class="btn act" data-a="obGo" data-k="3">Continue</button></div>`,
    `<span class="kick">Step 3 of 3 · optional</span><h3>Reply and invite with Google</h3><p>Your Google events already show. To reply, invite or make Meet links, Calendr needs your Google account.</p>
      <div class="ba"><div class="bacard"><b>Without Google</b><small>You see your events</small>
          <div class="mini"><span class="lbl">Going?</span><div class="segc off"><button class="on">Yes</button><button>Maybe</button><button>No</button></div></div>
          <div class="mini dim">${ic('lock', 12)} Reply in Google Calendar</div></div>
        <div class="bacard on"><b>With Google</b><small>Also reply, invite, add Meet</small>
          <div class="mini"><span class="lbl">Going?</span><div class="segc"><button>Yes</button><button class="on">Maybe</button><button>No</button></div></div>
          <div class="mini"><span class="chip2">${ic('plus', 11)} Add guests</span><span class="chip2">${meetLogo(12)} Meet link</span></div></div></div>
      <div class="cta only-ab"><button class="btn act" data-a="obAuth">${gLogo(15)} Connect Google account</button><button class="btn ghost" data-a="obSkip">Skip, use Apple Calendar only</button></div>
      <div class="cta only-gb"><div class="okline">${ic('check', 15)} Google is connected</div><button class="btn act" data-a="obGo" data-k="4">Continue</button></div>`,
    `<span class="kick">All set</span><h3>You are ready</h3><p><span class="only-g">Google is connected as <b>${ME}</b>. Replies, guests, invitations and Meet links work.</span><span class="only-a">Calendr uses Apple Calendar only. Where Google would help, Calendr says so; connect any time in Settings → Accounts.</span></p>
      <div class="perm"><span class="pv">${ic('search', 15)}</span><div>Command menu and search<small>⌘K</small></div></div><div class="perm"><span class="pv">${ic('video', 15)}</span><div>Join the current call<small>⌘J</small></div></div>
      <div class="cta"><button class="btn act" data-a="closeModal">Start using Calendr</button></div>`,
  ];
  return `<div class="scrim blur"></div><div class="modal onb2 s${s} ${google() ? 'g-on' : ''}" id="onb">
    <div class="art">${arts.map((h, i) => `<div class="pane ${i === s ? 'on' : ''}" data-i="${i}">${h}</div>`).join('')}</div>
    <div class="body">${panes.map((h, i) => `<div class="pane ${i === s ? 'on' : ''}" data-i="${i}">${h}</div>`).join('')}
      <div class="foot"><button class="btn ghost sm back" data-a="obGo" data-k="back">${ic('left', 13)} Back</button><div class="dots">${panes.map((_, i) => `<i class="${i === s ? 'on' : ''}" data-i="${i}"></i>`).join('')}</div><span class="back" style="visibility:hidden;width:64px"></span></div>
      <div class="auth ${A.obAuthOpen ? 'on' : ''}">${gLogo(28)}<h3 style="margin:4px 0 0">Sign in with Google</h3><p>to continue to <b>Calendr</b></p>
        <div class="acct"><span class="av" style="background:#4f8f5f">YN</span><div>Your Name<small>${ME}</small></div>${ic('check', 15)}</div>
        <p style="font-size:var(--fs-s)">Calendr will be able to see and edit events in your calendars, see your calendar list and your contacts.</p>
        <div class="cta" style="flex-direction:row;justify-content:flex-end"><button class="btn ghost" data-a="obAuthCancel">Cancel</button><button class="btn act" data-a="obAuthOk">Continue</button></div></div>
    </div></div>`;
}
function obSync() {
  const m = document.getElementById('onb'); if (!m) return true;
  const s = A.obStep || 0;
  m.className = `modal onb2 s${s} ${google() ? 'g-on' : ''}`;
  m.querySelectorAll('.pane, .dots i').forEach(el => el.classList.toggle('on', +el.dataset.i === s));
  m.querySelector('.auth').classList.toggle('on', !!A.obAuthOpen);
  return false;
}

// ================================================================ menu bar (E2, F1, F2)
function joinTarget() {
  const evs = A.events.filter(e => e.call && !e.call.pending && visible(e) && myResp(e) !== 'no' && e.d <= TODAY && TODAY <= endDay(e));
  return evs.find(isNow) || evs.filter(e => e.d === TODAY && e.s > NOW && e.s - NOW <= 15).sort((a, b) => a.s - b.s)[0] || null;
}
function statusText() {
  const now = A.events.filter(e => visible(e) && isNow(e) && !inLane(e) && myResp(e) !== 'no').sort((a, b) => (b.call ? 1 : 0) - (a.call ? 1 : 0))[0];
  return now ? `${now.t} · ${now.e - NOW}m left` : 'Climbing · in 1 h';
}
function dayRows(d, fromNow) {
  return A.events.filter(e => visible(e) && !A.mbHidden.includes(e.cal) && myResp(e) !== 'no' && !e.allDay && !inLane(e) && e.d === d && (!fromNow || e.s > NOW)).sort((a, b) => a.s - b.s);
}
function laneOf(d) { return A.events.filter(e => visible(e) && !A.mbHidden.includes(e.cal) && inLane(e) && e.d <= d && d <= endDay(e)); }
function mbRow(e, opts = {}) {
  const soon = e.call && (e.d > TODAY || e.s - NOW <= 24 * 60);
  return `<button class="mi" data-a="mbOpen" data-id="${e.id}" style="${evVars(colorOf(e))}"><span class="b"></span><span class="tm tab">${fmt(e.s)}</span><span class="tt">${esc(e.t)}</span>${opts.end ? `<span class="end tab">${fmt(e.e)}</span>` : ''}${soon && !opts.noJoin ? `<span class="mbjoin sm" data-a="join" data-id="${e.id}">${callLogo(e.call, 12)} Join</span>` : ''}</button>`;
}
function mbNative(before) {
  const cap = before ? 999 : A.settings.mbRows, days = before ? 3 : +A.settings.mbDays;
  const now = A.events.filter(e => visible(e) && isNow(e) && e.call)[0];
  let html = '', used = 0, hiddenTotal = 0;
  if (now) html += `<div class="nowrow"><div class="tx"><b>${esc(now.t)}</b><span class="tab">Now · ${now.e - NOW} min left</span></div><button class="mbjoin" data-a="join" data-id="${now.id}">${callLogo(now.call, 13)} Join <span class="kh">⌘J</span></button></div><div class="sp2"></div>`;
  if (!before) html += `<div class="mbscroll" style="max-height:${A.settings.mbRows * 24 + 70}px">`;
  for (let k = 0; k < days; k++) {
    const d = TODAY + k, lane = laneOf(d), rows = dayRows(d, k === 0).filter(e => e !== now);
    html += `<div class="hd"><span>${k === 0 ? 'Today' : k === 1 ? 'Tomorrow' : fmtDay(d)}</span>${k ? `<span class="tab" style="font-weight:400">${fmtDay(d)}</span>` : ''}</div>`;
    if (before) {
      lane.forEach(e => { html += `<button class="mi" data-a="mbOpen" data-id="${e.id}" style="${evVars(colorOf(e))}"><span class="b"></span><span class="tm">all-day</span><span class="tt">${esc(e.t)}</span></button>`; });
      rows.forEach(e => { html += mbRow(e, { end: true, noJoin: true }); });
      continue;
    }
    if (lane.length) {
      const open = A.mbAllOpen === d;
      html += `<button class="mi" data-a="mbAll" data-d="${d}" style="--cc:${colorOf(lane[0])}"><span class="b" style="background:var(--fg3)"></span><span class="tm">all-day</span><span class="tt">${esc(lane.slice(0, 2).map(e => e.t).join(', '))}${lane.length > 2 ? ` +${lane.length - 2}` : ''}</span><span class="end">${ic(open ? 'down' : 'right', 12)}</span></button>`;
      if (open) lane.forEach(e => { html += `<button class="mi" style="padding-left:28px;${evVars(colorOf(e))}" data-a="mbOpen" data-id="${e.id}"><span class="b"></span><span class="tt">${esc(e.t)}</span></button>`; });
      used++;
    }
    rows.forEach(e => { html += mbRow(e); });
  }
  if (!before) html += '</div>';
  html += `<div class="sp2"></div><button class="mi" data-a="mbNew">${ic('plus', 14)} New event…<span class="kh">⌘N</span></button><button class="mi" data-a="mbOpenApp">Open Calendr<span class="kh">⌘1</span></button><button class="mi" data-a="openSettings" data-k="menubar">Settings…<span class="kh">⌘,</span></button><div class="sp2"></div><button class="mi" data-a="noop">Quit Calendr<span class="kh">⌘Q</span></button>`;
  return `<div class="mbmenu" data-mb style="width:${before ? 470 : 300}px">${html}</div>`;
}
function parseQuick(t) {
  const s = (t || '').toLowerCase();
  let d = A.qaddDay != null ? A.qaddDay : null, mins = A.qaddTime != null ? A.qaddTime : null;
  if (d == null) {
    if (/übermorgen|day after tomorrow/.test(s)) d = TODAY + 2;
    else if (/morgen|tomorrow/.test(s)) d = TODAY + 1;
    else { const names = [['mon', 'montag'], ['tue', 'dienstag'], ['wed', 'mittwoch'], ['thu', 'donnerstag'], ['fri', 'freitag'], ['sat', 'samstag'], ['sun', 'sonntag']]; names.forEach((n, i) => { if (d == null && n.some(x => new RegExp(`\\b${x}`).test(s))) { let k = (i - dow(TODAY) + 7) % 7 || 7; d = TODAY + k; } }); }
  }
  if (mins == null) { const mt = s.match(/\b(\d{1,2})(?::(\d{2}))?\s*(uhr|h\b|am|pm)/) || s.match(/\b(\d{1,2}):(\d{2})\b/); if (mt) { let h = +mt[1]; if (mt[3] === 'pm' && h < 12) h += 12; mins = h * 60 + (+mt[2] || 0); } }
  if (mins == null) mins = Math.ceil((NOW + 15) / 60) * 60;
  if (d == null) d = mins > NOW ? TODAY : TODAY + 1;
  const title = (t || '').replace(/\b(übermorgen|morgen|tomorrow|um|at)\b/gi, '').replace(/\b\d{1,2}(:\d{2})?\s*(uhr|h\b|am|pm)?/gi, '').replace(/\b(montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag|mon|tue|wed|thu|fri|sat|sun)\w*\b/gi, '').replace(/\s+/g, ' ').trim();
  return { d, s: mins, e: Math.min(mins + 60, 1439), title };
}
function qaddHTML() {
  if (!A.qadd) return '';
  const p = parseQuick(A.q.qadd);
  return `<div class="qadd" data-mb style="right:340px"><b>New event</b>
    <label class="boxf">${ic('plus', 14)}<input data-k="qadd" placeholder="e.g. Kaffee mit Sam morgen 15 uhr" value="${esc(A.q.qadd)}" autocomplete="off"></label>
    <div class="chips">${[[TODAY, 'Today'], [TODAY + 1, 'Tomorrow'], [TODAY + 2, fmtDay(TODAY + 2)]].map(([d, l]) => `<button class="${p.d === d ? 'on' : ''}" data-a="qaDay" data-d="${d}">${l}</button>`).join('')}${[[19 * 60, '19:00'], [20 * 60, '20:00'], [9 * 60, '09:00']].map(([t, l]) => `<button class="${p.s === t ? 'on' : ''}" data-a="qaTime" data-v="${t}">${l}</button>`).join('')}</div>
    <div class="r"><span class="parse tab">${esc(p.title || 'New event')} · ${fmtDay(p.d)} ${fmt(p.s)}–${fmt(p.e)} · Personal</span></div>
    <div class="r"><button class="btn sm ghost" data-a="openFull">Open in Calendr</button><button class="btn sm act" data-a="qaddOk">Add <span class="kh">↩</span></button></div></div>`;
}
function mbHTML() {
  let h = '';
  if (A.mb) h += mbNative(false).replace('class="mbmenu"', 'class="mbmenu" style="right:300px"');
  return h + qaddHTML();
}
function dockHTML() {
  if (V.dock !== '1') return '';
  const ph = c => `<div class="app"><i class="ph2" style="background:${c}"></i><span class="run" style="opacity:0"></span></div>`;
  return `<div class="dockwrap"><div class="dock">${ph('linear-gradient(#5ac8fa,#007aff)')}${ph('linear-gradient(#ffffff,#d9d9d9)')}${ph('linear-gradient(#ff9f0a,#ff375f)')}<div class="app"><span class="lbl3">Calendr</span>${appIcon('nowline', 52)}<span class="run"></span></div>${ph('linear-gradient(#34c759,#30b0c7)')}${ph('linear-gradient(#3a3a3c,#1c1c1e)')}</div></div>`;
}

// ================================================================ render
function render() {
  const host = document.getElementById('host');
  const ae = document.activeElement;
  let fk = null, ss = 0, se = 0;
  if (ae && host.contains(ae) && (ae.dataset.k || ae.dataset.k2)) { fk = ae.dataset.k || ae.dataset.k2; try { ss = ae.selectionStart; se = ae.selectionEnd; } catch (_) { } }
  const gw = host.querySelector('.gridwrap'); if (gw) A.gridScroll = gw.scrollTop;
  // v10: the Designer's hour height (keep the same time at the top of the grid)
  const nH = PK().H || THEME.H; if (nH !== H) { A.gridScroll = A.gridScroll / H * nH; H = nH; }
  const ps = host.querySelector('.right .scroll'), psTop = ps ? ps.scrollTop : 0;
  const oldAnc = host.querySelector('#upanchor'), ancDelta = oldAnc && ps ? oldAnc.offsetTop - ps.scrollTop : null;
  const adb = host.querySelector('.ad .body'), adH = adb ? adb.getBoundingClientRect().height / scale() : null;
  const e = selEv(), d = e ? detail(e) : null;
  const sideCls = A._left == null || A._left === A.left ? (A.left ? '' : 'gone') : (A._left ? '' : 'gone');
  const rightCls = A._right == null || A._right === A.right ? (A.right ? '' : 'gone') : (A._right ? '' : 'gone');
  const rightBody = A.q.search.trim() ? searchCol() : d ? d.body : todayCol();
  host.innerHTML = `<div class="desk ${isLight() ? 'light' : ''} ov-cascade ${V.rowgrid === '1' ? 'rowgrid' : ''} ${deskCls()}" ${deskAttrs()} style="${themeVars()}">
    <div class="macbar"><span style="font-size:14px"></span><b>Calendr</b><span>File</span><span>Edit</span><span>View</span><span>Window</span><span>Help</span><div class="sp"></div>
      <button class="si ${A.mb ? 'on' : ''}" id="statusitem" data-a="togMenubar" title="Menu bar calendar  ⌃⌘K">${menuGlyph(15)}<span class="tab">${esc(statusText())}</span></button><span>${ic('search', 14)}</span><span class="tab">Wed 4 Nov ${fmt(NOW)}</span></div>
    <div class="win">${sidebar(sideCls)}
      <main class="center">${hdr()}${viewBody()}</main>
      <aside class="right ${rightCls}"><div class="srch"><label>${ic('search', 14)}<input data-k="search" placeholder="Search events" value="${esc(A.q.search)}" autocomplete="off">${A.q.search ? `<button class="ibtn sm" data-a="clearSearch" title="Clear  esc">${ic('x', 12)}</button>` : `<span class="kbd">/</span>`}</label></div><div class="scroll">${rightBody}</div>${d && !A.q.search.trim() ? d.foot : ''}</aside>
    </div>
    ${popHTML()}${modalHTML()}${mbHTML()}
    ${A.toast ? `<div class="toast"><span style="color:var(--fg2)">${A.toast.logo || ic(A.toast.icon, 18)}</span><div class="tx"><b>${esc(A.toast.t)}</b>${A.toast.s ? `<span class="s">${esc(A.toast.s)}</span>` : ''}</div>${A.toast.undo ? `<button class="btn sm" data-a="undo">Undo <span class="kh">⌘Z</span></button>` : ''}<button class="ibtn sm" data-a="closeToast">${ic('x', 13)}</button></div>` : ''}
    ${dockHTML()}</div>`;
  // animate the sidebars (C6) and the all-day lane (C5)
  const side = host.querySelector('.side'), right = host.querySelector('.right');
  if (A._left != null && A._left !== A.left) requestAnimationFrame(() => side.classList.toggle('gone', !A.left));
  if (A._right != null && A._right !== A.right) requestAnimationFrame(() => right.classList.toggle('gone', !A.right));
  A._left = A.left; A._right = A.right;
  const ad2 = host.querySelector('.ad .body');
  if (ad2 && adH != null && A.animAd) { const to = ad2.style.height; ad2.style.height = adH + 'px'; ad2.getBoundingClientRect(); requestAnimationFrame(() => { ad2.style.height = to; }); }
  A.animAd = false;
  const g2 = host.querySelector('.gridwrap'); if (g2) { g2.scrollTop = A.gridScroll; if (A.reveal) { revealGrid(g2, A.reveal); A.reveal = null; } A.gridScroll = g2.scrollTop; g2.addEventListener('scroll', () => { A.gridScroll = g2.scrollTop; }, { passive: true }); }
  const ps2 = host.querySelector('.right .scroll'); if (ps2) ps2.scrollTop = A.panelTop != null ? A.panelTop : psTop; A.panelTop = null;
  // D5: open at "Upcoming" (a sliver of the earlier results above it); keep the view steady when earlier rows load
  const anc = host.querySelector('#upanchor');
  if (ps2 && anc) {
    if (A.search.jump) { ps2.scrollTop = anc.offsetTop - ps2.offsetTop - 46; if (A.search.phase === 'ready') A.search.jump = false; }
    else if (ancDelta != null) ps2.scrollTop = anc.offsetTop - ancDelta;
  }
  host.querySelectorAll('textarea.notes').forEach(t => { t.style.height = 'auto'; t.style.height = t.scrollHeight + 'px'; });
  const want = A.focusKey || fk, isNew = !!A.focusKey && A.focusKey !== fk; A.focusKey = null;
  if (want) {
    const el = host.querySelector(`[data-k="${want}"]`) || host.querySelector(`[data-k2="${want}"]`);
    if (el) { el.focus({ preventScroll: true }); if (el.setSelectionRange) try { const n = el.value.length; el.setSelectionRange(isNew ? n : ss, isNew ? n : se); } catch (_) { } }
  }
  fit(); place(); tabNumbers();
  if (window.railAfterRender) railAfterRender();
}
// v7 fix (b): scroll the grid so the minutes [from, to] are visible, measured on the real layout (hour height, all-day lane, an open
// dialog that covers the grid). Scenes C3 and C4 use it; before, they scrolled by a fixed 16.5 hours and the evening sat under the dialog.
function revealGrid(g, { from, to, under }) {
  const k = scale(), gr = g.getBoundingClientRect(), dlg = under && document.querySelector(under);
  let top = gr.top, bottom = gr.bottom;
  if (dlg) { const r = dlg.getBoundingClientRect(); if (r.bottom < bottom - (to - from) / 60 * H * k) top = Math.max(top, r.bottom); else bottom = Math.min(bottom, r.top); }
  const band = (bottom - top) / k, off = (top - gr.top) / k, need = (to - from) / 60 * H;
  const want = from / 60 * H - off - Math.max(8, (band - need) / 2);
  g.scrollTop = Math.max(0, Math.min(g.scrollHeight - g.clientHeight, want));
}
function scale() { const d = document.querySelector('.desk'); return d ? d.getBoundingClientRect().width / 1440 : 1; }
function place() {
  const desk = document.querySelector('.desk'); if (!desk) return;
  const k = scale(), dr = desk.getBoundingClientRect();
  desk.querySelectorAll('.pop[data-anchor]').forEach(p => {
    const a = desk.querySelector(p.dataset.anchor);
    if (!a) { p.style.display = 'none'; return; }
    const ar = a.getBoundingClientRect(), r = { t: (ar.top - dr.top) / k, b: (ar.bottom - dr.top) / k, l: (ar.left - dr.left) / k, r: (ar.right - dr.left) / k };
    const W = p.offsetWidth, Hh = p.offsetHeight;
    let top, left;
    if (p.dataset.place === 'over') { const g = desk.querySelector('.gridwrap'), gr = g.getBoundingClientRect(); left = r.l + 2; top = (gr.top - dr.top) / k + (+p.dataset.top / 60 * H) - g.scrollTop; if (left + W > 1440 - 8) left = r.r - W - 2; }
    else {
      left = r.l - 8; top = r.b + 4;
      // menus from the right column end left of it when they would cover it
      if (a.closest('.right') && left + W > 1440 - 8) left = 1440 - W - 8;
      if (top + Hh > 900 - 8) top = Math.max(32, r.t - Hh - 4);
    }
    left = Math.max(8, Math.min(left, 1440 - W - 8)); top = Math.max(28, Math.min(top, 900 - Hh - 8));
    Object.assign(p.style, { top: top + 'px', left: left + 'px' });
  });
}
function fit() {
  const st = document.getElementById('stage'), fr = document.getElementById('frame');
  const s = Math.min((st.clientWidth - 32) / 1440, (st.clientHeight - 32) / 900);
  fr.style.transform = `scale(${s}) translate(-50%, -50%)`;
}
// A1: the editor's own Tab order, top to bottom; the numbers show it
function tabStops() {
  const pd = document.querySelector('.right .pd'); if (!pd) return [];
  const foot = document.querySelector('.right .pfoot');
  return [...pd.querySelectorAll('[data-k], [data-k2]'), ...(foot ? [...foot.querySelectorAll('button')] : [])]
    .filter(el => !el.disabled && el.getAttribute('aria-disabled') !== 'true' && el.offsetParent !== null);
}
function tabNumbers() {
  document.querySelectorAll('.tabn').forEach(n => n.remove());
  if (V.tabnums !== '1') return;
  const desk = document.querySelector('.desk'); if (!desk) return;
  const k = scale(), dr = desk.getBoundingClientRect(), ae = document.activeElement;
  tabStops().forEach((el, i) => {
    const r = el.getBoundingClientRect(), n = document.createElement('span');
    n.className = 'tabn' + (el === ae ? ' cur' : ''); n.textContent = i + 1;
    n.style.left = ((r.left - dr.left) / k - 10) + 'px'; n.style.top = ((r.top - dr.top) / k - 6) + 'px';
    desk.appendChild(n);
  });
}
