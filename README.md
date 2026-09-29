# Calendr

A native macOS SwiftUI calendar. It keeps what makes Notion Calendar good (dense week grid, keyboard-first command palette, right-hand inspector, menu bar list) and has its own identity (design v2, see `design/DESIGN.md`): an ink ramp with violet undertones, one action accent (`act` purple: selection, focus, today, primary buttons, toggles), one "now" accent (`live` red: the current-time line and imminence), SF Mono for every machine value (times, dates, keycaps) and SF Pro for everything human. Week, day and month views, tasks as checkable capsules, an Up Next card, an event inspector with write-through edits, teammate overlays, a menu bar calendar, empty states, undo toasts, and two stores: your real Google / iCloud / local calendars through EventKit, or fictional demo data.

Motion follows one curve and four durations (120 / 180 / 260 / 300 ms) and collapses to instant under System Settings > Accessibility > Reduce Motion or Calendr's own Settings override. No third-party packages. SwiftPM only.

## Install

Download `Calendr.dmg` (build it with `scripts/make-dmg.sh`; it lands in `dist/`), open it and drag Calendr onto Applications. The app is ad-hoc signed, not notarized: on first launch macOS refuses to open it by double-click. Right-click (or Control-click) Calendr in Applications, choose **Open**, then **Open** again in the dialog. macOS remembers the choice. Calendr then asks for calendar access; without it you see an empty state with a shortcut to System Settings > Privacy & Security > Calendars.

## Run it

```sh
scripts/build-app.sh && open build/Calendr.app                # real calendars (asks for calendar access)
open build/Calendr.app --args --demo                          # demo data, clock pinned to Tue Sep 29 2026 11:48
open build/Calendr.app --args --demo --now "2026-10-12T09:00" # demo data with another pinned time
```

`scripts/build-app.sh` builds release, assembles `build/Calendr.app` (bundle id `com.luiskisters.calendr`, calendar usage descriptions) and ad-hoc signs it (`codesign -s -`).

### Showing your Google and Apple calendars

Calendr reads calendars through EventKit, so anything macOS knows about shows up, grouped by account in the sidebar:

- **Google**: System Settings > Internet Accounts > Add Account > Google, sign in, keep "Calendars" on. The account appears under its gmail address with each calendar in its Google color.
- **iCloud / Exchange / CalDAV**: same place.
- **On My Mac**: calendars created locally in Calendar.app.

Then launch Calendr and press "Allow access". Cmd R asks macOS to re-sync remote sources; edits are written back through the account (typing is debounced into one save; edits to a recurring event apply to that occurrence, deletes ask this / all). Read-only calendars (holidays, subscribed, shared read-only) show no edit affordances and cannot be dragged. Attendees are shown but cannot be edited: EventKit has no API to add them. Direct Google Calendar API access (OAuth) would allow attendee editing and Meet links; it is out of scope because it needs a provisioned client ID.

## Shortcuts

Single keys only fire when no text field is focused.

| Key | Action | Key | Action |
|---|---|---|---|
| `T` | Go to today | `C` | Create event at next free half hour |
| `Option T` | Left-align today in view | `P` | Show teammate calendar |
| `J` or `Right` | Next period | `F` | Meet with... (sidebar field) |
| `K` or `Left` | Previous period | `/` | Search events (focuses the field) |
| `.` | Go to date ("oct 12", "12.10.", "next friday", "2026-12-24") |
| `D` `W` `M` | Day / Week / Month | `?` | All keyboard shortcuts |
| `` ` `` | Toggle sidebar | `Delete` | Delete selected event (recurring: this / all) |
| `Cmd /` | Toggle right panel | `Esc` | Deselect / close |
| `Cmd K` | Command menu | `Cmd Z` | Undo create / move / resize / delete |
| `Ctrl Cmd K` | Open the menu bar calendar | `Cmd F` | Search events |
| `Cmd 1` | Main window | `Cmd R` | Refresh calendars |
| `Cmd ,` | Settings | | |

Mouse: click an empty slot to select it, drag on the grid to create (15 minute snap), drag an event to move it across days, drag its bottom edge to resize, double-click to edit the title.

## How it is built

```
Sources/CalendrKit   Foundation-only logic: models, week math (Monday start), overlap + all-day layout, go-to-date parser,
                     command registry + fuzzy filter, upcoming grouping, duration/recurrence text, search, shortcut
                     resolver, EventKit mapping decisions. Swift Testing tests in Tests/CalendrKitTests.
