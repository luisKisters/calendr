import Foundation
import HorionKit

/// The v11 fixture (`--fixture v11`, and every `v11-*` snapshot state): the neutral demo week of design/mockup-v11 (`?demo=1`,
/// data.js "public demo data"), so the app and the locked mockup show the same week for a pixel compare. Mon 2 - Sun 8 Nov 2026,
/// "now" Wed 4 Nov 18:15, 44 pt per hour. Invented names only; every address is example.com, and locations are invented too.
enum DemoDataV11 {
    static let math = DemoDataV4.math
    static let weekStart = math.date(year: 2026, month: 11, day: 2)
    static let now = math.date(year: 2026, month: 11, day: 4, hour: 18, minute: 15)
    static let hourHeight = 44.0
    /// Mockup `fs=1` at 1440 × 900: the grid is scrolled 288 pt (06:32 at the top), plus the app's 10 pt pad above 00:00.
    static let scroll = 288.0 + GridGeometry.pad

    // MARK: Calendars (data.js CALS0 hexes, demo names)

    static let google = "v11.google", icloud = "v11.icloud", subs = "v11.subs", bday = "v11.bday"
    /// Mockup calendar keys to (id, account, name, hex, read-only).
    static let cals: [(key: String, acct: String, name: String, hex: String, ro: Bool)] = [
        ("personal", google, "Personal", "#5B8DEF", false), ("work", google, "Work", "#8F86E8", false), ("product", google, "Horion", "#A9A6F5", false),
        ("family", google, "Family", "#E5674F", false), ("holidays", google, "Holidays", "#9254DE", true),
        ("holidaysDE", google, "Holidays in Germany", "#3FA36B", true), ("sport", google, "Sport", "#F2884B", false),
        ("tasks", google, "Tasks", "#B9B9B9", false), ("team", google, "Team", "#E9B949", false),
        ("ipersonal", icloud, "Personal", "#3A8EF0", false), ("uni", icloud, "Uni", "#C04BD8", false),
        ("public", subs, "Public holidays", "#D9822B", true), ("birthdays", bday, "Birthdays", "#8E9AAF", true),
    ]
    static func cal(_ key: String) -> String { "v11.\(key)" }

    static let accounts: [CalendarAccount] = [(google, "Google"), (icloud, "iCloud"), (subs, "Subscribed calendars"), (bday, "Birthdays")].map { a in
        CalendarAccount(id: a.0, name: a.1, calendars: cals.filter { $0.acct == a.0 }.map {
            CalendarInfo(id: cal($0.key), accountID: a.0, title: $0.name, colorHex: $0.hex, isDefault: $0.key == "personal", isWritable: !$0.ro)
        })
    }

    // MARK: People (the demo names)

    static let people: [String: (name: String, email: String)] = [
        "me": ("You", "you@example.com"), "sam": ("Sam Lee", "sam@example.com"), "jordan": ("Jordan Park", "jordan@example.com"),
        "alex": ("Alex Kim", "alex@example.com"), "noah": ("Noah Fischer", "noah@example.com"), "tom": ("Tom Weber", "tom@example.com"),
        "nina": ("Nina Brooks", "nina@example.com"), "omar": ("Omar Haddad", "omar@example.com"), "ivy": ("Ivy Chen", "ivy@example.com"),
        "ben": ("Ben Novak", "ben@example.com"),
    ]
    static let teammates: [Teammate] = people.filter { $0.key != "me" }.sorted { $0.key < $1.key }.map { Teammate(name: $0.value.name, email: $0.value.email) }

    typealias Reply = DemoDataV4.Reply
    struct Guest { var key: String; var reply: Reply; var organizer = false }

    struct Seed {
        var day: Int                       // 0 = Mon 2 Nov
        var start = 0, end = 0
        var title: String
        var cal: String
        var allDay = false
        var lastDay: Int?                  // all-day: the last day, inclusive
        var organizer = true
        var guests: [Guest] = []
        var call = ""
        var location = ""
        var series: String?
    }

    static func m(_ t: String) -> Int { DemoDataV4.m(t) }

