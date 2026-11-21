# Calendr v11 decisions
Mockup: `design/mockup-v11/index.html` (serve: `node design/mockup-v11/serve.mjs 8803`, https://<tailnet-host>:8803/). The picker (Readability tab) shows the same state.
Look R covers Dark and (since round h) Paper, derived from the locked Dark rules. The hand-off files are `design/design-system/` (README, foundations, components).

## Locked in round h (2026-11-20)
| Element | Pick |
| --- | --- |
| Design | **R10 · Mine**: R10 levers + your sliders (`r=112213000220110111`), the default state of the mockup (`LOCKED` in `readability.js`) |
| Type scale | **Three sizes, weight for rank · 15 / 12 / 12 / 11**: you said "calm 3 sizes lgtm. now lets lock these in", then picked "Three sizes, weight" when asked which |
| Weights | **400 / 500 / 600** (600 only on the month title, today's date, the right-column lead) |
| Paper | Derived from the locked Dark rules (neutral near-white canvas, same structure, scale and weights; light hue tints, near-black titles). Shown once for a check. |
| Font | **Geist** for the whole UI, bundled in the app (you said: "use geist fr"). The Swift build bundles Geist 400 / 500 / 600 (OTF or variable TTF) and its SIL OFL 1.1 licence, and replaces SF Pro (`enum SF`) and Instrument Sans (`enum Typeface`) in `Typeface.swift`; details in `design/design-system/foundations.md` → Font. |
| Paper event colours | **Clear tint** (round h polish; you said: "paper needs some polish where the colors arent like as good visible"): per-hue OKLCH fills with fill ΔE_OK ≥ 7.5 against the canvas (7.7–10.6; before 3.8–8.4), a 4 px bar at L .57 with more chroma, muted hues (lavender, grape, graphite, slate) given more chroma or a lower L, yellow kept light. Options shown: Clear tint (rec.), Rich tint, Tint + stronger bar, Round h (before); slider "Paper fill strength" 50–150 %. Dark unchanged (pixel-identical). |
Locked link: `#tab=read&look=R&r=112213000220110111&rp=R10&k=rD15rH12rB12rL12rM11rd4.5ec.074el.29bc.25bl.7bw3.5tl1ml.89mc.062cl.15wt0`.
The round-g options stay behind "Unlock to compare" in the Readability tab; the round-g link is the preset "R10 (round g link)"; B switches before (round g) / after (locked).
Counter (week view): before 8 sizes · 3 weights → locked **3 sizes (15, 12, 11) · 3 weights (400, 500, 600)**; text colours 14 (Dark) / 13 (Paper), 9 of them the per-calendar event times.

## Locked before round g
| Element | Pick |
| --- | --- |
| Base design | R10 · Mine: the user's link of round g (`r=112213000220110111`, `k=ft12fm10.5fh11fd12.5fT18.5rd4.5ec.074el.29bc.25bl.7bw3.5tl1ml.89mc.062cl.15`). The earlier R10 stays as "R10 (previous)". |
| Structure | Locked as in v10 (week view, sidebar, right column, editor, cascade overlaps, now line). |

## Open in round g (designr step 4: clean-up into a design system)
Counter (X) on R10 as linked: **8 text sizes** (18.5, 14, 13, 12.5, 12, 11.5, 11, 10.5) · 3 weights (400, 500, 600) · 14 text colours (9 of them hue-tinted event times).

### Type scale
You said: "generally make sure my font sizes somehow make sense, u get the directions but they need to be coherent i guess right? also to preserve visual hierarchy. there need to be different consistent sizes i think. gimme designr suggestions for that."
Also: "idk this is too small" (mini-month title) and "these also perhaps need to be bigger a bit" (sidebar group headers).
Where: Readability tab → Design system · type → Type scale. Each option sets the role sliders (Title · Heading · Body · Label · Secondary); "Advanced: per place" keeps per-place overrides.
| Option | Title / Heading / Body / Label / Secondary | Sizes in view |
| --- | --- | --- |
| **Calm 4 sizes** (recommended) | 18 / 13 / 12 / 12 / 11 | 4 (18, 13, 12, 11) |
| Apple-like | 20 / 13 / 13 / 12 / 11 | 4 (20, 13, 12, 11) |
| Notion compact | 16 / 12 / 11.5 / 11.5 / 10.5 | 4 (16, 12, 11.5, 10.5) |
| Three sizes, weight for rank | 15 / 12 / 12 / 12 / 11 | 3 (15, 12, 11) |
| Current (yours) | per place: 18.5 title, 13 base, 12.5 day header, 12 events / rows, 11 hour labels / group headers / mini month, 10.5 times | 8 |
Roles: Title = month title; Heading = day-header date, mini-month title (and the right-column lead); Body = event title, sidebar rows, right column, base text; Label = sidebar group headers (fg3, 500); Secondary = event time, hour labels, mini-month days, small labels.
Why Calm: one size per job and four steps with clear gaps (18 › 13 › 12 › 11); it keeps your 12 px events and 11 px times, makes the mini-month title (11 → 13) and the group headers (11 → 12) bigger as asked, and removes the half steps 18.5, 12.5, 11.5 and 10.5.

### Weights
| Option | |
| --- | --- |
| **400 / 500 / 600** (recommended) | 600 only for the month title and today's date; 500 event titles, group headers, mini-month title; 400 the rest (day-header weekdays 450 → 400). |
| 400 / 500 only | No semibold; the month title and today's date drop to 500. |
| Current (yours) | As linked. |

Before / After (B, or the button in the tab): before = your link, after = Calm 4 sizes + 400 / 500 / 600. "Design system sheet" lists every text token in view (size / line height, weight, colour, where used), the role sizes and the Dark colour tokens.

## Design system (round h, locked)
Every screen uses only these values. The mockup shows them in the "Design system sheet" (Readability tab, Dark and Paper); B switches round g (before) / locked (after). Full tables: `design/design-system/foundations.md`.
- Surfaces (Dark / Paper): bg `#0B0B0C` / `#FBFBFB` (canvas, grid, header) · rail `#070708` / `#F4F4F5` (sidebar, right column) · surface `#151516` / `#F1F1F2` (cards, all-day lane) · raised `#1D1D1E` / `#FFFFFF` (fields, buttons, menus) · hover bg→fg1 5 % / 4.5 % · selected 8.5 % / 7.5 %.
- Text sizes: **15** month title · **12** body, headings, labels, events, rows · **11** times, hour labels, mini-month days, small labels. Roles: Title 15, Heading 12, Body 12, Label 12, Secondary 11.
- Weights: 400 (body), 500 (event titles, day-header date, mini-month title, group headers, chips), 600 (month title, today's date, right-column lead).
- Text colours: fg1 `#EBEBED` / `#1D1D20` (content) · fg2 `#CCCCCE` / `#4A4A50` (times, secondary, hour labels) · fg3 `#A8A8AA` / `#606067` (labels, group headers) · fg4 disabled. Event text fitted per fill.
- Line strengths (bg → fg1): hour line 10 % (`#212123` / `#E1E1E2`, ≥ 1.15:1), day divider 7 % (decor, ≤ Lc 15), all-day edge 14 % (≥ 1.15:1), pane edge ≤ Lc 15, no half-hour line; today column 3.5 %.
- Event recipe: bar + tint. Dark fill oklch(.29, .074, H), Paper oklch(.95, ≤ .075, H); 3.5 px flush bar oklch(.70 / .60, H); title white / fg1; time hue-tinted (oklch .89 / mid hue), fitted. States: hover +.025 L (Paper −.02), selected +.05 L with 1.5 px bg + 3 px bar ring, past fill → bg 55 % / 60 % with fg2 / fg3 text above the floors, declined fill → bg 50 % / 45 % struck, maybe = 135° 5 px hatch in the hover fill, needs reply = bg fill + 1 px hue outline (≥ 3:1). No opacity on any text.
- Heights: header 48, day header 32, sidebar row 26, all-day chip 19 (+3), hour 44, hour gutter 56, sidebar 236, right column 320, task marker 14, event min 16.
- Radii: 4.5 events / chips / task markers, 6 rows and icon buttons, 8 fields and buttons, 12 menus and dialogs.
- Spacing: 4, 8, 12, 16, 24; event padding 3 top, 6 sides (after the bar); gaps 2 left / 4 right / 2 below; pane padding 12.
- Font: Geist only (locked), bundled, OFL; tabular figures for all times.
- Paper events: Clear tint, fill ΔE_OK ≥ 7.5 vs canvas (7.7–10.6), closest swatches 1.7 apart (Basil / Sage), bar 4 px.

## Fixed without a decision
Round h:
- Paper event fills nearly vanished for lavender, violet, grey and blue calendars (fill ΔE_OK 3.8–4.6): fixed by the Paper colours decision above (Clear tint).
- Drawer shadow showed at the right edge when the rail was closed in full screen; it now appears only with the drawer open.
- Bar chroma of grey calendars (Graphite) went olive with the bar-chroma slider; it is now capped by the calendar's own chroma.
Round g:
- **One-line events had no top padding** ("top padding is buggy here", "the top padding is fucked up"): `.ev.one` had padding-top 0 from the Designer CSS. Now every event uses the padding-y slider; short one-line blocks centre their line (the line box never exceeds the block).
- **Time clipped** ("we need to fix time clipping somehow"): a block shows title + time on two lines only when padding + both line heights fit (`minTwo`); otherwise the time goes inline after the title; the title clamps to the lines that fit; one-line rows share one line box. Checked: 81 slider settings (event title 9 / 12 / 15, time 8.5 / 11 / 13, padding y 0 / 4 / 8, hour 28 / 44 / 96) × every event in the demo week + 15 to 60 min test events: 0 clipped boxes.
- **Past task marker / dimmed contrast** ("the contrast is really bad on some things idk"): the task checkbox had opacity .85; removed (no opacity on text or text-like marks anywhere in look R). Past text now has design targets above the floors: past title ≥ 9:1 / Lc 72, past time ≥ 5.7:1 / Lc 58. Checked in the page: 235 text elements with their computed colour × opacity on the real background: 0 below 4.5:1 / Lc 45, 0 with opacity.
- **Mini-month title too small** ("idk this is too small") and **group headers** ("these also perhaps need to be bigger a bit"): new per-place sliders (Mini-month title, Group headers) and roles Heading / Label; the recommended scale makes them 13 and 12.
- **Today column** ("i want to be able to change this … the lightness of the day marker"): sliders Today column lightness (0–12 % toward fg1), chroma (0–.04) and hue; guarded (hour line and every text on the tint must pass).

## Alignment check
Round h: week view of the locked R10, Dark and Paper, full screen 1600 × 1000: **0 red boxes** in both (sidebar, grid, right column).

Press G (or "Alignment guides" in the tab). Green: a left edge 3+ items share. Red box: an item 1 to 5 px off a shared line.
- Week view, R10, before: 7 red boxes. Six all-day chips sat 2.5 px left of the event text below them (chip padding did not include the bar width); fixed (chip padding = event padding + bar width + 1). One false match: "Week" in the Day / Week / Month control (centred text), now excluded.
- After the fix: 0 red boxes in the week view (sidebar, grid, right column), before and after the type scale.
