import Foundation
import CalendrKit

/// The v4 fixture (`--fixture v4`): a port of design/mockup-v4/index.html `CALS0`, `ACCTS0`, `PEOPLE`, `RAW`, `RAW_AD` and `seedEvents()`
/// (mockup :800-899), so app snapshots and mockup shots show the same week. Sam Rivera, Mon 28 Sep - Sun 4 Oct 2026, "now" Sun 4 Oct 15:10,
/// 46 pt per hour. Invented data: every address uses a reserved example domain. Only the showcase week has events.
enum DemoDataV4 {
    static let math = DemoData.math
    static let weekStart = math.date(year: 2026, month: 9, day: 28)
    static let now = math.date(year: 2026, month: 10, day: 4, hour: 15, minute: 10)
    static let hourHeight = 46.0

    // MARK: Calendars and accounts (CALS0, ACCTS0)

    static let g1 = "v4.g1", g2 = "v4.g2", g3 = "v4.g3"
    static let personal = "v4.personal", family = "v4.family", tasks = "v4.tasks", club = "v4.club", work = "v4.work", side = "v4.side"
    /// `CALS0` keys to calendar ids.
    static let calendarIDs = ["personal": personal, "family": family, "tasks": tasks, "club": club, "work": work, "side": side]

    static let accounts: [CalendarAccount] = [
        CalendarAccount(id: g1, name: "sam.rivera@example.com", calendars: [
            CalendarInfo(id: personal, accountID: g1, title: "Personal", colorHex: "#5B8DEF", isDefault: true),
            CalendarInfo(id: family, accountID: g1, title: "Family", colorHex: "#F2884B"),
            // `task: true` in the mockup: tasks stay plain events until TickTick.
            CalendarInfo(id: tasks, accountID: g1, title: "Tasks", colorHex: "#B9B9B9"),
            CalendarInfo(id: club, accountID: g1, title: "Running club", colorHex: "#F2C94C"),
        ]),
        CalendarAccount(id: g2, name: "sam@northwind.example", calendars: [
            CalendarInfo(id: work, accountID: g2, title: "Work", colorHex: "#5DADE2"),
        ]),
        CalendarAccount(id: g3, name: "sam@sideproject.example", calendars: [
            CalendarInfo(id: side, accountID: g3, title: "Side project", colorHex: "#E9B949"),
        ]),
    ]

    // MARK: People (PEOPLE)

    struct Person { var key: String; var name: String; var email: String }
    /// The display name is `name`, else the Google name, else the Contacts name.
    static let people: [Person] = [
        Person(key: "me", name: "Sam Rivera", email: "sam.rivera@example.com"),
        Person(key: "icloud", name: "Sam Rivera", email: "sam@example.net"),
        Person(key: "svc", name: "Sam Rivera", email: "sam@northwind.example"),
        Person(key: "mara", name: "Mara Hoffmann", email: "mara.hoffmann@example.com"),
        Person(key: "jonas", name: "Jonas Weber", email: "jonas.weber@example.org"),
        Person(key: "theo", name: "Theo Park", email: "theo.park@example.com"),
        Person(key: "lea", name: "Lea Brandt", email: "lea.brandt@example.org"),
        Person(key: "dion", name: "Dion Kraft", email: "dion.k@example.com"),
        Person(key: "ines", name: "Ines Duarte", email: "ines.d@example.com"),
        Person(key: "tom", name: "Tom Richter", email: "tom.richter@example.net"),
        Person(key: "sven", name: "Sven Krüger", email: "sven@client.example"),
        Person(key: "nina", name: "Nina Hale", email: "nina.hale@example.com"),
        Person(key: "nils", name: "Nils Bauer", email: "n.bauer@club.example"),
        Person(key: "ida", name: "Ida Sommer", email: "ida.sommer@example.org"),
    ]
    static func person(_ key: String) -> Person { people.first { $0.key == key }! }

