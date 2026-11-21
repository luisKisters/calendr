import Foundation

/// Keyboard walking of the selection (mockup `tabSel` and `neighbour`).
public enum KeyboardSelection {
    /// Tab order of a period: by day, all-day first, then by start and end.
    public static func tabOrder(_ events: [CalendarEvent], math: CalendarMath) -> [CalendarEvent] {
        events.map { (e: $0, day: math.startOfDay($0.start)) }
            .sorted { a, b in
                if a.day != b.day { return a.day < b.day }
                if a.e.isAllDay != b.e.isAllDay { return a.e.isAllDay }
                return a.e.start != b.e.start ? a.e.start < b.e.start : a.e.end < b.e.end
            }
            .map(\.e)
    }

    /// Tab / Shift-Tab: the next or previous event of the period, wrapping. From nothing, Tab starts at the first event
    /// that has not ended and Shift-Tab at the one before it.
    public static func tab(from id: String?, in events: [CalendarEvent], now: Date, direction: Int, math: CalendarMath) -> CalendarEvent? {
        let list = tabOrder(events, math: math)
        guard !list.isEmpty else { return nil }
        let n = list.count
        if let id, let i = list.firstIndex(where: { $0.id == id }) { return list[(i + direction + n) % n] }
        let first = list.firstIndex { $0.end > now } ?? 0
        return list[direction < 0 ? (first - 1 + n) % n : first]
    }

    /// Arrow keys: up and down walk the timed events of the same day by start; left and right go to the timed event
    /// nearest in start time on the closest day (up to a week away) that has one.
    public static func neighbour(of e: CalendarEvent, in events: [CalendarEvent], dx: Int, dy: Int, math: CalendarMath) -> CalendarEvent? {
        let timed = events.filter { !$0.isAllDay }
        let day0 = math.startOfDay(e.start)
        if dy != 0 {
            let same = timed.filter { math.startOfDay($0.start) == day0 }
                .sorted { $0.start != $1.start ? $0.start < $1.start : $0.end < $1.end }
            guard let i = same.firstIndex(where: { $0.id == e.id }), same.indices.contains(i + dy) else { return nil }
            return same[i + dy]
        }
        guard dx != 0 else { return nil }
        let minute = math.minutesSinceMidnight(e.start)
        for k in 1...7 {
            let day = math.addDays(day0, dx * k)
            let c = timed.filter { math.startOfDay($0.start) == day }.sorted { $0.start < $1.start }
            if let best = c.min(by: { abs(math.minutesSinceMidnight($0.start) - minute) < abs(math.minutesSinceMidnight($1.start) - minute) }) {
                return best
            }
        }
        return nil
    }

    /// Option-arrows: the event moved by whole days and by minutes; a timed event stays inside its day. nil when nothing moves.
    public static func nudged(_ e: CalendarEvent, days: Int, minutes: Int, math: CalendarMath) -> CalendarEvent? {
        var out = e
        let len = e.end.timeIntervalSince(e.start)
        if e.isAllDay || len >= 86_400 {
            out.start = math.addDays(e.start, days)
        } else {
            let lenMin = Int(len / 60)
            let m = max(0, min(1440 - lenMin, math.minutesSinceMidnight(e.start) + minutes))
            out.start = math.date(on: math.addDays(math.startOfDay(e.start), days), minutes: m)
        }
        out.end = out.start.addingTimeInterval(len)
        if e.isAllDay { out.end = math.addDays(e.end, days) }
        return out.start == e.start && out.end == e.end ? nil : out
    }
}
