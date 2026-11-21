import Testing
import Foundation
import CoreGraphics
import CalendrKit
@testable import Calendr

/// v5 H: event blocks as the locked v11 mockup draws them. The expected colours are the mockup's computed styles of the demo week
/// (`?demo=1#tab=read&look=R&fs=1`, Dark and `appear=paper`), read with headless Chrome: fill, bar, title and time per state.
@MainActor
@Suite("Event block v11: colours per state and the painted block")
struct EventBlockV11Tests {
    struct Want { var hex: String; var reply: EventReply; var past: Bool; var fill: String; var bar: String; var title: String; var time: String; var outline: String? = nil }

    static let dark: [String: Want] = [
        "Deep work": Want(hex: "#A9A6F5", reply: .accepted, past: false, fill: "#28244E", bar: "#968CFF", title: "#FFFFFF", time: "#D6D6FE"),
        "Deep work (past)": Want(hex: "#A9A6F5", reply: .accepted, past: true, fill: "#18162A", bar: "#514B8A", title: "#D1D1D3", time: "#B1B1B3"),
        "Gym (past)": Want(hex: "#F2884B", reply: .accepted, past: true, fill: "#261408", bar: "#843E05", title: "#D1D1D3", time: "#B1B1B3"),
        "Standup": Want(hex: "#E9B949", reply: .accepted, past: false, fill: "#382901", bar: "#C69608", title: "#FFFFFF", time: "#EED8AC"),
        "Neighbourhood meetup (declined)": Want(hex: "#E5674F", reply: .declined, past: false, fill: "#2A130F", bar: "#88382A", title: "#CCCCCE", time: "#CCCCCE"),
        "Hiring sync (not answered, past)": Want(hex: "#E9B949", reply: .notAnswered, past: true, fill: "#0B0B0C", bar: "#6A5107", title: "#EBEBED", time: "#CCCCCE", outline: "#C2A055"),
        "maybe: founders breakfast": Want(hex: "#5B8DEF", reply: .maybe, past: false, fill: "#162A50", bar: "#689BFF", title: "#FFFFFF", time: "#C9DCFE"),
    ]
    static let paper: [String: Want] = [
        "Deep work": Want(hex: "#A9A6F5", reply: .accepted, past: false, fill: "#E2E2FE", bar: "#715EE0", title: "#1D1D20", time: "#454365"),
        "Deep work (past)": Want(hex: "#A9A6F5", reply: .accepted, past: true, fill: "#F1F1FC", bar: "#B1A8EE", title: "#434349", time: "#606067"),
        "Gym (past)": Want(hex: "#F2884B", reply: .accepted, past: true, fill: "#FCEFE9", bar: "#DCA277", title: "#434349", time: "#606067"),
        "Standup": Want(hex: "#E9B949", reply: .accepted, past: false, fill: "#F6E6C3", bar: "#BB8D01", title: "#1D1D20", time: "#594923"),
        "Neighbourhood meetup (declined)": Want(hex: "#E5674F", reply: .declined, past: false, fill: "#FDE7E2", bar: "#EA8C76", title: "#4A4A50", time: "#4A4A50"),
        "Hiring sync (not answered, past)": Want(hex: "#E9B949", reply: .notAnswered, past: true, fill: "#FBFBFB", bar: "#DAC073", title: "#1D1D20", time: "#4A4A50", outline: "#916F02"),
        "maybe: founders breakfast": Want(hex: "#5B8DEF", reply: .maybe, past: false, fill: "#D1E1FE", bar: "#3970E0", title: "#1D1D20", time: "#33405A"),
    ]
    /// The hatch bands of a maybe block (`fillh`), Dark and Paper.
    static let hatch = (dark: "#1A305B", paper: "#C8DAF9")

    func check(_ wants: [String: Want], dark: Bool) {
        for (name, w) in wants.sorted(by: { $0.key < $1.key }) {
            let c = Palettes.palette(barHex: w.hex, fillHex: nil, dark: dark).colors(reply: w.reply, past: w.past)
            #expect(c.fill.c8 == C8(hex: w.fill), "\(name) fill")
            #expect(c.bar.c8 == C8(hex: w.bar), "\(name) bar")
            #expect(c.title.c8 == C8(hex: w.title), "\(name) title")
            #expect(c.time.c8 == C8(hex: w.time), "\(name) time")
            #expect(c.outline?.c8 == w.outline.map(C8.init(hex:)), "\(name) outline")
            #expect(c.strike == (w.reply == .declined) && c.barAlpha == 1, "\(name): no alpha on bars or text")
        }
    }

