import Testing
import Foundation
@testable import CalendrKit

/// v5 H: `OverlapV11`, the locked cascade of design/mockup-v11 (app.js `clustersOf`, `cascade`), and the `covered` rule.
@Suite("Overlap layout v11 (cascade)")
struct OverlapV11Tests {
    static func m(_ t: String) -> Int { let p = t.split(separator: ":").compactMap { Int($0) }; return p[0] * 60 + p[1] }
    func it(_ id: String, _ s: String, _ e: String) -> V5Item { V5Item(id: id, startMinute: Self.m(s), endMinute: Self.m(e)) }
    func lay(_ items: [V5Item]) -> [String: V5Placement] { Dictionary(uniqueKeysWithValues: OverlapV11.layout(items).map { ($0.id, $0) }) }

    @Test func aLaterBlockIndentsOneStepAndKeepsTheWidth() {
        // Wednesday of the demo week: Design review 16:30-18:45, Hiring sync 17:00-18:00.
        let p = lay([it("review", "16:30", "18:45"), it("hiring", "17:00", "18:00")])
        #expect(p["review"]!.indent == 0 && p["review"]!.width == 1 && !p["review"]!.cut)
        #expect(p["hiring"]!.indent == 12 && p["hiring"]!.left == 0 && p["hiring"]!.width == 1 && p["hiring"]!.cut)
    }

    @Test func aBlockWithinOneTitleLineTakesTheRightHalf() {
        let p = lay([it("a", "10:00", "11:00"), it("b", "10:15", "11:00")])
        #expect(p["a"]!.width == 0.5 && p["b"]!.left == 0.5 && p["b"]!.width == 0.5 && p["b"]!.indent == 0)
        let q = lay([it("a", "10:00", "11:00"), it("b", "10:22", "11:00")])     // 22 minutes: a cascade step instead
        #expect(q["a"]!.width == 1 && q["b"]!.indent == 12)
    }

    @Test func theDepthFollowsTheDeepestBlockStillRunning() {
        let p = lay([it("a", "09:00", "12:00"), it("b", "09:30", "11:00"), it("c", "10:00", "10:45"), it("d", "11:30", "12:30")])
        #expect(p["b"]!.indent == 12 && p["c"]!.indent == 24)
        #expect(p["d"]!.indent == 12)                                         // only "a" still runs at 11:30
    }

    @Test func separateClustersStartOverAndNothingIsFolded() {
        let items = (0..<12).map { V5Item(id: "e\($0)", startMinute: 600 + $0 * 5, endMinute: 720) } + [it("later", "13:00", "14:00")]
        let r = OverlapV11.layout(items)
        #expect(r.count == items.count)
        #expect(r.first { $0.id == "later" }!.indent == 0 && !r.first { $0.id == "later" }!.cut)
    }

    @Test func shortItemsSpan22Minutes() {
        let p = lay([it("task", "09:00", "09:00"), it("standup", "09:30", "09:45")])
        #expect(p["task"]!.endMinute == 9 * 60 + 22 && p["standup"]!.endMinute == 9 * 60 + 52)
    }

    @Test func aBlockCoveredWithinFortyMinutesIsMarked() {
        let math = CalendarMath(timeZone: TimeZone(identifier: "Europe/Berlin")!)
        let day = math.date(year: 2026, month: 11, day: 4)
        func ev(_ id: String, _ s: String, _ e: String) -> CalendarEvent {
            CalendarEvent(id: id, calendarID: "c", title: id, start: math.date(on: day, minutes: Self.m(s)), end: math.date(on: day, minutes: Self.m(e)))
        }
        let r = RangeLayoutBuilder.build(events: [ev("review", "16:30", "18:45"), ev("hiring", "17:00", "18:00"), ev("walk", "19:00", "20:00"),
                                                  ev("talk", "19:45", "20:30")], days: [day], math: math)
        let c = Dictionary(uniqueKeysWithValues: r.timed[0].map { ($0.event.id, $0.placement.covered) })
        #expect(c == ["review": true, "hiring": false, "walk": false, "talk": false])   // walk: talk starts 45 minutes in
    }
}
