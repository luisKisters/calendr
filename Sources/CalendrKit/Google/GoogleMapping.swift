import Foundation

/// Google Calendar JSON to `CalendarEvent` and back (v4 Phase 8b). Pure: the store passes the ids, the calendar's default reminders and
/// the zone that all-day dates are read in (the app's calendar zone, so an all-day event starts at that day's midnight on the grid).
public enum GoogleMapping {
    /// The conferencing value of "Google Meet" before Google made the link: a store that can make Meet links sends a
    /// `conferenceData.createRequest` instead (and the server's link replaces this one).
    public static let newMeetLink = "https://meet.google.com/new"

    // MARK: Read

    /// Nil for a cancelled event (incremental syncs report deletions that way) and for one without a start.
    public static func event(_ g: GEvent, id: String, calendarID: String, defaultReminders: [Int] = [], zone: TimeZone, seriesPrefix: String = "") -> CalendarEvent? {
        guard g.status != "cancelled", let s = g.start, let e = g.end else { return nil }
        let allDay = s.date != nil
        guard let start = date(s, zone: zone), let end = date(e, zone: zone) else { return nil }
        // rooms and other resources are not guests (the store keeps their raw entries and sends them back on a guest-list PATCH)
        var attendees = (g.attendees ?? []).filter { $0.resource != true }.map(attendee)
        // the organizer, from `organizer` when the guest list does not mark (or list) them
        if let o = g.organizer, let mail = o.email, !mail.isEmpty, !attendees.isEmpty {
            if let i = attendees.firstIndex(where: { $0.email.lowercased() == mail.lowercased() }) {
                attendees[i].isOrganizer = true
                if o.isSelf == true { attendees[i].isMe = true }
            } else {
                attendees.insert(Attendee(email: mail, name: o.displayName, isOrganizer: true, isMe: o.isSelf ?? false, status: .confirmed), at: 0)
            }
        }
        let me = attendees.first { $0.isMe }
        // My own events without guests: I organise them, no reply to give.
        let status: ResponseStatus = me?.status ?? .confirmed
        let series = g.recurringEventId ?? (g.recurrence != nil ? g.id : nil)
        var ev = CalendarEvent(
            id: id, seriesID: series.map { seriesPrefix + $0 }, calendarID: calendarID, title: g.summary ?? "",
            start: start, end: max(end, start), isAllDay: allDay, status: status, location: g.location ?? "", notes: g.description ?? "",
            recurrence: (g.recurrence ?? []).lazy.compactMap(RRule.parse).first,
            attendees: attendees, conferencing: conferencing(g), reminders: reminders(g.reminders, defaults: defaultReminders),
            availability: g.transparency == "transparent" ? .free : .busy,
            visibility: g.visibility == "public" ? .public : (g.visibility == "private" || g.visibility == "confidential") ? .private : .standard,
            timeZoneID: s.timeZone ?? zone.identifier,
            colorHex: g.colorId.flatMap(GoogleColors.hex(colorId:)))
        ev.externalID = g.iCalUID
        return ev
    }

    /// Where a call link that is not a new Meet goes: Google ignores `conferenceData` without a `createRequest` from a client that is
    /// not a conferencing add-on, so a plain link (Zoom, Teams, a pasted Meet link) is kept in the location when that is empty, else
    /// at the end of the description. The call row finds it there (`CallLink` reads the notes and the location).
    public static func placedLink(_ e: CalendarEvent) -> (location: String, notes: String) {
        let link = e.conferencing.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty, link != newMeetLink, !e.location.contains(link), !e.notes.contains(link) else { return (e.location, e.notes) }
        if e.location.trimmingCharacters(in: .whitespaces).isEmpty { return (link, e.notes) }
        return (e.location, e.notes.isEmpty ? link : e.notes + "\n\n" + link)
    }

    public static func attendee(_ a: GAttendee) -> Attendee {
        let n = a.displayName?.trimmingCharacters(in: .whitespaces)
        return Attendee(email: a.email ?? "", name: (n?.isEmpty ?? true) ? nil : n, isOrganizer: a.organizer ?? false, isMe: a.isSelf ?? false,
                        isOptional: a.optional ?? false, status: status(a.responseStatus))
    }

    public static func status(_ s: String?) -> ResponseStatus {
        switch s {
        case "accepted": .confirmed
        case "tentative": .tentative
        case "declined": .declined
        default: .needsAction
        }
    }

    public static func responseStatus(_ s: ResponseStatus) -> String {
        switch s {
        case .confirmed: "accepted"
        case .tentative: "tentative"
        case .declined: "declined"
        case .needsAction: "needsAction"
        }
    }

