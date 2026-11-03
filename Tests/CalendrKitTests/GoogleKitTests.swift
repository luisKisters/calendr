import Testing
import Foundation
import CalendrKit

/// The JSON fixtures in Fixtures/google (shapes of the Google Calendar and People APIs, invented data).
func googleFixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/google"))
    return try Data(contentsOf: url)
}
func googleFixture<T: Decodable>(_ name: String, as: T.Type) throws -> T { try JSONDecoder().decode(T.self, from: googleFixture(name)) }

/// v4 Phase 8b: Google JSON to events, PKCE, OAuth URLs, the sync-token state machine.
@Suite("Google mapping")
struct GoogleMappingTests {
    let berlin = TimeZone(identifier: "Europe/Berlin")!

    func events() throws -> [GEvent] {
        try googleFixture("events-page1", as: GEventsPage.self).items! + googleFixture("events-page2", as: GEventsPage.self).items!
    }
    func map(_ g: GEvent, defaults: [Int] = [10]) -> CalendarEvent? {
        GoogleMapping.event(g, id: "g:" + (g.id ?? ""), calendarID: "cal", defaultReminders: defaults, zone: berlin)
    }

    @Test func attendeesSelfOrganizerAndStatuses() throws {
        let e = try #require(map(events()[0]))
        #expect(e.title == "Flat dinner" && e.location == "Kitchen, 12 Harbour Street" && e.notes == "Everyone brings something to eat.")
        // the room is a resource, not a guest
        #expect(e.attendees.count == 5)
        let me = try #require(e.attendees.first { $0.isMe })
        #expect(me.email == "sam.rivera@example.com" && me.isOrganizer && e.iAmOrganizer && e.status == .confirmed)
        #expect(e.attendees.map(\.status) == [.confirmed, .confirmed, .tentative, .declined, .needsAction])
        #expect(e.attendees[3].name == nil && e.attendees[4].isOptional)
        #expect(EditorRows.withoutName(e.attendees) == 2)
        #expect(e.seriesID == "flatdinner" && e.isRecurring)
    }

    @Test func invitationIsUnansweredAndUsesDefaultReminders() throws {
        let e = try #require(map(events()[1], defaults: [10, 30]))
        #expect(e.status == .needsAction && e.isUnaccepted && !e.iAmOrganizer && e.organizer?.email == "jonas.weber@example.org")
        #expect(e.reminders == [10, 30])
        // "Z" and fractional seconds are both RFC 3339
        #expect(e.start == RFC3339.date("2026-10-01T17:00:00+02:00") && e.durationMinutes == 60)
    }

    @Test func conferenceDataRemindersAndColor() throws {
        let e = try #require(map(events()[0]))
        #expect(e.conferencing == "https://meet.google.com/cmv-hjhb-qgb" && CallLink.parse(e)?.kind == .meet)
        #expect(e.reminders == [10, 30, 1440])
        #expect(e.colorHex == EventColors.google.first { $0.name == "Sage" }?.hex)
        #expect(e.timeZoneID == "Europe/Berlin")
        #expect(e.start == RFC3339.date("2026-10-04T17:00:00Z"))
    }

    @Test func allDayDatesAreMidnightAndExclusive() throws {
        let e = try #require(map(events()[2]))
        var cal = Calendar(identifier: .gregorian); cal.timeZone = berlin
        #expect(e.isAllDay && e.start == cal.date(from: DateComponents(year: 2026, month: 10, day: 2)))
        #expect(e.end == cal.date(from: DateComponents(year: 2026, month: 10, day: 5)))
        #expect(e.availability == .free && e.visibility == .private && e.colorHex == "#D9443A")
    }

    @Test func recurrenceRuleAndCancelled() throws {
        let e = try #require(map(events()[3]))
        #expect(e.recurrence?.frequency == .weekly && e.recurrence?.weekdays == [1] && e.recurrence?.until != nil)
        #expect(e.seriesID == "run")
        #expect(map(GEvent(id: "x", status: "cancelled")) == nil)
        let r = try #require(e.recurrence)
        #expect(RRule.parse(RRule.format(r, zone: berlin)) == r)
    }

    @Test func colorIDsRoundTrip() {
        for id in (1...11).map(String.init) {
            let hex = GoogleColors.hex(colorId: id)
            #expect(hex != nil && GoogleColors.colorId(hex: hex!) == id)
        }
        #expect(Set((1...11).compactMap { GoogleColors.hex(colorId: String($0)) }).count == 11)
    }