    /// Meet with: everyone except Sam's own addresses.
    static let teammates: [Teammate] = people.filter { !["me", "icloud", "svc"].contains($0.key) }.map { Teammate(name: $0.name, email: $0.email) }

    // MARK: Replies

    /// The mockup's reply values. `none` is invited, not answered yet.
    enum Reply: String { case yes, maybe, no, none }

    /// The one mapping from a mockup reply to the event status.
    static func status(_ r: Reply) -> ResponseStatus {
        switch r {
        case .yes: .confirmed
        case .maybe: .tentative
        case .no: .declined
        case .none: .needsAction
        }
    }

    struct Guest { var key: String; var reply: Reply; var organizer = false }
    enum Call { case meet(String), zoom(String) }

    /// One mockup event (`seedEvents()` with its `Object.assign` and `inv` overrides applied).
    struct Seed {
        var id: String
        var day: Int                 // 0 = Mon 28 Sep ... 6 = Sun 4 Oct
        var start = 0, end = 0       // minutes since midnight
        var title: String
        var cal: String              // CALS0 key
        var allDay = false
        var span = 1
        var color: String?
        var guests: [Guest] = []
        var call: Call?
        var location = ""
        var notes = ""
        var reminders: [Int] = [10]
        var free = false
        var repeatWeekday: Int?      // Calendar weekday (Sunday = 1) of "Every week on ..."
        var organizer = true

        /// Sam's reply: the `me` guest, or yes when there are no guests.
        var myReply: Reply { guests.first { $0.key == "me" }?.reply ?? .yes }
    }

    static let green = "#5FB97E"

    static func m(_ t: String) -> Int { let p = t.split(separator: ":").compactMap { Int($0) }; return p[0] * 60 + p[1] }