    /// The video entry point (Meet, or a third-party add-on's), else the legacy `hangoutLink`.
    public static func conferencing(_ g: GEvent) -> String {
        if let v = g.conferenceData?.entryPoints?.first(where: { $0.entryPointType == "video" })?.uri { return v }
        return g.hangoutLink ?? ""
    }

    /// `useDefault` takes the calendar's default reminders; otherwise the overrides (popup and email alike: minutes before the start).
    public static func reminders(_ r: GReminders?, defaults: [Int]) -> [Int] {
        guard let r else { return defaults }
        if r.useDefault == true { return defaults }
        return (r.overrides ?? []).map(\.minutes)
    }

    public static func date(_ d: GDateTime, zone: TimeZone) -> Date? {
        if let s = d.dateTime { return RFC3339.date(s) }
        if let s = d.date { return RFC3339.day(s, zone: zone) }
        return nil
    }

    // MARK: Write

    /// The whole event as an insert body. `meetRequestID`: ask Google for a new Meet link (send with `conferenceDataVersion=1`).
    public static func body(_ e: CalendarEvent, zone: TimeZone, meetRequestID: String? = nil) -> GEvent {
        var g = GEvent()
        let placed = placedLink(e)
        g.summary = e.title; g.description = placed.notes; g.location = placed.location
        (g.start, g.end) = times(e, zone: zone)
        if !e.attendees.isEmpty { g.attendees = e.attendees.filter { !$0.email.isEmpty }.map(gAttendee) }
        g.reminders = GReminders(useDefault: false, overrides: e.reminders.map { GReminder(minutes: $0) })
        g.colorId = e.colorHex.flatMap(GoogleColors.colorId(hex:))
        g.transparency = e.availability == .free ? "transparent" : "opaque"
        g.visibility = switch e.visibility { case .standard: "default"; case .public: "public"; case .private: "private" }
        if let id = meetRequestID { g.conferenceData = GConferenceData(createRequest: GCreateRequest(requestId: id, conferenceSolutionKey: GSolutionKey(type: "hangoutsMeet"))) }
        if let r = e.recurrence { g.recurrence = [RRule.format(r, zone: zone)] }
        return g
    }

    /// A PATCH body with only what changed between two versions of an event, or nil when nothing Google stores changed.
    /// My reply is not in it: that is `rsvp` (a patch of my own attendee entry only).
    /// `resources`: the event's raw room and resource entries, sent back with a changed guest list so the room stays booked.
    public static func patch(old: CalendarEvent, new: CalendarEvent, zone: TimeZone, meetRequestID: String? = nil, resources: [GAttendee] = []) -> GEvent? {
        var g = GEvent()
        var any = false
        func set<T: Equatable>(_ a: T, _ b: T, _ apply: () -> Void) { if a != b { apply(); any = true } }
        // a new plain call link lands in the location or the notes (`placedLink`)
        let placed: (location: String, notes: String) = old.conferencing != new.conferencing ? placedLink(new) : (new.location, new.notes)
        set(old.title, new.title) { g.summary = new.title }
        set(old.notes, placed.notes) { g.description = placed.notes }
        set(old.location, placed.location) { g.location = placed.location }
        if old.start != new.start || old.end != new.end || old.isAllDay != new.isAllDay { (g.start, g.end) = times(new, zone: zone); any = true }
        let guests = { (e: CalendarEvent) in e.attendees.map { [$0.email.lowercased(), $0.name ?? "", "\($0.isOptional)"] } }
        if guests(old) != guests(new) {
            // my own entry keeps my reply as it is stored: the reply goes through `rsvp`
            g.attendees = new.attendees.filter { !$0.email.isEmpty }.map { a in
                var x = gAttendee(a)
                if a.isMe { x.responseStatus = responseStatus(old.status) }
                return x
            } + resources.filter { $0.resource == true }
            any = true
        }
        set(old.reminders, new.reminders) { g.reminders = GReminders(useDefault: false, overrides: new.reminders.map { GReminder(minutes: $0) }) }
        set(old.colorHex, new.colorHex) { g.colorId = new.colorHex.flatMap(GoogleColors.colorId(hex:)) ?? "" }
        set(old.availability, new.availability) { g.transparency = new.availability == .free ? "transparent" : "opaque" }
        set(old.visibility, new.visibility) { g.visibility = switch new.visibility { case .standard: "default"; case .public: "public"; case .private: "private" } }
        // only a new Meet goes in `conferenceData` (with `conferenceDataVersion=1`); removing Google's own Meet is not sent
        if let id = meetRequestID {
            g.conferenceData = GConferenceData(createRequest: GCreateRequest(requestId: id, conferenceSolutionKey: GSolutionKey(type: "hangoutsMeet"))); any = true
        }
        return any ? g : nil
    }

