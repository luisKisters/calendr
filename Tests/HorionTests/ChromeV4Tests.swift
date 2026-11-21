import Testing
import Foundation
import HorionKit
@testable import Horion

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

    /// v8 decision C: the right column has no shortcut list; the shortcuts stay behind ⌘K and ?.
    @Test func shortcutsStayBehindCommandKAndQuestionMark() {
        let m = makeModelV4()
        m.handle(.commandMenu)
        #expect(m.overlay == .command)
        m.overlay = nil
        m.handle(.showShortcuts)
        #expect(m.overlay == .shortcuts)
        m.overlay = nil
        let visible = m.sidebarVisible
        m.handle(.toggleSidebar)
        #expect(m.sidebarVisible != visible)
    }

    /// The header's right-column button (⌥⌘I, mockup C6): hides the column; selecting an event or searching shows it again.
    @Test func rightColumnHidesAndComesBackForTheEditorAndSearch() {
        let m = makeModelV4()
        #expect(m.rightColumnVisible)
        m.handle(.toggleRightColumn)
        #expect(!m.rightColumnVisible)
        let e = m.layout.timed.flatMap { $0 }.first?.event.id
        m.select(eventID: e)
        #expect(m.rightColumnVisible, "selecting opens the column (the editor lives there)")
        m.deselect()
        m.toggleRightColumn()
        #expect(!m.rightColumnVisible)
        m.focusColumnSearch()
        #expect(m.rightColumnVisible, "search opens the column")
        #expect(CommandRegistry.all.contains { $0.id == .toggleRightColumn && $0.keys == ["\u{2325}", "\u{2318}", "I"] })
    }

    /// v8 decisions D and E: a group header folds its calendars (their visibility stays); hiding is explicit and kept in the list.
    @Test func sidebarGroupsFoldAndHiddenCalendarsStay() {
        let m = makeModelV4()
        let acc = m.store.accounts[0]
        m.toggleGroup(acc.id)
        #expect(m.collapsedGroups == [acc.id] && m.hiddenCalendars.isDisjoint(with: acc.calendars.map(\.id)))
        m.toggleGroup(acc.id)
        #expect(m.collapsedGroups.isEmpty)
        let cal = acc.calendars[0]
        m.toggleCalendar(cal.id)
        #expect(m.hiddenCalendars.contains(cal.id) && m.store.accounts[0].calendars.contains { $0.id == cal.id })
        #expect(!m.layout.timed.flatMap { $0 }.contains { $0.event.calendarID == cal.id })
    }

    /// ⌘J joins the call of the running event, else the next one's, as the right column's Join buttons show.
    @Test func commandJJoinsTheLeadCall() {
        let m = makeModelV4()
        m.setNow(m.math.date(on: m.math.startOfDay(m.now), minutes: 18 * 60 + 40))
        #expect(ShortcutResolver.resolve(KeyInput(characters: "j", command: true), textFocused: true) == .joinCall)
        #expect(m.leadCallEvent?.title == "Flat dinner")     // (not run here: outside a headless run it opens the browser)
        m.setNow(m.math.date(on: m.math.startOfDay(m.now), minutes: 23 * 60 + 50))
        #expect(m.leadCallEvent == nil && !m.handle(.joinCall), "no call: the key is not consumed")
    }

    @Test func sidebarAccountsShowTheirNameWithoutTheDomain() {
        let m = makeModelV4()
        #expect(m.store.accounts.map { AccountName.display($0.name) } == ["sam.rivera", "sam", "sam"])
    }
}
