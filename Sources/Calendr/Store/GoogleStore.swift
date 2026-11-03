import Foundation
import CalendrKit

/// One Google account through the Google Calendar API (v4 Phase 8b). Unlike EventKit it writes my reply (a PATCH of my own attendee
/// entry), the guest list, new Meet links (`conferenceDataVersion=1`), and lets the editor choose whether guests hear about a change
/// (`sendUpdates=all|none`: "Send update" / "Save without sending", "Delete event" / "without email").
///
/// The `CalendarStore` calls are synchronous, so writes apply to the local copy at once and go to Google in the background; the
/// server's answer then replaces the local copy. Network work runs off the main thread and comes back through `deliver`
/// (a run-loop perform: headless runs pump the run loop from inside a main-queue block, where a main-actor Task would never run).
/// The calendars and every calendar's sync state are cached on disk (Application Support), so a launch shows the last known events
/// before the first sync.
@MainActor
final class GoogleStore: CalendarStore {
    let email: String
    let api: GoogleCalendarAPI
    let zone: TimeZone
    private let cacheURL: URL?
    /// Hands a finished background result to the main actor. Called off the main thread; set once (tests use a main-actor Task).
    nonisolated(unsafe) var deliver: @Sendable (@escaping @MainActor () -> Void) -> Void = GoogleStore.runLoopDeliver
    var onChange: (() -> Void)?
    /// A write failed: the local copy is restored and the model says so.
    var onError: ((String) -> Void)?
    /// Every finished request, as "PATCH /calendars/…/events/…?sendUpdates=all" (newest last).
    private(set) var requestLog: [String] = []
    var onRequest: ((String) -> Void)?

    private(set) var calendars: [GCalendarListEntry] = []
    private var syncs: [String: GoogleCalendarSync] = [:]
    private var events: [CalendarEvent] = []
    private var byID: [String: CalendarEvent] = [:]
    /// Event id to (Google calendar id, Google event id).
    private var refs: [String: (cal: String, gid: String)] = [:]
    private(set) var inFlight = 0
    private(set) var isSyncing = false
    private(set) var lastSync: Date?
    private(set) var lastError: String?
    /// The full-sync window around "now".
    var window: () -> DateInterval = { DateInterval(start: Date().addingTimeInterval(-400 * 86400), end: Date().addingTimeInterval(800 * 86400)) }

    init(email: String, api: GoogleCalendarAPI, zone: TimeZone = .current, cacheURL: URL? = nil) {
        self.email = email; self.api = api; self.zone = zone; self.cacheURL = cacheURL
        loadCache()
    }

    nonisolated static let runLoopDeliver: @Sendable (@escaping @MainActor () -> Void) -> Void = { block in
        RunLoop.main.perform(inModes: [.common]) { MainActor.assumeIsolated { block() } }
    }
    /// For tests: a main-actor Task.
    nonisolated static let taskDeliver: @Sendable (@escaping @MainActor () -> Void) -> Void = { block in Task { @MainActor in block() } }

    // MARK: Ids

    var accountID: String { "google:\(email)" }
    func calendarKey(_ gcal: String) -> String { "google:\(email)/\(gcal)" }
    func googleCalendar(_ calendarID: String) -> String? {
        let p = "google:\(email)/"
        return calendarID.hasPrefix(p) ? String(calendarID.dropFirst(p.count)) : nil
    }
    func eventID(_ gcal: String, _ gid: String) -> String { "google:\(email)/\(gcal)/\(gid)" }

    // MARK: CalendarStore

    var accounts: [CalendarAccount] {
        [CalendarAccount(id: accountID, name: email, calendars: calendars.filter { $0.accessRole != "freeBusyReader" }.map { c in
            CalendarInfo(id: calendarKey(c.id), accountID: accountID, title: c.summaryOverride ?? c.summary ?? c.id, colorHex: c.backgroundColor ?? "#5B8DEF",
                         icon: c.accessRole == "reader" ? .feed : .standard, isDefault: c.primary == true,
                         isVisibleByDefault: c.selected != false && c.hidden != true, isWritable: c.accessRole == "owner" || c.accessRole == "writer")
        })]
    }
    var teammates: [Teammate] { [] }
    var authorization: StoreAuthorization { .authorized }
    var defaultCalendarID: String? { calendars.first { $0.primary == true }.map { calendarKey($0.id) } }
    var canEditParticipants: Bool { true }
    var canSendUpdates: Bool { true }
    var canRespond: Bool { true }
    func canCreateMeetLinks(calendarID: String) -> Bool { true }
    var coalescesTextEdits: Bool { true }

