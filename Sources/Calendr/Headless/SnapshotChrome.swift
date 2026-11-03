import AppKit
import CalendrKit

/// Snapshot states of the CHROME area. `SnapshotStates.apply` falls through to this for names it does not know.
@MainActor
enum SnapshotChrome {
    /// States of this area. "v4-search": the right column's field with "walk", results grouped by day.
    static let v4States = ["v4-search"]

    /// Puts the model into the named state. Returns false for names this area does not define.
    static func apply(_ state: String, _ m: AppModel) -> Bool {
        switch state {
        case "v4-search":
            m.setColumnQuery("walk")
            after(0.05) {
                m.gridState.scrollTarget = SnapshotV4.defaultScroll
                m.gridState.scrollTick += 1
            }
        default: return false
        }
        return true
    }
}
