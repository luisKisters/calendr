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

    /// Command menu matches: the query appears in the title or the place. Nearest day to `today` first (a past day just
    /// before the same distance ahead), then by start.
    public static func nearest(_ events: [CalendarEvent], query: String, today: Date, math: CalendarMath, limit: Int) -> [CalendarEvent] {
        let q = fold(query.trimmingCharacters(in: .whitespaces))
        guard !q.isEmpty else { return [] }
        let day0 = math.startOfDay(today)
        func distance(_ e: CalendarEvent) -> Double {
            let d = Double(math.daysBetween(day0, math.startOfDay(e.start)))
            return abs(d < 0 ? d + 0.5 : d)
        }
        var seen = Set<String>()
        var hits: [(event: CalendarEvent, distance: Double)] = []
        for e in events where fold(e.title).contains(q) || fold(e.location).contains(q) {
            if seen.insert(e.id).inserted { hits.append((e, distance(e))) }
        }
        hits.sort { a, b in a.distance != b.distance ? a.distance < b.distance : a.event.start < b.event.start }
        return hits.prefix(limit).map(\.event)
    }
}
