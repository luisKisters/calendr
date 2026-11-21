# Horion v15: corner scale

Four scales, each rendered from the real app: Soft 4 · 8 · 12, Round 6 · 10 · 14, Tight 3 · 6 · 10, Sharp 2 · 4 · 8.

## Round 1 (locked)
The user said: "just use round btw go ahead and implment it", and "never completely circle where it doesnt like really mkae a lot of sense".
Then: "now all looks a tiny bit too rounded".

Locked: Round minus 1 pt, **5 · 9 · 13** (`Theme.swift` `enum Radius`). Nested rows and segments are 7 (`inner`, concentric with a 13 pt menu and 6 pt padding). Marks of 10 to 16 pt (calendar squares, checkboxes, swatches, keycaps, the now pill) stay at 4 (`mark`). The menu-bar preview keeps native corners (12 menu, 8 rows).
