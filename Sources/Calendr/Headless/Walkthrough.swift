import AppKit
import SwiftUI
import CalendrKit

/// Scripted tour of every feature. Keyboard shortcuts are real NSEvents; grid pointer gestures call the model functions the SwiftUI DragGesture forwards to. Inspector fields that are pickers/menus (calendar, reminder, all-day) call the same
/// `AppModel.updateSelected` setter their bindings call; sidebar/toolbar buttons call the same model methods their actions call.
@MainActor
enum Walkthrough {
    static func run(_ o: LaunchOptions) -> Int32 {
        Motion.forcedInstant = false          // the video shows the real animations
        let model = HeadlessRunner.makeModel(o)
        let rec = o.record.flatMap { VideoRecorder(url: URL(fileURLWithPath: $0), width: Int(o.size.width), height: Int(o.size.height)) }
        if o.record != nil && rec == nil { print("could not open recorder"); return 2 }
        let d = Driver(model: model, size: o.size, recorder: rec)
        let started = Date()
        tour(d, model)
        rec?.finish()
        let secs = rec.map { String(format: "%.1f", $0.seconds) } ?? "-"
        print("walkthrough: \(d.checks) checks, \(d.failures.count) failures, video \(secs)s, wall \(String(format: "%.1f", Date().timeIntervalSince(started)))s")
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
        func day(_ mo: Int, _ dd: Int) -> Date { math.date(year: 2026, month: mo, day: dd) }
        func startDay() -> Int { math.day(m.visibleStart) }

        // 1. Overview
        d.section("Calendr v2: week view, tasks as capsules, now line, Up Next")
        d.check(m.headerTitle == "September 2026" && m.weekLabel == "W40", "header title and week chip (\(m.weekLabel))")
        d.check(m.visibleDays.count == 7 && m.viewMode == .week, "seven day columns")
        d.check(m.layout.allDay.laneCount == 5, "five all-day lanes")
        d.check(m.layout.timedCount > 70, "timed events laid out (\(m.layout.timedCount))")
        d.check(m.todayIndex == 1, "today is column 2")
        d.check(m.upcoming.next?.title == "Calculus", "Up Next card shows Calculus")
        d.check(!Motion.reduced || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, "motion is on")
        d.frame(hold: 3.5)

        // 2. Navigation with the 180 ms slide
        d.section("Next / previous / today: the grid slides 36 pt and fades in")
        d.play(0.6) { d.key("j") }
        d.check(startDay() == 5 && math.month(m.visibleStart) == 10, "J goes to next week"); d.check(d.lastAnimateFrames >= 4, "slide sampled in real time (\(d.lastAnimateFrames) frames)")
        d.frame(hold: 0.6)
        d.play(0.6) { d.key("k") }; d.check(startDay() == 28, "K goes back"); d.frame(hold: 0.4)
        d.play(0.6) { d.special("right") }; d.check(startDay() == 5, "right arrow next week")
        d.play(0.6) { d.special("left") }; d.check(startDay() == 28, "left arrow previous week")
        d.key("j"); d.key("j"); d.frame(hold: 0.4)
        d.play(0.6) { d.key("t") }; d.check(startDay() == 28 && m.todayIndex == 1, "T returns to today"); d.frame(hold: 0.6)
        d.section("Left-align today in view (option T)")
        d.play(0.6) { d.key("t", opt: true) }; d.check(startDay() == 29 && m.leftAligned, "option+T left-aligns today"); d.frame(hold: 1.6)
        d.play(0.5) { d.key("t") }; d.check(!m.leftAligned && startDay() == 28, "T restores Monday week")

        // 3. Sidebar
        d.section("Mini calendar: week band in act purple, today marker; calendar checkboxes")
        m.stepMiniMonth(1); d.frame(hold: 0.8)
        d.check(m.math.month(m.miniMonth) == 10, "mini month chevron")
        m.stepMiniMonth(-1)
        d.play(0.6) { m.go(to: day(10, 12)) }; d.check(startDay() == 12, "mini calendar click navigates"); d.frame(hold: 0.8)
        d.play(0.5) { d.key("t") }
        d.section("Calendars: click a row to hide or show it")
        let before = m.layout.timedCount
        d.play(0.5) { m.toggleCalendar(DemoData.tasks) }
        d.check(m.layout.timedCount < before && m.hiddenCalendars.contains(DemoData.tasks), "hide Tasks calendar"); d.frame(hold: 1.4)
        d.play(0.5) { m.toggleCalendar(DemoData.tasks) }; d.check(m.layout.timedCount == before, "show Tasks calendar again"); d.frame(hold: 0.5)
        m.toggleCalendar(DemoData.svcHolidays); d.frame(hold: 0.4); m.toggleCalendar(DemoData.svcHolidays)
        d.section("All-day area: collapse to one lane with +N more")
        d.play(0.5) { m.allDayCollapsed = true }
        d.check(m.layout.allDay.collapsed(maxLanes: 1).hiddenPerDay.contains { $0 > 0 }, "collapsed shows hidden counts"); d.frame(hold: 1.4)
        d.play(0.5) { m.allDayCollapsed = false }

        // 4. View modes
        d.section("Day / Week / Month: D, W, M (the segmented thumb slides)")
        d.play(0.6) { d.key("d") }; d.check(m.viewMode == .day && m.visibleDays.count == 1, "D day view"); d.frame(hold: 1.4)
        d.play(0.6) { d.key("m") }; d.check(m.viewMode == .month && m.monthEvents.count == 42, "M month view"); d.frame(hold: 1.8)
        d.play(0.6) { d.key("j") }; d.check(m.headerTitle == "October 2026", "month next (title crossfades)"); d.frame(hold: 0.5)
        d.key("t")
        d.play(0.6) { d.key("w") }; d.check(m.viewMode == .week, "W week view"); d.frame(hold: 0.8)
        m.setMode(.custom(3)); d.check(m.visibleDays.count == 3, "custom 3-day view"); d.section("Custom 2-7 day views (view menu)"); d.frame(hold: 1.2)
        m.setMode(.week); d.frame()

        // 5. Panels
        d.section("Toggle sidebar (`) and right panel (cmd /)")
        d.play(0.5) { d.key("`") }; d.check(!m.sidebarVisible, "backtick hides sidebar"); d.frame(hold: 1.0)
        d.play(0.5) { d.key("`") }; d.check(m.sidebarVisible, "backtick shows sidebar")
        d.play(0.5) { d.key("/", cmd: true) }; d.check(!m.rightPanelVisible, "cmd-/ hides right panel"); d.frame(hold: 1.0)
        d.play(0.5) { d.key("/", cmd: true) }; d.check(m.rightPanelVisible, "cmd-/ shows right panel")

        // 6. Select + inspector
        d.section("Click an event: act selection ring, inspector slides in")
        guard let policy = placed(m, "Public Policy", day: 2) else { d.check(false, "Public Policy exists"); return }
        d.clickAnimated(grid: centerOf(d, policy))
        d.check(m.selectedEvent?.title == "Public Policy", "real click selects Public Policy")
        d.frame(hold: 2.5)
        d.section("Inspector: title, mono time fields, recurrence, location, calendar, reminder")
        d.click(grid: centerOf(d, policy), clickCount: 2)
        d.settle(6)
        d.type(" LF1")
        d.check(m.selectedEvent?.title.hasSuffix("LF1") == true, "typed into the focused title field (\(m.selectedEvent?.title ?? "nil"))")
        d.frame(hold: 1.0)
        d.special("esc")
        m.updateSelected { $0.title = "Public Policy" }
        let orig = m.selectedEvent!
        m.updateSelected { $0.location = "Room 204\nBuilding 2" }; d.check(m.selectedEvent?.location.hasPrefix("Room") == true, "location write-through"); d.frame(hold: 0.8)
        m.updateSelected { $0.location = orig.location }
        m.updateSelected { $0.calendarID = DemoData.family }; d.check(m.selectedEvent?.calendarID == DemoData.family, "calendar picker write-through"); d.frame(hold: 1.0)
        m.updateSelected { $0.calendarID = DemoData.personal }
        m.updateSelected { $0.reminderMinutes = 15 }; d.check(m.selectedEvent?.reminderMinutes == 15, "reminder write-through"); d.frame(hold: 0.8)
        m.updateSelected { $0.reminderMinutes = 1 }
        m.updateSelected { $0.participants.append("max@example.com") }; d.check(m.selectedEvent?.participants.contains("max@example.com") == true, "participant added"); d.frame(hold: 1.0)
        m.updateSelected { $0.participants.removeAll() }
        let ev0 = m.selectedEvent!
        d.play(0.5) { m.updateSelected { $0.isAllDay = true; $0.start = math.startOfDay($0.start); $0.end = math.addDays($0.start, 1) } }
        d.check(m.selectedEvent?.isAllDay == true && m.layout.allDay.placements.count > 5, "all-day toggle (knob springs) moves event to all-day lane"); d.frame(hold: 1.2)
        d.play(0.5) { m.updateSelected { $0.isAllDay = false; $0.start = ev0.start; $0.end = ev0.end } }
        d.check(m.selectedEvent?.isAllDay == false, "all-day off restores timed event")
        d.section("Recurrence chevrons: the inspector swaps with an 8 pt slide")
        let s0 = m.selectedEvent!.start
        d.play(0.5) { m.selectOccurrence(1) }; d.check(m.selectedEvent.map { math.daysBetween(s0, $0.start) } == 7, "next occurrence is +7 days"); d.frame(hold: 1.0)
        d.play(0.5) { m.selectOccurrence(-1) }; d.check(m.selectedEvent?.start == s0, "previous occurrence"); d.frame(hold: 0.4)

        // 7. Tasks
        d.section("Tasks are capsules: click the checkbox to complete (spring pop)")
        d.play(0.3) { m.deselect() }
        guard let task = placed(m, "[P1] Book a haircut", day: 1) else { d.check(false, "task exists"); return }
        let cb = EventPainter.checkboxRect(in: m.gridGeometry.rect(for: task))
        d.clickAnimated(grid: CGPoint(x: cb.midX, y: cb.midY), seconds: 0.6)
        d.check(m.isDone(task.event.id) && m.selectedEventID == nil, "checkbox completes the task without selecting it")
        d.frame(hold: 1.6)
        d.clickAnimated(grid: CGPoint(x: cb.midX, y: cb.midY), seconds: 0.4)
        d.check(!m.isDone(task.event.id), "checkbox toggles back")

        // 8. Delete + undo toast
        d.section("Delete: a toast with Undo and cmd Z arrives with a spring")
        guard let sam = placed(m, "Thursday sync", day: 3) else { d.check(false, "Thursday sync exists"); return }
        d.clickAnimated(grid: centerOf(d, sam), seconds: 0.5)
        let n0 = m.layout.timedCount
        d.play(0.7) { d.special("delete") }
        d.check(m.layout.timedCount == n0 - 1 && m.toast?.undo == true, "delete removes the event and shows an undo toast"); d.frame(hold: 1.6)
        d.play(0.7) { d.key("z", cmd: true) }
        d.check(m.layout.timedCount == n0, "cmd-Z restores it"); d.play(0.4) { m.dismissToast() }
        d.section("Delete a recurring event: This event / All events")
        d.clickAnimated(grid: centerOf(d, policy), seconds: 0.4)
        let count = m.layout.timedCount
        d.play(0.5) { d.special("delete") }
        d.check({ if case .deleteRecurring = m.overlay { return true } else { return false } }(), "delete key asks about recurrence"); d.frame(hold: 1.8)
        d.play(0.6) { if let e = m.selectedEvent { m.delete(e, span: .this) } }
        d.check(m.layout.timedCount == count - 1, "This event removes one occurrence"); d.frame(hold: 1.0)
        d.play(0.6) { d.key("z", cmd: true) }; d.check(m.layout.timedCount == count, "cmd-Z restores it"); d.frame(hold: 0.6)
        m.dismissToast(); d.special("esc")

        // 9. Drag create / move / resize
        d.section("Drag on the empty grid to create (15 minute snap, no animation while dragging)")
        let created0 = m.layout.timedCount
        d.drag(from: d.gridPoint(day: 5, minute: 14 * 60 + 3), to: d.gridPoint(day: 5, minute: 15 * 60 + 40))
        let newEv = m.selectedEvent
        d.check(newEv != nil && m.fmt.time(newEv!.start) == "14:00" && m.fmt.time(newEv!.end) == "15:45", "drag-create snapped 14:00-15:45 (got \(newEv.map { m.fmt.timeRange($0.start, $0.end) } ?? "nil"))")
        d.check(m.layout.timedCount == created0 + 1, "created event appears in the grid")
        d.settle(6)
        d.type("Design review")
        d.check(m.selectedEvent?.title.hasSuffix("review") == true, "title typed into inspector (\(m.selectedEvent?.title ?? "nil"))")
        d.frame(hold: 1.2)
        d.special("esc"); d.special("esc")
        d.section("Drag an event to move it across days; drag the bottom edge to resize (the drop settles in 120 ms)")
        guard let mine = m.layout.timed[5].first(where: { $0.event.title.hasSuffix("review") }) else { d.check(false, "created event findable"); return }
        let eid = mine.event.id
        d.drag(from: d.gridPoint(day: 5, minute: 14 * 60 + 25), to: d.gridPoint(day: 6, minute: 11 * 60 + 25))
        d.check(m.event(id: eid).map { math.weekdayIndex($0.start) == 6 && m.fmt.time($0.start) == "11:00" } == true, "moved to Sunday 11:00 (got \(m.event(id: eid).map { m.fmt.timeRange($0.start, $0.end) } ?? "nil"))")
        if let moved = m.flatTimed.first(where: { $0.event.id == eid }) {
            let r = m.gridGeometry.rect(for: moved)
            d.drag(from: CGPoint(x: r.midX, y: r.maxY - 3), to: CGPoint(x: r.midX, y: r.maxY + 48))
            d.check(m.event(id: eid).map { m.fmt.time($0.end) == "13:45" } == true, "resized to 13:45 (got \(m.event(id: eid).map { m.fmt.time($0.end) } ?? "nil"))")
        }
        d.frame(hold: 0.8)
        d.section("Undo: cmd Z reverts resize, move and create")
        d.key("z", cmd: true); d.check(m.event(id: eid).map { m.fmt.time($0.end) == "12:45" } == true, "undo resize"); d.frame(hold: 0.8)
        d.key("z", cmd: true); d.check(m.event(id: eid).map { math.weekdayIndex($0.start) == 5 } == true, "undo move"); d.frame(hold: 0.8)
        d.key("z", cmd: true); d.check(m.layout.timedCount == created0, "undo create"); d.frame(hold: 0.8)
        d.section("C: create at the next free half hour")
        d.play(0.6) { d.key("c") }; let c = m.selectedEvent
        d.check(c != nil && m.fmt.time(c!.start) == "15:00" && c!.durationMinutes == 60, "C creates 15:00 (\(c.map { m.fmt.time($0.start) } ?? "nil"))")
        d.frame(hold: 1.2)
        d.special("esc"); d.special("esc"); d.check(m.layout.timedCount == created0, "untitled draft discarded on deselect")

        // 10. Search
        d.section("Search: cmd F, results grouped by date, then an empty result")
        d.key("f", cmd: true); d.frame(hold: 0.4)
        d.type("calculus")
        d.check(!m.searchGroups.isEmpty && m.searchGroups.count > 3, "search groups (\(m.searchGroups.count))")
        d.frame(hold: 1.8)
        d.play(0.5) { d.special("return") }
        d.check(m.selectedEvent?.title == "Calculus", "Return opens the first result")
        d.frame(hold: 1.0)
        d.special("esc"); m.searchText = ""
        d.key("/"); d.type("Quokka")
        d.check(m.searchGroups.isEmpty, "no results for Quokka"); d.frame(hold: 2.0)
        d.special("esc"); m.searchText = ""; d.key("t")

        // 11. Command menu
        d.section("Command menu: cmd K arrives (scale 0.98, fade), fuzzy filter, Return")
        d.play(0.6) { d.key("k", cmd: true) }; d.check(m.overlay == .command, "cmd-K opens command menu"); d.frame(hold: 1.6)
        d.special("down"); d.special("down"); d.special("down"); d.check(m.commandIndex == 3, "arrow down moves selection"); d.frame(hold: 0.8)
        d.type("mont")
        d.check(CommandRegistry.flat(m.commandSections).first?.id == .viewMonth, "fuzzy filter finds Month view")
        d.frame(hold: 0.8)
        d.play(0.6) { d.special("return") }; d.check(m.viewMode == .month && m.overlay == nil, "Return runs the command"); d.frame(hold: 1.0)
        d.play(0.5) { d.key("w") }

        // 12. Teammates
        d.section("Show teammate calendar: P, filter, Return overlays their events")
        d.play(0.6) { d.key("p") }; d.check(m.overlay == .teammate, "P opens teammate picker"); d.frame(hold: 1.6)
        d.type("maya")
        d.check(m.filteredTeammates(m.teammateQuery).first?.name == "Maya Sterling", "filter finds Max")
        d.play(0.6) { d.special("return") }
        d.check(m.shownTeammates.count == 1 && m.overlayLayout.timedCount > 0, "overlay events shown"); d.frame(hold: 2.0)
        d.key("p"); d.type("mateo"); d.special("return"); d.check(m.shownTeammates.count == 2, "second teammate"); d.frame(hold: 1.2)
        d.section("Meet with...: F focuses the sidebar field")
        d.key("f"); d.type("to", frames: false); d.check(!m.filteredTeammates(m.meetQuery).isEmpty, "meet field filters teammates"); d.frame(hold: 1.4)
        d.special("esc")
        m.shownTeammates.forEach { m.removeTeammate($0) }; d.check(m.overlayLayout.timedCount == 0, "teammates removed"); d.frame(hold: 0.4)

        // 13. Go to date
        d.section("Go to date: . then natural input")
        d.play(0.5) { d.key(".") }; d.check(m.overlay == .goToDate, "period opens go to date"); d.frame(hold: 0.6)
        d.type("next friday")
        d.check(m.goToPreview.map { math.day($0) == 9 && math.month($0) == 10 } == true, "preview resolves next friday")
        d.frame(hold: 1.2)
        d.play(0.7) { d.special("return") }; d.check(m.overlay == nil && math.day(m.visibleStart) == 5 && math.month(m.visibleStart) == 10, "Return navigates"); d.frame(hold: 0.8)
        d.key("."); d.type("12.10."); d.special("return"); d.check(math.day(m.visibleStart) == 12, "German date format"); d.frame(hold: 0.6)
        d.play(0.6) { d.key("t") }; d.check(startDay() == 28 && math.month(m.visibleStart) == 9, "T returns to today after go to date (start \(startDay()))")

        // 14. Shortcuts sheet
        d.section("All keyboard shortcuts: ? (sheet drops in over 300 ms)")
        d.play(0.7) { d.key("?") }; d.check(m.overlay == .shortcuts, "? opens shortcuts sheet"); d.frame(hold: 2.4)
        d.play(0.5) { d.special("esc") }; d.check(m.overlay == nil, "esc closes it")

        // 15. Settings + reduce motion
        d.section("Settings: cmd comma. Reduce motion makes everything instant")
        d.play(0.7) { d.key(",", cmd: true) }; d.check(m.overlay == .settings, "cmd-, opens settings"); d.frame(hold: 1.4)
        m.settings.use24h = false; d.settle(); d.check(m.fmt.time(m.now).contains("AM") || m.fmt.time(m.now).contains("PM"), "12-hour format applies"); d.frame(hold: 1.0)
        m.settings.use24h = true
        d.play(0.4) { m.settings.reduceMotion = true }; d.check(Motion.reduced, "Reduce motion override turns animations off"); d.frame(hold: 0.8)
        d.special("esc"); d.settle(6)
        d.play(0.5) { d.key("j") }; d.check(startDay() == 5 && Motion.reduced, "with Reduce motion the week changes instantly (start \(startDay()), overlay \(String(describing: m.overlay)), mode \(m.viewMode))")
        d.play(0.4) { d.key("k") }
        d.key(",", cmd: true); d.settle(8)
        m.settings.reduceMotion = false; d.settle(4); d.check(!Motion.reduced, "Reduce motion off again"); d.frame(hold: 0.6)
        m.settings.showDeclined = false; d.settle(); d.check(!m.layout.timed[2].contains { $0.event.status == .declined }, "hide declined events"); d.frame(hold: 0.8)
        m.settings.showDeclined = true
        d.play(0.5) { d.special("esc") }

        // 16. Menu bar
        d.section("Menu bar calendar: live label, Up Next card, later today")
        let label = Upcoming.menuBarLabel(m.upcoming)
        d.check(label == "Calculus \u{00B7} in 12m", "menu bar label: \(label)")
        d.check(m.upcoming.sections.first?.title == "Today" && m.upcoming.sections.dropFirst().first?.title == "Tomorrow", "popover sections")
        let pop = OffscreenWindow(MenuBarPopover().environment(m).environment(\.colorScheme, .dark), size: CGSize(width: 392, height: 1000), chrome: false)
        pop.resize(CGSize(width: 392, height: min(820, max(200, pop.host.fittingSize.height))))
        d.popover = pop.image(scale: 2); d.menuBarLabel = label
        d.frame(hold: 3.5)
        d.popover = nil; pop.close()
        d.section("Menu bar with nothing left today: explanation and a primary action")
        m.setNow(math.date(year: 2026, month: 9, day: 29, hour: 23, minute: 40))
        let pop2 = OffscreenWindow(MenuBarPopover().environment(m).environment(\.colorScheme, .dark), size: CGSize(width: 392, height: 1000), chrome: false)
        pop2.resize(CGSize(width: 392, height: min(820, max(200, pop2.host.fittingSize.height))))
        d.popover = pop2.image(scale: 2); d.menuBarLabel = Upcoming.menuBarLabel(m.upcoming)
        d.frame(hold: 2.5)
        d.popover = nil; d.menuBarLabel = nil; pop2.close()
        m.setNow(DemoData.defaultNow)
        if let next = m.upcoming.next { m.open(event: next) }
        d.check(m.selectedEvent?.title == "Calculus", "clicking the Up Next card opens it in the main window"); d.frame(hold: 1.2)
        m.deselect(); m.goToToday()

        // 17. Light
        d.section("Light appearance: warm paper, lavender selection")
        m.settings.appearance = .light; d.win.setDark(false); d.settle(8); d.frame(hold: 2.4)
        d.clickAnimated(grid: centerOf(d, placed(m, "Public Policy", day: 2) ?? mine), seconds: 0.5); d.frame(hold: 1.6)
        d.special("esc")
        m.settings.appearance = .dark; d.win.setDark(true); d.settle(8)

        // 18. Empty state
        d.section("No calendar access: an empty state with one primary action")
        (m.store as? DemoStore)?.authorization = .notDetermined
        d.play(0.5) { m.storeChanged() }
        d.check(m.authState == .notDetermined, "access state shows the empty screen"); d.frame(hold: 3)
        (m.store as? DemoStore)?.authorization = .authorized; m.storeChanged(); d.settle(6)

        d.section("Calendr: native SwiftUI, EventKit + demo store")
        d.frame(hold: 2.0)
    }
}
