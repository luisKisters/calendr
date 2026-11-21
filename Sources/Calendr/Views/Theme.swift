import SwiftUI
import AppKit

// Values come from the locked v11 design (design/design-system/, mockup-v11 look R, preset R10 · Mine, round h 2026-11-20):
// Dark is locked, Paper is derived from the Dark rules (event colours "Clear tint"). Tests/CalendrTests/PaletteV5Tests.swift compares
// every value here with the mockup's own output (scripts/v5-tokens.js).

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

/// The one colour table. `Theme` (SwiftUI), `EventPainter.Ink` (CoreGraphics) and `Palettes` (event colours) all derive from it.
/// Neutral greys with no hue cast; lines and washes are solid mixes of `bg` toward `fg` (no alpha), as in the mockup.
struct InkRGB: Equatable {
    /// bg: canvas, grid, header · rail: sidebar and right column · bg1 (`surface`): cards, all-day lane, segmented track ·
    /// bg2 (`raised`): fields, buttons · bg3: knobs, pills, "+N" · pop: menus and dialogs.
    let bg, rail, bg1, bg2, bg3, pop: RGB
    /// Text levels: fg (fg1) titles and values · fg2 times, secondary rows · fg3 labels, hints, group headers, icons · fg4 disabled only.
    let fg, fg2, fg3, fg4: RGB
    /// Hour labels (`hourc`, = fg2).
    let hourLabel: RGB
    /// Row hover on bg and on the rail, selected row.
    let hover, hoverRail, selected: RGB
    /// Lines: `grid` hour line (≥ 1.15:1), `gridV` day divider, `hairStrong` all-day edge, `hair` pane edge. No half-hour line.
    let grid, gridV, hairStrong, hair: RGB
    /// The today column (bg → fg 3.5 %).
    let todayTint: RGB
    /// Red, only for now; `onLive` is the text of the now pill.
    let live, onLive: RGB
    /// The 2 px focus ring.
    let focus: RGB
    /// Status text.
    let ok, warn, danger: RGB
    /// The selected segment of a `Segmented` and its edge.
    let thumb, segRing: RGB

