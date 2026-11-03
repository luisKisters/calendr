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
        case .meet: parts.first { $0.range(of: #"^[a-z]{3}-[a-z]{4}-[a-z]{3}$"#, options: .regularExpression) != nil }
        case .zoom: parts.firstIndex(of: "j").flatMap { $0 + 1 < parts.count ? parts[$0 + 1] : nil }
        default: nil
        }
        return CallLink(kind: kind, url: url, code: code)
    }

    /// The text with every call link taken out (the word that held it, and the brackets around it); a line left empty goes too.
    /// Other text, websites included, stays as written.
    public static func removingCalls(from text: String) -> String {
        guard parse(conferencing: "", notes: text) != nil else { return text }
        let lines = text.components(separatedBy: "\n").compactMap { line -> String? in
            var l = line
            for t in tokens(line) where link(t) != nil {
                for wrapped in ["(\(t))", "[\(t)]", "<\(t)>", t] { l = l.replacingOccurrences(of: wrapped, with: "") }
            }
            if l == line { return line }
            l = l.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
            if l.hasSuffix(":") { return nil }      // "Join: <link>": the label goes with its link
            while let c = l.last, ":,;".contains(c) { l.removeLast(); l = l.trimmingCharacters(in: .whitespaces) }
            return l.isEmpty ? nil : l
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
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
    /// Only a pair of fence lines with a Meet link between them is a Meet block; other fence-like lines stay. The blank lines
    /// around a removed block shrink to one (none at the start or the end); the rest of the user's text, its blank lines and
    /// its line endings (LF or CRLF) stay as written. `hadMeet` says whether a block was removed.
    public static func stripMeetBoilerplate(_ notes: String) -> (notes: String, hadMeet: Bool) {
        let crlf = notes.contains("\r\n")
        let lines = notes.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        func blank(_ l: String) -> Bool { l.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        func fence(_ l: String) -> Bool {
            l.trimmingCharacters(in: .whitespacesAndNewlines).range(of: #"^-::~[:~]*::-$"#, options: .regularExpression) != nil
        }
        var out: [String] = []
        var hadMeet = false
        var i = 0
        while i < lines.count {
            // The next fence closes this one; the pair is a Meet block only when the lines between hold a Meet link.
            if fence(lines[i]), let close = lines[(i + 1)...].firstIndex(where: fence),
               lines[(i + 1)..<close].contains(where: { $0.contains("meet.google.com/") }) {
                hadMeet = true
                while let l = out.last, blank(l) { out.removeLast() }
                i = close + 1
                while i < lines.count, blank(lines[i]) { i += 1 }
                if !out.isEmpty && i < lines.count { out.append("") }
                continue
            }
            out.append(lines[i])
            i += 1
        }
        guard hadMeet else { return (notes, false) }
        return (out.joined(separator: crlf ? "\r\n" : "\n"), true)
    }
}
