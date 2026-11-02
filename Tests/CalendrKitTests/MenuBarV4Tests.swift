import Testing
import Foundation
@testable import CalendrKit

/// v4 Phase 9: the menu bar's Join row comes from `CallLink`, with the call's logo.
@Suite("Menu bar v4")
struct MenuBarV4Tests {
    let fmt = Fmt(math: berlin)
    func ev(_ t: String, _ start: Date, mins: Int = 60, link: String = "") -> CalendarEvent {
        CalendarEvent(id: t, calendarID: "c", title: t, start: start, end: start.addingTimeInterval(Double(mins) * 60), conferencing: link)
    }
    func build(_ evs: [CalendarEvent], at h: Int, _ m: Int) -> MenuBarMenuModel {
        MenuBarMenu.build(events: evs, now: d(2026, 9, 29, h, m).addingTimeInterval(30), fmt: fmt) { _ in "#5C88E4" }
    }

    @Test func meetEventGivesJoinWithMeet() {
        let m = build([ev("Standup", d(2026, 9, 29, 10), link: "https://meet.google.com/abc-defg-hij")], at: 9, 50)
        #expect(m.joinIndex == 0 && m.joinRow?.title == "Standup")
        #expect(m.joinRow?.call?.kind == .meet && m.joinRow?.call?.url.absoluteString == "https://meet.google.com/abc-defg-hij")
        #expect(m.joinRow?.logo == "meet")
        // The row menu's Join call uses the same link.
        #expect(MenuBarMenu.submenu(for: m.rows[0].event, canRespond: false, guestAddresses: []).first == .join(m.joinRow!.call!.url))
    }

    @Test func zoomEventGivesTheZoomLogo() {
        let m = build([ev("Client call", d(2026, 9, 29, 17, 30), link: "https://us02web.zoom.us/j/88123456789")], at: 17, 20)
        #expect(m.joinRow?.call?.kind == .zoom && m.joinRow?.logo == "zoom")
        #expect(MenuBarMenu.logo(.teams) == "video" && MenuBarMenu.logo(.other) == "video")
    }

    @Test func websiteGivesNoJoin() {
        let m = build([ev("Read the doc", d(2026, 9, 29, 10), link: "https://example.com/agenda")], at: 9, 50)
        #expect(m.rows.count == 1 && m.rows[0].call == nil && m.rows[0].logo == nil)
        #expect(m.joinIndex == nil && m.joinRow == nil)
    }

    @Test func withoutACallOnTheHeadTheNextCallOfTodayGetsJoin() {
        let evs = [ev("Focus", d(2026, 9, 29, 10)), ev("Lunch", d(2026, 9, 29, 12)),
                   ev("Flat dinner", d(2026, 9, 29, 19), link: "meet.google.com/cmv-hjhb-qgb"),
                   ev("Tomorrow call", d(2026, 9, 30, 9), link: "meet.google.com/aaa-bbbb-ccc")]
        let m = build(evs, at: 9, 50)
        #expect(m.head?.title == "Focus" && m.head?.call == nil)
        #expect(m.joinRow?.title == "Flat dinner" && m.joinIndex == 2)
        // Nothing today with a call: no Join row (tomorrow's call keeps its row menu only).
        #expect(build(Array(evs.prefix(2)) + [evs[3]], at: 9, 50).joinIndex == nil)
    }
}
