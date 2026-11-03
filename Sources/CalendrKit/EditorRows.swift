import Foundation

/// One row of the event editor (design/mockup-v4 `detail()`), in the order the right column shows them.
public enum EditorRow: String, CaseIterable, Sendable {
    case title, when, repeats, findTime, participants, going, call, location, notes, calendar, reminders

    /// What an empty row shows, in fg3. Nil for rows that always have a value.
    public var placeholder: String? {
        switch self {
        case .title: "(No title)"
        case .repeats: "Does not repeat"
        case .participants: "Add participants"
        case .call: "Add conferencing"
        case .location: "Add location"
        case .notes: "Add notes"
        case .reminders: "Add reminder"
        case .when, .findTime, .going, .calendar: nil
        }
    }
}

/// What decides which rows an event shows.
public struct EditorContext: Equatable, Sendable {
    /// Guests other than me.
    public var hasOthers: Bool
    /// I may change the shared fields (title, time, guests, call, place, notes).
    public var canEdit: Bool
    /// The event is being created and not saved yet.
    public var isDraft: Bool
    /// The guest list has my own entry (I am invited or I organise it).
    public var hasMyEntry: Bool

    public init(hasOthers: Bool, canEdit: Bool, isDraft: Bool, hasMyEntry: Bool) {
        self.hasOthers = hasOthers; self.canEdit = canEdit; self.isDraft = isDraft; self.hasMyEntry = hasMyEntry
    }

    public init(_ e: CalendarEvent, canEdit: Bool, isDraft: Bool) {
        self.init(hasOthers: e.attendees.contains { !$0.isMe }, canEdit: canEdit, isDraft: isDraft, hasMyEntry: e.attendees.contains(where: \.isMe))
    }
}

public enum EditorRows {
    /// Every row is always there (an empty one shows its placeholder), except two that need people: "Find a new time" needs other
    /// guests and the right to move the event; "Going?" needs an invitation (my entry and other guests) that is saved.
    public static func rows(_ c: EditorContext) -> [EditorRow] {
        EditorRow.allCases.filter { r in
            switch r {
            case .findTime: c.hasOthers && c.canEdit
            case .going: c.hasMyEntry && c.hasOthers && !c.isDraft
            default: true
            }
        }
    }

    /// The fields guests see. A change to one of them is an update to send; reminders, colour, calendar, availability and my reply are mine.
    public static func sharedChanged(_ a: CalendarEvent, _ b: CalendarEvent) -> Bool {
        a.title != b.title || a.start != b.start || a.end != b.end || a.isAllDay != b.isAllDay || a.recurrence != b.recurrence
            || a.location != b.location || a.notes != b.notes || a.conferencing != b.conferencing || guests(a) != guests(b)
    }

    /// `target` with my own fields (reminders, colour, calendar, availability, visibility, my reply) taken from `source`.
    public static func personal(of source: CalendarEvent, onto target: CalendarEvent) -> CalendarEvent {
        var t = target
        t.reminders = source.reminders; t.colorHex = source.colorHex; t.calendarID = source.calendarID
        t.availability = source.availability; t.visibility = source.visibility; t.status = source.status
        return t
    }

    /// The guest list without the replies (a reply is not a change to send).
    static func guests(_ e: CalendarEvent) -> [String] { e.attendees.map { "\($0.email)|\($0.name ?? "")|\($0.isOptional)" } }

    /// "2 yes, 1 maybe, 1 no, 1 awaiting" (mockup `gsum`): every entry, mine included, the organizer counted as yes.
    public static func replySummary(_ attendees: [Attendee]) -> String {
        var yes = 0, maybe = 0, no = 0, none = 0
        for a in attendees {
            switch a.isOrganizer ? .confirmed : a.status {
            case .confirmed: yes += 1
            case .tentative: maybe += 1
            case .declined: no += 1
            case .needsAction: none += 1
            }
        }
        return [yes > 0 ? "\(yes) yes" : nil, maybe > 0 ? "\(maybe) maybe" : nil, no > 0 ? "\(no) no" : nil, none > 0 ? "\(none) awaiting" : nil]
            .compactMap { $0 }.joined(separator: ", ")
    }

    /// "5 participants", "1 participant"
    public static func participantCount(_ n: Int) -> String { "\(n) participant\(n == 1 ? "" : "s")" }

    /// "organizer · you", "optional"
    public static func role(_ a: Attendee) -> String {
        [a.isOrganizer ? "organizer" : nil, a.isMe ? "you" : nil, a.isOptional ? "optional" : nil].compactMap { $0 }.joined(separator: " · ")
    }

    /// Guests known only by their address: the "N without a name · Allow Contacts" row counts them.
    public static func withoutName(_ attendees: [Attendee]) -> Int {
        attendees.filter { ($0.name ?? "").trimmingCharacters(in: .whitespaces).isEmpty && !$0.email.isEmpty }.count
    }
}

/// Reminder rows (mockup `remLabel`): minutes before the start.
public enum Reminders {
    /// The choices of the "Add reminder" menu.
    public static let choices = [0, 5, 10, 15, 30, 60, 1440]

