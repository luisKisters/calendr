import SwiftUI
import AppKit

// Values come from design/mockup-v4 (DECISIONS.md and the `.ds` design-system block): `PALETTES` 'oled' dark, Paper light (Q4).

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        let v = UInt64(h, radix: 16) ?? 0
        self.init(.sRGB, red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255, opacity: 1)
    }
    /// Dynamic color following the effective appearance (dark first).
    static func dyn(_ dark: Color, _ light: Color) -> Color {
        Color(nsColor: NSColor(name: nil) { ap in
            NSColor(ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
        })
    }
    /// One `InkRGB` role in both appearances.
    static func ink(_ role: (InkRGB) -> RGB) -> Color { dyn(role(.dark).color, role(.light).color) }
    /// One `InkRGB` role at an alpha (the alpha may differ per appearance).
    static func ink(_ role: (InkRGB) -> RGB, _ darkAlpha: Double, _ lightAlpha: Double) -> Color {
        dyn(role(.dark).color.opacity(darkAlpha), role(.light).color.opacity(lightAlpha))
    }
}

/// The one colour table. `Theme` (SwiftUI), `EventPainter.Ink` (CoreGraphics) and `Palettes` (event tints) all derive from it.
/// Dark is the mockup's `PALETTES` 'oled' line (TokenTests compares them); light stays Paper with the same roles.
struct InkRGB: Equatable {
    /// bg: window, sidebar, right column · bg1: cards · bg2: fields, raised controls · bg3: knobs, pills · pop: menus and dialogs.
    let bg, bg1, bg2, bg3, pop, fg, fg2, fg3: RGB
    /// Red, only for now.
    let live: RGB
    /// The selected segment of a `Segmented`.
    let thumb: RGB
    /// Alphas of fg for hair, hair2 and hover.
    let hairAlpha, hair2Alpha, hoverAlpha: Double

    static let dark: InkRGB = {
        let bg3 = RGB(hex: "#1F1F1F"), fg = RGB(hex: "#F2F2F2")
        return InkRGB(bg: RGB(hex: "#000000"), bg1: RGB(hex: "#0A0A0A"), bg2: RGB(hex: "#141414"), bg3: bg3, pop: RGB(hex: "#0C0C0C"),
                      fg: fg, fg2: RGB(hex: "#A0A0A0"), fg3: RGB(hex: "#6A6A6A"), live: RGB(hex: "#FF453A"),
                      thumb: bg3.mixed(with: fg, 0.08), hairAlpha: 0.065, hair2Alpha: 0.13, hoverAlpha: 0.055)
    }()
    static let light = InkRGB(bg: RGB(hex: "#FBFAF6"), bg1: RGB(hex: "#F5F3ED"), bg2: RGB(hex: "#ECE9E1"), bg3: RGB(hex: "#DFDBD1"), pop: RGB(hex: "#FFFFFF"),
                              fg: RGB(hex: "#1B1A20"), fg2: RGB(hex: "#5C5A65"), fg3: RGB(hex: "#918E99"), live: RGB(hex: "#E5342A"),
                              thumb: RGB(hex: "#FFFFFF"), hairAlpha: 0.075, hair2Alpha: 0.15, hoverAlpha: 0.05)
    static func of(_ dark: Bool) -> InkRGB { dark ? .dark : .light }
    /// What `--cc` darkens toward on Paper.
    static let paperShade = RGB(hex: "#15151A")
    /// A calendar with no colour.
    static let neutralHex = "#888888"
}

/// Calendr v4 tokens. Dark first.
enum Theme {
    static let bg = Color.ink(\.bg)
    static let bg1 = Color.ink(\.bg1)
    /// Fields and raised controls.
    static let bg2 = Color.ink(\.bg2)
    static let bg3 = Color.ink(\.bg3)
    /// Menus, popovers and dialogs.
    static let pop = Color.ink(\.pop)
    static let fg = Color.ink(\.fg)
    static let fg2 = Color.ink(\.fg2)
    static let fg3 = Color.ink(\.fg3)
    static let hair = Color.ink(\.fg, InkRGB.dark.hairAlpha, InkRGB.light.hairAlpha)
    static let hair2 = Color.ink(\.fg, InkRGB.dark.hair2Alpha, InkRGB.light.hair2Alpha)
    static let hover = Color.ink(\.fg, InkRGB.dark.hoverAlpha, InkRGB.light.hoverAlpha)
    static let scrim = Color.dyn(Color.black.opacity(0.6), InkRGB.light.fg.color.opacity(0.22))
    static let live = Color.ink(\.live)
    /// The selected segment of a `Segmented` (`--thumb`).
    static let thumb = Color.ink(\.thumb)
    /// The tick on a filled calendar checkbox: always dark.
    static let tick = Color.dyn(InkRGB.dark.bg.color, InkRGB.paperShade.color)

