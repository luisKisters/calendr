import Foundation

/// One calendar's incremental sync (Google `events.list` with sync tokens, https://developers.google.com/calendar/api/guides/sync):
/// a full sync pages through everything and ends with a sync token; later rounds send the token and get only what changed (deleted
/// events come back as `status: cancelled`). When Google answers 410 Gone the token is no longer valid: drop it and everything kept,
/// and sync in full again. The state is Codable: the disk cache keeps it between launches.
public struct GoogleCalendarSync: Codable, Equatable, Sendable {
    public struct Request: Equatable, Sendable {
        public var syncToken: String?
        public var pageToken: String?
        /// A full sync: the store adds its time window (`timeMin`/`timeMax` may not go with a sync token).
        public var isFull: Bool { syncToken == nil }
        public init(syncToken: String?, pageToken: String?) { self.syncToken = syncToken; self.pageToken = pageToken }
    }

    public private(set) var syncToken: String?
    /// The events by Google id, as of the last finished round.
    public private(set) var items: [String: GEvent] = [:]
    /// The calendar's default reminders, from the last page.
    public private(set) var defaultReminders: [Int] = []
    /// A full sync collects here and replaces `items` only when its last page arrived.
    private var pending: [String: GEvent]?
    private var pageToken: String?
    /// The token the running round started with (incremental pages all send it).
    private var roundToken: String?
    public private(set) var fullSyncs = 0

    public init(syncToken: String? = nil) { self.syncToken = syncToken }

    public var isRunning: Bool { pageToken != nil || pending != nil }

    /// The next `events.list` request: the next page of the running round, else a new round (full when there is no token).
    public mutating func nextRequest() -> Request {
        if let p = pageToken { return Request(syncToken: roundToken, pageToken: p) }
        roundToken = syncToken
        if syncToken == nil { pending = [:]; fullSyncs += 1 }
        return Request(syncToken: syncToken, pageToken: nil)
    }

    /// Applies one page. Returns true when the round is done (the page had the next sync token).
    @discardableResult
    public mutating func apply(_ page: GEventsPage) -> Bool {
        if let d = page.defaultReminders { defaultReminders = d.map(\.minutes) }
        for e in page.items ?? [] {
            guard let id = e.id else { continue }
            if pending != nil {
                if e.status == "cancelled" { pending?[id] = nil } else { pending?[id] = e }
            } else {
                if e.status == "cancelled" { items[id] = nil } else { items[id] = e }
            }
        }
        if let next = page.nextPageToken { pageToken = next; return false }
        pageToken = nil
        if let p = pending { items = p; pending = nil }
        if let t = page.nextSyncToken { syncToken = t }
        return true
    }

    /// 410 Gone: the sync token expired. Everything is dropped; the next request is a full sync.
    public mutating func gone() {
        syncToken = nil; roundToken = nil; pageToken = nil; pending = nil
        items = [:]
    }

    /// Our own write, applied at once (the next incremental round confirms it).
    public mutating func upsert(_ e: GEvent) {
        guard let id = e.id else { return }
        items[id] = e
        if pending != nil { pending?[id] = e }
    }
    public mutating func remove(_ id: String) {
        items[id] = nil
        pending?[id] = nil
    }
}
