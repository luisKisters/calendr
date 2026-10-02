# Locked designs: what to build (v3)

Locked by the owner on 1 October 2026 from `design/mockup-v3/`. One chosen design per element. Every other
fassung in the mockup is reference only; do not implement it. The mockup is the specification: serve it
(`node design/mockup-v3/serve.mjs`), click through it, and match it. Where this table and the mockup disagree, the
mockup wins. `design/DESIGN.md` (v2) is superseded wherever it disagrees with this file.

The mockup opens on the locked design. The first option of every element in the picker is the locked one.

## Window

| Area | Element | Locked | Swift target | Notes |
|---|---|---|---|---|
| System | Accent | **None, ink only** | `Theme.act` | Selection and today are inverted ink. The only colours are calendar colours and `live` red for now. |
| System | Typeface | **Instrument Sans** | `Font.cal*` | Bundled (OFL). Tabular figures for every time. The v2 mono-is-machine rule is retired. |
| System | Corners | **Soft** | `Layout.radius*` | Events 6, controls 7, rows 7, surfaces 12. |
| Frame | Header | **Title left, controls right** | `CenterView.swift` | 60 pt. Month 22 pt, year in haze, week number as plain text. Right: view switch, arrows around Today, search. |
| Frame | View switch | **Text tabs** | `CenterView.swift` | Three words, no container. Active: ink, 600, 1.5 pt rule. |
| Frame | Day header | **Inline** | `TimeGridView.swift` | "Tue 29" on one line, 38 pt row, text 11 pt into the column. |
| Frame | Today marker | **Numeral pill** | `TimeGridView.swift` | Inverted pill around the numeral. No column tint. |
| Sidebar | Contents | **Month and calendars** | `SidebarView.swift` | 236 pt. Settings row at the foot. Scheduling and Meet with live in the command menu. |
| Sidebar | Mini month | **Numerals only** | `SidebarView.swift` | Week numbers are a setting, off by default (see Settings). No load marks. |
| Sidebar | Calendar list | **Checkboxes** | `SidebarView.swift` | Coloured 14 pt checkbox, every calendar listed under its account. |
| Grid | Event block | **Tint and bar** | `EventsCanvas.swift` | Colour at 16 percent, 3 pt inset bar. Title and time only; no place in the week view. |
| Grid | Hour scale | **Fit, then yours** | `TimeGridView.swift` | See "Hour scale" below. |
| Grid | Now marker | **Line and time** | `TimeGridView.swift` | 2 pt with a dot in today's column, 1 pt at 30 percent across the week, time pill in the gutter. The nearest hour label gives way. |
| Event | Where it opens | **Right panel** | `RightPanelView.swift` | See "The right column" below. |
| Event | Field layout | **Icon rows** | `RightPanelView.swift` | Only fields that have a value. Empty ones are "add" chips: Place, Guests, Video call, Notes. |
| Event | Creating | **Full detail** | `GridInteraction.swift` | Drag, double-click or C: dashed block on the grid, the panel in edit with the title focused. Return saves, Esc discards. |
| Event | Nothing selected | **Today column** | `RightPanelView.swift` | Now (with time left), Up next (with countdown), Later. |
| Command | Command menu | **Centred** | `Overlays.swift` | 620 pt, over a scrim. One field for commands, events and dates. |
| Command | Result rows | **Leading icons** | `Overlays.swift` | 16 pt icon, section labels, keycaps on the right. |
| Command | Undo | **Pill** | `Overlays.swift` | Bottom centre of the grid, six seconds, after move, resize and delete. Creating is silent. |

## Decisions that came out of the review notes

### Hour scale: fit is the focus, not a cage
- A week (or day) opens with its first to last event filling the grid. That sets the opening hour height and scroll position.
- The canvas is always all 24 hours. Scrolling reaches the hours outside the fit.
- The hour gutter is a zoom handle: drag down for taller hours, up for shorter (20 to 150 pt per hour). The hour under the pointer stays put.
- Double-click the gutter, or Settings > Hour height > Fit again, returns to the fit.
- A hand-set height carries to other weeks. A fitted period keeps the range it opened with, so editing never rescales the grid under the pointer.

### The right column: one width
- 320 pt, always present. Today, an event, and a new event swap inside it with a 180 ms fade. The grid never changes width.

### Settings (new)
- Opens from the sidebar foot, Cmd-comma, and the command menu.
- Appearance (Ink, Paper), Show week numbers (off), New events last (30 min, 45 min, 1 hour), Hour height (Fit again), Show in the menu bar (Title and countdown, Countdown, Icon only).

### Tasks: an ordinary calendar for now
- The Tasks calendar is a calendar like any other. Its entries are events: no checkboxes, no capsules, no lane, titles shown as they arrive ("[P1] Water the plants").
- The three task treatments explored in the mockup (own lane, margin ticks, capsules) are parked, not locked and not declined. They return with a TickTick integration, which is not scheduled.
- In the app this means removing the `[P1]` / "Tasks" calendar special-casing (`EventKind.task`, task capsules, the local "done" marker).

### Overlapping events: cascade
- An event reaches across later columns unless something there starts inside its own head (title and time). A 15 minute event an hour into a lecture sits on the lecture's right half, cut out with the window colour, and the lecture keeps its full width. Events that start together split the column.

## Menu bar: not locked yet

`design/mockup-v3/menubar.html` is the proposal (Notion Calendar's menu as the base, with a countdown in the item and in the list, a time column, row menus only where an event has a call or guests). It is waiting for the owner's picks.
Already done in the app: the "Start transcription" button is removed from the menu bar popover.

## Not designed in v3

The no-calendar-access empty state and recurrence editing are unchanged from v2.

## Verifying an implementation

1. `node design/mockup-v3/serve.mjs` and open the mockup next to the running app at 1440 x 900.
2. `node design/mockup-v3/check.mjs` must pass before and after any change to the mockup.
3. Differences between the app and the locked mockup are bugs.