    /// `RAW`: id, day, start, end, title, calendar.
    static let raw: [(String, Int, String, String, String, String)] = [
        ("a1", 0, "08:00", "09:45", "Deep work", "work"), ("a2", 0, "12:00", "13:40", "Team lunch", "work"), ("a3", 0, "14:00", "16:00", "Design review", "work"),
        ("a4", 0, "14:10", "14:10", "Call the landlord", "tasks"), ("a5", 0, "21:30", "22:15", "Evening walk", "personal"),
        ("b1", 1, "08:00", "09:45", "Deep work", "work"), ("b2", 1, "10:00", "10:30", "Standup", "work"), ("b3", 1, "12:00", "13:40", "Team lunch", "work"),
        ("b4", 1, "14:35", "16:10", "Research interviews", "work"), ("b5", 1, "16:00", "16:00", "[P2] Fill in the insurance form", "tasks"), ("b6", 1, "16:30", "18:30", "Focus block", "work"),
        ("b7", 1, "18:15", "18:15", "[P1] Take vitamins", "tasks"), ("b8", 1, "19:30", "20:30", "Flat meeting", "personal"), ("b9", 1, "19:40", "19:40", "📦 Pick up the parcel", "tasks"), ("b10", 1, "23:15", "23:45", "Journal", "personal"),
        ("c1", 2, "09:00", "09:00", "Wish Nina a happy birthday", "tasks"), ("c2", 2, "12:00", "13:15", "Reading", "personal"), ("c3", 2, "14:00", "16:00", "Lunch with Theo", "personal"),
        ("c4", 2, "14:10", "14:10", "Call the landlord", "tasks"), ("c5", 2, "18:15", "18:15", "[P1] Take vitamins", "tasks"), ("c6", 2, "21:30", "22:15", "Evening walk", "personal"),
        ("d1", 3, "08:00", "09:30", "Deep work", "work"), ("d2", 3, "11:00", "12:00", "Club committee", "club"), ("d3", 3, "13:00", "14:00", "Lunch", "family"),
        ("d4", 3, "17:00", "18:00", "Office hours", "side"), ("d5", 3, "17:30", "18:30", "Client call", "work"), ("d6", 3, "21:30", "22:15", "Evening walk", "personal"),
        ("e1", 4, "08:00", "09:45", "Deep work", "work"), ("e2", 4, "10:00", "11:30", "Usability test", "work"), ("e3", 4, "15:00", "16:30", "Pitch rehearsal", "side"), ("e4", 4, "19:00", "22:00", "Cinema", "family"),
        ("f1", 5, "11:00", "12:30", "Brunch", "family"), ("f2", 5, "15:00", "17:00", "Prepare the talk", "personal"), ("f3", 5, "20:00", "23:00", "Nina's birthday party", "family"),
        ("g1", 6, "09:45", "11:30", "Long run", "club"), ("g2", 6, "09:40", "09:40", "[P1] Reply to Ines", "tasks"), ("g3", 6, "14:45", "15:45", "Test", "personal"),
        ("g4", 6, "17:00", "17:30", "[P0] Weekly review", "tasks"), ("g5", 6, "18:15", "18:15", "[P1] Take vitamins", "tasks"), ("wg", 6, "19:00", "20:00", "Flat dinner", "personal"),
        ("w1", 2, "17:00", "18:30", "Founder meetup", "side"), ("w2", 2, "17:15", "18:45", "Idea session", "personal"), ("w3", 2, "18:00", "19:00", "Flat cleaning", "personal"),
        ("w4", 2, "19:00", "20:00", "Dinner break", "personal"), ("w5", 2, "19:00", "20:00", "Club board meeting", "club"), ("w6", 2, "20:00", "21:30", "Project sync", "club"), ("w7", 2, "20:15", "20:45", "Practice quiz", "personal"),
        ("w8", 0, "19:00", "20:30", "Family dinner", "family"), ("w9", 5, "13:00", "14:30", "Flea market", "family"),
        ("g6", 6, "19:00", "19:00", "Groceries", "tasks"), ("g7", 6, "21:30", "22:15", "Evening walk", "personal"), ("g8", 6, "22:49", "22:49", "Evening reading", "tasks"), ("g9", 6, "23:10", "23:10", "Bedtime", "personal"),
    ]

    /// `RAW_AD`: day, span in days, title, calendar.
    static let rawAllDay: [(Int, Int, String, String)] = [
        (0, 1, "[P1] Send the invoices", "tasks"), (2, 1, "Quarterly check-in", "personal"), (3, 1, "[P2] Study for the quiz", "tasks"),
        (4, 3, "Trip (maybe)", "personal"), (4, 3, "Alex away", "personal"), (4, 1, "[P2] File the tax form", "tasks"), (4, 1, "[P3] Cancel the subscription", "tasks"),
        (5, 1, "Nina's birthday", "personal"), (5, 1, "[P1] Talk prep with Ines", "tasks"), (5, 1, "[P2] Practise the pitch", "tasks"), (5, 1, "[P3] Follow up on the contract", "tasks"), (5, 1, "[P3] Book the dentist", "tasks"),
        (6, 1, "[P1] Check the claim", "tasks"), (6, 1, "[P2] Call Kim", "tasks"),
    ]