    static let dark = InkRGB(
        bg: RGB(hex: "#0B0B0C"), rail: RGB(hex: "#070708"), bg1: RGB(hex: "#151516"), bg2: RGB(hex: "#1D1D1E"), bg3: RGB(hex: "#2A2A2C"), pop: RGB(hex: "#0B0B0C"),
        fg: RGB(hex: "#EBEBED"), fg2: RGB(hex: "#CCCCCE"), fg3: RGB(hex: "#A8A8AA"), fg4: RGB(hex: "#4E4E50"), hourLabel: RGB(hex: "#CCCCCE"),
        hover: RGB(hex: "#161617"), hoverRail: RGB(hex: "#121213"), selected: RGB(hex: "#1E1E1F"),
        grid: RGB(hex: "#212123"), gridV: RGB(hex: "#1B1B1C"), hairStrong: RGB(hex: "#2A2A2C"), hair: RGB(hex: "#1C1C1D"), todayTint: RGB(hex: "#131314"),
        live: RGB(hex: "#FF6B5F"), onLive: RGB(hex: "#0B0B0C"), focus: RGB(hex: "#6E9BF5"),
        ok: RGB(hex: "#6CC58A"), warn: RGB(hex: "#E5B44A"), danger: RGB(hex: "#FF7B72"),
        thumb: RGB(hex: "#1D1D1E"), segRing: RGB(hex: "#6B6B6C"))
    static let light = InkRGB(
        bg: RGB(hex: "#FBFBFB"), rail: RGB(hex: "#F4F4F5"), bg1: RGB(hex: "#F1F1F2"), bg2: RGB(hex: "#FFFFFF"), bg3: RGB(hex: "#DCDCDC"), pop: RGB(hex: "#FBFBFB"),
        fg: RGB(hex: "#1D1D20"), fg2: RGB(hex: "#4A4A50"), fg3: RGB(hex: "#606067"), fg4: RGB(hex: "#B8B8B9"), hourLabel: RGB(hex: "#4A4A50"),
        hover: RGB(hex: "#F1F1F1"), hoverRail: RGB(hex: "#EAEAEB"), selected: RGB(hex: "#EAEAEB"),
        grid: RGB(hex: "#E1E1E2"), gridV: RGB(hex: "#EBEBEC"), hairStrong: RGB(hex: "#DCDCDC"), hair: RGB(hex: "#E8E8E8"), todayTint: RGB(hex: "#F3F3F3"),
        live: RGB(hex: "#C9372C"), onLive: RGB(hex: "#FFFFFF"), focus: RGB(hex: "#2F6BDC"),
        ok: RGB(hex: "#2F7A4B"), warn: RGB(hex: "#8A5A00"), danger: RGB(hex: "#B4382D"),
        thumb: RGB(hex: "#FFFFFF"), segRing: RGB(hex: "#878789"))
    static func of(_ dark: Bool) -> InkRGB { dark ? .dark : .light }
    static let black = RGB(0, 0, 0)
    /// The neutral shadow on Paper (`rgba(20, 20, 30, …)` in the mockup's `--shadow-pop`).
    static let paperShadow = RGB(hex: "#14141E")
    /// The warm shadow of a selected segment in Paper (`0 1px 2px rgba(60,50,35,.10)`).
    static let segShadow = RGB(hex: "#3C3223")
    /// Chrome buttons on `raised` (v11 looks.css): the Join button's edge, Dark `inset 0 0 0 1px rgba(255,255,255,.09)` on raised,
    /// Paper `0 0 0 1px rgba(20,20,30,.12)` on the rail; the Today button's edge, none in Dark, Paper `inset 0 0 0 1px
    /// rgba(60,50,35,.16)` on white. Solid mixes over the surface they sit on.
    static let joinEdgeDark = RGB(hex: "#313132"), joinEdgeLight = RGB(hex: "#D9D9DB")
    static let buttonEdgeLight = RGB(hex: "#E0DEDC")
    /// A calendar with no colour.
    static let neutralHex = "#888888"
    /// The dark greys the Paper / Dark event recipe starts dark text from when a fill is light (readability.js `recipe`).
    static let recipeInk = C8(hex: "#3A3A40"), recipeInkSoft = C8(hex: "#55555C")
}

