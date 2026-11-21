# v6 · B "Structured contrast": designer notes

Status: done. Served at https://<tailnet-host>:8797/ (headless check: no console errors).

Copy of `mockup-v5` with only the visual system changed. Every locked behaviour in `FEEDBACK.md` stays.
Serve: `node design/mockup-v6-b/serve.mjs 8797`. Contrast table: `node design/mockup-v6-b/contrast.mjs` (add `--all` for every calendar colour).
The page and the script read the same `tokens.js`.

## Intent

Keep the locked OLED black, but make the calendar read like a well-set timetable: crisp, explicit structure,
scannable from across the desk. Hierarchy comes from **alignment and contrast**, not from colour or weight.

- **Font**: Inter 4 variable, bundled (`fonts/InterVariable.woff2`, OFL). UI at 13 / 12 / 11 with `cv05` (l with tail) everywhere and
  `tnum` + `zero` on every time, date and number. Titles use Inter's Display optical size (`opsz` 32) at 600. Fallback: SF Pro / system-ui.
- **Type scale**: 5 sizes, 3 weights. `title` 20/24 600 · `heading` 15/20 600 · `body` 13/18 400 (500 selected) · `event` 12/15 500 · `small` 11/14 400 (500 for fg3 labels).
  Onboarding step titles keep a 24 px hero.
- **Structure**: a visible grid. Full hours `#28282C`, a faint half-hour tick `#111113`, day dividers `#1C1C1F`, and one stronger edge `#36363C`
  where scrolling content meets fixed chrome (header, all-day lane). Hour labels in fg2. Hour height 48 (12 px per 15 min).
- **One time column everywhere**: a 36 px right-aligned tabular column. The grid gutter, the Day-view list, Now / Up next, Later,
  search results, ⌘K and the menu bar all put the start time in it; where the end matters (Now card, Day list) it sits under the start in fg3.
- **Events**: solid but dark fill `mix(#000, colour, .30)`, a 3 px bar in the calendar colour, a **white** title (12/500),
  meta `mix(title, fill, .18)` (≥ 8.3:1). Under 45 min the time moves onto the title line. One mark per state:
  outline = needs reply (no fill, no bar), dotted outline = maybe (no stripes), fill 50 % + struck fg2 title = declined,
  fill 55 % toward bg with fg2 / fg3 text at full opacity = past, fill .42 + 1.5 px fg1 ring = selected. Hover only lightens (fill .35); a click brings the block to the front.
- **All-day lane**: chips on a raised neutral fill with a 6 px colour dot (no colour bars), titles fg1.
- **Surfaces**: bg #000 → surface #0E0E10 (both sidebars, own shade) → raised #18181B (fields, menus, Now card) → raised2 #232327.
  The "Now" card is the one raised element in the right column.
- **Colour means calendar**: neutral chrome. Live red only for the now line, now time and countdown. Focus blue only on keyboard focus.
  Success, warning and danger use tokens that pass on both themes.
- **Removed**: Instrument Sans; the year and "Week 45" in the header (year shows only when it is not this year); sidebar checkboxes
  (10 px squares, outline when hidden); all-day colour bars; stripes on "maybe"; the red now pill (now time is red text in the hour column);
  the "Today · Wed 4 Nov" header (labels "Now", "Up next", "Later" say it); 9 / 9.5 / 10.5 / 11.5 / 12.5 / 16 / 18 / 22 px sizes.
- **Paper**: pure white canvas, cool neutral greys, fill `.20` + bar, title #111114, meta `mix(title, fill, .22)`.
- **Rule for fg3 text**: always weight 500 (brief: tertiary text at 11–13 px only at ≥ 500). Exception: placeholders stay 400.
- **Kept on purpose** (differs from A): "Useful shortcuts" in the right column, restyled as a quiet 28 px list with keys in fg3.

## Tokens (from `tokens.js`; ratios on bg unless noted)

