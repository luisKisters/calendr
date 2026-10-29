# Calendr v4 implementation plan
Target: `design/mockup-v4/DECISIONS.md` (rounds 1 to 5 and the round-4 design system). Reference: `design/mockup-v4/index.html` (`LOCKED` :913, `DECISIONS` :919, `PALETTES` :782, `layoutDay()` :1083, `.ds` block :595–686, `evVars()` :1003). This plan changes no code.

## 1. Facts checked in the code
Most of the explorer findings are correct. These points differ or add detail:

| Item | What the code shows |
|---|---|
| Sidebar background | It already uses `Theme.bg` (`SidebarView.swift:30`). `#121216` is the colour of the checkbox tick (`:306`). The sidebar hairline is `hair2`. The mockup uses `hair`. |
| Duplicated colours | Dark ink hex values are in `Theme.swift:31-42`, again in `EventPainter.Ink` (`EventsCanvas.swift:230-240`) and again in `Palettes.bg/fg/fg2` (`Theme.swift:153-155`). The "thumb" colour is in `Components.swift:188` and again in `PanelControls.swift:15`. |
| Segmented copies | `Segmented` (`Components.swift:134`) and `PanelRSVP` (`PanelControls.swift:150`) contain the same code. `ViewTabs` (`CenterView.swift:123`) shows text tabs with an underline. Settings uses `Segmented` and one `ActToggleStyle` toggle (`Overlays.swift:354-372`). |
| Radii | Control 7, row 7, chip 5, and the surface uses `Radius.surface + 2` = 14 (`Overlays.swift:38`). The target is 6 / 8 / 12. |
| Type | Instrument Sans is used for all text (`Typeface.swift:105`), at sizes 22 / 16 / 13 / 11.5 / 10.5. The target is SF Pro for 12.5 and 11.5 text, and Instrument Sans 600 only for 18 pt titles (month, event title, Today, dialogs; mockup :1595). |
| Area ownership | There is already a pattern for parallel work. `GridV3State`, `PanelV3State` and `ChromeV3State` are structs on `AppModel`, one per area. Each area also has its own snapshot hook: `SnapshotGrid`, `SnapshotChrome`, `SnapshotPanel` and `SnapshotMenuBar`. |
| EventKit | EventKit can read the organizer, the role and the status of every attendee. `makeEvent` drops them (`EventKitStore.swift:172-178`). It can write more than one alarm, but `apply` removes all alarms and adds one back (`:253`). It cannot write attendees or RSVP. |
| Compare pipeline | `compare-all.sh` reads `design/mockup-v2/shots`, which does not exist. `mockup-v4` has no shots folder. You open a mockup scene with `index.html#<scene>`. Extra picks use `&key=value`. The picks are kept in `localStorage`. |
| Mockup frame | `.desk` is 1440×928 and includes a fake 28 px menu bar. The hour height is H = 46, the gutter is 58 px (the app uses 56), and "now" is Sun 4 Oct 15:10. The people are Sam Rivera and others. |
| App demo data | Alex Rivera, with "now" at Tue 29 Sep 11:48. Ten test files use these titles ("Public Policy", "Sam / Alex"). |
| Short item rule | In the mockup an item is short when it lasts 15 min or less (`isShort`, :1054). A short item draws as a block 22 min tall. |

## 2. Conflicts and how this plan resolves them
1. Typeface. DECISIONS wins. Use SF Pro (the system font, `monospacedDigitSystemFont` for times) for all 12.5 and 11.5 text and for events. Use Instrument Sans 600 only for 18 pt titles. Update the README line "Instrument Sans throughout". This needs confirmation (Q3).
2. SPEC "copy Notion 1:1". This rule ended with v3. Change SPEC to "mockup-v4 and DECISIONS.md are the visual truth". The README identity text stays as it is, except the font and palette lines.
3. README "Google API out of scope" conflicts with the locked "Google Calendar API + Contacts". Phase 8 reverses the README rule. It needs a client ID from the user (Q1).
4. Order of authority: DECISIONS.md, then the mockup `LOCKED` picks with the `.ds` CSS, then README, then `design/LOCKED.md` (v3), then SPEC.