    /// `seedEvents()`.
    static func seeds() -> [Seed] {
        var evs = raw.map { Seed(id: $0.0, day: $0.1, start: m($0.2), end: m($0.3), title: $0.4, cal: $0.5) }
        for (i, a) in rawAllDay.enumerated() {
            evs.append(Seed(id: "ad\(i)", day: a.0, title: a.2, cal: a.3, allDay: true, span: a.1, reminders: [], free: true))
        }
        func g(_ id: String, _ f: (inout Seed) -> Void) { if let i = evs.firstIndex(where: { $0.id == id }) { f(&evs[i]) } }
        func gu(_ k: String, _ r: Reply, org: Bool = false) -> Guest { Guest(key: k, reply: r, organizer: org) }
        g("wg") {
            $0.color = green; $0.repeatWeekday = 1
            $0.guests = [gu("me", .yes, org: true), gu("mara", .yes), gu("jonas", .maybe), gu("dion", .no), gu("icloud", .none)]
            $0.call = .meet("cmv-hjhb-qgb"); $0.location = "Kitchen, 12 Harbour Street"
            $0.notes = "Everyone brings something to eat.\nPlan the cleaning rota for October."
        }
        g("d4") {
            $0.organizer = false; $0.repeatWeekday = 5
            $0.guests = [gu("jonas", .yes, org: true), gu("me", .yes), gu("mara", .none), gu("theo", .no)]
            $0.call = .meet("qpe-tnwa-kdz"); $0.notes = "Put your questions in the doc first."
        }
        g("d5") { $0.guests = [gu("me", .yes, org: true), gu("sven", .yes)]; $0.call = .zoom("zoom.us/j/88123456789") }
        g("c3") { $0.guests = [gu("me", .yes, org: true), gu("theo", .yes)]; $0.location = "Market Hall, 42 Station Road" }
        g("g1") { $0.color = green; $0.repeatWeekday = 1; $0.location = "Riverside Park, River Road" }
        func inv(_ id: String, _ org: String, _ resp: Reply, _ more: [Guest] = []) {
            g(id) { $0.organizer = false; $0.guests = [gu(org, .yes, org: true), gu("me", resp)] + more }
        }
        inv("w2", "lea", .maybe, [gu("dion", .yes)]); inv("w3", "mara", .no, [gu("jonas", .yes)]); inv("w5", "nils", .none, [gu("ida", .yes), gu("tom", .none)])
        inv("w8", "nina", .none); inv("w9", "mara", .maybe, [gu("lea", .maybe)]); inv("w1", "ines", .yes, [gu("sven", .yes)])
        g("w5") { $0.call = .meet("oet-mzpa-wdr"); $0.location = "St. Mary's Hall, 8 Church Square"; $0.repeatWeekday = 4 }
        g("e3") { $0.guests = [gu("me", .yes, org: true), gu("ines", .yes), gu("lea", .none)]; $0.call = .meet("ksd-pqra-mzx") }
        return evs
    }

    // MARK: Events

    static func event(_ s: Seed) -> CalendarEvent {
        let day = math.addDays(weekStart, s.day)
        let start = s.allDay ? day : math.date(on: day, minutes: s.start)
        let end = s.allDay ? math.addDays(day, s.span) : math.date(on: day, minutes: s.end)
        let call: String = switch s.call {
        case .meet(let code)?: "https://meet.google.com/\(code)"
        case .zoom(let url)?: "https://\(url)"
        case nil: ""
        }
        return CalendarEvent(id: "v4.\(s.id)", seriesID: s.repeatWeekday.map { _ in "v4.series.\(s.id)" }, calendarID: calendarIDs[s.cal]!, title: s.title,
                             start: start, end: end, isAllDay: s.allDay, status: status(s.myReply), location: s.location, notes: s.notes,
                             recurrence: s.repeatWeekday.map { Recurrence(frequency: .weekly, weekdays: [$0]) },
                             attendees: s.guests.map(attendee), conferencing: call, reminders: s.reminders,
                             availability: s.free ? .free : .busy, colorHex: s.color)
    }

    /// A guest as an `Attendee`: only the `me` key is Sam's own entry (Sam's other addresses are guests, as in the mockup).
    static func attendee(_ g: Guest) -> Attendee {
        let p = person(g.key)
        return Attendee(email: p.email, name: p.name, isOrganizer: g.organizer, isMe: g.key == "me", status: status(g.reply))
    }

    static func buildEvents() -> [CalendarEvent] {
        seeds().map(event).sorted { $0.start != $1.start ? $0.start < $1.start : $0.id < $1.id }
    }
}
