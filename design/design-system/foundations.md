# Foundations
The values come from the locked v11 mockup (R10 · Mine, round h, 2026-11-20). Dark is locked. Paper is derived from the Dark rules and approved for a check, not yet tuned.

Notation:
- `mix(a, b, t)` moves colour `a` toward `b` by the fraction `t`, in sRGB.
- `oklch(L, C, H)` is a colour in OKLCH. When a colour is out of gamut, only its chroma is reduced.
- `fit(c, bgs, to, floor)` moves `c` toward `to` in 1 % steps until it passes `floor` on every background in `bgs`.

## Colours
Neutral, with no hue cast. The Dark greys are solved for APCA targets: fg1 Lc ≈ 95, fg2 Lc 75, fg3 Lc 55.

| Token | Dark | Paper | Use | Swift |
|---|---|---|---|---|
| `bg` | `#0B0B0C` | `#FBFBFB` | Canvas, grid, header, unfilled events | `InkRGB.bg` |
| `rail` | `#070708` | `#F4F4F5` | Sidebar, right column | new `InkRGB.rail` |
| `surface` | `#151516` | `#F1F1F2` | Cards, all-day lane, segmented track | `InkRGB.bg1` |
| `raised` | `#1D1D1E` | `#FFFFFF` | Fields, buttons, menus, Join | `InkRGB.bg2` / `pop` |
| `hover` | `#161617` (bg → fg1 5 %) | `#F1F1F1` (4.5 %) | Row hover | `Theme.hover` |
| `selected` | `#1E1E1F` (8.5 %) | `#EAEAEB` (7.5 %) | Selected row | new |
| `fg1` | `#EBEBED` | `#1D1D20` | Titles, values, event titles, today pill | `InkRGB.fg` |
| `fg2` | `#CCCCCE` | `#4A4A50` | Times, secondary rows, hour labels | `InkRGB.fg2` |
| `fg3` | `#A8A8AA` | `#606067` | Labels, hints, group headers, icons | `InkRGB.fg3` |
| `fg4` | `#4E4E50` | `#B8B8B9` | Disabled only | new |
| `hourc` | = `fg2` | = `fg2` | Hour labels | new |
| `accent` / `onAccent` | `fg1` / `bg` | `fg1` / `bg` | Today date, primary button | `Theme.act`, `onAct` |
| `live` / `onLive` | `#FF6B5F` / `bg` | `#C9372C` / `#FFFFFF` | Now line, now pill, countdown. Nothing else. | `InkRGB.live` |
| `focus` | `#6E9BF5` | `#2F6BDC` | Focus ring, 2 px | `Theme.focus` |
| status ok / warn / danger | `#6CC58A` / `#E5B44A` / `#FF7B72` | `#2F7A4B` / `#8A5A00` / `#B4382D` | Status text | `Theme.reply*`, `danger` |

Lines are mixes from `bg` toward `fg1`.

| Token | Dark | Paper | Mix | Floor |
|---|---|---|---|---|
| `grid` (hour line) | `#212123` | `#E1E1E2` | 10 %; Paper is raised until it reaches 1.17:1 on bg and on the today column | ≥ 1.15:1, Lc ≤ 35 |
| `gridV` (day divider) | `#1B1B1C` | `#EBEBEC` | 7 %, capped at Lc 15 | decoration |
| `hairStrong` (all-day edge) | `#2A2A2C` | `#DCDCDC` | 14 %, raised to 1.17:1 | ≥ 1.15:1 |
| `hair` (pane edge) | `#1C1C1D` | `#E8E8E8` | 7.5–8.5 %, capped at Lc 15 | decoration |
| `todayTint` (today column) | `#131314` | `#F3F3F3` | 3.5 % (slider "Today column lightness") | Text and the hour line on it pass |
| half-hour line | off | off | none | |

## Event recipe (bar + tint)
The calendar colour goes in as an OKLCH hue H, with its own chroma C₀ as the upper limit. The same recipe applies to every calendar, so no calendar looks louder than another.