## 3. Phases in dependency order
| # | Phase | Area (lane) | Needs | Size |
|---|---|---|---|---|
| 0 | Tooling: mockup shots, compare, v4 fixture | TOOLS | none | M |
| 1 | Design tokens and one Segmented | SHARED UI | 0 | L |
| 2 | Data model: replies, attendees, reminders, call links | KIT | 0 | M |
| 3 | Overlap layout v5 (pure algorithm) | KIT | 0 | M |
| 4 | Event rendering and all-day chip styles | GRID | 1, 2 | M |
| 5 | Grid integration: v5 layout, "+N", stack panel, all-day mix | GRID | 3, 4 | L |
| 6 | Chrome: sidebar, right column, header, menus, settings | CHROME | 1 | M |
| 7 | Event editor | PANEL | 1, 2 | L (split into 7a and 7b) |
| 8 | Apple Contacts, Google Calendar API, Google People API | SERVICES | 2; its UI needs 6 and 7 | L (split into 8a, 8b, 8c) |
| 9 | Menu bar call logo and Join | MENUBAR | 1, 2 | S |

Rules for every PR:
- `scripts/verify.sh` passes. PRs that touch the grid must also pass the full run with `--perf`.
- Append each new snapshot state to `design/states.json` and to the snapshot hook of the PR's area.
- Update the README in the same PR when behaviour or a flag changes.

### Phase 0: Tooling (M)
- Goal: compare app pixels with mockup-v4 for every scene, using the same data.
- Files:
    - New `scripts/render-mockup.swift`. Use the `render-svg.swift` pattern with `WKWebView`. Use a non-persistent `WKWebsiteDataStore` so that the `LOCKED` picks apply. Load with `loadFileURL(allowingReadAccessTo:)` set to the repo root, because the font path is `../../Sources/...`. Wait for `document.fonts.ready`. Run an optional `js` step to open popovers (for example, click `[data-pop=evmore]`). Crop the top 28 px. Write `design/mockup-v4/shots/<scene>.png`.
    - `scripts/compare-all.sh` reads `mockupDir` from `states.json`. Remove the mockup-v2 references.
    - `scripts/compare.py` writes a mean-difference score to `artifacts/compare/report.json`. This is a report only, not a gate.
    - `design/states.json`: add `mockupDir`, plus `mockup`, `js` and `fixture` for each state.
    - New `Sources/Calendr/Store/DemoDataV4.swift`. Port `CALS0`, `ACCTS0`, `RAW`, `RAW_AD` and `seedEvents()` exactly (mockup :800–899). Keep the mockup values `yes/maybe/no/none` in a fixture-local enum with one mapping function. Until Phase 2, `none` maps to `.confirmed`; add a comment that says this.
    - `LaunchOptions.swift`: add `--fixture v4`, which pins 2026-10-04T15:10 and an hour height of 46.
- Kit or app: app and scripts only.
- Tests: `FixtureV4Tests` (CalendrTests) checks these points:
    - The week has the mockup counts of timed and all-day events.
    - Wednesday has "Flat cleaning" and "Club board meeting".
    - Every address uses a reserved example domain.
    - `AuditTests` add: every `states.json` entry exists in a snapshot hook, and every `mockup` entry has a shot file.
- Snapshot states: `v4-week`, `v4-overlap`, `v4-status`, `v4-event`, `v4-cmd`, `v4-settings`, `v4-menubar`, `v4-delete`. These scenes can be reached now. Later phases add the remaining scenes.
- Acceptance: `compare-all.sh` writes 8 triptychs and a JSON report. The old states still render.

