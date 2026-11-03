import Testing
import Foundation
import CalendrKit
@testable import Calendr

/// v4 Phase 8b: GoogleStore against a fake HTTP client (DemoGoogleServer: the v4 fixture's sam.rivera@example.com). No network.
@MainActor
@Suite("Google store")
struct GoogleStoreTests {
    let zone = DemoDataV4.math.timeZone

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
        let atts = p.json?["attendees"] as? [[String: Any]]
        let mails = atts?.compactMap { $0["email"] as? String }
        // the five guests, Kim, and the kitchen (a resource: sent back so the room stays booked)
        #expect(mails?.count == 7 && mails?.contains("kim.lindqvist@example.org") == true)
        #expect(atts?.contains { $0["email"] as? String == DemoGoogleServer.room && $0["resource"] as? Bool == true } == true)
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
        // create without notify (undo) emails nobody
        let post = try #require(http.sent.last { $0.method == "POST" })
        #expect(post.query["sendUpdates"] == "all" && post.json?["summary"] as? String == "Planning")
        let saved = try #require(s.searchCorpus(around: .now).first { $0.title == "Planning" })
        // the id the editor holds stays the event's id after Google answered
        #expect(saved.id == made.id)
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

extension GoogleStoreTests {
    @Test func moveKeepsTheEventAndItsGuests() async throws {
        let (s, http) = await store()
        var e = try #require(event(s, "wg"))
        e.calendarID = "google:sam.rivera@example.com/\(DemoDataV4.family)"
        e.title = "Flat dinner (family)"
        let moved = try s.update(e, span: .this, notify: false)
        await s.idle()
        let mv = try #require(http.sent.first { $0.path.hasSuffix("/events/wg/move") })
        #expect(mv.method == "POST" && mv.query["destination"] == DemoDataV4.family && mv.query["sendUpdates"] == "none")
        #expect(!http.sent.contains { $0.method == "DELETE" || $0.method == "POST" && $0.path.hasSuffix("/events") })
        let now = try #require(s.searchCorpus(around: .now).first { $0.id == moved.id })
        #expect(now.calendarID.hasSuffix(DemoDataV4.family) && now.title == "Flat dinner (family)" && now.attendees.count == 5 && CallLink.parse(now)?.kind == .meet)
        #expect(s.searchCorpus(around: .now).filter { $0.title.hasPrefix("Flat dinner") }.count == 1)
    }

    @Test func moveToAnotherStoreIsRefusedWithoutAWrite() async throws {
        let (s, http) = await store()
        var e = try #require(event(s, "wg"))
        let before = http.sent.count
        e.calendarID = DemoDataV4.work          // a macOS Calendar calendar
        e.title = "Elsewhere"
        #expect(throws: GoogleStore.NotGoogle.self) { try s.update(e, span: .this, notify: false) }
        #expect(http.sent.count == before && event(s, "wg")?.title == "Flat dinner")
    }

    @Test func editAndDeleteBeforeTheInsertReturns() async throws {
        let gate = Gate()
        let server = DemoGoogleServer()
        let http = FakeHTTPClient { r in
            if r.method == "POST" && r.path.hasSuffix("/events") { gate.wait() }
            return server.handle(r)
        }
        let s = GoogleStore(email: DemoGoogleServer.email, api: GoogleCalendarAPI(http: http, token: { "t" }), zone: zone)
        s.deliver = GoogleStore.taskDeliver
        s.sync(); await s.idle()
        let cal = "google:sam.rivera@example.com/v4.personal"
        let start = DemoDataV4.now.addingTimeInterval(7200)
        var made = try s.create(CalendarEvent(calendarID: cal, title: "Draft", start: start, end: start.addingTimeInterval(1800)), notify: false)
        made.title = "Draft, renamed"
        try s.update(made, span: .this, notify: false)            // the insert has not come back
        #expect(s.searchCorpus(around: .now).first { $0.id == made.id }?.title == "Draft, renamed")
        gate.open()
        await s.idle()
        let patch = try #require(http.sent.last { $0.method == "PATCH" })
        #expect(patch.json?["summary"] as? String == "Draft, renamed" && !patch.path.contains("local-"))
        // and a delete that waits for its insert
        gate.close()
        let other = try s.create(CalendarEvent(calendarID: cal, title: "Gone", start: start, end: start.addingTimeInterval(600)), notify: false)
        try s.delete(other, span: .this, notify: false)
        gate.open()
        await s.idle()
        #expect(http.sent.last?.method == "DELETE" && !s.searchCorpus(around: .now).contains { $0.title == "Gone" })
    }

