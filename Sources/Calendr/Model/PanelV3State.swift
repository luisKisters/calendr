import Foundation
import AppKit
import CalendrKit

/// v3 view state of the PANEL area (RightPanelView, RootView). Stored on `AppModel.panelState`.
struct PanelV3State: Equatable {
    /// Today column: what runs now, what comes next, the rest of the day. Rebuilt with `refreshUpcoming`.
    var today = PanelToday()
    /// Fields opened with an "add" chip, per event id, so an empty field can show while it is being filled in.
    var added: [String: Set<PanelField>] = [:]
    /// Times an event had before it was made all-day, so switching back restores them.
    var timedBefore: [String: DateInterval] = [:]
    /// The title was edited since the last focus request: later focus nudges must not select what was typed.
    var titleTyped = false
}

enum PanelField: String, CaseIterable, Hashable {
    case place, guests, video, notes
    var label: String {
        switch self {
        case .place: "Place"
        case .guests: "Guests"
        case .video: "Video call"
        case .notes: "Notes"
        }
    }
}

/// app-views.js `upNext`: today's timed events that are not declined, by start.
struct PanelToday: Equatable {
    var live: CalendarEvent?
    var next: CalendarEvent?
    var later: [CalendarEvent] = []

    static func build(_ events: [CalendarEvent], now: Date, math: CalendarMath) -> PanelToday {
        // Today's events, and one that started before today and still runs.
        let list = events.filter { !$0.isAllDay && $0.status != .declined && (math.isSameDay($0.start, now) || $0.start <= now && $0.end > now) }
            .sorted { $0.start != $1.start ? $0.start < $1.start : $0.end < $1.end }
        let rest = list.filter { $0.start > now }
        return PanelToday(live: list.first { $0.start <= now && $0.end > now }, next: rest.first, later: Array(rest.dropFirst()))
    }
}

/// Texts of the panel, as the mockup writes them (data.js `fmtDay`, `dur`, app-views.js `inMin`).
enum PanelText {
    /// "Tue 29 Sep"
    static func day(_ d: Date, _ fmt: Fmt) -> String { "\(fmt.weekdayShort(d)) \(fmt.math.day(d)) \(fmt.monthShort(d))" }
    /// "1h 30m", "45m", "2h"
    static func duration(_ minutes: Int) -> String {
        let h = max(0, minutes) / 60, m = max(0, minutes) % 60
        return h > 0 && m > 0 ? "\(h)h \(m)m" : h > 0 ? "\(h)h" : "\(m)m"
    }
    /// "in 12 min", "in 2h 5m"
    static func until(_ minutes: Int) -> String { minutes < 60 ? "in \(max(0, minutes)) min" : "in \(duration(minutes))" }
    /// The answer to "Going?" as the segmented control names it.
    static func response(_ s: ResponseStatus) -> String {
        switch s {
        case .confirmed: "Yes"
        case .tentative: "Maybe"
        case .declined: "No"
        }
    }
    /// "Weekly on Tue", "Every weekday", "Every day"
    static func repeats(_ e: CalendarEvent, _ fmt: Fmt) -> String? {
        guard let r = e.recurrence else { return e.seriesID != nil ? "Repeats" : nil }
        if r.interval == 1 && r.until == nil {
            switch r.frequency {
            case .daily: return "Every day"
            case .weekly:
                let days = r.weekdays.isEmpty ? [fmt.math.calendar.component(.weekday, from: e.start)] : r.weekdays
                if Set(days) == [2, 3, 4, 5, 6] { return "Every weekday" }
                if days.count == 7 { return "Every day" }
                let fw = fmt.math.calendar.firstWeekday
                return "Weekly on " + days.sorted { ($0 - fw + 7) % 7 < ($1 - fw + 7) % 7 }.map { Fmt.weekdayShort[$0 - 1] }.joined(separator: ", ")
            default: break
            }
        }
        return RecurrenceDescriber.describe(r, start: e.start, fmt: fmt).full
    }
    /// First line of a location, for one-line places ("Halden College, North Campus").
    static func place(_ location: String) -> String? {
        let first = location.split(whereSeparator: \.isNewline).first.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespaces)) }
        return first?.isEmpty == false ? first : nil
    }
    /// Two initials for a guest chip: "Sam Okafor" -> "SO", "mateo.alvarez@x.com" -> "MA".
    static func initials(_ guest: String) -> String {
        let name = guest.split(separator: "@").first.map(String.init) ?? guest
        let words = name.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "_" || $0 == "-" })
        return words.prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
    }
    /// The date field takes words ("fri", "oct 12") and its own text back ("Tue 29 Sep"). Words count from today;
    /// a date typed without a year keeps the event's year ("13 Jan" on a January event does not jump to next year).
    static func parseDay(_ raw: String, now: Date, event: Date, math: CalendarMath) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        let bare = s.replacingOccurrences(of: #"^[A-Za-z]+,? (?=\d)"#, with: "", options: .regularExpression)     // "Tue 29 Sep" -> "29 Sep"
        func parse(_ from: Date) -> Date? { GoToDateParser.parse(s, now: from, math: math) ?? GoToDateParser.parse(bare, now: from, math: math) }
        guard let d = parse(now) else { return nil }
        if let near = parse(event), math.year(near) != math.year(d),
           math.calendar.dateComponents([.month, .day], from: near) == math.calendar.dateComponents([.month, .day], from: d) { return near }
        return d
    }
    /// A pasted video link: "https://…" or "host.tld/…" (stored with https). Nil for anything that is not a web address.
    static func videoLink(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !s.contains(where: \.isWhitespace) else { return nil }
        guard let u = URL(string: s.contains("://") ? s : "https://" + s), let scheme = u.scheme?.lowercased(),
              scheme == "https" || scheme == "http", let host = u.host(), host.contains("."), !host.hasPrefix("."), !host.hasSuffix(".") else { return nil }
        return u.absoluteString
    }
}

