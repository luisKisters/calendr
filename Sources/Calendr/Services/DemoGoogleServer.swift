import Foundation
import CalendrKit

/// A Google Calendar API stand-in for the headless tours and snapshots: it answers `calendarList`, `events.list` (with sync tokens),
/// insert, get, patch and delete from memory, seeded with the v4 fixture's account sam.rivera@example.com. No network: it is the
/// handler of a `FakeHTTPClient`. Patches merge like Google's (my reply alone with `attendeesOmitted`, a Meet `createRequest` gets a link).
final class DemoGoogleServer: @unchecked Sendable {
    static let email = "sam.rivera@example.com"
    static let room = "kitchen-room@resource.calendar.google.com"
    private let lock = NSLock()
    private var calendars: [GCalendarListEntry]
    private var events: [String: [String: GEvent]]          // calendar id -> event id -> event
    private var changed: [String: Set<String>] = [:]          // since the last sync token
    private var deleted: [String: Set<String>] = [:]
    private var tokens = 0
    private var nextID = 0

    init() {
        let zone = DemoData.math.timeZone
        let acct = DemoDataV4.accounts.first { $0.name == Self.email }!
        calendars = acct.calendars.map { c in
            GCalendarListEntry(id: c.id, summary: c.title, backgroundColor: c.colorHex, accessRole: "owner", primary: c.isDefault ? true : nil,
                               selected: true, timeZone: zone.identifier, defaultReminders: [GReminder(minutes: 10)])
        }
        var evs: [String: [String: GEvent]] = [:]
        for e in DemoDataV4.buildEvents() where acct.calendars.contains(where: { $0.id == e.calendarID }) {
            var g = GoogleMapping.body(e, zone: zone)
            let gid = String(e.id.dropFirst(3))       // "v4.wg" -> "wg"
            g.id = gid
            g.iCalUID = "\(gid)@google.com"
            g.status = "confirmed"
            g.recurrence = nil
            if let s = e.seriesID { g.recurringEventId = String(s.dropFirst("v4.series.".count)) }
            g.attendees = e.attendees.isEmpty ? nil : e.attendees.map { a in
                GAttendee(email: a.email, displayName: a.name, organizer: a.isOrganizer ? true : nil, isSelf: a.isMe ? true : nil,
                          optional: a.isOptional ? true : nil, responseStatus: GoogleMapping.responseStatus(a.status))
            }
            if let org = e.organizer { g.organizer = GPerson(email: org.email, displayName: org.name, isSelf: org.isMe ? true : nil) }
            if CallLink.parse(conferencing: e.conferencing)?.kind == .meet {
                g.conferenceData = GConferenceData(entryPoints: [GEntryPoint(entryPointType: "video", uri: e.conferencing)],
                                                   conferenceSolution: GConferenceSolution(key: GSolutionKey(type: "hangoutsMeet"), name: "Google Meet"))
                g.hangoutLink = e.conferencing
            }
            // Flat dinner books the kitchen: a resource, not a guest; it must stay on the event when the guest list changes
            if gid == "wg" { g.attendees?.append(GAttendee(email: Self.room, displayName: "Kitchen", resource: true, responseStatus: "accepted")) }
            evs[e.calendarID, default: [:]][gid] = g
        }
        events = evs
    }

    var client: FakeHTTPClient { FakeHTTPClient { [self] in self.handle($0) } }

    private func json<T: Encodable>(_ v: T, _ status: Int = 200) -> (Data, Int) { ((try? JSONEncoder().encode(v)) ?? Data(), status) }

    /// The account's Google contacts (People API): the fixture's people with a Google name, Dion Kraft (whose invitations carry only
    /// the address), and two "other contacts" (people Sam emailed).
    static let connections: [GPeoplePerson] = DemoDataV4.people.filter { !$0.contactsOnly && !["me", "svc"].contains($0.key) }
        .map { GPeoplePerson(resourceName: "people/\($0.key)", names: [GPeopleName(displayName: $0.name)], emailAddresses: [GPeopleEmail(value: $0.email)]) }
        + [GPeoplePerson(resourceName: "people/dion", names: [GPeopleName(displayName: "Dion Kraft")], emailAddresses: [GPeopleEmail(value: "dion.k@example.com")])]
    static let otherContacts: [GPeoplePerson] = [
        GPeoplePerson(resourceName: "otherContacts/pia", names: [GPeopleName(displayName: "Pia Neumann")], emailAddresses: [GPeopleEmail(value: "pia.neumann@example.net")]),
        GPeoplePerson(resourceName: "otherContacts/ola", names: [GPeopleName(displayName: "Ola Berg")], emailAddresses: [GPeopleEmail(value: "ola.berg@example.com")]),
        GPeoplePerson(resourceName: "otherContacts/x", emailAddresses: [GPeopleEmail(value: "newsletter@example.org")]),
    ]