/// Calendr v5 tokens. Dark first.
enum Theme {
    static let bg = Color.ink(\.bg)
    /// Sidebar and right column.
    static let rail = Color.ink(\.rail)
    static let bg1 = Color.ink(\.bg1)
    /// Fields and raised controls.
    static let bg2 = Color.ink(\.bg2)
    static let bg3 = Color.ink(\.bg3)
    /// Menus, popovers and dialogs.
    static let pop = Color.ink(\.pop)
    static let fg = Color.ink(\.fg)
    static let fg2 = Color.ink(\.fg2)
    static let fg3 = Color.ink(\.fg3)
    /// Disabled only.
    static let fg4 = Color.ink(\.fg4)
    static let hourLabel = Color.ink(\.hourLabel)
    /// Pane edge (decoration, ≤ Lc 15).
    static let hair = Color.ink(\.hair)
    /// All-day edge, structural rules (≥ 1.15:1).
    static let hair2 = Color.ink(\.hairStrong)
    static let hourLine = Color.ink(\.grid)
    static let dayDivider = Color.ink(\.gridV)
    static let todayTint = Color.ink(\.todayTint)
    static let hover = Color.ink(\.hover)
    static let hoverRail = Color.ink(\.hoverRail)
    static let selected = Color.ink(\.selected)
    /// Row hover and the keyboard's row on a floating surface (menus, the command menu, dialogs, toasts): fg1 6 % over `pop`
    /// (app.css `.pop, .modal, .toast { --hover: color-mix(fg1 6 %, raised) }`). `hover` is mixed over the canvas and would sit
    /// darker than the menu.
    static let hoverPop = Color.dyn(InkRGB.dark.pop.mixed(with: InkRGB.dark.fg, 0.06).color, InkRGB.light.pop.mixed(with: InkRGB.light.fg, 0.06).color)
    /// A settings group (`.sbox`): fg1 3.5 % over `pop`.
    static let groupBox = Color.dyn(InkRGB.dark.pop.mixed(with: InkRGB.dark.fg, 0.035).color, InkRGB.light.pop.mixed(with: InkRGB.light.fg, 0.035).color)
    static let scrim = Color.ink(\.bg, 0.5, 0.26)
    static let live = Color.ink(\.live)
    static let onLive = Color.ink(\.onLive)
    /// The selected segment of a `Segmented` (`--thumb`) and its edge.
    static let thumb = Color.ink(\.thumb)
    static let segRing = Color.ink(\.segRing)
    /// Edges of the chrome's raised buttons (Join, Today).
    static let joinEdge = Color.dyn(InkRGB.joinEdgeDark.color, InkRGB.joinEdgeLight.color)
    static let buttonEdge = Color.dyn(.clear, InkRGB.buttonEdgeLight.color)
    /// The right column's search field edge: none in Dark, hair2 in Paper (`.srch label`).
    static let searchEdge = Color.dyn(.clear, InkRGB.light.hairStrong.color)
    /// The sidebar eye under the pointer (`.cal .eye:hover`: fg1 8 % over the row's rail hover).
    static let eyeHover = Color.dyn(InkRGB.dark.hoverRail.mixed(with: InkRGB.dark.fg, 0.08).color, InkRGB.light.hoverRail.mixed(with: InkRGB.light.fg, 0.08).color)
    /// Hover of a `raised` chrome button: fg1 mixed in by 6 % (Today) or 5 % (Join).
    static let buttonHover = Color.dyn(InkRGB.dark.bg2.mixed(with: InkRGB.dark.fg, 0.06).color, InkRGB.light.bg2.mixed(with: InkRGB.light.fg, 0.06).color)
    static let joinHover = Color.dyn(InkRGB.dark.bg2.mixed(with: InkRGB.dark.fg, 0.05).color, InkRGB.light.bg2.mixed(with: InkRGB.light.fg, 0.05).color)
    /// A calendar colour as a dot, square or swatch (`calDot`, the recipe's mark), in both appearances. Every place that shows a
    /// calendar's colour outside an event block uses this or `calendarBar`, never the raw hex.
    static func calendarMark(_ hex: String) -> Color { Color.dyn(Palettes.cc(hex, dark: true).color, Palettes.cc(hex, dark: false).color) }
    /// A calendar colour as a 3 pt bar (list rows, the command menu, the menu bar), the bar of the event recipe.
    static func calendarBar(_ hex: String) -> Color { Color.dyn(Palettes.barColor(hex, dark: true).color, Palettes.barColor(hex, dark: false).color) }
    /// The tick on a filled calendar checkbox.
    static let tick = fg

    // Accent: none, ink only. Today's date and primary buttons are inverted ink (`accent` = fg1, `onAccent` = bg).
    static let act = fg
    static let onAct = bg
    static let actWash = Color.ink(\.fg, 0.09, 0.09)
    /// Hover of a filled `act` control: act 88 percent over the window colour.
    static let actHover = Color.dyn(InkRGB.dark.fg.mixed(with: InkRGB.dark.bg, 0.12).color, InkRGB.light.fg.mixed(with: InkRGB.light.bg, 0.12).color)
    static let ring = Color.ink(\.fg, 0.82, 0.82)
    /// The 2 px focus ring.
    static let focus = Color.ink(\.focus)

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
    /// Window header (`.hdr`) and day header (`.dh`), v11: 48 and 32.
    static let toolbarHeight: CGFloat = 48
    static let dayHeaderHeight: CGFloat = 32
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

/// Event block shape (v11 locked: bar + tint). The bar is flush with the block's left edge, full height, and the block's
/// corners clip it. 3.5 pt in Dark and in Paper: DECISIONS.md names a 4 px Paper bar, but the locked link sets `bw3.5`, which
/// overrides the Paper default (readability.js `!has(K, 'bw')`), so the mockup draws 3.5 in both; the mockup wins.
enum EventShape {
    static func bar(dark: Bool) -> CGFloat { 3.5 }
    /// The hatch of a maybe block: 135 degree bands, 5 pt of the hover fill, 5 pt of the fill.
    static let hatch: CGFloat = 5
}

/// Spacing scale: 4 · 8 · 12 · 16 · 24.
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}

