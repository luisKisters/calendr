import Testing
import Foundation
import CalendrKit
@testable import Calendr

/// v4 Phase 8b: GoogleStore against a fake HTTP client (DemoGoogleServer: the v4 fixture's sam.rivera@example.com). No network.
@MainActor
@Suite("Google store")
struct GoogleStoreTests {
    let zone = DemoData.math.timeZone

    /// A store on the demo server, synced. `wrap` may answer some requests itself (a 410, an error).
    func store(_ wrap: (@Sendable (FakeHTTPClient.Sent) -> (Data, Int)?)? = nil) async -> (GoogleStore, FakeHTTPClient) {
        let server = DemoGoogleServer()
        let http = FakeHTTPClient { s in wrap?(s) ?? server.handle(s) }
        let s = GoogleStore(email: DemoGoogleServer.email, api: GoogleCalendarAPI(http: http, token: { "test-token" }), zone: zone)
        s.deliver = GoogleStore.taskDeliver
        s.sync()
        await s.idle()
        return (s, http)
    }
    func event(_ s: GoogleStore, _ gid: String) -> CalendarEvent? { s.searchCorpus(around: .now).first { $0.id.hasSuffix("/\(gid)") } }

    @Test func syncMapsTheAccount() async {
        let (s, http) = await store()
        #expect(s.accounts.first?.calendars.map(\.title) == ["Personal", "Family", "Tasks", "Running club"])
        #expect(s.defaultCalendarID == "google:sam.rivera@example.com/v4.personal")
        let wg = event(s, "wg")
        #expect(wg?.title == "Flat dinner" && wg?.iAmOrganizer == true && wg?.attendees.count == 5 && CallLink.parse(wg!)?.kind == .meet)
        #expect(http.sent.first?.path.hasSuffix("/users/me/calendarList") == true)
        #expect(http.sent.contains { $0.query["singleEvents"] == "true" && $0.query["syncToken"] == nil })
        #expect(s.canSendUpdates && s.canRespond && s.canEditParticipants)
    }

    @Test func replyPatchesMyEntryOnly() async throws {
        let (s, http) = await store()
        var e = try #require(event(s, "w8"))          // Family dinner: Nina invited me, not answered
        #expect(e.status == .needsAction && !e.iAmOrganizer)
        e.status = .confirmed
        try s.update(e, span: .this)
        await s.idle()
        let p = try #require(http.sent.last { $0.method == "PATCH" })
        #expect(p.path.hasSuffix("/events/w8") && p.query["sendUpdates"] == nil)
        let atts = p.json?["attendees"] as? [[String: Any]]
        #expect(atts?.count == 1 && atts?.first?["email"] as? String == "sam.rivera@example.com" && atts?.first?["responseStatus"] as? String == "accepted")
        #expect(p.json?["attendeesOmitted"] as? Bool == true && p.json?["summary"] == nil)
        #expect(event(s, "w8")?.status == .confirmed)
        #expect(s.requestLog.last?.hasPrefix("PATCH /calendars/…/events/w8") == true)
    }

    @Test func sendUpdateAllAndSaveWithoutSendingNone() async throws {
        let (s, http) = await store()
        var e = try #require(event(s, "wg"))
        e.title = "Flat dinner and games"
        try s.update(e, span: .this, notify: true)
        await s.idle()
        var p = try #require(http.sent.last { $0.method == "PATCH" })
        #expect(p.query["sendUpdates"] == "all" && p.json?["summary"] as? String == "Flat dinner and games" && p.json?["location"] == nil)
        e.location = "Market Hall"
        try s.update(e, span: .this, notify: false)
        await s.idle()
        p = try #require(http.sent.last { $0.method == "PATCH" })
        #expect(p.query["sendUpdates"] == "none" && p.json?.keys.sorted() == ["location"])
        #expect(event(s, "wg")?.title == "Flat dinner and games" && event(s, "wg")?.location == "Market Hall")
    }

    @Test func guestsAreWritten() async throws {
        let (s, http) = await store()
        var e = try #require(event(s, "wg"))
        e.addGuest("Kim Lindqvist <kim.lindqvist@example.org>")
        try s.update(e, span: .this, notify: true)
        await s.idle()
        let p = try #require(http.sent.last { $0.method == "PATCH" })
        let mails = (p.json?["attendees"] as? [[String: Any]])?.compactMap { $0["email"] as? String }
        #expect(mails?.count == 6 && mails?.last == "kim.lindqvist@example.org")
        #expect(event(s, "wg")?.attendees.contains { $0.email == "kim.lindqvist@example.org" && $0.name == "Kim Lindqvist" } == true)
    }

