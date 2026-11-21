# Calendr v7 · Packs: designer notes

Status: built and checked. Tailnet: https://<tailnet-host>:8799/ (opens on D1, Dark).
Serve: `node design/mockup-v7/serve.mjs 8799`. Contrast: `node design/mockup-v7/contrast.mjs` (`--all`, `--fails`, `--pack D3`).

This is one page with one data set and one codebase, started as a copy of `mockup-v6-c`. Every product decision from `FEEDBACK.md` stays as it is. Only the visual system changes from pack to pack.

## What a pack is

A pack is a matched pair: a Dark theme and a Paper theme that use the same fonts, event mark, line structure, radii and spacing. Switching Dark/Paper inside a pack keeps the same product. Only the canvas changes.

- **Switch**: the strip at the top of the picker rail (D1 D2 D3 D4 · A B C · Dark Paper), plus the **Packs** tab with one line per pack. The choice is stored in the URL hash, for example `#tab=packs&pack=D3&appear=paper`.
- **One token source**: `packs.js`. The page reads it through `PK()` in app.js, and `contrast.mjs` reads the same file.
- **Stylesheets**: A and B load their v6 stylesheet unchanged (`pack-a.css`, `pack-b.css`; only the page shell and the rail moved out). C uses `app.css` (the v6 C sheet). D1–D4 use `app.css` + `pack-d.css`. `shell.css` holds the rail and the two v7 fixes, and every pack loads it. `applyPack()` in rail.js switches sheets with `CSSStyleSheet.disabled`, so there is no reload and no flash.
- **Markup**: the few places where v6 A, B and C wrote different HTML (Today column, Day list, header week number, sidebar mark, search icon, guest reply colours) branch on `UI()`.
- **A, B, C are faithful**: a pixel diff against the v6 pages finds ≤ 0.02 % of pixels changed above 16:00. Every change comes from fix (a) below.

## The packs

| Pack | Dark canvas | Sidebars | Event mark | Lines | Body font | Light counterpart (Paper) |
| --- | --- | --- | --- | --- | --- | --- |
| **D1 · Graphite, bar** | #111113 graphite (A) | #0C0C0E, one shade darker, no hairline (A) | 3 px bar + **white** title on a firmer tint (fill .28) (B) | calm: hour lines only (#29292B), hour labels fg3 (A) | SF Pro | C's paper #F7F4EC, rail #F0ECE3 (darker). Same bar, ink title #211E19 on fill .18, same calm lines |
| **D2 · OLED, soft** | #000000 (B) | #0E0E10, one step up (B) | **no bar**, off-white title #E6E6E8 on a soft tint (fill .28 on black) (A) | calm and faint (#171717), minimal chrome: no shortcut list, week number on title hover | SF Pro | warm near-white #FAF8F3, rail #F2EFE8. No bar, ink title on fill .22 (stronger, because no bar carries the hue) |
| **D3 · Graphite timetable** | #131315 graphite | #0E0E10 darker + hairline pane edges | **no bar**, title **tinted with the calendar hue** (hue mixed .74 toward white) on fill .20 | timetable (B): hour #343436, half hour #232325, hour labels fg2, start over end in one right-aligned time column, under 45 min on one line | Inter | C's paper. No bar, hue-dark title (C's recipe) on fill .18, same timetable lines and hairlines |
| **D4 · Black, graphite panes** | #000000 | #1C1C1F graphite panes, clearly lighter | 3 px bar + off-white title on a soft tint (fill .24). All-day items are neutral chips with a 6 px dot (B) | B's structure, A's calm: quiet hour lines (#1C1C1C), dotted half-hour ticks, hour labels fg2, start over end | Inter | deeper paper canvas #F3F0E7 between lighter panes #FBF9F4 (mirrors the lifted panes). Bar, ink title #1B1814 on fill .16, dotted half hours |
| A · Calm graphite (v6) | #111113 | #0D0D0F | no bar in dark, bar in paper | hour lines | SF Pro | v6 A paper #FAF9F6 |
| B · Structured contrast (v6) | #000000 | #0E0E10 | bar + white title | timetable | Inter | v6 B paper #FFFFFF |
| C · Warm editorial (v6) | #151412 warm night | #1A1917 | no bar in dark, bar + hue-dark title in paper | faint, 52 px hours | Geist + Geist Mono | v6 C paper #F7F4EC |

