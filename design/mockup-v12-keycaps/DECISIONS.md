# Calendr v12 keycaps decisions
Mockup: `design/mockup-v12-keycaps/index.html` (opens from disk). Built on the locked v11 tokens (`design/design-system/foundations.md`); only keycaps are open.

## Locked in round 1 (2026-11-21)
| Element | Pick |
| --- | --- |
| Keycap look | **Outline + raised fill** (not the recommendation): raised fill, 1 px `capEdge`, 16 high, radius 4 |
| Keycap on a filled button | **Outline in the button ink** |
| Shortcuts with a modifier | **One cap per shortcut** (not the recommendation): ⌘Z, ⌥↑ |
Built: `Keycap` / `Keycaps` in `Sources/Calendr/Views/Components.swift`, `Theme.capEdge`. Spec: `design/design-system/components.md` → Keycap.

## Options of round 1 (2026-11-21)
You said: "i think having like an outline thing around it perhaps would be nice lets generally better define how we have kbds"
Where: Everywhere · Dark / Paper (every place the app draws a keycap today), Close-up 3×, Design system.

### Keycap look
| Option | |
| --- | --- |
| **Outline: 1 px edge, no fill** (recommended) | 16 pt tall, min 16 wide, 0 4 pt padding, radius 4, edge bg → fg1 ≈ 18 % (`#3A3A3C` / `#D2D2D4`), glyph 11 / 400 fg3 |
| Outline + raised fill | the same, filled with raised |
| Physical key | raised fill, edge, 1 px heavier bottom |
| Fill only, no edge | soft grey fill |
| Bare glyph (now) | today's look |

### Keycap on a filled button
| Option | |
| --- | --- |
| **Outline in the button ink** (recommended) | edge onAct ≈ 30 %, glyph onAct ≈ 62 % |
| Soft fill in the button ink | 9 % onAct fill, no edge |
| Bare glyph (now) | |

### Shortcuts with a modifier
| Option | |
| --- | --- |
| **One cap per key, 3 pt apart** (recommended) | ⌘ and Z each in a cap |
| One cap per shortcut | ⌘Z in one cap |

## Defined without a decision (from the inventory)
- One spelling per key: ⌘ ⌥ ⇧ ⌃ ↩ ⌫ ⇥ ↑ ↓ ← →, `esc` as a word, letters upper case, punctuation as typed. Modifier order ⌃ ⌥ ⇧ ⌘.
- ↩ is the return-arrow icon (SF Symbol `return`), not the font glyph.
- Spacing: 3 pt between alternatives in a hint, 11 pt between shortcuts in the sheet, 6 pt from caps to their label. Today the app uses 3, 9, 10 and 11.
- Today `⌘J` is one string in the call row and the right column while `⌘ ,` is two caps in the sidebar: the pick above makes them one rule.