    @Test func newMeetLinkUsesConferenceDataVersion1() async throws {
        let (s, http) = await store()
        var e = try #require(event(s, "g1"))     // Long run: no call
        e.conferencing = GoogleMapping.newMeetLink
        try s.update(e, span: .this, notify: false)
        await s.idle()
        let p = try #require(http.sent.last { $0.method == "PATCH" })
        #expect(p.query["conferenceDataVersion"] == "1")
        let cr = (p.json?["conferenceData"] as? [String: Any])?["createRequest"] as? [String: Any]
        #expect((cr?["conferenceSolutionKey"] as? [String: Any])?["type"] as? String == "hangoutsMeet" && cr?["requestId"] != nil)
        // the server's link replaces the placeholder
        let link = try #require(event(s, "g1")?.conferencing)
        #expect(link != GoogleMapping.newMeetLink && CallLink.parse(conferencing: link)?.kind == .meet)
    }

    @Test func createAndDeleteChooseWhetherGuestsHear() async throws {
        let (s, http) = await store()
        let cal = "google:sam.rivera@example.com/v4.personal"
        let start = DemoDataV4.now.addingTimeInterval(3600)
        let made = try s.create(CalendarEvent(calendarID: cal, title: "Planning", start: start, end: start.addingTimeInterval(1800),
                                              attendees: [Attendee(email: "sam.rivera@example.com", isOrganizer: true, isMe: true, status: .confirmed),
                                                          Attendee(email: "mara.hoffmann@example.com")]), notify: true)
        #expect(made.id.contains("/local-"))
        await s.idle()
        let post = try #require(http.sent.last { $0.method == "POST" })
        #expect(post.query["sendUpdates"] == "all" && post.json?["summary"] as? String == "Planning")
        let saved = try #require(s.searchCorpus(around: .now).first { $0.title == "Planning" })
        #expect(!saved.id.contains("/local-"))
        try s.delete(saved, span: .this, notify: false)
        await s.idle()
        let del = try #require(http.sent.last { $0.method == "DELETE" })
        #expect(del.query["sendUpdates"] == "none" && s.searchCorpus(around: .now).first { $0.title == "Planning" } == nil)
    }

