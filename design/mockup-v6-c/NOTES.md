# v6 · C "Warm editorial": designer notes

Status: done. Serve: `node design/mockup-v6-c/serve.mjs 8798` (tailnet: https://<tailnet-host>:8798/).
Contrast table: `node design/mockup-v6-c/contrast.mjs` (`--fails` for misses only). The page and the script read the same `tokens.js`.

## Intent
A calm personal planner that reads like a well-printed diary, not a dashboard. Warm neutrals, Paper is the
default, Dark is a first-class "warm night" (not OLED black). One voice: Geist for the UI, a serif
(Newsreader) only for page titles. Hierarchy comes from type voice and space, not from weight, borders or colour.
Every locked behaviour from FEEDBACK.md stays; only the visual system changes.

How C stays different from A and B:
- A (graphite, SF only, no bars) and B (OLED black, Inter, bars + white titles, strong grid) are both cool and dark-first.
- C is warm (yellow-grey neutrals in both themes), paper-first, has a serif title voice, hue-dark event titles
  on pale tints in Paper, taller hours (52 px), roomier group spacing (24/32) and softer radii (6/10/14).

## Tokens (`tokens.js`, shared by the page and `contrast.mjs`)

| Token | Paper | Dark | Use |
| --- | --- | --- | --- |
| bg | #F7F4EC | #151412 | canvas, grid |
| rail | #F0ECE3 | #1A1917 | sidebars, own shade (C8) |
| surface | #ECE7DC | #201F1C | cards, segmented track, chips |
| raised | #FFFDF8 | #292724 | fields, menus, popovers, dialogs, selected segment |
| fg1 | #211E19 (15.1:1, Lc 97) | #EEEAE2 (15.3:1, Lc 94) | titles, values |
| fg2 | #47423A (9.1:1, Lc 87) | #CCC6BA (10.8:1, Lc 72) | times, secondary rows |
| fg3 | #5B554C (6.7:1, Lc 79) | #AAA498 (7.4:1, Lc 53) | labels, hints, placeholders, icons, hour labels |
| fg4 | #A29C90 | #67625A | disabled only |
| accent (ink) | #211E19 on #F7F4EC | #EEEAE2 on #151412 | primary button, today pill |
| focus | #2F6BDC (4.5:1) | #7AA2F7 (7.3:1) | 2 px ring, keyboard only |
| live | #C2362B (4.9:1) | #FF6B5C (6.6:1) | now line, "min left" |
| hover / selected | fg1 4 % / 7 % over bg | fg1 5 % / 9 % over bg | neutral only, never a hue |
| grid (hour line) | #DFDCD5 (Lc 11) | #2D2C29 (1.32:1) | below Lc 15; no half-hour lines |
| hairStrong | #C8C5BE | #403F3C | all-day lane edge (C8 asked for it) |
| segRing | #87837B (3.1:1 on track) | #6E6C67 (3.1:1) | 1 px edge of the selected segment |

Event recipe (one mark per state):
- Paper: fill = mix(bg, cal, .18), title = mix(cal, #1A140C, .80) (hue-dark), time = mix(title, fill, .14), 3 px bar.
- Dark: fill = mix(bg, cal, .22), title = fg1, time = mix(title, fill, .18), no bar.
- Hover lightens the fill only. Selected: fill one step stronger + 1.5 px fg1 ring, comes to the front.
- Needs reply: no fill, 1 px outline in the calendar colour. Maybe: fill + 1 px dotted outline (no stripes).
- Declined: half fill, fg2 struck. Past: fill 55 % toward bg, title fg2, time fg3, full opacity.

Type: 22 serif title / 15 heading / 13 body / 12 event / 11 small. Weights 400 and 500; 600 only for the one
dominant title per area. Tabular figures everywhere; Geist Mono 11 only in time columns.
Spacing 4/8/12/16/24/32. Radius 6 (events, rows, chips) / 10 (buttons, fields, track) / 14 (menus, cards, dialogs).

## Contrast check
`node design/mockup-v6-c/contrast.mjs` prints every pair (neutrals on all 6 surfaces, accent, live, focus,
grid, segment edge, and 9 event states for all 16 calendar and swatch colours) with WCAG ratio and APCA Lc. 344 pairs, 0 below target.
Worst margins: dark selected Banana event time 6.65:1 (Lc 75, target 6.5:1); paper "min left" live text on the rail 4.62:1 (Lc 65);
lowest dark Lc for text is live red 47.6 (6.3:1). Paper selected events use a darker title (mix .88) so reds and purples keep Lc ≥ 80.
The brief's floors apply on the canvas; on rail/surface/hover/selected the Lc floor is 5–7 lower, the ratio floor stays.

## What changed on every surface
- **Type**: Geist (bundled woff2, latin + latin-ext, OFL) for all UI text; Newsreader 22/600 (bundled, `opsz` 36) for the view title,
  the editor title, the Day-view focus title and the Settings page title; 28 px Newsreader for the onboarding hero only.
  Geist Mono 11 in time columns (hour gutter, Later, search results, Day-view list). The macOS menu bar and the native
  menu-bar menu stay SF (system chrome). Fallbacks: -apple-system / Iowan Old Style / ui-monospace.
- **Grid**: hour height 52, hour lines Lc 11 (paper) / 1.32:1 (dark), softer day separators, no half hours, the all-day lane keeps
  one stronger bottom edge (C8). Now = 2 px live line with an 8 px dot and the time in live red in the gutter (no pill).
- **Events**: one mark per state (see recipe). No outline + fill + stripes combinations. Hover = a light overlay only; click selects and brings to front.
- **Sidebar**: calendar = 10 px circle (filled / outline), no checkbox. Glyph at 16, text at 40. Groups 16 apart, labels 11 fg3.
- **Right column**: search field without the redundant magnifier (rule 5), "Today" without the repeated date (rule 6), the Now card is the
  one card (raised on paper, surface on dark) with a 15/600 title; Up next sits flat; Later rows have no icons (brief C).
  "Useful shortcuts" stays (C does not list it as removed) but at 11 px fg2/fg3, no bold header.
- **Editor**: serif title on the 48 px text column; icons fg3; dates fg2; fields raised with a hair ring on paper only.
- **Menus, ⌘K, popovers, dialogs, toasts**: raised surface, radius 14, 28/32 rows, hints in fg3 without boxes, one shadow recipe per theme.
- **Settings**: grouped rows on a 3.5 % tint (no frames), serif page title, nav selected = selected fill + 500.
- **Onboarding**: warm art panels (no navy), ink primary, success green from tokens.
- **Status colours** (ok / warn / danger) are tokens that pass on both themes; guest reply marks use them.

## Coordination
- Read A (`mockup-v6-a/NOTES.md`) and B (`mockup-v6-b/NOTES.md`) midway and at the end.
- **Took from A**: the selected segment needs a 3:1 edge against its track (WCAG 1.4.11); a raised fill alone is ~1.1:1. Added `segRing`, checked in contrast.mjs.
  Also A's point that the brief's dark fg3 fails on raised surfaces: C's fg3 is #AAA498 (6.0:1 on raised).
- **Avoided** (to keep C distinct): A's SF-only cool graphite and 48 px hours; B's OLED black, Inter, white titles on dark fills,
  visible half-hour ticks and neutral all-day chips; both A and B drop "Week 45" and the whole "Today" header, C keeps both (quietly).
  C is warm in both themes, paper-first, with a serif voice, 52 px hours, 6/10/14 radii and roomier group spacing.
- **Shared bug for A and B** (found here, also in v5): in onboarding "Choose your calendars", `.onb2 .cgrp .gact { display: inline-flex }`
  out-ranks `.onb2 .only-g { display: none }`, so "Connected" shows next to "Connect" while Google is off. Fix (app.css):
  `.onb2 .cgrp .gact.only-g { display: none } .onb2.g-on .cgrp .gact.only-g { display: inline-flex } .onb2.g-on .cgrp .gact.only-a { display: none }`,
  plus `flex: none; white-space: nowrap` on `.gact` so "to reply and invite" does not wrap into a column.

## Open issues
- Scenes that scroll to 16.5 × H (C3, C4) now clamp at the end of the day with 52 px hours; Thursday evening still shows.
- Geist at 11 px is on the small side (the brief prefers 12 for Geist); kept 11 for the 5-size scale, with +0.012 em tracking.
- Dark events at 22 % tint still read as a blue block when a column is all "Personal"; that is the calendar colour, not chrome.
