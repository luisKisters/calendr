# Horion readability brief and design system (v5 to v6)

Written 2026-11-04 after looking at `r2-*.png` and `r3-*.png` and the tokens in `app.js` (`PAL`, `themeVars`, `evVars`) and `app.css`.
All contrast values below were computed with the WCAG 2.x relative-luminance formula and APCA 0.0.98G-4g. The script is in the scratchpad (`brief/c.py`).
Sign convention: APCA Lc is negative for light text on a dark background, so only the size of the number matters.

---

## 0. What is wrong today (measured)

| Problem | Evidence | Effect |
| --- | --- | --- |
| `--fg3` #6A6A6A on #000 | **3.88:1, Lc 25**. Fails WCAG AA for text. Lc 25 is below APCA's floor for any text (Lc 30). | "Week 45", "2026", "all-day", sidebar section titles, week numbers, shortcut hints, placeholders and icons all look faint and washed out. |
| `--fg2` #A0A0A0 on #000 | 8.0:1 but only **Lc 51**. | It passes WCAG, yet event times and secondary rows at 11.5 px look dim. WCAG 2 overrates dark pairs. |
| Event time #A0A0A0 on the yellow fill #4F3F19 | **3.90:1** (fails) | The time line in yellow, orange and gold events is hard to read. |
| Pure #000 with #F2F2F2 text | Lc 99 at 18.8:1 | This causes halation (glow and smear) at 11–12 px, especially for the roughly 1 in 3 people with astigmatism. |
| 13 font sizes in `app.css` (9, 9.5, 10.5, 11, 11.5, 12, 12.5, 13, 15, 16, 18, 22, 24) and 2 families | `grep font-size` | There is no rhythm, and the eye sees "many kinds of text". |
| Weight 600 is used 55 times, 500 6 times, 400 13 times | `grep font-weight` | When everything is semibold, nothing stands out. Bold has stopped meaning anything. |
| Every event has a fill, a 3 px colour bar and often an outline, stripes or a chip; the week grid is 34 % saturated navy | screenshots | The result is a blue wall with up to 4 visual devices per block. The grid has no calm resting state. |
| 7 calendar colours shown at the same time as checkboxes, all-day bars, dots and blocks | sidebar plus all-day lane | The colour that should mark one event is repeated everywhere. |
| The right column stacks Today, Now, Up next, Later and Useful shortcuts, each with its own title style | r3-week | It competes with the grid. No area has a single dominant element. |

---

## 1. Readability rules

### WCAG 2.2 (the legal floor)
- **1.4.3 Contrast (Minimum), AA:** text needs **4.5:1**. "Large" text needs 3:1, and large means at least 18 pt (24 px) regular or 14 pt (18.66 px) bold. **Every 11–13 pt UI label in Horion counts as normal text, so it needs 4.5:1.** Disabled controls and pure decoration are exempt. Placeholders are not.
- **1.4.6 Enhanced, AAA:** 7:1 for text. Use this as the target for event titles and times.
- **1.4.11 Non-text Contrast:** **3:1** for the parts of a control you need to identify it (field borders when they are the only cue, focus rings, checkbox outlines, the selected segment, the now line) and for meaningful graphics. Grid hairlines are decoration and are exempt.

### APCA (the perceptual target, better on dark)
The levels come from the APCA "Bronze" guidance. In CSS, px matches macOS pt at 1x.

| Lc | Use | Horion mapping |
| --- | --- | --- |
| **90** | Preferred for body text. Minimum for *non-body* text at **12 px/400**. | Event titles, row titles, field values: `--fg1`. |
| **75** | Minimum for body text at 18/400, 16/500 or 14/700. Non-body text from 15 px/400. | Text that is read on paper. On dark it is hard to reach without halation, so 11–13 px text uses Lc 70+ with weight 500. |
| **60** | Minimum for text people need to read that is not body text (it assumes larger sizes). | Secondary rows, event times and metadata: `--fg2` (aim for **Lc 70**). |
| **45** | Headlines, fine pictograms and outline icons. | Labels, hints and 14–16 px outline icons: `--fg3` (aim for **Lc 50**). |
| **30** | Absolute minimum for any text, such as placeholders and disabled text. | Disabled only: `--fg4`. |
| **15** | Minimum for non-text that must be seen: dividers and thick focus outlines. | Below this a hairline is "invisible". Use that for decorative grid lines on purpose. |

