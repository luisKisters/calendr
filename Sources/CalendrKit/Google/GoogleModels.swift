import Foundation

// The Google Calendar API v3 JSON this app reads and writes (https://developers.google.com/calendar/api/v3/reference/events).
// Every field is optional: Google leaves out what is not set, and a PATCH body sends only the fields it changes
// (`JSONEncoder` skips nil optionals).

public struct GDateTime: Codable, Hashable, Sendable {
    /// RFC 3339 with an offset, for timed events: "2026-10-04T19:00:00+02:00".
    public var dateTime: String?
    /// "yyyy-mm-dd", for all-day events. The end date is exclusive.
    public var date: String?
    public var timeZone: String?
    public init(dateTime: String? = nil, date: String? = nil, timeZone: String? = nil) { self.dateTime = dateTime; self.date = date; self.timeZone = timeZone }
}

public struct GAttendee: Codable, Hashable, Sendable {
    public var email: String?
    public var displayName: String?
    public var organizer: Bool?
    /// The authenticated user's own entry (`self` in the JSON).
    public var isSelf: Bool?
    public var optional: Bool?
    public var resource: Bool?
    /// "needsAction", "declined", "tentative", "accepted"
    public var responseStatus: String?
    enum CodingKeys: String, CodingKey { case email, displayName, organizer, isSelf = "self", optional, resource, responseStatus }
    public init(email: String? = nil, displayName: String? = nil, organizer: Bool? = nil, isSelf: Bool? = nil, optional: Bool? = nil,
                resource: Bool? = nil, responseStatus: String? = nil) {
        self.email = email; self.displayName = displayName; self.organizer = organizer; self.isSelf = isSelf; self.optional = optional
        self.resource = resource; self.responseStatus = responseStatus
    }
}

public struct GPerson: Codable, Hashable, Sendable {
    public var email: String?
    public var displayName: String?
    public var isSelf: Bool?
    enum CodingKeys: String, CodingKey { case email, displayName, isSelf = "self" }
    public init(email: String? = nil, displayName: String? = nil, isSelf: Bool? = nil) { self.email = email; self.displayName = displayName; self.isSelf = isSelf }
}

public struct GReminder: Codable, Hashable, Sendable {
    public var method: String?
    public var minutes: Int
    public init(method: String? = "popup", minutes: Int) { self.method = method; self.minutes = minutes }
}

public struct GReminders: Codable, Hashable, Sendable {
    public var useDefault: Bool?
    public var overrides: [GReminder]?
    public init(useDefault: Bool? = nil, overrides: [GReminder]? = nil) { self.useDefault = useDefault; self.overrides = overrides }
}

public struct GEntryPoint: Codable, Hashable, Sendable {
    /// "video", "phone", "sip", "more"
    public var entryPointType: String?
    public var uri: String?
    public var label: String?
    public init(entryPointType: String? = nil, uri: String? = nil, label: String? = nil) { self.entryPointType = entryPointType; self.uri = uri; self.label = label }
}

public struct GSolutionKey: Codable, Hashable, Sendable {
    /// "hangoutsMeet" for a new Meet link.
    public var type: String
    public init(type: String) { self.type = type }
}

public struct GCreateRequest: Codable, Hashable, Sendable {
    public var requestId: String
    public var conferenceSolutionKey: GSolutionKey
    public init(requestId: String, conferenceSolutionKey: GSolutionKey) { self.requestId = requestId; self.conferenceSolutionKey = conferenceSolutionKey }
}

public struct GConferenceSolution: Codable, Hashable, Sendable {
    public var key: GSolutionKey?
    public var name: String?
    public init(key: GSolutionKey? = nil, name: String? = nil) { self.key = key; self.name = name }
}

public struct GConferenceData: Codable, Hashable, Sendable {
    public var entryPoints: [GEntryPoint]?
    public var conferenceSolution: GConferenceSolution?
    public var conferenceId: String?
    /// Asks Google for a new conference (needs `conferenceDataVersion=1` on the request).
    public var createRequest: GCreateRequest?
    public init(entryPoints: [GEntryPoint]? = nil, conferenceSolution: GConferenceSolution? = nil, conferenceId: String? = nil, createRequest: GCreateRequest? = nil) {
        self.entryPoints = entryPoints; self.conferenceSolution = conferenceSolution; self.conferenceId = conferenceId; self.createRequest = createRequest
    }
}

