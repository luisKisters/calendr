import AppKit
import CalendrKit

/// Named UI states. `design/states.json` lists them with the mockup hash each one is compared against.
@MainActor
enum SnapshotStates {
    static let all = ["week", "week-selected-event", "command-menu", "teammate-picker", "teammate-overlay", "go-to-date", "search-results",
                      "month", "day", "menubar-popover", "sidebar-hidden", "all-day-collapsed", "create-drag", "shortcuts-sheet",
                      "settings", "light-week", "delete-recurring", "meet-with", "readonly-event", "empty-access", "month-light", "toast", "search-empty", "menubar-empty",
                      "create-event", "week-zoomed", "week-numbers", "detail-guests",
                      "menubar", "menubar-submenu", "menubar-running", "menubar-none"]

    static func find(_ m: AppModel, _ title: String, day: Int) -> CalendarEvent? {
        m.layout.timed[day].first { $0.event.title == title }?.event
    }

    /// Puts the model into the named state. Names not handled here fall through to the area hooks
    /// (`SnapshotGrid`, `SnapshotChrome`, `SnapshotPanel`, `SnapshotMenuBar`). Returns false for unknown names.
    static func apply(_ name: String, to m: AppModel) -> Bool {
        switch name {
        case "week": break
        case "week-selected-event":
            if let e = find(m, "Public Policy", day: 2) { m.select(eventID: e.id) }
        case "month": m.setMode(.month)
        case "day": m.setMode(.day)
        case "sidebar-hidden": m.sidebarVisible = false
        case "all-day-collapsed":
            // The demo week folds its all-day lane; this opens the day list of Saturday's "n more".
            m.openDayList(DemoData.day(10, 3))
        case "create-drag":
            let g = m.gridGeometry
            let x = 5.5 * g.dayWidth
            m.gridMouseDown(CGPoint(x: x, y: g.yPos(14 * 60) + 2))
            m.gridMouseDragged(CGPoint(x: x, y: g.yPos(15 * 60 + 20)))
        case "shortcuts-sheet": m.overlay = .shortcuts
        case "settings": m.overlay = .settings
        case "light-week": m.settings.appearance = .light
        case "delete-recurring":
            if let e = find(m, "Public Policy", day: 2) { m.select(eventID: e.id); m.requestDeleteSelected() }
        case "readonly-event":
            if let e = m.layout.allDayEvents.values.first(where: { $0.title == "Day of German Unity" }) { m.select(eventID: e.id) }
        case "empty-access": break
        case "month-light": m.setMode(.month); m.settings.appearance = .light
        case "create-event":
            // Thu 1 Oct 12:00-13:00, created the way C or a drag creates: selected, title focused.
            let s = m.math.date(on: DemoData.day(10, 1), minutes: 12 * 60)
            m.createEvent(start: s, end: s.addingTimeInterval(3600))
        case "week-zoomed": m.settings.hourHeight = 96
        case "week-numbers": m.settings.showWeekNumbers = true
        case "detail-guests":
            if let e = find(m, "Sam / Alex", day: 1) { m.select(eventID: e.id) }
        default:
            return SnapshotAudit.apply(name, m) || SnapshotGrid.apply(name, m) || SnapshotChrome.apply(name, m) || SnapshotPanel.apply(name, m) || SnapshotMenuBar.apply(name, m)
        }
        return true
    }
}
