# Calendr

A native macOS SwiftUI calendar. It keeps what makes Notion Calendar good (dense week grid, keyboard-first command menu, menu bar list) and has its own identity (design v3, locked in `design/LOCKED.md`, specified by `design/mockup-v3/`): an ink ramp with no accent colour (selection and today are inverted ink), `live` red only for now, and Instrument Sans (bundled, tabular figures for every time) throughout. The only other colours are your calendars'. Week, day and month views; a 320 pt right panel that is always present and swaps between today (now, up next, later), the selected event and a new event; an hour scale that fits the week's events and zooms from the gutter; overlapping events that cascade; a command menu for commands, events and dates; undo pills; teammate overlays; a real `NSStatusItem` with a native `NSMenu` in the menu bar; and two stores: your real Google / iCloud / local calendars through EventKit, or fictional demo data. Tasks are an ordinary calendar: its entries are plain events, titles as they arrive.

Time format (12 or 24 hour) and the first day of the week follow System Settings > General > Language & Region. Demo mode pins 24-hour time and a Monday week start so snapshots are deterministic.

Motion follows one curve and four durations (120 / 180 / 260 / 300 ms) and collapses to instant under System Settings > Accessibility > Reduce Motion or Calendr's own Settings override. No third-party packages. SwiftPM only.

## Install

