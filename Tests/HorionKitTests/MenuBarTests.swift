import Testing
import Foundation
@testable import HorionKit

@Suite("Menu bar menu")
struct MenuBarMenuTests {
    let fmt = Fmt(math: berlin)
    func ev(_ t: String, _ start: Date, mins: Int = 60, allDay: Bool = false, status: ResponseStatus = .confirmed,
            guests: [String] = [], video: String = "") -> CalendarEvent {
        CalendarEvent(id: t, calendarID: "c", title: t, start: start,
                      end: allDay ? berlin.addDays(start, 1) : start.addingTimeInterval(Double(mins) * 60),
                      isAllDay: allDay, status: status, participants: guests, conferencing: video)
    }
    func build(_ evs: [CalendarEvent], at h: Int, _ m: Int) -> MenuBarMenuModel {
        MenuBarMenu.build(events: evs, now: d(2026, 9, 29, h, m).addingTimeInterval(30), fmt: fmt) { _ in "#5C88E4" }
    }
    var day: [CalendarEvent] {
        [ev("Genetics", d(2026, 9, 29, 10, 10), mins: 100), ev("Calculus", d(2026, 9, 29, 12), mins: 100),
         ev("Sam / Alex", d(2026, 9, 29, 14), guests: ["Sam Okafor"], video: "meet.example.com/sam-alex"),
         ev("Evening journal", d(2026, 9, 29, 22, 45), mins: 15)]
    }

    @Test func twelveMinutesAhead() {
        let m = build(day, at: 11, 48)
        #expect(m.focus?.event.title == "Calculus" && m.focus?.running == false)
        #expect(m.focus?.text == "in 12 min" && m.focus?.soon == true)
        #expect(m.headLabel == "Up next" && m.itemTitle == "Calculus")
        #expect(m.head?.title == "Calculus" && m.head?.start == "12:00" && m.head?.end == "13:40")
        // The focus event is not repeated under Today.
        #expect(m.sections[0].rows.map(\.title) == ["Genetics", "Sam / Alex", "Evening journal"])
    }
    @Test func twoMinutesAhead() {
        let m = build(day, at: 11, 58)
        #expect(m.focus?.text == "in 2 min" && m.focus?.soon == true)
    }
    @Test func runningEventCountsDown() {
        let m = build(day, at: 12, 20)
        #expect(m.focus?.event.title == "Calculus" && m.focus?.running == true)
        #expect(m.focus?.text == "1 h 20 min left" && m.focus?.soon == true)
        #expect(m.headLabel == "Now")
        #expect(m.sections[0].rows.map(\.title) == ["Sam / Alex", "Evening journal"])
    }
    @Test func runningGivesWayInsideFifteenMinutes() {
        let m = build(day, at: 13, 50)
        #expect(m.focus?.event.title == "Sam / Alex" && m.focus?.text == "in 10 min")
    }
    @Test func farNextEvent() {
        let m = build(day, at: 21, 5)
        #expect(m.focus?.event.title == "Evening journal")
        #expect(m.focus?.text == "in 1 h 40 min" && m.focus?.soon == false)
    }
    @Test func nothingLeftToday() {
        let m = build(day + [ev("Half-year review", d(2026, 9, 30), allDay: true)], at: 23, 30)
        #expect(m.focus == nil && m.head == nil && m.itemTitle == nil)
        #expect(m.headLabel == "Nothing else today")
        #expect(m.sections.map(\.title) == ["Tomorrow"])
        #expect(m.sections[0].rows[0].start == "all-day" && m.sections[0].rows[0].end == nil)
    }
    @Test func longTitlesAreCut() {
        #expect(MenuBarMenu.cut("Plan the weekend trip with Jamie") == "Plan the weekend trip wit\u{2026}")
        #expect(MenuBarMenu.cut(String(repeating: "a", count: 26)) == String(repeating: "a", count: 26))
        #expect(MenuBarMenu.span(100) == "1 h 40 min" && MenuBarMenu.span(120) == "2 h" && MenuBarMenu.span(5) == "5 min")
    }
    @Test func threeDaySectionsAllDayFirstDeclinedLeftOut() {
        let evs = day + [
            ev("Meal prep", d(2026, 9, 30, 7, 30), mins: 15), ev("Half-year review", d(2026, 9, 30), allDay: true),
            ev("Climbing", d(2026, 9, 30, 16, 30), status: .declined),
            ev("Statistics", d(2026, 10, 1, 8)), ev("Too far", d(2026, 10, 2, 8)),
        ]
        let m = build(evs, at: 11, 48)
        #expect(m.sections.map(\.title) == ["Today", "Tomorrow", "Thu 1 Oct"])
        #expect(m.sections[1].rows.map(\.title) == ["Half-year review", "Meal prep"])
        #expect(m.sections[2].rows.map(\.title) == ["Statistics"])
    }
    @Test func hintSaysWhatTheRowMenuHas() {
        let m = build(day + [ev("Call", d(2026, 9, 29, 16), video: "https://meet.example.com/x"), ev("Party", d(2026, 9, 29, 17), guests: ["A", "B"])], at: 11, 48)
        let hints = Dictionary(uniqueKeysWithValues: m.rows.map { ($0.title, $0.hint) })
        #expect(hints == ["Calculus": nil, "Genetics": nil, "Sam / Alex": .call, "Call": .call, "Party": nil, "Evening journal": nil])
        // The icon after the title says what the menu has: a call, or guests to answer.
        #expect(m.rows.first { $0.title == "Sam / Alex" }?.hint == .call && m.rows.first { $0.title == "Genetics" }?.hint == nil)
    }
    @Test func rowMenuOffersOnlyWhatApplies() {
        let sam = day[2]
        let full = MenuBarMenu.submenu(for: sam, canRespond: true, guestAddresses: ["sam@example.com"])
        #expect(full.map(\.title) == ["Join call", "", "Going?", "Yes", "No", "Maybe", "", "Email Sam Okafor", "", "Copy details", "Show in Horion"])
        #expect(full.first == .join(URL(string: "https://meet.example.com/sam-alex")!))
        #expect(full.contains(.respond(.confirmed, checked: true)))
        if case .email(_, let url) = full[7] { #expect(url.absoluteString == "mailto:sam@example.com?subject=Sam%20/%20Alex") } else { Issue.record("no email") }
        // A store that cannot change the answer gets no Yes / No / Maybe.
        #expect(MenuBarMenu.submenu(for: sam, canRespond: false, guestAddresses: ["sam@example.com"]).map(\.title) == ["Join call", "", "Email Sam Okafor", "", "Copy details", "Show in Horion"])
        let call = ev("Call", d(2026, 9, 29, 16), video: "meet.example.com/x")
        #expect(MenuBarMenu.submenu(for: call, canRespond: true, guestAddresses: []).map(\.title) == ["Join call", "", "Copy details", "Show in Horion"])
        let party = ev("Party", d(2026, 9, 29, 17), guests: ["A <a@x.org>", "B"])
        #expect(MenuBarMenu.submenu(for: party, canRespond: false, guestAddresses: ["a@x.org"]).map(\.title) == ["Email 2 guests", "", "Copy details", "Show in Horion"])
        #expect(MenuBarMenu.guestAddress("A <a@x.org>") == "a@x.org" && MenuBarMenu.guestAddress("B") == nil && MenuBarMenu.guestName("A <a@x.org>") == "A")
    }

    @Test func sameEventInTwoCalendarsIsOneRow() {
        var a = ev("Father & son", d(2026, 9, 29, 20, 10), mins: 80), b = a
        b.id = "copy"; b.calendarID = "family"
        let m = MenuBarMenu.build(events: [a, b], now: d(2026, 9, 29, 9, 0), fmt: fmt) { $0.calendarID == "c" ? "#3D8BFD" : "#FF5F57" }
        #expect(m.rows.count == 1)
        #expect(m.rows[0].colorHex == "#3D8BFD" && m.rows[0].secondColorHex == "#FF5F57")
    }
    @Test func noEndTimeForAnEventWithoutLength() {
        let m = build([ev("Vitamin D", d(2026, 9, 29, 18), mins: 0), ev("Gym", d(2026, 9, 29, 19))], at: 9, 0)
        #expect(m.rows.first { $0.title == "Vitamin D" }?.end == nil)
        #expect(m.rows.first { $0.title == "Gym" }?.end == "20:00")
    }
}

@Suite("Menu bar layout")
struct MenuBarLayoutTests {
    let fmt = Fmt(math: berlin)
    func ev(_ t: String, _ start: Date) -> CalendarEvent {
        CalendarEvent(id: t + "\(start.timeIntervalSince1970)", calendarID: "c", title: t, start: start, end: start.addingTimeInterval(1800),
                      isAllDay: false, status: .confirmed)
    }
    /// `n` events a day from 13:00 on, for today, tomorrow and the day after.
    func menu(today: Int, tomorrow: Int, after: Int) -> MenuBarMenuModel {
        var evs: [CalendarEvent] = []
        for (k, n) in [today, tomorrow, after].enumerated() {
            for i in 0..<n { evs.append(ev("E\(k)-\(i)", berlin.addDays(d(2026, 9, 29, 13), k).addingTimeInterval(Double(i) * 1800))) }
        }
        return MenuBarMenu.build(events: evs, now: d(2026, 9, 29, 9, 0), fmt: fmt) { _ in "#5C88E4" }
    }
    func rows(_ l: [MenuBarLine]) -> [String] { l.compactMap { if case .row(let r) = $0 { r.title } else { nil } } }
    func folds(_ l: [MenuBarLine]) -> [String] { l.compactMap { if case .fold(let t, let d, _) = $0 { t + (d.map { " | " + $0 } ?? "") } else { nil } } }

