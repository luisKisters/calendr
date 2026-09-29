# Calendr design system (v2)

v1 was a pixel copy of Notion Calendar. v2 keeps what makes Notion Calendar good (layout, density, keyboard-first flows, command palette, right-hand inspector, menu bar list) and gives Calendr its own identity, borrowing the NoteTakr design language so both apps feel like siblings.

## Rules

1. **Colour means two things.** `act` purple = you can act here: selection, focus rings, primary buttons, today marker, the selected week band in the mini calendar, active toggles, links. `live` red = now: the current-time line and its dot, "in 5 min" imminence in the menu bar. Nothing else in the chrome is coloured. Calendar colours belong to the user's data only (event fills, calendar checkboxes).
2. **Mono is the machine, Pro is the human.** Every time, duration, date number, keycap and GMT label the app produces is SF Mono with tabular figures. Titles, names, locations and notes are SF Pro.
3. **One background.** `ink-900` is the window. Depth is hairlines and raised `ink-800` / `ink-700` fills, never a different black. Neutrals carry a violet undertone.
4. **Selection is tinted, hover is not.** Selected rows and events use `act`; hover is a neutral wash.
5. **Nothing shifts.** Fixed trailing slots, reserved widths.

## Tokens (Dark)

| Token | Hex | Role |
|---|---|---|
| ink-900 | #0F0E14 | window background, grid |
| ink-800 | #16151D | sidebar, right panel, popovers |
| ink-700 | #1E1C28 | fields, chips, segmented controls |
| ink-600 | #2A2836 | keycaps, strong hairline |
| paper | #EDEBF5 | primary text |
| haze | #9A96AD | secondary text |
| haze-dim | #6B6880 | tertiary text, past-day headers |
| act / act-lift | #8B5CF6 / #A78BFA | action accent |
| row-sel | act @ .20 | selection band |
| row-hover | rgba(255,255,255,.03) | hover wash |
| live | #FF453A | now line, imminence |
| hair / hair-strong | rgba(237,235,245,.08) / .14 | grid lines, separators |

Light mode: warm paper background, lavender-tinted selection; derive contrast-appropriate values, don't reuse dark hexes.

## Events

Calendar colour drives a tint fill (colour at ~22% over ink-900), a 3pt leading bar in full colour, title in paper, time in mono haze. Selected event: 1.5pt `act` ring plus slight lift (shadow). Past events at 55% opacity. Declined: strikethrough + dashed outline in the calendar colour (not red; red means now). Tasks: capsule pill with a round checkbox glyph at the leading edge (checkable).

## Motion

`120ms` under the cursor (hover, press), `180ms` state changes (selection, toggles, inspector field swaps), `260–300ms` surfaces arriving (command palette scale 0.98→1 + fade, inspector slide-in, sheets, menu bar popover). One curve: cubic-bezier(.22,.61,.36,1) (`Animation.timingCurve(0.22, 0.61, 0.36, 1, duration:)`). Toggle knob and undo toast may overshoot slightly (spring). Week/day/month navigation: 180ms horizontal slide of the grid content with crossfade of the title, must stay under the perf budget (no layout recompute during the animation). Drag create/move/resize tracks the pointer with no animation; the drop settles in 120ms. Everything collapses to instant under System Settings > Accessibility > Reduce Motion.

## Identity

- App name Calendr. Wordmark in the sidebar top: small purple ring-and-dot glyph (echoing NoteTakr's record-ring icon, turned into a calendar dot) + "Calendr".
- App icon: ink-900 rounded tile, act-purple ring, a small live-red dot at the "now" position on the ring, plus a subtle 7-column grid hint. Generate `.icns` (1024 master drawn in code or SVG → iconutil).
- Proper empty states (no calendar access, no search results, no events today in menu bar) with a one-line explanation and a primary action.
- Toasts (undo, link copied) bottom-center, ink-700, with keycap hints.
