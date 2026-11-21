import Foundation

/// The menu bar item and its menu as plain data (design/menubar-v2, round 3 picks). The NSMenu and the
/// snapshot preview both draw this, so what the tests check is what the menu shows.
public struct MenuBarMenuModel: Equatable, Sendable {
    /// What the countdown is about: the running event until 15 minutes before the next one, otherwise the next one.
    public struct Focus: Equatable, Sendable {
        public var event: CalendarEvent
        public var running: Bool
        /// "in 12 min", "now", "1 h 20 min left"
        public var text: String
        /// Inside 15 minutes, or an event runs (the ring glyph's dot turns red).
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
        /// The same event in a second calendar: one row, its bar in both colours.
        public var secondColorHex: String?
        public var tentative: Bool { event.status == .tentative }
        /// Every row has a menu (at least Copy details and Show in Horion).
        /// What the row's menu is about, drawn as a small icon after the title (there is no arrow).
        public var hint: Hint?
        /// The event's call (`CallLink`): Meet, Zoom, Teams or another known host. Nil for no link or a website.
        public var call: CallLink? = nil
        /// The logo the Join button shows: "meet", "zoom", or "video" for any other call host. Nil without a call.
        public var logo: String? { call.map { MenuBarMenu.logo($0.kind) } }
        /// Drawn with a Join button: a timed event of today (the head row included) with a call.
        public var join = false
        public enum Hint: Equatable, Sendable { case call, guests }
    }

    /// The rows drawn with a Join button (indices into `rows`), as the mockup's menu: every timed row of today (the head row
    /// included) whose event has a call. Empty when nothing today has a call.
    public var joinIndices: [Int] = []
    /// The first of them.
    public var joinIndex: Int? { joinIndices.first }
    /// That row.
    public var joinRow: Row? { joinIndex.map { rows[$0] } }

    public struct Section: Equatable, Sendable {
        public var title: String
        public var rows: [Row]
        /// 0 today, 1 tomorrow, 2 the day after.
        public var day: Int = 0
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
    case copy
    case show
    case separator

    public var title: String {
        switch self {
        case .join: "Join call"
        case .header(let t): t
        case .respond(let s, _): s == .confirmed ? "Yes" : s == .declined ? "No" : "Maybe"
        case .email(let t, _): t
        case .copy: "Copy details"
        case .show: "Show in Horion"
        case .separator: ""
        }
    }
}

public enum MenuBarMenu {
    /// Builds the menu from the events around `now` (hidden calendars already left out). Declined events are left out.
    /// `canRespond` and `guestAddresses` are what `submenu` gets, so a row has a menu exactly when it has something in it.
    public static func build(events: [CalendarEvent], now: Date, fmt: Fmt, canRespond: Bool = false,
                             guestAddresses: (CalendarEvent) -> [String] = MenuBarMenu.guestAddresses,
                             colorHex: (CalendarEvent) -> String) -> MenuBarMenuModel {
        build(events: events, now: now, fmt: fmt, canRespondTo: { _ in canRespond }, guestAddresses: guestAddresses, colorHex: colorHex)
    }

