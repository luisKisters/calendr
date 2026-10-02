import Foundation

// MARK: - Overlap layout (cascade)

public struct TimeSpan: Sendable {
    public var id: String
    public var startMinute: Int
    public var endMinute: Int
    public init(id: String, startMinute: Int, endMinute: Int) {
        self.id = id; self.startMinute = startMinute; self.endMinute = endMinute
    }
}

public struct Placement: Equatable, Sendable {
    public init(id: String, column: Int, columns: Int, span: Int = 1, over: Bool = false) {
        self.id = id; self.column = column; self.columns = columns; self.span = span; self.over = over
    }
    public var id: String
    public var column: Int
    public var columns: Int
    /// Columns this event reaches across, starting at `column`.
    public var span: Int
    /// Laid over an earlier event: drawn with a window-coloured outline so it reads as cut out.
    public var over: Bool
    /// 0...1 of the day column width.
    public var left: Double { Double(column) / Double(columns) }
    public var width: Double { Double(span) / Double(columns) }
    /// Paint order: later columns on top.
    public var z: Int { column }
}

public enum OverlapLayout {
    /// Every block is at least this tall (points), so short events still collide when they would touch.
    public static let minHeight = 19.0
    /// The head of a block (title and time): an event only gives up the columns to its right when something there starts inside it.
    static let head = 36.0
    /// A short neighbour's last points may touch the corner of the head.
    static let touch = 8.0

    /// Lays out one day's spans at `pointsPerHour` (the cascade works in points, as the blocks are drawn).
    public static func layout(_ spans: [TimeSpan], pointsPerHour: Double = 56) -> [Placement] {
        let k = pointsPerHour / 60
        return pack(spans.map { s in
            let y0 = Double(s.startMinute) * k
            return (s.id, y0, max(Double(s.endMinute) * k, y0 + minHeight))
        })
    }

    /// `pack()` of design/mockup-v3/app-core.js: columns per overlap cluster, then each event reaches right across later columns
    /// unless one of them has an event starting inside this event's head. Events that start together split the column.
    public static func pack(_ input: [(id: String, y0: Double, y1: Double)]) -> [Placement] {
        let items = input.indices.sorted {
            let a = input[$0], b = input[$1]
            if a.y0 != b.y0 { return a.y0 < b.y0 }
            if a.y1 != b.y1 { return a.y1 > b.y1 }
            return $0 < $1
        }
        var out: [Placement] = []
        out.reserveCapacity(input.count)
        var cluster: [(i: Int, col: Int)] = []
        var end = -Double.infinity
        var cols: [Double] = []

        func flush() {
            guard !cluster.isEmpty else { return }
            let n = cols.count
            var spans = [Int](repeating: 1, count: cluster.count)
            for (j, it) in cluster.enumerated() {
                let a = input[it.i]
                let h = min(a.y1 - a.y0, head)
                var span = 1
                for c in (it.col + 1)..<max(it.col + 1, n) {
                    if cluster.contains(where: { o in o.col == c && input[o.i].y0 < a.y0 + h && input[o.i].y1 > a.y0 + touch }) { break }
                    span += 1
                }
                spans[j] = span
            }
            for (j, it) in cluster.enumerated() {
                let a = input[it.i]
                let over = cluster.indices.contains { k in
                    let o = cluster[k], b = input[o.i]
                    return k != j && o.col < it.col && o.col + spans[k] > it.col && b.y0 < a.y1 - 0.5 && b.y1 > a.y0 + 0.5
                }
                out.append(Placement(id: a.id, column: it.col, columns: n, span: spans[j], over: over))
            }
            cluster.removeAll(keepingCapacity: true)
            cols.removeAll(keepingCapacity: true)
            end = -Double.infinity
        }

        for i in items {
            let it = input[i]
            if !cluster.isEmpty && it.y0 >= end - 0.5 { flush() }
            var c = cols.firstIndex { $0 <= it.y0 + 0.5 } ?? -1
            if c < 0 { c = cols.count; cols.append(0) }
            cols[c] = it.y1
            cluster.append((i, c))
            end = max(end, it.y1)
        }
        flush()
        return out
    }
}

// MARK: - All-day lanes

public struct AllDayItem: Sendable {
    public var id: String
    /// Inclusive day indices relative to the visible range (may be outside 0..<dayCount, they are clipped).
    public var firstDay: Int
    public var lastDay: Int
    public init(id: String, firstDay: Int, lastDay: Int) { self.id = id; self.firstDay = firstDay; self.lastDay = lastDay }
}

