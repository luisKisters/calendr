import AppKit
import CalendrKit

/// Named UI states. `design/states.json` lists them with the mockup hash each one is compared against.
@MainActor
enum SnapshotStates {
    static let all = ["week", "week-selected-event", "command-menu", "teammate-picker", "teammate-overlay", "go-to-date", "search-results",
                      "month", "day", "menubar-popover", "sidebar-hidden", "all-day-collapsed", "create-drag", "shortcuts-sheet",
                      "settings", "light-week", "delete-recurring", "meet-with", "readonly-event", "empty-access", "month-light", "toast", "search-empty", "menubar-empty"]

    static func find(_ m: AppModel, _ title: String, day: Int) -> CalendarEvent? {
        m.layout.timed[day].first { $0.event.title == title }?.event
    }

    /// Puts the model into the named state. Returns false for unknown names.
    static func apply(_ name: String, to m: AppModel) -> Bool {
        switch name {
        case "week": break
        case "week-selected-event":
            if let e = find(m, "Public Policy", day: 2) { m.select(eventID: e.id) }
        case "command-menu": m.openCommandMenu()
        case "teammate-picker": m.openTeammatePicker(); m.teammateIndex = 3
        case "teammate-overlay":
            for i in [3, 0] { m.showTeammate(m.store.teammates[i]) }
        case "go-to-date": m.openGoToDate(); m.goToText = "oct 12"
        case "search-results": m.searchText = "calculus"
        case "month": m.setMode(.month)
        case "day": m.setMode(.day)
        case "sidebar-hidden": m.sidebarVisible = false
        case "all-day-collapsed": m.allDayCollapsed = true
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
        case "meet-with": m.meetQuery = "ma"
        case "readonly-event":
            if let e = m.layout.allDayEvents.values.first(where: { $0.title == "Tag der Deutschen Einheit" }) { m.select(eventID: e.id) }
        case "empty-access": break
        case "toast":
            if let e = m.layout.timed[1].first(where: { $0.event.title == "Meal Prep" })?.event { m.select(eventID: e.id); m.delete(e, span: .this) }
        case "search-empty": m.searchText = "Quokka"
        case "month-light": m.setMode(.month); m.settings.appearance = .light
        default: return false
        }
        return true
    }
}