**Concrete targets for 11–13 pt UI text:**

| Role | On near-black (#0B–#15) | On off-white (#F7–#FA) |
| --- | --- | --- |
| Primary text (titles, values) | ≥ 12:1 **and** Lc 88–96 (do not exceed about 96, which avoids halation) | ≥ 12:1, Lc ≥ 95 |
| Secondary text (times, meta) | ≥ 7:1, **Lc ≥ 68** | ≥ 7:1, Lc ≥ 80 |
| Tertiary text (labels, hints, placeholders, icons) | ≥ 4.5:1 (we use ≥ 6.5:1), **Lc ≥ 48** and only at weight ≥ 500 or for icons | ≥ 5:1, **Lc ≥ 70** |
| Disabled | Lc 20–30, exempt | Lc 40–50 |
| Focus ring, selected segment, now line | ≥ 3:1 against the neighbouring colour | ≥ 3:1 |

Note that APCA is asymmetric. On dark, the same "grey level" reads weaker than on light. Dark-mode greys therefore have to sit **higher** (#A0+ for tertiary text) than people expect.

### Pure black and light grey on dark
- **Halation:** pure white on pure black glows and smears for readers with astigmatism. Most guidance moves the background to #111–#121212 and the text to #E6–#EEE.
- **OLED black is still possible** if the brightest text stays near #E6E6E8 (Lc about 92) and surfaces step up from #000 for raised elements (direction B).
- **Light grey on dark fails silently.** WCAG 2 says #6A6A6A on black is 3.9:1, which is close to passing, but APCA gives only Lc 25. Use APCA to tune dark-theme greys. Do not use opacity for text greys over coloured fills, because the result changes with every fill. Mix toward the fill colour with a fixed ratio instead (see the event recipe).
- **Thin weights on dark:** light text on dark looks bolder through irradiation. That makes 400 fine for body text. Do not go below 400. Weight 500 helps more at 11 px on dark than on light.

---

## 2. Typography for dense macOS UI

### Apple's macOS scale (`NSFont.preferredFont(forTextStyle:)`)

| Style | Size / line height | Weight |
| --- | --- | --- |
| Large Title | 26 / 32 | Regular |
| Title 1 | 22 / 26 | Regular |
| Title 2 | 17 / 22 | Regular |
| Title 3 | 15 / 20 | Regular |
| Headline | 13 / 16 | Bold |
| **Body** | **13 / 16** | Regular |
| Callout | 12 / 15 | Regular |
| Subheadline | 11 / 14 | Regular |
| Footnote / Caption 1 / 2 | 10 / 13 | Regular / Regular / Medium |

Horion's 12.5 / 11.5 sizes sit *between* Apple's steps. That is legal, but it gives up native alignment with menus and the system. **Proposal: 13 body, 11 small, with events at 12/500.** In practice 10 pt is the minimum for anything that is read, and Horion should not go below 11.

### SF Pro tracking at small sizes
SF tracks by size, in 1/1000 em at the given pt size. The system font applies this automatically in SwiftUI and AppKit. **The HTML mockup does not**, so set it there by hand:

| Size | Tracking |
| --- | --- |
| 10 pt | +0.12 pt |
| 11 pt | +0.06 pt |
| 12 pt | 0 |
| 13 pt | −0.08 pt |
| 15 pt | −0.23 pt |
| 17 pt | −0.43 pt |
| 20 pt and up (Display optical size) | the tracking table changes |

Never letter-space body text. ALL-CAPS labels would need +0.04–0.06 em, so use sentence case instead (already decided).

### Line height
- Dense rows use 13/16 to 13/18. Text in a 28 px row uses a 16 px line box.
- Multi-line event titles use 12/15. Notes and descriptions use 13/19 (about 1.45).

### Weights
- Use **2 weights in the UI plus 1 for titles: 400 and 500, with 600 only for the single dominant title in each area.**
- Use 500 for event titles, the selected row and the selected segment. Everything else is 400.
- Do not use 600 for labels or section headers. A smaller size and `--fg3` create the hierarchy, not weight.

### Numbers
- Use `font-variant-numeric: tabular-nums` (SwiftUI `.monospacedDigit()`) for every time, date, duration and mini-month digit, so times line up in columns and do not jump on hover or drag.

### Font choice

| Font | Fit for calendar density | Notes |
| --- | --- | --- |
| **SF Pro** (Text and Display) | Best native fit | Optical sizes and automatic tracking. It matches menus, sheets and the menu bar, and costs nothing to bundle. Narrow enough for 118 px day columns. |
| **Inter** (4.x, `opsz`) | Very good | Tall x-height and open apertures read slightly larger at 11–12 px. It has tabular figures, a slashed zero (`zero`) and disambiguation (`cv05` for `l`, `ss02`), plus an Inter Display cut for titles (used by Linear). It is wider than SF, so expect more ellipsis in week columns. It has to be bundled and set in SwiftUI with `.font(.custom)`. |
| **Geist** (Vercel) | Good | Swiss and slightly condensed with a crisp feel. Its tabular figures and Geist Mono suit time columns. It has less warmth and a smaller x-height than Inter, so use 12 px minimum. |
| **Instrument Sans** (current titles) | Hurts coherence | It is a second grotesque, close to SF but not equal (different `a`, `g`, widths and a wider 600). At 18 pt next to SF text it reads as an *almost-match*, which looks like a mistake rather than a choice. A display face helps only if it is clearly different (a serif) or the same family's Display cut. |

**Recommendation:** use one family for the whole UI. If you want a voice for titles, use a clearly different serif for **only** the 1–2 page titles (direction C), or the family's own Display cut (SF Pro Display or Inter Display).

---

## 3. Reducing visual noise

### Rules
1. **One dominant element per area.**
   - Grid: the events. The chrome around them is grey.
   - Sidebar: the mini month.
   - Right column: "Now / Up next". Everything else is `--fg2` or `--fg3`.
   - Editor: the title.
2. **Colour means calendar, and only calendar.**
   - The neutral UI uses 0 hues.
   - There is 1 alert hue (live red, used only for the now line and "Join" urgency).
   - There is 1 focus blue.
   - Calendar colours appear **once per event**, as the fill tint *or* the bar, never both at full strength.
   - In the sidebar a calendar is a 10 px colour square or circle that is filled when on and an outline when off. Do not use a checkbox on top of a coloured box.
3. **Order of tools: spacing first, then surface step, then hairline.**
   - Separate groups with 16–24 px of space.
   - Separate panes with a surface step of about 3–6 % lightness.
   - Use hairlines only where scrolling content meets fixed chrome (the grid header, the all-day lane) and for the hour grid.
   - Hour lines should sit **below Lc 15** (decoration). The half-hour line can be dropped or dotted at half the strength.
4. **Use at most 3 grey text levels.** Placeholders use `--fg3`, never a fourth grey.
5. **Icons:** use 16 px icons with 1.5 stroke in `--fg3`, and only where they *replace* a label or mark a row type (editor fields). Do not use an icon next to a label that already says the same thing ("Settings ⚙", "Search 🔍" inside a field that already says "Search events"). Third-party logos (Meet, Maps) appear only on the action that opens them.
6. **Do not repeat state.** Week number, year, "Today" header and "Wed 4 Nov" all say "today" in different places. Show each fact once.
7. **Use few event decorations.** Use one mark per state: outline for "needs reply", 45 % opacity for past, strike-through for declined, and drop the stripes for maybe (use a dotted outline instead).

### How the reference apps keep a dense calendar calm (observed; verify against the live apps)

| App | Event block | Text in event | Chrome |
| --- | --- | --- | --- |
| **Apple Calendar** (macOS 14–15) | Light tint of the calendar colour with a thin, saturated left bar | A *dark shade of the same hue* in light mode, light tint text in dark mode | No borders between panes. The sidebar is a material, and the grid lines are very faint. |
| **Notion Calendar / Cron** | Soft tinted fill from an 8-colour palette, no heavy border | Near-white in dark mode; darker text in light mode | Grid lines at about 9 % opacity. A single sans and tabular times. Chrome is almost monochrome. |
| **Fantastical** | Tinted fill. The selected event becomes a solid fill. | Hue-dark text on light, light text on dark | It is colourful, but the colour lives only in events. The rest is system grey. |
| **Amie** | Pastel, rounded, fully tinted blocks | Dark text | Big rounded radius and lots of white space. Density is traded for friendliness. |
| **Linear** (not a calendar, but the reference for calm dense UI) | n/a | n/a | Themes are generated in LCH from base, accent and contrast. Its stated goal is "reduce visual noise, maintain visual alignment, increase hierarchy and density". Accent leaks less into neutrals. Labels, icons and buttons are aligned with care. |

The common pattern: **neutral chrome, low-saturation tinted event fills, high-contrast event text, faint grid, one family, and colour only on events.** Horion already does the tinted fill, but at 34 % it is too saturated on black, and it adds a bar, outlines and pills on top.

---

## 4. Layout system
- **Grid:** use 4 px as the base and multiples of 8 for layout. The spacing scale is 4, 8, 12, 16, 24, 32. Remove 10, 14 and 20 from the CSS.
- **Row heights:** 28 for compact rows (sidebar, menus, the right column list) and 32 for interactive rows (fields, buttons, search, editor rows). Hour height stays 44 or 48 (48 = 6 × 8 fits the grid better and gives 12 px per 15 min).
- **Alignment columns:**
  - Sidebar: glyph at 16, text at 40.
  - Right column: content edge 20, time column 52 px wide and right-aligned with tabular figures, title at 64.
  - Editor: icon column 20–36, text at 48 (keep).
  - Every list with times uses the **same time column width**.
- **Widths:** sidebar 236 (the Apple range is 200–260), right column 320–340, week gutter 56–58.
- **Density:** keep one density. Make the hour height a user setting (44/52/60) instead of shrinking type.

---

## 5. Proposed Horion design system (base = direction A; B and C list their deltas)

### Colour tokens: dark

| Token | Value | On bg #111113 | Use |
| --- | --- | --- | --- |
| `--bg` | #111113 | | App canvas, grid, sidebar and right column (one surface) |
| `--surface` | #18181B | | Cards, all-day lane, segmented track |
| `--raised` | #202024 | | Fields, buttons, selected segment, menus (`--pop`) |
| `--hover` | fg 5 % over the background (#1A1A1D on bg) | | Hover. Always only lighter, never a hue. |
| `--selected` | fg 9 % (#222225) | | Selected row or day |
| `--hair` | #232327 (fg 8 %) | 1.2:1, Lc < 15 (decorative) | Pane edges and grid hour lines |
| `--hair-strong` | #3A3A40 | 1.9:1 | Field outline (fields also have a raised fill, so 3:1 is not needed) |
| `--fg1` | **#EDEDEF** | **16.1:1, Lc 95.7** | Titles, values, event titles |
| `--fg2` | **#C4C4CA** | **10.9:1, Lc 70.7** | Times, secondary rows, inactive tabs |
| `--fg3` | **#A0A0A8** | **7.3:1, Lc 50.7** | Labels, hints, placeholders, icons, hour labels |
| `--fg4` | #62626A | 3.1:1, Lc 21 | Disabled only |
| `--accent` | #EDEDEF ("Ink") | | Primary button fill and today pill, with text in `--bg` |
| `--focus` | #6E9BF5 | 6.9:1 on bg | 2 px focus ring with a 1 px gap |
| `--live` | #FF5A4F | 6.1:1 on bg | Now line and "starting now" only |

### Colour tokens: paper

| Token | Value | On bg #FAF9F6 | Use |
| --- | --- | --- | --- |
| `--bg` | #FAF9F6 | | Canvas |
| `--surface` | #F2F0EB | | Cards, all-day lane |
| `--raised` | #FFFFFF with a 1 px `--hair` and a soft shadow | | Fields, menus |
| `--hair` | #E6E3DC | 1.2:1, Lc 10 | Grid and panes |
| `--hair-strong` | #CFCBC2 | | Field outline |
| `--fg1` | **#1C1B20** | **16.3:1, Lc 100** | |
| `--fg2` | **#4B4952** | **8.4:1, Lc 87** (7.8:1 on surface) | |
| `--fg3` | **#625F69** | **5.9:1, Lc 78** (5.5:1, Lc 72 on surface) | It replaces #77747F, which is 4.38:1 and fails AA. |
| `--fg4` | #A3A0A8 | 2.5:1 | Disabled |
| `--focus` | #2F6BDC | 4.7:1 | |
| `--live` | #D93A2F | 4.3:1 | Lines only (needs 3:1). Never use it as text under 18 pt. |

### Event block recipe (one decoration per state)

**Fill**
- Dark: `mix(--bg, calColor, 0.24)`. This lowers the 0.34 used today and removes the navy wall.
- Paper: `mix(--bg, calColor, 0.16)`.

**Bar**
- 3 px at the left, inset 2 px, radius 1.5, in the calendar colour.
- Show it **only** when the fill is too pale to tell calendars apart (paper), or drop it entirely (direction A dark).

**Title**
- Dark: `--fg1`, 12 px/500.
- Paper: `mix(calColor, #0B0B10, 0.72)`, a hue-dark text like Apple Calendar.

**Time and meta**
- Use `mix(title, fill, 0.18)` in dark and `mix(title, fill, 0.15)` in paper, at 11 px/400 with tabular figures.
- Measured results:
  - Dark, every calendar colour: ≥ **6.5:1, Lc 63–70**. The worst case is yellow (6.6:1, Lc 64 at a 0.22 mix; 7.1:1, Lc 68 at 0.18).
  - Paper: title ≥ **9.4:1, Lc 85**, meta ≥ **6.2:1, Lc 75**.
  - Today's yellow time is 3.9:1 and fails, so this recipe fixes it.

| Event state | Treatment |
| --- | --- |
| Normal | Fill and title |
| Needs reply | No fill, a 1 px outline in the calendar colour, title `--fg1` |
| Maybe | Fill and a 1 px dotted outline (no stripes) |
| Declined | Fill at 50 %, title `--fg2` struck through |
| Past | Fill at 55 % toward `--bg`; title `--fg2`, meta `--fg3`, at full opacity. Do **not** fade the whole block: at 55 % opacity the meta drops to 3.6:1. With this recipe the title is ≥ 9:1 and the meta ≥ 5.7:1. |
| Selected | A fill one step stronger (`mix 0.40`) and a 1.5 px `--fg1` ring. No shadow. |
| Hover | Fill +4 % lighter only |

**Shape and layout**
- Radius 4. Padding 3 × 6. Leave a 1 px gap to the neighbour instead of a border.
- Titles at the top. Fewer than 30 min means one line with title and start time. Narrower than 48 px means a colour sliver only, and the content goes into a hover popover.

### Type scale (one family)

| Token | Size / line | Weight | Tracking (SF) | Use |
| --- | --- | --- | --- | --- |
| `title` | 20 / 24 | 600 | +0.38 → use the system default for Display | View title "November 2026" (the year in `--fg3`, same weight) |
| `heading` | 15 / 20 | 600 | −0.23 | Editor event title, right column "Now" title |
| `body` | 13 / 16 (18 in lists) | 400; 500 when selected | −0.08 | Rows, fields, menus |
| `event` | 12 / 15 | 500 | 0 | Event titles |
| `small` | 11 / 14 | 400 | +0.06 | Times, labels, hints, mini month, hour labels |

There are 5 sizes and 3 weights. Kill 9, 9.5, 10.5, 12.5, 16, 18, 22 and 24 (except the onboarding hero).

### Spacing, radius and elevation
- **Spacing:** 4, 8, 12, 16, 24, 32.
- **Radius:**
  - 4: events, chips, segments.
  - 6: rows, icon buttons.
  - 8: buttons, fields, the segmented track.
  - 12: menus, popovers, cards, dialogs.
- **Elevation (dark):** elevation comes from a lighter surface (`--surface` → `--raised`) plus a 1 px `--hair` ring. Use shadows only for floating layers (menus, popovers, dialogs): `0 8px 24px rgba(0,0,0,.5)`.
- **Elevation (paper):** a white raised surface with `0 1px 2px rgba(0,0,0,.06), 0 8px 24px rgba(0,0,0,.08)`.

### States
- **Hover:** a lighter (dark) or darker (paper) neutral tint, `--hover`. Never a hue, never a border.
- **Selected:**
  - Lists: `--selected` with text at 500.
  - Segments: a `--raised` segment with text in `--fg1`, while the others use `--fg2`.
  - The mini-month today pill uses `--accent`. The selected day gets a 1 px `--fg3` ring.
- **Focus:** a 2 px `--focus` ring with a 1 px offset on keyboard focus only (`:focus-visible`). It meets 3:1 in both themes.
- **Pressed:** `--selected`.
- **Disabled:** `--fg4`, with no hover.

### Components
- **Rows:** 28 high, text 13/400 in `--fg1`, meta in `--fg3` aligned right with tabular figures. Leading glyph 14–16. No row separators; group with 16 px of space and an 11 px `--fg3` group label.
- **Segmented control:** a `--surface` track at height 24, radius 8, padding 2. The selected segment is `--raised` with text at 500 in `--fg1`, and the others use `--fg2`. No hairline frame in dark mode, because the track step is enough.
- **Buttons:**
  - Primary: an `--accent` fill with `--bg` text at 500, height 28 or 32, radius 8.
  - Secondary: a `--raised` fill with text in `--fg1`.
  - Ghost: text in `--fg2` with a `--hover` background.
  - Use one primary button per view.
- **Inputs:** a `--raised` fill, height 32, radius 8, placeholder in `--fg3`, value in `--fg1`, and a focus ring. No outline at rest in dark mode. In paper mode use a 1 px `--hair-strong` outline.
- **Menus and popovers:** a `--raised` surface, radius 12, rows of 28, padding 4, hover in `--hover`, and keyboard hints in `--fg3` without boxes.

---

## 6. Three directions for the designers

All three use the scale, spacing, states and contrast floors above. The table values were computed against each direction's own background.

### A: "Calm graphite" (minimal; the base system above)
**Intent:** make the calendar feel quiet and expensive, like Notion Calendar or Linear. The page is graphite, not black, and the only colour is the events, at low saturation. Hierarchy comes from size and two greys, never from weight or lines.

- **Font:** SF Pro only. Drop Instrument Sans. Titles are SF Pro Display 20/600.
- **Tokens:** use the tables above.
  - bg #111113, fg1 #EDEDEF (16.1:1, Lc 96), fg2 #C4C4CA (10.9:1, Lc 71), fg3 #A0A0A8 (7.3:1, Lc 51).
  - Paper: fg3 #625F69 (5.9:1).
  - Events: dark fill mix 0.24 with **no colour bar** in dark (paper keeps a 3 px bar). Meta ≥ 6.5:1.
- **Removes:**
  - The event left bar (dark) and the stripes.
  - Sidebar checkboxes, which become colour dots.
  - Most hairlines: only the hour grid and the header edge remain.
  - Weight 600 except on titles.
  - The "Useful shortcuts" block from the right column (move it to `?`).
  - "Week 45" (move it to a hover or a setting).
  - The red now pill, which becomes a thin red line with a small dot.

### B: "Structured contrast" (OLED, high legibility)
**Intent:** keep the locked OLED black, but make everything crisp and scannable, like a well-set timetable. The structure is explicit: a visible grid, aligned time columns, solid but dark event fills with white titles. It is for people who read the calendar at a glance from across the desk.

- **Font:** Inter 4 (bundled) for UI text at 13/12/11 with `tnum`, `cv05` and `zero`, and Inter Display 600 for titles. It reads larger than SF at 11 px. If bundling is a no-go, use SF Pro with every time in `.monospacedDigit()`.
- **Tokens:**
  - bg #000000, surfaces #0E0E10 and #18181B.
  - fg1 **#E6E6E8** (16.9:1, Lc 92). This is off-white on purpose, against halation.
  - fg2 #C8C8CE (12.6:1, Lc 74), fg3 #A4A4AC (8.5:1, Lc 53).
  - Grid hairline #1A1A1D, and the hour line on the full hour at #26262A.
  - Events: fill mix 0.30 with a **3 px bar** and title #FFFFFF (≥ 11.4:1). Meta is mix(title, fill, 0.18) at **≥ 8.3:1, Lc 77–79**.
  - Paper: a pure #FFFFFF canvas, fg1 #111114 (18.9:1), fg2 #3E3E46 (10.6:1), fg3 #5A5A63 (6.8:1, Lc 84), event fill mix 0.20, title #111114 (≥ 14.5:1), meta ≥ 6.2:1.
- **Removes:**
  - The tint-on-tint layers: no outline plus fill plus stripes.
  - Two-line time blocks under 45 min: the time moves to the same line as the title.
  - The decorative all-day colour bars, which become small chips with a dot.
  - The year and week number from the header.
  - All 12.5 and 11.5 sizes.
- **Adds:** a fixed time column width shared by the grid, the day list and the right column, and stronger hour labels (`--fg2`).

### C: "Warm editorial" (paper-first, different voice)
**Intent:** a calm and personal planner that feels more like a well-printed diary than a dashboard (Amie's warmth with fewer toys). The neutrals are warm, the default is light, there is generous space, and the page titles are in a serif. That gives the app one clear voice instead of two near-identical sans faces.

- **Fonts:**
  - UI: Geist 13/12/11 (or SF Pro if bundling is unwanted), with tabular figures in Geist.
  - Titles: **Newsreader** or **Source Serif 4** at 22/600, used only for the view title and the editor event title.
  - Times: Geist Mono 11 in time columns only.
- **Tokens (paper):**
  - bg #F7F4EC, surface #EFEBE1.
  - fg1 #24211C (14.6:1, Lc 97), fg2 #4F4A41 (8.0:1, Lc 84), fg3 **#615B52** (6.1:1, Lc 77; 5.6:1 on surface).
  - Events: fill mix 0.18. The title is a hue-dark shade, mix(colour, #1A140C, 0.72), at ≥ 8.0:1, Lc 80. Meta is mix(title, fill, 0.12) at ≥ 5.9:1, Lc 72.
  - A 3 px bar.
- **Tokens (dark):**
  - bg #151412, surface #1C1B18.
  - fg1 #EEEAE2 (15.3:1), fg2 #C8C2B6 (10.4:1, Lc 69), fg3 #A49E92 (6.9:1, Lc 49).
  - Event fill mix 0.22 with no bar, and meta ≥ 6.5:1.
- **Hour height and spacing:** hour height 52, a larger 24/32 spacing between groups, and radius 6/10/14.
- **Removes:**
  - Instrument Sans.
  - The pure black theme as the default: dark becomes "warm night".
  - Blue as the default UI accent: the accent becomes ink #24211C, with focus still blue.
  - Grid lines on the half hour.
  - Colour checkboxes.
  - Icons on right-column rows.

### Quick comparison

| | A Calm graphite | B Structured contrast | C Warm editorial |
| --- | --- | --- | --- |
| Default theme | Dark graphite #111113 | OLED #000 | Paper #F7F4EC |
| Font | SF Pro only | Inter + Inter Display | Geist + serif titles (+ Geist Mono times) |
| Event block | Tint 0.24, no bar (dark) | Tint 0.30, 3 px bar, white title | Hue-dark text on pale tint, bar |
| Grid | Faint hour lines only | Visible hour lines, strong time column | Faint, no half hours, taller hours |
| Hierarchy tool | Size and grey | Alignment and contrast | Type voice and space |

---

## Sources
- WCAG 2.2, SC 1.4.3 Contrast (Minimum): https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
- WCAG 2.2, SC 1.4.11 Non-text Contrast: https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html
- APCA in a Nutshell (Lc levels, use cases, the dark-mode note): https://git.apcacontrast.com/documentation/APCA_in_a_Nutshell
- APCA contrast calculator: https://www.myndex.com/APCA/
- Apple HIG Typography (macOS text styles; verify the exact values on the page): https://developer.apple.com/design/human-interface-guidelines/typography
- WWDC20 "The details of UI typography" (SF optical sizes and tracking): https://developer.apple.com/videos/play/wwdc2020/10175/ and notes at https://wwdcnotes.com/notes/wwdc20/10175
- HIG spacing and tracking lesson (12 pt: 0, 13 pt: −6/1000 em): https://app.uxcel.com/courses/apple-hig/system-typography-sf-font-963/spacing-rules-1411
- Linear, "How we redesigned the Linear UI" (LCH themes, less noise, Inter Display): https://linear.app/now/how-we-redesigned-the-linear-ui
- Notion Calendar design analysis (soft fills, 9 % grid lines): https://blakecrosley.com/de/guides/design/notion-calendar
- Dark mode practices (avoid #000 and #FFF, halation): https://atmos.style/blog/dark-mode-ui-best-practices, https://uxplanet.org/alternatives-to-using-pure-black-000000-for-text-and-backgrounds-54ef0e733cdb, https://www.levelaccess.com/blog/accessibility-for-people-with-astigmatism/
- Material dark theme (#121212 base, surface elevation by lightness): https://m2.material.io/design/color/dark-theme.html
- Inter: https://rsms.me/inter/
- Geist: https://vercel.com/font

Caveat: the descriptions of event blocks in Apple Calendar, Fantastical and Amie are from product observation, not from official documentation. Check them against current screenshots before quoting them.
