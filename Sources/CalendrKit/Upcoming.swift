import Foundation

public struct UpcomingSection: Identifiable, Equatable, Sendable {
    public init(title: String, day: Date, events: [CalendarEvent]) { self.title = title; self.day = day; self.events = events }
    public var id: Date { day }
    public var title: String
    public var day: Date
    public var events: [CalendarEvent]
}

public struct UpcomingSummary: Equatable, Sendable {
    public init(next: CalendarEvent?, untilNext: String, label: String, sections: [UpcomingSection]) { self.next = next; self.untilNext = untilNext; self.label = label; self.sections = sections }
    public var next: CalendarEvent?
    /// "4h 58min"
    public var untilNext: String
    /// "in 4h 58m"
    public var label: String
    public var sections: [UpcomingSection]
}

public enum Upcoming {
    /// Groups upcoming timed events for the menu bar. The next event is lifted out of its day section.
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
        var until = "", label = ""
        if let n = next {
            if n.start <= now { until = "now"; label = "now" } else {
                let mins = Int((n.start.timeIntervalSince(now) / 60).rounded(.up))
                until = DurationText.minutes(mins)
                label = "in " + DurationText.short(mins)
            }
        }
        return UpcomingSummary(next: next, untilNext: until, label: label, sections: sections)
    }

    public static func sectionTitle(_ day: Date, today: Date, fmt: Fmt) -> String {
        switch fmt.math.daysBetween(today, day) {
        case 0: "Today"
        case 1: "Tomorrow"
        default: fmt.sectionDate(day)
        }
    }

    /// "Meal Prep \u{00B7} in 4h 58m"
    public static func menuBarLabel(_ s: UpcomingSummary) -> String {
        guard let n = s.next else { return "No upcoming events" }
        return "\(n.title) \u{00B7} \(s.label)"
    }
}
