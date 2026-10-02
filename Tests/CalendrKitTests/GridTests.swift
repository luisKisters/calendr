import Testing
import Foundation
@testable import CalendrKit

@Suite("Overlap cascade")
struct GridCascadeTests {
    func layout(_ spans: [(String, Int, Int)], pph: Double = 56) -> [String: Placement] {
        Dictionary(uniqueKeysWithValues: OverlapLayout.layout(spans.map { TimeSpan(id: $0.0, startMinute: $0.1, endMinute: $0.2) }, pointsPerHour: pph).map { ($0.id, $0) })
    }

    @Test func shortEventInsideALectureLeavesItFullWidth() {
        // A 2 hour lecture and a 15 minute event an hour into it.
        let p = layout([("lecture", 600, 720), ("call", 660, 675)])
        #expect(p["lecture"]!.column == 0 && p["lecture"]!.span == 2 && p["lecture"]!.width == 1)
        #expect(p["call"]!.column == 1 && p["call"]!.left == 0.5 && p["call"]!.width == 0.5)
        #expect(p["call"]!.over && !p["lecture"]!.over)
    }

    @Test func eventsStartingTogetherSplitTheColumn() {
        let p = layout([("a", 600, 660), ("b", 600, 660)])
        #expect(p["a"]!.width == 0.5 && p["b"]!.width == 0.5)
        #expect(p["a"]!.left == 0 && p["b"]!.left == 0.5)
        #expect(!p["a"]!.over && !p["b"]!.over)
    }

    @Test func eventStartingInsideTheHeadSplits() {
        // 20 minutes at 56 pt per hour is 18.7 pt: inside the 36 pt head.
        let p = layout([("a", 600, 720), ("b", 620, 700)])
        #expect(p["a"]!.span == 1 && p["b"]!.column == 1)
    }

    @Test func threeWayChain() {
        // a 10-12, b 10:45-11:45 (outside a's head, so a reaches over it), c 11:00-11:30 starts inside b's head.
        let p = layout([("a", 600, 720), ("b", 645, 705), ("c", 660, 690)])
        #expect(p.values.allSatisfy { $0.columns == 3 })
        #expect(p["a"]!.column == 0 && p["b"]!.column == 1 && p["c"]!.column == 2)
        #expect(p["a"]!.span == 3)              // nothing starts inside a's head
        #expect(p["b"]!.span == 1)              // c starts inside b's head
        #expect(p["c"]!.span == 1 && p["c"]!.over && p["b"]!.over)
    }

    @Test func threeStartingTogetherShareThirds() {
        let p = layout([("a", 600, 660), ("b", 600, 660), ("c", 600, 660)])
        #expect(p.values.allSatisfy { $0.columns == 3 && $0.span == 1 })
        #expect(Set(p.values.map(\.column)) == [0, 1, 2])
    }

    @Test func cascadeDependsOnHourHeight() {
        // 30 minutes after the start: outside the head at 96 pt per hour (48 pt), inside it at 56 pt per hour (28 pt).
        #expect(layout([("a", 600, 720), ("b", 630, 700)], pph: 96)["a"]!.span == 2)
        #expect(layout([("a", 600, 720), ("b", 630, 700)], pph: 56)["a"]!.span == 1)
    }

    @Test func separateClustersAreIndependent() {
        let p = layout([("a", 600, 660), ("b", 600, 660), ("c", 900, 960)])
        #expect(p["c"]!.columns == 1 && p["c"]!.width == 1)
    }
}