    @Test func goneTriggersAFullResync() async throws {
        let first = LockedFlag()
        let (s, http) = await store { r in
            // the first incremental request gets 410 Gone
            if r.query["syncToken"] != nil && first.take() { return (Data(#"{"error":{"code":410}}"#.utf8), 410) }
            return nil
        }
        let before = http.sent.filter { $0.path.hasSuffix("/events") && $0.query["syncToken"] == nil }.count
        s.sync()
        await s.idle()
        let gets = http.sent.filter { $0.path.hasSuffix("/events") }
        #expect(gets.contains { $0.query["syncToken"] != nil })
        // the calendar that got 410 synced in full again (with a time window)
        let full = gets.filter { $0.query["syncToken"] == nil }
        #expect(full.count == before + 1 && full.last?.query["timeMin"] != nil)
        #expect(event(s, "wg") != nil && s.lastError == nil)
    }

    @Test func failedWriteRestoresTheEvent() async throws {
        let (s, _) = await store { r in r.method == "PATCH" ? (Data(), 500) : nil }
        var errors: [String] = []
        s.onError = { errors.append($0) }
        var e = try #require(event(s, "wg"))
        e.title = "Nope"
        try s.update(e, span: .this, notify: true)
        #expect(event(s, "wg")?.title == "Nope")      // at once, locally
        await s.idle()
        #expect(event(s, "wg")?.title == "Flat dinner" && errors.count == 1)
    }

    @Test func diskCacheShowsEventsBeforeTheFirstSync() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("calendr-google-\(UUID().uuidString)")
        let url = dir.appendingPathComponent("cache.json")
        let server = DemoGoogleServer()
        let s = GoogleStore(email: DemoGoogleServer.email, api: GoogleCalendarAPI(http: server.client, token: { "t" }), zone: zone, cacheURL: url)
        s.deliver = GoogleStore.taskDeliver
        s.sync(); await s.idle()
        let offline = GoogleStore(email: DemoGoogleServer.email, api: GoogleCalendarAPI(http: FakeHTTPClient { _ in (Data(), 503) }, token: { "t" }), zone: zone, cacheURL: url)
        #expect(offline.searchCorpus(around: .now).count == s.searchCorpus(around: .now).count && offline.accounts == s.accounts)
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: CompositeStore

    @Test func compositeHidesTheCalDAVDuplicateAndRoutesWrites() async throws {
        let base = DemoStore(fixture: .v4)
        let c = CompositeStore(base: base)
        let (g, http) = await store()
        #expect(c.accounts.map(\.name) == ["sam.rivera@example.com", "sam@northwind.example", "sam@sideproject.example"])
        c.add(g)
        // EventKit's copy of the Google account is hidden; the Google account comes from the API
        #expect(c.accounts.map(\.name) == ["sam@northwind.example", "sam@sideproject.example", "sam.rivera@example.com"])
        #expect(c.hiddenBaseAccounts.map(\.name) == ["sam.rivera@example.com"])
        let week = DateInterval(start: DemoDataV4.weekStart, duration: 7 * 86400)
        let titles = c.events(in: week).filter { $0.title == "Flat dinner" }
        #expect(titles.count == 1 && titles[0].id.hasPrefix("google:"))
        // capabilities per calendar: Google yes; the base store (demo here, EventKit in the app) its own
        base.canSendUpdates = false; base.canRespond = false
        #expect(c.canSendUpdates(calendarID: g.defaultCalendarID!) && !c.canSendUpdates(calendarID: DemoDataV4.work))
        #expect(c.canRespond(calendarID: g.defaultCalendarID!) && !c.canRespond(calendarID: DemoDataV4.work))
        var e = titles[0]
        e.title = "Flat dinner, routed"
        try c.update(e, span: .this, notify: true)
        await g.idle()
        #expect(http.sent.last?.method == "PATCH")
        var w = try #require(c.events(in: week).first { $0.calendarID == DemoDataV4.work })
        w.title = "Work, routed"
        try c.update(w, span: .this)
        #expect(base.events(in: week).contains { $0.title == "Work, routed" })
        c.remove(email: DemoGoogleServer.email)
        #expect(c.accounts.count == 3 && c.events(in: week).contains { $0.title == "Flat dinner" && !$0.id.hasPrefix("google:") })
    }

    // MARK: Accounts and config

    @Test func connectWithoutClientIDExplainsAndDoesNothing() {
        let m = makeModelV4()
        m.connectGoogle()
        #expect(m.services.google.showsClientIDNote && m.services.google.accounts.isEmpty)
        #expect(m.toast?.text == "A Google client ID is needed first")
    }

    @Test func configReadsOnlyARealClientID() {
        #expect(GoogleConfig.load(info: nil, env: [:]).clientID == nil)
        #expect(GoogleConfig.load(info: ["CalendrGoogleClientID": ""], env: [:]).clientID == nil)
        #expect(GoogleConfig.load(info: ["CalendrGoogleClientID": "$(GOOGLE_ID)"], env: [:]).clientID == nil)
        let c = GoogleConfig.load(info: nil, env: ["CALENDR_GOOGLE_CLIENT_ID": "1234-abc.apps.googleusercontent.com"])
        #expect(c.clientID == "1234-abc.apps.googleusercontent.com" && c.callbackScheme == "com.googleusercontent.apps.1234-abc")
    }

    @Test func modelUsesThePerCalendarCapabilities() {
        let base = DemoStore(fixture: .v4)
        base.canSendUpdates = false; base.canRespond = false
        let o = LaunchOptions.parse(["Calendr", "--fixture", "v4", "--freeze-clock"])
        let m = AppModel(store: CompositeStore(base: base), options: o, persist: false)
        let g = m.connectDemoGoogle()
        #expect(g != nil && m.services.google.accounts.map(\.email) == ["sam.rivera@example.com"])
        let flat = m.store.searchCorpus(around: m.now).first { $0.title == "Flat dinner" }!
        let hours = m.store.searchCorpus(around: m.now).first { $0.title == "Office hours" }!     // the base store's Side project calendar
        #expect(m.buffersUpdates(flat) && !m.buffersUpdates(hours))
        #expect(m.canRespond(m.store.searchCorpus(around: m.now).first { $0.title == "Family dinner" }!) && !m.canRespond(hours))
    }
}

final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    /// True once.
    func take() -> Bool { lock.withLock { defer { fired = true }; return !fired } }
}