    /// My reply: a PATCH with my own attendee entry only (`attendeesOmitted`), so the rest of the guest list stays as Google has it.
    public static func rsvp(selfEmail: String, status: ResponseStatus) -> GEvent {
        GEvent(attendees: [GAttendee(email: selfEmail, responseStatus: responseStatus(status))], attendeesOmitted: true)
    }

    /// True when the only difference is my reply.
    public static func onlyReplyChanged(old: CalendarEvent, new: CalendarEvent) -> Bool {
        guard old.status != new.status else { return false }
        var o = old
        o.status = new.status
        return o == new
    }

    static func gAttendee(_ a: Attendee) -> GAttendee {
        GAttendee(email: a.email, displayName: a.name, organizer: a.isOrganizer ? true : nil, isSelf: nil, optional: a.isOptional ? true : nil,
                  responseStatus: responseStatus(a.status))
    }

    static func times(_ e: CalendarEvent, zone: TimeZone) -> (GDateTime, GDateTime) {
        if e.isAllDay { return (GDateTime(date: RFC3339.dayString(e.start, zone: zone)), GDateTime(date: RFC3339.dayString(e.end, zone: zone))) }
        let tz = TimeZone(identifier: e.timeZoneID) ?? zone
        return (GDateTime(dateTime: RFC3339.string(e.start, zone: tz), timeZone: tz.identifier), GDateTime(dateTime: RFC3339.string(e.end, zone: tz), timeZone: tz.identifier))
    }
}

/// Google's 11 event colours (`colorId` 1...11) as the app's swatches (`EventColors.google`). Google's "Basil" is the swatch "Mint".
public enum GoogleColors {
    public static let names: [String: String] = [
        "1": "Lavender", "2": "Sage", "3": "Grape", "4": "Flamingo", "5": "Banana", "6": "Tangerine",
        "7": "Peacock", "8": "Graphite", "9": "Blueberry", "10": "Mint", "11": "Tomato",
    ]
    public static func hex(colorId: String) -> String? {
        names[colorId].flatMap { n in EventColors.google.first { $0.name == n }?.hex }
    }
    public static func colorId(hex: String) -> String? {
        guard let n = EventColors.google.first(where: { $0.hex.caseInsensitiveCompare(hex) == .orderedSame })?.name else { return nil }
        return names.first { $0.value == n }?.key
    }
}

/// RFC 3339 times ("2026-10-04T19:00:00+02:00", "...Z", with or without fractions) and all-day dates ("2026-10-04").
public enum RFC3339 {
    public static func date(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s)
    }

    public static func string(_ d: Date, zone: TimeZone) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = zone
        return f.string(from: d)
    }

    /// Midnight of that day in `zone`.
    public static func day(_ s: String, zone: TimeZone) -> Date? {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        return cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    public static func dayString(_ d: Date, zone: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// The RRULE subset the editor shows: FREQ, INTERVAL, BYDAY (plain weekdays), UNTIL.
public enum RRule {
    static let days = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]

    public static func parse(_ line: String) -> Recurrence? {
        guard line.hasPrefix("RRULE:") else { return nil }
        var kv: [String: String] = [:]
        for part in line.dropFirst(6).split(separator: ";") {
            let p = part.split(separator: "=", maxSplits: 1).map(String.init)
            if p.count == 2 { kv[p[0]] = p[1] }
        }
        guard let f = kv["FREQ"].flatMap({ Recurrence.Frequency(rawValue: $0.lowercased()) }) else { return nil }
        let weekdays = (kv["BYDAY"] ?? "").split(separator: ",").compactMap { d in days.firstIndex(of: String(d.suffix(2))).map { $0 + 1 } }
        var until: Date?
        if let u = kv["UNTIL"] {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = u.count > 8 ? "yyyyMMdd'T'HHmmss'Z'" : "yyyyMMdd"
            until = f.date(from: u)
        }
        return Recurrence(frequency: f, interval: Int(kv["INTERVAL"] ?? "") ?? 1, weekdays: weekdays, until: until)
    }

    public static func format(_ r: Recurrence, zone: TimeZone) -> String {
        var parts = ["FREQ=\(r.frequency.rawValue.uppercased())"]
        if r.interval > 1 { parts.append("INTERVAL=\(r.interval)") }
        if !r.weekdays.isEmpty { parts.append("BYDAY=" + r.weekdays.compactMap { (1...7).contains($0) ? days[$0 - 1] : nil }.joined(separator: ",")) }
        if let u = r.until {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC"); f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            parts.append("UNTIL=" + f.string(from: u))
        }
        return "RRULE:" + parts.joined(separator: ";")
    }
}