Sources/Calendr      SwiftUI + AppKit shell. AppModel (@Observable @MainActor) owns state and caches layouts;
                     views are thin bindings. Stores/ has CalendarStore, EventKitStore, DemoStore.
  Views/             Sidebar, toolbar, grid, inspector, palettes, menu bar. The event grid, the mini calendar and the
                     hour lines, the day header row and the mini calendar are Canvas/CoreGraphics; everything else is native SwiftUI (List-free, Menu, Toggle,
                     Picker, TextField, MenuBarExtra).
  Headless/          --snapshot, --walkthrough, --perf drivers (offscreen window, video writer).
Tests/CalendrTests   App-level tests (model, gestures entry points, demo data vs the reference screenshot).
design/              DESIGN.md (v2 system), icon, states.json. (HTML mockups and reference screenshots are kept out of the public repo.)
```

AppKit is used only where SwiftUI cannot: window chrome, the key event monitor, offscreen rendering, video writing, opening the menu bar item.

## Verify

```sh
scripts/verify.sh          # gates, build, tests, app bundle, snapshots, walkthrough-v2.mp4, perf, launch time, DMG build + mount check
scripts/verify.sh --fast   # skips walkthrough video, perf and DMG
```

- **Unit tests**: `swift test` (CalendrKit logic and app model).
- **Snapshots**: `scripts/snapshots.sh` renders every state in `design/states.json` offscreen into `artifacts/snapshots/`; `scripts/compare-all.sh` writes mockup | snapshot | diff images to `artifacts/compare/` when the (private) mockup shots are present.
- **Walkthrough / E2E**: `Calendr --walkthrough --record artifacts/walkthrough-v2.mp4` tours every feature (about two minutes, 1440x900, H.264 avc1, 30 fps, moov first so it streams in browsers and chat viewers, captions drawn into the frame) with 85+ assertions; the exit code is non-zero on any failure. Animated steps are recorded in real time: frames are captured back to back while SwiftUI animates and placed on the 30 fps timeline by wall-clock timestamp, so slides, palettes, toasts and the checkbox pop play at true speed. Keyboard shortcuts and typing are real `NSEvent`s dispatched through `NSApp.sendEvent`. Grid pointer gestures call `AppModel.gridMouseDown/Dragged/Up`, the exact functions the SwiftUI drag gesture forwards to, because synthesized mouse events cannot reach SwiftUI while the process cannot become the active app (unattended or locked session).
- **Performance**: `Calendr --perf` navigates 50 weeks forward and 50 back with 300+ events per visible week and prints p50/p95 milliseconds per navigation (model reload + SwiftUI update + layout + draw) for week and month with animations off (the gated numbers: about 11-12 ms p50 / 15-17 ms p95 week, 11 / 13 ms month), the week again with animations on, and cold launch. `Calendr --demo --print-launch` prints launch-to-window time of the real app.

Launch flags: `--demo`, `--now <ISO time>`, `--snapshot <state> --out <png> [--size WxH]`, `--walkthrough [--record <mp4>]`, `--perf`, `--print-launch`.

## Known gaps

- The EventKit store could not be exercised here: the session has no calendar permission, so Google (CalDAV) and iCloud paths are reviewed and unit-tested at the mapping level only. Real-account behavior (saves, "this and following" spans, all-day dates, the debounced text saves) is unverified on a live account.
- Recurring edits from the inspector or drag always apply to the single occurrence; only delete offers this / all. Recurrence rules cannot be edited, only shown and stepped through.
- Tasks are events whose title starts with `[P1]`.. or that live in a calendar named Tasks/Reminders; completion is a local marker (EventKit reminders are out of scope), so it does not sync.
- The time zone is read at launch; changing it while running needs a relaunch.
- Search and the teammate list fetch a year each way on a background thread; visible-range fetches (a month plus a week either side) still run on the main thread.
- All-day events cannot be dragged in the grid (use the inspector). Participants can be added only in the demo store.
- The week-grid capsule slot search (free slot within 35 minutes, otherwise a 19 pt checkbox chip) is a heuristic fitted to the mockup, not a full packing solver.
- The menu bar item uses a template glyph plus text; SwiftUI cannot color part of a MenuBarExtra label, so the imminence is not red there (it is red inside the popover).
- The DMG is ad-hoc signed and not notarized (first launch needs right-click > Open); it has no custom background.
- Screen capture of the running app needs Screen Recording permission, so pixel evidence comes from the offscreen renderer; real mouse gestures were never driven through the live window, and the animations were only observed through the offscreen window.
