---
name: calendr-design
description: Calendr v4 design system for the native macOS SwiftUI app. Load it before you add or change any view in Sources/Calendr/Views (grid, events, sidebar, right column, event panel, menus, dialogs, menu bar). It gives the locked tokens, component rules, overlap layout and alignment rules from design/mockup-v4.
---

# Calendr design (v4)
Use this skill for every SwiftUI change in `Sources/Calendr/Views`. The result must match the v4 mockup.
## Source of truth
Order of authority. If two sources disagree, the first wins.
1. `design/mockup-v4/DECISIONS.md`: the locked decisions of rounds 1 to 5 and the design system.
2. `design/mockup-v4/index.html`: the `LOCKED` object, the CSS under `.ds`, and the "Design system" scene (`md === 'system'`).
3. `design/mockup-v4/IMPLEMENTATION-PLAN.md`: the phases and the files for each phase.
4. `design/LOCKED.md` and `design/DESIGN.md` are v3 and v2. Do not use them for new work.

Open `index.html` in a browser to see a screen. The picker selects a scene. Press G for the alignment guides.

Exact token values and their SwiftUI names are in [tokens.md](tokens.md). Read it before you write a colour, a font, a size or a radius.
## Core rules
- Use only the tokens. Do not add a new size, colour, weight, height or radius.
- Three text sizes: 18 (titles), 12.5 (text), 11.5 (small text and events).
- Two weights: 400 and 600. Event titles are 500.
- Three text colours: `fg` content, `fg2` secondary, `fg3` labels, hints, placeholders and icons.
- Labels are sentence case. No capitals, no letter spacing.
- Quiet chrome: icons and key hints are `fg3`. Key hints have no box. No panel separators. No Today frame.
- Colour has three uses only: calendar colours (user data), `act` (primary button, today), `live` (now line and countdown).
- Use space before boxes. Do not put a box in a box.
## Components
Segmented control. Use one control for Day/Week/Month, Going? and the settings switches.
- Frame: 1 px inset hairline `hair2`, no fill, padding 2, radius 8.
- Segment: height 22, padding 0 10, radius 6, 11.5 / 400, `fg2`.
- Selected segment: `thumb` fill, `fg`, 600.
- Other segments on hover: `hover` fill, `fg`.

Buttons.
| Kind | Height | Padding | Radius | Fill | Text |
|---|---|---|---|---|---|
| Button | 32 | 0 12 | 8 | `bg2` | 12.5 / 400, `fg` |
| Primary | 32 | 0 12 | 8 | `act` | 12.5 / 600, `onAct` |
| Ghost | 32 | 0 12 | 8 | none, `hover` on hover | `fg2`, `fg` on hover |
| Destructive | 32 | 0 12 | 8 | `#D9645A` | 12.5 / 600, white |
| Small | 28 | 0 10 | 8 | as its kind | 11.5 |
| Split (Send) | 32 | 0 12, chevron part 32 wide | 8 | `act` | 600; divider 1 px `onAct` 25 % |
| Join (big) | 32, full width | centred | 8 | `act` | 12.5 / 600 |

- Icon button 26 with a 16 icon: panel and header. Icon button 22 with a 14 icon: sidebar and rows.
- Icon buttons: radius 6, icon `fg3`. On hover: `hover` fill and `fg`.
- Hover on a filled `act` control: 8 % brighter. Hover on a `bg2` button: 12 % brighter.

Fields.
- Field and search: height 32, radius 8, no fill, 1 px inset `hair2`. Focus: `bg` fill and a 1.5 px inset `fg3` ring.
- Inline field in a panel row: radius 6, padding 3 8, margin −3 −8 (8 px bleed). Hover: `hover`. Focus: `bg` and a 1.5 px `fg3` ring.
- Placeholder text: `fg3`. Empty fields always show, with a placeholder.
- Switch (All day): 26 × 15 track, radius 8, `bg3`; on: `act`. Knob 11, `fg2`; on: `onAct`.