    func requestAccess() async {}
    /// ⌘R, focus and the 60 s poll.
    func refresh() { sync() }

    func events(in range: DateInterval) -> [CalendarEvent] {
        events.filter { $0.end > range.start && $0.start < range.end || ($0.start == $0.end && $0.start >= range.start && $0.start < range.end) }
    }
    func teammateEvents(_ email: String, in range: DateInterval) -> [CalendarEvent] { [] }
    func searchCorpus(around date: Date) -> [CalendarEvent] { events }
    func series(of event: CalendarEvent) -> [CalendarEvent] {
        guard let s = event.seriesID else { return [event] }
        return events.filter { $0.seriesID == s && $0.calendarID == event.calendarID }
    }

    // MARK: Sync

    /// One sync round for every calendar: the calendar list, then each calendar's changes since its sync token (410: in full again).
    func sync() {
        guard !isSyncing else { return }
        isSyncing = true
        inFlight += 1
        let api = api, start = syncs, window = window()
        Task.detached {
            let result: Result<([GCalendarListEntry], [String: GoogleCalendarSync]), Error>
            do {
                let cals = try await api.calendarList()
                var syncs = start
                for c in cals where c.accessRole != "freeBusyReader" {
                    var s = syncs[c.id] ?? GoogleCalendarSync()
                    var resets = 0
                    while true {
                        let r = s.nextRequest()
                        do {
                            if s.apply(try await api.events(calendarID: c.id, request: r, window: r.isFull ? window : nil)) { break }
                        } catch GoogleCalendarAPI.APIError.gone {
                            s.gone()
                            resets += 1
                            if resets > 1 { throw GoogleCalendarAPI.APIError.gone }
                        }
                    }
                    syncs[c.id] = s
                }
                result = .success((cals, syncs.filter { k, _ in cals.contains { $0.id == k } }))
            } catch { result = .failure(error) }
            self.deliverResult(result)
        }
    }

    nonisolated private func deliverResult(_ r: Result<([GCalendarListEntry], [String: GoogleCalendarSync]), Error>) {
        Self.runLoopDeliverOrCustom(self) { s in
            s.isSyncing = false
            s.inFlight -= 1
            switch r {
            case .success(let (cals, syncs)):
                s.calendars = cals; s.syncs = syncs; s.lastSync = Date(); s.lastError = nil
                s.rebuild(); s.saveCache(); s.onChange?()
            case .failure(let e):
                s.lastError = "\(e)"
            }
        }
    }

    /// Uses the store's own `deliver` (tests swap it).
    nonisolated private static func runLoopDeliverOrCustom(_ store: GoogleStore, _ block: @escaping @MainActor (GoogleStore) -> Void) {
        store.deliver { block(store) }
    }

