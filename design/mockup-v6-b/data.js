// Horion mockup: neutral demo data (a made-up week, Mon 2 - Sun 8 Nov 2026). Every name, address, email and link
// here is invented. Same layout features as a busy real week: overlaps, a full all-day lane, multi-day events,
// tasks, a live call, a declined event, a call invitation in the notes and a search term that goes back months.
'use strict';

// ---------------------------------------------------------------- dates
// Day index 0 = Mon 2 Nov 2026. "Now" = Wed 4 Nov 18:15.
const BASE = Date.UTC(2026, 10, 2);
const TODAY = 2, NOW = 18 * 60 + 15;
const WDS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const WDL = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const MONS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const MONL = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const dd = d => new Date(BASE + d * 864e5);
const di = (y, mo, day) => Math.round((Date.UTC(y, mo - 1, day) - BASE) / 864e5);
const dow = d => ((d % 7) + 7) % 7;
const dnum = d => dd(d).getUTCDate();
const dmon = d => dd(d).getUTCMonth();
const dyear = d => dd(d).getUTCFullYear();
const fmtDay = d => `${WDS[dow(d)]} ${dnum(d)} ${MONS[dmon(d)]}`;
const fmtDayY = d => `${fmtDay(d)}${dyear(d) !== 2026 ? ' ' + dyear(d) : ''}`;
const fmtMonY = d => `${MONS[dmon(d)]} ${dyear(d)}`;
const weekNo = d => { const t = dd(d); const th = new Date(t); th.setUTCDate(t.getUTCDate() + 3 - ((t.getUTCDay() + 6) % 7)); const y1 = new Date(Date.UTC(th.getUTCFullYear(), 0, 4)); return 1 + Math.round(((th - y1) / 864e5 - 3 + ((y1.getUTCDay() + 6) % 7)) / 7); };
const m = t => { const [h, mi] = t.split(':').map(Number); return h * 60 + mi; };
const fmt = x => `${String(Math.floor(x / 60) % 24).padStart(2, '0')}:${String(x % 60).padStart(2, '0')}`;
const dur = x => x >= 1440 ? `${Math.floor(x / 1440)} d${x % 1440 >= 60 ? ` ${Math.floor((x % 1440) / 60)} h` : ''}` : x >= 60 ? `${Math.floor(x / 60)} h${x % 60 ? ` ${x % 60} min` : ''}` : `${x} min`;

// ---------------------------------------------------------------- accounts and calendars
const ME = 'you@example.com';
const GROUPS = [
  { id: 'google', name: 'Google', sub: ME },
  { id: 'icloud', name: 'iCloud', sub: 'via macOS Calendar' },
  { id: 'subs', name: 'Subscribed calendars', sub: 'read-only' },
  { id: 'bday', name: 'Birthdays', sub: 'from Contacts' },
];
const CALS0 = {
  personal: { name: 'Personal', hex: '#5B8DEF', g: 'google' },
  work: { name: 'Work', hex: '#8F86E8', g: 'google' },
  product: { name: 'Horion', hex: '#A9A6F5', g: 'google' },
  family: { name: 'Family', hex: '#E5674F', g: 'google' },
  holidays2: { name: 'Holidays', hex: '#9254DE', g: 'google', ro: true },
  holidays: { name: 'Holidays in Germany', hex: '#3FA36B', g: 'google', ro: true },
  sport: { name: 'Sport', hex: '#F2884B', g: 'google' },
  tasks: { name: 'Tasks', hex: '#B9B9B9', g: 'google', task: true },
  team: { name: 'Team', hex: '#E9B949', g: 'google' },
  ipersonal: { name: 'Personal', hex: '#3A8EF0', g: 'icloud' },
  uni: { name: 'Uni', hex: '#C04BD8', g: 'icloud' },
  pubhol: { name: 'Public holidays', hex: '#D9822B', g: 'subs', ro: true },
  birthdays: { name: 'Birthdays', hex: '#8E9AAF', g: 'bday', ro: true },
};
const SWATCHES = [['#D9443A', 'Tomato'], ['#E5674F', 'Flamingo'], ['#F2884B', 'Tangerine'], ['#E9B949', 'Banana'], ['#3FA36B', 'Basil'], ['#5FB97E', 'Sage'], ['#5DADE2', 'Peacock'], ['#5B8DEF', 'Blueberry'], ['#A9A6F5', 'Lavender'], ['#9254DE', 'Grape'], ['#B9B9B9', 'Graphite'], ['#8E9AAF', 'Slate']];

