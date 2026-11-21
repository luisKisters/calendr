# Components and patterns
Each spec uses the tokens in `foundations.md`. Sizes are in points.

## Event block (week and day grid)
| Part | Spec |
|---|---|
| Box | Fill and text from the event recipe. Radius 4.5. Padding 3 at the top, 6 at the right, 0 at the bottom. At the left the padding is 6 after the 3.5 bar. |
| Bar | 3.5 wide, flush left, full height, clipped by the radius |
| Text | Title `event` 12 / 500. The time is `small` 11 in the time colour, tabular, with 1 pt above it. |
| Two lines | Only when 3 + 15.5 + 14 + 2 ≤ height. The title clamps to as many lines as fit, at most 2. |
| One line | Title and time share one line box and sit vertically centred. A tall block that becomes one-line (cut by an overlap) keeps the 3 top padding. |
| Position | left = lane + 2 + cascade indent. width = lane − 4 − indent. top + 1. height = duration − 2, min 16. |
| Overlap (cascade) | 12 px per step, with a 1 px `bg` ring between layers |
| Hover | The hover fill |
| Selected | 1.5 px `bg` ring, then a 3 px ring in the bar colour |
| Past | The past fill and text. The bar is mixed toward the past fill by 50 %. No opacity. |
| Maybe | Hatch: 135° stripes, 5 px, in the hover fill. The time also passes on the hover fill. |
| Declined | The declined fill. Title and time struck through. |
| Needs reply | `bg` fill, 1 px outline in `edge`, no bar |

## Task marker
| Part | Spec |
|---|---|
| Box | Height 14, padding 0 5 0 4, radius 4.5. Uses the event fill of the Tasks calendar. |
| Checkbox | 8 × 8, radius 2, 1.25 px inset outline in the text colour. Full opacity, past or not. |
| Text | `small` in the title colour. Past markers use the past title colour (Dark ≥ 9:1 / Lc 72). |

## All-day lane
| Part | Spec |
|---|---|
| Chip | Height 19, gap 3, the same recipe and bar as events, `body-strong` 12 / 500 |
| Text edge | Chip text starts on the event-text edge: padding = 6 + 3.5 + 1, because chips sit 1 px further left than blocks |
| Lane | Up to 2 rows, then "+N more". Below it a 1 px line in `hairStrong`. |

## Grid
| Part | Spec |
|---|---|
| Hour line | 1 px `grid` on every hour. There is no half-hour line. |
| Day divider | 1 px `gridV` |
| Today column | `todayTint` under the column and its day header |
| Hour labels | `small` 11, `hourc`, right-aligned in the 56 gutter, tabular |
| Now line | Across the week 1 px `live` at 30 %. Today 2 px with an 8 px dot ringed by 1.5 px `bg`. The time sits on a `live` pill (`onLive` text). |
| Day header | Height 32. Weekday 12 in `fg3` (500 Dark, 400 Paper; `fg1` today), 8 from the column edge; date `body-strong` 500 (`fg2` before today) 6 after it. The today date sits on an `accent` pill 18 high, at least 20 wide (`onAccent`, 600). Hover only turns the text `fg1`. No rule under it: the all-day lane's `hairStrong` bottom edge is the one line. |