/// Event edits from the panel, the draft's save and discard, and the Today column.
extension AppModel {
    var isDraftOpen: Bool { draft != nil && draft?.id == selectedEventID }

    func refreshPanelToday(_ events: [CalendarEvent]) {
        let t = PanelToday.build(events, now: now, math: math)
        if t != panelState.today { panelState.today = t }
    }

    /// Return or Save: write the event (untitled becomes "New event"), close it, back to Today.
    func saveDraft() {
        guard var d = draft else { return }
        d.title = d.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if d.title.isEmpty { d.title = "New event" }
        closeDraft()
        do {
            let saved = try store.create(d)
            undoStack.push(.created(saved))
        } catch { showToast("Could not save event") }
        storeChanged()      // the saved event shows at once, before the store's change notification
    }

    /// Esc or the close button while creating: the draft goes, silently. Nothing was written, so nothing is.
    func discardDraft() {
        guard draft != nil else { return }
        closeDraft()
        reload()
    }

    /// Clicking elsewhere, navigating, creating another: a draft with a title is saved, an untitled one dropped.
    func settleDraft() {
        guard let d = draft else { return }
        if d.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { discardDraft() } else { saveDraft() }
    }

    private func closeDraft() {
        guard let d = draft else { return }
        draft = nil
        panelState.added[d.id] = nil
        panelState.timedBefore[d.id] = nil
        titleFocusPending = false
        if selectedEventID == d.id { selectedEventID = nil }
        selectedSlot = nil
    }

    /// Close × of the panel.
    func closePanel() { if isDraftOpen { discardDraft() } else { deselect() } }

    /// Opens an event from the Today column; the grid follows when it shows another period.
    func panelOpen(_ e: CalendarEvent) {
        if !visibleDays.contains(where: { math.isSameDay($0, e.start) }) { go(to: e.start) }
        select(eventID: e.id)
        scrollToHourTick += 1
    }

    func addPanelField(_ f: PanelField) {
        guard let e = selectedEvent else { return }
        panelState.added[e.id, default: []].insert(f)
    }

    func panelShows(_ f: PanelField, _ e: CalendarEvent) -> Bool {
        let added = panelState.added[e.id]?.contains(f) ?? false
        switch f {
        case .place: return !e.location.isEmpty || added
        case .guests: return !e.participants.isEmpty || added
        case .video: return !e.conferencing.isEmpty || added
        case .notes: return !e.notes.isEmpty || added
        }
    }

    /// Start keeps the length; the event stays inside its day.
    func setSelectedStart(_ minutes: Int) {
        updateSelected { ev in
            let len = ev.end.timeIntervalSince(ev.start)
            let day = math.startOfDay(ev.start)
            ev.start = math.date(on: day, minutes: min(minutes, 1440 - 15))
            ev.end = min(ev.start.addingTimeInterval(len), math.addDays(day, 1))
        }
    }

    /// An end at or before the start is refused (returns false).
    func setSelectedEnd(_ minutes: Int) -> Bool {
        guard let e = selectedEvent, minutes > math.minutesSinceMidnight(e.start) else { return false }
        updateSelected { $0.end = math.date(on: $0.start, minutes: minutes) }
        return true
    }

    /// Moves the event to another day, times unchanged. Returns false when the text is not a date.
    func setSelectedDay(_ text: String) -> Bool {
        guard let e = selectedEvent, let d = PanelText.parseDay(text, now: now, event: e.start, math: math) else { return false }
        let delta = math.daysBetween(e.start, d)
        if delta != 0 { updateSelected { $0.start = math.addDays($0.start, delta); $0.end = math.addDays($0.end, delta) } }
        if !visibleDays.contains(where: { math.isSameDay($0, d) }) { go(to: d, settling: false) }
        return true
    }

    func setSelectedAllDay(_ on: Bool) {
        guard let e = selectedEvent, e.isAllDay != on else { return }
        if on { panelState.timedBefore[e.id] = DateInterval(start: e.start, end: e.end) }
        let before = panelState.timedBefore[e.id]
        updateSelected { ev in
            ev.isAllDay = on
            let day = math.startOfDay(ev.start)
            if on { ev.start = day; ev.end = math.addDays(day, 1) }
            else if let before, before.duration > 0 {
                let shift = math.daysBetween(before.start, day)
                ev.start = math.addDays(before.start, shift); ev.end = math.addDays(before.end, shift)
            } else {
                ev.start = math.date(on: day, minutes: 9 * 60); ev.end = ev.start.addingTimeInterval(Double(settings.defaultDurationMinutes) * 60)
            }
        }
    }

    func addGuest(_ name: String) {
        let v = name.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return }
        updateSelected { $0.participants.append(v) }
    }

    /// Only the demo store makes up a call link; real calendars take a pasted one (`setVideoLink`).
    var canInventVideoLink: Bool { store is DemoStore }

    /// Returns false when the text is not a web address.
    func setVideoLink(_ text: String) -> Bool {
        guard let link = PanelText.videoLink(text) else { return false }
        updateSelected { $0.conferencing = link }
        return true
    }

    func createVideoLink() {
        updateSelected { ev in
            let slug = ev.title.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            ev.conferencing = "meet.example.com/" + String((slug.isEmpty ? "call" : slug).prefix(18))
        }
    }

    func joinCall(_ e: CalendarEvent) {
        if options.isHeadless { showToast("Opens the call in your browser"); return }
        let link = e.conferencing.trimmingCharacters(in: .whitespacesAndNewlines)
        if let u = URL(string: link.contains("://") ? link : "https://" + link) { NSWorkspace.shared.open(u) }
    }
}
