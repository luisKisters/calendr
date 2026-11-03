import AppKit
import CalendrKit

/// Snapshot states of the PANEL area. `SnapshotStates.apply` falls through to this for names it does not know.
@MainActor
enum SnapshotPanel {
    /// Puts the model into the named state. Returns false for names this area does not define.
    static func apply(_ state: String, _ m: AppModel) -> Bool {
        switch state {
        case "panel-sync":          // mockup: select(... "Thursday sync")
            if let e = SnapshotStates.find(m, "Thursday sync", day: 3) { m.select(eventID: e.id) }
        case "panel-readonly":      // mockup: select(... "Day of German Unity")
            if let e = m.layout.allDayEvents.values.first(where: { $0.title == "Day of German Unity" }) { m.select(eventID: e.id) }
        case "panel-long-title":
            if let e = SnapshotStates.find(m, "Sam / Alex", day: 1) {
                m.select(eventID: e.id)
                m.updateSelected { $0.title = "Quarterly planning with the studio team and everyone from Northwind" }
            }
        case "panel-added":         // v4: no "add" chips; the empty place and notes rows show their placeholders
            if let e = SnapshotStates.find(m, "Sam / Alex", day: 1) { m.select(eventID: e.id) }
        case "panel-create-titled":
            let s = m.math.date(on: DemoData.day(10, 1), minutes: 12 * 60)
            m.createEvent(start: s, end: s.addingTimeInterval(3600))
            m.updateSelected { $0.title = "Lunch with Maya" }
        case "panel-nothing-left":  // 23:30: the day is over
            m.setNow(m.math.date(on: m.now, minutes: 23 * 60 + 30))
        case "panel-light-detail":
            m.settings.appearance = .light
            if let e = SnapshotStates.find(m, "Thursday sync", day: 3) { m.select(eventID: e.id) }
        default: return applyV4(state, m)
        }
        return true
    }

    /// v4 editor scenes (design/mockup-v4 `preset()`), on the v4 fixture. "v4-event" and "v4-delete" are in `SnapshotV4`.
    static let v4States = ["v4-call", "v4-location", "v4-maps", "v4-calendar", "v4-reminders"]

    static func applyV4(_ state: String, _ m: AppModel) -> Bool {
        func open(_ id: String) { if let e = SnapshotV4.event(m, id) { m.select(eventID: e.id) } }
        switch state {
        case "v4-call": open("c3"); m.openPanelMenu(.call)              // Lunch with Theo: no call yet, the call menu
        case "v4-location":
            // Lunch with Theo, "Mark" typed into the location: the suggestions (the demo list stands in for MapKit)
            if var e = SnapshotV4.event(m, "c3") { e.location = "Mark"; _ = try? m.store.update(e, span: .this); m.storeChanged(); m.select(eventID: e.id) }
            m.searchPlaces("Mark")
        case "v4-maps": open("wg"); m.openPanelMenu(.maps)
        case "v4-calendar": open("wg"); m.openPanelMenu(.calendar)
        case "v4-reminders": open("wg"); m.openPanelMenu(.reminders)
        default: return false
        }
        SnapshotV4.scroll(m, to: SnapshotV4.defaultScroll)
        return true
    }
}