Download `Calendr.dmg` from the [latest release](https://github.com/luisKisters/calendr/releases/latest), open it and drag Calendr onto Applications. Starting with 1.1.1, releases are Developer ID signed and notarized by Apple. Open Calendr normally; macOS can ask you to confirm the first launch of an app downloaded from the internet. Calendr then asks for calendar access; without it you see an empty state with a shortcut to System Settings > Privacy & Security > Calendars. Browsers can still set `com.apple.quarantine` on signed downloads. You do not need to remove it.

## Run it

```sh
scripts/build-app.sh && open build/Calendr.app                # real calendars (asks for calendar access)
open build/Calendr.app --args --demo                          # demo data, clock pinned to Tue Sep 29 2026 11:48
open build/Calendr.app --args --demo --now "2026-10-12T09:00" # demo data with another pinned time
```

`scripts/build-app.sh` builds release, assembles `build/Calendr.app` (bundle id `com.luiskisters.calendr`, calendar usage descriptions) and ad-hoc signs it (`codesign -s -`).

To build a distribution release, use your Developer ID certificate and a saved `notarytool` keychain profile:

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-notarization-profile' scripts/make-dmg.sh
```

This enables the hardened runtime and a secure signing timestamp, notarizes and staples the app, then signs, notarizes and staples `dist/Calendr.dmg`. The script checks Apple's acceptance, both tickets, Gatekeeper, the mounted app signature and a demo launch. Without these variables, local builds remain ad-hoc signed.

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
| `T` | Go to today | `C` | Create event at the next free half hour |
| `J` or `Right` | Next period | `F` | Meet with... (stores that share availability) |
| `K` or `Left` | Previous period | `/` or `Cmd F` | Search events |
| `.` | Go to date ("oct 12", "12.10.", "next friday", "2026-12-24") | `?` | All keyboard shortcuts |
| `D` `W` `M` | Day / Week / Month | `Delete` | Delete selected event (recurring: this / all) |
| `` ` `` or `Cmd \` | Toggle sidebar | `Esc` | Leave the field / deselect / close |
| `Cmd K` | Command menu | `Cmd Z` | Undo create / move / resize / delete |
| `Ctrl Cmd K` | Open the menu bar menu | `Cmd R` | Refresh calendars |
| `Cmd 1` | Main window | `Cmd ,` | Settings |

Mouse: click an empty slot to select it, drag on the grid to create (15 minute snap), drag an event to move it across days, drag its bottom edge to resize, double-click to edit the title.

## How it is built

```
Sources/CalendrKit   Foundation-only logic: models, week math (locale first weekday), overlap + all-day layout, go-to-date parser,
                     command registry + fuzzy filter, upcoming grouping, duration/recurrence text, search, shortcut
                     resolver, EventKit mapping decisions. Swift Testing tests in Tests/CalendrKitTests.
Sources/Calendr      SwiftUI + AppKit shell. AppModel (@Observable @MainActor) owns state and caches layouts;
                     views are thin bindings. Stores/ has CalendarStore, EventKitStore, DemoStore.
  Views/             Sidebar, header, grid, right panel, command menu, settings, menu bar. The event grid, the hour lines,
                     the day header row and the mini calendar are Canvas/CoreGraphics; the menu bar is an NSStatusItem with
                     an NSMenu; everything else is native SwiftUI. Theme.swift holds the v3 tokens, Typeface.swift the
                     bundled Instrument Sans (Resources/Fonts).
  Headless/          --snapshot, --walkthrough, --perf drivers (offscreen window, video writer).
Tests/CalendrTests   App-level tests (model, gestures entry points, demo data vs the reference screenshot).
design/              LOCKED.md (the v3 decisions) and mockup-v3 (the specification), DESIGN.md (v2, superseded),
                     mockup-v2, icon, the v1 Notion references and mockup, states.json.
```

AppKit is used only where SwiftUI cannot: window chrome, the key event monitor, offscreen rendering, video writing, opening the menu bar item.

## Verify

```sh
scripts/verify.sh          # gates, build, tests, app bundle, snapshots, walkthrough-v3.mov, perf, launch time, DMG build + mount check
scripts/verify.sh --fast   # skips walkthrough video, perf and DMG
```

- **Unit tests**: `swift test` (CalendrKit logic and app model).
- **Snapshots**: `scripts/snapshots.sh` renders every state in `design/states.json` offscreen into `artifacts/snapshots/`; `scripts/compare-all.sh` writes mockup | snapshot | diff images to `artifacts/compare/`. Every visible difference to the reference is a bug.
- **Walkthrough / E2E**: `Calendr --walkthrough --record artifacts/walkthrough-v3.mov` is a fast tour of the demo week (about a minute, frames at 2x from the 1440x900 window, H.264 avc1, 60 fps, nothing drawn into the frames) with 45+ assertions. It writes `<file>.cursor.json` (cursor path and clicks in Glide's schema), `<file>.captions.json` and `<file>.zoom.json` next to the video; the exit code is non-zero on any failure. Animated steps get a frame for every 60 fps tick: a 2x `cacheDisplay` capture takes up to ~400 ms, so while recording the Motion tokens are stretched 24x (`Motion.timeScale`), frames are captured back to back and placed on the timeline at wall-clock time / 24, and sampling stops once the picture stops changing. The video plays every animation at true speed. (Capturing the composited window instead would need Screen Recording permission and an active display session.) Keyboard shortcuts and typing are real `NSEvent`s dispatched through `NSApp.sendEvent`. Grid pointer gestures call `AppModel.gridMouseDown/Dragged/Up`, the exact functions the SwiftUI drag gesture forwards to, because synthesized mouse events cannot reach SwiftUI while the process cannot become the active app (unattended or locked session).
- **Performance**: `Calendr --perf` navigates 50 weeks forward and 50 back with 300+ events per visible week and prints p50/p95 milliseconds per navigation (model reload + SwiftUI update + layout + draw) for week and month with animations off (the gated numbers: about 11-12 ms p50 / 15-17 ms p95 week, 11 / 13 ms month), the week again with animations on, and cold launch. `Calendr --demo --print-launch` prints launch-to-window time of the real app.

`scripts/walkthrough-video.sh` makes the polished video (`artifacts/walkthrough-v3.mp4`): it records the tour, renders it with [Glide](https://glide.dipxsy.app) (ink backdrop, rounded window, drawn cursor and click ripples, 7 explicit zooms) and burns the caption chips in with `scripts/caption-video.py`. Glide is a separate tool, so verify.sh does not run it.

Launch flags: `--demo`, `--now <ISO time>`, `--snapshot <state> --out <png> [--size WxH]`, `--walkthrough [--record <mov>]`, `--perf`, `--print-launch`.

## Known gaps

- The EventKit store could not be exercised here: the session has no calendar permission, so Google (CalDAV) and iCloud paths are reviewed and unit-tested at the mapping level only. Real-account behavior (saves, "this and following" spans, all-day dates, the debounced text saves) is unverified on a live account.
- Recurring edits from the right panel or drag always apply to the single occurrence; only delete offers this / all. Recurrence rules cannot be edited, only shown and stepped through.
- Tasks are plain events in their calendar; there is no completion state until a TickTick integration exists.
- The time zone is read at launch; changing it while running needs a relaunch.
- Search and the teammate list fetch a year each way on a background thread; visible-range fetches (a month plus a week either side) still run on the main thread.
- All-day events cannot be dragged in the grid (use the right panel). Participants can be added only in the demo store.
- The menu bar design is not locked yet (`design/mockup-v3/menubar.html` is the proposal); the menu uses the system font on purpose so it looks native.
- The DMG has no custom background.
- Screen capture of the running app needs Screen Recording permission, so pixel evidence comes from the offscreen renderer; real mouse gestures were never driven through the live window, and the animations were only observed through the offscreen window.
- `artifacts/walkthrough-v3.mov` and the snapshots show fictional demo data only. Older git history contains the previous personal demo data.
