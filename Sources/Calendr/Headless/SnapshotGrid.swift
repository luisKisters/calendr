import AppKit
import CalendrKit

/// Snapshot states of the GRID area. `SnapshotStates.apply` falls through to this for names it does not know.
@MainActor
enum SnapshotGrid {
    /// Puts the model into the named state. Returns false for names this area does not define.
    static func apply(_ state: String, _ m: AppModel) -> Bool {
        switch state {
        case "week-zoomed-scrolled":
            // Mockup: S.zoom = 96; S.scrollTop = 600
            m.settings.hourHeight = 96
            scroll(m, to: 600)
        case "week-scrolled-midnight": scroll(m, to: 0)
        case "week-hover":
            // The gutter pill for the snapped time under the pointer (Wed 14:15, empty grid).
            m.gridState.pointer.minute = 14 * 60 + 15
        case "week-double-click":
            // A double-click on empty grid (Sat 10:20) creates an event of the default length at the half hour under the pointer.
            let g = m.gridGeometry
            let p = CGPoint(x: 5.5 * g.dayWidth, y: g.yPos(10 * 60 + 20))
            m.gridMouseDown(p); m.gridMouseUp(p)
            m.gridMouseDown(p, clickCount: 2); m.gridMouseUp(p)
        case "month-more":
            m.setMode(.month)
            // The first "n more" of the month as laid out on screen.
            after(0.05) { if let it = m.gridState.monthCache.layout?.items.first(where: { $0.kind == .more }) { m.openDayList(it.day) } }
        case "month-create-all-day":
            m.setMode(.month)
            m.createAllDay(on: DemoData.day(9, 24))
        case "month-selected":
            m.setMode(.month)
            if let e = m.monthEvents.joined().first(where: { $0.title == "Public Policy" && m.math.day($0.start) == 30 }) { m.select(eventID: e.id) }
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
