import Testing
import Foundation
@testable import CalendrKit

/// v4 Phase 3: `OverlapV5`, the port of the mockup's `layoutDay()` with the locked picks (smart, right, stack, block).
@Suite("Overlap layout v5")
struct OverlapV5Tests {
    static func m(_ t: String) -> Int { let p = t.split(separator: ":").compactMap { Int($0) }; return p[0] * 60 + p[1] }
    func it(_ id: String, _ s: String, _ e: String, un: Bool = false) -> V5Item { V5Item(id: id, startMinute: Self.m(s), endMinute: Self.m(e), isUnaccepted: un) }
    func lay(_ items: [V5Item]) -> (p: [String: V5Placement], r: OverlapV5.Result) {
        let r = OverlapV5.layout(items)
        return (Dictionary(uniqueKeysWithValues: r.placements.map { ($0.id, $0) }), r)
    }
    func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

    // Rule 1
    @Test func sameStartPutsTheLongerFirstAndShortItemsSpan22Minutes() {
        let (p, _) = lay([it("short", "10:00", "10:30"), it("long", "10:00", "11:00"), it("task", "14:00", "14:00")])
        #expect(close(p["long"]!.left, 0) && close(p["long"]!.width, 0.5) && !p["long"]!.cut)
        #expect(close(p["short"]!.left, 0.5) && close(p["short"]!.width, 0.5) && p["short"]!.cut)
        #expect(p["task"]!.startMinute == 14 * 60 && p["task"]!.endMinute == 14 * 60 + 22)
        #expect(V5Item(id: "x", startMinute: 0, endMinute: 15).isShort && !V5Item(id: "x", startMinute: 0, endMinute: 16).isShort)
    }

    // Rule 2
    @Test func aThirdBlockAtTheSameTimeOverflows() {
        let (p, r) = lay([it("a", "10:00", "12:00"), it("b", "10:10", "12:00"), it("c", "10:20", "11:00")])
        #expect(p["c"] == nil && r.groups == [OverflowGroup(startMinute: Self.m("10:20"), ids: ["c"])])
    }

    // Rule 3
    @Test func startsWithin30MinutesShareTheWidth() {
        let (p, _) = lay([it("a", "10:00", "11:00"), it("b", "10:20", "11:00")])
        #expect(close(p["a"]!.left, 0) && close(p["a"]!.width, 0.5) && !p["a"]!.cut && p["a"]!.level == 0)
        #expect(close(p["b"]!.left, 0.5) && close(p["b"]!.width, 0.5) && p["b"]!.cut && p["b"]!.level == 0)
    }

    // Rule 4
    @Test func laterStartsCascadeWithAnIndent() {
        let (p, _) = lay([it("a", "10:00", "12:00"), it("b", "10:45", "11:30")])
        #expect(close(p["a"]!.width, 1) && p["a"]!.indent == 0)
        #expect(p["b"]!.level == 1 && close(p["b"]!.left, 0) && close(p["b"]!.width, 1) && p["b"]!.indent == 14 && p["b"]!.cut)
    }

    // Rule 5
    @Test func unacceptedAloneTakesTheFullWidth() {
        let (p, _) = lay([it("u", "10:00", "11:00", un: true)])
        #expect(close(p["u"]!.left, 0) && close(p["u"]!.width, 1) && p["u"]!.level == 0 && !p["u"]!.cut)
    }

    @Test func unacceptedGoesRightAndShrinksAcceptedThatStartWithIt() {
        let (p, _) = lay([it("a", "10:00", "11:00"), it("early", "09:00", "11:00"), it("u", "10:15", "11:00", un: true)])
        // "a" (cascaded over "early") starts within 30 min of "u" and shrinks; "early" started an hour before and keeps its width.
        #expect(close(p["a"]!.width, 0.5) && close(p["early"]!.width, 1))
        #expect(close(p["u"]!.left, 0.5) && close(p["u"]!.width, 0.5) && p["u"]!.level == 8 && p["u"]!.cut)
    }