// ---------------------------------------------------------------- people (contacts for guest autocomplete)
const PEOPLE = {
  me: { name: 'You', email: ME, src: 'me' },
  sam: { name: 'Sam Lee', email: 'sam.lee@mailbox.example', src: 'Contacts' },
  jordan: { name: 'Jordan Park', email: 'jordan@example.com', src: 'Google' },
  alex: { name: 'Alex Kim', email: 'alex@example.com', src: 'Contacts' },
  maya: { name: 'Maya Cruz', email: 'maya@example.com', src: 'Contacts' },
  noah: { name: 'Noah Fischer', email: 'noah@example.com', src: 'Google' },
  lea: { name: 'Lea Martin', email: 'lea@example.com', src: 'Contacts' },
  tom: { name: 'Tom Weber', email: 'tom@example.com', src: 'Contacts' },
  nina: { name: 'Nina Brooks', email: 'nina@example.com', src: 'Google' },
  omar: { name: 'Omar Haddad', email: 'omar@example.com', src: 'Google' },
  ivy: { name: 'Ivy Chen', email: 'ivy@example.com', src: 'Google' },
  rae: { name: 'Rae Novak', email: 'rae@example.com', src: 'Google' },
  eli: { name: 'Eli Stone', email: 'eli@example.com', src: 'Contacts' },
  kai: { name: '', email: 'kai@example.com', src: 'recent' },
};
const AVC = ['#4f8f5f', '#6c63c7', '#c26b3f', '#b0517a', '#3d7ea6', '#7a6a3c', '#a0603a', '#56708f', '#8a5a8f'];

// ---------------------------------------------------------------- places (instant location suggestions)
const PLACES = [
  ['Conference Center', '1 Expo Square'],
  ['Office, Room 1', '5 Harbour Street'],
  ['Office, Room 3', '5 Harbour Street'],
  ['Café Lula', '12 Market Street'],
  ['Climbing Gym', '38 Mill Road'],
  ['Riverside Park', 'River Road'],
  ['City Library', '2 Library Lane'],
  ['Central Station', '1 Station Square'],
  ['East Station', '3 Rail Road'],
  ['Market Hall', '42 Station Road'],
  ['Town Hall', '8 Church Square'],
  ['Community Center', '14 Garden Street'],
  ['Old Town Bakery', '50 Baker Street'],
  ['Shopping Arcade', '66 High Street'],
];

// ---------------------------------------------------------------- call invitation text
const ZOOM_URL = 'https://zoom.us/j/123456789?pwd=demo';
const FENCE = '-::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-';
const ZOOM_BOILER = `${FENCE}\nJoin Zoom meeting\n${ZOOM_URL}\n\nMeeting ID: 123 456 789\nPasscode: 000000\n\nOne tap mobile\n+10000000000,,123456789#,,,,*000000# Example\n\nPlease do not edit this section.\n${FENCE}`;
const MEET_BOILER = code => `${FENCE}\nJoin with Google Meet: https://meet.google.com/${code}\n\nLearn more about Meet at: https://support.google.com/a/users/answer/9282720\n\nPlease do not edit this section.\n${FENCE}`;

