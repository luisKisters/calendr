import Foundation
import CalendrKit

/// The Google Calendar API v3 calls the store makes, as `URLRequest`s through an `HTTPClient` (https://developers.google.com/calendar/api/v3/reference).
/// Not tied to the main actor: the store runs these off the main thread and hands the results back.
struct GoogleCalendarAPI: Sendable {
    static let base = URL(string: "https://www.googleapis.com/calendar/v3")!

    enum APIError: Error, Equatable {
        /// 410: the sync token expired; sync in full.
        case gone
        case unauthorized
        case status(Int, String)
        case decoding(String)
    }

    let http: HTTPClient
    /// A valid access token (refreshed when needed).
    let token: @Sendable () async throws -> String
    /// Every request sent, as a one-line summary.
    let log = RequestLog()

    init(http: HTTPClient, token: @escaping @Sendable () async throws -> String) { self.http = http; self.token = token }

    // MARK: Requests (static, so tests can read what would be sent)

    /// Path segments are percent-encoded on their own (calendar ids contain "@" and "#").
    static func request(_ method: String, _ segments: [String], query: [(String, String)] = [], body: Data? = nil, token: String) -> URLRequest {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~@")
        let path = segments.map { $0.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0 }.joined(separator: "/")
        var c = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        c.percentEncodedPath = base.path + "/" + path
        if !query.isEmpty { c.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) } }
        var r = URLRequest(url: c.url!)
        r.httpMethod = method
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body { r.httpBody = body; r.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return r
    }

    /// "PATCH /calendars/…/events/<id>?sendUpdates=all" for logs and the demo's debug line.
    static func summary(method: String, url: URL) -> String {
        let p = url.path.replacingOccurrences(of: base.path, with: "")
        let parts = p.split(separator: "/").map(String.init)
        let short = parts.enumerated().map { i, s in i > 0 && parts[i - 1] == "calendars" ? "…" : (s.count > 24 ? String(s.prefix(10)) + "…" : s) }.joined(separator: "/")
        let q = url.query.map { "?" + ($0.removingPercentEncoding ?? $0) } ?? ""
        return "\(method) /\(short)\(q)"
    }

    static func sendUpdates(_ notify: Bool) -> (String, String) { ("sendUpdates", notify ? "all" : "none") }

    // MARK: Calls

    private func call(_ method: String, _ segments: [String], query: [(String, String)] = [], body: Data? = nil) async throws -> Data {
        let t = try await token()
        let req = Self.request(method, segments, query: query, body: body, token: t)
        log.append(Self.summary(method: method, url: req.url!))
        let (data, status) = try await http.send(req)
        switch status {
        case 200..<300: return data
        case 401: throw APIError.unauthorized
        case 410: throw APIError.gone
        default: throw APIError.status(status, String(decoding: data.prefix(300), as: UTF8.self))
        }
    }

    private func decode<T: Decodable>(_ d: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: d) } catch { throw APIError.decoding("\(error)") }
    }

    func calendarList() async throws -> [GCalendarListEntry] {
        var out: [GCalendarListEntry] = []
        var page: String?
        repeat {
            let l: GCalendarList = try decode(try await call("GET", ["users", "me", "calendarList"], query: page.map { [("pageToken", $0)] } ?? []))
            out += l.items ?? []
            page = l.nextPageToken
        } while page != nil
        return out
    }

    /// One page of a sync round: instances of recurring events expanded (`singleEvents`), deleted ones included (`showDeleted`).
    /// A full sync is limited to `window`; an incremental one may not send a window.
    func events(calendarID: String, request: GoogleCalendarSync.Request, window: DateInterval?) async throws -> GEventsPage {
        var q: [(String, String)] = [("singleEvents", "true"), ("showDeleted", "true"), ("maxResults", "250")]
        if let t = request.syncToken { q.append(("syncToken", t)) }
        else if let w = window {
            q.append(("timeMin", RFC3339.string(w.start, zone: TimeZone(identifier: "UTC")!)))
            q.append(("timeMax", RFC3339.string(w.end, zone: TimeZone(identifier: "UTC")!)))
        }
        if let p = request.pageToken { q.append(("pageToken", p)) }
        return try decode(try await call("GET", ["calendars", calendarID, "events"], query: q))
    }

    func get(calendarID: String, eventID: String) async throws -> GEvent {
        try decode(try await call("GET", ["calendars", calendarID, "events", eventID]))
    }

    /// `conference`: the body asks for a new Meet link (`conferenceDataVersion=1`).
    func insert(calendarID: String, _ body: GEvent, notify: Bool, conference: Bool) async throws -> GEvent {
        var q = [Self.sendUpdates(notify)]
        if conference { q.append(("conferenceDataVersion", "1")) }
        return try decode(try await call("POST", ["calendars", calendarID, "events"], query: q, body: try JSONEncoder().encode(body)))
    }

    /// `notify` nil: Google's default (my reply is not an update to the guests).
    func patch(calendarID: String, eventID: String, _ body: GEvent, notify: Bool?, conference: Bool) async throws -> GEvent {
        var q: [(String, String)] = notify.map { [Self.sendUpdates($0)] } ?? []
        if conference || body.conferenceData != nil { q.append(("conferenceDataVersion", "1")) }
        return try decode(try await call("PATCH", ["calendars", calendarID, "events", eventID], query: q, body: try JSONEncoder().encode(body)))
    }

    func delete(calendarID: String, eventID: String, notify: Bool) async throws {
        _ = try await call("DELETE", ["calendars", calendarID, "events", eventID], query: [Self.sendUpdates(notify)])
    }
}

/// Request summaries, appended from any thread.
final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var _lines: [String] = []
    var lines: [String] { lock.withLock { _lines } }
    var count: Int { lock.withLock { _lines.count } }
    func append(_ s: String) { lock.withLock { _lines.append(s) } }
}
