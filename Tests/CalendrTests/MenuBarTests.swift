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
        #expect(menu.focus?.event.title == "Calculus" && menu.focus?.text == "in 12 min")
        #expect(menu.sections.map(\.title) == ["Today", "Tomorrow", "Thu 1 Oct"])
        #expect(menu.sections[0].rows.prefix(2).map(\.title) == ["Genetics", "Sam / Alex"])
        #expect(menu.sections[1].rows.first?.start == "all-day")
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
        guard let sam = m.menuBarMenu.rows.first(where: { $0.title == "Sam / Alex" })?.event else { Issue.record("no Sam / Alex"); return }
        let sub = m.menuBarSubmenu(for: sam)
        #expect(sub.contains(.respond(.confirmed, checked: true)))
        // Sam Okafor has no address in the demo, so there is no Email item.
        #expect(!sub.contains { if case .email = $0 { true } else { false } })
        m.setResponse(.tentative, for: sam)
        let after = m.menuBarMenu.rows.first { $0.title == "Sam / Alex" }
        #expect(after?.tentative == true)
    }
}