Rows.
- 28: list rows, menu rows, small buttons, sidebar rows.
- 32: panel rows, buttons, fields, search.
- Row radius 6. Hover and the selected row use `hover`.
- A list row (Later): time column 40 (`fg2`, 11.5), 3 × 14 colour bar (radius 2), title 12.5 with an ellipsis, gap 8.

Menus and popovers.
- Surface: `pop`, 1 px `hair2` border, radius 12, padding 6, shadow 0 22 60 black 50 %.
- Item: min height 28, padding 4 10, gap 10, radius 6. Hover: `hover`. Check column 14.
- Section label: 11.5 / 600, `fg3`, padding 8 10 4. Separator: 1 px `hair`, margin 6 4.
- Danger item text: `#E5776C`.
- Dialog: `pop`, radius 12, width 520, 1 px `hair2`. Title 18 Instrument Sans 600. Footer buttons right, gap 8. Scrim black 50 %.
- Calendar menu: width 224. Account name without the domain.
## Event blocks
Geometry in a day column (mockup, hour = 46 px):
- Left = lane start + 2 + cascade indent. Width = lane width − 5 − indent. Top + 1. Height = duration − 2, minimum 18.
- Radius 6. Padding 4 7 4 10. Colour bar: 3 wide, 3 from the left, top and bottom, radius 2.
- Title 11.5 / 500, line height 1.25. Time 11.5 / 400, tabular figures.
- The title always starts at the top. Never centre it vertically, except one-line blocks under 22 px.

Text rules (from the mockup render code):
- Height under 30: one line, title then start time.
- Height under 52: the title has 1 line, so the time always shows. Otherwise 2 lines.
- Width under 56: one line with an ellipsis. A one-line narrow block hides the time.
- Show the range "14:00–16:00" only if width − 17 ≥ 62. Else show the start time.
- Hyphenate long words at syllables. Never break inside a word.

Reply states. `cc` is the calendar colour. `fill` = mix(bg, cc, 34 %).
| State | Fill | Bar | Title | Time | Extra |
|---|---|---|---|---|---|
| Going (normal) | `fill` | `cc` | `fg` | `fg2` | none |
| Past | mix(bg, cc, 15 %) | mix(bg, cc, 32 %) | `fg2` | `fg3` | none |
| Not answered | `bg` (unfilled) | `cc` | `fg` | `fg2` | 1 px solid outline mix(bg, cc, 75 %) |
| Maybe | stripes 135°: 6 px `fill`, 6 px mix(fill, bg, 45 %) | `cc` | `fg` | `fg2` | none |
| Declined | mix(bg, fill, 38 %), solid | `cc` at 45 % | `fg3`, struck | `fg3`, struck | never see-through |

- A block on top of another one (cut) has a 1.5 px `bg` ring.
- Selected: 1.5 px `bg` ring, then a 3 px `fg` ring.
- Hover: 12 % brighter.
- All-day items: height 18, radius 6, padding 0 7 0 10, the same detached bar. Two rows, then "+N more". Expanded: fixed height that scrolls.
- Reminders and 0-min items: a small block, not a pill.
## Overlap layout
Smart cascade, 2 lanes maximum.
1. Sort by start, then the longer event first.
2. An event that starts 30 min or more after the event under it cascades: one level up, indent +14 px, it fills the rest of the width.
3. Events that start within 30 min of each other share the width equally (side by side).
4. At most 2 events are side by side at one time. The third becomes a "+N" chip.
5. Events I have not accepted (declined or no reply) take the right half, on top. Accepted events keep the left half. If they start within 30 min, the accepted event narrows to the left half.
6. Two unaccepted events at the same time: the later one goes into "+N".
7. A short item (task, 0 min) sits on the right half. In the first 30 min of a block it takes the right third, and the block narrows to two thirds. It never pushes the title down.

"+N" chip: height 16, min width 22, padding 0 5, radius 8, `bg3`, `fg`, 11.5 / 600, 3 from the right, 1.5 px `bg` ring. Hover or open: `fg` fill, `bg` text.

