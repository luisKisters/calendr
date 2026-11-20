import AppKit
import CalendrKit

/// Snapshot states of the GRID area on the demo week (views, appearance, hour height, creating by drag). `SnapshotStates.apply` falls
/// through to this for names it does not know.
@MainActor
enum SnapshotGrid {
    static let states = ["v11-week", "v11-week-paper", "month", "day", "light-week", "month-light", "sidebar-hidden", "create-drag", "week-numbers", "week-zoomed"]
    /// States drawn in Paper: `HeadlessRunner` switches the window to light for them.
    static let paper: Set<String> = ["light-week", "month-light", "v11-week-paper"]

    /// Puts the model into the named state. Returns false for names this area does not define.
    static func apply(_ state: String, _ m: AppModel) -> Bool {
        switch state {
        // The mockup-v11 demo week (`--fixture v11`) as the locked mockup shows it at `?demo=1#tab=read&look=R&fs=1`.
        case "v11-week": SnapshotV4.scroll(m, to: DemoDataV11.scroll)
        case "v11-week-paper": m.settings.appearance = .light; SnapshotV4.scroll(m, to: DemoDataV11.scroll)
        case "month": m.setMode(.month)
        case "day": m.setMode(.day); SnapshotV4.scroll(m, to: SnapshotV4.defaultScroll)
        case "light-week": m.settings.appearance = .light; SnapshotV4.scroll(m, to: SnapshotV4.defaultScroll)
        case "month-light": m.setMode(.month); m.settings.appearance = .light
        case "sidebar-hidden": m.sidebarVisible = false; SnapshotV4.scroll(m, to: SnapshotV4.defaultScroll)
        case "create-drag":
            // Thursday 14:15-15:35, mid-drag: free time between Lunch and Office hours.
            let g = m.gridGeometry
            let x = 3.5 * g.dayWidth
            m.gridMouseDown(CGPoint(x: x, y: g.yPos(14 * 60 + 15) + 2))
            m.gridMouseDragged(CGPoint(x: x, y: g.yPos(15 * 60 + 35)))
            SnapshotV4.scroll(m, to: SnapshotV4.defaultScroll)
        case "week-numbers": m.settings.showWeekNumbers = true; SnapshotV4.scroll(m, to: SnapshotV4.defaultScroll)
        case "week-zoomed": m.settings.hourHeight = 96; SnapshotV4.scroll(m, to: 12 * 96)
        default: return false
        }
        return true
    }
}
