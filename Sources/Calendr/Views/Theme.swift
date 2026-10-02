import SwiftUI
import AppKit

// Values come from design/mockup-v3/app.css (the locked v3 design).

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        let v = UInt64(h, radix: 16) ?? 0
        self.init(.sRGB, red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255, opacity: 1)
    }
    /// Dynamic color following the effective appearance (dark first).
    static func dyn(_ dark: String, _ light: String) -> Color {
        Color(nsColor: NSColor(name: nil) { ap in
            let isDark = ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
    }
    static func dyn(_ dark: Color, _ light: Color) -> Color {
        Color(nsColor: NSColor(name: nil) { ap in
            NSColor(ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
        })
    }
}

/// Calendr v3 tokens (design/mockup-v3/app.css: `ink` dark, `paper` light, accent "None, ink only"). Dark first.
enum Theme {
    static func a(_ hex: String, _ alpha: Double) -> Color { Color(hex: hex).opacity(alpha) }

    static let bg = Color.dyn("#0E0E11", "#FBFAF6")
    static let bg1 = Color.dyn("#15151A", "#F5F3ED")
    static let bg2 = Color.dyn("#1E1E24", "#ECE9E1")
    static let bg3 = Color.dyn("#2B2B33", "#DFDBD1")
    static let fg = Color.dyn("#EDECF1", "#1B1A20")
    static let fg2 = Color.dyn("#A19FAC", "#5C5A65")
    static let fg3 = Color.dyn("#6D6B78", "#918E99")
    static let hair = Color.dyn(a("#EDECF1", 0.065), a("#1B1A20", 0.075))
    static let hair2 = Color.dyn(a("#EDECF1", 0.13), a("#1B1A20", 0.15))
    static let hover = Color.dyn(a("#EDECF1", 0.055), a("#1B1A20", 0.05))
    static let scrim = Color.dyn(a("#040407", 0.52), a("#28241E", 0.26))
    static let live = Color.dyn("#FF453A", "#E5342A")

    // Accent: none, ink only. Selection and today are inverted ink.
    static let act = fg
    static let onAct = bg
    static let actWash = Color.dyn(a("#EDECF1", 0.09), a("#1B1A20", 0.09))
    /// Hover of a filled `act` control: act 88 percent over the window colour.
    static let actHover = Color.dyn("#D2D1D6", "#36353A")
    static let ring = Color.dyn(a("#EDECF1", 0.82), a("#1B1A20", 0.82))
    static let focus = Color.dyn(a("#EDECF1", 0.46), a("#1B1A20", 0.46))

    // v2 names still used by the root and onboarding views.
    static let ink900 = bg
    static let ink700 = bg2
    static let paper = fg
    static let haze = fg2
    static let hazeDim = fg3
    static let actLift = fg
    static let actSoft = hover
    static let hairStrong = hair2

    // Metrics
    static let gutterWidth: CGFloat = Dim.hourGutter
}

enum Dim {
    static let sidebarWidth: CGFloat = 236
    static let panelWidth: CGFloat = 320
    static let hourGutter: CGFloat = 56
    static let toolbarHeight: CGFloat = 60
    static let dayHeaderHeight: CGFloat = 38
    static let inset: CGFloat = 16
}

/// Corners: soft (events 6, controls 7, rows 7, surfaces 12).
enum Radius {
    static let event: CGFloat = 6
    static let chip: CGFloat = 5
    static let control: CGFloat = 7
    static let row: CGFloat = 7
    static let card: CGFloat = 12
    static let surface: CGFloat = 12
}

/// Shadows only exist on surfaces above the window.
extension View {
    func popShadow() -> some View { shadow(color: Color.dyn(Color.black.opacity(0.6), Color(hex: "#282214").opacity(0.20)), radius: 30, y: 22) }
    func liftShadow() -> some View { shadow(color: Color.dyn(Color.black.opacity(0.45), Color(hex: "#282214").opacity(0.16)), radius: 11, y: 8) }
}

// MARK: Motion (design/DESIGN.md)

/// One curve, four durations. Everything is instant under Reduce Motion (system or the Settings override).
@MainActor
enum Motion {
    /// Set by the model from the Settings override.
    static var override = false
    /// Snapshots and perf runs render settled frames.
    static var forcedInstant = false
    static var reduced: Bool { forcedInstant || override || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    static func curve(_ d: Double) -> Animation? { reduced ? nil : Animation.timingCurve(0.22, 0.61, 0.36, 1, duration: d) }
    static var fast: Animation? { curve(0.12) }
    static var base: Animation? { curve(0.18) }
    static var slow: Animation? { curve(0.26) }
    static var sheet: Animation? { curve(0.30) }
    static var spring: Animation? { reduced ? nil : .spring(response: 0.3, dampingFraction: 0.7) }
}

/// Period change: content slides 36 pt in the direction of travel while fading in (180 ms). The old content is removed at once,
/// so nothing is laid out twice during the animation.
struct SlideFade: ViewModifier {
    var x: CGFloat
    var opacity: Double
    func body(content: Content) -> some View { content.offset(x: x).opacity(opacity) }
}

extension AnyTransition {
    static func periodSlide(_ direction: Int) -> AnyTransition {
        .asymmetric(insertion: .modifier(active: SlideFade(x: CGFloat(direction) * 36, opacity: 0), identity: SlideFade(x: 0, opacity: 1)), removal: .identity)
    }
}

struct RGB: Equatable {
    var r: Double, g: Double, b: Double
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    init(hex: String) {
        let v = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255)
    }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    var cg: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: 1) }
    func mixed(with o: RGB, _ t: Double) -> RGB { RGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t) }
}