/// Corners: one scale, three steps (v13 "Round" minus 1 pt). 5 for events, all-day chips and the today numbers · 9 for
/// everything you click in a list or a form (rows, buttons, fields, tiles, segmented tracks) · 13 for surfaces (menus, dialogs, the
/// toast, cards, settings groups). A shape nested inside another with padding p uses the outer radius minus p: a segment in its 2 pt
/// track and a row in a menu's 6 pt padding are both 7 (`inner`). Marks of 10 to 16 pt (calendar squares, checkboxes, swatches, the
/// now pill, the "+N" chip) stay at 4 (`mark`) so they never turn into circles. The 3 pt colour bars are rounded to half their
/// width (`bar`). The switch track is the one pill.
enum Radius {
    static let small: CGFloat = 5
    static let control: CGFloat = 9
    static let surface: CGFloat = 13
    /// A segment inside its 2 pt padded track; a row inside a menu's 6 pt padding.
    static let inner: CGFloat = control - 2
    /// Squares and labels 10 to 16 pt high: 4, so they stay squares, not circles.
    static let mark: CGFloat = 4
    static let row: CGFloat = control
    static let event: CGFloat = small
    static let card: CGFloat = surface
    /// The 3 pt calendar colour bar.
    static let bar: CGFloat = 1.5
    static let nowPill: CGFloat = mark
    /// Rules and the now line.
    static let rule: CGFloat = 1
    static let check: CGFloat = mark
    static let swatch: CGFloat = mark
    static let leadBar: CGFloat = bar
}

/// Shadows only exist on surfaces above the window.
extension View {
    func popShadow() -> some View { shadow(color: Color.dyn(InkRGB.black.color.opacity(0.55), InkRGB.paperShadow.color.opacity(0.10)), radius: 24, y: 12) }
    func liftShadow() -> some View { shadow(color: Color.dyn(InkRGB.black.color.opacity(0.45), InkRGB.paperShadow.color.opacity(0.10)), radius: 11, y: 8) }
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
    /// The nearest 8-bit colour (for the mockup's colour math).
    var c8: C8 { C8(Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded())) }
}

/// Colours of an event block: the v11 recipe "bar + tint" (design/design-system/foundations.md, readability.js `recipe` (Dark) and
/// `recipeP` (Paper, "Clear tint")). The calendar colour goes in as an OKLCH hue H with its own chroma C₀ as the upper limit;
/// every text colour is fitted to its fills (never dimmed with opacity). `EventPalette.colors(reply:past:)` picks one reply state.
/// Both SwiftUI and CoreGraphics forms are kept because the grid paints events with CoreGraphics.
struct EventPalette: Equatable {
    /// Normal: fill, hover fill, selected fill, the 3.5 px bar, title, time; selected title and time.
    var barRGB: RGB, fillRGB: RGB, hoverFillRGB: RGB, selFillRGB: RGB, titleRGB: RGB, timeRGB: RGB, selTitleRGB: RGB, selTimeRGB: RGB
    /// Past: fill → bg, bar, title, time.
    var pastFillRGB: RGB, pastBarRGB: RGB, pastTitleRGB: RGB, pastTimeRGB: RGB
    /// Declined: fill → bg, title (struck).
    var declFillRGB: RGB, declTitleRGB: RGB
    /// The 1 px outline of an invitation without an answer (and the next-event ring), ≥ 3:1 on bg.
    var edgeRGB: RGB
    /// The calendar dot: sidebar checkboxes, swatches.
    var markRGB: RGB
    var bgRGB: RGB
    /// fg1 / fg2 of the appearance: the title and time of an invitation without an answer (`.ev.st-none`).
    var fgRGB: RGB = InkRGB.dark.fg, fg2RGB: RGB = InkRGB.dark.fg2
    var bar: Color { barRGB.color }
    var fill: Color { fillRGB.color }
    var title: Color { titleRGB.color }
    var time: Color { timeRGB.color }
}

