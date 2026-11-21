import Foundation

public struct UpcomingSection: Identifiable, Equatable, Sendable {
    public init(title: String, day: Date, events: [CalendarEvent]) { self.title = title; self.day = day; self.events = events }
    public var id: Date { day }
    public var title: String
    public var day: Date
    public var events: [CalendarEvent]
}

public struct UpcomingSummary: Equatable, Sendable {
    public init(next: CalendarEvent?, sections: [UpcomingSection]) { self.next = next; self.sections = sections }
    public var next: CalendarEvent?
    public var sections: [UpcomingSection]
}

public enum Upcoming {
    /// Groups upcoming timed events. The next event is lifted out of its day section.
    public static func summarize(events: [CalendarEvent], now: Date, days: Int = 7, fmt: Fmt) -> UpcomingSummary {
        let math = fmt.math
        let today = math.startOfDay(now)
        let horizon = math.addDays(today, days)
        let relevant = events.filter {
            !$0.isAllDay && $0.status != .declined && $0.end > now && $0.start < horizon
        }.sorted { $0.start != $1.start ? $0.start < $1.start : $0.title < $1.title }

        let next = relevant.first { $0.start >= now } ?? relevant.first
        var sections: [UpcomingSection] = []
        for ev in relevant where ev.id != next?.id && ev.start >= now {   // events already running are not upcoming
            let day = max(today, math.startOfDay(ev.start))
            if let last = sections.last, last.day == day { sections[sections.count - 1].events.append(ev) } else {
                sections.append(UpcomingSection(title: sectionTitle(day, today: today, fmt: fmt), day: day, events: [ev]))
            }
        }
        return UpcomingSummary(next: next, sections: sections)
    }

    public static func sectionTitle(_ day: Date, today: Date, fmt: Fmt) -> String {
        switch fmt.math.daysBetween(today, day) {
        case 0: "Today"
        case 1: "Tomorrow"
        default: fmt.sectionDate(day)
        }
    }
}
