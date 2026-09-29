import Foundation

// Pure mirror types of the EventKit objects the adapter reads. The adapter in the app target only copies
// fields into these; every decision (grouping, colors, status, icons) lives here and is tested.

public enum RawSourceType: Sendable { case local, exchange, calDAV, mobileMe, subscribed, birthdays }
public enum RawCalendarType: Sendable { case local, calDAV, exchange, subscription, birthday }
public enum RawParticipantStatus: Sendable { case unknown, pending, accepted, declined, tentative, delegated, completed, inProcess }

public struct RawSource: Sendable {
    public var id: String, title: String, type: RawSourceType
    public init(id: String, title: String, type: RawSourceType) { self.id = id; self.title = title; self.type = type }
}

public struct RawCalendar: Sendable {
    public var id: String, sourceID: String, title: String, type: RawCalendarType
    public var red: Double, green: Double, blue: Double
    public var allowsContentModifications: Bool
    public init(id: String, sourceID: String, title: String, type: RawCalendarType, red: Double, green: Double, blue: Double, allowsContentModifications: Bool) {
        self.id = id; self.sourceID = sourceID; self.title = title; self.type = type
        self.red = red; self.green = green; self.blue = blue; self.allowsContentModifications = allowsContentModifications
    }
}

public enum EventKitMapping {
    public static func hex(red: Double, green: Double, blue: Double) -> String {
        func c(_ v: Double) -> Int { Int((min(1, max(0, v)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(red), c(green), c(blue))
    }

    /// Google (CalDAV) sources are titled with the gmail address; local and iCloud sources keep their names.
    public static func accountName(_ s: RawSource) -> String {
        switch s.type {
        case .local: s.title.isEmpty || s.title == "Default" ? "On My Mac" : s.title
        case .subscribed: "Subscribed calendars"
        case .birthdays: "Birthdays"
        default: s.title
        }
    }

    public static func icon(for c: RawCalendar) -> CalendarKindIcon {
        switch c.type {
        case .subscription, .birthday: .feed
        default: .standard
        }
    }

    /// Groups calendars under their source, sources sorted by title (subscribed/birthdays last), calendars by title.
    /// Sources without calendars are dropped.
    public static func accounts(sources: [RawSource], calendars: [RawCalendar], defaultCalendarID: String?) -> [CalendarAccount] {
        var result: [CalendarAccount] = []
        let order: (RawSourceType) -> Int = { t in
            switch t { case .subscribed: 2; case .birthdays: 3; default: 0 }
        }
        for s in sources.sorted(by: { (order($0.type), $0.title.lowercased()) < (order($1.type), $1.title.lowercased()) }) {
            let cals = calendars.filter { $0.sourceID == s.id }.sorted {
                if ($0.id == defaultCalendarID) != ($1.id == defaultCalendarID) { return $0.id == defaultCalendarID }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }.map { c in
                CalendarInfo(id: c.id, accountID: s.id, title: c.title, colorHex: hex(red: c.red, green: c.green, blue: c.blue),
                             icon: icon(for: c), isDefault: c.id == defaultCalendarID, isVisibleByDefault: true,
                             isWritable: c.allowsContentModifications && c.type != .subscription && c.type != .birthday)
            }
            if !cals.isEmpty { result.append(CalendarAccount(id: s.id, name: accountName(s), calendars: cals)) }
        }
        return result
    }

    /// The event's own status wins for tentative/cancelled; otherwise the current user's attendee response decides.
    public static func responseStatus(myStatus: RawParticipantStatus?, eventTentative: Bool, eventCanceled: Bool) -> ResponseStatus {
        if eventCanceled { return .declined }
        switch myStatus {
        case .declined: return .declined
        case .tentative: return .tentative
        default: return eventTentative ? .tentative : .confirmed
        }
    }

    /// EventKit stores the reminder as a negative offset in seconds.
    public static func reminderMinutes(alarmOffsetSeconds: [Double]) -> Int? {
        alarmOffsetSeconds.filter { $0 <= 0 }.map { Int((-$0 / 60).rounded()) }.min()
    }
    public static func alarmOffsetSeconds(minutes: Int?) -> Double? { minutes.map { -Double($0) * 60 } }

    /// Participants shown as "Name <email>" or just the email/name. The organizer/self entry is dropped.
    public static func participantLabel(name: String?, email: String?) -> String? {
        let n = name?.trimmingCharacters(in: .whitespaces) ?? ""
        let e = email?.trimmingCharacters(in: .whitespaces) ?? ""
        if !e.isEmpty && (n.isEmpty || n == e) { return e }
        if !e.isEmpty { return "\(n) <\(e)>" }
        return n.isEmpty ? nil : n
    }

    /// Reminders and title-only tasks: EventKit has no task kind, so a leading "[P0]".."[P9]" is treated as a task style.
    public static func kind(forTitle t: String, calendarIsTasks: Bool) -> EventKind {
        if calendarIsTasks { return .task }
        return isPriorityTitle(t) ? .task : .event
    }

    public static func isPriorityTitle(_ t: String) -> Bool {
        let u = Array(t.utf8)
        return u.count >= 4 && u[0] == UInt8(ascii: "[") && u[1] == UInt8(ascii: "P") && u[3...].contains(UInt8(ascii: "]"))
    }
}
