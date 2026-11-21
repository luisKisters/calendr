# Calendr v5: test feedback report

Test of 4 Nov 2026 on the installed build (PR F, `bdb401d`), real Apple Calendar data, no Google account.
Mockup: `design/mockup-v5/index.html` (serve with `node design/mockup-v5/serve.mjs`). The picker's **Feedback** tab has a **Show me** button for every ID below.
Paths are under `Sources/Calendr/` unless they start with `CalendrKit/`. Root causes come from code reading (`investigate-*.md`); nothing was profiled yet.

Size: S = under a day, M = one to three days, L = more.

## Round 4 decisions

- **D5 locked**: earlier results sit above "Upcoming", oldest at the top. The list opens with the last 3 earlier results just above "Upcoming", scrolled so "Upcoming" starts near the top. "Earlier" and "Upcoming" are sticky section headers (scrolling up pushes "Upcoming" away and "Earlier" sticks). "Load earlier results" is the first row of "Earlier" when more exist (then six more months at a time). No hint bar. No picker options.
- **Onboarding**: Welcome → Calendar access → **Choose your calendars** → Google (optional) → Ready. The calendars step lists every calendar found, grouped Google / iCloud / Subscribed / Birthdays, with checkboxes for "Calendr" and "Menu bar"; "Connect" sits next to the Google group. If Apple Calendar has no Google calendars, the Google group explains that and offers "Connect Google account" or "Add in System Settings → Internet Accounts". The Google step uses plain copy and a before/after card: without Google you see events and the reply control is locked; with Google you can reply, add guests and make Meet links.
- Preview switch "Has Google calendars" shows both versions of the calendars step.

## Round 2 decisions (preview annotations)

DECIDED and built in as the only behaviour (the picker no longer offers these): C2 lane = crosses midnight and ≥ 12 h · C3 overlap = side by side · C5 all-day lane = chevron + "Show less", animated · C4 declined = muted fill, struck text · C1 Day view = timeline + focus panel · B7 dates = times on one line, dates under them · A4 conferencing = Create Meet + paste field · E2 menu bar = native compact · F1 = quick-add window · C7 hour labels = brighter · C8 grid lines = stronger (13 % / 14 %, all-day border 22 % / 24 %) · C8 sidebars = own shade · C9 = Paper+ · E4 icon = Now line.

Changes from the annotations:
- Grid events: hover only lightens a block (no move, no grow, no z change). A click brings it to the front and selects it.
- Editor: no status line under the title ("Saved to …" is gone).
- B5: the call invitation text is stripped silently. No fold, no notice. No variants.
- B6: one behaviour. No location shows "Add location"; typing shows suggestions under the field; a set location shows "Open in Google Maps", "Open in Apple Maps" and "Copy address" on hover. No map image. No variants.
- D5: the earlier results were hard to find. Four variants: "Load earlier results" button at the bottom (REC), scroll up for earlier like a chat (with a sticky "↑ Scroll up for N earlier results" bar), Upcoming/Earlier switch, one list with a divider. The "N results · title, place, notes, guests" header row is gone.
- E2: the native menu has a fixed maximum height and the list scrolls; no "+N more" rows.
- Themes: the picker's Dark/Paper switch is only a preview. The app keeps both themes; Settings → Appearance offers Dark, Paper and Auto (follows macOS).
- O1: onboarding is a fixed-size dialog over the blurred app; steps crossfade in place with step dots and an illustration per step; the Google sign-in slides in inside the same dialog.

## Decisions after the test (round 1)

- **Onboarding (O1, new).** First launch gets a short flow: Welcome → calendar access → "Connect Google? (optional)" → done. The Google step says in plain words that Apple Calendar stays the default, and that Google adds four things: reply Yes / Maybe / No, add guests, send invitations and updates, create Google Meet links. Buttons: **Connect Google account** and **Skip, use Apple Calendar only**. Mockup: Feedback → O1, or Google tab → Show onboarding.
- **Q5 menu bar: native compact macOS menu.** Today and Tomorrow, about 8 rows and "+N more", all-day items folded into one row, 300 pt wide, Join on every call row, ⌘J on the current one, "New event…". The custom popover is dropped.
- **Day view is not broken, it is not useful.** Keep the redesign variants (C1 / F5).
- **The "+N" stack is removed entirely.** When expanded it reached far outside the column. Overlaps are shown in the grid only (C3 variants).