    @Test func writesDuringASyncSurviveItsResult() async throws {
        let slow = Gate()
        let server = DemoGoogleServer()
        let http = FakeHTTPClient { r in
            // the events list is read now, but answered only after the write below
            if r.method == "GET" && r.path.hasSuffix("/events") && r.query["syncToken"] != nil {
                let answer = server.handle(r)
                slow.wait()
                return answer
            }
            return server.handle(r)
        }
        let s = GoogleStore(email: DemoGoogleServer.email, api: GoogleCalendarAPI(http: http, token: { "t" }), zone: zone)
        s.deliver = GoogleStore.taskDeliver
        s.sync(); await s.idle()
        slow.close()
        s.sync()
        var e = try #require(event(s, "g1"))
        e.title = "Written during the sync"
        try s.update(e, span: .this, notify: false)
        while !http.sent.contains(where: { $0.method == "PATCH" }) || s.inFlight > 1 { try? await Task.sleep(nanoseconds: 2_000_000) }
        slow.open()
        await s.idle()
        #expect(event(s, "g1")?.title == "Written during the sync")
    }

    @Test func oneFailingCalendarKeepsTheOthers() async throws {
        let breakFamily = LockedFlag()
        let (s, _) = await store { r in
            r.path.contains("/calendars/\(DemoDataV4.family)/events") && !breakFamily.isOn ? (Data(#"{"error":{"code":500}}"#.utf8), 500) : nil
        }
        // the first round failed for Family only
        #expect(s.calendarErrors.keys.sorted() == [DemoDataV4.family] && event(s, "wg") != nil && event(s, "w8") == nil)
        breakFamily.set()
        s.sync(); await s.idle()
        #expect(s.calendarErrors.isEmpty && event(s, "w8") != nil && s.lastError == nil)
    }

    @Test func aPlainCallLinkGoesIntoTheLocation() async throws {
        let (s, http) = await store()
        var e = try #require(event(s, "a5"))      // Evening walk: no location, no call
        e.conferencing = "https://zoom.us/j/5551234567"
        try s.update(e, span: .this, notify: false)
        await s.idle()
        let p = try #require(http.sent.last { $0.method == "PATCH" })
        #expect(p.json?["conferenceData"] == nil && p.query["conferenceDataVersion"] == nil && p.json?["location"] as? String == "https://zoom.us/j/5551234567")
        #expect(CallLink.parse(event(s, "a5")!)?.kind == .zoom)
    }

    @Test func queryValuesArePercentEncoded() async throws {
        let r = GoogleCalendarAPI.request("GET", ["calendars", "a#b@example.com", "events"], query: [("syncToken", "CP+a/b=="), ("pageToken", "x y")], token: "t")
        let raw = r.url!.absoluteString
        #expect(raw.contains("syncToken=CP%2Ba%2Fb%3D%3D") && raw.contains("pageToken=x%20y") && raw.contains("/calendars/a%23b@example.com/events"))
        #expect(FakeHTTPClient.Sent(method: "GET", url: r.url!, body: nil).query["syncToken"] == "CP+a/b==")
    }

    @Test func removingRevokesAndLeavesNoCache() async throws {
        let m = makeModelV4Composite()
        let g = try #require(m.connectDemoGoogle())
        let http = try #require(g.api.http as? FakeHTTPClient)
        m.disconnectGoogle(DemoGoogleServer.email)
        let until = Date().addingTimeInterval(2)
        while !http.sent.contains(where: { $0.url.host == "oauth2.googleapis.com" }) && Date() < until { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
        let rv = try #require(http.sent.first { $0.url.path == "/revoke" })
        #expect(rv.method == "POST" && String(decoding: rv.body ?? Data(), as: UTF8.self) == "token=demo")
        #expect(g.isClosed && m.services.google.accounts.isEmpty)
    }

    @Test func undoOfADeleteEmailsNobodyAndGoogleSeriesHaveNoUndo() async throws {
        let m = makeModelV4Composite()
        let g = try #require(m.connectDemoGoogle())
        let http = try #require(g.api.http as? FakeHTTPClient)
        let wg = try #require(m.store.searchCorpus(around: m.now).first { $0.title == "Flat dinner" })
        #expect(m.delete(wg, span: .this, notify: false) && m.toast?.undo == true)
        m.undo()
        while !g.isIdleNow { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
        let post = try #require(http.sent.last { $0.method == "POST" && $0.path.hasSuffix("/events") })
        #expect(post.query["sendUpdates"] == "none")
        #expect(m.store.searchCorpus(around: m.now).filter { $0.title == "Flat dinner" }.count == 1)
        // a whole Google series: deleted, no undo offered (undo would make one event per occurrence)
        let run = try #require(m.store.searchCorpus(around: m.now).first { $0.title == "Long run" })
        let before = m.undoStack.changes.count
        #expect(m.delete(run, span: .all, notify: false) && m.toast?.undo == false && m.undoStack.changes.count == before)
        #expect(m.toast?.text.contains("cannot be undone") == true)
    }

    @Test func compositeIsAuthorizedWithGoogleAlone() async {
        let c = CompositeStore(base: DemoStore(authorization: .denied, fixture: .v4))
        #expect(c.authorization == .denied)
        let (g, _) = await store()
        c.add(g)
        #expect(c.authorization == .authorized)
    }

    @Test func eventKitCopiesAreHiddenByICalUID() async throws {
        let base = DemoStore(fixture: .v4)
        let c = CompositeStore(base: base)
        let (g, _) = await store()
        c.add(g)
        // an EventKit copy of Flat dinner in a calendar named differently from the Google address
        var copy = CalendarEvent(calendarID: DemoDataV4.work, title: "Flat dinner (CalDAV copy)", start: DemoDataV4.now, end: DemoDataV4.now.addingTimeInterval(3600))
        copy.externalID = "wg@google.com"
        _ = try base.create(copy)
        let week = DateInterval(start: DemoDataV4.weekStart, duration: 7 * 86400)
        #expect(!c.events(in: week).contains { $0.title == "Flat dinner (CalDAV copy)" })
        #expect(base.events(in: week).contains { $0.title == "Flat dinner (CalDAV copy)" })
    }
}

@MainActor func makeModelV4Composite() -> AppModel {
    let o = LaunchOptions.parse(["Calendr", "--fixture", "v4", "--freeze-clock"])
    return AppModel(store: CompositeStore(base: DemoStore(fixture: .v4)), options: o, persist: false)
}

/// Blocks a fake server answer until opened.
final class Gate: @unchecked Sendable {
    private let c = NSCondition()
    private var shut = true
    func wait() { c.lock(); while shut { c.wait() }; c.unlock() }
    func open() { c.lock(); shut = false; c.broadcast(); c.unlock() }
    func close() { c.lock(); shut = true; c.unlock() }
}

final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    /// True once.
    func take() -> Bool { lock.withLock { defer { fired = true }; return !fired } }
    var isOn: Bool { lock.withLock { fired } }
    func set() { lock.withLock { fired = true } }
}

/// Review fix 8: refresh tokens.
@Suite("Google tokens")
struct GoogleTokenTests {
    func tokenJSON(_ access: String, refresh: String? = nil) -> Data {
        Data((refresh.map { #"{"access_token":"\#(access)","expires_in":3600,"refresh_token":"\#($0)"}"# } ?? #"{"access_token":"\#(access)","expires_in":3600}"#).utf8)
    }

    @Test func invalidGrantNeedsReconnectAndIsNotRetried() async {
        let http = FakeHTTPClient { _ in (Data(#"{"error":"invalid_grant","error_description":"Token has been expired or revoked."}"#.utf8), 400) }
        let p = GoogleTokenProvider(clientID: "c", refreshToken: "r", http: http, retryDelay: 0)
        await #expect(throws: GoogleCalendarAPI.APIError.needsReconnect) { try await p.token() }
        #expect(http.sent.count == 1)
    }

    @Test func serverErrorsAreRetriedAndARotatedTokenIsKept() async throws {
        let n = Counter()
        let http = FakeHTTPClient { _ in n.next() < 2 ? (Data(), 503) : (self.tokenJSON("A1", refresh: "R2"), 200) }
        let rotated = Box()
        let p = GoogleTokenProvider(clientID: "c", refreshToken: "R1", http: http, retryDelay: 0) { rotated.set($0) }
        #expect(try await p.token() == "A1")
        let kept = await p.refreshToken
        #expect(http.sent.count == 3 && rotated.get() == "R2" && kept == "R2")
        // cached until it expires
        #expect(try await p.token() == "A1" && http.sent.count == 3)
    }

    @Test func aStoreThatLosesItsTokenAsksToReconnect() async {
        let http = FakeHTTPClient { r in r.url.host == "oauth2.googleapis.com" ? (Data(#"{"error":"invalid_grant"}"#.utf8), 400) : (Data(), 500) }
        let p = GoogleTokenProvider(clientID: "c", refreshToken: "r", http: http, retryDelay: 0)
        let s = await GoogleStore(email: "a@example.com", api: GoogleCalendarAPI(http: http, token: { try await p.token() }))
        await MainActor.run { s.deliver = GoogleStore.taskDeliver; s.sync() }
        await s.idle()
        #expect(await s.needsReconnect)
        let info = await MainActor.run { GoogleAccountInfo(email: "a", accountID: "x", calendarCount: 0, peopleCount: 0, needsReconnect: s.needsReconnect).statusLine }
        #expect(info.contains("Connect it again"))
    }

    @Test func aFailedKeychainSaveRecordsNoAccount() {
        let t = MemoryTokenStore()
        t.failsSaves = true
        #expect(!t.save(refreshToken: "r", for: "a@example.com") && t.emails().isEmpty)
    }
}

final class Counter: @unchecked Sendable {
    private let l = NSLock(); private var n = 0
    func next() -> Int { l.withLock { defer { n += 1 }; return n } }
}
final class Box: @unchecked Sendable {
    private let l = NSLock(); private var v: String?
    func set(_ s: String) { l.withLock { v = s } }
    func get() -> String? { l.withLock { v } }
}