    @Test func unacceptedOverAnUnacceptedOnTheRightOverflows() {
        let (p, r) = lay([it("a", "10:00", "11:00"), it("u1", "10:00", "11:00", un: true), it("u2", "10:30", "11:00", un: true)])
        #expect(p["u1"] != nil && p["u2"] == nil && r.groups.flatMap(\.ids) == ["u2"])
    }

    // Rule 6
    @Test func shortItemUnderTwoBlocksOverflows() {
        let (p, r) = lay([it("a", "10:00", "11:00"), it("b", "10:00", "11:00"), it("s", "10:10", "10:10")])
        #expect(p["s"] == nil && r.groups == [OverflowGroup(startMinute: 610, ids: ["s"])])
    }

    @Test func shortItemInABlocksHeadTakesItsRightThird() {
        let (p, _) = lay([it("a", "10:00", "11:00"), it("s", "10:15", "10:15")])
        #expect(close(p["a"]!.width, 0.66) && close(p["s"]!.left, 0.66) && close(p["s"]!.width, 0.34) && p["s"]!.level == 9)
        // From 10 minutes before the start.
        let (q, _) = lay([it("a", "10:00", "11:00"), it("s", "09:50", "09:50")])
        #expect(close(q["a"]!.width, 0.66) && close(q["s"]!.left, 0.66))
    }

    @Test func shortItemLaterInABlockSitsOnItsRightHalfAndAloneAtZero() {
        let (p, _) = lay([it("a", "10:00", "12:00"), it("s", "11:00", "11:00"), it("t", "13:00", "13:00"), it("t2", "13:10", "13:10")])
        #expect(close(p["a"]!.width, 1) && close(p["s"]!.left, 0.5) && p["s"]!.level == 9)
        #expect(close(p["t"]!.left, 0) && close(p["t"]!.width, 1))
        #expect(close(p["t2"]!.left, 0.5))
    }

    // Rule 7
    @Test func overflowGroupsJoinWithin30MinutesAndTheStackListsTheBusyTime() {
        let items = [it("a", "10:00", "12:00"), it("b", "10:10", "12:00"), it("c", "10:20", "11:00"), it("d", "10:40", "11:00"),
                     it("e", "11:00", "11:30"), it("late", "13:00", "14:00")]
        let (_, r) = lay(items)
        #expect(r.groups == [OverflowGroup(startMinute: 620, ids: ["c", "d"]), OverflowGroup(startMinute: 660, ids: ["e"])])
        #expect(r.groups[0].busyRange(items) == 620...660)
        #expect(r.groups[0].stackRows(dayEvents: items).map(\.id) == ["a", "b", "c", "d"])
        #expect(r.groups[1].stackRows(dayEvents: items).map(\.id) == ["a", "b", "e"])
        // A zero-length item is busy for 15 minutes.
        let task = V5Item(id: "t", startMinute: 600, endMinute: 600)
        #expect(OverflowGroup(startMinute: 600, ids: ["t"]).busyRange([task]) == 600...615)
    }

    // The v4 fixture's Wednesday (mockup RAW day 2): Flat cleaning is declined, Club board meeting not answered.
    static let wednesday: [(String, String, String, Bool)] = [
        ("c1", "09:00", "09:00", false), ("c2", "12:00", "13:15", false), ("c3", "14:00", "16:00", false), ("c4", "14:10", "14:10", false),
        ("c5", "18:15", "18:15", false), ("c6", "21:30", "22:15", false), ("w1", "17:00", "18:30", false), ("w2", "17:15", "18:45", false),
        ("w3", "18:00", "19:00", true), ("w4", "19:00", "20:00", false), ("w5", "19:00", "20:00", true), ("w6", "20:00", "21:30", false),
        ("w7", "20:15", "20:45", false),
    ]

