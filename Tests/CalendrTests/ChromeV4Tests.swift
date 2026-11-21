import Testing
import Foundation
import CalendrKit
@testable import Calendr

/// v4 Phase 6: the right column's search field, its results, the useful shortcuts, the sidebar account names.
@MainActor
@Suite("Chrome v4")
struct ChromeV4Tests {
    @Test func slashFocusesTheColumnSearch() {
        let m = makeModelV4()
        #expect(!m.chromeState.searchFocused)
        let tick = m.chromeState.searchFocusTick
        #expect(m.handle(ShortcutResolver.resolve(KeyInput(characters: "/", keyCode: 44), textFocused: false)!))
        #expect(m.chromeState.searchFocused && m.chromeState.searchFocusTick == tick + 1)
        #expect(m.overlay == nil, "/ no longer opens the command menu")
    }

    @Test func commandFAndTheCommandMenuFocusTheField() {
        let m = makeModelV4()
        #expect(ShortcutResolver.resolve(KeyInput(characters: "f", keyCode: 3, command: true), textFocused: true) == .searchEvents)
        m.openPalette(.all)
        m.run(.searchEvents)
        #expect(m.overlay == nil && m.chromeState.searchFocused)
    }

    @Test func aQueryShowsResultsGroupedByDay() {
        let m = makeModelV4()
        #expect(!m.columnSearching && m.columnResults.isEmpty)
        m.setColumnQuery("walk")
        #expect(m.columnSearching)
        let groups = m.columnResults
        #expect(groups.map { m.math.day($0.day) } == [28, 30, 1, 4])
        #expect(groups.allSatisfy { g in g.events.allSatisfy { $0.title == "Evening walk" && m.math.isSameDay($0.start, g.day) } })
        m.setColumnQuery("   ")
        #expect(!m.columnSearching && m.columnResults.isEmpty)
    }

    @Test func returnOpensTheFirstResultAndEscClearsTheQuery() {
        let m = makeModelV4()
        m.setColumnQuery("walk")
        m.chromeState.searchFocused = true
        m.openFirstColumnResult()
        #expect(m.selectedEvent?.title == "Evening walk" && m.math.day(m.selectedEvent!.start) == 28)
        #expect(!m.chromeState.searchFocused && m.chromeState.columnQuery == "walk")
        #expect(m.handle(.escape) && m.selectedEventID == nil && m.columnSearching)
        #expect(m.handle(.escape) && !m.columnSearching && m.chromeState.columnQuery.isEmpty)
    }

    @Test func theCommandMenuKeepsTheColumnQuery() {
        let m = makeModelV4()
        m.setColumnQuery("walk")
        m.openPalette(.all)
        m.setPaletteQuery("flat")
        m.overlay = nil
        #expect(m.searchText == "walk" && m.columnResults.count == 4)
    }

    @Test func usefulShortcutsRunTheirActions() {
        let m = makeModelV4()
        #expect(m.usefulShortcuts.map(\.title) == Shortcuts.useful.map(\.title))
        m.runUseful(Shortcuts.useful[0])
        #expect(m.overlay == .command)
        m.overlay = nil
        m.runUseful(Shortcuts.useful.last!)
        #expect(m.overlay == .shortcuts)
        m.overlay = nil
        let visible = m.sidebarVisible
        m.runUseful(Shortcuts.useful.first { $0.action == .toggleSidebar }!)
        #expect(m.sidebarVisible != visible)
    }

    @Test func sidebarAccountsShowTheirNameWithoutTheDomain() {
        let m = makeModelV4()
        #expect(m.store.accounts.map { AccountName.display($0.name) } == ["sam.rivera", "sam", "sam"])
    }
}