## Key context

The demo store (`Store/DemoStore.swift:11-15`) turns on every capability, so the tours and `verify.sh` never showed the EventKit limits the user hit. EventKit (`Store/EventKitStore.swift:16`, defaults in `Store/CalendarStore.swift:58-66`) cannot add guests, reply, send updates or make Meet links, and Google cannot be connected today (`Services/GoogleAccounts.swift:118`: no client ID in the build). Add a demo mode with EventKit capabilities so tours cover this.

## A. Stability and input

| ID | Problem | Root cause | Fix | Size | Mockup |
|---|---|---|---|---|---|
| A1 P0 | Tab jumps in odd order, then the app crashed. | A hidden 1×1 notes `TextField` (`Views/PanelDetailView.swift:153`) is in the key-view loop; tabbing onto it swaps it for the real field while it is first responder. No explicit order exists. After the last field Tab falls through to `.selectNext` (`CalendrKit/Shortcuts.swift:66,71`), which saves and swaps the editor. Start-time edits change the event id (`Store/EventKitStore.swift:186`), so the editor is rebuilt mid-focus. | One always-present notes field. Own the Tab order with `.onKeyPress(.tab)` over a fixed list, Shift-Tab back, never leave the editor. Stable editor identity. Get the `.ips` crash log to confirm. | M | A1: numbered Tab stops, focus ring, Tab wraps inside the editor |
| A2 P0 | Fields freeze the app for seconds; notes sometimes dead. | Every save and every `EKEventStoreChanged` runs `storeChanged()` on the main thread: full reload, search reset, second fetch (`Model/AppModel.swift:218-230, 279, 375, 572-579`). Contacts lookups are synchronous (`Services/ContactsResolver.swift:40-56`). Notes focus race in `PanelDetailView.swift:139-155`. | Coalesce store notifications (0.3-0.5 s, ignore our own saves), fetch and convert on a background store, save off the main actor, prewarm contacts. Fix notes as in A1. Confirm with `sample Calendr 5` while frozen. | L | A2: typing stays live (no status line, decided in round 2) |
| A3 P1 | Caret stays in Location after clicking "Add reminder". | Plain SwiftUI buttons do not take first responder; nothing resigns the text field (`Views/PanelDetailView.swift:326`, `Model/PanelV4State.swift:108-110`). | In `Views/PanelClickAway.swift`, resign text focus when the click lands on a non-text control; also in `openPanelMenu`. | S | A3: the focus ring and "Focus now" readout follow every click |
| A4 P1 | Conferencing offers only "paste link"; a 3 pt pill; froze. | Meet row hidden when `canCreateMeetLinks` is false (`Views/PanelMenus.swift:252`). Paste mode reuses `PanelCommitField`, sized to its own text (`Views/PanelControls.swift:89-102`, `Views/PanelCallRow.swift:46-48`). | Use the full-width `LinkField`, placeholder "Paste a Zoom, Teams or Meet link", name the detected service, keep the field until the link is valid. Always show "Create Google Meet link"; without Google, disabled with "Connect Google". | S | A4: link field detects Zoom/Teams/Meet/Webex; Meet button |

## B. Event editor

