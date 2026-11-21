# Horion menu bar v2: decisions

Focused round on the menu bar menu (the NSMenu from `MenuBarStatusItem.swift`). It follows
`design/the v3 menu bar proposal`, which is still unlocked. Open the mockup with `open design/menubar-v2/index.html`.

Design read (tasteskill): a preserve-redesign of a native macOS menu for one daily user, in a quiet
Apple / Notion Calendar language, on NSMenu metrics and SF Pro. Dials: variance 2, motion 2, density 6.

## Round 1 (2026-11-21): open

The feedback came with a screenshot of the menu on Sat 21 Nov: about 35 rows over three days.

| Decision | You said | Options (first = recommended) |
|---|---|---|
| The arrow on some rows | "also this thing with the arrow looks off" | Icon after the title · No row menus, Join on the highlighted row · Arrow only on the highlighted row · Every event row has an arrow · As it is today |
| End time | "this looks bad and buggy" | On the right edge, none when the event has no length · Range next to the start · Start only · As it is today |
| How much the menu lists | "way to big" | The rest of today, then one row per day · Today and tomorrow, 6 rows each · As it is today |
| The same event in two calendars | "this looks bad and buggy" | One row with a two-colour bar · One row, first calendar's colour · As it is today |
| The countdown | "way to big" | Once, in the "Now" line · Only on the row · As it is today |

Every option except "Every event row has an arrow" and "As it is today" needs custom row views in the app
(`NSMenuItem.view`). A plain NSMenu draws the submenu arrow in its own right-hand column, on any row
that has a submenu.

## Round 2 (2026-11-21): open

Your notes on elements in the mockup. You didn't paste any picks, so the round 1 decisions stay open.

| Decision | You said | Options (first = recommended) |
|---|---|---|
| End time (reopened) | "what is this fkn time there ? i dont like that i think" | Start only · Start only, end on the highlighted row · Range · Right edge (round 1) · As it is today |
| Where long titles are cut (new) | "make sure the text doesnt expand too much … for some of my events it clipped way too late" | 220 px · 180 px · 260 px (round 1) · 330 px (today) |
| Shortcuts in the menu (new) | "we cant just simply blatantly copy the same shortcuts they need to be ones that arent reserved" | Only ⌘, and ⌘Q · Plus Horion's own ⌃⌘K on Open Horion · None · As it is today |
| How much the menu lists (more options) | "but this is too much" | The next 2 events, then one row per day · Rest of today, then one row per day (round 1) · Today and tomorrow, 6 rows each (round 1) · As it is today |

## Round 3 (2026-11-21): open

| Decision | You said | Options (first = recommended) |
|---|---|---|
| Between the title and the time left (new) | "there needs to be a good sepeator between event name and the time thing" | A middle dot, the time a little dimmer · A thin vertical line · The time in a soft capsule · No mark, only a dimmer time |
| How much the menu lists (new first option) | "generally show tmr as well only do the show x more when the thing take up more than 50% of the macs screen" | Today and tomorrow in full; "x more" only past half the screen · the earlier options |

"Half the screen" in the app means half of `NSScreen.visibleFrame.height` of the screen the menu opens on.
Rows that don't fit go into an "N more tomorrow ›" row, and its submenu lists them.

## Fixed without a decision
- "make the x time left not red pls": the countdown is no longer red anywhere. In the menu bar item it uses the title's colour; in the menu it is grey.
- "here i also want to be able to change my rsvp": "Call with Jo" now has a guest, so its menu shows Going? Yes / No / Maybe. **In the app:** EventKit cannot set your own RSVP (`canChangeResponse` is true only for the demo store). Changing it means going through the account's API (Google Calendar, CalDAV) or handing off to Calendar.app.
- Titles are cut at 260 px instead of 330 px, so a long `[P0?] …` title no longer sets the width of the whole menu.

## Locked (2026-11-21, "sounds good to me inplimenet it": the recommended options)
- Between the title and the time left: a middle dot, the time a little dimmer
- The arrow on some rows: no arrows; a small camera or people icon after the title (custom row views, `MenuBarRowView`)
- End time: start only
- Where long titles are cut: at 220 pt
- Shortcuts in the menu: only ⌘, and ⌘Q
- How much the menu lists: today and tomorrow in full, the day after as one row; "N more" only past half the screen
- The same event in two calendars: one row, its bar in both colours
- The countdown: once, in the "Now" line, never red

Built in `Sources/HorionKit/MenuBarMenu.swift` (`MenuBarMenu.lines`) and `Sources/Horion/Views/MenuBarStatusItem.swift`.
