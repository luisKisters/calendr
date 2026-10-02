import AppKit
import SwiftUI
import CalendrKit

/// The v3 tour: a fast scripted walk through the demo week, recorded at 2x / 60 fps with no overlays. Next to the video it writes the cursor
/// telemetry and the captions (`<file>.cursor.json`, `<file>.captions.json`) that Glide and scripts/caption-video.py use afterwards.
/// Keyboard shortcuts are real NSEvents through the key router; pointer gestures call the model functions the SwiftUI gestures forward to;
/// buttons call the same model methods their actions call. Every step asserts that it worked.
@MainActor
enum Walkthrough {
    static func run(_ o: LaunchOptions) -> Int32 {
        Motion.forcedInstant = false          // the video shows the real animations
        let model = HeadlessRunner.makeModel(o)
        let rec = o.record.flatMap { VideoRecorder(url: URL(fileURLWithPath: $0), width: Int(o.size.width * 2), height: Int(o.size.height * 2), fps: 60) }
        if o.record != nil && rec == nil { print("could not open recorder"); return 2 }
        let d = Driver(model: model, size: o.size, recorder: rec)
        let started = Date()
        if rec != nil { Motion.timeScale = Driver.recordingTimeScale }
        tour(d, model)
        rec?.finish()
        if let path = o.record { d.writeTelemetry(to: path) }
        let secs = rec.map { String(format: "%.1f", $0.seconds) } ?? "-"
        print("walkthrough: \(d.checks) checks, \(d.failures.count) failures, video \(secs)s, animations stretched \(Int(Motion.timeScale))x, wall \(String(format: "%.1f", Date().timeIntervalSince(started)))s")
        if !d.failures.isEmpty { d.failures.forEach { print(" - \($0)") } }
        return d.failures.isEmpty ? 0 : 1
    }

    static func placed(_ m: AppModel, _ title: String, day: Int) -> PlacedEvent? { m.layout.timed[day].first { $0.event.title == title } }

    static func centerOf(_ d: Driver, _ p: PlacedEvent, yFraction: Double = 0.4) -> CGPoint {
        let r = d.model.gridGeometry.rect(for: p)
        return CGPoint(x: r.minX + r.width * 0.5, y: r.minY + r.height * yFraction)
    }

