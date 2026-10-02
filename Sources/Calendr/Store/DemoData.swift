import Foundation
import CalendrKit

/// Fictional seed data (Alex Rivera, a design student with a freelance studio and a part-time job at Northwind). The week of Mon Sep 28 -
/// Sun Oct 4 2026 is the showcase week and matches the v3 mockup fixture (design/mockup-v3/data.js); other weeks
/// get the same recurring rhythm plus deterministic one-off appointments so month view and search have content.
/// The Tasks calendar is an ordinary calendar: its entries are plain events with their titles as they arrive ("[P1] ...").
enum DemoData {
    static let math = CalendarMath(timeZone: TimeZone(identifier: "Europe/Berlin")!)
    static let refWeekStart = math.date(year: 2026, month: 9, day: 28)
    static let refWeekEnd = math.date(year: 2026, month: 10, day: 5)
    static let generateFrom = math.date(year: 2026, month: 6, day: 29)
    static let generateTo = math.date(year: 2027, month: 4, day: 5)

    // MARK: Accounts

    static let acc1 = "acc.personal", acc2 = "acc.services", acc3 = "acc.work"
    static let personal = "cal.personal", family = "cal.family", tasks = "cal.tasks", study = "cal.study"
    static let feiertage = "cal.feiertage", holidays = "cal.holidays", ferien = "cal.ferien"
    static let services = "cal.services", svcFeiertage = "cal.svc.feiertage", svcHolidays = "cal.svc.holidays", svcItaly = "cal.svc.italy"
    static let work = "cal.work", workHolidays = "cal.work.holidays"

    static let accounts: [CalendarAccount] = [
        CalendarAccount(id: acc1, name: "alex.rivera@mail.example.com", calendars: [
            CalendarInfo(id: personal, accountID: acc1, title: "Personal", colorHex: "#6F97F0", isDefault: true),
            CalendarInfo(id: family, accountID: acc1, title: "Family", colorHex: "#EF8452"),
            CalendarInfo(id: tasks, accountID: acc1, title: "Tasks", colorHex: "#B9B6C9"),
            CalendarInfo(id: study, accountID: acc1, title: "Study Group", colorHex: "#E3B341"),
            CalendarInfo(id: feiertage, accountID: acc1, title: "Feiertage in Deutschland", colorHex: "#DD6FAE", icon: .feed, isWritable: false),
            CalendarInfo(id: holidays, accountID: acc1, title: "Holidays in Germany", colorHex: "#6CC48A", icon: .feed, isWritable: false),
            CalendarInfo(id: ferien, accountID: acc1, title: "Ferien Berlin", colorHex: "#6CC48A", icon: .feed, isWritable: false),
        ]),
        CalendarAccount(id: acc2, name: "alex.rivera.studio@mail.example.com", calendars: [
            CalendarInfo(id: services, accountID: acc2, title: "Studio", colorHex: "#69A9DD"),
            CalendarInfo(id: svcFeiertage, accountID: acc2, title: "Feiertage in Deutschland", colorHex: "#6CC48A", icon: .feed, isVisibleByDefault: false, isWritable: false),
            CalendarInfo(id: svcHolidays, accountID: acc2, title: "Holidays in Germany", colorHex: "#6CC48A", icon: .feed, isVisibleByDefault: false, isWritable: false),
            CalendarInfo(id: svcItaly, accountID: acc2, title: "Holidays in Italy", colorHex: "#6CC48A", icon: .feed, isVisibleByDefault: false, isWritable: false),
        ]),
        CalendarAccount(id: acc3, name: "alex.rivera@northwind.example.com", calendars: [
            CalendarInfo(id: work, accountID: acc3, title: "Northwind", colorHex: "#C58AF9"),
            CalendarInfo(id: workHolidays, accountID: acc3, title: "Holidays in Germany", colorHex: "#6CC48A", icon: .feed, isVisibleByDefault: false, isWritable: false),
        ]),
    ]

    static let teammates: [Teammate] = [
        Teammate(name: "Mateo Alvarez", email: "mateo.alvarez@northwind.example.com"),
        Teammate(name: "Maya Sterling", email: "maya.sterling@northwind.example.com"),
        Teammate(name: "Tina Tester", email: "tina.tester@northwind.example.com"),
        Teammate(name: "Lucas Marlowe", email: "lucas.marlowe@northwind.example.com"),
        Teammate(name: "Tom Fielding", email: "tom.fielding@northwind.example.com"),
        Teammate(name: "Chair Office", email: "chair.office@northwind.example.com"),
        Teammate(name: "IT Department", email: "it@northwind.example.com"),
        Teammate(name: "Social Media Team", email: "social@northwind.example.com"),
    ]