    @Test func todayAndTomorrowInFullWhenTheyFit() {
        let l = MenuBarMenu.lines(menu(today: 3, tomorrow: 4, after: 5), maxHeight: 450)
        #expect(rows(l).count == 1 + 2 + 4)          // the focus row, the rest of today, all of tomorrow
        #expect(folds(l) == ["Thu 1 Oct | 5 events"])
    }
    @Test func moreOnlyPastHalfTheScreen() {
        let m = menu(today: 4, tomorrow: 14, after: 13)
        let l = MenuBarMenu.lines(m, maxHeight: 450)
        let height = l.reduce(MenuBarMenu.menuPadding + MenuBarMenu.footHeight) { $0 + ($1 == .separator ? MenuBarMenu.separatorHeight : MenuBarMenu.rowHeight) }
        #expect(height <= 450)
        let shown = rows(l).count - 1
        #expect(folds(l) == ["\(4 - 1 + 14 - shown) more tomorrow", "Thu 1 Oct | 13 events"])
        // The fold lists exactly what was left out, in order.
        if case .fold(_, _, let s) = l.first(where: { if case .fold = $0 { true } else { false } }) {
            #expect(s.flatMap(\.rows).map(\.title) == Array(m.sections[1].rows.map(\.title).suffix(s.flatMap(\.rows).count)))
        }
        // A tall screen shows everything.
        #expect(folds(MenuBarMenu.lines(m, maxHeight: 1400)) == ["Thu 1 Oct | 13 events"])
    }
}
