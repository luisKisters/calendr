import Foundation

/// Fast, allocation-light formatting. No DateFormatter: month/weekday names are static tables.
public struct Fmt: Sendable {
    public var math: CalendarMath
    public var use24h: Bool
    public init(math: CalendarMath, use24h: Bool = true) { self.math = math; self.use24h = use24h }

    public static let weekdayShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    public static let weekdayLong = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    public static let monthShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    public static let monthLong = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    private func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }

    public func time(_ d: Date) -> String { time(minutes: math.minutesSinceMidnight(d)) }

    public func time(minutes m: Int) -> String {
        let m = ((m % 1440) + 1440) % 1440
        let h = m / 60, mm = m % 60
        if use24h { return "\(pad(h)):\(pad(mm))" }
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12):\(pad(mm)) \(h < 12 ? "AM" : "PM")"
    }

    /// "05:00" style hour label for the grid gutter.
    public func hourLabel(_ hour: Int) -> String { time(minutes: hour * 60) }

    public func timeRange(_ s: Date, _ e: Date) -> String { "\(time(s))\u{2013}\(time(e))" }

    public func weekdayShort(_ d: Date) -> String { Self.weekdayShort[math.calendar.component(.weekday, from: d) - 1] }
    public func weekdayLong(_ d: Date) -> String { Self.weekdayLong[math.calendar.component(.weekday, from: d) - 1] }
    public func monthShort(_ d: Date) -> String { Self.monthShort[math.month(d) - 1] }
    public func monthLong(_ d: Date) -> String { Self.monthLong[math.month(d) - 1] }

    /// "September 2026"
    public func monthTitle(_ d: Date) -> String { "\(monthLong(d)) \(math.year(d))" }
    /// "Wed Sep 30"
    public func inspectorDate(_ d: Date) -> String { "\(weekdayShort(d)) \(monthShort(d)) \(math.day(d))" }
    /// "Thu Oct 1"
    public func sectionDate(_ d: Date) -> String { inspectorDate(d) }
    /// "Oct 12"
    public func monthDay(_ d: Date) -> String { "\(monthShort(d)) \(math.day(d))" }
    /// "Mon, Oct 12, 2026"
    public func fullDate(_ d: Date) -> String { "\(weekdayShort(d)), \(monthShort(d)) \(math.day(d)), \(math.year(d))" }

    /// "GMT+2"
    public func gmtLabel(_ d: Date = Date()) -> String {
        let secs = math.timeZone.secondsFromGMT(for: d)
        let sign = secs < 0 ? "-" : "+"
        let a = abs(secs)
        let h = a / 3600, m = (a % 3600) / 60
        return m == 0 ? "GMT\(sign)\(h)" : "GMT\(sign)\(h):\(pad(m))"
    }

    /// "Berlin" from "Europe/Berlin".
    public func timeZoneCity() -> String {
        let id = math.timeZone.identifier
        return (id.split(separator: "/").last.map(String.init) ?? id).replacingOccurrences(of: "_", with: " ")
    }
}

public enum DurationText {
    /// "1h 40min", "45min", "2h", "1d".
    public static func minutes(_ total: Int) -> String {
        let t = max(0, total)
        if t >= 1440 && t % 1440 == 0 { return "\(t / 1440)d" }
        let h = t / 60, m = t % 60
        if h == 0 { return "\(m)min" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)min"
    }

    /// Menu bar label form: "4h 58m", "12m", "2d 3h".
    public static func short(_ total: Int) -> String {
        let t = max(0, total)
        if t >= 1440 { let d = t / 1440, h = (t % 1440) / 60; return h == 0 ? "\(d)d" : "\(d)d \(h)h" }
        let h = t / 60, m = t % 60
        if h == 0 { return "\(m)m" }
        return "\(h)h \(m)m"
    }
}

public struct RecurrenceText: Equatable, Sendable {
    /// Bright part, e.g. "Every week".
    public var lead: String
    /// Dim part, e.g. "on Wed until Dec 18".
    public var rest: String
    public var full: String { rest.isEmpty ? lead : "\(lead) \(rest)" }
}

public enum RecurrenceDescriber {
    public static func describe(_ r: Recurrence, start: Date, fmt: Fmt) -> RecurrenceText {
        let unit: String
        switch r.frequency {
        case .daily: unit = "day"
        case .weekly: unit = "week"
        case .monthly: unit = "month"
        case .yearly: unit = "year"
        }
        var lead = r.interval == 1 ? "Every \(unit)" : "Every \(r.interval) \(unit)s"
        var rest: [String] = []
        if r.frequency == .weekly {
            let days = r.weekdays.isEmpty ? [fmt.math.calendar.component(.weekday, from: start)] : r.weekdays
            let sorted = days.sorted { (a, b) in
                let fw = fmt.math.calendar.firstWeekday
                return (a - fw + 7) % 7 < (b - fw + 7) % 7
            }
            if r.interval == 1 && Set(sorted) == Set([2, 3, 4, 5, 6]) {
                lead = "Every weekday"
            } else {
                rest.append("on " + sorted.map { Fmt.weekdayShort[$0 - 1] }.joined(separator: ", "))
            }
        } else if r.frequency == .monthly {
            rest.append("on day \(fmt.math.day(start))")
        }
        if let u = r.until {
            rest.append("until \(fmt.monthDay(u))")
        }
        return RecurrenceText(lead: lead, rest: rest.joined(separator: " "))
    }
}

public enum TimeParser {
    /// "9", "930", "9:30", "09:30", "9.30", "9:30 pm" -> minutes since midnight.
    public static func parse(_ raw: String) -> Int? {
        var s = raw.lowercased().trimmingCharacters(in: .whitespaces)
        var pm: Bool?
        if s.hasSuffix("pm") { pm = true; s = String(s.dropLast(2)).trimmingCharacters(in: .whitespaces) }
        else if s.hasSuffix("am") { pm = false; s = String(s.dropLast(2)).trimmingCharacters(in: .whitespaces) }
        s = s.replacingOccurrences(of: ".", with: ":")
        var h: Int, m = 0
        if s.contains(":") {
            let p = s.split(separator: ":", omittingEmptySubsequences: false)
            guard p.count == 2, let hh = Int(p[0]), let mm = Int(p[1]) else { return nil }
            h = hh; m = mm
        } else if let v = Int(s) {
            if s.count <= 2 { h = v } else if s.count <= 4 { h = v / 100; m = v % 100 } else { return nil }
        } else { return nil }
        if let pm { if h < 1 || h > 12 { return nil }; h = h % 12 + (pm ? 12 : 0) }
        guard (0...23).contains(h), (0...59).contains(m) else { return nil }
        return h * 60 + m
    }
}

/// Tasks are events whose title starts with "[P1]" ... "[P9]" (or "[P0?]"): the priority is shown apart from the title.
public enum TaskTitle {
    /// ("P1", "Water the plants") for "[P1] Water the plants"; (nil, title) otherwise.
    public static func split(_ title: String) -> (priority: String?, text: String) {
        guard title.hasPrefix("[P"), let close = title.firstIndex(of: "]") else { return (nil, title) }
        let pr = String(title[title.index(after: title.startIndex)..<close])
        guard pr.count <= 4 else { return (nil, title) }
        let rest = title[title.index(after: close)...].trimmingCharacters(in: .whitespaces)
        return (pr, rest.isEmpty ? title : rest)
    }
}