| Part | Dark | Paper |
|---|---|---|
| Fill | `oklch(.29, .074 × min(1, C₀/.1), H)`. Yellow hues (60–118°) get +.015 L and 15 % less chroma. | **Clear tint** (round h polish). Chroma basis `C = max(1.25 C₀, .075)`, or `C₀` when C₀ < .015 (greys), capped at .16. Search `t` from 0 in steps of .01 for `oklch(.975 − .25 t + off, C (.12 + .62 t), H)` until ΔE_OK to the canvas ≥ `9 × clamp(1 + 2.2 (.66 − L₀), .85, 1.25) × (Paper fill strength / 100)`. Here `off = clamp(.45 (L₀ − .66), ±.03)` and L₀ is the calendar's own OKLCH lightness. Result: ΔE_OK 7.7–10.6 for every calendar. |
| Hover | Fill L +.025 | Fill L −.022, C ×1.08 |
| Selected | Fill L +.05, C ×1.35, plus a 1.5 px `bg` ring and a 3 px bar-colour ring | Fill L −.05, C ×1.22, same rings |
| Bar | 3.5 px flush left, `oklch(.70, min(.25, 2.5 C₀), H)` | **4 px**, `oklch(.57 (+.10 for yellow), min(1.15 × max(C₀, C_bar), .22), H)` |
| Title | `#FFFFFF` (title L 1), fitted to ≥ 7:1 / Lc 75 | `fg1`, fitted to ≥ 7.4:1 / Lc 78 |
| Time | `oklch(.89, min(.062, 2 C₀), H)`, fitted to ≥ 6.5:1 / Lc 60 | `mix(title, fill, .3)` in hue, fitted to ≥ 6.1:1 / Lc 71 |
| Past | Fill → bg 55 %. Title `fg2` + 10 % title colour, fitted to ≥ 9:1 / Lc 72. Time `fg3`, fitted to ≥ 5.7:1 / Lc 58. | Fill → bg 60 %. Title fitted to ≥ 8:1 / Lc 78. Time `fg3`, fitted to ≥ 5.4:1 / Lc 68. |
| Declined | Fill → bg 50 %, title `fg2` fitted to 6:1 / Lc 55, struck through | Fill → bg 45 %, title `fg2` fitted to 6.8:1 / Lc 76, struck through |
| Maybe (hatch) | 135° stripes, 5 px, in the hover fill | the same |
| Needs reply | `bg` fill, 1 px outline in `edge` = `oklch(.68, .12, H)` (≥ 3:1) | `oklch(.56, .13, H)` (≥ 3:1) |
| Next / now | The now line goes across the week: 1 px live at 30 %, 2 px with a dot on today | the same |

Samples (fill / title / time): Personal `#5B8DEF` gives Dark `#162A50` / `#FFFFFF` / `#C9DCFE`. Swatches in Paper (fill / bar): Blueberry `#D1E1FE` / `#3970E0`, Lavender `#E2E2FE` / `#715EE0`, Grape `#DFD5F2` / `#9049E1`, Graphite `#E1E1E1` / `#959595`, Banana `#F6E6C3` / `#BB8D01`, Tomato `#F6D2CC` / `#DB1E1D`.

Paper visibility (round h polish): every calendar fill sits at ΔE_OK 7.7–10.6 from the canvas (target ≥ 7.5; before 3.8–8.4). The closest two swatches are Basil and Sage at 1.7 (before 0.1, Blueberry and Slate). ΔE_OK is the OKLab distance × 100; about 2 is just visible side by side. Paper options in the mockup: Clear tint (locked), Rich tint (ΔE ≥ 13), Tint + stronger bar (ΔE ≥ 6.5, 5 px bar L .50). The "Paper fill strength" slider runs 50–150 %.

## Typography
Face: Geist, bundled under SIL OFL (mockup `fonts/geist-latin*.woff2`). Use tabular figures for every time, date and count.

| Style | Size / line | Weight | Colour | Use | Swift |
|---|---|---|---|---|---|
| `title` | 15 / 21 | 600 (year 400 `fg3`) | `fg1` | Month title | `TypeSize.title` 18 → 15 |
| `body` | 12 / 18 | 400 | `fg1` | Sidebar rows, right column rows, base text, day-header weekday | `TypeSize.text` 12.5 → 12 |
| `body-strong` | 12 / 18 | 500 | `fg1` | Day-header date, mini-month title, all-day chips | `textMedium` |
| `label` | 12 / 18 | 500 | `fg3` | Sidebar group headers | `MicroLabel` → this |
| `event` | 12 / 15.5 | 500 | event title | Event titles | `TypeSize.event` 11.5 → 12 |
| `heading` | 12 / 20 | 600 | `fg1` | Right-column lead title, today's date | `textSemibold` |
| `small` | 11 / 14 | 400 | `fg2` / `fg3` | Event time (line 14), hour labels, mini-month days, all-day label | `TypeSize.small` 11.5 → 11 |

