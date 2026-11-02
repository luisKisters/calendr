import Testing
import Foundation
import AppKit
import SwiftUI
@testable import Calendr

/// The v4 design tokens: one colour table that matches the mockup, used by SwiftUI and CoreGraphics alike, and one segmented control.
@MainActor
@Suite("v4 design tokens")
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

    @Test func darkTableIsTheMockupOledPalette() throws {
        let html = try String(contentsOf: Self.root.appendingPathComponent("design/mockup-v4/index.html"), encoding: .utf8)
        let line = try #require(html.split(separator: "\n").first { $0.contains("['oled',") })
        let hexes = line.matches(of: #/'(#[0-9A-Fa-f]{6})'/#).map { String($0.output.1) }
        // bg, bg1, bg2, bg3, pop, fg, fg2, fg3
        try #require(hexes.count == 8)
        let d = InkRGB.dark
        let ours = [d.bg, d.bg1, d.bg2, d.bg3, d.pop, d.fg, d.fg2, d.fg3]
        for (hex, rgb) in zip(hexes, ours) { #expect(RGB(hex: hex) == rgb, "\(hex)") }
        #expect(d.bg == RGB(0, 0, 0))
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
        #expect(Self.close(Self.rgb(Theme.bg, dark: true), RGB(0, 0, 0)))
        // Light stays Paper (Q4).
        #expect(InkRGB.light.bg == RGB(hex: "#FBFAF6"))
    }

    @Test func metricsAreTheDesignSystemScale() {
        #expect(Dim.row == 28 && Dim.field == 32 && Dim.iconButton == 26 && Dim.iconButtonSmall == 22 && Dim.hourGutter == 58)
        #expect(Radius.row == 6 && Radius.control == 8 && Radius.surface == 12)
        #expect([Space.xs, Space.s, Space.m, Space.l, Space.xl] == [4, 8, 12, 16, 24])
        #expect(TypeSize.title == 18 && TypeSize.text == 12.5 && TypeSize.small == 11.5 && TypeSize.event == 11.5)
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
