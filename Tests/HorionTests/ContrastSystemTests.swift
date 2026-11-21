import Testing
@testable import Horion

/// The colour system of mockup-v16 round 3: states are fitted to contrast on their surface, and text stays readable on them.
@Suite("Colour system")
struct ContrastSystemTests {
    @Test(arguments: [true, false]) func statesAreFittedOnTheirSurface(dark: Bool) {
        let t = InkRGB.of(dark), b = dark ? InkRGB.darkBase : InkRGB.lightBase
        let sel = Contrast.ratio(b.rail, t.selected), hover = min(Contrast.hover, sel.squareRoot())
        #expect(sel <= Contrast.selected + 0.03 && sel > 1.1)
        // Every surface gets the same hover step.
        for (surface, state) in [(b.bg, t.hover), (b.rail, t.hoverRail), (b.bg2, t.raisedHover), (b.pop, t.popHover), (t.selected, t.selectedHover)] {
            #expect(abs(Contrast.ratio(surface, state) - hover) < 0.03, "hover \(state.c8.hex) on \(surface.c8.hex)")
        }
        #expect(Contrast.ratio(b.bg1, t.segRing) >= Contrast.edge)
        // States are neutral greys.
        for c in [t.hover, t.hoverRail, t.selected, t.selectedHover, t.segRing, t.todayTint] { #expect(c.r == c.g && c.g == c.b) }
    }

    @Test(arguments: [true, false]) func textPassesItsFloorsOnEveryStateFill(dark: Bool) {
        let t = InkRGB.of(dark), f = Contrast.textFloors(dark: dark)
        for fill in [t.hover, t.hoverRail, t.selected, t.raisedHover, t.popHover] {
            for (i, text) in [t.fg, t.fg2, t.fg3].enumerated() { #expect(ColorMath.ok(text.c8, fill.c8, f[i]), "text \(i + 1) on \(fill.c8.hex)") }
        }
    }

    /// Dark: the mini month's week band is clearly visible on the sidebar (it was 1.08:1).
    @Test func darkBandIsVisible() { #expect(Contrast.ratio(InkRGB.dark.rail, InkRGB.dark.selected) >= 1.35) }
}
