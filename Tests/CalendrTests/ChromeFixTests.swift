import Testing
import Foundation
@testable import Calendr
@testable import CalendrKit

/// A store that cannot read other people's calendars (EventKit's position), backed by the demo data.
@MainActor
final class OwnCalendarsOnlyStore: CalendarStore {
    let base = DemoStore()
    var accounts: [CalendarAccount] { base.accounts }
    var teammates: [Teammate] { base.teammates }
    var authorization: StoreAuthorization { .authorized }
    var defaultCalendarID: String? { base.defaultCalendarID }
    var canEditParticipants: Bool { false }
    var onChange: (() -> Void)?
    func requestAccess() async {}
    func refresh() {}
    func events(in range: DateInterval) -> [CalendarEvent] { base.events(in: range) }
    func teammateEvents(_ email: String, in range: DateInterval) -> [CalendarEvent] { [] }
    func searchCorpus(around date: Date) -> [CalendarEvent] { base.searchCorpus(around: date) }
    func create(_ event: CalendarEvent) throws -> CalendarEvent { try base.create(event) }
    func update(_ event: CalendarEvent, span: EditSpan) throws -> CalendarEvent { try base.update(event, span: span) }
    func delete(_ event: CalendarEvent, span: EditSpan) throws { try base.delete(event, span: span) }
    func series(of event: CalendarEvent) -> [CalendarEvent] { base.series(of: event) }
}

/// The demo data with the Family calendar read-only (a subscribed calendar): the read-only paths.
@MainActor
final class ReadOnlyFamilyStore: CalendarStore {
    let base = DemoStore()
    var accounts: [CalendarAccount] {
        base.accounts.map { a in
            var a = a
            a.calendars = a.calendars.map { c in var c = c; if c.id == DemoDataV4.family { c.isWritable = false }; return c }
            return a
        }
    }
    var teammates: [Teammate] { base.teammates }
    var authorization: StoreAuthorization { .authorized }
    var defaultCalendarID: String? { base.defaultCalendarID }
    var canEditParticipants: Bool { true }
    var onChange: (() -> Void)?
    func requestAccess() async {}
    func refresh() {}
    func events(in range: DateInterval) -> [CalendarEvent] { base.events(in: range) }
    func teammateEvents(_ email: String, in range: DateInterval) -> [CalendarEvent] { base.teammateEvents(email, in: range) }
    func searchCorpus(around date: Date) -> [CalendarEvent] { base.searchCorpus(around: date) }
    func create(_ event: CalendarEvent) throws -> CalendarEvent { try base.create(event) }
    func update(_ event: CalendarEvent, span: EditSpan) throws -> CalendarEvent { try base.update(event, span: span) }
    func delete(_ event: CalendarEvent, span: EditSpan) throws { try base.delete(event, span: span) }
    func series(of event: CalendarEvent) -> [CalendarEvent] { base.series(of: event) }
}

@MainActor
@Suite("Chrome fixes")
struct ChromeFixTests {
    func pick(_ m: AppModel, _ title: String, day: Int) -> CalendarEvent {
        m.layout.timed[day].first { $0.event.title == title }!.event
    }

    @Test func tabFromNothingStartsAtTheNextEvent() {
        let m = makeModel()
        m.handle(.selectNext)
        let e = m.selectedEvent
        #expect(e != nil && e!.end > m.now)
        m.handle(.selectPrevious)
        #expect(m.selectedEventID != e?.id)
        m.handle(.selectNext)
        #expect(m.selectedEventID == e?.id)
    }

    @Test func arrowsWalkTheSelectionInsteadOfThePeriod() {
        let m = makeModel()
        let start = m.visibleStart
        let club = pick(m, "Club committee", day: 3)
        m.select(eventID: club.id)
        m.handle(.arrow(dx: 1, dy: 0))
        #expect(m.visibleStart == start)
        #expect(m.selectedEvent.map { m.math.daysBetween(club.start, $0.start) } == 1)
        m.handle(.arrow(dx: -1, dy: 0))
        m.handle(.arrow(dx: 0, dy: -1))
        #expect(m.selectedEvent.map { $0.start <= club.start && m.math.isSameDay($0.start, club.start) } == true)
        m.deselect()
        m.handle(.arrow(dx: 1, dy: 0))
        #expect(m.visibleStart == m.math.addDays(start, 7))
        #expect(m.handle(.arrow(dx: 0, dy: 1)) == false)   // up and down without a selection scroll the grid
    }