| Token | Dark | WCAG / Lc | Paper | WCAG / Lc |
| --- | --- | --- | --- | --- |
| bg | #000000 | | #FFFFFF | |
| surface (sidebars, lane) | #0E0E10 | | #F4F4F6 | |
| raised (fields, menus) | #18181B | | #FFFFFF + ring + shadow | |
| raised2 | #232327 | | #EDEDF0 | |
| fg1 | #E6E6E8 | 16.9:1, Lc 92 | #111114 | 18.9:1, Lc 105 |
| fg2 (times, hour labels) | #C8C8CE | 12.6:1, Lc 74 | #3E3E46 | 10.6:1, Lc 95 |
| fg3 (labels, icons, placeholders) | #A4A4AC | 8.5:1, Lc 53 (7.2:1 on raised) | #5A5A63 | 6.8:1, Lc 84 (6.2:1 on surface) |
| fg4 (disabled) | #5E5E66 | exempt | #A3A3AB | exempt |
| hour line / lane edge | #28282C / #36363C | decorative | #D9D9DE / #C4C4CB | decorative |
| accent (primary, today pill) | #E6E6E8, text #000 | 16.9:1 | #111114, text #FFF | 18.9:1 |
| focus | #6E9BF5 | 7.7:1 | #2F6BDC | 4.9:1 |
| live line / live text | #FF5A4F / #FF8075 | 6.8:1 / 8.6:1, Lc 54 | #E0362B / #BF2A20 | 4.4:1 / 5.9:1 |
| event title on fill (worst, yellow) | #FFFFFF | 11.4:1, Lc 100 | #111114 (worst, tomato) | 14.3:1, Lc 87 |
| event meta on fill (worst) | mix .18 | 8.3:1, Lc 77 | mix .22 | 8.1:1, Lc 77 |

Contrast result (`node contrast.mjs`): 100 pairs, 0 below target, every calendar colour and swatch in both themes.
Worst text ratio: Paper success green on white 5.29:1 (Lc 76). Lowest Lc: dark fg3 on a hovered raised row 6.1:1, Lc 50.
Event worst cases (all 16 colours): dark title 11.4:1, meta 8.3:1 (yellow); paper title 14.3:1, meta 8.1:1 (tomato).
Deviations from the brief's B numbers, each forced by the check: live red text is #FF8075 in dark (#FF6B61 gave Lc 48),
selected fill .42 (not .44) so the yellow time stays ≥ 5.5:1, paper meta mix .22 (not .30) for Lc ≥ 75, paper needs-reply
outline darkened 32 % so yellow reaches 3:1. Hover states are checked against AA+ (5.5:1), not the resting 6.5:1 floor.

## Coordination with A and C

Read A and C midway and at the end.
- **Took** (shared fixes): A's selected-segment ring (a raised thumb alone is ~1.3:1 against its track; `segRing` ≥ 3.5:1, in the check);
  the onboarding bug A and C both reported (`.onb2 .cgrp .gact` out-ranked `.only-a/.only-g`, so "Connect" and "Connected" showed
  together; fixed in app.css, plus `flex: none; white-space: nowrap` on `.gact`, verified in both Google states);
  the ⌘K date column (112 px, `nowrap`; I had hit the same wrap).
- **Avoided**, to keep B distinct: A's graphite #111113, SF-only type, bar-less dark events, fg3 hour labels and fg1 now time;
  C's warm neutrals, serif titles, Geist, 52 px hours and roomier spacing. B stays OLED black + Inter, white titles on .30 fills with a
  bar, a visible grid with half-hour ticks, fg2 hour labels, the red now time in the hour column, neutral all-day chips with dots,
  and one shared right-aligned time column (start over end) through grid, Day list, right column, search, ⌘K and menu bar.
- Same as A (independently): 48 px hours, no year / week number in the header, no sidebar checkboxes, no "Today · date" header.

## Open issues
- Most of the owner's events are "Personal" blue, so at fill .30 a dark week still reads blue; that is calendar colour, not chrome.
- The native menu bar menu keeps the system font (it is an NSMenu); its time column is 44 px because SF 13 is wider than Inter 11.
- "Replies need Google." wraps to two lines next to its button in the narrow editor (copy unchanged from v5).
- Slashed zeros (`zero`) are on in every time as the brief asks; worth a look on a real display, they can read busy at 11 px.
