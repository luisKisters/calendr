import Testing
import AppKit
import HorionKit
@testable import Horion

@MainActor
@Suite("Menu bar item fixes")
struct MenuBarItemFixTests {
    @Test func storeChangesBumpTheVersion() {
        let m = makeModel()
        m.setNow(m.math.date(year: 2026, month: 9, day: 30, hour: 16))
        let v = m.storeVersion
        guard let board = m.menuBarMenu.rows.first(where: { $0.title == "Club board meeting" })?.event else { Issue.record("no Club board meeting"); return }
        m.setResponse(.tentative, for: board)
        #expect(m.storeVersion > v)
    }

    @Test func itemTitleHasADotAndNoRed() {
        let s = MenuBarController.itemTitle(title: "Clean the flat", countdown: "2 h 3 min left")
        #expect(s.string == " Clean the flat  \u{00B7}  2 h 3 min left")
        s.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: s.length)) { v, _, _ in
            if let c = v as? NSColor { #expect(c != MenuBarArt.soon) }
        }
    }

    @Test func rowWidthCutsLongTitles() {
        let long = String(repeating: "Plan the weekend trip with Jamie ", count: 4)
        let m = makeModel()
        guard var r = m.menuBarMenu.rows.first else { Issue.record("no rows"); return }
        r.event.title = long
        let w = MenuBarRowView.width(for: [.row(r)])
        #expect(w <= MenuBarRowView.titleX + MenuBarRowView.maxTitle + 21 + MenuBarRowView.trailing + 1)
        #expect(MenuBarRowView.timeWidth >= MenuBarRowView.width("all-day", MenuBarRowView.timeFont))
    }
}
