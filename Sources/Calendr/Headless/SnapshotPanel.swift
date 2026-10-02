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
        case "panel-added":         // "+ Place" and "+ Notes" pressed on an event without them
            if let e = SnapshotStates.find(m, "Sam / Alex", day: 1) { m.select(eventID: e.id); m.addPanelField(.place); m.addPanelField(.notes) }
        case "panel-create-titled":
            let s = m.math.date(on: DemoData.day(10, 1), minutes: 12 * 60)
            m.createEvent(start: s, end: s.addingTimeInterval(3600))
            m.updateSelected { $0.title = "Lunch with Maya" }
        case "panel-nothing-left":  // 23:30: the day is over
            m.setNow(m.math.date(on: m.now, minutes: 23 * 60 + 30))
        case "panel-light-detail":
            m.settings.appearance = .light
            if let e = SnapshotStates.find(m, "Thursday sync", day: 3) { m.select(eventID: e.id) }
        default: return false
        }
        return true
    }
}
