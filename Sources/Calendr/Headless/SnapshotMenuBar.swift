import AppKit
import SwiftUI
import CalendrKit

/// Snapshot states of the MENUBAR area. `SnapshotStates.apply` falls through to this for names it does not know.
@MainActor
enum SnapshotMenuBar {
    /// The menu bar states are whole screens drawn by `run`, so no window state applies.
    static func apply(_ state: String, _ m: AppModel) -> Bool { false }

    /// The menu bar screens of design/mockup-v3/menubar.html (moment m12, an open row menu, run, none).
    /// "menubar-popover" and "menubar-empty" are the older names design/states.json still lists for "menubar" and "menubar-none".
    static let screens = ["menubar-popover", "menubar", "menubar-submenu", "menubar-running", "menubar-none", "menubar-empty"]

    /// Renders a menu bar screen (`MenuBarScreenPreview`) instead of the window. Nil for every other state.
    static func run(_ state: String, _ m: AppModel, _ o: LaunchOptions, out: String) -> Int32? {
        guard screens.contains(state) else { return nil }
        let behind = OffscreenWindow(RootView().environment(m), size: CGSize(width: 1440, height: 900), dark: true)
        behind.settle(8)
        let backdrop = behind.image(scale: o.scale).map { NSImage(cgImage: $0, size: NSSize(width: 1440, height: 900)) }
        behind.close()

        let day = DemoData.day(9, 29)
        switch state {
        case "menubar-running": m.setNow(m.math.date(on: day, minutes: 12 * 60 + 20))
        case "menubar-none", "menubar-empty": m.setNow(m.math.date(on: day, minutes: 23 * 60 + 30))
        default: break
        }
        let menu = m.menuBarMenu
        var highlight: Int? = menu.rows.isEmpty ? nil : 0
        var submenu: [MenuBarSubItem]?
        if state == "menubar-submenu", let i = menu.rows.firstIndex(where: { $0.title == "Sam / Alex" }) {
            highlight = i
            submenu = m.menuBarSubmenu(for: menu.rows[i].event)
        }
        let f = m.fmt
        let clock = "\(f.weekdayShort(m.now)) \(m.math.day(m.now)) \(f.monthShort(m.now))  \(f.time(m.now))"
        let view = MenuBarScreenPreview(menu: menu, display: m.settings.menuBarDisplay, clock: clock, backdrop: backdrop,
                                        highlight: highlight, submenu: submenu)
        let w = OffscreenWindow(view, size: CGSize(width: 1440, height: 900), chrome: false)
        w.settle(6)
        let ok = w.writePNG(to: out, scale: o.scale)
        print(ok ? "wrote \(out)" : "failed \(out)")
        return ok ? 0 : 1
    }
}
