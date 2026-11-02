import Foundation

// Overlap layout v5: a port of design/mockup-v4/index.html `layoutDay()` (:1083) with the locked picks
// overlap "smart", unsure "right", more "stack" and short "block". Pure: minutes in, fractions of the day column out.
// It does not know about `CalendarEvent`; the caller passes the two flags that matter (short, not accepted).
//
// One deliberate difference from the mockup: "+N" groups. The mockup groups overflow items in the order they overflow
// (accepted blocks, then unaccepted, then short items) and joins an item to the first group with `item.start - group.start < 30`,
// which also holds for an item that starts long *before* the group, so an early short item can join a later group.
// Here the overflow items are sorted by start first, and an item joins the last group that started less than 30 minutes
// before it. Placements are identical; only the grouping of hidden items can differ (OverlapV5Tests lists the golden days
// where it does).

/// One timed event of a day. Minutes since the start of the day; `endMinute` is the real end.
public struct V5Item: Equatable, Sendable {
    public var id: String
    public var startMinute: Int
    public var endMinute: Int
    /// 15 minutes or less (mockup `isShort`): drawn as a block `OverlapV5.shortSpan` minutes tall.
    public var isShort: Bool
    /// Declined or not answered: on the right half, never pushing accepted events.
    public var isUnaccepted: Bool

    public init(id: String, startMinute: Int, endMinute: Int, isShort: Bool? = nil, isUnaccepted: Bool = false) {
        self.id = id; self.startMinute = startMinute; self.endMinute = max(endMinute, startMinute)
        self.isShort = isShort ?? (endMinute - startMinute <= OverlapV5.shortLimit)
        self.isUnaccepted = isUnaccepted
    }

    /// An event's minutes on `day`, clamped to the day: 23:00-00:30 gives 1380-1440, and a day it spans fully gives 0-1440.
    /// Short or not follows the real length.
    public init(id: String, start: Date, end: Date, day: Date, math: CalendarMath, isUnaccepted: Bool = false) {
        let m = math.minutesOnDay(start, end, day: day)
        self.init(id: id, startMinute: m.start, endMinute: m.end, isShort: end.timeIntervalSince(start) <= Double(OverlapV5.shortLimit) * 60,
                  isUnaccepted: isUnaccepted)
    }

    /// The end the "+N" busy time uses: the real end, or 15 minutes for a zero-length item (mockup `evmore` `end`).
    public var busyEnd: Int { endMinute > startMinute ? endMinute : startMinute + 15 }
}

/// Where an item goes. `left` and `width` are fractions of the day column; `indent` is extra points from the left
/// (the cascade); `level` orders the drawing (higher on top); `cut` items draw a gap line on their left edge.
public struct V5Placement: Equatable, Sendable {
    public var id: String
    public var left: Double
    public var width: Double
    public var indent: Double
    public var level: Int
    public var cut: Bool
    /// The drawn span: a short item spans `OverlapV5.shortSpan` minutes.
    public var startMinute: Int
    public var endMinute: Int
    public init(id: String, left: Double, width: Double, indent: Double, level: Int, cut: Bool, startMinute: Int, endMinute: Int) {
        self.id = id; self.left = left; self.width = width; self.indent = indent; self.level = level; self.cut = cut
        self.startMinute = startMinute; self.endMinute = endMinute
    }
}

/// Items that do not fit, shown as one "+N" button at `startMinute` that opens the stack.
public struct OverflowGroup: Equatable, Sendable {
    public var startMinute: Int
    public var ids: [String]
    public init(startMinute: Int, ids: [String]) { self.startMinute = startMinute; self.ids = ids }

    /// The busy time of the hidden items: from the earliest start to the latest end (mockup :1512).
    public func busyRange(_ items: [V5Item]) -> ClosedRange<Int>? {
        let mine = items.filter { ids.contains($0.id) }
        guard let lo = mine.map(\.startMinute).min(), let hi = mine.map(\.busyEnd).max() else { return nil }
        return lo...hi
    }

    /// The rows of the "+N" stack: every event of the day that overlaps the busy time, by start (mockup :1513).
    public func stackRows(dayEvents: [V5Item]) -> [V5Item] {
        guard let r = busyRange(dayEvents) else { return [] }
        return dayEvents.enumerated().filter { $0.element.startMinute < r.upperBound && $0.element.busyEnd > r.lowerBound }
            .sorted { $0.element.startMinute != $1.element.startMinute ? $0.element.startMinute < $1.element.startMinute : $0.offset < $1.offset }
            .map(\.element)
    }
}

public enum OverlapV5 {
    /// An item this long or shorter is short.
    public static let shortLimit = 15
    /// A short item draws as a block this many minutes tall (mockup short "block").
    public static let shortSpan = 22
    /// Items that start within this many minutes of a group's start share its width; overflow groups within it merge.
    public static let joinWindow = 30
    /// Points of extra indent per cascade level.
    public static let indentStep = 14.0
    /// Unaccepted items sit right of this; accepted ones that start with them shrink to it.
    public static let unacceptedLeft = 0.5
    /// A short item in the head of a block takes the block's right part from here.
    public static let headLeft = 0.66

    public struct Result: Equatable, Sendable {
        /// In drawing order: accepted blocks, unaccepted blocks, short items.
        public var placements: [V5Placement]
        public var groups: [OverflowGroup]
    }

    private struct W {
        var id: String, order: Int, s: Int, en: Int, short: Bool, un: Bool
        var left = 0.0, width = 1.0, px = 0.0, level = 0, cut = false, grp = -1
    }
    private struct G { var s: Int; var left: Double; var width: Double; var items: [Int] }

