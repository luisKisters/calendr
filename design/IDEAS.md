# Ideas

Feature ideas that are not specced or scheduled yet. Each one lists what was said, the design so far, and what is still open.

Inspiration screenshots (Fantastical, Morgen, Apple Calendar, Notion Calendar, Google Calendar, Analog) live outside the repo in `~/Documents/horion-inspo/`, because they contain private calendar data. Its `README.md` lists every file and the features liked in each app. A text-only summary of those features goes in `design/INSPIRATION.md`.

---

## 1. Natural-language quick-add

Source: thread "Natural Language Event Quick-Add" (2026-11-20).

Type a sentence, get an event. Seen in Fantastical ("Test 12–16" fills date, start and end; "with Richard" turns into a contact chip; "at …" opens a location popover). TickTick does the same with sigils: `~Projects #idea every day at 7 test`.

### Starting points in the code

- `GoToDateParser` in `Sources/HorionKit/GoToDate.swift` already parses dates from text ("in 4 weeks", "dec 25 2028").
- `CalendarStore.create` saves events.
- `MenuBarHotKey` already registers a global hotkey.
- Google sync (`Sources/HorionKit/Google/`) and `Attendee` exist, so guests can be written through the Google API, which EventKit can't do.

### Parser

A pure `QuickEntryParser` in HorionKit. Input `(text, now, context)`, output:

```swift
struct ParsedEntry {
  var title: String
  var start, end: Date?; var allDay: Bool
  var recurrence: RecurrenceRule?        // "every week", "jeden Montag"
  var calendar: CalendarRef?             // #business
  var location: LocationQuery?           // "at amrit"
  var people: [PersonQuery]              // "with Richard"
  var alert: TimeInterval?               // "!15m"
  var kind: .event | .task               // "todo …", "remind me …"
  var tokens: [(Range<String.Index>, TokenKind)]  // for highlighting
}
```

The token ranges let the field style recognized parts (chips) and fill the form live.

Pipeline. Each stage removes its part of the string; what is left is the title.

1. Sigils: `#calendar`, `~list`, `@person`, `!alert`. Each opens its own autocomplete.
2. Recurrence: "every day / weekday / 2 weeks / monday", "until 12.12.", "for 3 weeks". German too: "jeden Tag", "alle 2 Wochen".
3. Date and time: extend the own grammar ("8pm", "20:00", "8-9pm", "for 2h", "at noon", "morgen um 8", "next fri"). `NSDataDetector(.date)` as fallback only; it handles durations badly.
4. People: "with X" matched against `CNContactStore`.
5. Location: trailing "at X" / "in X" goes to `MKLocalSearchCompleter`, plus current location. If what follows "at" parses as a time, it is a time.
6. Task vs. event: leading "todo", "task" or "remind me" makes an `EKReminder`.

Optional: on macOS 26, `FoundationModels` with `@Generable` can return a `ParsedEntry` for messy input ("dinner w/ dido sometime next week evening"). The rule parser stays the live path, because it is instant and gives exact ranges.

### UI

- Input field at the top of the right panel, plus a global hotkey for quick entry from the menu bar.
- Parse on every keystroke; fill the editor form live.
- Ghost block in the time grid at the parsed time.
- One autocomplete popover with sections (Contacts, Locations, Calendars). Tab accepts, Enter adds.
- A field edited by hand is no longer overwritten by the parser.

### Order

1. Parser for title, date/time, duration, recurrence, with table-driven tests on a fixed `now`.
2. Input field, live form, ghost event, save through `store.create`.
3. `#calendar` and `!alert` sigils.
4. Location autocomplete.
5. Contacts, then reminders.

### Open

- German and English from the start, or English first?

---

## 2. Calendar sets and sub-calendars

Source: thread "Subcalendar Groups in Calendar Sets" (2026-11-20).

Calendar sets (from Fantastical): a named, saved pattern of the sidebar's calendar checkboxes that you switch between. The user also wants sub-groups, e.g. a "Personal" calendar split into "Eating", "Sport" and so on.

That is two different features.

### A. Nested sets: grouping whole calendars

```
Personal (set)
├── Eating      → "Meals" calendar
├── Sport       → "Training" calendar
└── Family      → "Familienkalender"
Work (set)
└── ...
```

Each sub-item is a real Google or iCloud calendar. Simple, and it syncs to the phone. Cost: one real calendar per category, which sprawls.

### B. Categories inside one calendar: tags on events

```
☑ Personal
   ☑ Eating
   ☑ Sport
   ☐ Errands
```

Events stay in one calendar. Horion adds categories on top, each with a colour and a checkbox under the calendar. Assigned in the right panel, or by rules ("title contains Lunch/Dinner/Essen → Eating"). A set can then be "Personal, only Sport and Family".

- Upside: no calendar sprawl; time stats later ("6 h eating this week").
- Catch: storage. EventKit can't nest calendars. Either local only (the phone won't see it), or a marker in the event (a `#eating` tag in the notes, or a Google extended property for Google events), which syncs but may show in other apps.

### Proposal

1. Sets first: named, switchable from the command menu, maybe auto-activated by time (Work 9–18).
2. Then categories as rule-based tags, so events don't need tagging by hand.

### Open

- What is "Eating" for: hiding/showing, colouring, or measuring time spent? That decides whether sets alone are enough.
- Next step once decided: a clickable mockup in `design/`.