public struct AllDayPlacement: Equatable, Sendable {
    public var id: String
    public var lane: Int
    public var firstDay: Int
    public var lastDay: Int
    public var clippedLeft: Bool
    public var clippedRight: Bool
    public var span: Int { lastDay - firstDay + 1 }
    public init(id: String, lane: Int, firstDay: Int, lastDay: Int, clippedLeft: Bool, clippedRight: Bool) {
        self.id = id; self.lane = lane; self.firstDay = firstDay; self.lastDay = lastDay; self.clippedLeft = clippedLeft; self.clippedRight = clippedRight
    }
}

public struct AllDayLayout: Equatable, Sendable {
    public var placements: [AllDayPlacement]
    public var laneCount: Int
    public var dayCount: Int
    public static let empty = AllDayLayout(placements: [], laneCount: 0, dayCount: 0)

    /// Items visible with at most `maxLanes` lanes, and the number hidden per day.
    public func collapsed(maxLanes: Int) -> (visible: [AllDayPlacement], hiddenPerDay: [Int]) {
        var hidden = [Int](repeating: 0, count: dayCount)
        var vis: [AllDayPlacement] = []
        for p in placements {
            if p.lane < maxLanes { vis.append(p) } else {
                for d in p.firstDay...p.lastDay where d >= 0 && d < dayCount { hidden[d] += 1 }
            }
        }
        return (vis, hidden)
    }
}

public enum AllDayPacker {
    /// First-fit packing: longer spans first within the same start day, no gaps between lanes.
    public static func pack(_ items: [AllDayItem], dayCount: Int) -> AllDayLayout {
        guard dayCount > 0 else { return .empty }
        let clipped: [(idx: Int, id: String, a: Int, b: Int, cl: Bool, cr: Bool)] = items.enumerated().compactMap { i, it in
            guard it.lastDay >= 0, it.firstDay < dayCount else { return nil }
            return (i, it.id, max(0, it.firstDay), min(dayCount - 1, it.lastDay), it.firstDay < 0, it.lastDay > dayCount - 1)
        }.sorted {
            if $0.a != $1.a { return $0.a < $1.a }
            let l0 = $0.b - $0.a, l1 = $1.b - $1.a
            if l0 != l1 { return l0 > l1 }
            return $0.idx < $1.idx
        }
        var laneEnds: [Int] = []   // last occupied day per lane
        var out: [AllDayPlacement] = []
        for c in clipped {
            var lane = laneEnds.firstIndex { $0 < c.a } ?? -1
            if lane < 0 { laneEnds.append(c.b); lane = laneEnds.count - 1 } else { laneEnds[lane] = c.b }
            out.append(AllDayPlacement(id: c.id, lane: lane, firstDay: c.a, lastDay: c.b, clippedLeft: c.cl, clippedRight: c.cr))
        }
        return AllDayLayout(placements: out, laneCount: laneEnds.count, dayCount: dayCount)
    }
}

// MARK: - Range layout (what the views draw)

public struct PlacedEvent: Identifiable, Equatable, Sendable {
    public var id: String
    public var event: CalendarEvent
    public var dayIndex: Int
    public var startMinute: Int
    public var endMinute: Int
    public var placement: Placement
    public var continuesFromPrevious: Bool
    public var continuesToNext: Bool
    public init(id: String, event: CalendarEvent, dayIndex: Int, startMinute: Int, endMinute: Int, placement: Placement,
                continuesFromPrevious: Bool = false, continuesToNext: Bool = false) {
        self.id = id; self.event = event; self.dayIndex = dayIndex; self.startMinute = startMinute; self.endMinute = endMinute
        self.placement = placement; self.continuesFromPrevious = continuesFromPrevious; self.continuesToNext = continuesToNext
    }
}

public struct RangeLayout: Sendable {
    public var days: [Date]
    public var timed: [[PlacedEvent]]         // per day
    public var allDay: AllDayLayout
    public var allDayEvents: [String: CalendarEvent]
    /// Hour height the overlap cascade was computed for.
    public var pointsPerHour: Double = 56
    public static let empty = RangeLayout(days: [], timed: [], allDay: .empty, allDayEvents: [:])

    public var timedCount: Int { timed.reduce(0) { $0 + $1.count } }

    /// The same events cascaded for another hour height (the cascade is measured in points).
    public func repacked(pointsPerHour pph: Double) -> RangeLayout {
        guard pph != pointsPerHour else { return self }
        var r = self
        r.pointsPerHour = pph
        r.timed = timed.map { RangeLayoutBuilder.pack($0, pointsPerHour: pph) }
        return r
    }
}

public enum RangeLayoutBuilder {
    /// Day index (relative to `days`) containing `t`, by binary search over the day starts: DST safe and much cheaper than Calendar.
    public static func dayIndex(_ t: Date, starts: [Date]) -> Int {
        var lo = 0, hi = starts.count
        while lo < hi { let m = (lo + hi) / 2; if starts[m] <= t { lo = m + 1 } else { hi = m } }
        return lo - 1      // -1 before the range, starts.count - 1 at/after the last start
    }