public struct GEvent: Codable, Hashable, Sendable {
    public var id: String?
    /// "confirmed", "tentative", "cancelled" (a deleted event, in incremental syncs)
    public var status: String?
    public var summary: String?
    public var description: String?
    public var location: String?
    public var start: GDateTime?
    public var end: GDateTime?
    public var attendees: [GAttendee]?
    /// Set on a PATCH that sends only my own attendee entry: my reply, nothing else of the guest list.
    public var attendeesOmitted: Bool?
    public var organizer: GPerson?
    public var conferenceData: GConferenceData?
    public var hangoutLink: String?
    public var reminders: GReminders?
    /// "1" ... "11"
    public var colorId: String?
    /// The series an instance belongs to (with `singleEvents=true`).
    public var recurringEventId: String?
    /// RRULE / EXDATE lines of a series' main event.
    public var recurrence: [String]?
    /// "opaque" (busy) or "transparent" (free)
    public var transparency: String?
    /// "default", "public", "private", "confidential"
    public var visibility: String?
    public var guestsCanModify: Bool?
    public var updated: String?

    public init(id: String? = nil, status: String? = nil, summary: String? = nil, description: String? = nil, location: String? = nil,
                start: GDateTime? = nil, end: GDateTime? = nil, attendees: [GAttendee]? = nil, attendeesOmitted: Bool? = nil,
                organizer: GPerson? = nil, conferenceData: GConferenceData? = nil, hangoutLink: String? = nil, reminders: GReminders? = nil,
                colorId: String? = nil, recurringEventId: String? = nil, recurrence: [String]? = nil, transparency: String? = nil,
                visibility: String? = nil, guestsCanModify: Bool? = nil, updated: String? = nil) {
        self.id = id; self.status = status; self.summary = summary; self.description = description; self.location = location
        self.start = start; self.end = end; self.attendees = attendees; self.attendeesOmitted = attendeesOmitted; self.organizer = organizer
        self.conferenceData = conferenceData; self.hangoutLink = hangoutLink; self.reminders = reminders; self.colorId = colorId
        self.recurringEventId = recurringEventId; self.recurrence = recurrence; self.transparency = transparency; self.visibility = visibility
        self.guestsCanModify = guestsCanModify; self.updated = updated
    }
}

/// One page of `events.list`. The last page carries `nextSyncToken`; the others `nextPageToken`.
public struct GEventsPage: Codable, Hashable, Sendable {
    public var items: [GEvent]?
    public var nextPageToken: String?
    public var nextSyncToken: String?
    public var timeZone: String?
    public var defaultReminders: [GReminder]?
    public init(items: [GEvent]? = nil, nextPageToken: String? = nil, nextSyncToken: String? = nil, timeZone: String? = nil, defaultReminders: [GReminder]? = nil) {
        self.items = items; self.nextPageToken = nextPageToken; self.nextSyncToken = nextSyncToken; self.timeZone = timeZone; self.defaultReminders = defaultReminders
    }
}

public struct GCalendarListEntry: Codable, Hashable, Sendable {
    public var id: String
    public var summary: String?
    public var summaryOverride: String?
    public var backgroundColor: String?
    public var colorId: String?
    /// "owner", "writer", "reader", "freeBusyReader"
    public var accessRole: String?
    public var primary: Bool?
    public var selected: Bool?
    public var hidden: Bool?
    public var timeZone: String?
    public var defaultReminders: [GReminder]?
    public init(id: String, summary: String? = nil, summaryOverride: String? = nil, backgroundColor: String? = nil, colorId: String? = nil,
                accessRole: String? = nil, primary: Bool? = nil, selected: Bool? = nil, hidden: Bool? = nil, timeZone: String? = nil,
                defaultReminders: [GReminder]? = nil) {
        self.id = id; self.summary = summary; self.summaryOverride = summaryOverride; self.backgroundColor = backgroundColor; self.colorId = colorId
        self.accessRole = accessRole; self.primary = primary; self.selected = selected; self.hidden = hidden; self.timeZone = timeZone
        self.defaultReminders = defaultReminders
    }
}

public struct GCalendarList: Codable, Hashable, Sendable {
    public var items: [GCalendarListEntry]?
    public var nextPageToken: String?
    public init(items: [GCalendarListEntry]? = nil, nextPageToken: String? = nil) { self.items = items; self.nextPageToken = nextPageToken }
}