    /// `canRespondTo`: per event (a mix of Google calendars, which take a reply, and EventKit ones, which do not).
    public static func build(events: [CalendarEvent], now: Date, fmt: Fmt, canRespondTo canRespond: (CalendarEvent) -> Bool,
                             guestAddresses: (CalendarEvent) -> [String] = MenuBarMenu.guestAddresses,
                             colorHex: (CalendarEvent) -> String) -> MenuBarMenuModel {
        let math = fmt.math
        let today = math.startOfDay(now)
        let t = math.date(on: today, minutes: math.minutesSinceMidnight(now))   // the clock in whole minutes
        // The same event in two calendars (same title, start, end) is one row; the second calendar's colour goes on its bar.
        var shown: [CalendarEvent] = [], second: [String: String] = [:]
        for e in events where e.status != .declined {
            if let first = shown.first(where: { $0.title == e.title && $0.start == e.start && $0.end == e.end && $0.isAllDay == e.isAllDay }) {
                let c = colorHex(e)
                if second[first.id] == nil, c != colorHex(first) { second[first.id] = c }
            } else { shown.append(e) }
        }

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
        func row(_ e: CalendarEvent) -> MenuBarMenuModel.Row {
            let sub = submenu(for: e, canRespond: canRespond(e), guestAddresses: guestAddresses(e))
            let hint: MenuBarMenuModel.Row.Hint? = sub.contains { if case .join = $0 { true } else { false } } ? .call
                : sub.contains { if case .respond = $0 { true } else if case .email = $0 { true } else { false } } ? .guests : nil
            return .init(event: e, start: e.isAllDay ? "all-day" : fmt.time(e.start), end: e.isAllDay || e.end == e.start ? nil : fmt.time(e.end),
                         colorHex: colorHex(e), secondColorHex: second[e.id], hint: hint, call: CallLink.parse(e))
        }

        let todays = day(0)
        let f = focus(todays.filter { !$0.isAllDay }, t: t)
        var sections: [MenuBarMenuModel.Section] = []
        for k in 0..<3 {
            var list = k == 0 ? todays.filter { $0.isAllDay || $0.end > t } : day(k)
            if k == 0, let f { list.removeAll { $0.id == f.event.id } }
            guard !list.isEmpty else { continue }
            sections.append(.init(title: sectionTitle(math.addDays(today, k), k: k, fmt: fmt), rows: list.map(row), day: k))
        }
        var m = MenuBarMenuModel(focus: f, head: f.map { row($0.event) }, sections: sections)
        m.joinIndices = joinIndices(m, today: sectionTitle(today, k: 0, fmt: fmt))
        // the same rows, marked on the row so a laid-out line (`MenuBarMenu.lines`) knows it too
        if m.head?.call != nil { m.head?.join = true }
        if let first = m.sections.first, first.day == 0 {
            for k in first.rows.indices where first.rows[k].call != nil && !first.rows[k].event.isAllDay { m.sections[0].rows[k].join = true }
        }
        return m
    }
    /// The head row if it has a call, and every timed row of the Today section with one.
    static func joinIndices(_ m: MenuBarMenuModel, today: String) -> [Int] {
        var out: [Int] = []
        if let h = m.head, h.call != nil { out.append(0) }
        guard let first = m.sections.first, first.title == today else { return out }
        let offset = m.head == nil ? 0 : 1
        return out + first.rows.indices.filter { first.rows[$0].call != nil && !first.rows[$0].event.isAllDay }.map { $0 + offset }
    }

    /// "meet", "zoom", or "video" (Teams and the other hosts).
    public static func logo(_ kind: CallLink.Kind) -> String {
        switch kind {
        case .meet: "meet"
        case .zoom: "zoom"
        case .teams, .other: "video"
        }
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


    /// Join, the answer (only when the store can change it), email (only to guests with an address), then Copy details and Show in Horion. Nothing that does nothing.
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
        out += [.copy, .show]
        if out.first == .separator { out.removeFirst() }
        return out
    }

    /// The event's call link (`CallLink`: conferencing, then the notes, then the location; known meeting hosts only).
    public static func videoURL(_ e: CalendarEvent) -> URL? { CallLink.parse(e)?.url }