### Phase 1: Design tokens (L)
- Goal: one source of tokens, from the mockup `.ds` block and `PALETTES` 'oled'.
- Files: `Theme.swift`, `Typeface.swift`, `Components.swift`, `CenterView.swift` (ViewTabs only), `PanelControls.swift` (remove `PanelRSVP` and `panelThumb`), `Overlays.swift` (surface radius, settings switches), `EventsCanvas.swift` (only the `Ink` struct, which must use Theme RGB values), `scripts/verify.sh` (grep gates). Make mechanical font and radius changes in the other views.
- Steps:
    1. Add an `InkRGB` table. Dark OLED: bg `#000000`, bg1 `#0A0A0A`, bg2 `#141414`, bg3 `#1F1F1F`, pop `#0C0C0C`, fg `#F2F2F2`, fg2 `#A0A0A0`, fg3 `#6A6A6A`. Hair is fg at 6.5 %, hair2 is fg at 13 %, hover is fg at 5.5 %, thumb is mix(bg3, fg, .08), live is `#FF453A`, act is fg and onAct is bg. Light stays Paper (Q4). Derive `Theme` colours, `EventPainter.Ink` and `Palettes` from this table.
    2. Add a new `Theme.pop` for menus and dialogs. `Theme.bg2` is for fields.
    3. Type tokens: `.title18` (Instrument Sans 600), `.text` (SF 12.5/400), `.small` (SF 11.5/400), `.event` (SF 11.5/500), and tabular variants. Switch `TextCache.Kind` fonts to SF. Remove the 22, 16, 13 and 10.5 sizes. `MicroLabel` becomes sentence case with fg3.
    4. Metrics:
        - `Dim.row` 28, `Dim.field` 32.
        - `Dim.iconButton` 26 with a 16 icon; `Dim.iconButtonSmall` 22 with a 14 icon.
        - `Dim.hourGutter` 58.
        - `Space` 4/8/12/16/24.
        - `Radius` row 6, control 8, surface 12. Remove chip 5 and the +2.
    5. One `Segmented`: hairline frame (inset 1 pt, hair2), padding 2, radius 8. Segments are 22 pt high with radius 6 and a horizontal padding of 10. The selected segment has a thumb fill and fg 600 text. The other segments have fg2 400 text and a hover fill. Use it for ViewTabs, Going? and the settings switches.
    6. `Keycap` becomes grey hint text with no box (round 3).
    7. Grep gates in `verify.sh`:
        - No hex literals in `Views/`. Allowed exceptions: `Theme.swift` and the art in `MenuBarViews.swift`.
        - No `.ui(<number>` outside `Typeface.swift`.
        - No `cornerRadius:` with a number literal.
- Kit or app: app only.
- Tests: `TokenTests` (CalendrTests):
    - Read the 'oled' line of `PALETTES` from `index.html` (path from `#filePath`) and compare it with `InkRGB.dark`.
    - `EventPainter.Ink.of(true).bg` is equal to the Theme bg.
    - There is only one Segmented type. Use a source grep in the test, the same way as the existing audit tests.
- Snapshots: re-render all states. Add none.
- Acceptance:
    - The compare report score for `v4-week` drops.
    - The grep gates pass.
    - The background of the window, the sidebar and the right column is pure black.

### Phase 2: Data model (M)
- Goal: replies, the organizer, more than one reminder and call links in `CalendrKit`.
- Files: `CalendrKit/Models.swift`, `EventKitMapping.swift`, `MenuBarMenu.swift` (move `videoURL` out), new `CalendrKit/CallLink.swift`, new `CalendrKit/Attendee.swift`. In the app: `EventKitStore.swift` (`makeEvent`, `apply`), `DemoStore.swift`, `DemoData.swift`, `DemoDataV4.swift`.
- Steps:
    1. Add `ResponseStatus.needsAction`. The compiler then shows every `switch` that must change (37 uses).
    2. Add `Attendee { email, name?, isOrganizer, isMe, isOptional, status }` and `CalendarEvent.attendees`. Make `participants` a computed `[String]` until Phase 7 removes it.
    3. Add `CalendarEvent.myReply` and `isUnaccepted` (declined or needsAction). The organizer counts as accepted, the same as `myResp` in the mockup (:1056).
    4. Add `reminders: [Int]` (unique, sorted). `reminderMinutes` becomes computed (the first value). EventKit reads all alarms and writes all alarms.
    5. `CallLink.parse(conferencing:notes:location:)` returns kind (meet, zoom, teams or other), URL and code. `CallLink.stripMeetBoilerplate(notes)` returns the clean notes and a `hadMeet` flag (mockup `BOILER` :857).
    6. Mapping: `pending` maps to `needsAction`, but only when I am an attendee. EventKit maps `ev.organizer`, the attendee roles and the attendee statuses.
- Tests (`ModelV4Tests`, CalendrKitTests):
    - pending maps to needsAction.
    - An event where I am the organizer maps to confirmed.
    - A canceled event maps to declined.
    - Alarms `[-600, -3600, +60]` give `[10, 60]`.
    - Meet code from the boilerplate.
    - Zoom on a subdomain.
    - A website URL gives no call.
    - Stripping the boilerplate keeps the user's text.
