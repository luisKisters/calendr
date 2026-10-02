import Foundation

/// The menu bar item and its menu as plain data (design/mockup-v3/menubar.html). The NSMenu and the
/// snapshot preview both draw this, so what the tests check is what the menu shows.
public struct MenuBarMenuModel: Equatable, Sendable {
    /// What the countdown is about: the running event until 15 minutes before the next one, otherwise the next one.
    public struct Focus: Equatable, Sendable {
        public var event: CalendarEvent
        public var running: Bool
        /// "in 12 min", "now", "1 h 20 min left"
        public var text: String
        /// Red: inside 15 minutes, or an event runs.
        public var soon: Bool
    }

    public struct Row: Equatable, Identifiable, Sendable {
        public var event: CalendarEvent
        public var id: String { event.id }
        public var title: String { event.title }
        /// "12:00", or "all-day".
        public var start: String
        /// Nil for all-day events.
        public var end: String?
        public var colorHex: String
        public var tentative: Bool { event.status == .tentative }
        /// "1 h 20 min left" while the event runs.
        public var left: String?
        /// Only events whose row menu offers more than Show in Calendr get one.
        public var hasSubmenu: Bool
    }

    public struct Section: Equatable, Sendable {
        public var title: String
        public var rows: [Row]
    }

    public var focus: Focus?
    /// The focus event as the first row, under the countdown line.
    public var head: Row?
    /// "Today" (what has not ended), "Tomorrow", and the day after ("Thu 1 Oct"); empty days are left out.
    public var sections: [Section]

    /// "Up next", "Now", or "Nothing else today".
    public var headLabel: String { focus.map { $0.running ? "Now" : "Up next" } ?? "Nothing else today" }
    /// The item's title: the focus event's title, cut to 25 characters.
    public var itemTitle: String? { focus.map { MenuBarMenu.cut($0.event.title) } }
    /// Every event row in menu order (the head row first).
    public var rows: [Row] { (head.map { [$0] } ?? []) + sections.flatMap(\.rows) }
}

/// One entry of an event row's menu.
public enum MenuBarSubItem: Equatable, Sendable {
    case join(URL)
    case header(String)
    /// Yes, No, Maybe; `checked` on the current answer.
    case respond(ResponseStatus, checked: Bool)
    case email(title: String, url: URL)
    case show
    case separator

    public var title: String {
        switch self {
        case .join: "Join call"
        case .header(let t): t
        case .respond(let s, _): s == .confirmed ? "Yes" : s == .declined ? "No" : "Maybe"
        case .email(let t, _): t
        case .show: "Show in Calendr"
        case .separator: ""
        }
    }

    /// Bare key that runs the item while its menu is open.
    public var key: String {
        switch self {
        case .join: "j"
        case .respond(let s, _): s == .confirmed ? "y" : s == .declined ? "n" : "m"
        case .email: "e"
        case .show: "\r"
        case .header, .separator: ""
        }
    }
}

public enum MenuBarMenu {
    /// Builds the menu from the events around `now` (hidden calendars already left out). Declined events are left out.
    /// `canRespond` and `guestAddresses` are what `submenu` gets, so a row has a menu exactly when it has something in it.
    public static func build(events: [CalendarEvent], now: Date, fmt: Fmt, canRespond: Bool = false,
                             guestAddresses: (CalendarEvent) -> [String] = { $0.participants.compactMap(guestAddress) },
                             colorHex: (CalendarEvent) -> String) -> MenuBarMenuModel {
        let math = fmt.math
        let today = math.startOfDay(now)
        let t = math.date(on: today, minutes: math.minutesSinceMidnight(now))   // the clock in whole minutes
        let shown = events.filter { $0.status != .declined }

        /// Today also keeps timed events that began before midnight and still run.
        func day(_ k: Int) -> [CalendarEvent] {
            let d = math.addDays(today, k)
            return shown.filter { $0.isAllDay ? $0.start <= d && $0.end > d : math.isSameDay($0.start, d) || (k == 0 && $0.start < d && $0.end > t) }
                .sorted { a, b in
                    if a.isAllDay != b.isAllDay { return a.isAllDay }
                    if a.start != b.start { return a.start < b.start }
                    if a.end != b.end { return a.end < b.end }
                    return a.title < b.title
                }
        }
        func row(_ e: CalendarEvent, today isToday: Bool) -> MenuBarMenuModel.Row {
            let running = isToday && !e.isAllDay && e.start <= t && e.end > t
            return .init(event: e, start: e.isAllDay ? "all-day" : fmt.time(e.start), end: e.isAllDay ? nil : fmt.time(e.end),
                         colorHex: colorHex(e), left: running ? "\(span(minutes(t, e.end))) left" : nil,
                         hasSubmenu: submenu(for: e, canRespond: canRespond, guestAddresses: guestAddresses(e)) != [.show])
        }

        let todays = day(0)
        let f = focus(todays.filter { !$0.isAllDay }, t: t)
        var sections: [MenuBarMenuModel.Section] = []
        for k in 0..<3 {
            var list = k == 0 ? todays.filter { $0.isAllDay || $0.end > t } : day(k)
            if k == 0, let f { list.removeAll { $0.id == f.event.id } }
            guard !list.isEmpty else { continue }
            sections.append(.init(title: sectionTitle(math.addDays(today, k), k: k, fmt: fmt), rows: list.map { row($0, today: k == 0) }))
        }
        return MenuBarMenuModel(focus: f, head: f.map { row($0.event, today: true) }, sections: sections)
    }

