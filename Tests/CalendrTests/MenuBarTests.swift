import Testing
import Foundation
import CalendrKit
@testable import Calendr

@MainActor
@Suite("Menu bar on the demo week")
struct MenuBarModelTests {
    @Test func demoMenuMatchesMockup() {
        let m = makeModel()
        let menu = m.menuBarMenu
        // Sun 4 Oct 15:10: Test runs until 15:45; the fixture has nothing after Sunday.
        #expect(menu.focus?.event.title == "Test" && menu.focus?.text == "35 min left")
        #expect(menu.sections.map(\.title) == ["Today"])
        #expect(menu.sections[0].rows.prefix(4).allSatisfy { $0.start == "all-day" })
        #expect(menu.sections[0].rows.dropFirst(4).prefix(2).map(\.title) == ["[P0] Weekly review", "[P1] Take vitamins"])
        // Wednesday 16:00: three days ahead, each with its all-day rows first.
        m.setNow(m.math.date(year: 2026, month: 9, day: 30, hour: 16))
        let wed = m.menuBarMenu
        #expect(wed.focus?.event.title == "Founder meetup" && wed.focus?.text == "in 1 h")
        #expect(wed.sections.map(\.title) == ["Today", "Tomorrow", "Fri 2 Oct"])
        #expect(wed.sections[1].rows.first?.start == "all-day")
    }
    @Test func hiddenCalendarsAreLeftOut() {
        let m = makeModel()
        guard let cal = m.menuBarMenu.head?.event.calendarID else { Issue.record("no head"); return }
        m.toggleCalendar(cal)
        #expect(!m.menuBarMenu.rows.contains { $0.event.calendarID == cal })
    }
    @Test func demoStoreCanAnswerAndTheMenuFollows() {
        let m = makeModel()
        #expect(m.canChangeResponse)
        guard let dinner = m.menuBarMenu.rows.first(where: { $0.title == "Flat dinner" })?.event else { Issue.record("no Flat dinner"); return }
        let sub = m.menuBarSubmenu(for: dinner)
        #expect(sub.contains(.respond(.confirmed, checked: true)))
        // Every guest has an address: one Email item for all four.
        #expect(sub.contains { if case .email(let t, _) = $0 { t == "Email 4 guests" } else { false } })
        // Sam organises Flat dinner; an invitation gets the reply: Wednesday 16:00, Club board meeting (not answered yet).
        m.setNow(m.math.date(year: 2026, month: 9, day: 30, hour: 16))
        guard let board = m.menuBarMenu.rows.first(where: { $0.title == "Club board meeting" })?.event else { Issue.record("no Club board meeting"); return }
        #expect(m.menuBarSubmenu(for: board).contains(.respond(.confirmed, checked: false)))
        m.setResponse(.tentative, for: board)
        let after = m.menuBarMenu.rows.first { $0.title == "Club board meeting" }
        #expect(after?.tentative == true)
    }
}
