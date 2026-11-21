# v6 · A "Calm graphite": designer notes

Status: done. Tailnet: https://<tailnet-host>:8796/

Copy of `mockup-v5` with only the visual system changed. Every locked behaviour in `FEEDBACK.md` stays.
Serve: `node design/mockup-v6-a/serve.mjs 8796`. Contrast table: `node design/mockup-v6-a/contrast.mjs`.

## Intent

Quiet and expensive, like Notion Calendar or Linear. The page is graphite, not black.
The only colour on screen is the events, at low saturation. Hierarchy comes from size and two greys, never from weight or lines.

- **Font**: SF Pro only (system font). Instrument Sans is gone. Titles are SF Pro Display 20/600, set by the system's optical size.
- **Type scale**: 5 sizes, 3 weights. `title` 20/24 600 · `heading` 15/20 600 · `body` 13/16 400 (500 when selected) · `event` 12/15 500 · `small` 11/14 400. SF tracking set by hand (11: +0.06, 13: −0.08, 15: −0.23). Every time, date and duration uses tabular figures.
- **Weight 600** only on the single dominant title per area: view title, editor title, "Now" title, dialog and settings titles, onboarding step title.
- **Spacing** 4 / 8 / 12 / 16 / 24 / 32. Rows 28 (lists, menus) and 32 (fields, buttons). Hour height 48 (6 × 8, 12 px per 15 min). Radius 4 events · 6 rows · 8 buttons and fields · 12 menus, cards, dialogs.
- **Surfaces, not lines**: sidebars sit one shade darker than the canvas (C8 "own shade" kept), so no pane hairlines. Only the hour grid, the all-day lane edge and the footer edge keep a line.
- **Events**: tinted fill `mix(bg, colour, .24)` in dark with **no colour bar**; paper keeps a 3 px bar, fill `.16`, hue-dark title. One mark per state: outline = needs reply, dotted outline = maybe, struck + half fill = declined, fill 55 % toward bg = past (text stays at full opacity), stronger fill + 1.5 px ring = selected. Hover only lightens; a click brings the block to the front.
- **Colour means calendar**: neutral chrome with no hue. One alert hue (now line, "Now" dot). One focus blue (keyboard focus only). Guest replies, success ticks and onboarding art are neutral now.
- **Removed noise**: sidebar checkboxes (now 10 px dots, outline when hidden), "Week 45" next to the title (week numbers stay in the mini month and on title hover), the red now pill (a 1.5 px red line with a dot; the gutter shows the time in fg1), "Useful shortcuts" in the right column (they live under `?` and ⌘K), the "Today / Wed 4 Nov" header (the date already shows in the grid header and the menu bar), the search icon inside "Search events", the gear next to "Settings".
- **Alignment columns**: sidebar glyph at 16, text at 40. Right column labels at 20, times right-aligned in a column that ends at 52, the colour mark between, titles at 64; Now / Up next, Later, search results and the menu bar all share it. Editor: icon column 20–36, text at 48.

## Tokens (computed by `contrast.mjs`, the page reads the same `tokens.js`)

| Token | Dark | on bg | Paper | on bg |
| --- | --- | --- | --- | --- |
| bg | #111113 | | #FAF9F6 | |
| side (both sidebars) | #0D0D0F | | #F4F2EE | |
| surface | #18181B | | #F2F0EB | |
| raised (fields, menus, dialogs) | #202024 | | #FFFFFF + shadow | |
| line (hour grid) | #252529 | 1.24:1 (decorative) | #E3E0D9 | 1.25:1 |
| hair-strong (all-day edge, paper field outline) | #3A3A40 | 1.67:1 | #CFCBC2 | 1.54:1 |
| fg1 | #EDEDEF | 16.1:1, Lc 95.7 | #1C1B20 | 16.3:1, Lc 100 |
| fg2 | #C4C4CA | 10.9:1, Lc 70.7 | #4B4952 | 8.4:1, Lc 86.7 |
| fg3 | #A6A6AE | 7.8:1, Lc 53.9 (6.7:1 on raised) | #625F69 | 5.9:1, Lc 77.6 |
| fg4 (disabled) | #62626A | exempt | #A3A0A8 | exempt |
| accent (Ink) | #EDEDEF, text #111113 | 16.1:1 | #1C1B20, text #FAF9F6 | 16.3:1 |
| focus | #6E9BF5 | 6.9:1 | #2F6BDC | 4.7:1 |
| live (now line) | #FF5A4F | 6.1:1 | #D93A2F | 4.3:1 (lines only) |
| selected-segment ring | #76767E | 3.9:1 on track | #86828D | 3.3:1 on track |

fg3 is #A6A6AE instead of the brief's #A0A0A8: the brief's value gives 6.25:1 on raised fields and menus, below its own 6.5:1 target.
Selected events use fill `.34` (not `.40`) in dark: at `.40` the yellow time drops to 4.6:1.
The selected segment gets a 1 px ring: a raised fill alone is 1.15:1 against the track and fails the brief's own 3:1 for "selected segment".

Event recipe results (every calendar colour and every swatch, both themes): title ≥ 9.4:1, time ≥ 6.2:1, past time ≥ 6.4:1 (dark) / 5.3:1 (paper), needs-reply outline ≥ 3:1. Run the script for the full table.

## Shared bug fix (B and C: please take it)

- **Onboarding, "Choose your calendars"**: the Google group header showed both "Connect · to reply and invite" and "✓ Connected" at once (also in v5).
  `.onb2 .cgrp .gact { display: inline-flex }` has higher specificity than `.onb2 .only-g { display: none }`. Fix in `app.css`:
  `.onb2 .cgrp .gact.only-g, .onb2.g-on .cgrp .gact.only-a { display: none; } .onb2.g-on .cgrp .gact.only-g { display: inline-flex; }`
- **⌘K / search field focus**: with a global `:focus-visible` ring the ⌘K input and the search input get their own ring inside the field. A turns it off for inputs inside a field wrapper (`.srch`, `.cmd .q`, `.boxf`).
- **⌘K date column**: 92 px wraps "Wed 4 Nov · 16:30" at 11 px; A uses 112 px with `nowrap`.

## Coordination with B and C

Read B (Structured contrast) and C (Warm editorial) notes midway. How A stays different:
- B is OLED #000, Inter, 3 px bars, white titles, a visible grid with half-hour ticks and hour labels in fg2. A is graphite #111113, SF Pro only, **no bar in dark**, `fg1` titles on a 0.24 tint, hour lines at decorative strength, hour labels in fg3, no half-hour lines.
- C is warm, paper-first, Geist + a serif title, radius 6/10/14, hour height 52. A is cool-neutral, dark-first, one family, radius 4/6/8/12, hour height 48.
- Both B and C drop the year in the header or use a serif; A keeps "November **2026**" with the year in fg3, same weight (brief §5).

Read again before finishing. Taken from C: `flex: none; white-space: nowrap` on the onboarding `.gact` so "to reply and invite" stays on one line (C found the same Connect/Connected bug independently). Nothing visual taken, to keep the directions apart. Same approach as both on tinted grounds: the paper Lc floors in the brief are for off-white, so hover/selected rows are checked against AA+ floors (C does the same on its rail/surface grounds).
Avoided: B's red now time in the gutter (A shows the now time in fg1; red stays a line and a dot, because paper red text fails at 11 px), C's warm neutrals and serif.