    /// "At start", "10 min before", "1 hour before", "2 hours before", "1 day before"
    public static func label(_ m: Int) -> String {
        m == 0 ? "At start" : "\(amount(m)) before"
    }

    /// The row's first part, "10 min", "1 hour", "2 days" (the editor greys the "before" after it). "At start" for 0.
    public static func amount(_ m: Int) -> String {
        if m <= 0 { return "At start" }
        if m < 60 { return "\(m) min" }
        if m < 1440 { return m % 60 == 0 ? "\(m / 60) hour\(m > 60 ? "s" : "")" : "\(m / 60)h \(m % 60)m" }
        return m % 1440 == 0 ? "\(m / 1440) day\(m > 1440 ? "s" : "")" : "\(m / 60) hours"
    }

    /// Adds the reminder, or removes it when it is there. The list stays unique and sorted.
    public static func toggled(_ list: [Int], _ m: Int) -> [Int] {
        list.contains(m) ? list.filter { $0 != m } : Array(Set(list + [max(0, m)])).sorted()
    }
}

/// The 11 Google event colours (mockup `SWATCHES`), in Google's order.
public enum EventColors {
    public struct Swatch: Equatable, Sendable { public let hex: String; public let name: String }
    public static let google: [Swatch] = [
        Swatch(hex: "#D9443A", name: "Tomato"), Swatch(hex: "#C9736A", name: "Flamingo"), Swatch(hex: "#F2884B", name: "Tangerine"),
        Swatch(hex: "#F2C94C", name: "Banana"), Swatch(hex: "#5FB97E", name: "Sage"), Swatch(hex: "#9BD9C0", name: "Mint"),
        Swatch(hex: "#5DADE2", name: "Peacock"), Swatch(hex: "#5B8DEF", name: "Blueberry"), Swatch(hex: "#A9A6F5", name: "Lavender"),
        Swatch(hex: "#9254DE", name: "Grape"), Swatch(hex: "#B9B9B9", name: "Graphite"),
    ]
    /// The menu's grid: the calendar colour first, then the 11 swatches, 6 to a row.
    public static let columns = 6
}

/// The notes as the editor shows them: Google's Meet block hidden (one "Google Meet details hidden" line instead).
public enum MeetNotes {
    /// The notes without the Meet block, and whether there was one.
    public static func visible(_ notes: String) -> (text: String, hidden: Bool) {
        let s = CallLink.stripMeetBoilerplate(notes)
        return (s.notes, s.hadMeet)
    }

    /// The notes after the user edited the visible part: the Meet block stays at the end, as Google wrote it.
    public static func replacingVisible(in notes: String, with text: String) -> String {
        guard let block = block(notes) else { return text }
        return text.isEmpty ? block : text + "\n\n" + block
    }

    /// The first Meet block (both fence lines included), or nil.
    static func block(_ notes: String) -> String? {
        let lines = notes.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        func fence(_ l: String) -> Bool {
            l.trimmingCharacters(in: .whitespaces).range(of: #"^-::~[:~]*::-$"#, options: .regularExpression) != nil
        }
        var i = 0
        while i < lines.count {
            if fence(lines[i]), let close = lines[(i + 1)...].firstIndex(where: fence),
               lines[(i + 1)..<close].contains(where: { $0.contains("meet.google.com/") }) {
                return lines[i...close].joined(separator: "\n")
            }
            i += 1
        }
        return nil
    }

    /// Google's block for a Meet code (mockup `BOILER`), for the demo data.
    public static func boilerplate(_ code: String) -> String {
        let fence = "-::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-"
        return "\(fence)\nJoin with Google Meet: https://meet.google.com/\(code)\n\nLearn more about Meet at: https://support.google.com/a/users/answer/9282720\n\nPlease do not edit this section.\n\(fence)"
    }
}

/// A place the location field suggests (MapKit's completer, or the demo list).
public struct PlaceSuggestion: Equatable, Hashable, Sendable {
    public var title: String
    public var subtitle: String
    public init(title: String, subtitle: String) { self.title = title; self.subtitle = subtitle }
    /// What the field takes: "Market Hall, 42 Station Road".
    public var text: String { subtitle.isEmpty ? title : "\(title), \(subtitle)" }

    /// The demo places (mockup `PLACES`, invented).
    public static let demo: [PlaceSuggestion] = [
        ("Northwind Studio", "40 Market Street"), ("Market Street", "City centre"), ("Market Street 12", "City centre"), ("Café Lumen", "2 Market Street"),
        ("Market Hall", "42 Station Road"), ("St. Mary's Hall", "8 Church Square"), ("Harbour Street 12", "Old town"), ("Riverside Park", "River Road"),
        ("Central Station", "1 Station Square"), ("Coworking Loft", "23 Canal Street"), ("City Library", "72 Park Avenue"), ("Common Field", "Airfield Road"),
    ].map { PlaceSuggestion(title: $0.0, subtitle: $0.1) }

    /// Mockup `placesFor`: two letters or more, matched anywhere in the name or address, at most 5, never the text itself.
    public static func filter(_ list: [PlaceSuggestion], _ query: String) -> [PlaceSuggestion] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }
        return Array(list.filter { "\($0.title) \($0.subtitle)".lowercased().contains(q) && $0.text != query }.prefix(5))
    }
}
