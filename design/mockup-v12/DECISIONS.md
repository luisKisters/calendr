# Calendr v12: corner radii

Scale (`Theme.swift` `enum Radius`): 4 for events and chips, 8 for controls, 12 for surfaces. A shape nested in a padded parent uses the parent's radius minus the padding (6 = a row inside a 12 pt surface with 6 pt padding).

## Round 1 (locked)
The user said: "show me everywhere where this would make a difference but like zoomed into these parts to let me decide where its best"

These are the 12 spots where the radius audit changes a visible corner. Each one is drawn at 3× and at real size. The first option is the recommendation.

| Decision | Options | App now |
|---|---|---|
| Today number, week header | 4 · 6 · pill | pill |
| Today number, month view | 4 · 6 · pill | pill (11) |
| "+N" button on crowded events | 4 · pill · 6 | pill |
| "+N more" hover, all-day row | 4 · 8 | 8 |
| "N more" hover, month cell | 4 · 5 · 8 | 5 |
| Events in the "+N" stack panel | 8 (concentric) · 4 | 8 |
| Editor menu rows | 6 · 8 · 4 | 8 |
| ⌘K palette rows | 6 · 8 | 8 |
| Undo button in the toast | 6 · 8 | 8 |
| Eye button in a sidebar row | 6 · 8 · 4 | 8 |
| Remove (✕) on a reminder row | 6 · 8 · 4 | 8 |
| Loading bars in the sidebar | 4 · pill · 2 | pill |

"App now" means the code on `main`. The working tree already has the first proposal applied, with the stack panel at 4.

## Fixed without a decision
- Status-item colour bar: the literal 1.5 is now `Radius.bar`. The value is the same.

### Locked in round 1
Week-header today number 6 · month today number 6 · "+N" chip 4 · all-day "+N more" hover 4 · month "N more" hover 4 · stack-panel events 8 (concentric) · editor menu rows 6 · ⌘K rows 6 · toast Undo 6 · eye 6 · reminder ✕ 6 · loading bars 4.

## Round 2 (open)
- Space around ✕ on a reminder row. The user said: "padding around the btn looks weird". Options: even 4 pt with 4 pt corners · a 24 pt ✕ with even 2 pt and 6 pt corners · as now.
- Space around the eye in a sidebar row. The user said: "here as well". Options: even 2 pt with 6 pt corners · as now.
- Eye button look. The user said: "im not sure if i like it. but i gotta see it in the grand context". The scene "Eye in context" shows the real app. Options: box on hover (now) · no box, the eye brightens · no eye, click the colour square.

Answered without a decision:
- "didnt we remove the n+ more?" No. v11 removed the "+N more" rows in the native menu-bar menu (FEEDBACK E2). The grid "+N" chip, the all-day "+N more" and the month "N more" are still in the app.
- "does the outer border radius match the inner?" Yes. Menu 12 − 6 padding = 6 pt rows.
