# Calendr v11 · designer notes

Status: LOCKED (2026-11-20, round h): R10 · Mine, three sizes 15 / 12 / 11, weights 400 / 500 / 600, Dark + derived Paper. Tailnet: https://<tailnet-host>:8803/ (neutral demo data only).
Serve: `node design/mockup-v11/serve.mjs 8803`. Contrast: `node design/mockup-v11/contrast.mjs --rd` (Readability sweep only, ~50 s);
plain `contrast.mjs` also runs the v9 looks and the v10 Designer sweep.

Copy of v10 (v10 unchanged). New: the **Readability** tab (first tab) and look **R** (now the default look), Dark only. Paper under look R is the
v10 Designer output for the matching shape (not tuned this round). Structure is locked as in v10; the old Designer tab is still there.
Research base: `READABILITY-BRIEF.md` (copied from v10, unchanged); section numbers below (§) refer to it.

## Round 2026-11-20 h: lock, Paper derived, design system

Locked: R10 · Mine + type scale "Three sizes, weight for rank" (15 / 12 / 12 / 12 / 11) + weights 400 / 500 / 600 (`READ.LOCKED`; R10's `k` now
carries the scale; the round-g link is preset "R10 (round g link)"; the type and weight options sit behind "Unlock to compare"). B: before = round g link, after = locked.
**Paper for look R** (`tokensP`, `recipeP`, `chipP`, `pairsP` in `readability.js`): neutral #FBFBFB canvas, rail #F4F4F5, greys fitted to the Paper floors
(fg1 #1D1D20, fg2 #4A4A50, fg3 #606067), lines as bg → fg1 mixes (hour line raised to 1.17:1 on canvas, today column and shade), today column 3.5 %;
events take the Dark event's hue and chroma as a light tint (L .95 for bar + tint, C ≤ .075), bar oklch(.60, ≤ .17), titles fg1 (or a deep hue), times a mid hue,
all fitted a little above the Paper floors. The guard now checks Dark and Paper.
Proof (`contrast.mjs --rd`): levers 22,453,200 pairs (11,226,600 Paper), 0 below target on reachable designs, 0 mismatches; tightest Paper pair: live text on card
#C9372C on #F1F1F2 4.58:1, Lc 66 (floor 4.5 / 60). Sliders 19,760 settings over 13 presets, 13,359 accepted, 6.9 M pairs (Dark + Paper), 0 below target, 0 mismatches.
Counter: 3 sizes · 3 weights; G: 0 red boxes in Dark and Paper. Hand-off files: `design/design-system/README.md`, `foundations.md`, `components.md` (with the Swift code map).

Round h polish (Paper colours, Geist): font locked Geist (bundle list and Typeface.swift call sites in `design/design-system/foundations.md`). Paper event colours:
options `pf` (0 Clear tint, recommended · 1 Rich tint · 2 Tint + stronger bar · 3 round h before) and slider `ps` (Paper fill strength 50–150 %) in `k`;
Clear tint gives every swatch a fill ΔE_OK 7.7–10.6 vs the #FBFBFB canvas (before 3.8–8.4), closest pair 1.7 (before 0.1), bar 4 px L .57; titles / times fitted to the Paper floors.
Dark pixel-identical (MD5 of the 1600 × 1000 full-screen shot unchanged).

## Round 2026-11-20 g: designr clean-up (type scale), fixes

Base: the user's link → **R10 · Mine** (default; old R10 = "R10 (previous)"). Decisions and fixes: `DECISIONS.md` (designr format).
- **Tools** (Readability tab → Design system · type; keys): Counter **X** (sizes, weights, colours in view, each with where it is used), Alignment guides **G**,
  Design system sheet (every text token: size / line height, weight, colour, where used; role sizes; colour tokens), Before / After **B**
  (before = your link, after = Calm 4 sizes + 400 / 500 / 600). Hash: `cnt`, `gd`, `ds`, `ba`.
- **Type scale**: role sliders Title `rD` · Heading `rH` · Body `rB` · Label `rL` · Secondary `rM`; per-place sliders (now in "Advanced: per place", incl. new
  Group headers `fg`, Mini-month title `fn`, Mini-month days `fi`) override a role. Options (first = recommended): Calm 18/13/12/12/11 · Apple-like 20/13/13/12/11 ·
  Notion compact 16/12/11.5/11.5/10.5 · Three sizes 15/12/12/12/11 · Current (yours). Weights: 400/500/600 (rec.) · 400/500 · current (`wt` in `k`).
- Counter, R10 week view: before 8 sizes · 3 weights · 14 colours → Calm 4 sizes · 3 weights (2 with 400/500) · 14 colours (the hue-tinted times are 9 of them).
- **Today column sliders**: `ty` lightness 0–12 %, `yc` chroma 0–.04, `yh` hue (guarded; pairs: fg1–3 on the tint, hour line on the tint).
- **Fixes**: one-line top padding, time clipping (inline time when title + time + padding do not fit; 0 clipped boxes over 81 slider settings), no opacity on task
  checkboxes, past text targets raised (title Lc ≥ 72, time Lc ≥ 58), chip text aligned with event text (G: 7 → 0 red boxes).
- Proof (`contrast.mjs --rd`): levers 11.2 M pairs, 0 mismatches; sliders 18,240 settings over 12 presets (now incl. today-tint grids), 12,691 accepted,
  3,330,935 pairs, **0 below target**, 0 guard / check mismatches.

## Round 2026-11-20 e: sliders, full screen, R10 / R11

The user picked `r=112213000220110111` (R6 edited) → preset **R10 · Mine**, now the default R state. **R11 · Muted navy** = R10 + sliders tuned to the user's
close-up (muted navy fill OKLCH L .37 C .046 = #334058, 3 px flush bar L .65 C .15 ≈ #5C8CEA, title L .955, time L .685 C .044 asked, radius 6, canvas #191919).
The asked time colour (#8D9AB5-like) misses the time floor on that fill (≈ Lc 45), so it is refitted to #D2D8E3 (≥ 6.5:1, Lc ≥ 60): R11 reads lighter than the screenshot there.

**Sliders** (Readability tab → Sliders, above the levers; `<input type=range>` + number field, live while dragging, double-click = back to auto,
"auto" = follows its lever; `Reset sliders`; hash `k=` e.g. `k=sc85ft11.5el.37`):
- Scale: UI scale 70–120 % (the frame's logical size is the window ÷ scale, then scaled back: type, padding, rows and widths shrink together and more fits).
- Font sizes (px, 0.5 steps): base text 10–15, event title 9–15, event time 8.5–13, hour labels 8–13, day header 9–16, month title 12–28, sidebar 10–15, right column 10–15.
- Spacing (px): event padding x 2–12 / y 0–8, gap 0–8, hour height 28–96, sidebar row 18–36, header 32–64, day header 20–48, all-day chip 14–28, hour gutter 36–72,
  pane padding 4–24, sidebar width 160–320, right column 220–420, corner radius 0–12.
- Event colour (OKLCH, per calendar: shifts are relative to each calendar's hue): one hue for all (toggle) + hue 0–359°, fill hue shift ±180°, fill chroma 0–.16,
  fill lightness .12–.92, fill strength 0–100 %, bar hue shift ±180°, bar chroma 0–.25, bar lightness .30–.95, bar width 0–6 px, title lightness .50–1, time lightness .40–1, time chroma 0–.12.
- Canvas colour: lightness 0–.34, hue 0–359°, chroma 0–.04, sidebar / right offset ±.06, hour line 0–30 %, half-hour line 0–12 %.
- Tentative: hatch stripe width 1–10 px, angle 0–180°, opacity 0–100 %, dashed outline opacity 0–100 %.

**Guard**: every text colour is refitted at runtime against the actual fill / canvas (toward white on dark fills, toward black on light ones). After each rail
render the colour sliders get their safe range (16 samples + edge refinement; the input's min / max are cut there, with a note naming the first pair that would
fail); a value that still misses a floor while dragging is refused ("Blocked · …"). The live line at the top of the Sliders shows the tightest pair (ratio, Lc).
Font sizes never lower a floor.

**Full screen** (`fs=1` in the hash, F toggles, Esc leaves, "Full screen" in the rail header): the app fills the browser window (no frame, no fake menu bar),
widths are fluid (the week columns use the real width); **Tune** opens the rail as a drawer over the calendar (`?drawer=1` opens it from a link), **Exit** leaves.

**Proof** (`contrast.mjs --rd`): the lever sweep as in round d, plus a sampled slider sweep: 14,575 settings (11 presets × 1,325: each colour slider alone at
7 steps; fill L × C × strength, bar L × C × hue, title L × time L × C, canvas L × C × hue × offset at 5 steps; hour × half line at 7; one hue × fill L; hue shift × fill L × C).
10,664 accepted by the guard, 2,852,329 pairs, **0 below target**, 0 guard / check mismatches; 3,911 settings clamped (mostly canvas L × hue × chroma: fg1 cap or
12:1 on the canvas; fill lightness or hue shift: title on the selected fill; hour line too faint on the today column). Tightest accepted: selected time 8.40:1, Lc 55.0 (floor 5.5 / 55).

Trade-offs: a slider's range is the passing run around its current value; a second passing island (e.g. very light fills with dark text) is not reachable by
dragging. In tall full-screen windows 24 × 44 px hours leave space under midnight (raise Hour height). Paper ignores the colour sliders (size sliders apply).

## Files
- `readability.js`: `READ.LEVERS` (18 levers, 75 options), `PRESETS` (R1–R9), `tokens(s)` (Dark chrome), `recipe(hex, s, t)` (events),
  `chip()` (all-day), `pairs(s, hues, group)` (every Dark pair), `verdict()` / `passes()` (the guard, same floors as contrast.mjs),
  `look(code)` (a look with the DESIGNER interface: the shape comes from a DESIGNER option set, the Dark colours from this file).
- `rd-ui.js`: the Readability tab. `rd.css`: today column, elapsed shade, next ring, outline / card details, the tab, `?railwide=1` (the rail as a 4-column page, for screenshots).
- `app.js`: `PK()` knows look R; today's column carries `.today` and `--now-top`; the next event today gets `.next`.
- `rail.js`: tab, hash keys `r` (one base-36 character per lever) and `rp` (the preset it started from); a link to a design that would miss a floor falls back to R1.
- `contrast.mjs`: new section "Readability designer" (`--rd`, `--no-rd`).

## The new designer (Readability tab)
Top: the nine presets, Copy link, Reset (back to the preset you started from), the preset's idea and the rules it applies, and the live result of
the current design (every Dark pair, 16 calendar colours × every state). Then 18 levers in six groups. Every lever has a one-line "why" from the
brief, and its options as tiles: a preview drawn with that option's real tokens, the WCAG ratio and APCA Lc of the tightest pair it affects,
and a dot (green ≥ 3 % above the floor, amber within 3 % or within ~1 Lc of the halation cap, red = would break a floor). An option that would
break any floor anywhere in the current design is disabled and says why (tooltip lists the 4 tightest affected pairs).

| Group | Lever (options) | Rule |
| --- | --- | --- |
| Background | Canvas (Graphite #111113, Ink #0A0A0B, OLED black + stepped surfaces, Notion #191919, Dim grey #1C1C1E, Charcoal #222224) | §1 halation |
| | Panes (One surface, Darker sidebars, Lighter sidebars) | §3.3 surface step before a line |
| Text levels | Text steps (Soft Lc 89/68/49, Brief 93/71/51, Crisp 95/75/55, Two greys 92/72, Max 98/78/56) | §1 targets, §3.4 |
| | Hour labels (Quiet fg3, Medium, Clear fg2) | §6 B, §3.1 |
| Events | Event recipe (Tint, Bar + tint, Muted solid, Outline, Card + bar) | §5 one decoration per state, §3.2 |
| | Colour strength (Whisper C .028, Calm .042, Balanced .058, Rich .08; OKLCH, one lightness per strength) | §0, §3 refs |
| | Event text (Neutral, Hue title, Hue both) | §5 |
| | All-day lane (As events, Dot + text, Bar + text) | §3.2 |
| Type | Event type (11/10.5, 11.5/10.5, 12/11, 12.5/11, 13/11 px) · Title weight (400–600) · Font (Inter, System, Geist) · Chrome type (Calm 16·12·10.5, Mid 18·12·11, Brief 20·13·11) | §2 |
| Lines | Hour line (Hairline 7 %, Quiet 10 %, Clear 14 %, Strong 19 %, Ruled 25 %) · Minor lines (None, Day dividers, Dotted half hours, Both) | §3.3 |
| States | Past events (Fade, Ghost, Grey, Text only) · Today (Filled date, Date + column, Red date, Red + column, Bold + column) · Now & next (Today line, Week line, Line + elapsed, Line + next, Elapsed + next) · Maybe / declined (Dashed, Hatch, Striped bar, Faded) | §5 states, §3.6, §3.2, §3.7 |

Colour recipe (Dark): text greys are solved per canvas for an APCA target (neutral grey, a hair of blue), then lifted to the floors where a surface needs it
(never pulled down: the cap is a real limit, so "Max" is disabled on near-black). Fills: the calendar colour goes in as an OKLCH hue; the fill sits at
canvas lightness (≥ .17) + a step per strength with a fixed chroma (≤ the hue's own), so every calendar is equally loud and nothing turns muddy; yellows get
+.015 L and 15 % less chroma (dark yellow goes olive otherwise). Titles and times are fitted toward white only as far as needed; design targets sit a little
above the floors (time Lc ≥ 63, past time Lc ≥ 50). Today tint = canvas → fg1 3.5 %; elapsed shade = canvas → black 42 % (on #000: 3 % lighter).

## Presets (Dark numbers on the canvas; min = worst calendar colour)

| Preset | Idea | Rules | fg1 · fg2 · fg3 on bg | Hour line | Event title / time (min) |
| --- | --- | --- | --- | --- | --- |
| R1 Graphite calm | brief A: graphite, one surface, tint without bar, 3 APCA greys | §1, §5, §6 A, §3.3 | 15.6:1 Lc 93 · 10.9 Lc 71 · 7.4 Lc 51 | 1.27:1 | 10.9:1 Lc 89 / 8.1:1 Lc 64 |
| R2 OLED stepped | brief B: #000, lighter sidebars, fg1 held at Lc 93, bar + tint, fg2 hour labels, today column | §1 halation, §6 B | 17.2 Lc 93 · 12.1 Lc 71 · 8.1 Lc 51 | 1.29 | 11.1 Lc 88 / 8.1 Lc 64 |
| R3 Dim solid | dim grey, muted solid fills, near-white titles, red today, hatch | §1, §5, §3.2 | 14.3 Lc 93 · 10.1 Lc 71 · 6.8 Lc 51 | 1.31 | 9.5 Lc 90 / 6.6 Lc 65 |
| R4 Notion quiet | 11/10.5 events, calm chrome (16 px title), #191919, dot chips, red date | §2, §3 refs, §3.2 | 13.8 Lc 89 · 9.9 Lc 69 · 6.7 Lc 49 | 1.28 | 9.0 Lc 83 / 7.4 Lc 64 |
| R5 Two greys | fg1 + one grey (Lc 72), system font, bar + tint | §3.4, §1, §2 | 15.4 Lc 93 · 11.2 Lc 72 · = fg2 | 1.27 | 11.7 Lc 90 / 8.4 Lc 64 |
| R6 Timetable | ink canvas, strong hour lines, dotted halves + day dividers, crisp text, brief type | §6 B, §3.3, §1 | 16.6 Lc 95 · 12.2 Lc 75 · 8.3 Lc 55 | 1.62 | 11.4 Lc 90 / 8.1 Lc 64 |
| R7 Colour once | neutral cards, hue only as a 3 px bar, grey past, dot chips | §3.2, §5, §3.1 | 15.6 Lc 93 · 10.9 Lc 71 · 7.4 Lc 51 | 1.27 | 12.1 Lc 90 / 7.9 Lc 64 |
| R8 Now & next | today column tint, elapsed shade, ring on the next event, ghost past | §3.6, §3.2, §5 | 15.6 Lc 93 · 10.9 Lc 71 · 7.4 Lc 51 | 1.41 | 10.3 Lc 88 / 7.5 Lc 64 |
| R9 Outline airy | 1 px hue outlines on dim grey, hue text, Geist, dotted halves, bold today on a tinted column | §5, §2, §3.3 | 14.3 Lc 93 · 10.1 Lc 71 · 6.8 Lc 51 | 1.31 | 11.2 Lc 86 / 8.8 Lc 67 |

## Contrast proof (round d)
`node design/mockup-v11/contrast.mjs --rd`: the 13 colour levers split into two groups whose pairs never overlap (chrome: canvas × panes × steps ×
hour labels × hour line × minor lines × today × now; events: canvas × steps × recipe × strength × event text × past × all-day), each crossed fully,
16 calendar colours, checked with the contrast.mjs floors (T.dark, unchanged). Type levers and Maybe / declined change no colour pair.

- 156,600 combinations (135,000 chrome + 21,600 events), **11,226,600 pairs**. 40,416 chrome combinations miss a floor; every one is blocked by the guard
  (guard and check agree on all 156,600; 0 mismatches). Events: 0 misses.
- Reachable designs: 61,290,432,000 of 87,480,000,000, every one with 0 pairs below target. Presets R1–R9 all pass.
- Tightest text pair: fg1 on surface, Charcoal + Lighter sidebars, #EAEAEB on #29292C, 12.06:1, Lc 90.6 (floor 12:1 / Lc 85).
- Why options are disabled: fg1 above the halation cap Lc 96 on near-black (Max steps: 18,000; on a darker sidebar: 1,500); hour line under 1.15:1 on the
  today column (11,340), on the canvas (Hairline on OLED / Ink / Graphite: 7,200) or on the elapsed shade (576); fg1 under 12:1 on the today column on lighter canvases (1,800).

## Trade-offs / open
- Needs-reply (dashed or solid outline in the event's hue) and the "next" ring look alike in R8 / R9; the ring sits 1 px outside, the reply mark inside.
- Elapsed shade on OLED black is a lift, not a shade (nothing is darker than #000).
- Max text step is only reachable on Dim grey / Charcoal (luminance ≥ .01, where the brief's cap does not apply).
- Muted solid yellow and orange read brown-amber (deep fills for white text); chroma reduced for yellows to keep them from going olive.
- Paper is not tuned for look R.

---

# v10 notes

Status: built and checked (2026-11-20, round b). Tailnet: https://<tailnet-host>:8802/ (neutral demo data only).
Serve: `node design/mockup-v10/serve.mjs 8802`. Contrast: `node design/mockup-v10/contrast.mjs` (`--fails`, `--look L3`, `--no-designer`; the full sweep takes about 40 s).

Copy of v9 (v9 unchanged). New: the **Designer**, rail → **Designer** tab (now the first tab). Look switch gains **D**. A design is one digit per
control in the hash: `look=D&d=<24 digits>`, so a link reproduces it. Structure is locked as in v9.

## Round 2026-11-20 c: more colours, better pickers, "tweak everything"

User: "gimme even more options for colors, make the pickers make more sense, show when its colors it next to it, and yeah", then
"btw i want to be able to basically tweak everything, ux wise, font size in different places, contrast of hour dashes, etc".

**65 controls, 301 options, 20 change colours**, in six sections (Theme · Events · Text · Layout · Grid & time · States), ordered by importance;
rarely used controls sit in an **Advanced** fold inside each section. Each row: label, the current value (amber), a colour dot if the control
changes colours, a "changed from preset" dot, a lock (Randomize skips it), a one-line hint, and the widget that fits:
- **swatch** (colour chips with the real tokens): Canvas = two halves, current mode and the other mode, each with its sidebar strip, "Aa" in fg1 and a
  fg3 digit; Event colours = the calendar colours after the palette; Accent = the today circle in the accent with its text colour, plus a dot for the other mode;
  Sidebar / Right column / Header = a mini window.
- **preview** (a tiny mock drawn with that option's real colours, Personal-blue and a warm sample): fill, bar, edge, title colour, time colour, past,
  tentative, all-day chips, today marker, day header, grid lines, hour-label colour.
- **seg** (segmented, ≤ 4 options) and **step** (− · a row of steps · + · value) for numbers (radius, gap, hour height, weight, sizes, widths, line strengths).
- Unreadable options stay visible, struck through and greyed, with the reason as tooltip (dashed when only the other mode falls back).
- Presets, **Reset to <preset> (n)**, **Randomize** (respects locks; advanced controls mostly keep their default), **Copy link**, **Expand / Collapse all**,
  arrow keys on a focused row step through its readable options. Hash: `look=D&d=<65 base-36 chars>&dzb=<preset>&dzl=<locked keys>`; round-b links
  (`d=` with 24 digits) are mapped (every option kept its index; new ones were appended).

| Section | Control (options) |
| --- | --- |
| Theme | Canvas (16: + Stone, Mocha, Sage, Deep navy, Plum grey, High contrast, Nord) · Event colours (7: Default, Pastel, Vivid, Earthy, Muted, Jewel, Mono) · Accent (12: Ink, Blue, Red, Green, Violet, Indigo, Pink, Orange, Amber, Teal, Graphite, Cyan) · Adv: Sidebar shade (4) · Right column (4) · Header (3) · Hover & selected (3) |
| Events | Fill (12: + Glass, Inked, Tint fade, Deep solid) · Left bar (6) · Edge (4) · Corner radius (6) |
| Text | Title colour (6: + Soft neutral) · Time colour (5: + Grey, Faint) · Title weight (6) · Event text (3) · Font (4) · Adv: Month title (6) · Day header (4) · Hour labels (4) · Hour label colour (3) · Event time (6) · All-day chips (4) · Event line height (3) · Letter spacing (3) · Sidebar rows (3) · Sidebar headers (3) · Mini month text (3) · Right column text (3) · Editor text (3) |
| Layout | Time (4) · Extras (4) · Gap (5) · Hour height (6) · Day header (2) · Adv: Sidebar width (5) · Right column width (5) · Header height (5) · Day header height (4) · All-day chip height (4) · All-day rows shown (4) · Event padding (3) · Mini month (4: Normal, Compact, Large, Off) · Week numbers (3) · Weekend (3: Normal, Tinted, Narrower) · First hour shown (5) · Hour gutter (4) · One-line below (3) · Overlap indent (4) · Scrollbars (3) · Motion (2) |
| Grid & time | Grid lines (8: + Hairline, Hour + dashed half, Strong hour + faint half) · Day dividers (2) · Today marker (8: + Accent pill, Underline, Red dot) · Now line (4) · Adv: Hour line (6) · Half-hour line (5, incl. Off) · Half-hour style (3) · Day divider strength (5) · All-day separator (4) · Pane edges (4) · Now line thickness (4) |
| States | Past events (5: + Text only, Grey out) · Tentative (4) · Declined (2) · All-day chips (6: + Soft tint, Bar + text) |

Readability by construction (round c additions):
- **Event palettes** only remap the hue (OKLCH) that goes into the recipe; every text colour is fitted afterwards.
- **New canvases** derive their text greys with `autoFg` (fit against every canvas surface).
- **Chrome**: the main text stays put; a soft surface it misses on (hover, selected, shaded sidebar, right column, header) steps back toward the canvas until
  it fits, so the halation cap on near-black canvases (Lc ≤ 96) holds. Sidebar / right column shades step back the same way. fg2 / fg3 are refitted on every surface.
- **Live red** is fitted on every pane it can sit on. **Lines**: the hour line and the all-day separator are raised until ≥ 1.17:1; decor lines (half hour,
  day divider, pane edge) are capped at Lc 15. **Solid fills** darken until white passes (title, time, hover, selected); light-hue titles and times on them are fitted toward white.
- **Sizes** never relax a floor (a smaller size keeps the same targets).

Contrast proof (round c): `contrast.mjs` runs `designer-proof.mjs` in worker threads, one canvas each (≈ 2.5–3 min on 8 cores; `--no-designer` skips it).
The 20 colour controls split into groups that never share a pair, each crossed fully, both modes, 110 hues (16 calendar colours × 7 palettes, deduplicated):
chrome (canvas × sidebar × right column × header × hover), accent (× 12), lines (distinct fg1 × each line option × grid), events (distinct text greys × fill ×
title × time colour), past (× fill × past), chips (× all-day style × title × time colour, + past). That covers the full product (9.6 × 10¹⁴ designs × 2 modes).

**40,784 combinations, 20,729,768 pairs, 0 below target.** Tightest: fg1 on raised, Nord Dark with a darker sidebar, #EBEBEB on #252A35, 12.05:1, Lc 91 (floor 12:1).
Disabled: 1,035 of 17,280 event combinations (White title in Paper on the nine light fills: Outline, four tints, Raised card, Glass, Inked, Tint fade).

Round c trade-offs: Paper accents must carry white text at 12:1, so they are deep (navy, wine, forest …) and look alike in small sizes; Dark accents are pale tints.
Strong / Medium tint and Jewel / Vivid converge for saturated hues in Paper (fills stay at luminance ≥ .69). Shaded panes and strong hover step back where the
text would miss, so "Darker" / "Strong" are subtle on some canvases. Weekend "Tinted" is very light (2.5–3 %). The full proof takes ~3 minutes.

## Round 2026-11-20 b (first Designer)

## Files

- `designer.js`: `DESIGNER.CONTROLS` (24 controls), `PRESETS`, `decode/encode/valid`, `look(code)` (a look with the v9 interface plus `adVars`,
  `cls`, `H`, `o`), `titleAllowed(fill, title, mode)`. Built on `THEME.util` (the v9 maths from tokens.js: mix, WCAG, APCA, `fit`, tints, OKLCH).
- `designer.css`: the shape of every non-colour option, scoped to `.desk.dz` and `d-<control>-<option>` classes; the bundled fonts.
- `app.js`: `PK()` returns the Designer look for `look=D`; time layout, extras (location line, repeat / guests icons), all-day chip style.
  `panel.js`: desk classes; hour height follows the design (the grid keeps the same time at the top).
- `rail.js` + `shell.css`: the Designer tab (presets, Randomize, Copy link, live readability badge, one row per control).
- Fonts (all SIL OFL 1.1, bundled, no CDN): Inter (`fonts/Inter-OFL.txt`), Geist (`fonts/Geist-OFL.txt`), Instrument Sans (`fonts/InstrumentSans-OFL.txt`); System = SF Pro.

## Controls in round b (superseded by round c above; old links still map)

| Control | Options | Colour? |
| --- | --- | --- |
| Canvas (Dark + Paper pair) | 9: Neutral (#191919 / #FFFFFF), Warm, Cool, Graphite (v8), OLED black (#000), Soft black (#1F1F1F), Apple grey (#1E1E1E, lighter sidebar), Slate (#161B22), Card canvas | ● |
| Event fill | 8: Outline, Faint / Soft / Medium / Strong tint, Muted solid, Solid, Raised card | ● |
| Left bar | 6: None, 2 / 3 / 4 px flush, Inset rounded, Dot | |
| Title colour | 5: Auto, Neutral, Hue tint, Strong hue, White | ● |
| Title weight | 6: 400 450 500 560 600 700 | |
| Event text | 3: 11 / 12 / 13 px (time 10.5 / 11 / 11.5) | |
| Font | 4: Inter, System, Geist, Instrument Sans | |
| Time | 4: Start–end below, Start below, Inline after title, Hide on short | |
| Time colour | 3: Muted, Hue, As title | ● |
| Extras | 4: None, Location, Icons (repeat, guests), Location + icons | |
| Radius | 6: 0 2 4 6 8 10 | |
| Gap | 5: 0–4 px (right and between stacked blocks) | |
| Edge | 4: None, Hue line, Canvas ring, Soft shadow (overlaps always keep a 1 px canvas ring) | |
| Grid | 5: Hour quiet (.10), Hour (.14), Hour + half quiet (.10 / .03), Hour + half (.13 / .045), Strong (.18 / .06); the hour line is always drawn, ≥ 1.15:1 | ● |
| Day dividers | 2: On, Off | |
| Day header | 2: Inline "Wed 4", Stacked "WED / 4" | |
| Today marker | 5: Filled circle (accent), Red pill, Red circle, Outline, Bold only | ● |
| Now line | 4: Week · pill, Today · pill, Week · text, Today · text | |
| Tentative | 4: Hatch (stripes in the hover fill), Dashed outline, Striped bar, Faded (= past colours) | |
| Past events | 3: Light / Medium / Strong fade (fill → canvas .45 / .62 / .78) | ● |
| Declined | 2: Strike + fade, Strike only | |
| All-day chips | 4: As events, Solid, Dot + text, Outline | ● |
| Hour height | 6: 40 44 48 52 56 64 | |
| Accent | 5: Ink, Blue, Red, Green, Violet (Paper: darkened until white on it is 12:1 / Lc 90; Dark: lightened until the canvas colour on it is 12:1 / Lc 85) | ● |

24 controls, 2–9 options each (106 options).

## Presets

L0–L4 select the v9 looks as built (each has a nearest control setting, used when you change a control from it). Built from the controls:
- **Solid bright** `d=560421000132210103010121`: soft-black / near-white canvas, solid fills with white titles, location line, canvas ring, stacked header, filled-circle today in blue, hatch for tentative, solid all-day chips, 48 px hours.
- **Muted solid** `d=050121000022000010220010`: neutral canvas, muted solid fills (Dark ≈ #2F3F5C-like) with light titles, quiet hour-only grid, red today pill, striped-bar tentative, strong past fade.
- **Tinted bar** `d=632341001322010020010230`: Apple-grey canvas, medium tint + 3 px bar, strong-hue title and hue time, location + icons, red-circle today, hatch, dot + text all-day chips, 52 px hours.
- **Mono hue** `d=522321011022120000110021`: soft-black canvas, soft tint + 3 px bar, hue title and hue time, start time only, hue line edge, blue accent.

## Readability by construction

- Text that sits on a fill is always `fit()` against that fill (and its hover / selected / past / declined variants): it starts from the colour the option asks
  for and moves toward ink (Paper) or white (Dark) only as far as the floors need.
- Light text on solid fills: the fill is darkened in OKLCH (lightness only) until white passes as title, time, hover and selected; a light-hue title may darken it
  ≤ .06 more; every text colour is then fitted toward white.
- Fills under dark text keep relative luminance ≥ .69 (Paper; an ink title reaches Lc 75 from ≈ .68); fills under light text ≤ .045 (Dark). So a passing text colour always exists.
- The hatch stripes use the hover fill, which the title and time are fitted against too (new pair: time on hover / hatch).
- The only impossible pairing: a **White title on a light fill in Paper** (Outline, any tint, Raised card). It falls back to Auto; the rail strikes the option
  through with "Not readable with this fill" (dashed in Dark preview, where it works).
- Live badge in the tab: the current design's pairs (Dark + Paper, every calendar colour, every state, chips, neutrals).

## Contrast proof in round b (superseded)

Same targets as v8/v9. v9 looks: 1840 pairs, 0 fails (unchanged). Designer: the colour controls split into three groups that never share a pair, each crossed fully:
events = canvas × fill × title × time colour × past (3240 designs), chips = canvas × all-day style × title × time colour × past (1215), chrome = canvas × grid ×
dividers × today × accent (2250); × Dark and Paper × 16 calendar colours × every state. That covers the full product of the colour controls (1,620,000 designs × 2 modes).

**13,410 combinations, 1,603,800 pairs, 0 below target.** Tightest: fg1 on selected, Cool Dark, #F0F0F2 on #2D2D30, 12.06:1, Lc 93.6 (floor 12:1).
Fallbacks: 486 of 6480 event combinations (White title in Paper on the six light fills).

## Trade-offs

- **Strong tint in Paper is capped** for saturated hues (luminance ≥ .69), so Medium and Strong tint look alike for Tomato, Grape and similar colours.
- **Solid / Muted solid** darken light hues a lot (yellow → ochre, orange → rust), as in v9 L3; Muted solid in Paper reads as a deep desaturated fill.
- **Strong hue** titles in Dark end up close to white (Lc 75 on a hue fill leaves little hue).
- Hour height 40 makes 30-minute blocks one-line; extras (location line) only show on blocks tall enough for them.
- Mono hue uses each calendar's own hue (the mockup has many calendars); a true single-hue calendar looks like the third reference.

---

# v9 notes

Status: built and checked (2026-11-20). Tailnet: https://<tailnet-host>:8801/ (neutral demo data only).
Serve: `node design/mockup-v9/serve.mjs 8801`. Contrast: `node design/mockup-v9/contrast.mjs` (`--all`, `--fails`, `--look L3`).

Started as a copy of v8 (v8 stays unchanged). Round 2026-11-20 (`FEEDBACK.md`): v8 reads well but looks bad. v9 keeps the structure and the
readability floors and offers five **looks** (skins) side by side. Rail → **Look** switch next to Dark/Paper (hash key `look`, default **L1**).

## How a look is built

- `tokens.js`: `THEME.look(id)` returns a look with the same interface v8 had (`vars(th)`, `ev(hex, th)`, `evVars`, `calDot`, `check(th)`, `gap`).
  `THEME_L0` is v8's tokens.js verbatim. `LOOKS9` holds L1–L4: a neutral palette per mode, line mixes, an event recipe and a few extra variables
  (`--ev-w` title weight, `--r-ev`, `--shadow-card`, `--join-bg/-fg/-sh`, `--edge2`). Every text colour of a recipe goes through `fit()`: it starts from the
  colour the design wants and moves toward ink (Paper) or white (Dark) only as far as the contrast.mjs floors need (+ a small margin).
- `app.js`: `PK = () => THEME.look(V.look)`. Event geometry reads `PK().gap` (L0 = v8: 2 px left, 3 px right gap, 2 px between stacked blocks;
  L1–L4: 2 px left, 4 px right gap, 3 px stacked).
- `looks.css` (loaded last): shapes only, scoped under `.v9` (any of L1–L4) and `.pk-L1` … `.pk-L4`. L0 has no rule there; its screenshots match v8
  (at most 2/255 anti-aliasing noise on 1–2 pixels).
- Shared polish for L1–L4: title 12 px at 560–600 over the time at 11 px / 400 in the muted time colour; all-day chips take the same mark as
  timed blocks; quieter grid (hour line bg→fg1 .10–.12, still ≥ 1.15:1; half hour .03; day divider .07; all-day edge .12–.14); Join is a raised
  neutral button (white in Paper, `raised` in Dark, hairline + small shadow; the call logo carries the colour); the Now block in the right
  column is no longer a card in a panel (no fill, a hairline under it, 14 px / 600 title); neutral shadows (no warm rgba).

## The looks

| Look | Idea | Paper canvas · rail · fg1 | Dark canvas · rail · fg1 | Event recipe |
| --- | --- | --- | --- | --- |
| **L0 · v8** | v8 unchanged, for comparison | #F7F4EC · #F0ECE3 · #211E19 | #131315 · #0E0E10 · #EDEDEF | see "D3 tokens" below |
| **L1 · Clean bar** | Notion-Calendar-like | #FFFFFF · #F8F8F7 · #1D1D1F | #191919 · #141414 · #ECECEC | white/bg + 17 % / 20 % hue; 3 px bar flush left (hue, Paper 6 % toward ink); title fg1 + 18 % / 12 % hue, weight 560; radius 6 |
| **L2 · Soft solid** | Apple-Calendar-like | #FCFCFD · #F4F5F7 · #1C1D21 | #1C1C1F · #1A1A1D · #F0F0F2 | Paper: white + up to 26 % hue, luminance ≥ .70; Dark: bg + up to 30 % hue, luminance ≤ .045; 1 px inset edge (fill → hue 26 % / 20 %); title hue → ink .55 (Paper) / hue → white .50 (Dark), then fitted, weight 600; no bar; radius 6 |
| **L3 · Vivid** | Google / Cron solid | #FFFFFF · #F7F7F8 · #1B1B1F | #17171A · #151518 · #EEEEF0 | the hue darkened in OKLCH (lightness only, hue kept, chroma clipped to sRGB) until a white title (7:1, Lc 75), its time (white → fill 10 %) and the hover fill pass; title white 600; past = light tint (Paper) / bg + 30 % fill (Dark) with a hue-dark / grey title; selected = 1.5 px canvas gap + 1.5 px darker ring; radius 5 |
| **L4 · Cards** | Linear / Amie cards | #EFEFF2 canvas · #FAFAFB rail · #141417, cards #FFFFFF | #161618 · #111113 · #EDEDF0, cards #26262A | neutral card (raised) with `0 0 0 1px` + `0 1px 2px` shadow (Dark: inset 1px white 5.5 %); colour only as the 3 px bar; title fg1 560, time fg2; past card halfway to the canvas, bar faded; radius 6 |

Sample fills (Personal #5B8DEF · Team #E9B949 · Family #E5674F):

| Look | Paper fill / title | Dark fill / title |
| --- | --- | --- |
| L1 | #E3ECFC / #283144 · #FBF3E0 / #423927 · #FBE5E1 / #412A28 | #263044 / #DBE1EC · #433923 / #ECE6D8 · #422924 / #EBDCD9 |
| L2 | #D4E1FB / #273656 · #F9EDD0 / #5A4B2A · #F8D7D1 / #492928 | #2D3B58 / #D0DFFA · #433A27 / #F4DCA4 · #57322D / #F8D6CF |
| L3 | #2653B0 · #715403 · #A52B15, all white titles | #214DA9 · #6A4F03 · #9D220A, all white titles |
| L4 | #FFFFFF card / #141417, bars #5888E6 · #E0B247 · #DD644D | #26262A card / #EDEDF0, bars = calendar hue |

## Contrast (v9)

Same targets as v8. 1840 pairs (5 looks × 2 modes; 16 calendar colours × 9 event states per mode, neutrals, lines, status, now pill; new pair:
Join button text, held to the primary-button target 12:1 / Lc 85–90). **0 below target.**

| Look | Pairs · fails | Tightest pair Dark | Tightest pair Paper |
| --- | --- | --- | --- |
| L0 | 364 · 0 | hover title Tomato 9.20:1, Lc 77.1 | fg1 on selected 13.19:1, Lc 88.3 |
| L1 | 369 · 0 | event time Graphite 6.55:1, Lc 62.8 (floor 6.5 / 60) | selected title Tomato 10.01:1, Lc 75.6 (floor 75) |
| L2 | 369 · 0 | fg1 on selected 12.06:1, Lc 93.6 (floor 12) | selected title Grape 11.44:1, Lc 75.4 (floor 75) |
| L3 | 369 · 0 | event time Basil 6.56:1, Lc 79.1 (floor 6.5) | event title Slate (white on #4F596C) 7.05:1, Lc 89.4 (floor 7) |
| L4 | 369 · 0 | live text on card 5.89:1, Lc 46.8 (floor 45) | fg1 on bg 16.02:1, Lc 95.7 (floor 95) |

## Trade-offs and open points

- **L3 is limited by the 7:1 title floor.** White text at 7:1 needs a fill of relative luminance ≤ .10, so every hue ends up deep:
  blue #5B8DEF → #2653B0, red #E5674F → #A52B15, green #3FA36B → #026539. Light hues suffer most: Banana / Team #E9B949 → dark ochre
  #715403, Tangerine #F2884B → rust #914002, Graphite #B9B9B9 → #585858, Lavender #A9A6F5 → dusty violet #554F97. It looks good for
  blue, red, green and purple; yellow and orange read brown. Floors not lowered.
- **L2 Dark** titles are close to white (the bright-hue title can keep only a little hue at Lc 75 on a hue fill); the hue lives in the fill and edge.
- **Past events dominate** the demo week (now = Wed 18:15); every look keeps past clearly quieter, which makes Mon–Wed calm by design.
- **L4 Paper** canvas #EFEFF2 forced fg1 to #141417 (the Paper fg1 floor is Lc 95 on the canvas).
- Not changed: the today pill in the day header stays fg1 (a red pill would not reach the 12:1 primary target).

---

# v8 notes (L0)

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