Coverage: two packs have a bar (D1, D4) and two do not (D2, D3). Two use graphite (D1, D3) and two black (D2, D4). Fonts cross both: SF Pro for D1/D2, Inter for D3/D4. Each font therefore appears once with a bar and once without, and once on graphite and once on black.

**Shared by D1–D4**
- **Page titles**: Newsreader serif for the view title, the editor title, the Day-view focus title, the Settings page title and the onboarding hero, exactly as in v6 C: 22/28, weight 600, the year 400 in fg3 ("November 2026").
- **Type**: 5 sizes (22 · 15 · 13 · 12 · 11). Weights 400/500, plus 600 for the one title per area. On dark, small fg3 labels use weight 500 (brief §1). Times use the body font's tabular figures; no mono face. Inter adds `cv05`/`cv08`. SF tracking is set by hand per size.
- **Spacing and shape**: spacing 4/8, rows 28/32, hour 48 px, radius 4 events · 6 rows · 8 fields · 12 cards and menus.
- **Chrome**: "Today" header dropped (A and B agree); week number on title hover (A).
- **Right column**: Now/Up next with start over end in the shared 36 px right-aligned time column. Content edge 20, mark at 66, title at 79, the same as Later and search results.
- **One mark per state** (unchanged from v6): outline = needs reply, dotted = maybe, half fill + struck = declined, fill 55 % toward the canvas = past (text stays opaque), stronger fill + 1.5 px fg1 ring = selected.

## Contrast (every pack, both themes, one target table)

`contrast.mjs` checks 2,490 pairs: neutrals on every surface, accent, live, focus, selected segment, status colours, lines, and 9 event states × 16 calendar colours. **0 below target.**

**Targets** come from the brief §1/§5:
- **Dark**: fg1 ≥ 12:1 and Lc 88–96 on near-black, fg2 ≥ 7:1 Lc 68, fg3 ≥ 6.5:1 Lc 48. Event title ≥ 7:1 Lc 75, time ≥ 6.5:1 Lc 60.
- **Paper**: fg1 Lc 95, fg2 Lc 80, fg3 ≥ 5:1 Lc 70.
- **Non-text**: 3:1 (WCAG 1.4.11).
- **Off-canvas surfaces** (cards, fields, hover, selected): same ratio floor, Lc floor 3–5 lower.
- **Lines**: hairlines must stay under Lc 15. "Structure" lines (the C8 all-day edge and the hour line of timetable packs, brief §6 B "visible grid") may reach Lc 35, so the locked C8 value and B's grid pass.

The A, B and C tokens pass this table unchanged.

| Pack · theme | Worst pair (smallest margin over its floor) | Lowest text ratio |
| --- | --- | --- |
| D1 dark | fg2 on bg #C4C4CA / #111113: 10.86:1, Lc 70.7 (floor Lc 68) | 6.21:1 past time, Banana |
| D1 paper | fg1 on selected #211E19 / #E8E5DD: 13.19:1, Lc 88.3 (floor 88) | 4.62:1 live "min left" on rail |
| D2 dark | fg1 on rail #E6E6E8 / #0E0E10: 15.47:1, Lc 91.4 (88–96) | 6.53:1 live text on card |
| D2 paper | selected title, Tomato #211E19 / #F1C6BF: 10.73:1, Lc 76.1 (floor 75) | 4.74:1 live text on rail |
| D3 dark | title on hover, Tomato #F5CECC / #452827: 9.20:1, Lc 77.1 (floor 75) | 6.08:1 live text on card |
| D3 paper | fg1 on selected #211E19 / #E8E5DD: 13.19:1, Lc 88.3 (floor 88) | 4.62:1 live text on rail |
| D4 dark | fg1 on raised #E8E8EA / #26262A: 12.32:1, Lc 89.9 (floor 12:1) | 5.61:1 live text on card |
| D4 paper | fg1 on bg #1B1814 / #F3F0E7: 15.52:1, Lc 95.6 (floor 95) | 4.60:1 ok-green on bg |
| A dark | fg2 on bg #C4C4CA / #111113: 10.86:1, Lc 70.7 | 6.33:1 fg3 on selected |
| A paper | selected title, Tomato #451B1C / #F1CAC5: 9.81:1, Lc 75.5 | 5.39:1 fg3 on selected |
| B dark | fg1 on hover-on-raised #E6E6E8 / #262629: 12.11:1, Lc 88.6 | 5.78:1 selected time, Banana |
| B paper | fg1 on sidebar #111114 / #F4F4F6: 17.16:1, Lc 98.9 (floor 95) | 5.29:1 ok-green on bg |
| C dark | fg1 on selected #EEEAE2 / #292725: 12.40:1, Lc 91.1 | 6.00:1 fg3 on selected |
| C paper | fg1 on selected #211E19 / #E8E5DD: 13.19:1, Lc 88.3 | 4.62:1 live text on rail |