    // Accent: none, ink only. Selection and today are inverted ink.
    static let act = fg
    static let onAct = bg
    static let actWash = Color.ink(\.fg, 0.09, 0.09)
    /// Hover of a filled `act` control: act 88 percent over the window colour.
    static let actHover = Color.dyn(InkRGB.dark.fg.mixed(with: InkRGB.dark.bg, 0.12).color, InkRGB.light.fg.mixed(with: InkRGB.light.bg, 0.12).color)
    static let ring = Color.ink(\.fg, 0.82, 0.82)
    static let focus = Color.ink(\.fg, 0.46, 0.46)

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
    static let hourGutter: CGFloat = 58
    static let toolbarHeight: CGFloat = 60
    static let dayHeaderHeight: CGFloat = 38
    static let inset: CGFloat = 16
    /// List rows, menu rows, small buttons, sidebar rows.
    static let row: CGFloat = 28
    /// Panel rows, buttons, fields, search.
    static let field: CGFloat = 32
    /// Panel and header icon buttons (16 pt glyph).
    static let iconButton: CGFloat = 26
    static let iconGlyph: CGFloat = 16
    /// Sidebar and row icon buttons (14 pt glyph).
    static let iconButtonSmall: CGFloat = 22
    static let iconGlyphSmall: CGFloat = 14
    /// One `Segmented` segment.
    static let segment: CGFloat = 22
}

/// Spacing scale: 4 · 8 · 12 · 16 · 24.
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}

/// Corners: 6 rows, events, icon buttons, segments · 8 buttons, fields, segmented controls · 12 menus, dialogs, cards.
/// The small fixed shapes (calendar bars, checkboxes, swatches) have their own names so no view writes a number.
enum Radius {
    static let row: CGFloat = 6
    static let event: CGFloat = 6
    static let control: CGFloat = 8
    static let card: CGFloat = 12
    static let surface: CGFloat = 12
    /// The 3 pt calendar colour bar.
    static let bar: CGFloat = 1.5
    /// Rules and the now line.
    static let rule: CGFloat = 1
    /// Calendar checkboxes.
    static let check: CGFloat = 4
    /// The teammate swatch.
    static let swatch: CGFloat = 3
    /// The native menu bar menu (`NSMenu` look) and its rows.
    static let nativeMenu: CGFloat = 10
    static let nativeRow: CGFloat = 5
}

/// Shadows only exist on surfaces above the window.
extension View {
    func popShadow() -> some View { shadow(color: Color.dyn(Color.black.opacity(0.6), Theme.shadowTint.opacity(0.20)), radius: 30, y: 22) }
    func liftShadow() -> some View { shadow(color: Color.dyn(Color.black.opacity(0.45), Theme.shadowTint.opacity(0.16)), radius: 11, y: 8) }
}

extension Theme {
    /// The warm shadow colour on Paper.
    static let shadowTint = Color(hex: "#282214")
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
    /// The walkthrough recorder stretches every animation by this factor so slow offscreen captures still sample it at 60 fps;
    /// it maps the frames back to real time, so the video plays at true speed.
    static var timeScale = 1.0

    static func curve(_ d: Double) -> Animation? { reduced ? nil : Animation.timingCurve(0.22, 0.61, 0.36, 1, duration: d * timeScale) }
    static var fast: Animation? { curve(0.12) }
    static var base: Animation? { curve(0.18) }
    static var slow: Animation? { curve(0.26) }
    static var sheet: Animation? { curve(0.30) }
    static var spring: Animation? { reduced ? nil : .spring(response: 0.3 * timeScale, dampingFraction: 0.7) }
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
    static func bg(_ dark: Bool) -> RGB { InkRGB.of(dark).bg }
    static func fg(_ dark: Bool) -> RGB { InkRGB.of(dark).fg }
    static func fg2(_ dark: Bool) -> RGB { InkRGB.of(dark).fg2 }
    /// `--cc`: the calendar colour as drawn. Paper darkens it 22 percent toward `InkRGB.paperShade`.
    static func cc(_ hex: String, dark: Bool) -> RGB { dark ? RGB(hex: hex) : RGB(hex: hex).mixed(with: InkRGB.paperShade, 0.22) }

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

/// Section label: sentence case, small (11.5), fg3.
struct MicroLabel: View {
    let text: String
    var color: Color = Theme.fg3
    var body: some View { Text(Self.sentence(text)).font(.small).foregroundStyle(color) }
    /// "SIDE PROJECT" or "side project" -> "Side project".
    static func sentence(_ s: String) -> String {
        let l = s.lowercased()
        return l.prefix(1).uppercased() + l.dropFirst()
    }
}
