# Horion v8 · designer notes

Status: built and checked. Tailnet: https://<tailnet-host>:8800/ (Dark; neutral demo data only).
Serve: `node design/mockup-v8/serve.mjs 8800`. Contrast: `node design/mockup-v8/contrast.mjs` (`--all`, `--fails`).

Started as a copy of v7. **D3 "Graphite timetable" is the one theme** (locked 2026-11-05) in Dark and Paper. The pack switch, the Packs tab and packs A, B, C, D1, D2, D4 are gone (`pack-a.css`, `pack-b.css`, `packs.js`, the Geist fonts and their licence). No serif anywhere. Round 2026-11-05 (A–H) is in `FEEDBACK.md`.

## Files

- `tokens.js`: the D3 tokens and event recipe for both themes. The page reads it through `PK()` (app.js); `contrast.mjs` reads the same file.
- `app.css` (base) + `theme.css` (D3 structure and the v8 round, by item) + `shell.css` (page shell, picker rail, cascade overlaps and task markers).
- Rail: Dark/Paper switch on top; tabs **Feedback** (round 2026-11-05 A–H first, then the earlier rounds) and **Preview** (Dark/Paper, Google connected, Has Google calendars, Show onboarding).

## D3 tokens

| Token | Dark | Paper |
| --- | --- | --- |
| bg / rail (sidebars) | #131315 / #0E0E10 | #F7F4EC / #F0ECE3 |
| surface / raised | #1C1C20 / #242428 | #ECE7DC / #FFFDF8 |
| fg1 / fg2 / fg3 / fg4 | #EDEDEF / #C8C8CE / #A8A8B0 / #62626A | #211E19 / #47423A / #5B554C / #A29C90 |
| live (now) / on-live (pill text) | #FF6B5F / #131315 | #C2362B / #FFFFFF |
| focus · ok · warn · danger | #6E9BF5 · #6CC58A · #E5B44A · #FF7B72 | #2F6BDC · #2F7A4B · #8A5A00 · #B4382D |
| hour line · half hour · day divider · pane hairline (bg → fg1) | .15 · .05 · .10 · .10 | .15 · .045 · .10 · .10 |
| event fill · selected + · title hue · time mix | bg → hue .20 · +.08 · hue → white .74 · .14 | raised → hue up to .44, luminance ≥ .71 · +.08, ≥ .65 · hue → ink .80 · .12 |
| event hover · past · declined | +5 % white · fill → bg .55 · .50 | +30 % white · fill → bg .60 · .45 |
| accent (today pill, primary) | fg1 on bg | fg1 on bg |

Font: Inter (bundled, `cv05` `cv08`), tabular figures for times. Sizes 18 title · 14 heading · 13 body · 12 event · 11 small. Weights 400, 450 (event titles), 500, 600 (one title per area). Radius 4 events · 6 rows · 8 fields · 12 cards. Hour 44 px. No event bar: soft hue fill + hue-tinted title. Marks per state unchanged (outline = needs reply, dotted = maybe, half fill + struck = declined, faded fill = past, fg1 ring = selected).

## What changed for density (B)

Title 22 → 18 · heading 15 → 14 · event titles 500 → 450 · hour 48 → 44 px (one-line events under 45 min) · header 56 → 48 · day header 36 → 32 · sidebar rows 28 → 26 · mini month 28 → 24 and today marked softly (selected tint + ring instead of the white fill, so the grid's day header holds the one strong "today") · all-day chips 20 → 19 · buttons, Join and search 32 → 28 · editor rows 32 → 30 · right column lead title 15/600 → 13/600 · no shortcut list. Half-hour lines quieter; the hour line kept at .15 so hours read clearly (the user's main ask, Notion screenshot as density reference).

## Now line (A)

`.gridwrap { isolation: isolate }`, `.nowl` z 60 (events 1–45, dragged 50), gutter z 61. Today 2 px + dot with a 1.5 px bg ring, other days 1 px at 38 %, the time on a red pill.

## Overlaps: cascade (decided 2026-11-05)

The user picked cascade. The v7 "minimum 52 px lane + fold into +N" is gone (it hid two overlapping meetings on Thu and two items at 23:00 every day, and task chips covered titles). The columns and lanes variants, the rail picker and the `ov=` hash key are removed (an old `ov=` in a link is ignored). Rail → Feedback → **Overlaps: cascade** keeps the scenes `OV` ("Show Thu evening") and `OVD` (Day view). Code: `layoutDay`, `cascade`, `taskMarks` in `app.js`; styles at the end of `shell.css` (`.desk.ov-cascade`). Nothing is hidden; hover only lightens, a click selects and brings to the front.