enum Palettes {
    nonisolated(unsafe) private static var cache: [String: EventPalette] = [:]
    private static let lock = NSLock()
    static func bg(_ dark: Bool) -> RGB { InkRGB.of(dark).bg }
    static func fg(_ dark: Bool) -> RGB { InkRGB.of(dark).fg }
    static func fg2(_ dark: Bool) -> RGB { InkRGB.of(dark).fg2 }
    /// The calendar colour as a dot or swatch (the mockup's `calDot`).
    static func cc(_ hex: String, dark: Bool) -> RGB { palette(barHex: hex, fillHex: nil, dark: dark).markRGB }
    /// The calendar colour as a bar (right column rows, the editor).
    static func barColor(_ hex: String, dark: Bool) -> RGB { palette(barHex: hex, fillHex: nil, dark: dark).barRGB }

    /// `barHex` is the calendar colour, `fillHex` the event's own colour, which replaces it (mockup `colorOf`: `e.color || cal.hex`).
    static func palette(barHex: String, fillHex: String?, dark: Bool) -> EventPalette {
        let hex = (fillHex ?? barHex).uppercased()
        let key = hex + (dark ? "|d" : "|l")
        lock.lock(); defer { lock.unlock() }
        if let c = cache[key] { return c }
        let src = C8(hex: hex)
        let out = dark ? EventRecipe.dark(src).palette(ink: InkRGB.dark) : EventRecipe.paper(src).palette(ink: InkRGB.light)
        if cache.count > 2000 { cache.removeAll() }
        cache[key] = out
        return out
    }
}

/// The locked event recipe in 8-bit colours, exactly as the mockup computes it (look R, preset R10 · Mine:
/// `r=112213000220110111`, `k=…ec.074el.29bc.25bl.7bw3.5tl1ml.89mc.062cl.15`; Paper option 0 "Clear tint").
struct EventRecipe: Equatable {
    var fill, fillH, fillSel, bar, title, titleSel, meta, metaSel, fillPast, titlePast, metaPast, barPast, fillDec, titleDec, edge, mark: C8

    func palette(ink: InkRGB) -> EventPalette {
        var p = palette(bg: ink.bg)
        p.fgRGB = ink.fg; p.fg2RGB = ink.fg2
        return p
    }

    func palette(bg: RGB) -> EventPalette {
        EventPalette(barRGB: bar.rgb, fillRGB: fill.rgb, hoverFillRGB: fillH.rgb, selFillRGB: fillSel.rgb, titleRGB: title.rgb, timeRGB: meta.rgb,
                     selTitleRGB: titleSel.rgb, selTimeRGB: metaSel.rgb, pastFillRGB: fillPast.rgb, pastBarRGB: barPast.rgb,
                     pastTitleRGB: titlePast.rgb, pastTimeRGB: metaPast.rgb, declFillRGB: fillDec.rgb, declTitleRGB: titleDec.rgb,
                     edgeRGB: edge.rgb, markRGB: mark.rgb, bgRGB: bg)
    }

    typealias M = ColorMath
    private static func C3(_ L: Double, _ C: Double, _ H: Double) -> C8 { M.fromOklch(L, C, H) }
    private static func yellow(_ H: Double) -> Bool { let d = M.deg(H); return d > 60 && d < 118 }
    /// Text goes toward white on dark fills and toward black on light ones (the better of the two).
    private static func dir(_ b: C8) -> C8 { M.wcag(.white, b) >= M.wcag(.black, b) ? .white : .black }

    // Event text floors (readability.js FLOORS / design targets): [WCAG ratio, APCA |Lc|].
    static let darkTitle: M.Floor = (7, 75), darkTime: M.Floor = (6.55, 60.6), darkSelTime: M.Floor = (5.5, 58)
    static let darkPastTitle: M.Floor = (9, 72), darkPastTime: M.Floor = (5.7, 58), darkDeclined: M.Floor = (6, 55)
    static let paperTitle: M.Floor = (7.4, 78), paperTime: M.Floor = (6.1, 71), paperSelTime: M.Floor = (5.7, 66)
    static let paperPastTitle: M.Floor = (8, 78), paperPastTime: M.Floor = (5.4, 68), paperDeclined: M.Floor = (6.8, 76), paperLift: M.Floor = (7.4, 78.5)