## Header
| Part | Spec |
|---|---|
| Month title | `title` 15 / 600 `fg1`, the year in 400 `fg3` |
| Height | 48, padding 0 12 0 20, gap 10. No week label (the ISO week is the title's tooltip). |
| View switch | Segmented control, 26 high: `surface` track (padding 2, radius 8), segments 22 high, radius 6; the selected one `raised` with `fg1` 500 and a 1 px `segRing` edge. Hover only turns the text `fg1` (no fill). |
| Buttons | Icon buttons 26 (radius 6, `fg3` glyph, hover wash + `fg1`); Today 26 high, radius 8, on `raised`. ‹ Today › 4 apart, then the right-column button. |

## Sidebar
| Part | Spec |
|---|---|
| Mini month | Title `body-strong` 12 / 500 (year 400 `fg3`) with 22 pt ‹ ›. Weekday letters and week numbers `small` `fg3` (500 Dark, 400 Paper). Day cells 24 high, 2 apart, numbers `small` 11 tabular: `fg2` in the month, `fg3` outside, `fg1` in the visible week, which sits on one `hoverRail` band (radius 6 at its ends). Today = `selected` cell with a 1 px `segRing` edge, 600. |
| Group header | `label` 12 / 500 `fg3`, height 24, 12 above and 2 below. Hover: `fg1` and a 12 pt chevron. A click folds the group; folded, the chevron points right and stays, and the count follows the name ("9 · 1 hidden"). |
| Calendar row | Height 26, radius 6, the hover box 4 past the pane padding. A 12 px colour square, radius 3 (the calendar mark `oklch(.70 Dark / .60 Paper, min(C₀, .14), H)`), gap 10, name `body` 12. An eye (15, `fg3`, 22 box) at the right on hover. Hidden: square at 35 % over the rail, name `fg3`, eye-slash always shown. |
| Settings | 28 high at the foot, "Settings" `body` `fg2` (no icon), ⌘ , in `fg3` at the right; hover `hoverRail` + `fg1` |
| Padding | 8 top, 12 left, right and bottom |

## Right column
| Part | Spec |
|---|---|
| Lead (Now) | Label 11 / 500 `fg3` + countdown in `live`; a 36 pt time column (start `fg2`, end `fg3`), a 3 pt bar in the calendar mark, title 12 / 600 `fg1`, meta `small` `fg2`. Join 30 high on `raised` with a 1 px edge, 12 / 500 `fg1`, ⌘J in `fg3` (a ghost with a `hairStrong` edge on Up next). A pane edge under the lead card. No "Today" heading, no shortcut list. |
| List rows | "Later today" label; rows 26 high, time 11 `fg2` tabular right-aligned in 36, a 3 × 14 bar in the calendar mark, title `body` 12 |

## Keycap
Locked in `design/mockup-v12-keycaps` round 1 (2026-11-21). `Keycap` / `Keycaps` in `Components.swift`; nothing draws a key by hand.
| Part | Spec |
|---|---|
| Cap | 16 high, at least 16 wide, 4 sides, radius 4. Fill `raised`, 1 px `capEdge` (bg → fg1 21 % Dark `#3A3A3C`, 18.5 % Paper `#D2D2D4`). Key `small` 11 / 400 `fg3`, tabular. |
| On a filled button | No fill; edge `onAct` 30 %, key `onAct` 62 % (This event ↩, Save ↩). |
| Shortcut | One cap per shortcut: ⌘Z, ⌥↑, ⇧⇥. Alternatives are separate caps: 3 apart in hints (↑ ↓), 11 apart in the shortcuts sheet (⌥↑ ⌥↓). 6 from the caps to their label. |
| Glyphs | ⌃ ⌥ ⇧ ⌘ in that order, then the key. ↩ ⌫ ⇥ ↑ ↓ ← →, `esc` as a word, letters upper case, punctuation as typed. ↩ is the SF Symbol `return` (10 pt, semibold), not the font glyph. |

## Alignment
- Events, all-day chips and sidebar text: each set of text shares one left edge per column. G shows 0 red boxes in Dark and Paper.
- The hour gutter is 56. Day columns are equal. The weekend is not narrower.

## Do and avoid
- Do fit text colours to their real background, and check them with `contrast.mjs`.
- Do keep one decoration per state: bar + tint (normal), hatch (maybe), outline (needs reply), strike (declined).
- Avoid opacity on text or on text-like marks such as checkboxes.
- Avoid sizes other than 15, 12 and 11, and weights other than 400, 500 and 600.
- Avoid a second hue in the chrome. Colour belongs to calendars.
