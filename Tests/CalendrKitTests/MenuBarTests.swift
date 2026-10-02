import Testing
import Foundation
@testable import CalendrKit

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
        // The focus event is not repeated under Today; the running one says how long it has left.
        #expect(m.sections[0].rows.map(\.title) == ["Genetics", "Sam / Alex", "Evening journal"])
        #expect(m.sections[0].rows[0].left == "2 min left")
    }
    @Test func twoMinutesAhead() {
        let m = build(day, at: 11, 58)
        #expect(m.focus?.text == "in 2 min" && m.focus?.soon == true)
    }
    @Test func runningEventCountsDown() {
        let m = build(day, at: 12, 20)
        #expect(m.focus?.event.title == "Calculus" && m.focus?.running == true)
        #expect(m.focus?.text == "1 h 20 min left" && m.focus?.soon == true)
        #expect(m.headLabel == "Now" && m.head?.left == "1 h 20 min left")
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
    @Test func onlyCallsAndGuestsGetARowMenu() {
        let m = build(day + [ev("Call", d(2026, 9, 29, 16), video: "https://meet.example.com/x"), ev("Party", d(2026, 9, 29, 17), guests: ["A", "B"])], at: 11, 48)
        let menus = Dictionary(uniqueKeysWithValues: m.rows.map { ($0.title, $0.hasSubmenu) })
        #expect(menus == ["Calculus": false, "Genetics": false, "Sam / Alex": true, "Call": true, "Party": false, "Evening journal": false])
    }
    @Test func rowMenuOffersOnlyWhatApplies() {
        let sam = day[2]
        let full = MenuBarMenu.submenu(for: sam, canRespond: true, guestAddresses: ["sam@example.com"])
        #expect(full.map(\.title) == ["Join call", "", "Going?", "Yes", "No", "Maybe", "", "Email Sam Okafor", "", "Show in Calendr"])
        #expect(full.first == .join(URL(string: "https://meet.example.com/sam-alex")!))
        #expect(full.contains(.respond(.confirmed, checked: true)))
        if case .email(_, let url) = full[7] { #expect(url.absoluteString == "mailto:sam@example.com?subject=Sam%20/%20Alex") } else { Issue.record("no email") }
        // A store that cannot change the answer gets no Yes / No / Maybe.
        #expect(MenuBarMenu.submenu(for: sam, canRespond: false, guestAddresses: ["sam@example.com"]).map(\.title) == ["Join call", "", "Email Sam Okafor", "", "Show in Calendr"])
        let call = ev("Call", d(2026, 9, 29, 16), video: "meet.example.com/x")
        #expect(MenuBarMenu.submenu(for: call, canRespond: true, guestAddresses: []).map(\.title) == ["Join call", "", "Show in Calendr"])
        let party = ev("Party", d(2026, 9, 29, 17), guests: ["A <a@x.org>", "B"])
        #expect(MenuBarMenu.submenu(for: party, canRespond: false, guestAddresses: ["a@x.org"]).map(\.title) == ["Email 2 guests", "", "Show in Calendr"])
        #expect(MenuBarMenu.guestAddress("A <a@x.org>") == "a@x.org" && MenuBarMenu.guestAddress("B") == nil && MenuBarMenu.guestName("A <a@x.org>") == "A")
    }
}