    func handle(_ r: FakeHTTPClient.Sent) -> (Data, Int) {
        lock.lock(); defer { lock.unlock() }
        if r.url.host == GooglePeopleAPI.base.host {
            if r.path.hasSuffix("/people/me/connections") { return json(GConnectionsPage(connections: Self.connections)) }
            if r.path.hasSuffix("/otherContacts") { return json(GOtherContactsPage(otherContacts: Self.otherContacts)) }
            return (Data(), 404)
        }
        let parts = r.path.replacingOccurrences(of: GoogleCalendarAPI.base.path, with: "").split(separator: "/").map(String.init)
        if parts == ["users", "me", "calendarList"] { return json(GCalendarList(items: calendars)) }
        guard parts.count >= 3, parts[0] == "calendars", parts[2] == "events" else { return (Data(), 404) }
        let cal = parts[1]
        let body = r.body.flatMap { try? JSONDecoder().decode(GEvent.self, from: $0) }
        switch (r.method, parts.count) {
        case ("GET", 3):
            tokens += 1
            let token = "demo-sync-\(tokens)"
            if r.query["syncToken"] != nil {
                let ch = (changed[cal] ?? []).compactMap { events[cal]?[$0] } + (deleted[cal] ?? []).map { GEvent(id: $0, status: "cancelled") }
                changed[cal] = []; deleted[cal] = []
                return json(GEventsPage(items: ch, nextSyncToken: token))
            }
            changed[cal] = []; deleted[cal] = []
            return json(GEventsPage(items: Array((events[cal] ?? [:]).values).sorted { ($0.id ?? "") < ($1.id ?? "") }, nextSyncToken: token,
                                    defaultReminders: [GReminder(minutes: 10)]))
        case ("POST", 3):
            guard var g = body else { return (Data(), 400) }
            nextID += 1
            g.id = "demo\(nextID)"; g.status = "confirmed"
            if g.conferenceData?.createRequest != nil { meet(&g, id: g.id!) }
            events[cal, default: [:]][g.id!] = g
            changed[cal, default: []].insert(g.id!)
            return json(g)
        case ("GET", 4):
            guard let g = events[cal]?[parts[3]] else { return (Data(), 404) }
            return json(g)
        case ("PATCH", 4):
            guard var g = events[cal]?[parts[3]], let p = body else { return (Data(), 404) }
            merge(&g, p)
            events[cal]?[parts[3]] = g
            changed[cal, default: []].insert(parts[3])
            return json(g)
        case ("POST", 5) where parts[4] == "move":
            guard let dest = r.query["destination"], let g = events[cal]?[parts[3]] else { return (Data(), 404) }
            events[cal]?[parts[3]] = nil
            deleted[cal, default: []].insert(parts[3])
            events[dest, default: [:]][parts[3]] = g
            changed[dest, default: []].insert(parts[3])
            return json(g)
        case ("DELETE", 4):
            events[cal]?[parts[3]] = nil
            deleted[cal, default: []].insert(parts[3])
            return (Data(), 204)
        default: return (Data(), 400)
        }
    }

    private func merge(_ g: inout GEvent, _ p: GEvent) {
        if let v = p.summary { g.summary = v }
        if let v = p.description { g.description = v }
        if let v = p.location { g.location = v }
        if let v = p.start { g.start = v }
        if let v = p.end { g.end = v }
        if let v = p.reminders { g.reminders = v }
        if let v = p.colorId { g.colorId = v.isEmpty ? nil : v }
        if let v = p.transparency { g.transparency = v }
        if let v = p.visibility { g.visibility = v }
        if let v = p.recurrence { g.recurrence = v }
        if let a = p.attendees {
            if p.attendeesOmitted == true {
                // my reply only
                for x in a { if let i = g.attendees?.firstIndex(where: { $0.email?.lowercased() == x.email?.lowercased() }) { g.attendees?[i].responseStatus = x.responseStatus } }
            } else {
                let mine = g.attendees?.first { $0.isSelf == true }?.email?.lowercased()
                g.attendees = a.map { x in var y = x; if x.email?.lowercased() == mine { y.isSelf = true }; return y }
            }
        }
        if let c = p.conferenceData {
            if c.createRequest != nil { meet(&g, id: g.id ?? "x") } else { g.conferenceData = c.entryPoints == nil ? nil : c; if c.entryPoints == nil { g.hangoutLink = nil } }
        }
    }

    private func meet(_ g: inout GEvent, id: String) {
        let code = "https://meet.google.com/" + AppModel.meetCode("google:" + id)
        g.conferenceData = GConferenceData(entryPoints: [GEntryPoint(entryPointType: "video", uri: code)],
                                           conferenceSolution: GConferenceSolution(key: GSolutionKey(type: "hangoutsMeet"), name: "Google Meet"))
        g.hangoutLink = code
    }
}
