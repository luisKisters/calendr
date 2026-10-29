# Calendr v4 tokens
Values come from `design/mockup-v4/index.html`: `PALETTES` ('oled'), `ACCENTS` ('ink'), `themeVars()`, `evVars()` and the `.ds` CSS.
`mix(a, b, t)` moves colour `a` the fraction `t` toward `b` (the mockup `mix` function). "fg 6.5 %" means `fg` at 6.5 % opacity.

The Swift code today has v3 values (Ink palette, Instrument Sans everywhere). The "Swift target" column uses the names from Phase 1 of `IMPLEMENTATION-PLAN.md`. If a target name does not exist yet, add it in the named file. Do not put the literal in a view.
## Colours (OLED black, ink accent)
Only the dark theme is locked. Light mode keeps the current Paper values in `Theme.swift` until a decision exists.
| Token | Value | Use | Swift today → target |
|---|---|---|---|
| `bg` | `#000000` | app, sidebar, right column, unfilled events | `Theme.bg` (`#0E0E11`) → `#000000` |
| `bg1` | `#0A0A0A` | cards (not for the sidebar any more) | `Theme.bg1` |
| `bg2` | `#141414` | fields, raised controls | `Theme.bg2` |
| `bg3` | `#1F1F1F` | switch track, "+N" chip | `Theme.bg3` |
| `pop` | `#0C0C0C` | menus, dialogs, toasts, stack panel | new `Theme.pop` |
| `fg` | `#F2F2F2` | content: titles, names, places, selected option | `Theme.fg` |
| `fg2` | `#A0A0A0` | secondary: times, addresses, counts | `Theme.fg2` |
| `fg3` | `#6A6A6A` | labels, hints, placeholders, icons | `Theme.fg3` |
| `hair` | fg 6.5 % | grid lines, sidebar and right column edge, separators | `Theme.hair` |
| `hair2` | fg 13 % | control frames, popover border | `Theme.hair2` |
| `hover` | fg 5.5 % | hover, selected row | `Theme.hover` |
| `thumb` | mix(bg3, fg, .08) = `#303030` | selected segment | `Theme.thumb` (`Components.swift`, `#33333C`) → `#303030` |
| `act` | = `fg` (ink accent) | primary button, Join, switch on | `Theme.act` |
| `onAct` | = `bg` | text on `act` | `Theme.onAct` |
| `today` / `onToday` | = `act` / = `bg` | today pill (accent pill) | `Theme.act` / `Theme.onAct` |
| `live` | `#FF453A` | now line, now label, countdown only | `Theme.live` |
| `scrim` | black 50 % | behind dialogs | `Theme.scrim` |
| `pillBg` | mix(bg, fg, .17) = `#292929` | task pills | add to `Theme` if used |
| danger fill | `#D9645A` | destructive button | add `Theme.danger` |
| danger text | `#E5776C` | danger menu item, declined mark | add `Theme.dangerText` |
| reply going | `#3FA45B` | check mark | add `Theme.replyYes` |
| reply maybe | `#D9A33A` | question mark | add `Theme.replyMaybe` |

Shadows: popover 0 22 60 black 50 %; dialog 0 30 80 black 55 %. Swift: `popShadow()` in `Theme.swift`.
## Event colours
`cc` = calendar colour (dark: the hex as is). Code: `Palettes.palette` (`Theme.swift`) and `EventPainter` (`EventsCanvas.swift`).
| Token | Formula | Example `#5B8DEF` | Swift today |
|---|---|---|---|
| `bar` | `cc` | `#5B8DEF` | `barRGB` |
| `fill` | mix(bg, cc, .34) | `#1F3051` | `fillRGB` (.17, tint style) → .34 |
| `fillPast` | mix(bg, cc, .15) | `#0E1524` | `pastFillRGB` (.08) → .15 |
| `barPast` | mix(bg, cc, .32) | `#1D2D4C` | add |
| `outline` (not answered) | mix(bg, cc, .75) | `#446AB3` | add |
| title / time | `fg` / `fg2` | | `titleRGB`, `timeRGB` (tinted) → `fg`, `fg2` |
| past title / time | `fg2` / `fg3` | | add |
| declined fill | mix(bg, fill, .38) | | add |