    public static func layout(_ input: [V5Item]) -> Result {
        // 1. By start; the longer first when two start together (input order breaks the remaining ties).
        var w: [W] = input.enumerated().map { i, it in
            W(id: it.id, order: i, s: it.startMinute, en: it.isShort ? it.startMinute + shortSpan : it.endMinute, short: it.isShort, un: it.isUnaccepted)
        }
        w.sort { a, b in
            if a.s != b.s { return a.s < b.s }
            if a.en - a.s != b.en - b.s { return a.en - a.s > b.en - b.s }
            return a.order < b.order
        }
        var out: [Int] = []
        var over: [Int] = []
        var groups: [G] = []
        @inline(__always) func overlaps(_ a: Int, _ b: Int) -> Bool { w[a].s < w[b].en && w[a].en > w[b].s }
        @inline(__always) func covers(_ o: Int, _ i: Int) -> Bool { w[o].s <= w[i].s && w[o].en > w[i].s }

        // 2-4. Accepted blocks.
        for i in w.indices where !w[i].short && !w[i].un {
            let under = out.filter { overlaps($0, i) }
            if under.lazy.filter({ covers($0, i) }).count >= 2 { over.append(i); continue }
            if let host = under.last(where: { w[i].s - groups[w[$0].grp].s < joinWindow }) {
                let gi = w[host].grp
                groups[gi].items.append(i)
                w[i].grp = gi; w[i].level = w[host].level; w[i].px = w[host].px; w[i].cut = w[host].cut
                let g = groups[gi], n = Double(g.items.count)
                for (k, o) in g.items.enumerated() {
                    w[o].left = g.left + g.width * Double(k) / n
                    w[o].width = g.width / n
                    if k > 0 { w[o].cut = true }
                }
                out.append(i)
                continue
            }
            var top: Int?
            for o in under {
                guard let t = top else { top = o; continue }
                if w[o].level > w[t].level || (w[o].level == w[t].level && w[o].s > w[t].s) { top = o }
            }
            if let t = top {
                w[i].level = w[t].level + 1; w[i].left = groups[w[t].grp].left; w[i].px = w[t].px + indentStep; w[i].cut = true
            } else {
                w[i].level = 0; w[i].left = 0; w[i].px = 0; w[i].cut = false
            }
            w[i].width = 1 - w[i].left
            w[i].grp = groups.count
            groups.append(G(s: w[i].s, left: w[i].left, width: w[i].width, items: [i]))
            out.append(i)
        }

        // 5. Unaccepted blocks: alone they take the full width; otherwise the right half, on top.
        var placedRight: [Int] = []
        for i in w.indices where !w[i].short && w[i].un {
            let hit = out.filter { overlaps($0, i) }
            if hit.isEmpty { w[i].left = 0; w[i].width = 1; w[i].level = 0; out.append(i); continue }
            if placedRight.contains(where: { overlaps($0, i) }) { over.append(i); continue }
            for o in hit where abs(w[i].s - w[o].s) < joinWindow && w[o].left < unacceptedLeft {
                w[o].width = min(w[o].width, unacceptedLeft - w[o].left)
            }
            w[i].left = unacceptedLeft; w[i].width = 1 - unacceptedLeft; w[i].level = 8; w[i].cut = true
            placedRight.append(i); out.append(i)
        }

        // 6. Short items: never split a block; on its right half, or its right third in its first 30 minutes.
        let blocks = out
        for i in w.indices where w[i].short {
            if blocks.lazy.filter({ covers($0, i) }).count >= 2 { over.append(i); continue }
            let hit = blocks.contains { overlaps($0, i) } || out.contains { w[$0].short && overlaps($0, i) }
            var head = false
            if hit {
                for o in blocks {
                    let into = w[i].s - w[o].s
                    if into >= -10 && into < joinWindow && overlaps(o, i) && w[o].left + w[o].width > headLeft {
                        w[o].width = max(headLeft - w[o].left, 0.3); head = true
                    }
                }
            }
            w[i].left = hit ? (head ? headLeft : 0.5) : 0; w[i].width = 1 - w[i].left; w[i].level = 9
            out.append(i)
        }

        // 7. "+N" groups: overflow items that start within 30 minutes of a group's first item.
        var og: [OverflowGroup] = []
        for i in over.sorted(by: { w[$0].s != w[$1].s ? w[$0].s < w[$1].s : $0 < $1 }) {
            if let k = og.lastIndex(where: { w[i].s - $0.startMinute < joinWindow }) { og[k].ids.append(w[i].id) }
            else { og.append(OverflowGroup(startMinute: w[i].s, ids: [w[i].id])) }
        }

        let placements = out.map { i in
            V5Placement(id: w[i].id, left: w[i].left, width: w[i].width, indent: w[i].px, level: w[i].level, cut: w[i].cut,
                        startMinute: w[i].s, endMinute: w[i].en)
        }
        return Result(placements: placements, groups: og)
    }
}

extension CalendarMath {
    /// Minutes since the start of `day` of the span start..<end, clamped to 0...1440 (the day's wall clock: an end on the next
    /// day is 1440, not its minutes after midnight).
    public func minutesOnDay(_ start: Date, _ end: Date, day: Date) -> (start: Int, end: Int) {
        let d0 = startOfDay(day), d1 = addDays(d0, 1)
        func m(_ t: Date) -> Int { t <= d0 ? 0 : t >= d1 ? 1440 : minutesSinceMidnight(t) }
        let s = m(start)
        return (s, max(s, m(end)))
    }
}