- Snapshots: none. The fixture now gives true `needsAction` values.
- Acceptance: all 195 or more tests pass. In the v4 fixture, "Club board meeting" has `myReply == .needsAction`.

### Phase 3: Overlap layout v5, pure (M)
- Goal: port `layoutDay()` with the locked picks: smart, quiet, right, stack, block.
- Files: new `CalendrKit/OverlapV5.swift`. Do not edit `Layout.swift` in this phase. Phase 5 changes the call site.
- API: the input is `[V5Item(id, start, end, isShort, isUnaccepted)]` with Bool flags, so there is no dependency on Phase 2 types. The output is `V5Placement(id, left, width, indent, level, cut)` and `[OverflowGroup(start, ids)]`.
- Rules (with the mockup lines):
    1. Sort by start time. When two items start together, the longer item goes first. A short item (15 min or less) spans 22 min.
    2. Accepted blocks: if 2 or more placed blocks cover this start time, the item goes to overflow (:1121).
    3. When the item starts less than 30 min after the start of the host group, it joins the group. The group width is split evenly, and every member after the first is cut (:1122–1126).
    4. In other cases the item cascades: level + 1, the same left edge, the remaining width, and an indent of +14 pt (:1127–1131).
    5. Unaccepted items:
        - When nothing overlaps, the item gets the full width.
        - When an item that is already on the right half overlaps, the item goes to overflow.
        - In other cases, accepted items that start within 30 min shrink to the left half. The unaccepted item gets left .5, width .5, level 8 and cut (:1147–1155).
    6. Short items:
        - When 2 or more blocks cover the start time, the item goes to overflow.
        - When the item is in the first 30 min of a block (from −10 to 30), the block shrinks to .66 and the item sits at .66.
        - In other cases the item sits at .5 when something overlaps it, or at 0 when nothing does. It gets level 9 (:1157–1165).
    7. Overflow groups join when they start within 30 min of each other (:1258). Add `OverflowGroup.busyRange(...)` and `stackRows(dayEvents:)`, which return every event that overlaps the busy range, sorted by start time (:1510–1516).
- Tests (`OverlapV5Tests`): one test for each rule above. Also:
    - The v4 fixture Wednesday from 17:00 to 21:30 gives one "+1" group at 18:15.
    - Recommended: a golden JSON file, `Tests/CalendrKitTests/Fixtures/layout-v4.json`. Produce it once with `render-mockup.swift --eval "JSON.stringify(...layoutDay...)"`. Then add `resources:` to the test target in `Package.swift`.
- Acceptance: the tests pass. A benchmark of 60 events per day stays below 1 ms.

### Phase 4: Event rendering (M)
- Goal: solid blocks, all reply states, and the text rules.
- Files: `EventsCanvas.swift` (`EventPainter.draw`), `EventViews.swift` (`EventStyle.reply`), `Theme.swift` (`Palettes` only), `MonthView.swift` (`MonthPainter`), `DayHeaderView.swift` (`AllDayPainter` chip style, today accent pill), new `CalendrKit/BlockText.swift`.
- Colours (`evVars`, solid and polish, :1008–1015; `cc` is the calendar colour):

| State | Fill | Bar | Title | Time |
|---|---|---|---|---|
| Normal | mix(bg, cc, .34) | cc | fg | fg2 |
| Past (p2) | mix(bg, cc, .15) | mix(bg, cc, .32) | fg2 | fg3 |
| Not answered | bg | as normal | fg | as normal |
| Maybe | 135° stripes, 6 px fill / 6 px mix(fill 55 %, bg) | as normal | as normal | as normal |
| Declined | mix(fill 38 %, bg), solid | at .45 | fg3, struck | fg3, struck |

- Other states:
    - "Not answered" also has a 1 px solid outline in `dash` = mix(bg, cc, .75).
    - A cut block has a 1.5 pt ring in bg.
    - A selected block has a ring of 1.5 pt bg plus 3 pt fg.