    // MARK: Helpers

    static func at(_ base: Date, _ hhmm: String) -> Date {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        return math.date(on: base, minutes: p[0] * 60 + p[1])
    }
    static func day(_ m: Int, _ d: Int, year: Int = 2026) -> Date { math.date(year: year, month: m, day: d) }

    struct Series {
        var title: String
        var calendar: String
        var weekdays: [Int]              // Calendar weekday numbers, Sunday = 1
        var start: String, end: String
        var location = "", notes = ""
        var participants: [String] = []
        var conferencing = ""
        var colorHex: String?
        var until: Date?
        var skipHolidays = false
        var reminder: Int? = nil
    }

    static let schoolUntil = day(7, 9, year: 2027)
    static let policyNotes = "Bring laptop. Seminar room on the 2nd floor."
    static let studyLocation = "Halden College, North Campus,\n12 Example Street, 10115 Berlin"

    static func school(_ t: String, _ wd: [Int], _ s: String, _ e: String) -> Series {
        Series(title: t, calendar: personal, weekdays: wd, start: s, end: e, location: studyLocation, notes: t == "Public Policy" ? policyNotes : "", until: schoolUntil, skipHolidays: true, reminder: 1)
    }

    // Calendar weekdays: Sun=1 Mon=2 Tue=3 Wed=4 Thu=5 Fri=6 Sat=7
    static var series: [Series] {
        let all = [2, 3, 4, 5, 6, 7, 1]
        return [
            school("Statistics", [2, 5], "08:00", "09:45"),
            school("Data Structures", [3, 6], "08:00", "09:45"),
            school("Chemistry Lab", [2], "14:35", "16:10"),
            school("Genetics", [3], "10:10", "11:50"),
            school("Studio Art", [2, 5], "16:15", "17:50"),
            school("Calculus", [3], "12:00", "13:40"),
            school("Calculus", [5], "10:10", "11:50"),
            school("Public Policy", [3], "16:15", "17:50"),
            school("Public Policy", [4], "10:10", "11:50"),
            school("Composition", [4], "12:55", "14:30"),
            school("Composition", [5], "14:35", "16:10"),
            school("World History", [4, 6], "14:35", "16:10"),
            school("Statistics", [6], "12:00", "13:40"),
            Series(title: "Sam / Alex", calendar: personal, weekdays: [3], start: "14:00", end: "15:00", participants: ["Sam Okafor"], conferencing: "meet.example.com/sam-alex"),
            Series(title: "Piano lesson", calendar: personal, weekdays: [5], start: "13:00", end: "14:00"),
            Series(title: "Call with Jamie", calendar: personal, weekdays: [2, 3, 5, 6, 7, 1], start: "22:00", end: "22:30"),
            Series(title: "Meal prep", calendar: tasks, weekdays: [2, 3, 4, 5, 6], start: "07:30", end: "07:45"),
            Series(title: "Gym bag", calendar: tasks, weekdays: [3, 4, 6], start: "07:45", end: "08:00"),
            Series(title: "[P1] Water the plants", calendar: tasks, weekdays: all, start: "18:00", end: "18:15"),
            Series(title: "Evening journal", calendar: tasks, weekdays: all, start: "22:45", end: "23:00"),
        ]
    }

    static let holidayList: [(Date, Date?, String, String, [String])] = [   // start, endInclusive, title, calendar, extra
        (day(10, 3), nil, "Tag der Deutschen Einheit", feiertage, []),
        (day(10, 3), nil, "Day of German Unity", holidays, []),
        (day(10, 31), nil, "Reformationstag", feiertage, []),
        (day(12, 24), nil, "Heiligabend", feiertage, []),
        (day(12, 25), nil, "1. Weihnachtstag", feiertage, []),
        (day(12, 25), nil, "Christmas Day", holidays, []),
        (day(12, 26), nil, "2. Weihnachtstag", feiertage, []),
        (day(12, 26), nil, "Second Day of Christmas", holidays, []),
        (day(12, 31), nil, "Silvester", feiertage, []),
        (day(1, 1, year: 2027), nil, "Neujahr", feiertage, []),
        (day(1, 1, year: 2027), nil, "New Year's Day", holidays, []),
        (day(3, 8, year: 2027), nil, "Internationaler Frauentag", feiertage, []),
        (day(3, 26, year: 2027), nil, "Karfreitag", feiertage, []),
        (day(3, 28, year: 2027), nil, "Ostersonntag", feiertage, []),
        (day(7, 24), day(9, 5), "Sommerferien", ferien, []),
        (day(10, 19), day(10, 31), "Herbstferien", ferien, []),
        (day(12, 23), day(1, 2, year: 2027), "Weihnachtsferien", ferien, []),
        (day(2, 1, year: 2027), day(2, 6, year: 2027), "Winterferien", ferien, []),
    ]

