# Horion design system
The design system for Horion, the native macOS calendar client (SwiftUI + CoreGraphics). It covers Dark and Paper. Every value comes from the locked v11 mockup (round h, 2026-11-20).

## Sources
`design/mockup-v11/` is kept outside this repository (it holds personal calendar data). `scripts/v5-tokens.js <path to mockup-v11>` prints its locked colours; `Tests/HorionTests/PaletteV5Tests.swift` holds them.

Order of authority. If two sources disagree, the first wins.
1. `design/mockup-v11/DECISIONS.md`: the locks, the design-system block and the alignment result.
2. The mockup `design/mockup-v11/`. Use look R, preset **R10 · Mine**, with the `LOCKED` object and `READ.look()` in `readability.js`. CSS is in `rd.css`, `designer.css`, `looks.css` and `app.css`. The "Design system sheet" in the Readability tab shows live tokens for Dark and Paper.
3. The readability floors: `design/mockup-v11/contrast.mjs` (tables `T.dark` and `T.paper`) and `READABILITY-BRIEF.md`.
4. The current theme code, listed under "Code map" below. It is superseded wherever it disagrees.

Superseded and kept for history: `design/LOCKED.md` (v3), `design/DESIGN.md` (v2), and `design/mockup-v4/DECISIONS.md`.

## Principles
1. Use 3 text sizes only: **15** (month title), **12** (everything you read: events, rows, headings, labels) and **11** (times, hour labels, mini-month days, small labels). Weights and colours rank the text, not extra sizes.
2. Use 3 weights only: 400, 500 and 600. Reserve 600 for the month title and today's date. Geist is the only face (locked 2026-11-20); the app must bundle it.
3. Colour means calendar. Each event shows its colour once, as a 3.5 px bar plus a light tint. The chrome is neutral grey with no hue. The only other colours are live red (now) and focus blue.
4. Every text pair meets the floors in `contrast.mjs` (Dark and Paper). Text colours on event fills are fitted per fill, never dimmed with opacity.
5. Each event block uses one padding. When title and time do not both fit, the time moves inline after the title. Glyphs are never cut.
6. Text in the all-day lane, the events and the sidebar rows starts on shared edges. The alignment guides (G) show 0 red boxes.
7. In Paper every calendar fill is at least ΔE_OK 7.5 from the canvas (Clear tint), so each calendar reads as its colour.
8. Chrome steps back. Sidebars are one surface step darker than the canvas (Dark) or a light grey (Paper). The only grid line that must stay visible is the hour line (≥ 1.15:1).

## Check
- `swift test` runs `ViewTokenTests`: views may not use hex literals, named colours, system text fonts or literal font sizes. Add a token to `Theme.swift` / `Typeface.swift` and `foundations.md` instead.
- Run `node design/mockup-v11/contrast.mjs --rd`. The sweep checks every combination of the levers and a sampled sweep of the sliders, in Dark and Paper. The result must be 0 below target and 0 guard mismatches.
- In the mockup, the counter (X) must show 3 sizes (15, 12, 11) and 3 weights in the week view of R10, and G must show 0 red boxes in Dark and Paper.
- In the app, compare screenshots of the week view (demo data, Wed 18:15) with `design/mockup-v11` R10 in Dark and Paper at 1440 × 900.
- `Tests/HorionTests/PaletteV4Tests.swift` and the token tests compare `InkRGB` with the mockup. Update their expected values to `foundations.md`.

## Code map (token → Swift)
Do not change the Swift code from this file alone. These are the places to change when the system is built.

