# Calendr v10 · designer notes

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