    static func isSchoolBreak(_ d: Date) -> Bool {
        for (s, e, _, cal, _) in holidayList where cal == ferien || cal == feiertage {
            let end = e ?? s
            if d >= s && d <= end { return true }
        }
        return false
    }

    // MARK: Build

    static func buildEvents(dense: Bool = false) -> [CalendarEvent] {
        var out: [CalendarEvent] = []
        out.append(contentsOf: recurring())
        out.append(contentsOf: referenceWeekOneOffs())
        out.append(contentsOf: filler())
        out.append(contentsOf: holidayEvents())
        out.append(contentsOf: otherAccountEvents())
        if dense { out.append(contentsOf: denseEvents()) }
        return out.sorted { $0.start != $1.start ? $0.start < $1.start : $0.id < $1.id }
    }

    static func recurring() -> [CalendarEvent] {
        var out: [CalendarEvent] = []
        for (idx, s) in series.enumerated() {
            let sid = "series.\(idx)"
            let rule = Recurrence(frequency: .weekly, weekdays: s.weekdays.count == 7 ? [] : s.weekdays, until: s.until)
            var d = generateFrom
            while d < generateTo {
                defer { d = math.addDays(d, 1) }
                guard s.weekdays.contains(math.calendar.component(.weekday, from: d)) else { continue }
                if s.skipHolidays && isSchoolBreak(d) { continue }
                if let u = s.until, d > u { continue }
                var r = rule
                if s.weekdays.count == 7 { r = Recurrence(frequency: .daily, until: s.until) }
                out.append(CalendarEvent(id: "\(sid)@\(Int(d.timeIntervalSince1970))", seriesID: sid, calendarID: s.calendar, title: s.title,
                                         start: at(d, s.start), end: at(d, s.end), location: s.location, notes: s.notes,
                                         recurrence: r, participants: s.participants, conferencing: s.conferencing, reminderMinutes: s.reminder, colorHex: s.colorHex))
            }
        }
        return out
    }

    static func ev(_ id: String, _ cal: String, _ title: String, _ d: Date, _ s: String, _ e: String, status: ResponseStatus = .confirmed,
                   location: String = "", notes: String = "", guests: [String] = [], video: String = "") -> CalendarEvent {
        CalendarEvent(id: "ref.\(id)", calendarID: cal, title: title, start: at(d, s), end: at(d, e), status: status,
                      location: location, notes: notes, participants: guests, conferencing: video, reminderMinutes: 1)
    }
    static func allDay(_ id: String, _ cal: String, _ title: String, _ from: Date, days: Int = 1, status: ResponseStatus = .confirmed, notes: String = "") -> CalendarEvent {
        CalendarEvent(id: "ref.\(id)", calendarID: cal, title: title, start: from, end: math.addDays(from, days), isAllDay: true, status: status, notes: notes)
    }

