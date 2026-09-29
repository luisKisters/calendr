import Foundation

public enum EventKind: String, Sendable, Hashable, CaseIterable { case event, task }
public enum ResponseStatus: String, Sendable, Hashable, CaseIterable { case confirmed, tentative, declined }
public enum Availability: String, Sendable, Hashable, CaseIterable { case busy, free }
public enum EventVisibility: String, Sendable, Hashable, CaseIterable { case standard, `public`, `private` }

public enum CalendarKindIcon: String, Sendable, Hashable { case standard, feed, tasks }

public struct CalendarInfo: Identifiable, Hashable, Sendable {
    public var id: String
    public var accountID: String
    public var title: String
    public var colorHex: String
    public var icon: CalendarKindIcon
    public var isDefault: Bool
    public var isVisibleByDefault: Bool
    public var isWritable: Bool

    public init(id: String, accountID: String, title: String, colorHex: String, icon: CalendarKindIcon = .standard,
                isDefault: Bool = false, isVisibleByDefault: Bool = true, isWritable: Bool = true) {
        self.id = id; self.accountID = accountID; self.title = title; self.colorHex = colorHex; self.icon = icon
        self.isDefault = isDefault; self.isVisibleByDefault = isVisibleByDefault; self.isWritable = isWritable
    }
}

public struct CalendarAccount: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var calendars: [CalendarInfo]
    public init(id: String, name: String, calendars: [CalendarInfo]) {
        self.id = id; self.name = name; self.calendars = calendars
    }
}

public struct Teammate: Identifiable, Hashable, Sendable {
    public var id: String { email }
    public var name: String
    public var email: String
    public init(name: String, email: String) { self.name = name; self.email = email }
}

public struct Recurrence: Hashable, Sendable {
    public enum Frequency: String, Sendable, Hashable, CaseIterable { case daily, weekly, monthly, yearly }
    public var frequency: Frequency
    public var interval: Int
    /// Calendar weekday numbers (1 = Sunday ... 7 = Saturday). Empty means "the weekday of the start date".
    public var weekdays: [Int]
    public var until: Date?
    public init(frequency: Frequency, interval: Int = 1, weekdays: [Int] = [], until: Date? = nil) {
        self.frequency = frequency; self.interval = max(1, interval); self.weekdays = weekdays; self.until = until
    }
}

public struct CalendarEvent: Identifiable, Hashable, Sendable {
    public var id: String
    /// Shared by every occurrence of a recurring event.
    public var seriesID: String?
    public var calendarID: String
    public var title: String
    public var start: Date
    /// Exclusive end. For all-day events this is the start of the day after the last day.
    public var end: Date
    public var isAllDay: Bool
    public var kind: EventKind
    public var status: ResponseStatus
    public var location: String
    public var notes: String
    public var recurrence: Recurrence?
    public var participants: [String]
    public var conferencing: String
    public var reminderMinutes: Int?
    public var availability: Availability
    public var visibility: EventVisibility
    public var timeZoneID: String
    /// Set for events that belong to an overlaid teammate.
    public var ownerEmail: String?
    /// Per-event color override (fill tint). The leading bar keeps the calendar color.
    public var colorHex: String?
    /// Optional second leading bar (e.g. a tag color next to the calendar bar).
    public var secondaryBarHex: String?

    public init(id: String = UUID().uuidString, seriesID: String? = nil, calendarID: String, title: String,
                start: Date, end: Date, isAllDay: Bool = false, kind: EventKind = .event,
                status: ResponseStatus = .confirmed, location: String = "", notes: String = "",
                recurrence: Recurrence? = nil, participants: [String] = [], conferencing: String = "",
                reminderMinutes: Int? = nil, availability: Availability = .busy,
                visibility: EventVisibility = .standard, timeZoneID: String = "Europe/Berlin",
                ownerEmail: String? = nil, colorHex: String? = nil, secondaryBarHex: String? = nil) {
        self.id = id; self.seriesID = seriesID; self.calendarID = calendarID; self.title = title
        self.start = start; self.end = max(end, start); self.isAllDay = isAllDay; self.kind = kind
        self.status = status; self.location = location; self.notes = notes; self.recurrence = recurrence
        self.participants = participants; self.conferencing = conferencing; self.reminderMinutes = reminderMinutes
        self.availability = availability; self.visibility = visibility; self.timeZoneID = timeZoneID
        self.ownerEmail = ownerEmail; self.colorHex = colorHex; self.secondaryBarHex = secondaryBarHex
    }

    public var durationMinutes: Int { Int((end.timeIntervalSince(start) / 60).rounded()) }
    public var isRecurring: Bool { recurrence != nil || seriesID != nil }
}

public enum ViewMode: Hashable, Sendable {
    case day, week, month
    /// 2...7 visible days.
    case custom(Int)

    public var dayCount: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 7
        case .custom(let n): min(7, max(2, n))
        }
    }
    public var title: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .custom(let n): "\(n) days"
        }
    }
}

/// A reversible change to the store, used by undo.
public enum EventChange: Sendable {
    case created(CalendarEvent)
    case deleted([CalendarEvent])
    case updated(old: CalendarEvent, new: CalendarEvent)
}

public struct UndoStack: Sendable {
    public private(set) var changes: [EventChange] = []
    public let limit: Int
    public init(limit: Int = 100) { self.limit = limit }
    public var isEmpty: Bool { changes.isEmpty }
    public mutating func push(_ c: EventChange) {
        changes.append(c)
        if changes.count > limit { changes.removeFirst(changes.count - limit) }
    }
    public mutating func pop() -> EventChange? { changes.popLast() }
}
