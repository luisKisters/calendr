import AppKit
import SwiftUI
import CalendrKit

/// Snapshot states of the MENUBAR area. `SnapshotStates.apply` falls through to this for names it does not know.
@MainActor
enum SnapshotMenuBar {
    /// The menu bar states are whole screens drawn by `run`, so no window state applies.
    static func apply(_ state: String, _ m: AppModel) -> Bool { false }

    /// The menu bar screens: "v4-menubar", the open menu at the fixture's clock; "menubar-empty", the same at 23:30 with nothing left.
    static let screens = ["v4-menubar", "menubar-empty"]

    /// Renders a menu bar screen (`MenuBarScreenPreview`) instead of the window. Nil for every other state.
    static func run(_ state: String, _ m: AppModel, _ o: LaunchOptions, out: String) -> Int32? {
        guard screens.contains(state) else { return nil }
        let behind = OffscreenWindow(RootView().environment(m), size: CGSize(width: 1440, height: 900), dark: true)
        behind.settle(8)
        let backdrop = behind.image(scale: o.scale).map { NSImage(cgImage: $0, size: NSSize(width: 1440, height: 900)) }
        behind.close()

        if state == "menubar-empty" { m.setNow(m.math.date(on: m.math.startOfDay(m.now), minutes: 23 * 60 + 30)) }
        let menu = m.menuBarMenu
        let highlight: Int? = menu.rows.isEmpty ? nil : 0
        let f = m.fmt
        let clock = "\(f.weekdayShort(m.now)) \(m.math.day(m.now)) \(f.monthShort(m.now))  \(f.time(m.now))"
        let view = MenuBarScreenPreview(menu: menu, display: m.settings.menuBarDisplay, clock: clock, backdrop: backdrop,
                                        highlight: highlight, submenu: nil)
        let w = OffscreenWindow(view, size: CGSize(width: 1440, height: 900), chrome: false)
        w.settle(6)
        let ok = w.writePNG(to: out, scale: o.scale)
        print(ok ? "wrote \(out)" : "failed \(out)")
        return ok ? 0 : 1
    }
}
