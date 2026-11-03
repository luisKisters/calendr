import AppKit
import CalendrKit

/// Snapshot states of the CHROME area. `SnapshotStates.apply` falls through to this for names it does not know.
@MainActor
enum SnapshotChrome {
    /// States of this area. "v4-search": the right column's field with "walk", results grouped by day.
    static let v4States = ["v4-search"]
    /// The other chrome states: Meet with, go to date, an empty search, the shortcuts sheet, the undo pill, no calendar access.
    static let states = ["teammate-picker", "meet-with", "teammate-overlay", "go-to-date", "search-empty", "shortcuts-sheet", "toast", "empty-access"]

    /// Puts the model into the named state. Returns false for names this area does not define.
    static func apply(_ state: String, _ m: AppModel) -> Bool {
        switch state {
        case "teammate-picker": m.openPalette(.meet); SnapshotV4.scroll(m, to: SnapshotV4.defaultScroll)
        case "meet-with": m.openPalette(.meet); m.setPaletteQuery("ma"); SnapshotV4.scroll(m, to: SnapshotV4.defaultScroll)
        case "teammate-overlay":
            // Ines Duarte's busy time (the mockup's busyFor) next to Sam's week.
            if let t = m.store.teammates.first(where: { $0.name == "Ines Duarte" }) { m.toggleMate(t) }
            SnapshotV4.scroll(m, to: SnapshotV4.defaultScroll)
        case "go-to-date": m.openPalette(.goTo); m.setPaletteQuery("next fri"); SnapshotV4.scroll(m, to: SnapshotV4.defaultScroll)
        case "search-empty": m.openPalette(.search); m.setPaletteQuery("Quokka"); SnapshotV4.scroll(m, to: SnapshotV4.defaultScroll)
        case "shortcuts-sheet": m.overlay = .shortcuts; SnapshotV4.scroll(m, to: SnapshotV4.defaultScroll)
        case "toast":
            // The undo pill after moving Club committee an hour later.
            if let e = SnapshotStates.find(m, "Club committee", day: 3) {
                var moved = e; moved.start = e.start.addingTimeInterval(3600); moved.end = e.end.addingTimeInterval(3600)
                m.showToast(m.undoToastText(old: e, new: moved), undo: true)
            }
            SnapshotV4.scroll(m, to: SnapshotV4.defaultScroll)
        case "empty-access": break      // `HeadlessRunner` builds the model on a store that has not been granted access
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
