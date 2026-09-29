import Foundation

/// All calendar arithmetic goes through this type so the week start and time zone are decided in one place.
public struct CalendarMath: Sendable {
    public var calendar: Calendar

    public init(timeZone: TimeZone = TimeZone(identifier: "Europe/Berlin") ?? .current, weekStartsOnMonday: Bool = true) {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        c.locale = Locale(identifier: "en_US_POSIX")
        c.firstWeekday = weekStartsOnMonday ? 2 : 1
        c.minimumDaysInFirstWeek = 4
        calendar = c
    }

    public var timeZone: TimeZone { calendar.timeZone }

    public func startOfDay(_ d: Date) -> Date { calendar.startOfDay(for: d) }

    public func addDays(_ d: Date, _ n: Int) -> Date {
        calendar.date(byAdding: .day, value: n, to: d) ?? d.addingTimeInterval(Double(n) * 86_400)
    }

    public func addMonths(_ d: Date, _ n: Int) -> Date {
        calendar.date(byAdding: .month, value: n, to: d) ?? d
    }

    /// 0 = first day of the week (Monday by default).
    public func weekdayIndex(_ d: Date) -> Int {
        (calendar.component(.weekday, from: d) - calendar.firstWeekday + 7) % 7
    }

    public func startOfWeek(_ d: Date) -> Date { addDays(startOfDay(d), -weekdayIndex(d)) }

    public func startOfMonth(_ d: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: d)) ?? startOfDay(d)
    }

    public func isWeekend(_ d: Date) -> Bool { let w = calendar.component(.weekday, from: d); return w == 1 || w == 7 }

    public func isSameDay(_ a: Date, _ b: Date) -> Bool { calendar.isDate(a, inSameDayAs: b) }

    public func isSameMonth(_ a: Date, _ b: Date) -> Bool {
        calendar.component(.month, from: a) == calendar.component(.month, from: b)
            && calendar.component(.year, from: a) == calendar.component(.year, from: b)
    }

    /// Whole calendar days from a to b (b - a), DST safe.
    public func daysBetween(_ a: Date, _ b: Date) -> Int {
        calendar.dateComponents([.day], from: startOfDay(a), to: startOfDay(b)).day ?? 0
    }

    public func days(from start: Date, count: Int) -> [Date] {
        let s = startOfDay(start)
        return (0..<count).map { addDays(s, $0) }
    }

    public func minutesSinceMidnight(_ d: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    public func date(on day: Date, minutes: Int) -> Date {
        let s = startOfDay(day)
        return calendar.date(byAdding: .minute, value: minutes, to: s) ?? s.addingTimeInterval(Double(minutes) * 60)
    }

    public func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? Date(timeIntervalSince1970: 0)
    }

    public func components(_ d: Date) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: d)
    }

    public func day(_ d: Date) -> Int { calendar.component(.day, from: d) }
    public func month(_ d: Date) -> Int { calendar.component(.month, from: d) }
    public func year(_ d: Date) -> Int { calendar.component(.year, from: d) }

    public static func snap(_ minutes: Int, to step: Int = 15) -> Int {
        Int((Double(minutes) / Double(step)).rounded()) * step
    }

    /// Six rows of seven days starting on the week start of the week containing the 1st (mini calendar and month view).
    public func monthGrid(for d: Date) -> [[Date]] {
        let first = startOfWeek(startOfMonth(d))
        return (0..<6).map { row in (0..<7).map { col in addDays(first, row * 7 + col) } }
    }

    /// Start day of the visible range for a view mode. `leftAligned` starts the range on `anchor` itself.
    public func visibleStart(mode: ViewMode, anchor: Date, leftAligned: Bool) -> Date {
        switch mode {
        case .day: return startOfDay(anchor)
        case .week: return leftAligned ? startOfDay(anchor) : startOfWeek(anchor)
        case .custom: return startOfDay(anchor)
        case .month: return startOfMonth(anchor)
        }
    }

    /// Anchor after moving one period forward (`direction` = 1) or back (-1).
    public func step(mode: ViewMode, anchor: Date, direction: Int) -> Date {
        switch mode {
        case .month: return addMonths(startOfMonth(anchor), direction)
        case .week: return addDays(anchor, 7 * direction)
        case .day: return addDays(anchor, direction)
        case .custom(let n): return addDays(anchor, min(7, max(2, n)) * direction)
        }
    }

    /// Range of days actually queried for a mode. Month covers the full 6-row grid.
    public func queryRange(mode: ViewMode, start: Date) -> DateInterval {
        switch mode {
        case .month:
            let first = startOfWeek(startOfMonth(start))
            return DateInterval(start: first, end: addDays(first, 42))
        default:
            let s = startOfDay(start)
            return DateInterval(start: s, end: addDays(s, mode.dayCount))
        }
    }

    /// The next free half hour slot at or after `now` (used by the `C` shortcut).
    public func nextHalfHour(after now: Date) -> Date {
        let mins = minutesSinceMidnight(now)
        let next = (mins / 30 + 1) * 30
        return date(on: now, minutes: next)
    }
}