"+N" opens a stack panel over the day at the busy time:
- A `pop` surface, padding 4, gap 3. Width: 2 day columns − 8. Left edge 2 px inside the day. It flips left at the window edge.
- One full-width row per event of the busy time, in time order.
- Row: columns 76 / 1fr / auto, gap 8, min height 28, padding 4 8 4 12, radius 6, event fill and bar.
- Row text: time 11.5 (event time colour), title 500 with an ellipsis, reply ("maybe", "no reply", "declined") 11.5 `fg3`.
- Rows use the same reply states as the grid.
## Participants
- One line per person: reply mark, name, role in grey. No pictures.
- Row: min height 28, padding 2 0 2 8, margin left −8 (bleed), gap 8, radius 6.
- Reply mark, 14 × 14: going = check 12 `#3FA45B`; maybe = question 12 `#D9A33A`; declined = x 11 `#E5776C`; no reply = clock 12 `fg3`.
- Name 12.5 / 400 `fg`, ellipsis. Role 11.5 `fg3`: "organizer", "you", "optional", joined with " · ".
- Added or removed, not sent yet: a 7 px `fg2` dot at the end. Removed: the name is struck and `fg3`.
- Hover shows the row actions: 22 icon buttons with 14 icons, at the end of the row.
- My own row expands to a segmented control: Going · Maybe · Decline.
- Bare addresses: names from Apple Contacts, then Google contacts. Without access: "N without a name · Allow Contacts".
## Alignment
- Event panel: padding 12 14 16 20. Icon column 20–36 px (16 icon). Text column at 48 px. Line box 20 px; secondary lines 16 px. Icon to text gap 12.
- Every field, input and hover box bleeds 8 px to the left and right. The text stays on the text column.
- Reply marks and participant rows start on the text column, not in the icon column.
- Secondary text in a row starts after the 14 px mark and an 8 px gap, the same as participant names.
- Right column (320): box edge 8 px, content edge 20 px, for search, cards, rows and shortcuts.
- Sidebar (236): leading glyphs at 16 px, text at 40 px, trailing buttons end at 220 px. Row icons 14 px.
- Week grid: gutter 58 px, so each day column is 118 px and hairlines fall on whole pixels. Hour labels end 8 px from the gutter edge.
- Day labels and all-day text start on the event text line: 12 px inside the day column.
- Menus from the right column end 8 px left of it. Menus under a field start their text on the field text.
- Calendar menu headers and swatches start at the colour dot. Swatches: 6-column grid, 20 px, radius 6.
- Chevrons are 12 px everywhere.
## Do
- Read the current view and `Theme.swift` before you change a view.
- Take values from `tokens.md`. If a token does not exist in Swift yet, add it to `Theme.swift`, `Typeface.swift` or `Components.swift`.
- Use `.monospacedDigit()` (tabular figures) for every time, date and count.
- Keep one `Segmented` type.
- Re-render the snapshots (`scripts/snapshots.sh`) and compare with the mockup scene.
## Do not
- Do not write hex literals, font sizes or radius numbers in a view.
- Do not use Instrument Sans for text under 18.
- Do not use avatars or pictures in participant rows.
- Do not make declined events see-through.
- Do not show more than 2 events side by side.
- Do not add uppercase labels, key boxes, panel separators or a Today frame.
- Do not use `live` red for anything other than now.
- Do not invent a light theme value. Only OLED dark is locked.
## Check list before done
- [ ] Every text is 18, 12.5 or 11.5. Weights are 400 / 600 (events 500).
- [ ] Every text colour is `fg`, `fg2` or `fg3`.
- [ ] Heights are 28 or 32. Icon buttons are 26 / 16 or 22 / 14.
- [ ] Radii are 6, 8 or 12. Spacing is 4, 8, 12, 16 or 24.
- [ ] Surfaces: `bg` app, `pop` menus and dialogs, `bg2` raised controls, `hover` hover and selection.
- [ ] Text lines up on the columns in the Alignment list. Fields bleed 8 px.
- [ ] Event reply states match the table. Overlaps use 2 lanes and "+N".
- [ ] No hex literal in `Views/` outside `Theme.swift` and the menu bar art.
- [ ] `scripts/verify.sh` passes.
- [ ] The snapshot matches the same mockup scene. With G in the mockup, there are no red boxes.