    @Test func writeBodyRoundTrips() throws {
        let e = try #require(map(events()[0]))
        let body = GoogleMapping.body(e, zone: berlin, meetRequestID: "req-1")
        #expect(body.start?.dateTime == "2026-10-04T19:00:00+02:00" && body.start?.timeZone == "Europe/Berlin")
        #expect(body.conferenceData?.createRequest == GCreateRequest(requestId: "req-1", conferenceSolutionKey: GSolutionKey(type: "hangoutsMeet")))
        #expect(body.colorId == "2" && body.reminders?.useDefault == false && body.reminders?.overrides?.map(\.minutes) == [10, 30, 1440])
        let back = try #require(GoogleMapping.event(body, id: e.id, calendarID: "cal", zone: berlin))
        #expect(back.start == e.start && back.end == e.end && back.title == e.title && back.attendees.map(\.email) == e.attendees.map(\.email))
        let allDay = try #require(map(events()[2]))
        let b2 = GoogleMapping.body(allDay, zone: berlin)
        #expect(b2.start?.date == "2026-10-02" && b2.end?.date == "2026-10-05" && b2.start?.dateTime == nil)
    }

    @Test func patchHasOnlyTheChangedFields() throws {
        let e = try #require(map(events()[0]))
        var n = e
        n.title = "Flat dinner and games"
        let p = try #require(GoogleMapping.patch(old: e, new: n, zone: berlin))
        let json = String(decoding: try JSONEncoder().encode(p), as: UTF8.self)
        #expect(json == #"{"summary":"Flat dinner and games"}"#)
        #expect(GoogleMapping.patch(old: e, new: e, zone: berlin) == nil)
        n = e; n.addGuest("kim.lindqvist@example.org")
        let g = try #require(GoogleMapping.patch(old: e, new: n, zone: berlin))
        #expect(g.attendees?.count == 6 && g.summary == nil)
    }

    @Test func replyIsAPatchOfMyEntryOnly() throws {
        let e = try #require(map(events()[1]))
        var n = e
        n.status = .confirmed
        #expect(GoogleMapping.onlyReplyChanged(old: e, new: n))
        let body = GoogleMapping.rsvp(selfEmail: "sam.rivera@example.com", status: .confirmed)
        let json = String(decoding: try JSONEncoder().encode(body), as: UTF8.self)
        #expect(json.contains(#""attendeesOmitted":true"#) && json.contains(#""responseStatus":"accepted""#))
        #expect(body.attendees?.count == 1 && body.summary == nil)
        n.title = "x"
        #expect(!GoogleMapping.onlyReplyChanged(old: e, new: n))
    }

    @Test func calendarListDecodes() throws {
        let l = try googleFixture("calendar-list", as: GCalendarList.self)
        #expect(l.items?.count == 3 && l.items?[0].primary == true && l.items?[2].accessRole == "reader")
    }
}

@Suite("Google OAuth and PKCE")
struct GoogleOAuthTests {
    /// RFC 7636 Appendix B.
    @Test func pkceRFC7636Vector() {
        let bytes: [UInt8] = [116, 24, 223, 180, 151, 153, 224, 37, 79, 250, 96, 125, 216, 173, 187, 186, 22, 212, 37, 77, 105, 214, 191, 240, 91, 88, 5, 88, 83, 132, 141, 121]
        let v = PKCE.verifier(bytes: bytes)
        #expect(v == "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        #expect(PKCE.challenge(for: v) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func randomVerifierIsUnreservedAnd43Long() {
        let v = PKCE.verifier()
        #expect(v.count == 43 && v.allSatisfy { $0.isLetter || $0.isNumber || "-._~".contains($0) })
        #expect(PKCE.verifier() != v)
    }

    @Test func reversedClientIDAndRedirect() {
        let id = "1234-abcdef.apps.googleusercontent.com"
        #expect(GoogleOAuth.reversedClientID(id) == "com.googleusercontent.apps.1234-abcdef")
        #expect(GoogleOAuth.redirectURI(id) == "com.googleusercontent.apps.1234-abcdef:/oauth2redirect")
        #expect(GoogleOAuth.reversedClientID("not-a-client") == nil)
    }