| Token group | File | Symbols |
| --- | --- | --- |
| Surfaces, text greys, live, hover, hair (Dark + Paper) | `Sources/Horion/Views/Theme.swift` | `InkRGB.dark`, `InkRGB.light` (`bg`, `bg1`→`surface`, `bg2`→`raised`, `bg3`, `pop`, `fg`, `fg2`, `fg3`, `live`, `thumb`, `hairAlpha`, `hair2Alpha`, `hoverAlpha`). Also `Theme.*` (`bg`, `fg`, `fg2`, `fg3`, `hair`, `hair2`, `hover`, `live`, `act`, `onAct`, `ring`, `focus`). Add `rail`, `todayTint`, `hourLine`, `dayDivider` and `hourLabel`. Remove the warm `paperScrim` and `paperShadow` (Paper is neutral now). |
| Event colours (fill, hover, selected, bar, title, time, past, declined, edge) | `Sources/Horion/Views/Theme.swift` | `EventPalette` (`barRGB`, `fillRGB`, `hoverFillRGB`, `pastFillRGB`, `titleRGB`, `timeRGB`) and `Palettes.palette(barHex:fillHex:dark:)`, `Palettes.cc`. These change to the OKLCH recipe in `foundations.md` and need an OKLCH helper plus a contrast `fit`. |
| Event states (normal, past, maybe hatch, needs reply, declined) | `Sources/Horion/Views/EventViews.swift` | `BlockColors`, `colors(reply:past:)` (stripe = hover fill, bar 3.5, no alpha dimming) |
| Event drawing (padding, bar, one-line rule, clamp) | `Sources/Horion/Views/EventsCanvas.swift` | `EventPainter`, `EventPainter.Ink`. Padding is 6 / 3, the bar is 3.5 flush, and the time goes inline when 3 + 15.5 + 14 + 2 > height. |
| Font (Geist, locked) | `Sources/Horion/Views/Typeface.swift`, `Sources/Horion/Resources/Fonts/`, `scripts/build-app.sh`, `main.swift` | Bundle Geist 400 / 500 / 600 as OTF or variable TTF, plus `Geist-OFL.txt` (SIL OFL 1.1). `enum Typeface` registers Geist instead of Instrument Sans. `enum SF` (SF Pro, `.systemFont` / `.monospacedDigitSystemFont`) is replaced by Geist with `tnum`. Details and call sites are under "Font" in `foundations.md`. |
| Text sizes and weights | `Sources/Horion/Views/Typeface.swift` | `TypeSize` (`title` 18 → 15, `text` 12.5 → 12, `small` 11.5 → 11, `event` 11.5 → 12) and the `Font` styles (`title18` → `title15`, `text`, `textMedium`, `small`, `event`, `eventTab`) |
| Sizes, spacing, radii | `Sources/Horion/Views/Theme.swift` | `Dim` (`sidebarWidth` 236, `panelWidth` 320, `hourGutter` 58 → 56, `toolbarHeight` 60 → 48, `dayHeaderHeight` 38 → 32, `row` 28 → 26 for sidebar rows), `Space`, `Radius` (`event` 6 → 4.5, `bar` → flush) |
| Hour lines, today column, now line, elapsed time | `Sources/Horion/Views/TimeGridView.swift` | Hour and half-hour drawing, the today column fill (new), and the now line (week 1 pt at 30 %, today 2 pt with dot) |
| Day header, today date, all-day lane | `Sources/Horion/Views/DayHeaderView.swift` | Today date fill (`act`/`onAct`, 600), `AllDayPainter` (chip = event recipe, text aligned with event text) |
| Sidebar: mini month, group headers, rows | `Sources/Horion/Views/SidebarView.swift` | Mini-month title `.textSemibold` → 12 / 500, group headers (`MicroLabel` in `Theme.swift`) → 12 / 500 `fg3`, rows 12 / 400 |
| Header (month title, view switch) | `Sources/Horion/Views/CenterView.swift` | Month title → 15 / 600, the view switch `Segmented` (`Components.swift`) |
| Right column | `Sources/Horion/Views/RightPanelView.swift`, `PanelDetailView.swift` | Rows 12, times 11 `fg2`, the lead title 12 / 600 |
| Menus, dialogs | `Sources/Horion/Views/Overlays.swift`, `Components.swift` | `pop` material, Paper shadow neutral |
| Tests | `Tests/HorionTests/PaletteV4Tests.swift` | Expected colours |
