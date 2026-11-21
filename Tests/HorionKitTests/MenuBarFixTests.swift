import Testing
import Foundation
@testable import HorionKit

@Suite("Menu bar menu fixes")
struct MenuBarFixTests {
    let fmt = Fmt(math: berlin)
    func ev(_ t: String, _ start: Date, mins: Int = 60, guests: [String] = [], video: String = "") -> CalendarEvent {
        CalendarEvent(id: t, calendarID: "c", title: t, start: start, end: start.addingTimeInterval(Double(mins) * 60),
                      isAllDay: false, status: .confirmed, participants: guests, conferencing: video)
    }
    func build(_ evs: [CalendarEvent], at h: Int, _ m: Int, canRespond: Bool = false) -> MenuBarMenuModel {
        MenuBarMenu.build(events: evs, now: d(2026, 9, 29, h, m), fmt: fmt, canRespond: canRespond) { _ in "#5C88E4" }
    }

    @Test func copiedDetailsReadWell() {
        var e = ev("Design review", d(2026, 9, 29, 10), mins: 90, guests: ["Sam Okafor <sam@example.com>", "Mia Chen"],
                   video: "https://meet.google.com/abc-defg-hij")
        e.location = "Room 2.14"
        e.notes = "  Bring the printouts.\n"
        #expect(MenuBarMenu.details(e, fmt: fmt) == """
            Design review
            Tue 29 Sep \u{00B7} 10:00\u{2013}11:30
            Room 2.14
            Call: https://meet.google.com/abc-defg-hij
            Guests: Sam Okafor, Mia Chen

            Bring the printouts.
            """)
        // Nothing for empty parts; all-day spans name their last day; a plain link is a Link.
        let trip = CalendarEvent(id: "t", calendarID: "c", title: "Trip", start: d(2026, 9, 29), end: d(2026, 10, 2), isAllDay: true)
        #expect(MenuBarMenu.details(trip, fmt: fmt) == "Trip\nTue 29 Sep \u{2013} Thu 1 Oct \u{00B7} all day")
        let site = ev("Site", d(2026, 9, 29, 23), mins: 120, video: "https://example.com/agenda")
        #expect(MenuBarMenu.details(site, fmt: fmt) == "Site\nTue 29 Sep 23:00 \u{2013} Wed 30 Sep 01:00\nLink: https://example.com/agenda")
    }

    @Test func eventFromBeforeMidnightStillRunsToday() {
        let late = ev("Night shift", d(2026, 9, 28, 22), mins: 5 * 60)
        let over = ev("Ended", d(2026, 9, 28, 22), mins: 60)
        let m = build([late, over], at: 1, 0)
        #expect(m.focus?.event.title == "Night shift" && m.focus?.running == true && m.focus?.text == "2 h left")
        #expect(!m.rows.contains { $0.title == "Ended" })
        // Not the focus when a later event is close: then it is listed under Today.
        let m2 = build([late, ev("Early call", d(2026, 9, 29, 1, 10))], at: 1, 0)
        #expect(m2.focus?.event.title == "Early call")
        #expect(m2.sections.first?.rows.map(\.title) == ["Night shift"])
    }

    @Test func onlyMeetingHostsAreCalls() {
        func url(_ s: String) -> URL? { MenuBarMenu.videoURL(ev("x", d(2026, 9, 29, 9), video: s)) }
        #expect(url("https://meet.google.com/abc-defg-hij") != nil)
        #expect(url("https://us02web.zoom.us/j/123") != nil)
        #expect(url("teams.microsoft.com/l/meetup-join/1") != nil)
        #expect(url("meet.example.com/sam-alex")?.absoluteString == "https://meet.example.com/sam-alex")
        #expect(url("https://example.com/agenda.pdf") == nil)
        #expect(url("https://docs.google.com/document/d/1") == nil)
        #expect(url("https://notzoom.us/j/1") == nil)
        #expect(url("") == nil)
        let site = ev("Site", d(2026, 9, 29, 15), video: "https://example.com/agenda")
        #expect(build([site], at: 9, 0).rows.first?.hint == nil)
    }

    @Test func emailOnlyWithAnAddressAndRowMenuAgrees() {
        let party = ev("Party", d(2026, 9, 29, 17), guests: ["A", "B"])
        #expect(MenuBarMenu.submenu(for: party, canRespond: false, guestAddresses: []) == [.copy, .show])
        #expect(build([party], at: 9, 0).rows.first?.hint == nil)
        // A store that can answer still offers Yes / No / Maybe, but no Email.
        let answer = MenuBarMenu.submenu(for: party, canRespond: true, guestAddresses: [])
        #expect(answer.map(\.title) == ["Going?", "Yes", "No", "Maybe", "", "Copy details", "Show in Horion"])
        #expect(build([party], at: 9, 0, canRespond: true).rows.first?.hint == .guests)
        // Addresses written in the participant are found by default.
        let named = ev("Named", d(2026, 9, 29, 18), guests: ["A <a@x.org>"])
        #expect(build([named], at: 9, 0).rows.first?.hint == .guests)
    }
}