Tuning forced by the check:
- **D3 dark**: hue titles at .74 toward white, fill .20, time mixed .14. At .62 the titles fell to Lc 69–74.
- **D4 dark**: raised #26262A and rail hover 4.5 %. At #2B2B30, fg1 fell to 11.5:1.
- **D4 paper**: fg1 is #1B1814, because the deeper canvas otherwise misses Lc 95.
- **D2 paper**: time mixed .17.
- **Paper rail hover**: 3.5 %.

## v7 fixes (all packs, A/B/C included)

**(a) Crowded overlaps were unreadable fragments** ("[. 18:00", "PR", "[PC", "Scl" around Wed–Sun 18:00 and the 23:00 rows).
- **What stays**: side by side (C3, decided).
- **Minimum lane width**: a lane is never narrower than `EV_MINW` = 52 px. When a cluster needs more lanes than fit, the extra lanes fold into a small neutral **"+N"** chip in a 24 px slot at the column's right edge. There is one chip per run of folded events, placed at the first folded start; its tooltip lists the folded titles with their times. A visible event takes the slot only when nothing beside it is folded.
- **Short items** (tasks, ≤ 15 min) follow the same rule and stay clear of a slot. The 22:49 / 23:00 / 23:10 tasks now show one readable item + "+2".
- **Narrow one-line blocks** (< 96 px) drop the time instead of the title (B's rule, now in every pack).
- **Clicking "+N"** uses the existing selection. It selects the folded events in turn (each click steps to the next, then the last visible lane, then wraps). A selected event moves into the last visible lane and comes to the front; only the events it overlaps there fold instead.
- **Day view**: the 374 px column shows up to 6 lanes before folding.
- **Code**: `fitLanes` / `chipRuns` in app.js, `ACT.evMore` in input.js, `.evx` in shell.css.

**(b) Late-evening events were hidden in scenes C3/C4.**
- **Cause**: the scenes scrolled by a fixed `16.5 × H`. With taller hours that clamps to the end of the day, and in C4 the Settings sheet covered exactly Thursday evening.
- **Fix**: scenes now ask `revealGrid()` (panel.js) to bring a time range into view. It is measured on the real layout (hour height, all-day lane height, and the band left free below an open dialog).
  - C3 shows Thursday 17:30–21:00.
  - C4 places Thursday 18:00–20:00 below the Settings sheet. It pins the declined "Neighbourhood meetup" (`A.pin`) so the overlap rule keeps it visible, struck through, next to the highlighted "Show declined events" row.

## Open issues

- **v6 references mix marks across themes**: A and C have no bar in Dark but a bar in Paper. They are kept as built in v6. D1–D4 use the same mark in both themes.
- **Pane step direction**: OLED black can only step up, so D2's sidebars are a lighter shade in Dark and a darker shade in Paper. That is the usual light-theme convention. D4 mirrors its lifted panes in Paper with a deeper canvas instead. Worth a look whether D4's Paper or C's darker rail reads better.
- **Temperature**: the D darks are cool neutral (A/B) and the papers warm (C), as asked. If the switch reads as two products, warm the darks by 1–2 % (e.g. #121211).
- **D3 hue titles are pale in Dark**: Lc ≥ 75 allows only about a quarter of the hue. More hue needs a larger title or a lower floor.
- **Live red as small text in Paper**: "30 min left" and the gutter time sit at 4.6–4.7:1 (Lc 65). That passes, but with little margin; A avoids red text altogether.
- **Folding in the week view**: with both sidebars open a week column is 118 px, so a 3+ lane cluster shows one lane plus "+N". While a folded event is selected, the events it displaced fold, which can leave a gap in that lane. `EV_MINW` (52 px) is a judgement call and could become a density setting.
- **Short items over a block**: they still take the right half of the block (v5 behaviour) and show a clipped title such as "[P1] …".
- **Fonts outside macOS**: SF Pro only renders in a browser on macOS. Inter, Newsreader and Geist are bundled.
- **Scope of shared CSS**: A and B keep their own v6 stylesheet, so a later change to `app.css` or `pack-d.css` does not reach them. Shared fixes go in `shell.css`.