Calendar swatches (6-column grid): Tomato `#D9443A`, Flamingo `#C9736A`, Tangerine `#F2884B`, Banana `#F2C94C`, Sage `#5FB97E`, Mint `#9BD9C0`, Peacock `#5DADE2`, Blueberry `#5B8DEF`, Lavender `#A9A6F5`, Grape `#9254DE`, Graphite `#B9B9B9`.
## Type
Body face: SF Pro (system font). Title face: Instrument Sans (`Resources/Fonts/InstrumentSans.ttf`, registered by `Typeface.swift`).
| Token | Face | Size / weight | Use | Swift today → target |
|---|---|---|---|---|
| `title18` | Instrument Sans | 18 / 600, tracking −0.015 em (header −0.02 em) | month header, event title, Today, dialogs | `.calTitle` (22) → `Font.ui(18, .semibold)` |
| `text` | SF Pro | 12.5 / 400 | fields, rows, menus, buttons | `.calBody` (13, Instrument) → `.system(size: 12.5)` |
| `small` | SF Pro | 11.5 / 400 | times, addresses, segments, hour labels | `.calMeta` (Instrument) → `.system(size: 11.5)` |
| `label` | SF Pro | 11.5 / 600, `fg3`, sentence case | section labels | `MicroLabel` (10.5 caps) → sentence case 11.5 |
| `event` | SF Pro | 11.5 / 500, line height 1.25 | event titles, all-day items | `TextCache` kinds → `.system(size: 11.5, weight: .medium)` |
| `strong` | SF Pro | 12.5 or 11.5 / 600 | selected segment, primary button | `.weight(.semibold)` |

- Times, dates and counts: tabular figures. SwiftUI `.monospacedDigit()`. CoreText: `NSFont.monospacedDigitSystemFont`.
- Remove the sizes 22, 16, 13 and 10.5.
- Line box: 20 px for panel text, 16 px for secondary lines.
## Spacing, heights, radii, hairlines
| Group | Values | Swift target |
|---|---|---|
| Spacing | 4, 8, 12, 16, 24 | new `enum Space` in `Theme.swift` |
| Row height | 28 (lists, menus, sidebar, small buttons) | `Dim.row` |
| Field height | 32 (panel rows, buttons, fields, search) | `Dim.field` |
| Segment height | 22 | in `Segmented` |
| Icon button | 26 with 16 icon; 22 with 14 icon | `Dim.iconButton`, `Dim.iconButtonSmall`; `IconButton` |
| Radius | 6 rows, events, icon buttons, segments | `Radius.row` (7 → 6), `Radius.event` (6) |
| Radius | 8 buttons, fields, segmented controls | `Radius.control` (7 → 8) |
| Radius | 12 menus, dialogs, cards | `Radius.surface` (12); remove `+ 2` in `Overlays.swift` |
| Hairline | 1 px `hair`, frames 1 px `hair2` | `Hairline` (`Components.swift`) |
| Focus ring | 1.5 px `fg3` | `Theme.focus` (fg 46 %) → `fg3` |
| Selection ring | 1.5 px `bg` + 3 px `fg` | `Theme.ring` (fg 82 %) → `fg` |
| Chevron | 12 px | |

Layout: sidebar 236, right column 320, header 60, day header 38, hour gutter 58 (`Dim.hourGutter` is 56 → 58).
## Files to change
| File | What |
|---|---|
| `Views/Theme.swift` | colours, `pop`, `thumb`, `Dim`, `Radius`, `Space`, `Palettes`, `MicroLabel` |
| `Views/Typeface.swift` | type tokens: SF Pro for text, Instrument Sans for 18 only |
| `Views/Components.swift` | `Segmented`, `IconButton`, `PrimaryButton`, `SecondaryButton`, `Keycap` (no box), `Hairline` |
| `Views/PanelControls.swift` | remove `PanelRSVP` and `panelThumb`; use `Segmented` |
| `Views/CenterView.swift` | `ViewTabs` becomes `Segmented` |
| `Views/Overlays.swift` | surface radius 12, `pop` fill, settings switches as `Segmented` |
| `Views/EventsCanvas.swift` | `EventPainter.Ink` from `Theme`; reply states; text rules |
| `Views/EventViews.swift` | `EventStyle` reply states |
| `Views/DayHeaderView.swift` | `AllDayPainter` chips, today accent pill |
| `Views/SidebarView.swift`, `RightPanelView.swift`, `PanelDetailView.swift`, `MonthView.swift`, `MenuBarViews.swift` | fonts, radii, heights, alignment |