    @Test func selectionLeavingThePeriodTakesThePeriodAlong() {
        let m = makeModel()
        let start = m.visibleStart
        let last = m.layout.timed[6].map(\.event).sorted { $0.start < $1.start }.first!
        m.select(eventID: last.id)
        m.handle(.arrow(dx: 1, dy: 0))
        if let e = m.selectedEvent, e.id != last.id {
            #expect(m.visibleStart == m.math.addDays(start, 7))
            #expect(m.visibleDays.contains { m.math.isSameDay($0, e.start) })
        }
    }

    @Test func optionArrowsMoveWithUndo() {
        let m = makeModel()
        let club = pick(m, "Club committee", day: 3)
        m.select(eventID: club.id)
        m.handle(.nudge(dx: 0, dy: 1))
        #expect(m.selectedEvent?.start == club.start.addingTimeInterval(15 * 60))
        #expect(m.toast?.undo == true)
        m.handle(.nudge(dx: 1, dy: 0))
        #expect(m.selectedEventID == club.id)
        #expect(m.selectedEvent.map { m.math.daysBetween(club.start, $0.start) } == 1)
        m.undo(); m.undo()
        #expect(m.event(id: club.id)?.start == club.start)
    }

    @Test func optionArrowsRespectReadOnly() {
        let m = AppModel(store: ReadOnlyFamilyStore(), options: LaunchOptions.parse(["Calendr", "--demo", "--freeze-clock"]), persist: false)
        let e = m.layout.timed[3].first { $0.event.title == "Lunch" }!.event
        m.select(eventID: e.id)
        m.handle(.nudge(dx: 1, dy: 0))
        #expect(m.event(id: e.id)?.start == e.start)
        #expect(m.toast?.text == "This calendar is read-only")
    }

    @Test func returnEditsTheTitle() {
        let m = makeModel()
        #expect(m.handle(.editTitle) == false)
        m.select(eventID: pick(m, "Club committee", day: 3).id)
        let tick = m.focusTitleTick
        #expect(m.handle(.editTitle))
        #expect(m.titleFocusPending && m.focusTitleTick > tick)
    }

    @Test func meetWithOnlyWhereOtherCalendarsCanBeRead() {
        let o = LaunchOptions.parse(["Calendr", "--demo", "--freeze-clock"])
        let m = AppModel(store: OwnCalendarsOnlyStore(), options: o, persist: false)
        m.openPalette(.all)
        #expect(!m.paletteRows.contains { if case .command(let c) = $0.kind { return c.id == .meetWith }; return false })
        m.overlay = nil
        m.handle(.meetWith)
        #expect(m.overlay == nil && m.toast?.text == AppModel.meetWithUnavailable)
        m.openPalette(.meet)
        #expect(m.chromeState.paletteMode == .all)
        #expect(!ShortcutsSheet.groups(meetWith: false).flatMap(\.1).contains { $0.1 == "Meet with" })

        let demo = makeModel()
        demo.openPalette(.all)
        #expect(demo.paletteRows.contains { if case .command(let c) = $0.kind { return c.id == .meetWith }; return false })
    }

    @Test func paletteRowsAreBuiltOncePerInput() {
        let m = makeModel()
        m.openPalette(.all)
        m.setPaletteQuery("walk")
        _ = m.paletteRows
        let builds = m.chromeState.paletteCache.builds
        for i in 0..<5 { m.chromeState.paletteIndex = i; _ = m.paletteRows }
        #expect(m.chromeState.paletteCache.builds == builds)
        m.setPaletteQuery("wal")
        _ = m.paletteRows
        #expect(m.chromeState.paletteCache.builds == builds + 1)
    }

    @Test func bareCharactersAreSwallowed() {
        #expect(KeyRouter.isBareCharacter(KeyInput(characters: "p")))
        #expect(KeyRouter.isBareCharacter(KeyInput(characters: " ")))
        #expect(!KeyRouter.isBareCharacter(KeyInput(characters: "p", command: true)))
        #expect(!KeyRouter.isBareCharacter(KeyInput(characters: "p", option: true)))
        #expect(!KeyRouter.isBareCharacter(KeyInput(characters: "\r")))
        #expect(!KeyRouter.isBareCharacter(KeyInput(characters: "\u{F704}")))   // F1
    }

    @Test func commandMenuIconsAreTheMockups() {
        #expect(CommandID.meetWith.icon == .users && CommandID.today.icon == .cal && CommandID.undo.icon == .ret)
        for n in [ChromeIcon.Name.plus, .cal, .left, .right, .side, .moon, .search, .users, .ret, .trash, .gear, .clock, .keys] {
            #expect(!ChromeIcon.path(n).isEmpty)
        }
    }
}
