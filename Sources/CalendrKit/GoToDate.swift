import Foundation

/// Natural-language date input for the "Go to date" panel.
public enum GoToDateParser {
    static let months: [String: Int] = {
        var m: [String: Int] = [:]
        for (i, n) in Fmt.monthLong.enumerated() {
            m[n.lowercased()] = i + 1
            m[String(n.lowercased().prefix(3))] = i + 1
        }
        m["sept"] = 9
        return m
    }()
    static let weekdays: [String: Int] = {   // Calendar weekday numbers, Sunday = 1
        var m: [String: Int] = [:]
        for (i, n) in Fmt.weekdayLong.enumerated() {
            m[n.lowercased()] = i + 1
            m[String(n.lowercased().prefix(3))] = i + 1
        }
        m["tues"] = 3; m["wednes"] = 4; m["thur"] = 5; m["thurs"] = 5
        return m
    }()

    public static func parse(_ raw: String, now: Date, math: CalendarMath) -> Date? {
        let s = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let today = math.startOfDay(now)

        switch s {
        case "today", "now": return today
        case "tomorrow", "tmrw", "tom": return math.addDays(today, 1)
        case "yesterday": return math.addDays(today, -1)
        case "next week": return math.startOfWeek(math.addDays(today, 7))
        case "last week", "previous week": return math.startOfWeek(math.addDays(today, -7))
        case "next month": return math.startOfMonth(math.addMonths(today, 1))
        case "last month", "previous month": return math.startOfMonth(math.addMonths(today, -1))
        default: break
        }

        // ISO: 2026-12-24
        if let m = match(s, #"^(\d{4})-(\d{1,2})-(\d{1,2})$"#), m.count == 3 {
            return valid(m[0], m[1], m[2], math)
        }
        // German / European: 12.10. 12.10.2026 12.10.26
        if let m = match(s, #"^(\d{1,2})\.\s?(\d{1,2})\.?(?:\s?(\d{4}|\d{2}))?$"#) {
            let year = m.count > 2 ? expandYear(m[2]) : nil
            return resolve(day: m[0], month: m[1], year: year, now: today, math: math)
        }
        // Slash: 10/12 or 10/12/2026 (month first)
        if let m = match(s, #"^(\d{1,2})/(\d{1,2})(?:/(\d{4}|\d{2}))?$"#) {
            let year = m.count > 2 ? expandYear(m[2]) : nil
            return resolve(day: m[1], month: m[0], year: year, now: today, math: math)
        }
        // "oct 12", "october 12 2027", "12 oct", "12th of october"
        let cleaned = s.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: " of ", with: " ")
        let parts = cleaned.split(separator: " ").map(String.init)
        if parts.count >= 2 && parts.count <= 3 {
            var mon: Int?, day: Int?, year: Int?
            for p in parts {
                if let mm = months[p], mon == nil { mon = mm }
                else if let n = Int(stripOrdinal(p)) {
                    if stripOrdinal(p).count == 4 { year = n } else if day == nil { day = n } else if year == nil { year = expandYear(n) }
                } else { mon = nil; day = nil; break }
            }
            if let mon, let day { return resolve(day: day, month: mon, year: year, now: today, math: math) }
        }

        // "in 3 days", "in 2 weeks", "3 days ago"
        if let m = match(s, #"^in\s+(\d+)\s+(day|days|week|weeks|month|months)$"#) {
            return offset(Int(m[0]) ?? 0, unit: m[1], today: today, math: math)
        }
        if let m = match(s, #"^(\d+)\s+(day|days|week|weeks|month|months)\s+ago$"#) {
            return offset(-(Int(m[0]) ?? 0), unit: m[1], today: today, math: math)
        }

        // weekday names: "friday" (next occurrence, today counts), "next friday" (strictly after today, next week semantics), "last friday"
        var name = s, mode = 0
        if s.hasPrefix("next ") { name = String(s.dropFirst(5)); mode = 1 }
        else if s.hasPrefix("last ") { name = String(s.dropFirst(5)); mode = -1 }
        else if s.hasPrefix("this ") { name = String(s.dropFirst(5)); mode = 0 }
        if let wd = weekdays[name] {
            let cur = math.calendar.component(.weekday, from: today)
            switch mode {
            case -1:
                let back = (cur - wd + 7) % 7
                return math.addDays(today, -(back == 0 ? 7 : back))
            case 1:
                // "next friday" = that weekday in the following calendar week.
                let nextWeekStart = math.addDays(math.startOfWeek(today), 7)
                let idx = (wd - math.calendar.firstWeekday + 7) % 7
                return math.addDays(nextWeekStart, idx)
            default:
                let fwd = (wd - cur + 7) % 7
                return math.addDays(today, fwd)
            }
        }
        // a bare month name: first of that month
        if let mon = months[s] { return resolve(day: 1, month: mon, year: nil, now: today, math: math) }
        return nil
    }

    static func offset(_ n: Int, unit: String, today: Date, math: CalendarMath) -> Date {
        if unit.hasPrefix("day") { return math.addDays(today, n) }
        if unit.hasPrefix("week") { return math.addDays(today, 7 * n) }
        return math.addMonths(today, n)
    }

    static func stripOrdinal(_ s: String) -> String {
        for suf in ["st", "nd", "rd", "th"] where s.hasSuffix(suf) && s.count > suf.count && s.dropLast(suf.count).allSatisfy(\.isNumber) {
            return String(s.dropLast(suf.count))
        }
        return s
    }

    static func expandYear(_ s: String) -> Int? { Int(s).map(expandYear) }
    static func expandYear(_ n: Int) -> Int { n < 100 ? 2000 + n : n }

    static func valid(_ y: String, _ m: String, _ d: String, _ math: CalendarMath) -> Date? {
        guard let y = Int(y), let m = Int(m), let d = Int(d) else { return nil }
        return build(y, m, d, math)
    }

    static func build(_ y: Int, _ m: Int, _ d: Int, _ math: CalendarMath) -> Date? {
        guard (1...12).contains(m), (1...31).contains(d) else { return nil }
        let date = math.date(year: y, month: m, day: d)
        let c = math.components(date)
        return c.year == y && c.month == m && c.day == d ? date : nil
    }

    /// Without an explicit year, choose the current year unless that lands more than ~5 months in the past.
    static func resolve(day: String, month: String, year: Int?, now: Date, math: CalendarMath) -> Date? {
        guard let d = Int(day), let m = Int(month) else { return nil }
        return resolve(day: d, month: m, year: year, now: now, math: math)
    }

    static func resolve(day: Int, month: Int, year: Int?, now: Date, math: CalendarMath) -> Date? {
        if let year { return build(year, month, day, math) }
        let y = math.year(now)
        guard let this = build(y, month, day, math) else { return nil }
        if math.daysBetween(this, now) > 150 { return build(y + 1, month, day, math) ?? this }
        return this
    }

    static func match(_ s: String, _ pattern: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        var out: [String] = []
        for i in 1..<m.numberOfRanges {
            let r = m.range(at: i)
            if r.location != NSNotFound { out.append(ns.substring(with: r)) }
        }
        return out
    }
}
