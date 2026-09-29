import SwiftUI
import AppKit

// Values come from design/mockup/index.html (the design source, sampled from the reference screenshots).

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

/// Calendr v2 tokens (design/mockup-v2/TOKENS.md). Dark first, light derived.
enum Theme {
    static func a(_ hex: String, _ alpha: Double) -> Color { Color(hex: hex).opacity(alpha) }

    static let ink900 = Color.dyn("#0F0E14", "#FBFAF7")
    static let ink800 = Color.dyn("#16151D", "#F3F1EE")
    static let ink700 = Color.dyn("#1E1C28", "#EAE7EF")
    static let ink600 = Color.dyn("#2A2836", "#DCD8E6")
    static let paper = Color.dyn("#EDEBF5", "#1C1A26")
    static let haze = Color.dyn("#9A96AD", "#5F5B74")
    static let hazeDim = Color.dyn("#6B6880", "#8D89A1")
    static let act = Color.dyn("#8B5CF6", "#7C3AED")
    static let actLift = Color.dyn("#A78BFA", "#6D28D9")
    static let actWash = Color.dyn(a("#8B5CF6", 0.20), a("#7C3AED", 0.14))
    static let actSoft = Color.dyn(a("#8B5CF6", 0.09), a("#7C3AED", 0.06))
    static let onAct = Color.white
    static let live = Color.dyn("#FF453A", "#E5342A")
    static let hair = Color.dyn(a("#EDEBF5", 0.08), a("#1C1A26", 0.09))
    static let hairStrong = Color.dyn(a("#EDEBF5", 0.14), a("#1C1A26", 0.16))
    static let hover = Color.dyn(a("#EDEBF5", 0.05), a("#1C1A26", 0.045))
    static let scrim = Color.dyn(a("#06050A", 0.46), a("#282240", 0.22))
    static let keyEdge = Color.dyn(Color.black.opacity(0.35), a("#1C1A26", 0.16))

    // Legacy names used across the views, mapped onto the v2 ramp.
    static let bg = ink900
    static let side = ink800
    static let line = hair
    static let hline = hair
    static let border = hair
    static let sep = hair
    static let t1 = paper
    static let t2 = haze
    static let t3 = hazeDim
    static let chip = ink600
    static let chipText = haze
    static let btn = ink700
    static let btnBorder = hairStrong
    static let red = live
    static let pal = ink800
    static let palBorder = hair
    static let palSel = actWash
    static let palChip = ink600
    static let palFoot = ink900
    static let palFootText = haze
    static let band = actWash
    static let field = ink700
    static let placeholder = hazeDim
    static let overlay = scrim
    static let ring = act
    static let pop = ink800
    static let popBorder = hair
    static let getCal = ink700
    static let miniDow = hazeDim
    static let miniDay = paper
    static let miniOther = hazeDim

    // Metrics
    static let hourHeight: CGFloat = Dim.hourHeight
    static let gutterWidth: CGFloat = Dim.hourGutter
    static let sidebarWidth: CGFloat = Dim.sidebarWidth
    static let rightPanelWidth: CGFloat = Dim.panelWidth
    static let toolbarHeight: CGFloat = Dim.toolbarHeight
}

enum Dim {
    static let sidebarWidth: CGFloat = 248
    static let panelWidth: CGFloat = 304
    static let hourGutter: CGFloat = 56
    static let hourHeight: CGFloat = 48
    static let toolbarHeight: CGFloat = 52
    static let dayHeaderHeight: CGFloat = 36
    static let inset: CGFloat = 16
}

enum Radius {
    static let event: CGFloat = 7
    static let chip: CGFloat = 5
    static let control: CGFloat = 9
    static let card: CGFloat = 12
    static let surface: CGFloat = 15
}

/// Shadows only exist on surfaces above the window.
extension View {
    func popShadow() -> some View { shadow(color: Color.dyn(Color.black.opacity(0.55), Color(hex: "#281E50").opacity(0.20)), radius: 32, y: 24) }
    func liftShadow() -> some View { shadow(color: Color.dyn(Color.black.opacity(0.45), Color(hex: "#281E50").opacity(0.18)), radius: 9, y: 6) }
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

/// Colors for an event: tint fill (calendar color at ~22% over ink-900), full-color bar, paper title, haze time.
/// Both SwiftUI and CoreGraphics forms are kept because the grid paints events with CoreGraphics.
struct EventPalette: Equatable {
    var barRGB: RGB, fillRGB: RGB, hoverFillRGB: RGB, titleRGB: RGB, timeRGB: RGB
    var bar: Color { barRGB.color }
    var fill: Color { fillRGB.color }
    var title: Color { titleRGB.color }
    var time: Color { timeRGB.color }
}

enum Palettes {
    nonisolated(unsafe) private static var cache: [String: EventPalette] = [:]
    static func ink900(_ dark: Bool) -> RGB { dark ? RGB(hex: "#0F0E14") : RGB(hex: "#FBFAF7") }

    /// `barHex` is the calendar color, `fillHex` an optional per-event override of the tint.
    static func palette(barHex: String, fillHex: String?, dark: Bool) -> EventPalette {
        let key = barHex.lowercased() + "|" + (fillHex ?? "") + (dark ? "|d" : "|l")
        if let c = cache[key] { return c }
        let bar = RGB(hex: barHex), tint = RGB(hex: fillHex ?? barHex), base = ink900(dark)
        let out = EventPalette(barRGB: bar, fillRGB: base.mixed(with: tint, dark ? 0.22 : 0.17), hoverFillRGB: base.mixed(with: tint, dark ? 0.30 : 0.24),
                               titleRGB: RGB(hex: dark ? "#EDEBF5" : "#1C1A26"), timeRGB: RGB(hex: dark ? "#9A96AD" : "#5F5B74"))
        cache[key] = out
        return out
    }
    static func gray(_ dark: Bool) -> EventPalette { palette(barHex: "#B9B6C9", fillHex: nil, dark: dark) }
}

extension Font {
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
    /// Mono is the machine: times, durations, date numerals, keycaps, GMT, week numbers.
    static func calMono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .monospaced).monospacedDigit() }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { calMono(size, weight) }
    static let calTitle = Font.system(size: 22, weight: .semibold)
    static let calLead = Font.system(size: 16, weight: .semibold)
    static let calBody = Font.system(size: 13)
    static let calMeta = Font.system(size: 11.5)
    static let calMicro = Font.system(size: 10.5, weight: .semibold)
}

/// Small caps section label: 10.5 / 600, +0.06em.
struct MicroLabel: View {
    let text: String
    var color: Color = Theme.hazeDim
    var body: some View { Text(text.uppercased()).font(.calMicro).tracking(0.63).foregroundStyle(color) }
}