/// Colors for an event (app.css `.ev`): the calendar colour (`--cc`, darkened 22 percent toward ink on paper) as the bar, mixed over the
/// window colour for the fill (17 / 25 / 8 percent on ink, 15 / 23 / 7 on paper), title and time tinted toward it.
/// Both SwiftUI and CoreGraphics forms are kept because the grid paints events with CoreGraphics.
struct EventPalette: Equatable {
    var barRGB: RGB, fillRGB: RGB, hoverFillRGB: RGB, pastFillRGB: RGB, titleRGB: RGB, timeRGB: RGB
    var bar: Color { barRGB.color }
    var fill: Color { fillRGB.color }
    var title: Color { titleRGB.color }
    var time: Color { timeRGB.color }
}

enum Palettes {
    nonisolated(unsafe) private static var cache: [String: EventPalette] = [:]
    static func bg(_ dark: Bool) -> RGB { dark ? RGB(hex: "#0E0E11") : RGB(hex: "#FBFAF6") }
    static func fg(_ dark: Bool) -> RGB { dark ? RGB(hex: "#EDECF1") : RGB(hex: "#1B1A20") }
    static func fg2(_ dark: Bool) -> RGB { dark ? RGB(hex: "#A19FAC") : RGB(hex: "#5C5A65") }
    /// `--cc`: the calendar colour as drawn. Paper darkens it 22 percent toward #15151A.
    static func cc(_ hex: String, dark: Bool) -> RGB { dark ? RGB(hex: hex) : RGB(hex: hex).mixed(with: RGB(hex: "#15151A"), 0.22) }

    /// `barHex` is the calendar color, `fillHex` an optional per-event override of the tint.
    static func palette(barHex: String, fillHex: String?, dark: Bool) -> EventPalette {
        let key = barHex.lowercased() + "|" + (fillHex ?? "") + (dark ? "|d" : "|l")
        if let c = cache[key] { return c }
        let bar = cc(barHex, dark: dark), tint = fillHex.map { cc($0, dark: dark) } ?? bar, base = bg(dark)
        let out = EventPalette(barRGB: bar, fillRGB: base.mixed(with: tint, dark ? 0.17 : 0.15), hoverFillRGB: base.mixed(with: tint, dark ? 0.25 : 0.23),
                               pastFillRGB: base.mixed(with: tint, dark ? 0.08 : 0.07),
                               titleRGB: fg(dark).mixed(with: bar, 0.22), timeRGB: fg2(dark).mixed(with: bar, 0.30))
        cache[key] = out
        return out
    }
}

/// Small caps section label: 10.5 / 600, +0.06em.
struct MicroLabel: View {
    let text: String
    var color: Color = Theme.hazeDim
    var body: some View { Text(text.uppercased()).font(.calMicro).tracking(0.63).foregroundStyle(color) }
}