| ID | Problem | Root cause | Fix | Size | Mockup |
|---|---|---|---|---|---|
| B1 P1 | Cannot add guests, esp. to events that already have some. | `canAdd` is false for every EventKit calendar (`Views/PanelParticipants.swift:19`, `Store/EventKitStore.swift:16`); the field is not built and the header has no action. EventKit attendees are read-only. | With Google: guest field with Apple + Google contacts (already in `Views/PanelMenus.swift:274-307`). Without: the row is still clickable and explains, with Connect Google, Email instead, Open in Calendar. Move contact loading off the main thread. | S (affordance) / L (real add needs Google) | B1 with Google on and off |
| B2 P1 | "Does not repeat" does nothing. | The row is plain `Text` (`Views/PanelDetailView.swift:81-86`); `EventKitStore.apply` never writes `recurrenceRules` (`Store/EventKitStore.swift:255-273`). | `PanelMenu.repeats` with daily, weekdays, weekly on X, every 2 weeks, monthly (date and weekday), yearly, Custom… Write `EKRecurrenceRule` only when it changed. | M | B2: menu and Custom… (interval, weekdays, end) |
| B3 P2 | "…" next to participants does nothing. | It silently copies all addresses with a far-away toast (`Views/PanelParticipants.swift:32`). | Real menu: Email guests, Email those who have not replied, Copy emails, Copy names and emails, Open in Google Calendar. | S | B3 |
| B4 P2 | Uneven spacing; text off the icon line. | Each row is tuned by hand; repeat row lacks `minHeight: 20`, negative paddings in participants and reminders (`Views/PanelDetailView.swift:229-241, 303-313, 360-362`, `Views/PanelParticipants.swift:22,70`). | One row metric: 16 pt icon on a 20 pt first line, 6 pt padding, 32 pt minimum; no negative padding. | S-M | B4: row grid overlay |
| B5 P2 | Raw Zoom invitation in notes. | Boilerplate stripping only knows Google Meet (`CalendrKit/CallLink.swift:106-107`, `CalendrKit/EditorRows.swift:163`). | Decided: strip silently, no notice. Generalise the gate to any call host or "Please do not edit this section"; keep the stored notes intact, hide the block in the editor. | S | B5 |
| B6 P2 | Location suggestions slow; set location offers nothing. | Completer created lazily, no region, 2-character minimum (`Model/PanelV4State.swift:65-70, 255-261`); focus on a filled field only opens a menu (`Views/PanelLocationRow.swift:27-30`). | Decided: empty = "Add location"; typing = instant suggestions (prewarmed completer with a region, from the first letter); set = hover shows Open in Google Maps, Open in Apple Maps, Copy address. No map image. Commit on pick or blur, not per keystroke. | M | B6 |
| B7 / F3 P1 | No way to make multi-day events. | One date field plus times; the end is clamped to the start day (`Model/PanelState.swift:165-205`, `Model/AppModel.swift:540`). Editing a 30 h event cuts it to midnight. | End date field (Notion layout: times on one line, dates under them), keep length on start change, all-day keeps the number of days, "1 d 6 h" labels, month picker. | M | B7: Team offsite Fri 10:00 → Sat 16:00 |

## C. Grid and views

