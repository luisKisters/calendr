# Horion v16: today mark and today column

Shot of the app before this round: `shots/current-app.png` (`--snapshot v11-week`).

## Round 1 (open)
The user said: "perhaps it makes sense to have the same highlight as the day highlight has" and "the day highlight is a bit inconsistent".

Found: the header marks today with the `accent` pill, the mini month with a `selected` cell and `segRing` edge, the view switch with `raised` and a `segRing` edge. The `todayTint` covers the day header and the grid but not the all-day lane.

Open decisions: today mark, selected view, today column tint. All options use foundations.md tokens only.

## Round 1 (locked)
- Today mark: filled `accent` pill in the header and the mini month.
- Selected view: the same filled pill as today.
- Today column tint: the whole column, all-day lane included.

## Round 2 (replaced by round 3)
The user said: "You didn't give me options to choose which color is used to fill at the left side thing. Right now the contrast is really bad again".
Open: the mini month's week band fill (now `hoverRail`, about 1.08:1 on the rail) and the sidebar fill.

## Round 3 (locked)
The user said: "these decisions shouldn't be made on a per thing basis, that should be always the same. Contrast should always be good on these things and depending on the background it should be clear what color is on it."
Open: how hover, selected and edge colours are made on any background (fitted to contrast targets, fixed lightness steps, text-colour overlays, as now), and both sidebars' background.
The "Colour system" scene shows every background with its hover, selected and edge colours and the text on them, with WCAG contrast, and lets the user edit colours and targets.
Found: in Paper, fg3 #606067 on a selected fill is 3.9:1 (below 4.5). The fitted system darkens it to #565556.

Locked: "Fitted to a contrast target on every background"; both sidebars stay `rail`.
Built as `InkRGB.fitted(dark:)` and `enum Contrast` in Theme.swift: selected is the strongest neutral fill up to 1.45:1 on the rail on which fg1, fg2 and fg3 still pass the soft-surface floors (Dark 1.40:1, #2A2A2A; Paper about 1.15:1, #E8E8E8, capped by fg1's Lc 88); hover is the square root of that step on every surface (canvas, rail, raised, pop, inside the band); edges 3:1; today column 1.05:1. The text greys are unchanged.
Also built: the mini month's today is the filled pill, the selected segment of every `Segmented` is the filled pill, the today tint runs through the all-day lane. The Join button is left for its own thread.
Shots: `shots/after-dark.png`, `shots/after-paper.png`.