- Sizes in use: 15, 12, 11. Weights in use: 400, 500, 600. 600 appears only on the month title, today's date and the right-column lead.
- The roles map to the sliders as Title 15, Heading 12, Body 12, Label 12, Secondary 11.

## Layout
| Group | Values | Swift |
|---|---|---|
| Window | sidebar 236, right column 320, header 48, day header 32, hour gutter 56, hour 44 | `Dim.*` |
| Rows | sidebar row 26, all-day chip 19 (+3 gap) | `Dim.row` |
| Event block | padding 3 top, 6 left after a 3.5 bar; gap 2 left, 4 right, 2 below; radius 4.5; min height 16 | `EventPainter` |
| One-line rule | two lines only when 3 + 15.5 + 14 + 2 ≤ height; otherwise the time goes inline; the title clamps to the lines that fit | `EventPainter` |
| Pane padding | 12 (sidebar), header 20 | `Space.m` |
| Radius | 4.5 events and chips, 6 rows and icon buttons, 8 fields and buttons, 12 menus and dialogs | `Radius.*` |
| Spacing | 4, 8, 12, 16, 24 | `Space` |


## Font: Geist (locked 2026-11-20)
You said: "use geist fr". Geist is the only face for the whole UI. SF Pro and Instrument Sans are no longer used.
- Files the Swift build must bundle, in `Sources/Calendr/Resources/Fonts/`, copied by `scripts/build-app.sh` to `Contents/Resources/Fonts/`:
  - `Geist-Regular.otf` (400), `Geist-Medium.otf` (500) and `Geist-SemiBold.otf` (600), or one variable `Geist[wght].ttf` (100–900). Get them from the official release at https://github.com/vercel/geist-font (`packages/next/dist/fonts/geist-sans/` or the release zip). The mockup only has web subsets (`design/mockup-v11/fonts/geist-latin.woff2`, `geist-latin-ext.woff2`); do not convert those, use the full OTF/TTF.
  - Tabular figures come from the `tnum` feature (`kNumberSpacingType` / `kMonospacedNumbersSelector` in CoreText). Do not use `monospacedDigitSystemFont`, which is SF.
  - Licence: SIL Open Font License 1.1, "Copyright 2024 The Geist Project Authors". The text is `design/mockup-v11/fonts/Geist-OFL.txt`; ship it as `Fonts/Geist-OFL.txt` next to the font, the way `OFL.txt` ships for Instrument Sans today.
- Where the build replaces the current faces (`Sources/Calendr/Views/Typeface.swift`):
  - `enum Typeface` (`fileName = "InstrumentSans.ttf"`, `family = "Instrument Sans"`, `register()`, `ctFont`): register Geist instead. `main.swift:3` calls `Typeface.register()`.
  - `enum SF` (`ctFont` with `.systemFont` / `.monospacedDigitSystemFont`): this is SF Pro for all text and events. It becomes Geist through `Typeface.ctFont`.
  - `enum TypeSize`: `title` 18 → 15, `text` 12.5 → 12, `small` 11.5 → 11, `event` 11.5 → 12.
  - `extension Font`: `title18` and `title18Light` are Instrument Sans 18 and become `title15` (Geist 15 / 600, year 15 / 400 `fg3`). `text*`, `small*`, `event` and `eventTab` are SF and become Geist at 12 / 11.
  - Call sites of `.title18`: `CenterView.swift:71–72` (month title), `RightPanelView.swift:135` ("Today"), `PanelDetailView.swift:58` (editor title), `Overlays.swift:274` (dialog title), `RootView.swift:38`, `TimeGridView.swift:283` (empty state), `DeleteWithGuestsDialog.swift:14` and `Headless/SnapshotV4Layout.swift:76`. On the canvas, `EventsCanvas.swift:81` calls `SF.ctFont`.
  - Remove `Resources/Fonts/InstrumentSans.ttf` and its `OFL.txt` once nothing uses them. `scripts/build-app.sh` lines 16–18 copy them today.

## Open
- None for type or font. Paper's event colours were polished in round h ("Clear tint"). Check them once more in the app.