    /// Dark (locked): fill oklch(.29, .074 × min(1, C₀/.1), H), bar oklch(.70, min(.25, 2.5 C₀), H), white title, hue-tinted time.
    static func dark(_ hex: C8) -> EventRecipe {
        let t = InkRGB.dark, bg = t.bg.c8, fg2 = t.fg2.c8, fg3 = t.fg3.c8
        let (_, C0, H) = M.oklch(hex)
        let yel = yellow(H), c = 0.08, dl = 0.1                          // chroma lever "Rich" (C .08, ΔL .1)
        func CC(_ x: Double) -> Double { min(C0, x) * (yel ? 0.85 : 1) }
        let Lb = max(M.oklch(bg).L, 0.17), Lf = Lb + dl + (yel ? 0.015 : 0)
        let bar = C3(0.7, min(0.25, C0 * 2.5), H)                         // sliders bl .7, bc .25
        // recipe "Bar + tint", then the fill sliders (el .29, ec .074) move the three fills together
        var fill = C3(Lf - dl * 0.3, CC(c * 0.7), H), fillH = C3(Lf - dl * 0.3 + 0.025, CC(c * 0.8), H), fillSel = C3(Lf + 0.03, CC(c * 1.1), H)
        let f0 = M.oklch(fill), sc = min(1, max(C0, 0.005) / 0.1), Lt = 0.29, Ct = 0.074 * sc
        func re(_ x: C8) -> C8 { let o = M.oklch(x); return C3(max(0, Lt + o.L - f0.L), f0.C > 0.002 ? Ct * o.C / f0.C : Ct, H) }
        fill = re(fill); fillH = re(fillH); fillSel = re(fillSel)
        let to = dir(fill), on = [fill, fillH]
        let title = M.fit(C3(1, 0, H), on, to, darkTitle)                  // slider tl 1: white
        let titleSel = M.fit(title, [fillSel], dir(fillSel), darkTitle)
        var meta = C3(0.89, min(0.062, max(C0, 0.01) * 2), H)            // sliders ml .89, mc .062
        meta = M.fit(M.fit(meta, on, to, darkTime), on, to, darkTime)
        let metaSel = M.fit(M.fit(meta.mix(fillSel, 0.04), [fillSel], title, darkSelTime), [fillSel], dir(fillSel), darkSelTime)
        let fillPast = fill.mix(bg, 0.55), pd = dir(fillPast)
        let titlePast = M.fit(pd == .white ? fg2.mix(title, 0.1) : InkRGB.recipeInk.mix(title, 0.1), [fillPast], pd, darkPastTitle)
        let metaPast = M.fit(pd == .white ? fg3 : InkRGB.recipeInkSoft, [fillPast], pd, darkPastTime)
        let fillDec = fill.mix(bg, 0.5), dd = dir(fillDec)
        let titleDec = M.fit(dd == .white ? fg2 : InkRGB.recipeInk, [fillDec], dd, darkDeclined)
        let mark = C3(0.7 + (yel ? 0.05 : 0), min(C0, 0.14) * (yel ? 0.85 : 1), H)
        let edge = M.fit(C3(0.68 + (yel ? 0.04 : 0), CC(0.12), H), [bg], .white, (3, 0))
        return EventRecipe(fill: fill, fillH: fillH, fillSel: fillSel, bar: bar, title: title, titleSel: titleSel, meta: meta, metaSel: metaSel,
                           fillPast: fillPast, titlePast: titlePast, metaPast: metaPast, barPast: bar.mix(fillPast, 0.55),
                           fillDec: fillDec, titleDec: titleDec, edge: edge, mark: mark)
    }

