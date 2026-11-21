import Foundation

// The minute model of the timed-event layout (from overlap layout v5, design/mockup-v4). The v5 algorithm itself and its "+N"
// overflow groups are gone (mockup-v14: every event shows); `OverlapV11` lays the day out with these types.

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

public enum OverlapV5 {
    /// An item this long or shorter is short.
    public static let shortLimit = 15
    /// A short item draws as a block this many minutes tall (mockup short "block").
    public static let shortSpan = 22
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