    /// The showcase week, as in design/mockup-v3/data.js.
    static func referenceWeekOneOffs() -> [CalendarEvent] {
        let mon = refWeekStart, tue = day(9, 29), wed = day(9, 30), thu = day(10, 1), fri = day(10, 2), sat = day(10, 3), sun = day(10, 4)
        return [
            allDay("domain", tasks, "[P1] Renew domain", mon),
            ev("landlord", tasks, "[P2] Call the landlord about heating", mon, "09:00", "09:15"),
            ev("car-service", tasks, "[P3] Book the car service", mon, "10:00", "10:15"),
            ev("dinner-dad", family, "Dinner with Dad", mon, "18:00", "19:00", location: "Trattoria Example, Kreuzberg"),
            ev("roadmap", tasks, "[P1] Ask Sam: confirm roadmap slot", mon, "20:00", "20:15"),
            ev("hold", personal, "Hold: workshop", mon, "21:00", "22:00", status: .tentative),

            ev("haircut", tasks, "[P1] Book a haircut", tue, "16:00", "16:15"),
            ev("weekend-trip", tasks, "[P1] Plan the weekend trip with Jamie", tue, "20:00", "20:15"),

            allDay("half-year", personal, "Half-year review", wed),
            ev("half-year-notes", personal, "Send half-year notes", wed, "07:30", "08:00"),
            ev("climbing", personal, "Climbing", wed, "16:30", "18:30", status: .declined, location: "Climbing Hall Example"),
            ev("family-dinner", family, "Family dinner", wed, "16:30", "18:30", location: "Zuhause", guests: ["Dad", "Riley Rivera"]),
            ev("game-night", personal, "Board game night", wed, "19:00", "22:30", guests: ["Jamie Lin", "Sam Okafor", "Casey Moreau"]),

            ev("flat-cleaning", personal, "Flat cleaning", thu, "18:00", "19:00"),
            ev("grants", study, "How to grants", thu, "19:00", "19:30", status: .tentative, video: "meet.example.com/grants"),
            ev("ops", study, "Ops meeting", thu, "19:00", "20:00", guests: ["Maya Sterling", "Tom Fielding"], video: "meet.example.com/ops"),
            ev("thursday", study, "Thursday sync", thu, "20:00", "21:30", guests: ["Maya Sterling", "Lucas Marlowe", "Tina Tester"], video: "meet.example.com/thursday"),

            allDay("offsite", work, "Offsite (maybe, see description)", fri, days: 3, status: .tentative, notes: "Maybe. See the invite for the final dates."),
            allDay("sam-away", personal, "Sam away", fri, days: 3),
            allDay("saas", tasks, "[P3] Renew SaaS plan", fri),
            ev("taxform", tasks, "[P2] Fill in the tax form", fri, "16:00", "16:15"),

            allDay("a-casey", personal, "Casey's birthday", sat),
            ev("casey-wishes", tasks, "Congratulate Casey", sat, "09:00", "09:15"),
            ev("library", tasks, "[P3] Return the library book", sat, "18:30", "18:45"),

            ev("brunch", family, "Farmers market + brunch", sun, "09:45", "11:30", status: .tentative, location: "Markthalle Neun"),
            ev("dana", tasks, "[P1] Reply to Dana", sun, "09:30", "09:45"),
            ev("weekly-review", tasks, "[P0] Weekly review", sun, "17:15", "17:30"),
            ev("game-night-sun", family, "Flat game night", sun, "19:00", "20:00"),
        ]
    }