    /// Paper (derived, "Clear tint"): a light per-hue tint at ΔE_OK ≥ 9 × k from the canvas, a 4 px bar at L .57, fg1 titles.
    static func paper(_ hex: C8) -> EventRecipe {
        let t = InkRGB.light, bg = t.bg.c8, fg1 = t.fg.c8, fg2 = t.fg2.c8, fg3 = t.fg3.c8
        let d = dark(hex)
        let (L0, C0, Hcal) = M.oklch(hex), dfill = M.oklch(d.fill), Hd = dfill.H
        let yel = yellow(Hd), C = min(dfill.C * 1.1, 0.075) * (yel ? 0.9 : 1)
        let Cc = min(C0 < 0.015 ? C0 : max(C0 * 1.25, 0.075), 0.16)
        let off = max(-0.03, min(0.03, (L0 - 0.66) * 0.45)), V = 9 * max(0.85, min(1.25, 1 + (0.66 - L0) * 2.2))
        var k = 0.0, x: C8
        repeat { x = C3(min(0.975, 0.975 - 0.25 * k + off), Cc * (0.12 + 0.62 * k), Hd); k += 0.01 } while k < 1.6 && M.deltaE(x, bg) < V
        let lf = M.oklch(x)
        func lift(_ y0: C8) -> C8 {
            let o = M.oklch(y0)
            var y = y0, l = o.L
            while l < 0.99 && !M.ok(.black, y, paperLift) { l += 0.005; y = C3(l, o.C, Hd) }
            return y
        }
        let fill = lift(x), fillH = lift(C3(lf.L - 0.022, lf.C * 1.08, Hd)), fillSel = lift(C3(lf.L - 0.05, lf.C * 1.22, Hd))
        let db = M.oklch(d.bar)
        let bar = C3(0.57 + (yellow(db.H) ? 0.1 : 0), min(max(C0, db.C) * 1.15, 0.22), db.H)
        let on = [fill, fillH]
        let title = M.fit(fg1, on, .black, paperTitle), titleSel = M.fit(title, [fillSel], .black, paperTitle)
        let meta = M.fit(M.fit(C3(0.45, min(C * 1.2, 0.07), Hd), on, title, paperTime), on, .black, paperTime)
        let metaSel = M.fit(meta.mix(fillSel, 0.04), [fillSel], .black, paperSelTime)
        let fillPast = fill.mix(bg, 0.6)
        let titlePast = M.fit(fg2.mix(title, 0.15), [fillPast], .black, paperPastTitle), metaPast = M.fit(fg3, [fillPast], .black, paperPastTime)
        let fillDec = fill.mix(bg, 0.45), titleDec = M.fit(fg2, [fillDec], .black, paperDeclined)
        let mark = C3(0.6, min(C0, 0.14), Hcal), edge = M.fit(C3(0.56, min(C0, 0.13), Hd), [bg], .black, (3, 0))
        return EventRecipe(fill: fill, fillH: fillH, fillSel: fillSel, bar: bar, title: title, titleSel: titleSel, meta: meta, metaSel: metaSel,
                           fillPast: fillPast, titlePast: titlePast, metaPast: metaPast, barPast: bar.mix(fillPast, 0.5),
                           fillDec: fillDec, titleDec: titleDec, edge: edge, mark: mark)
    }
}

/// Section label (`label`): sentence case, 12 / 500, fg3.
struct MicroLabel: View {
    let text: String
    var color: Color = Theme.fg3
    var body: some View { Text(Self.sentence(text)).font(.label).foregroundStyle(color) }
    /// "SIDE PROJECT" or "side project" -> "Side project".
    static func sentence(_ s: String) -> String {
        let l = s.lowercased()
        return l.prefix(1).uppercased() + l.dropFirst()
    }
}

// MARK: Status and destructive tokens

extension Theme {
    /// Reply marks in the participant list: going, maybe, declined (the status colours ok / warn / danger, ≥ 4.5:1 on bg).
    static let replyYes = Color.ink(\.ok)
    static let replyMaybe = Color.ink(\.warn)
    static let replyNo = Color.ink(\.danger)
    /// Destructive actions: the red split button of the delete dialog, "Discard changes" in a menu.
    static let danger = Color(hex: "#D9645A")
    static let onDanger = Color(hex: "#FFFFFF")
}

// MARK: Hover by surface

/// The hover wash of the surface a control sits on: `hover` on the canvas, `hoverPop` inside menus and dialogs (set by `surface()`).
private struct HoverWashKey: EnvironmentKey { static let defaultValue: Color = Theme.hover }
extension EnvironmentValues {
    var hoverWash: Color {
        get { self[HoverWashKey.self] }
        set { self[HoverWashKey.self] = newValue }
    }
}
