# Calendr — spec

A native macOS SwiftUI calendar (dark appearance first). `design/mockup-v4/` and `design/mockup-v4/DECISIONS.md` are the visual truth (v4; the "copy Notion Calendar 1:1" rule ended with v3). When this spec and the mockup disagree, the mockup wins. Type: SF Pro for text, Instrument Sans 600 only for 18 pt titles. Light theme: Paper, with the v4 token roles.

Owner: the maintainer. Priorities, in order: 1) it works, 2) it is fast, 3) it looks exactly like the v4 mockup, 4) UX is thought through (keyboard-first, every action reachable from mouse and keyboard). **Motion (v2)**: one curve, four durations, everything instant under Reduce Motion (see `design/DESIGN.md`; v1 of this spec forbade animation, v2 replaces that rule).

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
  - `DemoStore`: in-memory, fictional data: the design/mockup-v4 week (`DemoDataV4`, `--demo`). Sam Rivera with three accounts (`sam.rivera@example.com` with Personal, Family, Tasks and Running club; `sam@northwind.example` with Work; `sam@sideproject.example` with Side project), the week Mon Sep 28 - Sun Oct 4 2026 with "now" at Sun 4 Oct 15:10 and 46 pt hours: overlapping evenings, invitations in every reply state, multi-day all-day events, tasks like "[P1] Take vitamins", guests (some names only in Contacts), Meet and Zoom calls, and eleven fictional teammates with the mockup's busy blocks for Meet with. Every address uses a reserved example domain. Only that week has events; `--perf` adds 300 generated events a week.