    @Test func authorizationURLCarriesPKCEAndScopes() throws {
        let url = try #require(GoogleOAuth.authorizationURL(clientID: "1234-abc.apps.googleusercontent.com", challenge: "CH", state: "ST"))
        let q = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(url.host == "accounts.google.com")
        #expect(q["code_challenge"] == "CH" && q["code_challenge_method"] == "S256" && q["state"] == "ST" && q["response_type"] == "code")
        #expect(q["redirect_uri"] == "com.googleusercontent.apps.1234-abc:/oauth2redirect" && q["access_type"] == "offline")
        #expect(q["scope"]?.contains("https://www.googleapis.com/auth/calendar.events") == true && q["scope"]?.contains("contacts.other.readonly") == true)
        #expect(q["client_secret"] == nil)
    }

    @Test func codeNeedsTheSameState() {
        let u = URL(string: "com.googleusercontent.apps.1234-abc:/oauth2redirect?state=ST&code=4/xyz")!
        #expect(GoogleOAuth.code(from: u, state: "ST") == "4/xyz")
        #expect(GoogleOAuth.code(from: u, state: "other") == nil)
    }

    @Test func tokenBodies() {
        let b = String(decoding: GoogleOAuth.tokenRequestBody(code: "4/x y", verifier: "V", clientID: "1-a.apps.googleusercontent.com"), as: UTF8.self)
        #expect(b == "client_id=1-a.apps.googleusercontent.com&code=4%2Fx%20y&code_verifier=V&grant_type=authorization_code&redirect_uri=com.googleusercontent.apps.1-a%3A%2Foauth2redirect")
        let r = String(decoding: GoogleOAuth.refreshRequestBody(refreshToken: "R", clientID: "C"), as: UTF8.self)
        #expect(r == "client_id=C&grant_type=refresh_token&refresh_token=R")
    }

    @Test func idTokenEmail() {
        let payload = PKCE.base64url(Data(#"{"email":"sam.rivera@example.com","sub":"1"}"#.utf8))
        #expect(GoogleOAuth.email(fromIDToken: "h.\(payload).s") == "sam.rivera@example.com")
    }
}

@Suite("Google sync tokens")
struct GoogleSyncTests {
    @Test func fullSyncPagesThenIncremental() throws {
        var s = GoogleCalendarSync()
        let r1 = s.nextRequest()
        #expect(r1.isFull && r1.pageToken == nil)
        #expect(!s.apply(try googleFixture("events-page1", as: GEventsPage.self)))
        // a full sync is not visible until its last page
        #expect(s.items.isEmpty && s.isRunning)
        let r2 = s.nextRequest()
        #expect(r2 == .init(syncToken: nil, pageToken: "page-2"))
        #expect(s.apply(try googleFixture("events-page2", as: GEventsPage.self)))
        #expect(s.items.count == 4 && s.syncToken == "sync-1" && s.defaultReminders == [10] && !s.isRunning)
        let r3 = s.nextRequest()
        #expect(r3 == .init(syncToken: "sync-1", pageToken: nil) && !r3.isFull)
        #expect(s.apply(try googleFixture("events-incremental", as: GEventsPage.self)))
        #expect(s.items["trip"] == nil && s.items["run"]?.summary == "Sunday long run" && s.items.count == 3 && s.syncToken == "sync-2")
        #expect(s.fullSyncs == 1)
    }

    @Test func goneResetsTheStateAndSyncsInFull() throws {
        var s = GoogleCalendarSync()
        _ = s.nextRequest(); s.apply(try googleFixture("events-page1", as: GEventsPage.self))
        _ = s.nextRequest(); s.apply(try googleFixture("events-page2", as: GEventsPage.self))
        _ = s.nextRequest()
        s.gone()
        #expect(s.syncToken == nil && s.items.isEmpty && !s.isRunning)
        let r = s.nextRequest()
        #expect(r.isFull && r.pageToken == nil && s.fullSyncs == 2)
    }

    @Test func stateSurvivesTheDiskCache() throws {
        var s = GoogleCalendarSync()
        _ = s.nextRequest(); s.apply(try googleFixture("events-page1", as: GEventsPage.self))
        _ = s.nextRequest(); s.apply(try googleFixture("events-page2", as: GEventsPage.self))
        let back = try JSONDecoder().decode(GoogleCalendarSync.self, from: JSONEncoder().encode(s))
        #expect(back == s && back.syncToken == "sync-1" && back.items.count == 4)
    }

    @Test func the410ErrorBodyDecodes() throws {
        let o = try JSONSerialization.jsonObject(with: googleFixture("error-410")) as? [String: Any]
        #expect((o?["error"] as? [String: Any])?["code"] as? Int == 410)
    }
}