    static func focus(_ timed: [CalendarEvent], t: Date) -> MenuBarMenuModel.Focus? {
        let run = timed.filter { $0.start <= t && $0.end > t }.max { $0.start < $1.start }
        let next = timed.first { $0.start > t }
        if let run, next.map({ minutes(t, $0.start) > 15 }) ?? true {
            return .init(event: run, running: true, text: "\(span(minutes(t, run.end))) left", soon: true)
        }
        if let next {
            let m = minutes(t, next.start)
            return .init(event: next, running: false, text: m < 1 ? "now" : "in \(span(m))", soon: m <= 15)
        }
        return nil
    }

    /// Join, the answer (only when the store can change it), email (only to guests with an address), then Show in Calendr. Nothing that does nothing.
    public static func submenu(for e: CalendarEvent, canRespond: Bool, guestAddresses: [String]) -> [MenuBarSubItem] {
        var out: [MenuBarSubItem] = []
        if let url = videoURL(e) { out.append(.join(url)) }
        if !e.participants.isEmpty {
            if canRespond {
                out += [.separator, .header("Going?")]
                out += [ResponseStatus.confirmed, .declined, .tentative].map { .respond($0, checked: e.status == $0) }
            }
            if !guestAddresses.isEmpty {
                let title = e.participants.count > 1 ? "Email \(e.participants.count) guests" : "Email \(guestName(e.participants[0]))"
                out += [.separator, .email(title: title, url: mailURL(to: guestAddresses, subject: e.title))]
            }
        }
        if !out.isEmpty { out.append(.separator) }
        out.append(.show)
        if out.first == .separator { out.removeFirst() }
        return out
    }

    /// Hosts whose links are calls. Any other URL on an event (a website, a document) gets no Join.
    static let callHosts = ["meet.google.com", "zoom.us", "zoomgov.com", "teams.microsoft.com", "teams.live.com", "webex.com",
                            "whereby.com", "around.co", "facetime.apple.com", "meet.jit.si", "chime.aws", "gotomeeting.com",
                            "meet.goto.com", "bluejeans.com", "meet.example.com"]

    /// The event's call link, when it points at a known meeting host (subdomains included, like us02web.zoom.us).
    public static func videoURL(_ e: CalendarEvent) -> URL? {
        let s = e.conferencing.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, let url = URL(string: s.contains("://") ? s : "https://" + s), let host = url.host?.lowercased() else { return nil }
        return callHosts.contains { host == $0 || host.hasSuffix("." + $0) } ? url : nil
    }

    /// "Sam Okafor <sam@example.com>" -> "Sam Okafor"
    public static func guestName(_ p: String) -> String {
        guard let i = p.range(of: " <") else { return p }
        return String(p[..<i.lowerBound])
    }

    /// The address in "Name <address>" or a bare address; nil for a plain name.
    public static func guestAddress(_ p: String) -> String? {
        if let a = p.range(of: "<"), let b = p.range(of: ">", range: a.upperBound..<p.endIndex) { return String(p[a.upperBound..<b.lowerBound]) }
        return p.contains("@") ? p.trimmingCharacters(in: .whitespaces) : nil
    }

    static func mailURL(to addresses: [String], subject: String) -> URL {
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = addresses.joined(separator: ",")
        c.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return c.url ?? URL(string: "mailto:")!
    }

    /// Titles longer than 26 characters keep 25 and an ellipsis.
    public static func cut(_ title: String) -> String { title.count > 26 ? String(title.prefix(25)) + "\u{2026}" : title }

    /// "12 min", "2 h", "1 h 40 min"
    public static func span(_ m: Int) -> String {
        let h = m / 60, r = m % 60
        return h > 0 && r > 0 ? "\(h) h \(r) min" : h > 0 ? "\(h) h" : "\(r) min"
    }

    static func minutes(_ a: Date, _ b: Date) -> Int { Int((b.timeIntervalSince(a) / 60).rounded(.down)) }

    static func sectionTitle(_ d: Date, k: Int, fmt: Fmt) -> String {
        k == 0 ? "Today" : k == 1 ? "Tomorrow" : "\(fmt.weekdayShort(d)) \(fmt.math.day(d)) \(fmt.monthShort(d))"
    }
}
