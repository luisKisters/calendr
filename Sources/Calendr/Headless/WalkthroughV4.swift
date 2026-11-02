import AppKit
import SwiftUI
import CalendrKit

/// The v4 feature tours (`--walkthrough v4-a --record <mov>`), one per PR of the v4 stack, on the v4 fixture (Sun 4 Oct 2026 15:10).
/// Each is 10-25 s at real speed and asserts every step, like the v3 tour.
@MainActor
enum WalkthroughV4 {
    /// Window points of the header's Day / Week / Month segments and of the settings rows (1440x900 window, v4 tokens).
    static let tabs: [(ViewMode, String, CGPoint)] = [(.day, "Day", CGPoint(x: 726, y: 30)), (.week, "Week", CGPoint(x: 772, y: 30)),
                                                      (.month, "Month", CGPoint(x: 825, y: 30))]
    static let weekNumbersOn = CGPoint(x: 975, y: 413)

    /// Brightness (0...1) of the frame at a window point: hover and selection fills change it.
    static func luma(_ d: Driver, at p: CGPoint) -> Double {
        d.settle(2)
        guard let img = d.win.image(scale: 1), let data = img.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return -1 }
        let x = Int(p.x), y = Int(p.y), bpp = img.bitsPerPixel / 8
        let o = y * img.bytesPerRow + x * bpp
        return (Double(bytes[o]) + Double(bytes[o + 1]) + Double(bytes[o + 2])) / (3 * 255)
    }

    /// A point on a segment's fill, left of its label.
    static func fillPoint(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - 16, y: p.y - 8) }

    static func hover(_ d: Driver, _ target: String?, at p: CGPoint) {
        d.moveCursor(to: p, duration: 0.4)
        d.play(0.25) { HoverProbe.shared.target = target }
    }

    /// PR A, the design tokens: black OLED surfaces, SF Pro text, the one Segmented, grey key hints, the 12 pt dialog surfaces.
    static func a(_ d: Driver, _ m: AppModel) {
        func tab(_ t: String) -> (ViewMode, String, CGPoint) { tabs.first { $0.1 == t }! }

        d.section("v4 tokens")
        d.check(m.viewMode == .week && m.math.day(m.now) == 4 && m.settings.hourHeight == 46, "v4 fixture: the week of Sun 4 Oct, 46 pt hours")
        d.check(luma(d, at: CGPoint(x: 700, y: 400)) == 0, "the grid background is pure black")
        d.say("v4 tokens: black surfaces, SF Pro, one segmented control")
        d.frame(hold: 1.6)

        d.section("Segmented view switch")
        for name in ["Month", "Day", "Week"] {
            let (mode, title, p) = tab(name)
            d.say("Hover, then click \(title)")
            let before = luma(d, at: fillPoint(p))
            hover(d, title, at: p)
            d.check(luma(d, at: fillPoint(p)) > before, "\(title) shows the hover fill")
            d.hold(0.5)
            HoverProbe.shared.target = nil
            d.clickPoint(p, seconds: 0.6)
            d.check(m.viewMode.baseMode == mode, "the \(title) segment switches to \(title)")
            d.hold(name == "Week" ? 0.6 : 1.0)
        }

        d.section("Command menu")
        d.say("Command menu", keys: ["\u{2318}", "K"])
        d.moveCursor(to: CGPoint(x: 720, y: 200))
        d.play(0.5) { d.key("k", cmd: true) }
        d.check(m.overlay == .command, "Cmd-K opens the command menu")
        d.hold(0.6)
        d.say("Type a query")
        d.type("flat")
        d.check(m.chromeState.paletteQuery == "flat" && !m.paletteRows.isEmpty, "the query filters the rows (\(m.paletteRows.count))")
        d.hold(1.2)
        d.play(0.4) { d.special("esc") }
        d.check(m.overlay == nil, "Esc closes the command menu")

        d.section("Settings")
        d.say("Settings", keys: ["\u{2318}", ","])
        d.play(0.6) { d.key(",", cmd: true) }
        d.check(m.overlay == .settings, "Cmd-, opens Settings")
        d.hold(0.6)
        d.say("Every switch is the same segmented control")
        let before = luma(d, at: fillPoint(weekNumbersOn))
        hover(d, "On", at: weekNumbersOn)
        d.check(luma(d, at: fillPoint(weekNumbersOn)) > before, "On shows the hover fill")
        d.hold(0.4)
        HoverProbe.shared.target = nil
        d.clickPoint(weekNumbersOn, seconds: 0.5)
        d.check(m.settings.showWeekNumbers, "week numbers are on")
        d.hold(1.2)
        d.say("Esc closes Settings", keys: ["esc"])
        d.play(0.5) { d.special("esc") }
        d.check(m.overlay == nil, "Esc closes Settings")
        d.say("Week numbers in the mini month")
        d.moveCursor(to: CGPoint(x: 30, y: 160), duration: 0.5)
        d.hold(1.4)
        d.endCaption()
    }
}
