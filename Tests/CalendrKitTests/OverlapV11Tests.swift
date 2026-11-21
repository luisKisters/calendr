import Testing
import Foundation
@testable import CalendrKit

/// v5 H: `OverlapV11`, the locked cascade of design/mockup-v11 (app.js `clustersOf`, `cascade`), and the `covered` rule;
/// mockup-v14: crowded spots side by side, and the visible part of a covered block.
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
        #expect(r.first { $0.id == "later" }!.indent == 0 && !r.first { $0.id == "later" }!.cut && r.first { $0.id == "later" }!.width == 1)
    }

    @Test func fourAtOnceStillCascades() {
        let p = lay([it("a", "09:00", "11:00"), it("b", "09:30", "11:00"), it("c", "10:00", "11:00"), it("d", "10:30", "11:00")])
        #expect(p["d"]!.indent == 36 && p["d"]!.width == 1)
        #expect(OverlapV11.crowdedAt == 5)
    }

    /// mockup-v14: five or more at one moment go side by side in equal columns; a block widens into free columns on its right.
    @Test func fiveAtOnceGoSideBySide() {
        let p = lay([it("a", "09:00", "10:30"), it("b", "09:00", "10:00"), it("c", "09:15", "10:15"), it("d", "09:30", "10:30"),
                     it("e", "09:45", "10:15"), it("f", "10:00", "10:30")])
        // Columns: a | b, f | c | d | e. Five columns; "f" takes b's column after it ends, "e" ends 10:15 so nothing widens.
        #expect(p.values.allSatisfy { $0.indent == 0 && abs($0.width - 0.2) < 1e-9 })
        #expect(p["a"]!.left == 0 && !p["a"]!.cut && p["b"]!.left == 0.2 && p["f"]!.left == 0.2 && abs(p["e"]!.left - 0.8) < 1e-9 && p["e"]!.cut)
        // A later block with free columns to its right widens into them.
        let q = lay([it("a", "09:00", "10:00"), it("b", "09:00", "10:00"), it("c", "09:00", "10:00"), it("d", "09:00", "09:30"),
                     it("e", "09:00", "09:30"), it("f", "09:30", "10:00")])
        #expect(abs(q["f"]!.left - 0.6) < 1e-9 && abs(q["f"]!.width - 0.4) < 1e-9)
    }

    @Test func concurrencyCountsSpansAtOneMoment() {
        #expect(OverlapV11.concurrency([(0, 60), (30, 90), (60, 120)]) == 2)      // a span ends before the next starts at its end
        #expect(OverlapV11.concurrency([]) == 0)
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
        let v = Dictionary(uniqueKeysWithValues: r.timed[0].map { ($0.event.id, $0.placement.visibleMinutes) })
        #expect(v == ["review": 30, "hiring": nil, "walk": 45, "talk": nil])
    }

    /// mockup-v14: a later block beside it (the right half) does not cover it; one drawn over it does, from its start.
    @Test func aBlockBesideItDoesNotCoverIt() {
        let math = CalendarMath(timeZone: TimeZone(identifier: "Europe/Berlin")!)
        let day = math.date(year: 2026, month: 11, day: 4)
        func ev(_ id: String, _ s: String, _ e: String) -> CalendarEvent {
            CalendarEvent(id: id, calendarID: "c", title: id, start: math.date(on: day, minutes: Self.m(s)), end: math.date(on: day, minutes: Self.m(e)))
        }
        // Family dinner 19:00-22:00; "With Mum" 19:10 takes the right half; "Jolie / Luis" 21:30 cascades over the dinner.
        let r = RangeLayoutBuilder.build(events: [ev("dinner", "19:00", "22:00"), ev("mum", "19:10", "19:40"), ev("jolie", "21:30", "22:30")],
                                         days: [day], math: math)
        let p = Dictionary(uniqueKeysWithValues: r.timed[0].map { ($0.event.id, $0.placement) })
        #expect(p["mum"]!.left == 0.5 && !p["dinner"]!.covered && p["dinner"]!.visibleMinutes == 150)
    }
}