- Text rules: add `BlockText.plan(height:width:isShort:)` in the kit. It returns the line mode, the maximum title lines, the time format (range, start or none) and whether the text is centred.
    - Under 30 pt: one line. Under 22 pt: centred.
    - Under 52 pt: the title has one line.
    - Under 40 pt: compact padding.
    - Narrower than 56 pt: one line with an ellipsis, and a one-line block hides the time.
    - The time shows as a range only when width − 17 ≥ 62. In other cases it shows the start time.
    - Hyphenate at syllables with `CFStringGetHyphenationLocationBeforeIndex` in `TextCache.wrapped`.
    - The title always starts at the top.
- Tests: `BlockTextTests` (kit) uses the mockup thresholds. `PaletteV4Tests` (app) checks the fill, bar, title and time for each state against the formulas above.
- Snapshots: `v4-status`. Re-check `v4-week`.
- Acceptance:
    - The `v4-status` triptych shows the same fill for each state.
    - The perf p95 stays within the current budget, because the stripes are drawn once per block with a clip.

### Phase 5: Grid integration (L)
- Goal: the v5 layout on screen, the "+N" chip, the stack panel and the all-day mix section.
- Files:
    - `CalendrKit/Layout.swift`: `RangeLayoutBuilder.pack` calls OverlapV5, and `RangeLayout.overflow` holds the groups for each day. The layout is in minutes, so `repacked()` has no work to do.
    - `TimeGridView.swift`, `GridInteraction.swift`, `GridV3State.swift` (`stack: StackRef?`, `allDayExpanded`), new `Views/GridStackPanel.swift`, `DayHeaderView.swift` (`AllDayView`), `SnapshotGrid.swift`.
- "+N" chip: 16 pt high, radius 8, bg3, fg 600 11.5. It sits at right 3 and top = start + 2. On hover or when open, the colours invert.
- Stack panel:
    - Use the pop surface with radius 12 over the day column, at the top of the busy range. The width is 2 columns − 8.
    - Rows are at least 28 pt high, with a 76 pt time column, the title, and the reply text ("declined", "no reply", "maybe"). Each row uses the reply-state fill from Phase 4.
    - A click on a row selects the event. Esc or a click outside closes the panel (`PanelClickAway`).
- All-day mix:
    - Show 2 lanes, with a "+N more" in lane 3 for each day.
    - The gutter has an expand and a collapse icon.
    - When expanded, the height is min(lanes, 4.5) × 21 + 9, and the section scrolls.
    - Chips are 18 pt high with radius 6 and the reply styles. `GridDayList` stays for the month view only.
- Tests:
    - `GridV5Tests` (app): the fixture gives the overflow group at Wednesday 18:15. Opening the stack lists the rows in time order with their replies. Esc closes the stack.
    - The all-day hidden counts for each day.
    - The expanded height formula.
- Snapshots: `v4-overlap`, `v4-overlap-stack` (`js` clicks "+1"), `v4-allday-expanded`.
- Acceptance: the triptychs match. The full `verify.sh` passes with `--perf` and `--walkthrough`. Update any walkthrough assertion that depends on the v3 cascade.