- Each event steps in from the deepest event still running at its start (12 px, less when deep), near full width, later on top, a 1 px bg ring between layers. An event that starts < 22 min after one below it takes the right half and the lower one ends there. A block covered within 40 min keeps one line at its top, so nothing peeks out half-hidden.
- **Tasks** (calendar Tasks, ≤ 15 min) never take a place in the cascade: a 14 px marker on their time, stacked downward when two are close; a pill at the right with checkbox + title when ≥ 58 px are free beside the blocks, else a checkbox in a 17 px strip at the right edge and the blocks there step in. Marker text uses the event title colours (`--tc`, `--tcp`), so no new contrast pairs.

## Paper event colours (2026-11-05)

User: Paper events were almost the canvas colour (pale grey-blue), the hue barely showed. Old recipe: canvas #F7F4EC + 18 % hue, which the warm cream greys out (OKLCH chroma ≈ .02–.04). New recipe (`tokens.js` `EV.paper`, `tint()`): a pastel of the hue on warm white (`raised` #FFFDF8), up to 44 % hue, but stopped at relative luminance .71 so the hue-dark title (Lc ≥ 75) and time (Lc ≥ 70) still pass. Light hues (Banana, Lavender, Graphite) take more hue, strong ones (Tomato, Grape) less; every fill has about the same lightness, so one calendar never shouts over another. Selected: 8 points more hue, floor .65, plus the fg1 ring. Hover: +30 % white (was 45 %, which washed the new fills out). Past: fill 60 % toward the canvas (fg2 / fg3 text), declined 45 % (fg2, struck), so normal > declined > past by strength. Titles unchanged (hue → ink .80), time 12 % toward the fill (was 14 %). Dark is unchanged (pixel-identical).

| Calendar | Fill old → new | OKLCH chroma | Fill vs canvas | Title (ratio, Lc) old → new | Time old → new |
| --- | --- | --- | --- | --- | --- |
| Personal #5B8DEF | #DBE1ED → #CFDCF5 | .018 → .037 | 1.19 → 1.26:1 | 10.63 / 82.7 → 10.10 / 79.7 | 7.30 / 74.4 → 7.39 / 72.8 |
| Team #E9B949 | #F4E9CF → #F5DFAB | .036 → .071 | 1.10 → 1.19:1 | 9.88 / 84.7 → 9.10 / 79.5 | 6.72 / 75.4 → 6.67 / 72.2 |
| Family #E5674F | #F4DBD0 → #F8D4CA | .032 → .043 | 1.20 → 1.25:1 | 10.47 / 82.0 → 10.06 / 79.6 | 7.25 / 73.8 → 7.37 / 72.8 |

## Contrast

`contrast.mjs`: 364 pairs (16 calendar colours × 9 event states, neutrals on every surface, lines, status, now pill). **0 below target.**

| Theme | Worst pair (smallest margin over its floor) | Lowest text ratio |
| --- | --- | --- |
| Dark | event title on hover, Tomato #F5CECC / #452827: 9.20:1, Lc 77.1 (floor 7:1, Lc 75) | 6.08:1 live text on card |
| Paper | fg1 on selected #211E19 / #E8E5DD: 13.19:1, Lc 88.3 (floor 88); closest event pairs: selected title Sage Lc 75.7 (floor 75), time Lavender Lc 70.7 (floor 70) | 4.62:1 live text on rail |

New pair: now pill text, Dark #131315 on #FF6B5F 6.65:1 (Lc 50), Paper #FFFFFF on #C2362B 5.45:1 (Lc 81).

## Open issues

- **Location editing** needs the pencil (or Tab to it); a click on the text opens maps. Confirm with the user that this is discoverable enough.
- **Hidden-calendar name** is fg3 (passes as text); the square at 35 % is decoration, not a contrast pair.
- **Live red as small text in Paper** still sits at 4.6:1 ("30 min left" on the rail).
- **D3 hue titles are pale in Dark** (Lc ≥ 75 allows about a quarter of the hue).
- **Overlaps**: cascade is decided. 44 px hours: one-line under 45 min.
- **Paper fills** are now much closer to the Lc floors (titles ≈ Lc 79, times ≈ Lc 72, selected titles ≈ Lc 75–76). Strong reds and purples (Tomato, Grape, Family) get less hue than blue or yellow, because a darker fill would push their time below Lc 70. Past events stay quite pale on purpose.