// ---------------------------------------------------------------- events
// e = { id, d, s, ed, e, allDay, t, cal, guests:[{id, resp, org}], call:{kind, url}, location, notes, repeat, organizer, reminders, ... }
// All-day: d..ed inclusive, s = e = 0. Timed: start day d at minute s, end day ed at minute e.
function seedEvents() {
  const EV = []; let nid = 1;
  const base = { allDay: false, guests: [], call: null, location: '', notes: '', repeat: null, organizer: true, reminders: [10], busy: 'Busy', vis: 'Default visibility', color: null };
  const add = o => { const e = { id: 'e' + (nid++), ...JSON.parse(JSON.stringify(base)), ...o }; if (e.ed == null) e.ed = e.d; if (e.allDay) { e.s = 0; e.e = 0; e.busy = 'Free'; e.reminders = []; } EV.push(e); return e; };
  const timed = (d, s, en, t, cal, x = {}) => add({ d, s: m(s), e: m(en), t, cal, ...x });
  const task = (d, s, t, x = {}) => add({ d, s: m(s), e: m(s), t, cal: 'tasks', reminders: [0], ...x });
  const allday = (d, ed, t, cal, x = {}) => add({ d, ed, t, cal, allDay: true, ...x });
  const me = (resp = 'yes', org = false) => ({ id: 'me', resp, org });
  const g = (id, resp = 'yes', org = false) => ({ id, resp, org });

  // recurring
  const FROM = di(2026, 9, 1), TO = di(2026, 12, 31);
  for (let d = FROM; d <= TO; d++) {
    const w = dow(d);
    if (w < 5) timed(d, '09:30', '09:45', 'Standup', 'team', { repeat: 'Every weekday', organizer: false, call: { kind: 'meet', url: 'meet.google.com/abc-defg-hij' }, guests: [g('nina', 'yes', true), me('yes'), g('rae', 'yes')] });
    if (w === 0 || w === 2) timed(d, '07:30', '08:30', 'Gym', 'sport', { repeat: 'Every week' });
    if (w === 1 || w === 3) timed(d, '10:00', '12:00', 'Deep work', 'product', { repeat: 'Every week' });
    if (w === 3) timed(d, '20:00', '21:30', 'Founder circle', 'team', {
      repeat: 'Every week on Thu', organizer: false, call: { kind: 'zoom', url: ZOOM_URL.replace('https://', '') },
      guests: [g('omar', 'yes', true), me('yes'), g('rae', 'yes'), g('noah', 'maybe'), g('eli', 'none'), g('ivy', 'no')],
      notes: 'Agenda in the doc. Please add your points beforehand.\n\n' + ZOOM_BOILER, reminders: [10] });
    if (w === 3) timed(d, '19:00', '20:00', 'Language exchange', 'team', { repeat: 'Every week on Thu', reminders: [] });
    timed(d, '21:30', '22:15', 'Call with Sam', 'personal', { repeat: 'Every day', guests: [me('yes', true), g('sam', 'yes')], reminders: [1] });
    timed(d, '22:30', '23:00', 'Read', 'personal', { repeat: 'Every day', reminders: [] });
    timed(d, '23:10', '23:20', 'Lights out', 'personal', { repeat: 'Every day', reminders: [0] });
    if (d >= di(2026, 10, 1)) {
      task(d, '18:00', 'Water the plants', { repeat: 'Every day' });
      add({ d, s: m('23:00'), e: m('23:15'), t: 'Stretch 10 minutes', cal: 'tasks', repeat: 'Every day', reminders: [0] });
    }
    if (d >= di(2026, 10, 15)) task(d, '22:49', 'Write in the journal', { repeat: 'Every day' });
  }
  // older things, some only found with "Search earlier"
  timed(di(2026, 8, 22), '20:15', '21:00', 'Sam / You – film club', 'personal', { guests: [me('yes', true), g('sam', 'yes')] });
  timed(di(2026, 8, 23), '18:30', '19:30', 'Sam / You – plan the trip', 'personal', { guests: [me('yes', true), g('sam', 'yes')] });
  timed(di(2026, 6, 14), '15:00', '17:00', 'Picnic with Sam', 'personal', { location: 'Riverside Park, River Road', guests: [me('yes', true), g('sam', 'yes')] });
  timed(di(2026, 5, 2), '19:00', '22:00', "Sam's birthday dinner", 'personal', { guests: [me('yes', true), g('sam', 'yes'), g('lea', 'yes')] });
  timed(di(2026, 3, 19), '08:30', '14:15', 'Statistics exam', 'uni');
  timed(di(2026, 2, 21), '14:00', '18:00', 'Exhibition with Sam', 'personal', { location: 'Market Hall, 42 Station Road', guests: [me('yes', true), g('sam', 'yes')] });

  // ---------------- the demo week: Mon 2 - Sun 8 Nov
  // Mon
  allday(0, 0, 'Ship v1.2 beta', 'tasks');
  timed(0, '11:00', '12:30', 'Customer interviews', 'work', { guests: [me('yes', true), g('jordan', 'yes')] });
  timed(0, '14:00', '15:30', 'Pricing page copy', 'product');
  timed(0, '17:00', '18:30', 'Investor update', 'work', { call: { kind: 'teams', url: 'teams.microsoft.com/l/meetup-join/demo' }, organizer: false, guests: [g('jordan', 'yes', true), me('yes')] });
  timed(0, '19:30', '21:00', 'Dinner with Sam', 'personal', { location: 'Café Lula, 12 Market Street', guests: [me('yes', true), g('sam', 'yes')] });
  // Tue
  task(1, '08:30', 'Reply to support emails');
  timed(1, '13:00', '14:00', 'Lunch with Maya', 'personal', { location: 'Market Hall, 42 Station Road' });
  timed(1, '14:30', '16:00', 'Onboarding review', 'product', { guests: [me('yes', true), g('noah', 'yes')] });
  timed(1, '18:00', '19:00', 'Run', 'sport');
  timed(1, '20:00', '21:30', 'Movie night', 'personal');
  // Wed (today)
  allday(2, 2, "Alex's birthday", 'birthdays');
  allday(2, 2, "Alex's birthday", 'family');
  allday(2, 2, "Alex's Birthday", 'ipersonal');
  allday(2, 2, 'Release day', 'product');
  allday(2, 2, 'Renew passport', 'tasks');
  task(2, '09:00', 'Text Alex happy birthday');
  timed(2, '11:00', '12:00', '1:1 with Jordan', 'work', { guests: [me('yes', true), g('jordan', 'yes')] });
  timed(2, '13:00', '14:30', 'Build: search v2', 'product');
  timed(2, '16:30', '18:45', 'Design review', 'product', {
    location: 'Office, Room 3, 5 Harbour Street', call: { kind: 'meet', url: 'meet.google.com/dmo-revw-xyz' },
    guests: [me('yes', true), g('sam', 'yes'), g('alex', 'none')], notes: 'Bring the latest build.\n\n' + MEET_BOILER('dmo-revw-xyz'), reminders: [30, 10] });
  timed(2, '17:00', '18:00', 'Hiring sync', 'team', { organizer: false, guests: [g('rae', 'yes', true), me('none'), g('noah', 'yes'), g('nina', 'maybe')], call: { kind: 'meet', url: 'meet.google.com/hir-sync-abc' }, notes: MEET_BOILER('hir-sync-abc') });
  timed(2, '19:15', '20:30', 'Climbing', 'sport');
  timed(2, '20:30', '21:00', 'Podcast', 'personal');
  // Thu
  allday(3, 3, 'Launch prep', 'product');
  timed(3, '13:00', '14:00', 'Dentist', 'ipersonal', { reminders: [60] });
  timed(3, '15:00', '16:30', 'Partner call', 'work', { organizer: false, guests: [g('tom', 'yes', true), me('yes')], call: { kind: 'zoom', url: 'zoom.us/j/987654321' } });
  timed(3, '18:00', '19:00', 'Weekly review', 'personal', { repeat: 'Every week on Thu' });
  timed(3, '18:30', '20:00', 'Neighbourhood meetup', 'family', { organizer: false, guests: [g('nina', 'yes', true), me('no'), g('maya', 'yes')], location: 'Community Center, 14 Garden Street' });
  timed(3, '19:30', '20:30', 'Study group', 'product', { organizer: false, guests: [g('noah', 'yes', true), me('none'), g('maya', 'yes'), g('ivy', 'maybe')], call: { kind: 'meet', url: 'meet.google.com/stu-dygr-oup' } });
  // Fri
  allday(4, 6, 'Lea visiting', 'personal');
  allday(4, 6, 'Tom away', 'family');
  allday(4, 5, 'Trip', 'personal');
  allday(4, 4, 'Ship day', 'product');
  timed(4, '14:00', '16:00', 'Bug bash', 'product', { location: 'Office, Room 3, 5 Harbour Street', guests: [me('yes', true), g('noah', 'yes'), g('rae', 'yes')] });
  timed(4, '17:30', '19:30', 'Demo prep', 'work', { location: 'Office, Room 1, 5 Harbour Street', notes: 'Run the whole demo once against the clock, then fix the rough spots.' });
  timed(4, '20:30', '23:00', 'Drinks with the team', 'personal', { guests: [me('yes', true), g('alex', 'yes')] });
  add({ d: 4, s: m('10:00'), ed: 5, e: m('16:00'), t: 'Team offsite', cal: 'personal', location: 'Conference Center, 1 Expo Square', notes: 'Two days of planning with the whole team.', reminders: [120, 1440] });
  add({ d: 4, s: m('10:00'), ed: 5, e: m('16:00'), t: 'Team offsite: planning days', cal: 'team', location: 'Conference Center, 1 Expo Square', organizer: false, guests: [g('nina', 'yes', true), me('yes'), g('rae', 'yes')] });
  // Sat
  timed(5, '08:15', '10:00', 'maybe: founders breakfast', 'personal', { organizer: false, guests: [g('omar', 'yes', true), me('maybe')] });
  timed(5, '10:00', '18:00', 'Founders Conference', 'personal', { location: 'Conference Center, 1 Expo Square', notes: 'A day of talks for early-stage founders. Ticket required.', reminders: [120, 1440] });
  add({ d: 5, s: m('22:00'), ed: 6, e: m('02:00'), t: 'maybe: conference after party', cal: 'personal', organizer: false, guests: [g('omar', 'yes', true), me('maybe'), g('ivy', 'yes')], location: 'Conference Center, 1 Expo Square' });
  // Sun
  timed(6, '10:00', '11:30', 'Long walk', 'personal', { location: 'Riverside Park, River Road', reminders: [1, 5] });
  task(6, '09:45', 'Call the landlord');
  timed(6, '13:00', '16:00', 'Write blog post', 'product');
  timed(6, '19:00', '20:00', 'Plan the week', 'personal', { repeat: 'Every week on Sun' });
  // next weeks
  allday(di(2026, 11, 11), di(2026, 11, 11), "St. Martin's Day", 'holidays');
  allday(di(2026, 11, 15), di(2026, 11, 15), 'National Day of Mourning', 'holidays');
  allday(di(2026, 11, 22), di(2026, 11, 22), 'Sunday of the Dead', 'holidays2');
  allday(di(2026, 10, 3), di(2026, 10, 3), 'German Unity Day', 'pubhol');
  allday(di(2026, 12, 24), di(2026, 12, 26), 'Christmas', 'pubhol');
  allday(di(2026, 11, 20), di(2026, 11, 20), "Sam's birthday", 'birthdays');
  timed(di(2026, 11, 10), '08:30', '14:15', 'Statistics exam (60 min break)', 'uni');
  timed(di(2026, 11, 13), '09:00', '10:00', 'Workshop: design systems', 'team');
  return EV;
}
