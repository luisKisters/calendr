import Testing
import Foundation
import AppKit
@testable import Calendr
import CalendrKit

/// v4 Phase 4: the block colours of each reply state against mockup-v4 `evVars()` (solid, quiet clean-up, past p2) and the
/// `.rs-quiet` / `.ds` reply rules. `cc` is the calendar colour, `mix(a, b, t)` is b at t over a.
@MainActor
@Suite("v4 event palette")
struct PaletteV4Tests {
    static func close(_ a: RGB, _ b: RGB) -> Bool { abs(a.r - b.r) < 1e-9 && abs(a.g - b.g) < 1e-9 && abs(a.b - b.b) < 1e-9 }
    let hex = "#5B8DEF"
    var ink: InkRGB { .dark }
    var cc: RGB { RGB(hex: hex) }
    var pal: EventPalette { Palettes.palette(barHex: hex, fillHex: nil, dark: true) }

    @Test func normal() {
        let c = pal.colors(reply: .accepted, past: false)
        #expect(Self.close(c.fill, ink.bg.mixed(with: cc, 0.34)) && Self.close(c.bar, cc) && c.barAlpha == 1)
        #expect(Self.close(c.title, ink.fg) && Self.close(c.time, ink.fg2) && c.stripe == nil && c.outline == nil && !c.strike)
    }

    @Test func past() {
        let c = pal.colors(reply: .accepted, past: true)
        #expect(Self.close(c.fill, ink.bg.mixed(with: cc, 0.15)) && Self.close(c.bar, ink.bg.mixed(with: cc, 0.32)))
        #expect(Self.close(c.title, ink.fg2) && Self.close(c.time, ink.fg3))
    }

    @Test func notAnsweredIsHollowWithADashOutline() {
        let c = pal.colors(reply: .notAnswered, past: false)
        #expect(Self.close(c.fill, ink.bg) && Self.close(c.outline!, ink.bg.mixed(with: cc, 0.75)))
        #expect(Self.close(c.bar, cc) && Self.close(c.title, ink.fg) && Self.close(c.time, ink.fg2))
        #expect(Self.close(pal.colors(reply: .notAnswered, past: true).title, ink.fg))   // `.ev.st-none .t` keeps fg
    }

    @Test func maybeIsStriped() {
        let fill = ink.bg.mixed(with: cc, 0.34)
        let c = pal.colors(reply: .maybe, past: false)
        #expect(Self.close(c.fill, fill) && Self.close(c.stripe!, ink.bg.mixed(with: fill, 0.55)))
        #expect(Self.close(c.bar, cc) && Self.close(c.title, ink.fg) && Self.close(c.time, ink.fg2))
    }

    @Test func declinedIsSolidAndStruck() {
        let fill = ink.bg.mixed(with: cc, 0.34)
        let c = pal.colors(reply: .declined, past: false)
        #expect(Self.close(c.fill, ink.bg.mixed(with: fill, 0.38)) && Self.close(c.bar, cc) && c.barAlpha == 0.45)
        #expect(Self.close(c.title, ink.fg3) && Self.close(c.time, ink.fg3) && c.strike)
    }

    @Test func theEventColourReplacesTheCalendarColour() {
        let p = Palettes.palette(barHex: hex, fillHex: "#5FB97E", dark: true)
        #expect(Self.close(p.barRGB, RGB(hex: "#5FB97E")))
    }

    @Test func fixtureRepliesMapToStates() {
        let m = makeModelV4()
        func reply(_ id: String) -> EventReply { EventReply(m.event(id: "v4.\(id)")!) }
        #expect(reply("w5") == .notAnswered && reply("w3") == .declined && reply("w2") == .maybe && reply("w1") == .accepted)
        #expect(reply("wg") == .accepted)              // Sam organises Flat dinner
        #expect(EventReply.declined.label == "declined" && EventReply.notAnswered.label == "no reply" && EventReply.maybe.label == "maybe")
    }

    @Test func longWordsHyphenateAtSyllablesAndTheResultIsCached() {
        let w = TextCache.line("Research inter-", .title).width + 1
        let lines = TextCache.wrapTexts("Research interviews", .title, width: w, maxLines: 2, hyphenate: true)
        #expect(lines == ["Research inter-", "views"])
        #expect(TextCache.wrapTexts("Research interviews", .title, width: w, maxLines: 2, hyphenate: false) == ["Research", "interviews"])
        let a = TextCache.wrapped("Research interviews", .title, width: w, maxLines: 2, hyphenate: true)
        let b = TextCache.wrapped("Research interviews", .title, width: w, maxLines: 2, hyphenate: true)
        #expect(a.count == 2 && a[0].line === b[0].line)
    }
}
