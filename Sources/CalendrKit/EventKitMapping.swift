import Foundation

// Pure mirror types of the EventKit objects the adapter reads. The adapter in the app target only copies
// fields into these; every decision (grouping, colors, status, icons) lives here and is tested.

public enum RawSourceType: Sendable { case local, exchange, calDAV, mobileMe, subscribed, birthdays }
public enum RawCalendarType: Sendable { case local, calDAV, exchange, subscription, birthday }
public enum RawParticipantStatus: Sendable { case unknown, pending, accepted, declined, tentative, delegated, completed, inProcess }

public enum RawParticipantRole: Sendable { case unknown, required, optional, chair, nonParticipant }

/// An `EKParticipant` as plain data. `email` is the `mailto:` address, or nil when the URL is not one.
public struct RawParticipant: Sendable {
    public var name: String?, email: String?, isCurrentUser: Bool, role: RawParticipantRole, status: RawParticipantStatus
    public init(name: String?, email: String?, isCurrentUser: Bool = false, role: RawParticipantRole = .required, status: RawParticipantStatus = .unknown) {
        self.name = name; self.email = email; self.isCurrentUser = isCurrentUser; self.role = role; self.status = status
    }
}

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

    /// A cancelled event reads as declined. The organizer's own events are accepted. Otherwise the current user's answer decides:
    /// `pending` (invited, not answered) is `needsAction`, but only when I am on the guest list (`myStatus` not nil).
    /// The event's own tentative flag applies when I have not said no or maybe.
    public static func responseStatus(myStatus: RawParticipantStatus?, iAmOrganizer: Bool = false, eventTentative: Bool, eventCanceled: Bool) -> ResponseStatus {
        if eventCanceled { return .declined }
        if iAmOrganizer { return eventTentative ? .tentative : .confirmed }
        switch myStatus {
        case .declined: return .declined
        case .tentative: return .tentative
        case .pending: return .needsAction
        default: return eventTentative ? .tentative : .confirmed
        }
    }

    /// One guest's answer. Not answered (or unknown) is `needsAction`.
    public static func status(of p: RawParticipantStatus) -> ResponseStatus {
        switch p {
        case .accepted, .completed, .delegated: .confirmed
        case .declined: .declined
        case .tentative: .tentative
        case .unknown, .pending, .inProcess: .needsAction
        }
    }

    /// The guest list from the attendees and the organizer (which EventKit keeps apart; it may or may not be among the attendees).
    /// The organizer comes first and counts as accepted. Entries without an address or a name are dropped.
    public static func attendees(_ raw: [RawParticipant], organizer: RawParticipant?) -> [Attendee] {
        func clean(_ s: String?) -> String { s?.trimmingCharacters(in: .whitespaces) ?? "" }
        func key(_ p: RawParticipant) -> String { clean(p.email).lowercased() }
        var out: [Attendee] = []
        if let o = organizer, !(clean(o.email).isEmpty && clean(o.name).isEmpty) {
            let same = raw.first { !key($0).isEmpty && key($0) == key(o) }
            out.append(Attendee(email: clean(o.email), name: clean(o.name).isEmpty ? nil : clean(o.name), isOrganizer: true,
                                isMe: o.isCurrentUser || same?.isCurrentUser == true, isOptional: false, status: .confirmed))
        }
        for p in raw where !(clean(p.email).isEmpty && clean(p.name).isEmpty) {
            if let o = organizer, !key(p).isEmpty, key(p) == key(o) { continue }
            let n = clean(p.name)
            out.append(Attendee(email: clean(p.email), name: n.isEmpty || n == clean(p.email) ? nil : n,
                                isOrganizer: p.role == .chair && organizer == nil, isMe: p.isCurrentUser, isOptional: p.role == .optional,
                                status: status(of: p.status)))
        }
        return out
    }

    /// EventKit stores reminders as offsets in seconds, negative before the start. Alarms after the start are dropped.
    public static func reminders(alarmOffsetSeconds: [Double]) -> [Int] {
        Array(Set(alarmOffsetSeconds.filter { $0 <= 0 }.map { Int((-$0 / 60).rounded()) })).sorted()
    }
    /// The smallest reminder, or nil.
    public static func reminderMinutes(alarmOffsetSeconds: [Double]) -> Int? { reminders(alarmOffsetSeconds: alarmOffsetSeconds).first }
    public static func alarmOffsetSeconds(minutes: Int?) -> Double? { minutes.map { -Double($0) * 60 } }
    /// One alarm offset per reminder.
    public static func alarmOffsets(reminders: [Int]) -> [Double] { reminders.map { -Double($0) * 60 } }

    /// Participants shown as "Name <email>" or just the email/name. The organizer/self entry is dropped.
    public static func participantLabel(name: String?, email: String?) -> String? {
        let n = name?.trimmingCharacters(in: .whitespaces) ?? ""
        let e = email?.trimmingCharacters(in: .whitespaces) ?? ""
        if !e.isEmpty && (n.isEmpty || n == e) { return e }
        if !e.isEmpty { return "\(n) <\(e)>" }
        return n.isEmpty ? nil : n
    }
}