    @Test func darkStatesMatchTheMockup() { check(Self.dark, dark: true) }
    @Test func paperStatesMatchTheMockup() { check(Self.paper, dark: false) }

    @Test func theMaybeHatchIsTheHoverFill() {
        #expect(Palettes.palette(barHex: "#5B8DEF", fillHex: nil, dark: true).colors(reply: .maybe, past: false).stripe?.c8 == C8(hex: Self.hatch.dark))
        #expect(Palettes.palette(barHex: "#5B8DEF", fillHex: nil, dark: false).colors(reply: .maybe, past: false).stripe?.c8 == C8(hex: Self.hatch.paper))
        #expect(EventShape.hatch == 5)
    }

    // MARK: The painted block

    /// Paints one block at 1x into a bitmap the size of `r` plus a margin and returns a pixel reader (top-left origin).
    func paint(_ style: EventStyle, size: CGSize = CGSize(width: 113, height: 42), minutes: Int = 60) -> (Int, Int) -> C8 {
        let w = Int(size.width) + 20, h = Int(size.height) + 20
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let cg = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs,
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        cg.translateBy(x: 0, y: CGFloat(h)); cg.scaleBy(x: 1, y: -1)           // top-left origin, as the canvas draws
        cg.setFillColor(InkRGB.of(style.isDark).bg.cg); cg.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let math = DemoDataV4.math
        let day = math.date(year: 2026, month: 11, day: 4)
        let e = CalendarEvent(id: "t", calendarID: "c", title: "Block", start: math.date(on: day, minutes: 600), end: math.date(on: day, minutes: 600 + minutes))
        EventPainter.draw(cg, event: e, start: 600, end: 600 + minutes, rect: CGRect(x: 10, y: 10, width: size.width, height: size.height), style: style,
                          fmt: Fmt(math: math), dayView: false)
        let data = cg.data!.assumingMemoryBound(to: UInt8.self)
        return { x, y in withExtendedLifetime(cg) { let o = (y * w + x) * 4; return C8(Int(data[o]), Int(data[o + 1]), Int(data[o + 2])) } }
    }

    func style(_ hex: String, dark: Bool, reply: EventReply = .accepted, past: Bool = false) -> EventStyle {
        var s = EventStyle(palette: Palettes.palette(barHex: hex, fillHex: nil, dark: dark), past: past, selected: false, overlapping: false)
        s.isDark = dark; s.reply = reply
        return s
    }

    @Test func theBarIsFlushAndFullHeightAndTheTextStartsAfterIt() {
        for dark in [true, false] {
            let s = style("#A9A6F5", dark: dark)
            let px = paint(s)
            let c = s.colors
            // 3.5 pt flush bar: pixels 10, 11, 12 are the bar from the top padding to the bottom (clear of the 4.5 pt corners).
            #expect(px(11, 15) == c.bar.c8 && px(11, 30) == c.bar.c8 && px(12, 46) == c.bar.c8, "dark \(dark): bar")
            #expect(px(14, 30) == c.fill.c8, "dark \(dark): fill right after the bar")
            #expect(px(110, 30) == c.fill.c8 && px(125, 30) == InkRGB.of(dark).bg.c8, "dark \(dark): the block ends at its width")
        }
        #expect(EventPainter.textInset(dark: true) == 9.5 && EventPainter.textInset(dark: false) == 9.5)
        #expect(Radius.event == 4)
    }

    @Test func anUnansweredBlockHasAnOutlineAndNoBar() {
        let s = style("#E9B949", dark: true, reply: .notAnswered)
        let px = paint(s)
        #expect(px(10, 30) == s.colors.outline!.c8)          // the 1 pt hue outline
        #expect(px(12, 30) == InkRGB.dark.bg.c8)            // bg fill where the bar would be
    }

    @Test func aMaybeBlockIsHatchedIn5PointBands() {
        let s = style("#5B8DEF", dark: true, reply: .maybe)
        let px = paint(s, size: CGSize(width: 113, height: 75))
        // d = ((x − 10) + (y − 10)) / √2 from the top-left corner: d mod 10 < 5 is the hatch, the rest the fill (band centres sampled).
        let hatch = s.colors.stripe!.c8, fill = s.colors.fill.c8
        #expect(px(34, 60) == hatch && px(41, 60) == fill && px(48, 60) == hatch)
    }

    @Test func aDeclinedBlockIsStruckWithoutAlpha() {
        let s = style("#E5674F", dark: true, reply: .declined)
        #expect(s.colors.strike && s.colors.bar == s.palette.pastBarRGB && s.colors.barAlpha == 1)
    }
}