    /// The events from every calendar's sync state, mapped.
    private func rebuild() {
        var out: [CalendarEvent] = []
        refs.removeAll()
        for c in calendars {
            guard let s = syncs[c.id] else { continue }
            let defaults = s.defaultReminders.isEmpty ? (c.defaultReminders ?? []).map(\.minutes) : s.defaultReminders
            for (gid, g) in s.items {
                let id = eventID(c.id, gid)
                guard let e = GoogleMapping.event(g, id: id, calendarID: calendarKey(c.id), defaultReminders: defaults, zone: zone, seriesPrefix: calendarKey(c.id) + "/") else { continue }
                out.append(e)
                refs[id] = (c.id, gid)
            }
        }
        events = out.sorted { $0.start != $1.start ? $0.start < $1.start : $0.id < $1.id }
        byID = Dictionary(events.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    // MARK: Writes

    struct NotGoogle: Error {}

    /// Runs one request in the background; `done` gets the answer on the main actor, `failed` restores the local copy.
    private func run<T: Sendable>(_ work: @escaping @Sendable () async throws -> T, done: @escaping @MainActor (T) -> Void, failed: @escaping @MainActor () -> Void) {
        inFlight += 1
        let log = api.log
        let before = log.count
        Task.detached {
            let r: Result<T, Error>
            do { r = .success(try await work()) } catch { r = .failure(error) }
            Self.runLoopDeliverOrCustom(self) { s in
                s.inFlight -= 1
                for line in log.lines.dropFirst(before) { s.logRequest(line) }
                switch r {
                case .success(let v): done(v)
                case .failure(let e):
                    s.lastError = "\(e)"
                    failed()
                    s.onError?("Google did not take the change")
                }
                s.rebuild(); s.saveCache(); s.onChange?()
            }
        }
    }

    private func logRequest(_ line: String) {
        requestLog.append(line)
        if requestLog.count > 50 { requestLog.removeFirst(requestLog.count - 50) }
        onRequest?(line)
    }

    private func local(_ e: CalendarEvent) {
        events.removeAll { $0.id == e.id }
        let i = events.firstIndex { $0.start > e.start } ?? events.count
        events.insert(e, at: i)
        byID[e.id] = e
        onChange?()
    }
    private func dropLocal(_ id: String) {
        events.removeAll { $0.id == id }
        byID[id] = nil
        onChange?()
    }

    func create(_ event: CalendarEvent) throws -> CalendarEvent { try create(event, notify: true) }

    func create(_ event: CalendarEvent, notify: Bool) throws -> CalendarEvent {
        guard let cal = googleCalendar(event.calendarID) else { throw NotGoogle() }
        let meet = event.conferencing == GoogleMapping.newMeetLink
        let body = GoogleMapping.body(event, zone: zone, meetRequestID: meet ? UUID().uuidString : nil)
        var temp = event
        temp.id = eventID(cal, "local-" + UUID().uuidString)
        local(temp)
        let api = api
        run({ try await api.insert(calendarID: cal, body, notify: notify, conference: meet) },
            done: { [weak self] g in self?.syncs[cal, default: GoogleCalendarSync()].upsert(g) },
            failed: { [weak self] in self?.dropLocal(temp.id) })
        return temp
    }

    func update(_ event: CalendarEvent, span: EditSpan) throws -> CalendarEvent { try update(event, span: span, notify: false) }

    func update(_ event: CalendarEvent, span: EditSpan, notify: Bool) throws -> CalendarEvent {
        guard let ref = refs[event.id], let old = byID[event.id] else { throw NotGoogle() }
        if let target = googleCalendar(event.calendarID), target != ref.cal {
            // another calendar of this account: Google's `move`, then the rest as a patch (kept simple: delete and insert)
            try delete(old, span: .this, notify: false)
            var moved = event
            moved.attendees = event.attendees
            return try create(moved, notify: notify)
        }
        let api = api, zone = zone, cal = ref.cal
        local(event)
        let restore: @MainActor () -> Void = { [weak self] in self?.local(old) }
        let store: @MainActor (GEvent) -> Void = { [weak self] g in self?.syncs[cal]?.upsert(g) }
        if GoogleMapping.onlyReplyChanged(old: old, new: event) {
            // my reply: my own attendee entry only, nothing else of the guest list
            let me = event.attendees.first { $0.isMe }?.email ?? email
            let body = GoogleMapping.rsvp(selfEmail: me, status: event.status)
            let gid = span == .this ? ref.gid : (syncs[cal]?.items[ref.gid]?.recurringEventId ?? ref.gid)
            run({ try await api.patch(calendarID: cal, eventID: gid, body, notify: nil, conference: false) }, done: span == .this ? store : { _ in }, failed: restore)
            if span != .this { scheduleResync() }
            return event
        }
        let meet = event.conferencing == GoogleMapping.newMeetLink && old.conferencing != event.conferencing
        guard var body = GoogleMapping.patch(old: old, new: event, zone: zone, meetRequestID: meet ? UUID().uuidString : nil) else { return event }
        if span == .this || old.seriesID == nil {
            run({ try await api.patch(calendarID: cal, eventID: ref.gid, body, notify: notify, conference: meet) }, done: store, failed: restore)
        } else {
            // the whole series: the main event, with the time shifted by as much as this occurrence moved
            let master = syncs[cal]?.items[ref.gid]?.recurringEventId ?? ref.gid
            let shift = event.start.timeIntervalSince(old.start), length = event.end.timeIntervalSince(event.start)
            let timesChanged = body.start != nil
            body.start = nil; body.end = nil
            let patch = body
            run({
                var p = patch
                if timesChanged {
                    let m = try await api.get(calendarID: cal, eventID: master)
                    if let s = m.start.flatMap({ GoogleMapping.date($0, zone: zone) }) {
                        let ns = s.addingTimeInterval(shift), tz = TimeZone(identifier: m.start?.timeZone ?? "") ?? zone
                        p.start = GDateTime(dateTime: RFC3339.string(ns, zone: tz), timeZone: tz.identifier)
                        p.end = GDateTime(dateTime: RFC3339.string(ns.addingTimeInterval(length), zone: tz), timeZone: tz.identifier)
                    }
                }
                return try await api.patch(calendarID: cal, eventID: master, p, notify: notify, conference: meet)
            }, done: { _ in }, failed: restore)
            scheduleResync()
        }
        return event
    }

    func delete(_ event: CalendarEvent, span: EditSpan) throws { try delete(event, span: span, notify: false) }

    func delete(_ event: CalendarEvent, span: EditSpan, notify: Bool) throws {
        guard let ref = refs[event.id] else { dropLocal(event.id); return }
        let api = api, cal = ref.cal
        let removed = span == .this ? [event] : series(of: event).filter { span == .all || $0.start >= event.start }
        for e in removed { dropLocal(e.id) }
        let restore: @MainActor () -> Void = { [weak self] in for e in removed { self?.local(e) } }
        let master = syncs[cal]?.items[ref.gid]?.recurringEventId ?? ref.gid
        switch span {
        case .this:
            run({ try await api.delete(calendarID: cal, eventID: ref.gid, notify: notify) }, done: { [weak self] in self?.syncs[cal]?.remove(ref.gid) }, failed: restore)
        case .all:
            run({ try await api.delete(calendarID: cal, eventID: master, notify: notify) }, done: { [weak self] in
                guard let self else { return }
                for e in removed { if let r = self.refs[e.id] { self.syncs[cal]?.remove(r.gid) } }
            }, failed: restore)
        case .future:
            // this and following: the series ends the second before this occurrence
            let until = event.start.addingTimeInterval(-1)
            run({
                let m = try await api.get(calendarID: cal, eventID: master)
                let rules = (m.recurrence ?? []).map { line -> String in
                    guard var r = RRule.parse(line) else { return line }
                    r.until = until
                    return RRule.format(r, zone: TimeZone(identifier: "UTC")!)
                }
                return try await api.patch(calendarID: cal, eventID: master, GEvent(recurrence: rules), notify: notify, conference: false)
            }, done: { [weak self] _ in
                guard let self else { return }
                for e in removed { if let r = self.refs[e.id] { self.syncs[cal]?.remove(r.gid) } }
            }, failed: restore)
        }
    }

    /// A series change: the next round brings the changed instances.
    private func scheduleResync() {
        after(0.5) { [weak self] in self?.sync() }
    }

    /// Work outside the store that the tests and tours wait for (the People API read).
    func track(_ d: Int) { inFlight += d }

    /// Tests: waits until every request has come back.
    func idle() async {
        while inFlight > 0 { try? await Task.sleep(nanoseconds: 2_000_000) }
    }

    // MARK: Disk cache

    struct Cache: Codable { var calendars: [GCalendarListEntry]; var syncs: [String: GoogleCalendarSync] }

    /// ~/Library/Application Support/Calendr/google/<address>.json
    static func cacheURL(for email: String) -> URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let safe = email.map { $0.isLetter || $0.isNumber || "@._-".contains($0) ? String($0) : "_" }.joined()
        return dir.appendingPathComponent("Calendr/google/\(safe).json")
    }

    private func loadCache() {
        guard let u = cacheURL, let d = try? Data(contentsOf: u), let c = try? JSONDecoder().decode(Cache.self, from: d) else { return }
        calendars = c.calendars; syncs = c.syncs
        rebuild()
    }

    private func saveCache() {
        guard let u = cacheURL, let d = try? JSONEncoder().encode(Cache(calendars: calendars, syncs: syncs)) else { return }
        try? FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? d.write(to: u, options: .atomic)
    }

    func deleteCache() {
        if let u = cacheURL { try? FileManager.default.removeItem(at: u) }
    }
}
