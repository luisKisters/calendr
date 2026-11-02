import Foundation

/// An event's video call: found in the conferencing field, else in the notes (Google puts its Meet block there), else in the location.
/// Only links to known meeting hosts count; a website or a document link is not a call.
public struct CallLink: Equatable, Sendable {
    public enum Kind: String, Sendable, Equatable, CaseIterable { case meet, zoom, teams, other }

    public var kind: Kind
    public var url: URL
    /// Meet: "abc-defg-hij". Zoom: the meeting number. Nil when the link has none.
    public var code: String?

    /// "Google Meet", "Zoom", "Teams", "Call"
    public var name: String {
        switch kind {
        case .meet: "Google Meet"
        case .zoom: "Zoom"
        case .teams: "Teams"
        case .other: "Call"
        }
    }

    /// The link without the scheme and a trailing slash, as the editor shows it: "meet.google.com/abc-defg-hij".
    public var display: String {
        var s = url.absoluteString
        for p in ["https://", "http://"] where s.lowercased().hasPrefix(p) { s.removeFirst(p.count) }
        if s.hasSuffix("/") { s.removeLast() }
        return s
    }

    /// Hosts whose links are calls (subdomains included, like us02web.zoom.us).
    public static let hosts: [(String, Kind)] = [
        ("meet.google.com", .meet), ("zoom.us", .zoom), ("zoomgov.com", .zoom), ("teams.microsoft.com", .teams), ("teams.live.com", .teams),
        ("webex.com", .other), ("whereby.com", .other), ("around.co", .other), ("facetime.apple.com", .other), ("meet.jit.si", .other),
        ("chime.aws", .other), ("gotomeeting.com", .other), ("meet.goto.com", .other), ("bluejeans.com", .other), ("meet.example.com", .other),
    ]

    /// The first call link in `conferencing`, then `notes`, then `location`.
    public static func parse(conferencing: String, notes: String = "", location: String = "") -> CallLink? {
        for text in [conferencing, notes, location] {
            for token in tokens(text) { if let c = link(token) { return c } }
        }
        return nil
    }

    public static func parse(_ e: CalendarEvent) -> CallLink? { parse(conferencing: e.conferencing, notes: e.notes, location: e.location) }

    /// One word as a call link, or nil.
    static func link(_ word: String) -> CallLink? {
        guard word.contains("."), let url = URL(string: word.contains("://") ? word : "https://" + word),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host?.lowercased() else { return nil }
        guard let kind = hosts.first(where: { host == $0.0 || host.hasSuffix("." + $0.0) })?.1 else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        let code: String? = switch kind {
        case .meet: parts.first { $0.range(of: #"^[a-z]{3,4}-[a-z]{3,4}-[a-z]{3,4}$"#, options: .regularExpression) != nil } ?? parts.first
        case .zoom: parts.firstIndex(of: "j").flatMap { $0 + 1 < parts.count ? parts[$0 + 1] : nil }
        default: nil
        }
        return CallLink(kind: kind, url: url, code: code)
    }

    /// Words of a text, split at white space and at the brackets and quotes that wrap links; trailing punctuation dropped.
    static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace || "<>()[]\"'".contains($0) }).map { w in
            var s = String(w)
            while let l = s.last, ".,;:!?".contains(l) { s.removeLast() }
            return s
        }.filter { !$0.isEmpty }
    }

    /// The Google Meet block Google writes into the notes (between two `-::~:~::~…::-` lines, mockup `BOILER`), removed.
    /// `hadMeet` says whether a Meet block was there. The user's own text stays as written, without the blank lines around the block.
    public static func stripMeetBoilerplate(_ notes: String) -> (notes: String, hadMeet: Bool) {
        let lines = notes.components(separatedBy: "\n")
        let isFence = { (l: String) in l.trimmingCharacters(in: .whitespaces).range(of: #"^-::~[:~]*::-$"#, options: .regularExpression) != nil }
        var out: [String] = []
        var hadMeet = false
        var i = 0
        while i < lines.count {
            if isFence(lines[i]), let close = lines[(i + 1)...].firstIndex(where: isFence) {
                let block = lines[i...close].joined(separator: "\n")
                if block.contains("meet.google.com") || block.contains("Google Meet") {
                    hadMeet = true
                    i = close + 1
                    continue
                }
            }
            out.append(lines[i])
            i += 1
        }
        guard hadMeet else { return (notes, false) }
        // Collapse the blank lines the block leaves behind and trim the ends.
        var clean: [String] = []
        for l in out where !(l.trimmingCharacters(in: .whitespaces).isEmpty && (clean.last?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)) { clean.append(l) }
        while let l = clean.last, l.trimmingCharacters(in: .whitespaces).isEmpty { clean.removeLast() }
        return (clean.joined(separator: "\n"), true)
    }
}
