import Testing
import AppKit
import CalendrKit
@testable import Calendr

@MainActor
@Suite("Menu bar item fixes")
struct MenuBarItemFixTests {
    @Test func storeChangesBumpTheVersion() {
        let m = makeModel()
        let v = m.storeVersion
        guard let sam = m.menuBarMenu.rows.first(where: { $0.title == "Sam / Alex" })?.event else { Issue.record("no Sam / Alex"); return }
        m.setResponse(.tentative, for: sam)
        #expect(m.storeVersion > v)
    }

    @Test func highlightedRowIsAllSelectedColour() {
        let m = makeModel()
        let rows = m.menuBarMenu.rows
        guard let r = rows.first(where: { $0.left != nil }) ?? rows.first else { Issue.record("no rows"); return }
        let cols = MenuBarColumns(rows: rows)
        let lit = cols.title(for: r, highlighted: true)
        var colors: [NSColor] = []
        lit.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: lit.length)) { v, _, _ in
            if let c = v as? NSColor { colors.append(c) }
        }
        #expect(!colors.isEmpty)
        #expect(colors.allSatisfy { $0 == .selectedMenuItemTextColor || $0 == NSColor.selectedMenuItemTextColor.withAlphaComponent(0.86) })
        #expect(lit.string == cols.title(for: r, highlighted: false).string)

        let item = NSMenuItem(title: r.title, action: nil, keyEquivalent: "")
        let state = MenuBarRowItem(row: r, columns: cols)
        state.apply(to: item, highlighted: true)
        #expect(item.attributedTitle == lit)
        state.apply(to: item, highlighted: false)
        #expect(item.attributedTitle != lit)
    }

    @Test func timeColumnFitsAllDay() {
        let w = MenuBarColumns.width("all-day", MenuBarColumns.timeFont)
        #expect(MenuBarColumns.timeWidth >= w && MenuBarColumns(rows: []).titleX == MenuBarColumns.timeWidth + 8)
    }
}
