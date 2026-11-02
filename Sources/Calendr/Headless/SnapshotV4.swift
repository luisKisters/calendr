import AppKit
import CalendrKit

/// Snapshot states of the v4 mockup scenes (design/mockup-v4/index.html `preset()`), rendered with `--fixture v4` (design/states.json
/// sets it) so they compare one to one with design/mockup-v4/shots. `SnapshotStates.apply` falls through to this for names it does not know.
/// "v4-menubar" is a menu bar screen: `SnapshotMenuBar.run` draws it.
@MainActor
enum SnapshotV4 {
    static let states = ["v4-week", "v4-overlap", "v4-status", "v4-event", "v4-cmd", "v4-settings", "v4-menubar", "v4-delete"]

    /// Mockup `A.gridScroll`: 7.5 hours down by default, 16.4 for the busy evening.
    static let defaultScroll = 7.5 * DemoDataV4.hourHeight
    static let eveningScroll = 16.4 * DemoDataV4.hourHeight

    static func event(_ m: AppModel, _ seedID: String) -> CalendarEvent? { m.event(id: "v4.\(seedID)") }

    /// Puts the model into the named state. Returns false for names this area does not define.
    static func apply(_ state: String, _ m: AppModel) -> Bool {
        switch state {
        case "v4-week": scroll(m, to: defaultScroll)
        case "v4-overlap": scroll(m, to: eveningScroll)
        case "v4-status":
            // Club board meeting: an invitation Sam has not answered.
            if let e = event(m, "w5") { m.select(eventID: e.id) }
            scroll(m, to: eveningScroll)
        case "v4-event":
            if let e = event(m, "wg") { m.select(eventID: e.id) }
            scroll(m, to: defaultScroll)
        case "v4-cmd": m.openPalette(.all); scroll(m, to: defaultScroll)
        case "v4-settings": m.overlay = .settings; scroll(m, to: defaultScroll)
        case "v4-delete":
            if let e = event(m, "wg") { m.select(eventID: e.id); m.requestDeleteSelected() }
            scroll(m, to: defaultScroll)
        default: return false
        }
        return true
    }

    private static func scroll(_ m: AppModel, to y: Double) {
        after(0.05) {
            m.gridState.scrollTarget = y
            m.gridState.scrollTick += 1
        }
    }
}
