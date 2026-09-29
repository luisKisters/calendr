import Foundation

public struct SearchGroup: Identifiable, Sendable {
    public var id: Date { day }
    public var day: Date
    public var events: [CalendarEvent]
}

public enum EventSearch {
    static func fold(_ s: String) -> String { s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }

    /// Every whitespace separated word must appear in title, location, notes or participants.
    /// Grouped by day, ascending. Upcoming days first when `preferFrom` is set.
    public static func search(_ events: [CalendarEvent], query: String, math: CalendarMath, near: Date? = nil, limit: Int = 200) -> [SearchGroup] {
        let words = fold(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return [] }
        var hits: [CalendarEvent] = []
        for ev in events {
            let hay = fold(ev.title + " " + ev.location + " " + ev.notes + " " + ev.participants.joined(separator: " "))
            if words.allSatisfy({ hay.contains($0) }) { hits.append(ev) }
        }

        if hits.count > limit {
            let ref = near ?? hits.map(\.start).min() ?? Date()
            hits.sort { abs($0.start.timeIntervalSince(ref)) < abs($1.start.timeIntervalSince(ref)) }
            hits = Array(hits.prefix(limit))
        }
        hits.sort { $0.start < $1.start }

        var groups: [SearchGroup] = []
        for ev in hits {
            let day = math.startOfDay(ev.start)
            if let last = groups.last, last.day == day { groups[groups.count - 1].events.append(ev) } else {
                groups.append(SearchGroup(day: day, events: [ev]))
            }
        }
        return groups
    }
}