    @Test func fixtureWednesdayEveningHasOnePlusOneAt1815() {
        let items = Self.wednesday.map { it($0.0, $0.1, $0.2, un: $0.3) }
        let (p, r) = lay(items)
        #expect(r.groups == [OverflowGroup(startMinute: 18 * 60 + 15, ids: ["c5"])])
        // Founder meetup and Idea session share the width; Flat cleaning sits on their right half.
        #expect(close(p["w1"]!.width, 0.5) && close(p["w2"]!.left, 0.5) && close(p["w3"]!.left, 0.5) && p["w3"]!.level == 8)
        // Club board meeting (no reply) takes the right half and Dinner break gives it room.
        #expect(close(p["w4"]!.width, 0.5) && close(p["w5"]!.left, 0.5) && p["w5"]!.level == 8)
        #expect(close(p["w6"]!.width, 0.5) && close(p["w7"]!.left, 0.5) && p["w7"]!.cut)
        let stack = r.groups[0].stackRows(dayEvents: items).map(\.id)
        #expect(stack == ["w1", "w2", "w3", "c5"])
    }

    // Golden file: `swift scripts/render-mockup.swift --eval` of the mockup's own layoutDay() on every fixture day and 12 random days.
    struct Golden: Decodable {
        struct Item: Decodable { var id: String; var s: Int; var e: Int; var un: Bool }
        struct Place: Decodable { var id: String; var s: Int; var en: Int; var left: Double; var width: Double; var px: Double; var level: Int; var cut: Bool }
        struct Group: Decodable { var s: Int; var ids: [String] }
        var name: String; var items: [Item]; var placements: [Place]; var over: [String]; var groups: [Group]
    }

    @Test func matchesTheMockupGolden() throws {
        let url = try #require(Bundle.module.url(forResource: "layout-v4", withExtension: "json", subdirectory: "Fixtures"))
        let days = try JSONDecoder().decode([Golden].self, from: Data(contentsOf: url))
        #expect(days.count == 19)
        for day in days {
            let r = OverlapV5.layout(day.items.map { V5Item(id: $0.id, startMinute: $0.s, endMinute: $0.e, isUnaccepted: $0.un) })
            #expect(r.placements.map(\.id) == day.placements.map(\.id), "\(day.name): drawing order")
            for (a, g) in zip(r.placements, day.placements) {
                let same = abs(a.left - g.left) < 1e-5 && abs(a.width - g.width) < 1e-5 && a.indent == g.px && a.level == g.level && a.cut == g.cut
                    && a.startMinute == g.s && a.endMinute == g.en
                #expect(same, "\(day.name) \(g.id): \(a) vs \(g)")
            }
            #expect(Set(r.groups.flatMap(\.ids)) == Set(day.over), "\(day.name): overflow")
            if day.name.hasPrefix("fixture") {
                #expect(r.groups.map(\.startMinute) == day.groups.map(\.s) && r.groups.map(\.ids) == day.groups.map(\.ids), "\(day.name): groups")
            }
        }
    }

    @Test func sixtyEventsADayLayOutUnderOneMillisecond() {
        var h: UInt32 = 7
        func rnd(_ n: Int) -> Int { h = h &* 1103515245 &+ 12345; return Int((h >> 8) % UInt32(n)) }
        let items = (0..<60).map { i -> V5Item in
            let s = 7 * 60 + rnd(56) * 15
            return V5Item(id: "e\(i)", startMinute: s, endMinute: s + [0, 15, 30, 45, 60, 90, 120][rnd(7)], isUnaccepted: rnd(5) == 0)
        }
        _ = OverlapV5.layout(items)
        var best = Double.infinity
        for _ in 0..<30 {
            let t = DispatchTime.now().uptimeNanoseconds
            let r = OverlapV5.layout(items)
            best = min(best, Double(DispatchTime.now().uptimeNanoseconds - t) / 1e6)
            #expect(r.placements.count + r.groups.reduce(0) { $0 + $1.ids.count } == 60)
        }
        print("OverlapV5 60 events: \(String(format: "%.3f", best)) ms")
        #expect(best < 1.0, "60 events took \(best) ms")
    }
}