    /// Cascades one day's events and sorts them into paint order (lower columns first, so cascaded events sit on top).
    public static func pack(_ day: [PlacedEvent], pointsPerHour: Double) -> [PlacedEvent] {
        var placed = day
        let placements = OverlapLayout.layout(placed.indices.map {
            TimeSpan(id: String($0), startMinute: placed[$0].startMinute, endMinute: placed[$0].endMinute)
        }, pointsPerHour: pointsPerHour)
        for p in placements { if let i = Int(p.id) { placed[i].placement = p } }
        // Sort small integer keys, not the (large) PlacedEvent values.
        let keys = placed.map { $0.placement.z * 100_000 + $0.startMinute }
        let order = (0..<placed.count).sorted { keys[$0] != keys[$1] ? keys[$0] < keys[$1] : $0 < $1 }
        return order.map { placed[$0] }
    }

    public static func build(events: [CalendarEvent], days: [Date], math: CalendarMath, pointsPerHour: Double = 56) -> RangeLayout {
        let dayCount = days.count
        guard dayCount > 0 else { return .empty }
        let rangeEnd = math.addDays(days[dayCount - 1], 1)
        // Days that are not 24h long (DST changes) need wall-clock minutes; everything else can use elapsed time.
        let regular: [Bool] = (0..<dayCount).map { i in
            let next = i + 1 < dayCount ? days[i + 1] : rangeEnd
            return next.timeIntervalSince(days[i]) == 86_400
        }
        func minute(_ t: Date, dayIdx: Int) -> Int {
            if regular[dayIdx] { return Int(t.timeIntervalSince(days[dayIdx]) / 60) }
            return math.minutesSinceMidnight(t)
        }
        var perDaySpans = [[(event: CalendarEvent, s: Int, e: Int, from: Bool, to: Bool)]](repeating: [], count: dayCount)
        var allDayItems: [AllDayItem] = []
        var allDayMap: [String: CalendarEvent] = [:]

        for ev in events {
            if ev.isAllDay {
                let a = math.daysBetween(days[0], ev.start)
                var b = math.daysBetween(days[0], ev.end) - 1
                if b < a { b = a }
                guard b >= 0, a < dayCount else { continue }
                allDayItems.append(AllDayItem(id: ev.id, firstDay: a, lastDay: b))
                allDayMap[ev.id] = ev
                continue
            }
            let endInstant = ev.end > ev.start ? ev.end.addingTimeInterval(-1) : ev.end
            let first = ev.start < days[0] ? -1 : dayIndex(ev.start, starts: days)
            let last = endInstant < days[0] ? -1 : (endInstant >= rangeEnd ? dayCount : dayIndex(endInstant, starts: days))
            guard last >= 0, first < dayCount else { continue }
            let lo = max(0, first), hi = min(dayCount - 1, last)
            for d in lo...hi {
                let s = (d == first) ? minute(ev.start, dayIdx: d) : 0
                var e = (d == last) ? minute(ev.end, dayIdx: d) : 1440
                if d == last && ev.end > ev.start && e == 0 { e = 1440 }
                if d == last && ev.end == ev.start { e = s }
                perDaySpans[d].append((ev, s, e, d != first, d != last))
            }
        }

        var timed: [[PlacedEvent]] = []
        timed.reserveCapacity(dayCount)
        for d in 0..<dayCount {
            let placed = perDaySpans[d].map { sp in
                PlacedEvent(id: "\(sp.event.id)|\(d)", event: sp.event, dayIndex: d, startMinute: sp.s, endMinute: sp.e,
                            placement: Placement(id: "", column: 0, columns: 1), continuesFromPrevious: sp.from, continuesToNext: sp.to)
            }
            timed.append(pack(placed, pointsPerHour: pointsPerHour))
        }
        return RangeLayout(days: days, timed: timed, allDay: AllDayPacker.pack(allDayItems, dayCount: dayCount), allDayEvents: allDayMap,
                           pointsPerHour: pointsPerHour)
    }
}

public enum FreeSlot {
    /// First start minute >= `from` on a `step` grid where [start, start+duration) collides with none of `busy`.
    /// Returns nil when the day has no room left.
    public static func next(from: Int, duration: Int, busy: [(start: Int, end: Int)], step: Int = 30) -> Int? {
        var s = ((max(0, from) + step - 1) / step) * step
        while s + duration <= 1440 {
            if let hit = busy.first(where: { $0.start < s + duration && $0.end > s }) {
                s = (((max(hit.end, s + 1)) + step - 1) / step) * step
            } else { return s }
        }
        return nil
    }
}
