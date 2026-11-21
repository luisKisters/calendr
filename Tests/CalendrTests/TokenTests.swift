import Testing
import Foundation
import AppKit
import SwiftUI
@testable import Calendr

/// The design tokens (v5: the locked v11 design): one colour table that matches the mockup, used by SwiftUI and CoreGraphics alike, and one segmented control.
@MainActor
@Suite("design tokens")
struct TokenTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// The sRGB components of a SwiftUI colour in an appearance.
    static func rgb(_ c: Color, dark: Bool) -> RGB {
        var out = RGB(0, 0, 0)
        NSAppearance(named: dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance {
            let n = NSColor(c).usingColorSpace(.sRGB)!
            out = RGB(Double(n.redComponent), Double(n.greenComponent), Double(n.blueComponent))
        }
        return out
    }

    static func close(_ a: RGB, _ b: RGB) -> Bool { abs(a.r - b.r) < 0.002 && abs(a.g - b.g) < 0.002 && abs(a.b - b.b) < 0.002 }

    @Test func darkTableIsTheLockedV11Palette() {
        // design/design-system/foundations.md "Colours" (PaletteV5Tests checks every token against the mockup's own output).
        let d = InkRGB.dark
        #expect(d.bg == RGB(hex: "#0B0B0C") && d.rail == RGB(hex: "#070708") && d.bg1 == RGB(hex: "#151516") && d.bg2 == RGB(hex: "#1D1D1E"))
        #expect(d.fg == RGB(hex: "#EBEBED") && d.fg2 == RGB(hex: "#CCCCCE") && d.fg3 == RGB(hex: "#A8A8AA") && d.live == RGB(hex: "#FF6B5F"))
    }

    @Test func canvasInkAndPalettesShareTheThemeColours() {
        for dark in [true, false] {
            let ink = EventPainter.Ink.of(dark)
            let theme = Self.rgb(Theme.bg, dark: dark)
            let cg = ink.bg.components!
            #expect(Self.close(RGB(Double(cg[0]), Double(cg[1]), Double(cg[2])), theme))
            #expect(Self.close(Self.rgb(Theme.fg, dark: dark), InkRGB.of(dark).fg))
            #expect(Self.close(Self.rgb(Theme.pop, dark: dark), InkRGB.of(dark).pop))
            #expect(Palettes.bg(dark) == InkRGB.of(dark).bg && Palettes.fg(dark) == InkRGB.of(dark).fg)
        }
        #expect(Self.close(Self.rgb(Theme.bg, dark: true), RGB(hex: "#0B0B0C")))
        #expect(Self.close(Self.rgb(Theme.rail, dark: false), RGB(hex: "#F4F4F5")))
        // Paper is neutral now (no warm cast).
        #expect(InkRGB.light.bg == RGB(hex: "#FBFBFB"))
    }

    @Test func metricsAreTheDesignSystemScale() {
        #expect(Dim.row == 28 && Dim.field == 32 && Dim.iconButton == 26 && Dim.iconButtonSmall == 22 && Dim.hourGutter == 56)
        #expect(Radius.small == 4 && Radius.row == 8 && Radius.control == 8 && Radius.surface == 12)
        // v5 I chrome (mockup-v11 computed CSS): header 48, day header 32, sidebar 236 / right column 320, sidebar rows 26 and
        // group headers 24, names at 38, mini-month cells 24 on a 26 pitch, right-column rows 26 with a 36 pt time column.
        #expect(Dim.toolbarHeight == 48 && ChromeDim.headerHeight == 48 && Dim.dayHeaderHeight == 32 && DayHeaderView.height == 32)
        #expect(Dim.sidebarWidth == 236 && PanelMetrics.width == 320 && ChromeDim.headerLeading == 20 && ChromeDim.headerTrailing == 12)
        #expect(SidebarDim.row == 26 && SidebarDim.groupRow == 24 && SidebarDim.glyph == 16 && SidebarDim.text == 38)
        #expect(MiniMonth.cell == 24 && MiniMonth.pitch == 26 && MiniMonth.weekColumn == 20 && MiniMonth.height(rows: 6) == 200)
        #expect(ColumnDim.row == 26 && ColumnDim.timeColumn == 36 && ColumnDim.box == 12 && ColumnDim.content == 20 && ColumnDim.searchRow == 44)
        #expect(DayHeaderView.textInset == 8 && DayHeaderView.todayPill(x: 0, numeralWidth: 7.3, height: 32) == CGRect(x: 0, y: 7, width: 20, height: 18))
        #expect(AllDayView.labelInset == 8 && AllDayView.labelTop == 4 && AllDayView.labelLine == 20)
        #expect([Space.xs, Space.s, Space.m, Space.l, Space.xl] == [4, 8, 12, 16, 24])
        // The locked "three" scale: 15 / 12 / 11.
        #expect(TypeSize.title == 15 && TypeSize.text == 12 && TypeSize.small == 11 && TypeSize.event == 12)
        #expect(Set([TypeSize.title, TypeSize.text, TypeSize.small, TypeSize.event]) == [15, 12, 11])
        #expect(TypeSize.titleLine == 21 && TypeSize.textLine == 18 && TypeSize.eventLine == 15.5 && TypeSize.smallLine == 14)
    }

    /// The chrome's raised buttons and the sidebar wash, as solid mixes of the mockup's rgba edges over their surface.
    @Test func chromeButtonColoursAreTheMockupsComputedMixes() {
        // Dark: rgba(255,255,255,.09) on raised #1D1D1E; Paper: rgba(20,20,30,.12) on the rail, rgba(60,50,35,.16) on white.
        #expect(Self.close(InkRGB.joinEdgeDark, InkRGB.dark.bg2.mixed(with: RGB(1, 1, 1), 0.09)))
        #expect(Self.close(InkRGB.joinEdgeLight, InkRGB.light.rail.mixed(with: RGB(hex: "#14141E"), 0.12)))
        #expect(Self.close(Self.rgb(Theme.joinEdge, dark: true), InkRGB.joinEdgeDark))
        #expect(InkRGB.joinEdgeLight == RGB(hex: "#D9D9DB") && InkRGB.buttonEdgeLight == RGB(hex: "#E0DEDC"))
        #expect(Self.close(Self.rgb(Theme.buttonHover, dark: true), InkRGB.dark.bg2.mixed(with: InkRGB.dark.fg, 0.06)))
        #expect(Self.close(Self.rgb(Theme.searchEdge, dark: false), InkRGB.light.hairStrong))
    }

    @Test func thereIsOnlyOneSegmentedControl() throws {
        let views = Self.root.appendingPathComponent("Sources/Calendr/Views")
        var hits: [String] = []
        for f in try FileManager.default.contentsOfDirectory(atPath: views.path) where f.hasSuffix(".swift") {
            let src = try String(contentsOf: views.appendingPathComponent(f), encoding: .utf8)
            for m in src.matches(of: #/struct (\w*(?:Segmented|RSVP)\w*)/#) { hits.append("\(f): \(m.output.1)") }
            #expect(!src.contains("panelThumb"), "\(f) keeps its own thumb colour")
        }
        #expect(hits == ["Components.swift: Segmented"], "\(hits)")
    }

    @Test func microLabelIsSentenceCase() {
        #expect(MicroLabel.sentence("SIDE PROJECT") == "Side project")
        #expect(MicroLabel.sentence("work") == "Work")
    }
}