### Phase 6: Chrome (M)
- Files: `SidebarView.swift`, `RightPanelView.swift`, `CenterView.swift`, `Overlays.swift` (command menu, settings sheet, surfaces), `ChromeV3State.swift`, `ChromeCommands.swift`, `CalendrKit/Shortcuts.swift`, `SnapshotChrome.swift`.
- Steps:
    1. Sidebar: width 236 and bg, with a `hair` edge (the same as the right column). Glyphs start at 16, text at 40, and trailing buttons end at 220. Rows are 28 pt with 14 pt icons. The account header shows the name without the domain. The Settings footer row is 28 pt with a grey hint.
    2. Right column, 320 pt:
        - At the top is a search field: 32 pt high, bg2, radius 8. The box edge is at 8 and the content edge at 20.
        - While you type, the search results replace the Today content, grouped by day (mockup :1288–1292).
        - Then "Today" (title 18), the Now and Up next cards with Join, and the Later rows at 28 pt.
        - Then "Useful shortcuts": Command menu ⌘K, Meet with F, New event C, Menu bar calendar ⌃⌘K, Toggle sidebar `, All keyboard shortcuts ?.
        - There is no frame around Today and there are no panel separators.
    3. Header: the month title in 18 pt Instrument Sans and ViewTabs as a Segmented. Remove `SearchButton`. `/` and ⌘F focus the right-column field.
    4. Menus and dialogs: `Theme.pop`, radius 12, a clear hairline, 28 pt rows. Menus that open from the right column end 8 pt to its left.
- Tests:
    - `ChromeV4Tests`: `/` sets `chromeState.searchFocused`. A query switches the column to results grouped by day.
    - Kit: `Shortcuts.useful` contains the 6 entries in order. `AccountName.display("sam@northwind.example") == "sam"`.
- Snapshots: `v4-week`, `v4-search`, `v4-cmd`, `v4-settings`.
- Acceptance: the column edges match the alignment check in the mockup (press G).

### Phase 7: Event editor (L). Split into 7a (fields) and 7b (people and send)
- Files: `PanelDetailView.swift`, `PanelControls.swift`, `PanelV3State.swift`, `SnapshotPanel.swift`, and new files: `Views/PanelParticipants.swift`, `Views/PanelCallRow.swift`, `Views/PanelLocationRow.swift`, `Views/PanelCalendarMenu.swift`, `Views/DeleteWithGuestsDialog.swift`. `Overlays.swift` gets only a one-line registration; tell the CHROME lane about it. Kit: `CalendrKit/EditorRows.swift`, `CalendrKit/MapLinks.swift`.
- 7a: grid, fields, call, location, reminders, calendar menu
    - Panel grid: the icon column is 20 to 36 pt and the text column starts at 48. The line box is 20 pt. Fields and hover boxes bleed 8 pt.
    - Row order: title (18), when, repeat, "Find a new time", participants, Going?, call, location, notes, calendar, reminders.
    - Every row is always present. An empty row shows a placeholder in fg3. Remove `PanelAddChip` and the "+ Add" `PanelFlow`.
    - Call: a big Join button (32 pt, radius 8, act, call logo) with an editable link field under it. When the notes contain the Meet boilerplate, hide it and show one line "Google Meet details hidden".
    - Location: suggestions from `MKLocalSearchCompleter` (MapKit is a system framework). A click opens a menu: Apple Maps, Google Maps, Copy.
    - Reminders: a list of rows, each with a remove button, and an "Add reminder" row.
    - Calendar and colour: one menu, 224 pt wide. Account headers have no domain. Swatches are in a 6-column grid of the 11 Google colours.
- 7b: participants, Going?, send and delete
    - Each person has one row: reply mark (14 pt), name, role in grey ("organizer", "optional"). There are no pictures. My own row expands to Going · Maybe · Decline.
    - Going? (Yes · Maybe · No, with its own icon) sits above the call row. It is read-only when the store cannot write RSVP.
    - Bare addresses: a row "N without a name · Allow Contacts". This needs Phase 8a.
    - Unsent changes: edits to an event with guests stay in the editor state until you send them. The footer shows "Not sent yet", a split button "Send update | ▾ Save without sending" (⌘↩) and Discard. This needs a store capability, `canSendUpdates`. EventKit shows a plain Save.
    - Delete with guests opens a modal with the guest list, "get a cancellation email", Cancel and a red split button "Delete event | ▾ without email".
- Tests:
    - `EditorRowsTests` (kit): the row order. Empty rows are present.
    - `MapLinksTests`: encoding for Apple and Google.
    - `PanelV4Tests` (app):
        - A buffered edit does not reach the store before Send.
        - Send calls `update` with `notify: true`. "Save without sending" uses `false`. Discard restores the event.
        - Reminders stay unique and sorted.
        - Delete with guests opens the dialog. Delete without guests keeps the current flow.
- Snapshots: `v4-event`, `v4-invited`, `v4-call`, `v4-location`, `v4-maps`, `v4-calendar`, `v4-reminders`, `v4-guests`, `v4-invite`, `v4-pending`, `v4-delete`.
- Acceptance: the triptychs match. The walkthrough passes after you update its editor steps.

### Phase 8: Contacts and Google (L). Three PRs
- 8a: Apple Contacts (S/M)
    - Add `Services/ContactsResolver.swift` (`CNContactStore`, email to name, with a cache).
    - Add `NSContactsUsageDescription` in `build-app.sh` and `com.apple.security.personal-information.addressbook` in `Calendr.entitlements`.
    - Kit: a `NameResolver` chain (Apple, then Google, then the bare address).
    - Settings: a "Contacts" section.
    - Tests: the chain order, and the fallback when access is denied (with a fake).
    - Snapshot: `v4-contacts`.
- 8b: Google Calendar (L)
    - Kit:
        - `GoogleMapping`: JSON DTO to `CalendarEvent`. It maps attendee statuses, `self`, the organizer, `conferenceData.entryPoints`, reminder overrides and `useDefault`, `colorId` to hex, and RFC 3339 and all-day dates.
        - A PKCE helper using CryptoKit.
        - A sync-token state machine: on 410, run a full resync.
    - App:
        - `GoogleAuth`: `ASWebAuthenticationSession` with PKCE and a reversed-client-ID URL scheme in `CFBundleURLTypes`. Refresh tokens go in the Keychain, one per account.
        - `GoogleCalendarAPI`: `URLSession` and `Codable` behind an `HTTPClient` protocol.
        - `GoogleStore: CalendarStore`. It writes RSVP (a patch of the `self` attendee only) and guests, uses `sendUpdates=all|none` for the split buttons, and requests a new Meet link with `conferenceDataVersion=1`.
        - `CompositeStore`: EventKit for iCloud and local calendars, plus Google. Hide EventKit CalDAV sources that duplicate a connected Google account.
        - Poll every 60 s, when the window gets focus, and on ⌘R. Keep a disk cache in Application Support.
    - Tests:
        - JSON fixtures in `Tests/CalendrKitTests/Fixtures/google/`.
        - The PKCE test vector from RFC 7636.
        - 410 resets the sync state.
        - `GoogleStoreTests` with a fake HTTP client: the RSVP patch body and the `sendUpdates` query.
        - No network in `swift test` or in `verify.sh`.
- 8c: Google People API (M)
    - Read `people.connections` and `otherContacts`, with read-only scopes. Use them for names and for guest suggestions.
    - Tests: mapping and merge with a fake.
    - Snapshot: `v4-settings-accounts`.

### Phase 9: Menu bar (S)
- Files: `MenuBarStatusItem.swift`, `MenuBarViews.swift`, `CalendrKit/MenuBarMenu.swift`, call-logo art (vector in code or a bundled PDF).
- Steps:
    - The head row of the current or next event uses an `NSMenuItem.view` (`NSHostingView`) with a Join button: 28 pt, radius 8, act, with the call logo (Q5).
    - `MenuBarMenu` uses `CallLink` from Phase 2.
- Tests: `MenuBarV4Tests`: a Meet event gives Join with kind `.meet`. A Zoom event gives the Zoom logo. A website URL gives no Join.
- Snapshot: `v4-menubar`.

### Clean-up PR (S, last)
- Move the app tests to the v4 fixture. Remove `DemoData.swift` (v3) and the references to mockup-v2 and mockup-v3.
- Rename the `*V3State` types.
- Update `design/LOCKED.md` so that it points to DECISIONS.md.

## 4. Parallel work (file ownership)
| Wave | Lanes that can run at the same time | Owned files |
|---|---|---|
| 1 | Phase 0 alone | `scripts/*`, `states.json`, `DemoDataV4.swift`, `LaunchOptions.swift` |
| 2 | Phase 1 (SHARED UI) ‖ Phase 2 (KIT) ‖ Phase 3 (KIT, new file only) ‖ Phase 8a kit part | P1: `Theme`, `Typeface`, `Components` and the view styling. P2: `Models`, `EventKitMapping`, `CallLink`, stores. P3: `OverlapV5.swift` only. |
| 3 | Phase 4 (GRID) ‖ Phase 6 (CHROME) ‖ Phase 7a (PANEL) ‖ Phase 9 (MENUBAR) ‖ Phase 8b services (no UI) | GRID: `EventsCanvas`, `EventViews`, `TimeGridView`, `GridInteraction`, `DayHeaderView`, `MonthView`, `GridDayList`, `GridV3State`, `Layout.swift`. CHROME: `SidebarView`, `RightPanelView`, `CenterView`, `Overlays`, `Chrome*`. PANEL: `Panel*`. MENUBAR: `MenuBar*`. SERVICES: `Store/`, `Services/`, `build-app.sh`, entitlements. |
| 4 | Phase 5 (GRID) ‖ Phase 7b (PANEL) ‖ Phase 8c, then the 8b UI wiring (after 6 and 7b) | as above |

Shared hot spots and their rules:
- `Theme.swift`, `Components.swift` and `Typeface.swift` belong to Phase 1. After Phase 1, other lanes only add new tokens at the end of a file, in a separate commit.
- `AppModel.swift`: each lane adds at most one stored property line. Put the logic in an extension file for the lane's area.
- `states.json` and `SnapshotStates.all`: add entries at the end only. Each lane writes its states in its own `Snapshot<Area>.swift`.
- `Package.swift`: only Phase 3 and Phase 8b edit it (test resources). Merge these two edits one after the other.
- Phase 1 must merge before wave 3 starts, because it touches every view.

## 5. Risks and open questions
1. Google OAuth client. Who owns the Google Cloud project and the OAuth client ID? The calendar and contacts scopes are "sensitive". Without Google verification, the app shows a warning screen and allows at most 100 test users. Is an unverified client for personal use acceptable at first?
2. EventKit as a source. The plan keeps EventKit for iCloud and local calendars and hides Google accounts that are also connected through the API. Is that correct, or must Google go only through the API? Until 8b ships, Going? and guest editing stay read-only for real accounts.
3. Typeface. The plan uses SF Pro for text and Instrument Sans only for 18 pt titles, as DECISIONS locks. The README v3 identity says the opposite. Confirm.
4. Light theme. v4 locks only OLED black. Keep Paper as the light theme with the new token roles, or remove light mode?
5. Menu bar. The mockup shows a custom popover. The app uses a native `NSMenu`. The plan keeps `NSMenu` and adds one custom-view row for Join. Do you want a full popover instead?
6. Pixel gate. Text rendering differs between WebKit and CoreText. The plan makes the compare a report only. Do you want a threshold gate in `verify.sh`, and when can the v3 fixture and its tests go?

More risks, with no question:
- The stripes and the hyphenation can affect the perf budget. Measure in Phase 4.
- The walkthrough assertions depend on the v3 cascade and the v3 editor. Update them in Phases 5 and 7.
- Google sync has quotas. Polling every 60 s with a sync token stays far below them.

## 6. How this codebase maps to web concepts
- A SwiftUI `View` struct is like a React function component. `body` is the JSX it returns, `@State` is `useState`, and `@Environment(AppModel.self)` is `useContext`.
- `AppModel` (`@Observable @MainActor`) is the app store. Views re-render when a property they read changes, as in MobX or Zustand selectors. `GridV3State`, `PanelV3State` and `ChromeV3State` are store slices.
- `CalendrKit` is a pure `lib/` package with no UI and no I/O, like a Python module tested with pytest. `Calendr` is the app that uses it.
- `Package.swift` is `package.json` or `pyproject.toml`, and its targets are like workspaces. It has no dependencies, so there is no `node_modules`.
- `swift build` is like `next build` or `tsc`. `swift test` with Swift Testing (`@Test`, `#expect`) is like vitest or pytest.
- `scripts/verify.sh` is the CI pipeline: grep "lint" gates, build, tests, app bundle, snapshots, E2E, perf.
- `--snapshot <state>` with `states.json` is like Playwright screenshots of named Storybook stories. `compare-all.sh` is the visual-regression diff. `--walkthrough` is a Playwright E2E run with video.
- `EventsCanvas` and `EventPainter` are `<canvas>` 2D draw code in CoreGraphics. `TextCache` is a memoized `measureText`.
- `CalendarStore` is a TypeScript interface for a data layer. `DemoStore` is a mock adapter (like MSW) and `EventKitStore` is the real API client.
- `Theme.swift` is the CSS custom-properties file. `Color.dyn` is a `prefers-color-scheme` switch. `Info.plist` and the entitlements file are the app manifest and its permissions.

## Critical files
- `Sources/Calendr/Views/Theme.swift`
- `Sources/Calendr/Views/EventsCanvas.swift`
- `Sources/CalendrKit/Layout.swift` (and the new `OverlapV5.swift`)
- `Sources/CalendrKit/Models.swift`
- `Sources/Calendr/Views/PanelDetailView.swift`