    /// The other guests' addresses (guests known only by name have none).
    public static func guestAddresses(_ e: CalendarEvent) -> [String] {
        e.attendees.filter { !$0.isMe }.compactMap { $0.email.isEmpty ? guestAddress($0.label) : $0.email }
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

    /// The event as plain text for the clipboard: title, when, where, call, guests, notes. Empty parts are left out.
    ///
    ///     Design review
    ///     Thu 19 Nov · 10:00–11:30
    ///     Room 2.14
    ///     Call: https://meet.google.com/abc-defg-hij
    ///     Guests: Sam Okafor, Mia Chen
    ///
    ///     Bring the printouts.
    public static func details(_ e: CalendarEvent, fmt: Fmt) -> String {
        let m = fmt.math
        func day(_ d: Date) -> String { "\(fmt.weekdayShort(d)) \(m.day(d)) \(fmt.monthShort(d))" }
        let when: String
        if e.isAllDay {
            let last = m.addDays(m.startOfDay(e.end), -1)
            when = (m.startOfDay(e.start) >= last ? day(e.start) : "\(day(e.start)) \u{2013} \(day(last))") + " \u{00B7} all day"
        } else if m.startOfDay(e.start) == m.startOfDay(e.end) || e.end == m.addDays(m.startOfDay(e.start), 1) {
            when = "\(day(e.start)) \u{00B7} \(fmt.timeRange(e.start, e.end))"
        } else {
            when = "\(day(e.start)) \(fmt.time(e.start)) \u{2013} \(day(e.end)) \(fmt.time(e.end))"
        }
        var lines = [e.title.trimmingCharacters(in: .whitespacesAndNewlines), when]
        let place = e.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !place.isEmpty { lines.append(place) }
        let other = e.conferencing.trimmingCharacters(in: .whitespacesAndNewlines)
        if let call = videoURL(e) { lines.append("Call: " + call.absoluteString) }
        else if !other.isEmpty, other != place { lines.append("Link: " + other) }
        if !e.participants.isEmpty { lines.append("Guests: " + e.participants.map(guestName).joined(separator: ", ")) }
        let notes = e.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { lines += ["", notes] }
        return lines.joined(separator: "\n")
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

/// One line of the menu as it is laid out for a screen: today and tomorrow in full, the day after as one row,
/// and an "N more" row only when the menu would be taller than half the screen.
public enum MenuBarLine: Equatable, Sendable {
    case header(String)
    case row(MenuBarMenuModel.Row)
    /// A row whose submenu lists `sections`: the day after ("Mon 23 Nov", "13 events"), or what did not fit ("7 more tomorrow").
    case fold(title: String, detail: String?, sections: [MenuBarMenuModel.Section])
    case separator
}

extension MenuBarMenu {
    /// Heights as the menu draws them (pt): rows and headers, separators, the menu's top and bottom padding.
    public static let rowHeight: CGFloat = 22, separatorHeight: CGFloat = 11, menuPadding: CGFloat = 10
    /// The fixed foot: separator, Open Horion, Settings, separator, Quit.
    public static let footHeight: CGFloat = 2 * separatorHeight + 3 * rowHeight

    /// The event part of the menu (the head block and the days, without the foot), fitted to `maxHeight`
    /// (half the screen the menu opens on). Rows that do not fit go into one "N more" fold, in order.
    public static func lines(_ m: MenuBarMenuModel, maxHeight: CGFloat) -> [MenuBarLine] {
        var out: [MenuBarLine] = []
        if let head = m.head { out += [.header(m.headLabel), .row(head)] } else { out.append(.header(m.headLabel)) }
        out.append(.separator)
        let full = m.sections.filter { $0.day < 2 }, later = m.sections.filter { $0.day >= 2 }
        var used = menuPadding + (m.head == nil ? rowHeight + separatorHeight : 2 * rowHeight + separatorHeight) + footHeight
        used += CGFloat(later.count) * rowHeight
        let total = full.reduce(CGFloat(0)) { $0 + rowHeight * CGFloat(1 + $1.rows.count) }
        var room = maxHeight - used - (used + total > maxHeight ? rowHeight : 0)
        var rest: [MenuBarMenuModel.Section] = []
        for s in full {
            let fit = room >= 2 * rowHeight ? min(s.rows.count, Int(((room - rowHeight) / rowHeight).rounded(.down))) : 0
            if fit > 0 {
                out.append(.header(s.title))
                out += s.rows.prefix(fit).map(MenuBarLine.row)
                room -= rowHeight * CGFloat(1 + fit)
            }
            if fit < s.rows.count { rest.append(.init(title: s.title, rows: Array(s.rows.dropFirst(fit)), day: s.day)) }
        }
        if !rest.isEmpty {
            let n = rest.reduce(0) { $0 + $1.rows.count }
            let when = rest.count == 1 ? (rest[0].day == 0 ? " today" : " tomorrow") : ""
            out.append(.fold(title: "\(n) more\(when)", detail: nil, sections: rest))
        }
        for s in later { out.append(.fold(title: s.title, detail: s.rows.count == 1 ? "1 event" : "\(s.rows.count) events", sections: [s])) }
        return out
    }
}
