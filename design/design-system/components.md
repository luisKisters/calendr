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
| Day header | Height 32. Weekday `body` 400 in `fg2`, date `body-strong` 500. The today date sits on an `accent` circle (`onAccent`, 600). |

## Header
| Part | Spec |
|---|---|
| Month title | `title` 15 / 600 `fg1`, the year in 400 `fg3` |
| View switch | Segmented control: `surface` track, the selected segment `raised` with `fg1` |
| Buttons | Height 28, radius 8 |

## Sidebar
| Part | Spec |
|---|---|
| Mini month | Title `body-strong` 12 / 500. Day numbers `small` 11, 24 per cell. Today = `accent` fill. |
| Group header | `label` 12 / 500 `fg3`, height 24, 16 space above |
| Calendar row | Height 26. A 10 px colour square (the calendar mark `oklch(.70 Dark / .60 Paper, min(C₀, .14), H)`), gap 10, name `body` 12. |
| Padding | 12 left and right |

## Right column
| Part | Spec |
|---|---|
| Lead (Now) | Title 12 / 600 `fg1`, meta `small` `fg2`, Join button height 28 on `raised` with a hairline |
| List rows | Time 11 `fg2` tabular, a 3 × 14 bar in the calendar mark, title `body` 12 |

## Alignment
- Events, all-day chips and sidebar text: each set of text shares one left edge per column. G shows 0 red boxes in Dark and Paper.
- The hour gutter is 56. Day columns are equal. The weekend is not narrower.

## Do and avoid
- Do fit text colours to their real background, and check them with `contrast.mjs`.
- Do keep one decoration per state: bar + tint (normal), hatch (maybe), outline (needs reply), strike (declined).
- Avoid opacity on text or on text-like marks such as checkboxes.
- Avoid sizes other than 15, 12 and 11, and weights other than 400, 500 and 600.
- Avoid a second hue in the chrome. Colour belongs to calendars.