    /// data.js `seedEvents` under `DEMO`, in its order.
    static func seeds() -> [Seed] {
        var out: [Seed] = []
        func timed(_ d: Int, _ s: String, _ e: String, _ t: String, _ c: String, _ f: (inout Seed) -> Void = { _ in }) {
            var x = Seed(day: d, start: m(s), end: m(e), title: t, cal: c); f(&x); out.append(x)
        }
        func task(_ d: Int, _ s: String, _ t: String) { out.append(Seed(day: d, start: m(s), end: m(s), title: t, cal: "tasks")) }
        func allday(_ d: Int, _ ed: Int, _ t: String, _ c: String) { out.append(Seed(day: d, title: t, cal: c, allDay: true, lastDay: ed)) }
        func g(_ k: String, _ r: Reply = .yes, _ org: Bool = false) -> Guest { Guest(key: k, reply: r, organizer: org) }
        func me(_ r: Reply = .yes, _ org: Bool = false) -> Guest { Guest(key: "me", reply: r, organizer: org) }
        let from = math.daysBetween(weekStart, math.date(year: 2026, month: 9, day: 1))
        let to = math.daysBetween(weekStart, math.date(year: 2026, month: 12, day: 31))
        for d in from...to {
            let w = ((d % 7) + 7) % 7                                    // 0 = Monday
            if w < 5 { timed(d, "09:30", "09:45", "Standup", "team") { $0.organizer = false; $0.series = "standup"; $0.call = "https://meet.google.com/abc-defg-hij"; $0.guests = [g("nina", .yes, true), me(), g("ben")] } }
            if w == 0 || w == 2 { timed(d, "07:30", "08:30", "Gym", "sport") { $0.series = "gym" } }
            if w == 1 || w == 3 { timed(d, "10:00", "12:00", "Deep work", "product") { $0.series = "deep" } }
            if w == 3 { timed(d, "20:00", "21:00", "Founder circle", "team") { $0.organizer = false; $0.series = "circle"; $0.call = "https://zoom.us/j/123456789"; $0.guests = [g("omar", .yes, true), me(), g("ivy", .maybe)] } }
            timed(d, "22:30", "23:00", "Read", "personal") { $0.series = "read" }
        }
        // Mon
        allday(0, 0, "Ship v1.2 beta", "tasks")
        timed(0, "11:00", "12:30", "Customer interviews", "work") { $0.guests = [me(.yes, true), g("jordan")] }
        timed(0, "14:00", "15:30", "Pricing page copy", "product")
        timed(0, "17:00", "18:30", "Investor update", "work") { $0.organizer = false; $0.call = "https://teams.microsoft.com/l/meetup-join/demo"; $0.guests = [g("jordan", .yes, true), me()] }
        timed(0, "19:30", "21:00", "Dinner with Sam", "personal") { $0.location = "Corner Café, 12 Example Street"; $0.guests = [me(.yes, true), g("sam")] }
        // Tue
        task(1, "08:30", "Reply to support emails")
        timed(1, "13:00", "14:00", "Lunch with Maya", "personal") { $0.location = "Market Hall, 42 Example Road" }
        timed(1, "14:30", "16:00", "Onboarding review", "product") { $0.guests = [me(.yes, true), g("noah")] }
        timed(1, "18:00", "19:00", "Run", "sport")
        timed(1, "20:00", "21:30", "Movie night", "personal")
        // Wed (today)
        allday(2, 2, "Alex's birthday", "birthdays")
        allday(2, 2, "Release day", "product")
        task(2, "09:00", "Text Alex happy birthday")
        timed(2, "11:00", "12:00", "1:1 with Jordan", "work") { $0.guests = [me(.yes, true), g("jordan")] }
        timed(2, "13:00", "14:30", "Build: search v2", "product")
        timed(2, "16:30", "18:45", "Design review", "product") { $0.call = "https://meet.google.com/kvh-ngsu-bdj"; $0.guests = [me(.yes, true), g("sam"), g("alex", .none)] }
        timed(2, "17:00", "18:00", "Hiring sync", "team") { $0.organizer = false; $0.guests = [g("ben", .yes, true), me(.none)]; $0.call = "https://meet.google.com/qre-hjxa-pkt" }
        timed(2, "19:15", "20:30", "Climbing", "sport")
        timed(2, "20:30", "21:00", "Podcast", "personal")
        // Thu
        allday(3, 3, "Launch prep", "product")
        timed(3, "13:00", "14:00", "Dentist", "ipersonal")
        timed(3, "15:00", "16:30", "Partner call", "work") { $0.organizer = false; $0.guests = [g("tom", .yes, true), me()]; $0.call = "https://zoom.us/j/987654321" }
        timed(3, "18:00", "19:00", "Weekly review", "personal")
        timed(3, "18:30", "20:00", "Neighbourhood meetup", "family") { $0.organizer = false; $0.guests = [g("nina", .yes, true), me(.no)] }
        // Fri
        allday(4, 6, "Lea visiting", "personal")
        allday(4, 4, "Ship day", "product")
        timed(4, "14:00", "16:00", "Bug bash", "product") { $0.location = "Office, Room 3"; $0.guests = [me(.yes, true), g("noah"), g("ben")] }
        timed(4, "17:30", "19:30", "Demo prep", "work") { $0.location = "Office, Room 1" }
        timed(4, "20:30", "23:00", "Drinks with the team", "personal") { $0.guests = [me(.yes, true), g("alex")] }
        // Sat
        timed(5, "08:15", "10:00", "maybe: founders breakfast", "personal") { $0.organizer = false; $0.guests = [g("omar", .yes, true), me(.maybe)] }
        timed(5, "10:00", "18:00", "Founders Conference", "personal") { $0.location = "Conference Hall, 80 Example Avenue" }
        // Sun
        timed(6, "10:00", "11:30", "Long walk", "personal") { $0.location = "City Park" }
        timed(6, "13:00", "16:00", "Write blog post", "product")
        timed(6, "19:00", "20:00", "Plan the week", "personal")
        return out
    }

    static func buildEvents() -> [CalendarEvent] {
        seeds().enumerated().map { i, s in
            let day = math.addDays(weekStart, s.day)
            let start = s.allDay ? day : math.date(on: day, minutes: s.start)
            let end = s.allDay ? math.addDays(day, (s.lastDay ?? s.day) - s.day + 1) : math.date(on: day, minutes: s.end)
            // Mockup `myResp`: the organizer (and an event without guests) counts as accepted.
            let mine = s.guests.first { $0.key == "me" }?.reply ?? .yes
            let status = s.organizer ? .confirmed : DemoDataV4.status(mine)
            let att = s.guests.map { g in
                Attendee(email: people[g.key]!.email, name: people[g.key]!.name, isOrganizer: g.organizer, isMe: g.key == "me", status: DemoDataV4.status(g.reply))
            }
            return CalendarEvent(id: "v11.e\(i)", seriesID: s.series.map { "v11.series.\($0)" }, calendarID: cal(s.cal), title: s.title, start: start, end: end,
                                 isAllDay: s.allDay, status: status, location: s.location, attendees: att, conferencing: s.call,
                                 reminders: s.allDay ? [] : [10], availability: s.allDay ? .free : .busy)
        }.sorted { $0.start != $1.start ? $0.start < $1.start : $0.id < $1.id }
    }
}