| ID | Problem | Root cause | Fix | Size | Mockup |
|---|---|---|---|---|---|
| C1 / F5 | Day view is not useful (decided: not broken). | Day view is the week grid with one 500-825 pt column; all sizes were tuned for 118 pt columns (`Views/TimeGridView.swift:13-19`); the `dayView` flag is never read (`Views/EventsCanvas.swift:14,344`). | Redesign. Variants: **timeline + focus panel** (REC: 430 pt timeline, the chosen event big with Join, reply and maps, rest of the day as a list with free time and the now line), **agenda with free time**, **fixed centred timeline**. | M (fixes) / L (redesign) | C1 + Day view tab |
| C2 P1 | A Fri 10:00 → Sat 16:00 event fills both days as tall columns. | Only `isAllDay` events go to the lane (`CalendrKit/Layout.swift:306`); the rest is split per day (`:315-326`). This also forces the 24 h fit (`Model/GridState.swift:126`). | Route timed events that cross midnight and last ≥ 12 h (REC; variants ≥ 24 h, any overnight) to the lane, chip shows "10:00". Add a layout test. | M | C2 |
| C3 P1 | The overlap "+N" stack reaches far outside the column (decided: remove it). | Stack panel is `2*dayWidth - 8` wide (`Views/GridStackPanel.swift:20,39`), ~1640 pt in Day view; "+N" chip sits at the column edge (`Model/GridInteraction.swift:39`); 2-lane cap in `OverlapV5.swift:127`. | Delete `GridStackPanel`, the "+N" chip and the lane cap. Variants: **side by side** (REC: equal columns, an event takes free columns to its right, narrow blocks show first letters; DECIDED), **compact cascade** (12 pt steps), **overlapping columns** (Google). Hover only lightens a block; a click brings it to the front and selects it. | M | C3 (Thu evening, five overlaps) |
| C4 P1 | Declined events are invisible. | Style is 13 % / 8 % tint with fg3 text (`Views/EventViews.swift:76`, `Theme.swift:236`); there is no setting UI for `showDeclined` (`Settings.swift:23`). | Verify first (log declined count in `EventKitStore.events(in:)`). Then fill 38 % → 65 %, text fg3 → fg2, struck; add "Show declined events" to Settings → General. | S-M | C4 (Neighbourhood meetup, settings row highlighted) |
| C5 P2 | All-day expand/collapse feels awkward. | No height animation (`Views/DayHeaderView.swift:185`); toggle hidden while auto-expanded (`:105`, `Views/GridDayList.swift:26`); state survives week changes (`Model/GridState.swift:30`). | Animate height, always show the chevron when rows are hidden, "Show less" under the last row, no auto-expand, reset per period. | S-M | C5 |
| C6 P2 | The right column cannot be closed. | Unconditional in `Views/RootView.swift:16`. | `rightPanelVisible` in settings, header button, ⌥⌘I (left sidebar ⌃⌘S), reopen on select/create, fix hard-coded widths (`Views/PanelClickAway.swift:42`, `Views/PanelMenus.swift:67`). | M | C6 |
| C7 P2 | Hour labels too dim. | `ink.fg3` #6A6A6A (3.9:1), Paper #918E99 (3.1:1) (`Views/TimeGridView.swift:108`, `Theme.swift:42,46`). | New `hourLabel` role: #8A8A8A dark, #6B6975 Paper. | S | Theme tab, C7 |
| C8 P2 | Grid lines too faint. | `ink.hair` 6.5 % / 7.5 % (`Views/TimeGridView.swift:72-74`). | Decided: grid lines 13 % / 14 %, all-day border 22 % / 24 %, sidebars in their own shade (#0D0D0E / #F2EFE7; reverses round 4). | S | Theme tab |
| C9 P2 | Paper looks washed out. | Low-contrast stack of Paper tokens (`Theme.swift:45-47, 226, 236-241`). | Paper+: fg2 #4A4853, fg3 #77747F, deeper bg1-3, event fill 30 %, colour darkening 30 %, past 22 %. Update `TokenTests`. | S-M | C9 |

## D. Search

| ID | Problem | Root cause | Fix | Size | Mockup |
|---|---|---|---|---|---|
| D1 P1 | Only ~Oct-Nov found. | Fixed ±365 d window (`Store/EventKitStore.swift:143,154`) and a 200-hit cap nearest to now (`CalendrKit/Search.swift:14,23-27`). | Chunked index: first today −3 / +9 months, "Search earlier" adds 6 months; no cap. Footer says what was searched. | M | D1 |
| D2 P1 | About 5 results, no "more". | ⌘K limit 5 (`Model/ChromeCommands.swift:144`), title/location only (`CalendrKit/Search.swift:52`). | ⌘K: 5 rows + "Show all N results in the sidebar"; sidebar pages 40 at a time. | S | D2 |
| D3 P1 | First search incomplete, never refreshed. | Loading looks like "no matches" (`Views/RightPanelView.swift:100-103`); every store change drops the corpus (`Model/AppModel.swift:223`). | Search state with "Searching…", stale-while-revalidate, publish partial results, refresh when loading ends. | M | D3 |
| D4 P1 | Typing lags. | Synchronous search per keystroke on the main thread, re-folding all notes (`Model/AppModel.swift:79, 632-654`). | 150 ms debounce, precomputed folded text, search off the main thread, lazy list. | M | D4 |
| D5 P2 | List starts at 10 Sep; round 2: earlier results hard to find. | Always ascending (`CalendrKit/Search.swift:28`). | Locked (round 4): earlier above upcoming with sticky "Earlier"/"Upcoming" headers, opens at Upcoming with 3 earlier rows above, "Load earlier results" at the top of Earlier. Return opens the next upcoming one. | S-M | D5 |
| D6 F | Find people. | Palette ignores guests; names from Contacts are not indexed (`CalendrKit/Search.swift:19,52`). | One index for both, with guest names, emails and resolved names; "Guest: …" line on such rows. | S | D6 ("mailbox") |

## E. RSVP, Google, menu bar, icon

| ID | Problem | Root cause | Fix | Size | Mockup |
|---|---|---|---|---|---|
| E1 P0 | Cannot decline or say maybe. | EventKit cannot reply; `canRespond` is false and the UI hides it: plain "Yes" text, an enabled-looking but inert segmented control (`Views/PanelDetailView.swift:299-315`, `Views/Components.swift:172-190`, `Views/PanelParticipants.swift:117-118`). | With Google: Yes / Maybe / No (path exists, `Store/GoogleStore.swift:343-350`; add `sendUpdates=all`). Without: visibly disabled control, "Connect Google to reply", "Open in Google Calendar". | S | E1 (Google off), toggle in the Google tab |
| E2 P2 | Menu bar menu too wide and tall. | `maxTitle 330` and widest title of 3 days set the width (`Views/MenuBarStatusItem.swift:281,297`); 3 days, no cap, one row per all-day item (`CalendrKit/MenuBarMenu.swift:135`). | **Decided: native compact menu.** Today + Tomorrow, all-day folded, 300 pt, a fixed maximum height (setting: visible rows, default 8) and the list scrolls, Join per call row, ⌘J on the current one, New event…. | S | E2 (and "Before (v4)") |
| E3 ? | Why connect Google? | Apple Calendar covers everything except reply, guests, update mails, Meet links. Sign-in is built but only tested against a fake server; the build has no client ID. Bugs: cancel shows an error toast (`Services/GoogleAccounts.swift:129`); the CalDAV copy is hidden before the first Google sync succeeds (`Store/CompositeStore.swift:42-46`). | Explain in onboarding (O1) and Settings → Accounts with a capability table. Ship a client ID, fix both bugs, test once with a real account. | S (+ setup) | E3, O1 |
| E4 P2 | Old app icon. | The locked "Now line" icon was never drawn; `design/icon/icon.svg` is v1; `scripts/make-icon.sh:9-12` skips when the `.icns` exists. | Port the Now line SVG, regenerate with `--force`, make the script compare mtimes, flush the Dock cache after install. | S | E4 (Dock) |
| O1 F | Onboarding (decided). | — | First-launch flow: fixed-size dialog over the blurred window, crossfading steps (Welcome → calendar access → choose calendars, with Connect next to the Google group → Google before/after → ready), step dots, an illustration per step, the 4 Google benefits, "Connect Google account" and "Skip, use Apple Calendar only". Remember "skipped"; Settings → Accounts keeps the Connect button. | M | O1 |

## F. Feature requests

| ID | Request | Plan | Size | Mockup |
|---|---|---|---|---|
| F1 | New event from the menu bar. | "New event… ⌘N" opens a small quick-add window that reads day and time from the text ("morgen 15 uhr"), chips to change them, Return adds, Undo in the toast. Level 1 (open the app with a draft) is the variant. | S / M | F1 |
| F2 | Join shortcut. | ⌘J joins the running call, or one starting within 15 min (`Model/ChromeCommands.swift`, `CalendrKit/Shortcuts.swift:50-64`; ⌘J is free). Show "⌘J" on every Join button and in the menu. Optional global ⌃⌘J. | S / M | F2 |
| F3 | Multi-day events. | See B7 and C2. | M | B7 |
| F4 | Create Google Meet. | Already in the Google data path (`CalendrKit/Google/GoogleMapping.swift:8,101-147`). Always show the row; disabled with "Connect Google" otherwise; treat the placeholder as pending (no Join until Google answers). | S | F4 |
| F5 | Better Day view. | See C1. | L | C1 |

## Implementation order

1. **P0 stability**: A1 (notes field, own Tab order), A3, A2(b) notes focus. Then A2(a) background store, measured with `sample` first.
2. **P0 honesty about Google**: E1 disabled state and hints, A4 link field, B1 affordance, F4 row. These are small and remove most "it does nothing" reports.
3. **P1 grid**: C2 lane routing (fixes most of the tall columns and the 24 h fit), C3 remove the stack and add side-by-side columns, C4 verify + style + setting.
4. **P1 editor**: B7 end date, B2 repeat menu.
5. **P1 search**: D5 + D6 + D2 (one small PR), D4 debounce and background, D1/D3 chunked index.
6. **Onboarding and Google**: O1, E3 bug fixes, client ID, first real-account test.
7. **P2 polish**: C7-C9 token pass (one commit, `TokenTests`), C5, C6, B3-B6, E2 native menu, E4 icon, F1, F2.
8. **Day view redesign** (C1/F5) after the user picks a variant.

Nothing is open: every item is decided and built in.