    static func tour(_ d: Driver, _ m: AppModel) {
        let math = m.math
        func startDay() -> Int { math.day(m.visibleStart) }
        func hhmm(_ date: Date) -> String { m.fmt.time(date) }
        /// Window point of the hour gutter at a y inside the grid viewport.
        func gutterPoint(y: Double) -> CGPoint { CGPoint(x: m.gridViewport.minX + Theme.gutterWidth / 2, y: m.gridViewport.minY + y) }

        // 1. The week
        d.section("The week")
        d.check(m.headerTitle == "September 2026" && m.weekLabel == "W40" && m.viewMode == .week && m.visibleDays.count == 7, "week view of W40")
        d.check(m.layout.timedCount > 60, "timed events laid out (\(m.layout.timedCount))")
        d.check(m.todayIndex == 1 && m.gridState.fit != nil && m.gridHandHeight == nil, "Today is column 2, hours are fitted")
        d.check(m.panelState.today.next?.title == "Calculus" && m.upcoming.next?.title == "Calculus", "Up next is Calculus")
        d.check(!Motion.reduced || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, "motion is on")
        d.say("The week, fitted to your day")
        d.frame(hold: 2.4)
        d.say("Today counts down: Calculus in 12 min")
        d.check(PanelText.until(Int(m.panelState.today.next!.start.timeIntervalSince(m.now) / 60)) == "in 12 min", "countdown reads in 12 min")
        d.hold(2.2)

        // 2. An event opens in the right column
        d.section("Event detail")
        guard let sam = placed(m, "Sam / Alex", day: 1) else { d.check(false, "Sam / Alex exists"); return }
        d.say("Click an event to see it")
        d.zoomIn(on: CGPoint(x: 900, y: 430))
        d.clickGrid(centerOf(d, sam))
        d.check(m.selectedEvent?.title == "Sam / Alex" && !m.isDraftOpen, "click selects Sam / Alex")
        d.check(m.selectedEvent?.participants.isEmpty == false && m.selectedEvent?.conferencing.isEmpty == false, "detail has guests and a call")
        d.hold(2.0)
        d.say("Answer Going? in place")
        d.click(at: CGPoint(x: 1239, y: 276)) { m.updateSelected { $0.status = .tentative } }
        d.check(m.selectedEvent?.status == .tentative, "Going? Maybe is written")
        d.hold(1.2)
        d.say("Esc closes it", keys: ["esc"])
        d.play(0.5) { d.special("esc") }
        d.check(m.selectedEventID == nil, "Esc deselects, the panel returns to Today")
        d.hold(0.5)
        d.zoomOut()
        d.hold(0.5)

        // 3. Create by dragging
        d.section("Create")
        d.say("Drag to create an event")
        d.zoomIn(on: CGPoint(x: 900, y: 430))
        let before = m.layout.timedCount
        d.drag(from: d.gridPoint(day: 3, minute: 12 * 60), to: d.gridPoint(day: 3, minute: 13 * 60))
        d.check(m.draft != nil && m.isDraftOpen, "drag opens a draft")
        d.check(m.draft.map { hhmm($0.start) == "12:00" && hhmm($0.end) == "13:00" && math.weekdayIndex($0.start) == 3 } == true, "draft is Thu 12:00-13:00 (got \(m.draft.map { m.fmt.timeRange($0.start, $0.end) } ?? "nil"))")
        d.check(m.layout.timedCount == before + 1, "the draft shows on the grid")
        d.settle(6)
        d.say("Type a title")
        d.moveCursor(to: CGPoint(x: 1150, y: 110))      // the hand moves to the panel; the camera follows it there
        d.type("Lunch with Maya")
        d.check(m.draft?.title == "Lunch with Maya", "title typed into the draft (\(m.draft?.title ?? "nil"))")
        d.hold(0.4)
        d.say("Return saves it", keys: ["\u{21A9}"])
        d.play(0.6) { d.special("return") }
        d.check(m.draft == nil && m.selectedEventID == nil, "Return saves; the panel returns to Today")
        d.check(m.layout.timed[3].contains { $0.event.title == "Lunch with Maya" }, "the saved event is on Thursday")
        d.hold(1.2)
        d.zoomOut()
        d.hold(0.4)

        // 4. Move, undo
        d.section("Move and undo")
        guard let piano = placed(m, "Piano lesson", day: 3) else { d.check(false, "Piano lesson exists"); return }
        let pid = piano.event.id, pc = centerOf(d, piano)
        d.say("Drag an event to move it")
        d.zoomIn(on: CGPoint(x: 780, y: 640))
        d.drag(from: pc, to: CGPoint(x: pc.x + 2 * m.gridGeometry.dayWidth, y: pc.y))
        d.check(m.event(id: pid).map { math.weekdayIndex($0.start) == 5 && hhmm($0.start) == "13:00" } == true, "Piano lesson moved to Sat 13:00 (got \(m.event(id: pid).map { m.fmt.timeRange($0.start, $0.end) } ?? "nil"))")
        d.check(m.toast?.undo == true, "the undo pill appears")
        d.say("The undo pill appears")
        d.moveCursor(to: CGPoint(x: 735, y: 861), duration: 0.45)      // the camera follows the hand down to the pill
        d.hold(1.0)
        d.say("Click Undo")
        d.click(at: CGPoint(x: 719, y: 861)) { m.dismissToast(); m.undo() }
        d.play(0.4) {}
        d.check(m.event(id: pid).map { math.weekdayIndex($0.start) == 3 } == true, "Undo moves it back")
        d.hold(1.0)
        d.zoomOut()
        d.play(0.4) { d.special("esc") }
        d.check(m.selectedEventID == nil, "Esc closes the restored event")

        // 5. The hour gutter
        d.section("Hour scale")
        d.say("Drag the gutter to zoom the hours")
        d.zoomIn(on: CGPoint(x: 520, y: 470))
        let fitted = m.gridHourHeight
        let gy = Double(m.gridViewport.height) * 0.45
        d.moveCursor(to: gutterPoint(y: gy))
        d.recordClick()
        m.gutterZoomBegan(y: gy)
        d.gesture(0.55) { e in
            d.cursor = gutterPoint(y: gy + 150 * e)
            m.gutterZoomChanged(y: gy + 150 * e)
        }
        m.gutterZoomEnded()
        d.settle(4); d.frame()
        d.check(m.gridHourHeight > fitted * 1.5 && m.settings.hourHeight != nil, "gutter drag zooms (\(Int(fitted)) -> \(Int(m.gridHourHeight)) pt per hour)")
        d.hold(0.8)
        d.say("Scroll to see the night")
        let startY = Double(m.gridScrollY), endY = max(startY, m.gridGeometry.totalHeight - Double(m.gridViewport.height))
        d.moveCursor(to: CGPoint(x: m.gridViewport.minX + 300, y: m.gridViewport.minY + 300))
        d.gesture(0.6) { e in
            m.gridState.scrollTarget = startY + (endY - startY) * e
            m.gridState.scrollTick += 1
        }
        d.check(Double(m.gridScrollY) > startY + 100, "grid scrolled to the night (\(Int(startY)) -> \(Int(m.gridScrollY)))")
        d.hold(0.8)
        d.say("Double-click the gutter to fit again")
        d.moveCursor(to: gutterPoint(y: gy))
        d.recordClick()
        d.frame(hold: 0.12)
        d.recordClick(double: true)
        d.play(0.6) { m.fitHourScale() }
        d.check(m.settings.hourHeight == nil && abs(m.gridHourHeight - fitted) < 1, "double-click fits the hours again")
        d.hold(0.9)
        d.zoomOut()
        d.hold(0.4)

        // 6. Command menu
        d.section("Command menu")
        d.say("Command menu", keys: ["\u{2318}", "K"])
        d.zoomIn(on: CGPoint(x: 720, y: 330))
        d.moveCursor(to: CGPoint(x: 800, y: 120))
        d.play(0.5) { d.key("k", cmd: true) }
        d.check(m.overlay == .command, "Cmd-K opens the command menu")
        d.hold(0.9)
        d.say("Type a date: next fri")
        d.type("next fri")
        d.check({ if case .date(let x)? = m.paletteRows.first?.kind { return math.day(x) == 9 && math.month(x) == 10 }; return false }(), "first row resolves next fri")
        d.hold(0.3)
        d.say("Return goes there", keys: ["\u{21A9}"])
        d.play(0.7) { d.special("return") }
        d.check(m.overlay == nil && startDay() == 5 && math.month(m.visibleStart) == 10, "Return navigates to the week of 5 Oct")
        d.hold(0.8)
        d.say("T comes back to today", keys: ["T"])
        d.play(0.6) { d.key("t") }
        d.check(startDay() == 28 && m.todayIndex == 1, "T returns to today")
        d.hold(0.6)
        d.say("Search events", keys: ["/"])
        d.play(0.4) { d.key("/") }
        d.check(m.overlay == .command && m.chromeState.paletteMode == .search, "/ opens event search")
        d.type("calc")
        d.check(m.paletteRows.contains { if case .event = $0.kind { return true }; return false }, "search finds events")
        d.hold(0.6)
        d.say("Return opens the first result", keys: ["\u{21A9}"])
        d.play(0.7) { d.special("return") }
        d.check(m.selectedEvent?.title == "Calculus", "Return opens Calculus")
        d.hold(1.0)
        d.play(0.4) { d.special("esc") }
        d.check(m.selectedEventID == nil, "Esc closes the detail")
        d.say("Meet with overlays a teammate", keys: ["F"])
        d.play(0.4) { d.key("f") }
        d.check(m.overlay == .command && m.chromeState.paletteMode == .meet, "F opens Meet with")
        d.hold(0.5)
        d.type("maya")
        d.check(m.paletteRows.first?.title == "Maya Sterling", "filter finds Maya Sterling")
        d.play(0.6) { d.special("return") }
        d.check(m.shownTeammates.count == 1 && m.overlayLayout.timedCount > 0, "Maya's calendar is overlaid")
        d.hold(1.8)
        d.say("Click the chip to remove it")
        d.click(at: CGPoint(x: 535, y: 30)) { if let t = m.shownTeammates.first { m.toggleMate(t) } }
        d.check(m.shownTeammates.isEmpty && m.overlayLayout.timedCount == 0, "the header chip removes the overlay")
        d.hold(1.0)
        d.zoomOut()

        // 7. Views
        d.section("Views")
        d.say("M for month", keys: ["M"])
        d.play(0.6) { d.key("m") }
        d.check(m.viewMode == .month && m.monthEvents.count == 42, "M shows the month")
        d.hold(1.3)
        d.say("D for day", keys: ["D"])
        d.play(0.6) { d.key("d") }
        d.check(m.viewMode == .day && m.visibleDays.count == 1, "D shows the day")
        d.hold(1.3)
        d.say("W for week", keys: ["W"])
        d.play(0.6) { d.key("w") }
        d.check(m.viewMode == .week && m.visibleDays.count == 7, "W shows the week")
        d.hold(0.8)

        // 8. Settings
        d.section("Settings")
        d.say("Settings", keys: ["\u{2318}", ","])
        d.zoomIn(on: CGPoint(x: 720, y: 330))
        d.moveCursor(to: CGPoint(x: 800, y: 300))
        d.play(0.6) { d.key(",", cmd: true) }
        d.check(m.overlay == .settings, "Cmd-, opens Settings")
        d.hold(0.8)
        d.say("Turn on week numbers")
        d.click(at: CGPoint(x: 982, y: 411)) { m.settings.showWeekNumbers = true }
        d.check(m.settings.showWeekNumbers, "week numbers are on")
        d.hold(1.0)
        d.say("Switch to Paper")
        d.click(at: CGPoint(x: 966, y: 333)) { m.settings.appearance = .light; d.win.setDark(false) }
        d.settle(8); d.frame()
        d.check(m.isPaper, "appearance is Paper")
        d.hold(1.2)
        d.say("And back to Ink")
        d.click(at: CGPoint(x: 919, y: 333)) { m.settings.appearance = .dark; d.win.setDark(true) }
        d.settle(8); d.frame()
        d.check(!m.isPaper, "appearance is Ink")
        d.hold(0.6)
        d.say("Esc closes Settings", keys: ["esc"])
        d.play(0.5) { d.special("esc") }
        d.check(m.overlay == nil, "Esc closes Settings")
        d.hold(0.5)
        d.zoomOut()
        d.say("The mini month shows week numbers")
        d.check(m.settings.showWeekNumbers, "week numbers stay on in the mini month")
        d.hold(1.7)

        // 9. Menu bar (the real NSMenu cannot be captured offscreen; the preview draws the same model)
        d.section("Menu bar")
        func itemLabel() -> String { m.menuBarMenu.focus.map { "\(m.menuBarMenu.itemTitle ?? "") \u{00B7} \($0.text)" } ?? "" }
        d.check(itemLabel() == "Calculus \u{00B7} in 12 min", "menu bar item reads \(itemLabel())")
        let backdrop = d.win.image(scale: 2).map { NSImage(cgImage: $0, size: NSSize(width: 1440, height: 900)) }
        let menu = m.menuBarMenu
        let f = m.fmt
        let clock = "\(f.weekdayShort(m.now)) \(math.day(m.now)) \(f.monthShort(m.now))  \(f.time(m.now))"
        func screen(open: Bool, highlight: Int?, submenu: [MenuBarSubItem]?) -> AnyView {
            AnyView(MenuBarScreenPreview(menu: menu, display: m.settings.menuBarDisplay, clock: clock, backdrop: backdrop, highlight: highlight, submenu: submenu, open: open))
        }
        let bar = OffscreenWindow(screen(open: false, highlight: nil, submenu: nil), size: CGSize(width: 1440, height: 900), chrome: false)
        bar.settle(6)
        d.say("The menu bar says what is next")
        d.source = bar
        d.frame(hold: 1.6)
        d.say("Click it to open the day")
        d.zoomIn(on: CGPoint(x: 1100, y: 300))
        let item = CGPoint(x: 1110, y: 15)
        d.moveCursor(to: item)
        d.recordClick()
        bar.host.rootView = screen(open: true, highlight: 0, submenu: nil)
        bar.settle(6)
        d.play(0.3) {}
        d.check(menu.rows.first?.title == "Calculus", "the open menu lists Calculus first")
        d.hold(0.9)
        d.say("Hover an event for its menu")
        guard let samIdx = menu.rows.firstIndex(where: { $0.title == "Sam / Alex" }) else { d.check(false, "Sam / Alex is in the menu"); return }
        func rowY(_ i: Int) -> Double { 32 + Double(MenuBarMenuPreview.rowTop(i, in: menu)) + 11 }
        let sub = m.menuBarSubmenu(for: menu.rows[samIdx].event)
        d.moveCursor(to: CGPoint(x: 1180, y: rowY(0)), duration: 0.3)
        var lastHL = 0
        d.moveCursor(to: CGPoint(x: 1180, y: rowY(samIdx)), duration: 0.55) { p in
            let hl = menu.rows.indices.min { abs(rowY($0) - p.y) < abs(rowY($1) - p.y) } ?? 0
            if hl != lastHL { lastHL = hl; bar.host.rootView = screen(open: true, highlight: hl, submenu: nil); bar.settle(2); d.refreshFrame() }
        }
        bar.host.rootView = screen(open: true, highlight: samIdx, submenu: sub)
        bar.settle(6)
        d.play(0.3) {}
        let titles = sub.map(\.title)
        d.check(titles.contains("Join call") && titles.contains("Show in Calendr") && titles.contains("Going?"), "Sam / Alex submenu: \(titles)")
        d.hold(1.8)
        d.zoomOut()

        // 10. End on the week
        d.source = d.win
        d.cursor = CGPoint(x: 700, y: 400)
        d.say("Calendr: your week, on one screen")
        d.settle(4)
        d.check(m.viewMode == .week && m.overlay == nil && m.selectedEventID == nil, "ends on the week")
        d.frame(hold: 2.0)
        d.endCaption()
    }
}
