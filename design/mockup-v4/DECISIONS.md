# Calendr v4 decisions
Mockup: `design/mockup-v4/index.html`. The picker shows the same state.
## Locked in round 1
| Element | Pick |
| --- | --- |
| Colour theme | OLED black |
| Accent (buttons, today) | Ink |
| Today marker | Accent pill |
| App icon | Now line |
| Typeface | SF Pro, Instrument Sans titles |
| Text size | 11.5 / 12.5 px |
| Event title weight | Medium 500 |
| Event block | Muted solid fill |
| Past events | Medium |
| Reminders and 0-min items | Small block |
| All-day section | Mix: 2 rows, "+N more", expands to a fixed height that scrolls |
| All-day item height | 18 px |
| Search | Top of the right column |
| Useful shortcuts | Under Today |
| Empty fields | Always there, placeholder |
| Participants | List with replies and actions |
| Google Meet text in notes | Hidden |
| Location | Suggestions while typing |
| Going? | Yes · Maybe · No |
| Calendar and colour | One menu |
| Reminders | List, add more |
| Send changes | Split button |
| Delete with guests | Dialog with guest list |
| Menu bar Join button | Call logo and Join |
| Google accounts | Google Calendar API + Contacts |

## Locked in round 2
| Element | Pick |
| --- | --- |
| Overlapping events | Smart: cascade with a 14 px indent; side by side if they start within 30 min |
| My reply on the event | Quiet: no reply thin outline, maybe stripes, declined faded and struck |
| Call | Big Join, editable link under it |
| Open the location | Click: small menu (Apple Maps, Google Maps, Copy) |
| Participant replies | Badge on the avatar |
| Names for bare addresses | Apple Contacts, then Google contacts |
| Menu background | Near-black like the cards, clear hairline |
| Readability pass | All four |
| Calendar menu width | 224 px, account name without domain |
## Locked in round 3
| Element | Pick |
| --- | --- |
| Clean-up approach | Quiet chrome: 18 / 12.5 / 11.5 px, sentence-case labels, grey icons and key hints, no key boxes, no panel separators, no Today frame |
## Design system (round 4)
Every screen uses only these values. The mockup shows them in "Design system". B in the picker switches between round 3 (before) and round 4 (after).
- Surfaces: `--bg` for the app, sidebar and right column (the sidebar was `--bg1` before); `--pop` for menus and dialogs; `--bg2` for fields and raised controls; `--hover` for hover and the selected row.
- Text: 18 titles, 12.5 text, 11.5 small; events 11.5 / 500. Colours: `--fg` content, `--fg2` secondary, `--fg3` labels, hints, placeholders, icons.
- One segmented control: Day/Week/Month, Going?, and the settings switches. It has a hairline frame, a 22 px segment, and a raised selected segment.
- Heights: 28 for list rows, menu rows, small buttons and sidebar rows; 32 for panel rows, buttons, fields and search.
- Icon buttons: 26 with a 16 px icon (panel, header); 22 with a 14 px icon (sidebar, rows).
- Radius: 6 for rows, events, icon buttons and segments; 8 for buttons, fields and segmented controls; 12 for menus, dialogs and cards.
- Spacing: 4, 8, 12, 16, 24.
- Secondary text in a row starts after a 14 px mark and an 8 px gap, the same as participant names.
## Locked in round 4
| Element | Pick |
| --- | --- |
| Someone else's event | Nothing extra. A not-answered invitation shows as an outlined, unfilled block; the participants list marks the organizer. |
| Participants | One line per person: reply mark, name, role in grey; no pictures |
## Locked in round 5
| Element | Pick |
| --- | --- |
| Events I have not accepted | Right half, on top of accepted events |
| When too much overlaps | At most 2 side by side. "+N" opens a panel over the day at that time: every event of the busy time as a full-width row, in time order, with its reply |
## Replaced
- Participant replies, badge on the avatar (round 2): the one-line rows (round 4) have no pictures. The reply mark before the name replaces the badge.
## Fixed without a decision
Round 5:
- The demo data is invented: the person, every address (reserved example domains), calendars, places and event titles.
- Menus anchored to a button with a quoted selector (account menu, "+N") opened in the wrong place or not at all.

Round 4:
- Declined events are solid (muted fill, grey struck text), never see-through.
- The sidebar and the right column have the same background and hairline.

Round 3:
- Event titles always start at the top. A short item in a block's first 30 min now takes the right third, instead of pushing the title down.
- The time always shows: blocks from 30 min have a title line and a time line; under 52 px the title is one line; narrow blocks show the start time only.
- Long words hyphenate at syllables, not inside letters.
- "Going?" moved up, over the call. It has its own icon now.
- My own participant row expands to Going · Maybe · Decline.
- Single-line participant rows centre the name on the avatar.
- The "maybe" badge is an icon, not 9 px text.
- Picker: "?" explains an option; "Preview on hover" (on by default) shows an option while hovered and outlines what changes; a counter shows the sizes, colours and weights on screen.

Round 2:
- Event titles start at the top of the block. Buttons centred their content before.
- Long words do not break inside the word. Narrow blocks show one line with an ellipsis.
- Event panel grid: icon column 20–36 px, text column at 48 px, 20 px line box. Every field, input and hover box bleeds 8 px.
- Avatars start on the text column, not in the icon column.
- Bare addresses show "N without a name · Allow Contacts" in the list.
- Right column: box edge 8 px, content edge 20 px, for search, cards, rows and shortcuts.
- Sidebar: leading glyphs at 16 px, text at 40 px, trailing buttons end at 220 px. All row icons are 14 px.
- Calendar names are display names, not the account address again.
- Week grid gutter is 58 px, so each day column is 118 px and hairlines are crisp.
- Day labels and all-day items start on the event text line. All-day items use the same detached colour bar as timed events.
- Menus opened from the right column end 8 px left of it. They no longer cover its icon column.
- Menus under a field start their text on the field's text.
- Calendar menu headers and swatches start at the colour dot. The swatches are a 6-column grid.
- Chevrons are 12 px everywhere.
- A declined event on top of another one is light, but the text below it no longer shows through.
## Alignment check
Press G (or "Show alignment guides" in the picker).
- Green line: a left edge that 3 or more items share.
- Blue line: a shared right edge.
- Red box: an item 1 to 5 px off a shared line, with the offset.

All 20 scenes pass with 0 red boxes, except one false match: the card countdown text lines up by chance with the "Later" titles.
