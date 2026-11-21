import AppKit
import CalendrKit

/// Snapshot states of the GRID area on the demo week (views, appearance, hour height, creating by drag). `SnapshotStates.apply` falls
/// through to this for names it does not know.
@MainActor
enum SnapshotGrid {
    static let states = ["v11-week", "v11-week-paper", "v11-sidebar", "v11-sidebar-paper", "v11-right-hidden", "month", "day", "light-week", "month-light", "sidebar-hidden", "create-drag", "week-numbers", "week-zoomed"]
    /// States drawn in Paper: `HeadlessRunner` switches the window to light for them.
    static let paper: Set<String> = ["light-week", "month-light", "v11-week-paper", "v11-sidebar-paper"]

    /// Puts the model into the named state. Returns false for names this area does not define.
    static func apply(_ state: String, _ m: AppModel) -> Bool {
        switch state {
        // The mockup-v11 demo week (`--fixture v11`) as the locked mockup shows it at `?demo=1#tab=read&look=R&fs=1` (its demo
        // state has week numbers on in the mini month).
        case "v11-week": m.settings.showWeekNumbers = true; SnapshotV4.scroll(m, to: DemoDataV11.scroll)
        case "v11-week-paper": m.settings.appearance = .light; m.settings.showWeekNumbers = true; SnapshotV4.scroll(m, to: DemoDataV11.scroll)
        // v5 I chrome states (v8 decisions D, E): Family hidden (dimmed, eye-slash), iCloud folded (chevron right, "2"), the
        // pointer on Work (its eye); and the week with the right column hidden (the header button stays lit).
        case "v11-sidebar", "v11-sidebar-paper":
            if state.hasSuffix("paper") { m.settings.appearance = .light }
            m.settings.showWeekNumbers = true
            let cals = m.store.accounts.flatMap(\.calendars)
            if let family = cals.first(where: { $0.title == "Family" }) { m.toggleCalendar(family.id) }
            if let work = cals.first(where: { $0.title == "Work" }) { HoverProbe.shared.target = "cal:\(work.id)" }
            if let icloud = m.store.accounts.first(where: { AccountName.display($0.name) == "iCloud" }) { m.toggleGroup(icloud.id) }
            SnapshotV4.scroll(m, to: DemoDataV11.scroll)
        case "v11-right-hidden": m.settings.showWeekNumbers = true; m.toggleRightColumn(); SnapshotV4.scroll(m, to: DemoDataV11.scroll)
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
