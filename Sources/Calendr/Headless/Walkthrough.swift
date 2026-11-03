import AppKit
import SwiftUI
import CalendrKit

/// The end-to-end tour (`--walkthrough`, used by scripts/verify.sh): a scripted walk through the demo week (the v4 fixture, Sun 4 Oct 2026
/// 15:10) that drives every main path once: keyboard routing, drag to create, resize, move and undo, delete and undo, the hour gutter,
/// the command menu, Today, search, Meet with, the views, Settings and the menu bar. Recorded at 2x / 60 fps with no overlays. Next to the video it writes the cursor
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
        switch o.tour {
        case nil, "e2e": tour(d, model)
        case "v4-a": WalkthroughV4.a(d, model)
        case "v4-b": WalkthroughV4.b(d, model)
        case "v4-c-1": WalkthroughV4.c1(d, model)
        case "v4-c-2": WalkthroughV4.c2(d, model)
        case "v4-c-3": WalkthroughV4.c3(d, model)
        case "v4-c-4": WalkthroughV4.c4(d, model)
        case "v4-d-1": WalkthroughV4.d1(d, model)
        case "v4-d-2": WalkthroughV4.d2(d, model)
        case "v4-d-3": WalkthroughV4.d3(d, model)
        case "v4-d-4": WalkthroughV4.d4(d, model)
        case "v4-d-5": WalkthroughV4.d5(d, model)
        case "v4-d-6": WalkthroughV4.d6(d, model)
        case "v4-e-1": WalkthroughV4.e1(d, model)
        case "v4-e-2": WalkthroughV4.e2(d, model)
        case "v4-e-3": WalkthroughV4.e3(d, model)
        case "v4-e-4": WalkthroughV4.e4(d, model)
        case let t?: print("unknown tour \(t) (tours: e2e (the default), v4-a, v4-b, v4-c-1 ... v4-c-4, v4-d-1 ... v4-d-6, v4-e-1 ... v4-e-4)"); return 2
        }
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
        WalkthroughV4.scrollGrid(d, m, to: SnapshotV4.defaultScroll + 4 * DemoDataV4.hourHeight)

        // 1. The week
        d.section("The week")
        d.check(m.chromeTitle == ("October", "2026") && m.weekLabel == "Week 40" && m.viewMode == .week && m.visibleDays.count == 7, "week view of Week 40, titled October 2026")
        d.check(m.layout.timedCount > 40, "timed events laid out (\(m.layout.timedCount))")
        d.check(m.todayIndex == 6 && m.settings.hourHeight == 46, "Today is Sunday, the last column; 46 pt hours")
        d.check(m.panelState.today.live?.title == "Test" && m.panelState.today.next?.title == "[P0] Weekly review", "Today: Test now, Weekly review up next")
        d.check(!Motion.reduced || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, "motion is on")
        d.say("Sam's week: Sunday 4 October, 15:10")
        d.frame(hold: 2.0)
        d.say("Today: Test runs, Weekly review is next")
        d.check(PanelText.until(Int(m.panelState.today.next!.start.timeIntervalSince(m.now) / 60)) == "in 1h 50m", "countdown reads in 1h 50m")
        d.moveCursor(to: CGPoint(x: 1240, y: 200), duration: 0.5)
        d.hold(1.6)

        // 2. An event opens in the right column
        d.section("Event detail")
        d.say("Click an event to see it")
        guard WalkthroughV4.openOnGrid(d, m, "Office hours", day: 3) else { return }
        d.check(m.selectedEvent?.participants.isEmpty == false && m.selectedEvent?.conferencing.isEmpty == false, "detail has guests and a call")
        d.hold(1.2)
        if let r = m.panelMenus.frames["row:going"] {
            d.say("Answer Going? in place")
            d.click(at: CGPoint(x: r.minX + 146, y: r.midY)) { m.setMyReply(.tentative) }
        }
        d.check(m.selectedEvent?.myReply == .tentative, "Going? Maybe is written")
        d.hold(1.0)
        d.say("Esc closes it", keys: ["esc"])
        d.play(0.5) { d.special("esc") }
        d.check(m.selectedEventID == nil, "Esc deselects, the column returns to Today")
        d.hold(0.5)

        // 3. Create by dragging, then resize
        d.section("Create")
        d.say("Drag to create an event")
        let visible = { m.layout.timed.joined().filter { !$0.placement.hidden }.count }
        let before = visible()
        d.drag(from: d.gridPoint(day: 3, minute: 14 * 60 + 30), to: d.gridPoint(day: 3, minute: 15 * 60 + 30))
        d.check(m.draft != nil && m.isDraftOpen, "drag opens a draft")
        d.check(m.draft.map { hhmm($0.start) == "14:30" && hhmm($0.end) == "15:30" && math.weekdayIndex($0.start) == 3 } == true, "draft is Thu 14:30-15:30 (got \(m.draft.map { m.fmt.timeRange($0.start, $0.end) } ?? "nil"))")
        d.check(visible() == before + 1, "the draft shows on the grid")
        d.settle(6)
        d.say("Type a title")
        d.moveCursor(to: CGPoint(x: 1240, y: 110))
        d.type("Coffee with Mara")
        d.check(m.draft?.title == "Coffee with Mara", "title typed into the draft (\(m.draft?.title ?? "nil"))")
        d.hold(0.4)
        d.say("Return saves it", keys: ["\u{21A9}"])
        d.play(0.6) { d.special("return") }
        d.check(m.draft == nil && m.selectedEventID == nil, "Return saves; the column returns to Today")
        guard let coffee = Walkthrough.placed(m, "Coffee with Mara", day: 3) else { d.check(false, "the saved event is on Thursday"); return }
        let cid = coffee.event.id
        d.hold(0.8)
        d.say("Drag the bottom edge to resize")
        d.drag(from: d.gridPoint(day: 3, minute: 15 * 60 + 30 - 3), to: d.gridPoint(day: 3, minute: 16 * 60 + 2))
        d.check(m.event(id: cid).map { hhmm($0.start) == "14:30" && hhmm($0.end) == "16:00" } == true, "resized to 14:30-16:00 (got \(m.event(id: cid).map { m.fmt.timeRange($0.start, $0.end) } ?? "nil"))")
        d.hold(0.8)
        d.play(0.3) { d.special("esc") }

        // 4. Move, undo
        d.section("Move and undo")
        guard let club = Walkthrough.placed(m, "Club committee", day: 3) else { d.check(false, "Club committee exists"); return }
        let pid = club.event.id, pc = Walkthrough.centerOf(d, club)
        d.say("Drag an event to move it")
        d.drag(from: pc, to: CGPoint(x: pc.x + m.gridGeometry.dayWidth, y: pc.y + m.gridGeometry.hourHeight))
        d.check(m.event(id: pid).map { math.weekdayIndex($0.start) == 4 && hhmm($0.start) == "12:00" } == true, "Club committee moved to Fri 12:00 (got \(m.event(id: pid).map { m.fmt.timeRange($0.start, $0.end) } ?? "nil"))")
        d.check(m.toast?.undo == true, "the undo pill appears")
        d.say("The undo pill appears")
        d.moveCursor(to: Self.undoPill, duration: 0.45)
        d.hold(0.9)
        d.say("Click Undo")
        d.click(at: Self.undoPill) { m.dismissToast(); m.undo() }
        d.play(0.4) {}
        d.check(m.event(id: pid).map { math.weekdayIndex($0.start) == 3 && hhmm($0.start) == "11:00" } == true, "Undo moves it back")
        d.hold(0.8)
        d.play(0.4) { d.special("esc") }
        d.check(m.selectedEventID == nil, "Esc closes the restored event")

        // 5. Delete, undo
        d.section("Delete and undo")
        d.say("Select, then Delete", keys: ["\u{232B}"])
        guard let coffee2 = Walkthrough.placed(m, "Coffee with Mara", day: 3) else { d.check(false, "Coffee with Mara is on the grid"); return }
        d.clickGrid(Walkthrough.centerOf(d, coffee2))
        d.check(m.selectedEventID == cid, "click selects Coffee with Mara")
        d.hold(0.5)
        d.play(0.5) { d.special("delete") }
        d.check(m.event(id: cid) == nil && m.toast?.undo == true, "Delete removes it, with an undo pill")
        d.hold(0.9)
        d.say("Undo", keys: ["\u{2318}", "Z"])
        d.play(0.5) { d.key("z", cmd: true) }
        d.check(m.event(id: cid) != nil, "Cmd-Z brings it back")
        d.hold(0.9)
        d.play(0.3) { m.dismissToast(); m.deselect() }

        // 6. The hour gutter
        d.section("Hour scale")
        d.say("Drag the gutter to zoom the hours")
        let hand = m.gridHourHeight
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
        d.check(m.gridHourHeight > hand * 1.5 && m.settings.hourHeight == m.gridHourHeight, "gutter drag zooms (\(Int(hand)) -> \(Int(m.gridHourHeight)) pt per hour)")
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
        d.say("Double-click the gutter to fit the week")
        d.moveCursor(to: gutterPoint(y: gy))
        d.recordClick()
        d.frame(hold: 0.12)
        d.recordClick(double: true)
        d.play(0.6) { m.fitHourScale() }
        d.check(m.settings.hourHeight == nil && m.gridState.fit.map { abs(m.gridHourHeight - $0.perHour) < 1 } == true, "double-click fits the hours to the week (\(Int(m.gridHourHeight)) pt)")
        d.hold(0.9)

        // 7. Command menu, Today, search, Meet with
        d.section("Command menu")
        d.say("Command menu", keys: ["\u{2318}", "K"])
        d.moveCursor(to: CGPoint(x: 800, y: 120))
        d.play(0.5) { d.key("k", cmd: true) }
        d.check(m.overlay == .command, "Cmd-K opens the command menu")
        d.hold(0.7)
        d.say("Type a date: next fri")
        d.type("next fri")
        d.check({ if case .date(let x)? = m.paletteRows.first?.kind { return math.day(x) == 9 && math.month(x) == 10 }; return false }(), "first row resolves next fri to 9 Oct")
        d.hold(0.3)
        d.say("Return goes there", keys: ["\u{21A9}"])
        d.play(0.7) { d.special("return") }
        d.check(m.overlay == nil && startDay() == 5 && math.month(m.visibleStart) == 10, "Return navigates to the week of 5 Oct")
        d.hold(0.8)
        d.say("T comes back to today", keys: ["T"])
        d.play(0.6) { d.key("t") }
        d.check(startDay() == 28 && m.todayIndex == 6, "T returns to today")
        d.hold(0.6)
        d.say("Search events", keys: ["/"])
        d.play(0.4) { d.key("/") }
        d.check(m.overlay == nil && m.chromeState.searchFocused, "/ focuses the right column's search field")
        d.type("walk")
        d.check(m.chromeState.columnQuery == "walk" && m.columnResults.contains { $0.events.contains { $0.title == "Evening walk" } }, "search finds Evening walk")
        d.hold(0.6)
        d.say("Return opens the first result", keys: ["\u{21A9}"])
        d.play(0.7) { d.special("return") }
        d.check(m.selectedEvent?.title == "Evening walk", "Return opens Evening walk")
        d.hold(1.0)
        d.play(0.4) { d.special("esc") }
        d.check(m.selectedEventID == nil, "Esc closes the detail")
        d.play(0.4) { d.special("esc") }
        d.check(!m.columnSearching, "Esc again clears the search")
        d.say("Meet with overlays a teammate", keys: ["F"])
        d.play(0.4) { d.key("f") }
        d.check(m.overlay == .command && m.chromeState.paletteMode == .meet, "F opens Meet with")
        d.hold(0.5)
        d.type("ines")
        d.check(m.paletteRows.first?.title == "Ines Duarte", "filter finds Ines Duarte")
        d.play(0.6) { d.special("return") }
        d.check(m.shownTeammates.count == 1 && m.overlayLayout.timedCount == 7, "Ines's busy time is overlaid (\(m.overlayLayout.timedCount) blocks)")
        d.hold(1.6)
        d.say("Click the chip to remove it")
        d.click(at: Self.mateChip) { if let t = m.shownTeammates.first { m.toggleMate(t) } }
        d.check(m.shownTeammates.isEmpty && m.overlayLayout.timedCount == 0, "the header chip removes the overlay")
        d.hold(0.8)

        // 8. Views
        d.section("Views")
        d.say("M for month", keys: ["M"])
        d.play(0.6) { d.key("m") }
        d.check(m.viewMode == .month && m.monthEvents.count == 42, "M shows the month")
        d.hold(1.2)
        d.say("D for day", keys: ["D"])
        d.play(0.6) { d.key("d") }
        d.check(m.viewMode == .day && m.visibleDays.count == 1, "D shows the day")
        d.hold(1.2)
        d.say("W for week", keys: ["W"])
        d.play(0.6) { d.key("w") }
        d.check(m.viewMode == .week && m.visibleDays.count == 7, "W shows the week")
        d.hold(0.8)

        // 9. Settings
        d.section("Settings")
        d.say("Settings", keys: ["\u{2318}", ","])
        d.moveCursor(to: CGPoint(x: 800, y: 300))
        d.play(0.6) { d.key(",", cmd: true) }
        d.check(m.overlay == .settings, "Cmd-, opens Settings")
        d.hold(0.7)
        d.say("Turn on week numbers")
        d.clickPoint(WalkthroughV4.weekNumbersOn, seconds: 0.5)
        d.check(m.settings.showWeekNumbers, "week numbers are on")
        d.hold(0.9)
        d.say("Switch to Paper")
        d.click(at: Self.paper) { m.settings.appearance = .light; d.win.setDark(false) }
        d.settle(8); d.frame()
        d.check(m.isPaper, "appearance is Paper")
        d.hold(1.2)
        d.say("And back to Black")
        d.click(at: Self.black) { m.settings.appearance = .dark; d.win.setDark(true) }
        d.settle(8); d.frame()
        d.check(!m.isPaper, "appearance is Black")
        d.hold(0.6)
        d.say("Esc closes Settings", keys: ["esc"])
        d.play(0.5) { d.special("esc") }
        d.check(m.overlay == nil, "Esc closes Settings")
        d.say("The mini month shows week numbers")
        d.moveCursor(to: CGPoint(x: 30, y: 160), duration: 0.5)
        d.check(m.settings.showWeekNumbers, "week numbers stay on in the mini month")
        d.hold(1.4)

        // 10. Menu bar (the real NSMenu cannot be captured offscreen; the preview draws the same model)
        d.section("Menu bar")
        func itemLabel() -> String { m.menuBarMenu.focus.map { "\(m.menuBarMenu.itemTitle ?? "") \u{00B7} \($0.text)" } ?? "" }
        d.check(itemLabel() == "Test \u{00B7} 35 min left", "menu bar item reads \(itemLabel())")
        let backdrop = d.win.image(scale: 2).map { NSImage(cgImage: $0, size: NSSize(width: 1440, height: 900)) }
        let menu = m.menuBarMenu
        let f = m.fmt
        let clock = "\(f.weekdayShort(m.now)) \(math.day(m.now)) \(f.monthShort(m.now))  \(f.time(m.now))"
        func screen(open: Bool, highlight: Int?, submenu: [MenuBarSubItem]?) -> AnyView {
            AnyView(MenuBarScreenPreview(menu: menu, display: m.settings.menuBarDisplay, clock: clock, backdrop: backdrop, highlight: highlight, submenu: submenu, open: open))
        }
        let bar = OffscreenWindow(screen(open: false, highlight: nil, submenu: nil), size: CGSize(width: 1440, height: 900), chrome: false)
        bar.settle(6)
        d.say("The menu bar says what is on")
        d.source = bar
        d.frame(hold: 1.4)
        d.say("Click it to open the day")
        let item = CGPoint(x: 1110, y: 15)
        d.moveCursor(to: item)
        d.recordClick()
        bar.host.rootView = screen(open: true, highlight: 0, submenu: nil)
        bar.settle(6)
        d.play(0.3) {}
        d.check(menu.rows.contains { $0.title == "Flat dinner" }, "the open menu lists the rest of today")
        d.hold(0.9)
        d.say("Hover an event for its menu")
        guard let idx = menu.rows.firstIndex(where: { $0.title == "Flat dinner" }) else { d.check(false, "Flat dinner is in the menu"); return }
        func rowY(_ i: Int) -> Double { 32 + Double(MenuBarMenuPreview.rowTop(i, in: menu)) + 11 }
        let sub = m.menuBarSubmenu(for: menu.rows[idx].event)
        d.moveCursor(to: CGPoint(x: 1180, y: rowY(0)), duration: 0.3)
        var lastHL = 0
        d.moveCursor(to: CGPoint(x: 1180, y: rowY(idx)), duration: 0.55) { p in
            let hl = menu.rows.indices.min { abs(rowY($0) - p.y) < abs(rowY($1) - p.y) } ?? 0
            if hl != lastHL { lastHL = hl; bar.host.rootView = screen(open: true, highlight: hl, submenu: nil); bar.settle(2); d.refreshFrame() }
        }
        bar.host.rootView = screen(open: true, highlight: idx, submenu: sub)
        bar.settle(6)
        d.play(0.3) {}
        let titles = sub.map(\.title)
        d.check(titles.contains("Join call") && titles.contains("Show in Calendr") && titles.contains("Going?"), "Flat dinner submenu: \(titles)")
        d.hold(1.6)

        // 11. End on the week
        d.source = d.win
        d.cursor = CGPoint(x: 700, y: 400)
        d.say("Calendr: your week, on one screen")
        d.settle(4)
        d.check(m.viewMode == .week && m.overlay == nil && m.selectedEventID == nil, "ends on the week")
        d.frame(hold: 1.8)
        d.endCaption()
    }

    /// Window points (1440 x 900) of the undo pill's Undo, the Meet with chip in the header and the Appearance segments in Settings.
    static let undoPill = CGPoint(x: 730, y: 862)
    static let mateChip = CGPoint(x: 568, y: 30)
    static let paper = CGPoint(x: 967, y: 328)
    static let black = CGPoint(x: 916, y: 328)
}
