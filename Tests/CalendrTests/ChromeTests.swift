import Testing
import Foundation
@testable import Calendr
@testable import CalendrKit

@MainActor
@Suite("Chrome")
struct ChromeTests {
    func model() -> AppModel { makeModel() }

    @Test func typedDateComesFirstAsGoTo() {
        let m = model()
        m.openPalette(.all)
        m.setPaletteQuery("tomorrow")
        let first = m.paletteRows.first
        #expect(first?.section == "Go to")
        if case .date(let d)? = first?.kind { #expect(m.math.day(d) == 30) } else { Issue.record("no date row") }
    }

    @Test func weekNumberParses() {
        let m = model()
        let d = GoToDateParser.parse("w42", now: m.now, math: m.math)
        #expect(d.map { m.math.month($0) == 10 && m.math.day($0) == 12 } == true)
    }

    @Test func eventsAppearFromTwoCharacters() {
        let m = model()
        m.openPalette(.all)
        m.setPaletteQuery("c")
        #expect(!m.paletteRows.contains { $0.section == "Events" })
        m.setPaletteQuery("calculus")
        #expect(m.paletteRows.contains { $0.section == "Events" })
    }

    @Test func searchModeListsNearestFirst() {
        let m = model()
        m.openPalette(.search)
        m.setPaletteQuery("calculus")
        let days = m.paletteRows.compactMap { r -> Int? in if case .event(let e) = r.kind { return abs(m.math.daysBetween(m.now, e.start)) }; return nil }
        #expect(!days.isEmpty && days == days.sorted())
    }

    @Test func backspaceLeavesAMode() {
        let m = model()
        m.handle(.meetWith)
        #expect(m.overlay == .command && m.chromeState.paletteMode == .meet)
        #expect(m.paletteBack())
        #expect(m.chromeState.paletteMode == .all)
        #expect(!m.paletteBack())
    }

    @Test func choosingAMateTwiceRemovesTheOverlay() {
        let m = model()
        m.openPalette(.meet)
        m.setPaletteQuery("maya")
        m.runPaletteSelection()
        #expect(m.shownTeammates.map(\.name) == ["Maya Sterling"] && m.overlay == nil)
        m.openPalette(.meet)
        m.setPaletteQuery("maya")
        #expect(m.paletteRows.first?.shown == true)
        m.runPaletteSelection()
        #expect(m.shownTeammates.isEmpty)
    }

    @Test func commandsOpenModesAndSheets() {
        let m = model()
        m.openPalette(.all)
        m.run(.goToDate); #expect(m.overlay == .command && m.chromeState.paletteMode == .goTo)
        m.run(.settings); #expect(m.overlay == .settings)
        m.run(.viewMonth); #expect(m.overlay == nil && m.viewMode == .month)
    }

    @Test func escapeDiscardsTheDraftBeforeTheSelection() {
        let m = model()
        m.createAtNextFreeSlot()
        let id = m.draftEventID
        #expect(id != nil)
        m.handle(.escape)
        #expect(m.draftEventID == nil && m.selectedEventID == nil)
        #expect(m.event(id: id) == nil || m.layout.timed.flatMap { $0 }.allSatisfy { $0.event.id != id })
    }

    @Test func moveShowsAnUndoToast() {
        let m = model()
        let e = m.layout.timed[3].first { $0.event.title == "Piano lesson" }!.event
        var moved = e
        moved.start = e.start.addingTimeInterval(3600); moved.end = e.end.addingTimeInterval(3600)
        m.commit(moved, span: .this, old: e)
        #expect(m.toast?.undo == true && m.toast?.text == "Moved to Thu 1 Oct, 14:00")
    }

    @Test func headerTitleSpansMonths() {
        let m = model()
        #expect(m.chromeTitle.main == "Sep \u{2013} Oct" && m.chromeTitle.year == "2026")
        m.setMode(.month)
        #expect(m.chromeTitle.main == "September")
    }
}
