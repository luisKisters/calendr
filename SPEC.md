# Calendr — spec

A native macOS SwiftUI app that copies Notion Calendar 1:1 (dark appearance first). Reference screenshots are in `design/reference/` and are the visual truth. When this spec and a screenshot disagree, the screenshot wins.

Owner: the maintainer. Priorities, in order: 1) it works, 2) it is fast, 3) it looks exactly like Notion Calendar, 4) UX is thought through (keyboard-first, every action reachable from mouse and keyboard). **Motion (v2)**: one curve, four durations, everything instant under Reduce Motion (see `design/DESIGN.md`; v1 of this spec forbade animation, v2 replaces that rule).

## Stack

- Swift 6 toolchain, Swift Package Manager, macOS 15+ deployment target. No Xcode project, no third-party packages.
- `Package.swift` with:
  - `CalendrKit` library: Foundation-only models and pure logic (event model, week/day math, overlap layout, all-day lane packing, command registry + fuzzy filter, natural-language "go to date" parser, upcoming-events grouping for the menu bar, search, recurrence description text, duration formatting). All logic lives here first, with tests.
  - `Calendr` executable: SwiftUI + AppKit shell, EventKit store, views. Views are thin bindings over an `@Observable` app model.
  - `CalendrKitTests`: Swift Testing (`import Testing`) tests. Add tests for named failures with observable results, not tests that restate implementation.
- `scripts/build-app.sh`: `swift build -c release`, assemble `build/Calendr.app` (Info.plist with `NSCalendarsFullAccessUsageDescription`, `NSContactsUsageDescription` not needed, bundle id `com.luiskisters.calendr`, `LSApplicationCategoryType` productivity), ad-hoc `codesign --force --deep -s -`.
- `scripts/verify.sh`: `swift build`, `swift test`, build-app, then the snapshot run (below). Must pass before any step is called done.

## Data

- `CalendarStore` protocol in the app target with two implementations:
  - `EventKitStore`: real macOS calendars (Google accounts added in System Settings show up here). Reads calendars grouped by source/account, events in a date range, creates/updates/deletes events, handles authorization (`requestFullAccessToEvents`). Listen to `EKEventStoreChanged` and refresh.
  - `DemoStore`: in-memory, fictional data (Alex Rivera: design student, freelance studio, part-time job at Northwind; example.com addresses). The showcase week is Mon Sep 28 - Sun Oct 4 2026: recurring classes, overlapping events, multi-day all-day events, tasks like "[P1] Water the plants", a declined dashed "Climbing" event, a tentative one, three accounts (`alex.rivera@mail.example.com`, `alex.rivera.studio@mail.example.com`, `alex.rivera@northwind.example.com`) with hidden and read-only holiday calendars, and eleven fictional teammates.