    /// Deterministic one-off appointments in every week except the reference week.
    static func filler() -> [CalendarEvent] {
        struct Item { var title: String; var cal: String; var start: String; var mins: Int; var location = "" }
        let items: [Item] = [
            Item(title: "Bike repair", cal: personal, start: "09:30", mins: 45, location: "Velo Werkstatt, Berlin"),
            Item(title: "Haircut", cal: personal, start: "15:00", mins: 60),
            Item(title: "Sprint Planning", cal: work, start: "10:00", mins: 90),
            Item(title: "Climbing", cal: personal, start: "19:30", mins: 120, location: "Climbing Hall Example"),
            Item(title: "Call with Sam", cal: personal, start: "17:00", mins: 30),
            Item(title: "Board meeting", cal: work, start: "18:30", mins: 120),
            Item(title: "Family dinner", cal: family, start: "18:00", mins: 150, location: "Zuhause"),
            Item(title: "Study session", cal: study, start: "19:00", mins: 120, location: "Halden College, Library"),
            Item(title: "Cinema with Jamie", cal: personal, start: "20:15", mins: 130, location: "Cinema Example"),
            Item(title: "Tax advisor", cal: services, start: "11:00", mins: 60),
            Item(title: "Running club", cal: personal, start: "07:00", mins: 60),
            Item(title: "Berlin Chapter Meetup", cal: work, start: "19:30", mins: 150),
        ]
        var out: [CalendarEvent] = []
        var seed: UInt64 = 42
        func rnd(_ n: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % UInt64(n)) }
        var week = generateFrom
        var i = 0
        while week < generateTo {
            defer { week = math.addDays(week, 7) }
            if math.startOfWeek(week) == refWeekStart { continue }
            for k in 0..<4 {
                let it = items[rnd(items.count)]
                let d = math.addDays(week, rnd(7))
                i += 1
                out.append(CalendarEvent(id: "fill.\(i)", calendarID: it.cal, title: it.title, start: at(d, it.start),
                                         end: at(d, it.start).addingTimeInterval(Double(it.mins) * 60), location: it.location, reminderMinutes: 10))
                _ = k
            }
            // A birthday or trip now and then.
            if rnd(3) == 0 {
                i += 1
                let d = math.addDays(week, rnd(7))
                out.append(CalendarEvent(id: "fill.\(i)", calendarID: personal, title: ["Birthday: Casey", "Birthday: Jordan", "Concert Tempodrom", "Flight to Rome", "Moving day"][rnd(5)],
                                         start: d, end: math.addDays(d, 1), isAllDay: true))
            }
        }
        return out
    }

    static func holidayEvents() -> [CalendarEvent] {
        var out: [CalendarEvent] = []
        for (i, h) in holidayList.enumerated() {
            if h.2 == "Tag der Deutschen Einheit" || h.2 == "Day of German Unity" { out.append(CalendarEvent(id: "ref.hol.\(h.3 == holidays ? "b" : "c")", calendarID: h.3, title: h.2, start: h.0, end: math.addDays(h.0, 1), isAllDay: true)); continue }
            let endEx = math.addDays(h.1 ?? h.0, 1)
            out.append(CalendarEvent(id: "hol.\(i)", calendarID: h.3, title: h.2, start: h.0, end: endEx, isAllDay: true))
        }
        return out
    }

    static func otherAccountEvents() -> [CalendarEvent] {
        // Events on the second/third account so their calendars are not empty (outside the reference week).
        var out: [CalendarEvent] = []
        var week = math.addDays(refWeekStart, 7)
        var i = 0
        while week < generateTo {
            defer { week = math.addDays(week, 14) }
            i += 1
            out.append(CalendarEvent(id: "svc.\(i)", calendarID: services, title: "Review invoices", start: at(math.addDays(week, 1), "14:00"), end: at(math.addDays(week, 1), "15:00")))
            out.append(CalendarEvent(id: "work.\(i)", calendarID: work, title: "Northwind Weekly", start: at(math.addDays(week, 2), "17:00"), end: at(math.addDays(week, 2), "18:00"),
                                     recurrence: Recurrence(frequency: .weekly, interval: 2), participants: ["mateo.alvarez@northwind.example.com"]))
        }
        return out
    }

    // MARK: Teammates

    static func teammateEvents() -> [CalendarEvent] {
        let titles = ["Standup", "1:1", "Planning", "Review", "Workshop", "Lunch", "Client call", "Design sync", "Retro", "Focus time"]
        var out: [CalendarEvent] = []
        for (ti, t) in teammates.enumerated() {
            var seed = UInt64(ti + 7) &* 2654435761
            func rnd(_ n: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % UInt64(n)) }
            var week = generateFrom
            var n = 0
            while week < generateTo {
                defer { week = math.addDays(week, 7) }
                for _ in 0..<(3 + rnd(3)) {
                    n += 1
                    let d = math.addDays(week, rnd(5))
                    let startMin = 8 * 60 + rnd(20) * 30
                    let dur = [30, 45, 60, 90][rnd(4)]
                    out.append(CalendarEvent(id: "tm.\(ti).\(n)", calendarID: "team:\(t.email)", title: titles[rnd(titles.count)],
                                             start: math.date(on: d, minutes: startMin), end: math.date(on: d, minutes: startMin + dur), ownerEmail: t.email))
                }
            }
        }
        return out.sorted { $0.start < $1.start }
    }

    // MARK: Dense data for --perf

    static func denseEvents() -> [CalendarEvent] {
        var out: [CalendarEvent] = []
        var seed: UInt64 = 99
        func rnd(_ n: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % UInt64(n)) }
        let cals = [personal, family, tasks, study, services, work]
        var week = math.addDays(math.startOfWeek(day(9, 28)), -60 * 7)
        for w in 0..<120 {
            for k in 0..<300 {
                let d = math.addDays(week, rnd(7))
                let start = rnd(23 * 4) * 15
                out.append(CalendarEvent(id: "dense.\(w).\(k)", calendarID: cals[rnd(cals.count)], title: "Dense event \(k)", start: math.date(on: d, minutes: start),
                                         end: math.date(on: d, minutes: start + [15, 30, 45, 60, 90, 120][rnd(6)])))
            }
            week = math.addDays(week, 7)
        }
        return out
    }
}
