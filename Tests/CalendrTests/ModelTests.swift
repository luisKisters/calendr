import Testing
import Foundation
import CalendrKit
import CoreText
@testable import Calendr

@MainActor
func makeModel() -> AppModel {
    let o = LaunchOptions.parse(["Calendr", "--demo", "--freeze-clock"])
    return AppModel(store: DemoStore(), options: o, persist: false)
}

@MainActor
@Suite("Demo week (the v4 fixture) in the model")
struct DemoWeekTests {
    @Test func tuesdayTimedTitlesInOrder() {
        let m = makeModel()
        let tue = m.layout.timed[1].map(\.event).sorted { $0.start < $1.start }.map { "\(m.fmt.time($0.start)) \($0.title)" }
        #expect(tue == ["08:00 Deep work", "10:00 Standup", "12:00 Team lunch", "14:35 Research interviews", "16:00 [P2] Fill in the insurance form",
                        "16:30 Focus block", "18:15 [P1] Take vitamins", "19:30 Flat meeting", "19:40 📦 Pick up the parcel", "23:15 Journal"])
    }
    @Test func allDayLanesForFriSun() {
        let m = makeModel()
        let byTitle = Dictionary(uniqueKeysWithValues: m.layout.allDay.placements.map { (m.layout.allDayEvents[$0.id]!.title, $0) })
        #expect(byTitle["Trip (maybe)"]?.span == 3 && byTitle["Trip (maybe)"]?.lane == 0)
        #expect(byTitle["Alex away"]?.lane == 1)
        #expect(m.layout.allDay.laneCount == 7)
    }
    @Test func tasksAreOrdinaryEventsWithRawTitles() {
        let m = makeModel()
        let tasks = m.layout.timed.flatMap { $0 }.map(\.event).filter { $0.calendarID == DemoDataV4.tasks }
        #expect(tasks.contains { $0.title == "[P1] Take vitamins" && m.fmt.time($0.start) == "18:15" && $0.end == $0.start })
        #expect(m.layout.timed[6].contains { $0.event.title == "[P1] Reply to Ines" && m.fmt.time($0.event.start) == "09:40" })
    }
    @Test func guestsAndCallMatchTheFixture() {
        let m = makeModel()
        let client = m.layout.timed[3].first { $0.event.title == "Client call" }!.event
        #expect(client.participants == ["Sven Krüger"] && client.conferencing == "https://zoom.us/j/88123456789")
        let pitch = m.layout.timed[4].first { $0.event.title == "Pitch rehearsal" }!.event
        #expect(pitch.participants.count == 2 && pitch.conferencing.contains("meet.google.com"))
    }
    @Test func officeHoursIsWeekly() {
        let m = makeModel()
        let hours = m.layout.timed[3].first { $0.event.title == "Office hours" }!.event
        #expect(hours.recurrence?.frequency == .weekly)
        let t = RecurrenceDescriber.describe(hours.recurrence!, start: hours.start, fmt: m.fmt)
        #expect(t.lead == "Every week" && t.rest == "on Thu")
    }
    @Test func upcomingFollowsTheClock() {
        let m = makeModel()
        #expect(m.upcoming.next?.title == "[P0] Weekly review")
        #expect(m.upcoming.sections.map(\.title) == ["Today"])
        #expect(m.upcoming.sections[0].events.first?.title == "[P1] Take vitamins")
    }
    @Test func sidebarAccountsMatchTheFixture() {
        let m = makeModel()
        #expect(m.store.accounts.map(\.name) == ["sam.rivera@example.com", "sam@northwind.example", "sam@sideproject.example"])
        #expect(m.store.accounts.map(\.calendars.count) == [4, 1, 1])
        #expect(m.hiddenCalendars.isEmpty)
        #expect(m.store.teammates.count == 11)
    }
    @Test func meetWithBusyBlocksAreTheMockups() {
        // design/mockup-v4 busyFor(): mara gets one usable block (the second one ends before it starts), ines seven.
        #expect(DemoDataV4.busy("mara").map { [$0.day, $0.start, $0.end] } == [[0, 600, 690], [0, 720, 690]])
        #expect(DemoDataV4.busy("ines").map { [$0.day, $0.start, $0.end] } == [[0, 600, 630], [1, 960, 990], [2, 960, 990], [3, 720, 750], [4, 720, 750], [4, 960, 990], [4, 720, 750]])
        let store = DemoStore()
        let week = DateInterval(start: DemoDataV4.weekStart, end: DemoDataV4.math.addDays(DemoDataV4.weekStart, 7))
        #expect(store.teammateEvents("mara.hoffmann@example.com", in: week).count == 1)
        #expect(store.teammateEvents("ines.d@example.com", in: week).count == 7)
    }
}

@MainActor
@Suite("Model behaviour")
struct ModelBehaviourTests {
    @Test func navigationAndModes() {
        let m = makeModel()
        #expect(m.headerTitle == "September 2026")
        m.next(); #expect(m.math.day(m.visibleStart) == 5 && m.math.month(m.visibleStart) == 10)
        m.previous(); m.previous(); #expect(m.math.day(m.visibleStart) == 21)
        m.goToToday(); #expect(m.math.day(m.visibleStart) == 28)
        m.setMode(.day); #expect(m.visibleDays.count == 1)
        m.setMode(.month); #expect(m.monthEvents.count == 42 && m.headerTitle == "October 2026")
        m.next(); #expect(m.headerTitle == "November 2026")
    }
    @Test func leftAlignStartsAtToday() {
        let m = makeModel()
        m.leftAlignToday()
        #expect(m.math.day(m.visibleStart) == 4)
        m.next(); #expect(m.math.day(m.visibleStart) == 11)
    }
    @Test func createMoveResizeDeleteUndo() {
        let m = makeModel()
        // Drag-create on Saturday 17:30-18:30 (free in the fixture) through the same entry points the gesture uses.
        m.gridGeometry = GridGeometry(dayWidth: 180, hourHeight: 48, dayCount: 7)
        let g = m.gridGeometry
        m.gridMouseDown(CGPoint(x: 5.5 * g.dayWidth, y: g.yPos(17 * 60 + 30) + 2))
        m.gridMouseDragged(CGPoint(x: 5.5 * g.dayWidth, y: g.yPos(18 * 60 + 25)))
        m.gridMouseUp(CGPoint(x: 5.5 * g.dayWidth, y: g.yPos(18 * 60 + 25)))
        let created = m.selectedEvent
        #expect(created != nil && m.fmt.time(created!.start) == "17:30" && m.fmt.time(created!.end) == "18:30")
        #expect(m.layout.timed[5].contains { $0.event.id == created!.id })
        // The draft cannot be dragged; the panel saves it first.
        m.updateSelected { $0.title = "Run" }
        m.draftEventID = nil
        // Move it to Thursday 14:30 (free).
        let id = created!.id
        m.gridMouseDown(CGPoint(x: 5.5 * g.dayWidth, y: g.yPos(17 * 60 + 50)))
        m.gridMouseDragged(CGPoint(x: 3.5 * g.dayWidth, y: g.yPos(14 * 60 + 50)))
        m.gridMouseUp(CGPoint(x: 3.5 * g.dayWidth, y: g.yPos(14 * 60 + 50)))
        let moved = m.event(id: id)!
        #expect(m.math.weekdayIndex(moved.start) == 3 && m.fmt.time(moved.start) == "14:30" && m.fmt.time(moved.end) == "15:30")
        // Resize by the bottom edge to 16:30.
        m.gridMouseDown(CGPoint(x: 3.5 * g.dayWidth, y: g.yPos(15 * 60 + 30) - 5))
        m.gridMouseDragged(CGPoint(x: 3.5 * g.dayWidth, y: g.yPos(16 * 60 + 30) + 3))
        m.gridMouseUp(CGPoint(x: 3.5 * g.dayWidth, y: g.yPos(16 * 60 + 30) + 3))
        #expect(m.fmt.time(m.event(id: id)!.end) == "16:30")
        // Undo resize, undo move, undo create.
        m.undo(); #expect(m.fmt.time(m.event(id: id)!.end) == "15:30")
        m.undo(); #expect(m.math.weekdayIndex(m.event(id: id)!.start) == 5)
        m.undo(); #expect(m.layout.timed[5].allSatisfy { $0.event.id != id })
    }
    @Test func deleteAndUndoRestores() {
        let m = makeModel()
        let ev = m.layout.timed[6].first { $0.event.title == "Long run" }!.event
        // The fixture holds one week: give the series a second occurrence, the next Sunday.
        var next = ev; next.id = "v4.g1.next"; next.start = m.math.addDays(ev.start, 7); next.end = m.math.addDays(ev.end, 7)
        try! m.store.create(next)
        m.select(eventID: ev.id)
        m.requestDeleteSelected()       // recurring: asks first
        #expect(m.overlay == .deleteRecurring(ev.id))
        m.delete(ev, span: .this)
        #expect(m.layout.timed[6].allSatisfy { $0.event.id != ev.id })
        m.undo()
        #expect(m.layout.timed[6].contains { $0.event.id == ev.id })
    }
    @Test func deleteAllRemovesSeries() {
        let m = makeModel()
        let ev = m.layout.timed[6].first { $0.event.title == "Long run" }!.event
        var next = ev; next.id = "v4.g1.next"; next.start = m.math.addDays(ev.start, 7); next.end = m.math.addDays(ev.end, 7)
        try! m.store.create(next)
        #expect(m.store.series(of: ev).count == 2)
        m.delete(ev, span: .all)
        #expect(m.store.series(of: ev).isEmpty)
        m.next()
        #expect(m.layout.timed.flatMap { $0 }.allSatisfy { $0.event.seriesID != ev.seriesID })
    }
    @Test func untitledDraftIsDiscardedOnDeselect() {
        let m = makeModel()
        let s = m.math.date(year: 2026, month: 10, day: 3, hour: 12)
        let e = m.createEvent(start: s, end: s.addingTimeInterval(3600))!
        m.deselect()
        #expect(m.event(id: e.id) == nil)
        #expect(!m.store.events(in: DateInterval(start: s, duration: 3600)).contains { $0.id == e.id })
        #expect(!m.layout.timed[5].contains { $0.event.id == e.id })
        #expect(m.undoStack.isEmpty)
    }
    @Test func inspectorEditWritesThrough() {
        let m = makeModel()
        let ev = m.layout.timed[2].first { $0.event.title == "Reading" }!.event
        m.select(eventID: ev.id)
        m.updateSelected { $0.title = "Reading 2"; $0.location = "Room 5" }
        #expect(m.layout.timed[2].contains { $0.event.title == "Reading 2" && $0.event.location == "Room 5" })
    }
    @Test func createShortcutPicksNextFreeHalfHour() {
        let m = makeModel()
        m.handle(.createEvent)
        let e = m.selectedEvent!
        #expect(m.fmt.time(e.start) == "16:00")     // now is 15:10; Test runs to 15:45, Weekly review is at 17:00
        #expect(e.durationMinutes == 60)
    }
    @Test func hiddenCalendarsAndTeammatesAffectLayout() {
        let m = makeModel()
        let before = m.layout.timedCount
        m.toggleCalendar(DemoDataV4.tasks)
        #expect(m.layout.timedCount < before)
        m.toggleCalendar(DemoDataV4.tasks)
        #expect(m.layout.timedCount == before)
        m.showTeammate(m.store.teammates.first { $0.name == "Ines Duarte" }!)
        #expect(m.overlayLayout.timedCount == 7)
    }
    @Test func searchFindsAcrossWeeksAndNavigates() {
        let m = makeModel()
        m.next(); m.next()
        m.searchText = "Evening walk"
        #expect(!m.searchGroups.isEmpty)
        let hit = m.searchGroups.flatMap(\.events).first { $0.start > m.now }!
        #expect(!m.visibleDays.contains { m.math.isSameDay($0, hit.start) })
        m.openSearchResult(hit)
        #expect(m.selectedEventID == hit.id)
        #expect(m.visibleDays.contains { m.math.isSameDay($0, hit.start) })
    }
    @Test func commandFlowGoToDate() {
        let m = makeModel()
        m.handle(.goToDate)
        m.setPaletteQuery("oct 12")
        #expect(m.chromeState.paletteMode == .goTo && m.paletteRows.count == 1)
        m.runPaletteSelection()
        #expect(m.overlay == nil && m.math.day(m.visibleStart) == 12)
    }
    @Test func escapeUnwindsLayers() {
        let m = makeModel()
        m.handle(.commandMenu); #expect(m.overlay == .command)
        m.handle(.escape); #expect(m.overlay == nil)
        m.select(eventID: m.layout.timed[1][0].event.id)
        m.handle(.escape); #expect(m.selectedEventID == nil)
    }
    @Test func calendarsHiddenAtLaunchStartHidden() {
        let store = TweakedCalendarStore(DemoDataV4.club) { $0.isVisibleByDefault = false }
        let m = AppModel(store: store, options: LaunchOptions.parse(["Calendr", "--demo", "--freeze-clock"]), persist: false)
        #expect(m.hiddenCalendars == [DemoDataV4.club])
        #expect(!m.layout.timed.joined().contains { $0.event.calendarID == DemoDataV4.club })
        #expect(!m.layout.timed[3].contains { $0.event.title == "Club committee" } && m.layout.timed[6].allSatisfy { $0.event.title != "Long run" })
        m.toggleCalendar(DemoDataV4.club)
        #expect(m.hiddenCalendars.isEmpty && m.layout.timed[3].contains { $0.event.title == "Club committee" })
    }
    @Test func aNewerToastReplacesTheOldAndUndoDismissesIt() {
        let m = makeModel()
        let club = m.layout.timed[3].first { $0.event.title == "Club committee" }!.event
        var later = club; later.end = club.end.addingTimeInterval(1800)
        m.commit(later, span: .this, old: club)
        #expect(m.toast?.undo == true && m.toast?.text.hasPrefix("Ends") == true)
        var moved = later; moved.start = club.start.addingTimeInterval(3600); moved.end = later.end.addingTimeInterval(3600)
        m.commit(moved, span: .this, old: later)
        #expect(m.toast?.text.hasPrefix("Moved to") == true)          // the newer action's pill, at once
        m.handle(.undo)                                               // Cmd-Z: the pill that offered it goes
        #expect(m.toast == nil && m.event(id: club.id)?.start == club.start)
        m.select(eventID: club.id)
        m.handle(.deleteSelection)
        #expect(m.toast?.undo == true && m.event(id: club.id) == nil)
        m.undo()
        #expect(m.toast == nil && m.event(id: club.id) != nil)
        m.undo(); m.undo()
        #expect(m.toast?.text == "Nothing to undo")                   // a plain message still shows
    }
    @Test func readOnlyCalendarEventsCannotBeMovedOrEdited() {
        let m = AppModel(store: TweakedCalendarStore(), options: LaunchOptions.parse(["Calendr", "--demo", "--freeze-clock"]), persist: false)
        let lunch = m.layout.timed[3].first { $0.event.title == "Lunch" }!.event
        #expect(!m.isWritable(lunch) && m.isWritable(m.layout.timed[3].first { $0.event.title == "Club committee" }!.event))
        m.select(eventID: lunch.id)
        m.updateSelected { $0.title = "x" }
        #expect(m.selectedEvent?.title == "Lunch")
    }
}


@MainActor
@Suite("Write paths")
struct WritePathTests {
    @Test func typingIsCoalescedIntoOneStoreWriteWhenTheStoreSyncsOverTheNetwork() {
        let store = DemoStore()
        store.coalescesTextEdits = true
        let o = LaunchOptions.parse(["Calendr", "--demo", "--freeze-clock"])
        let m = AppModel(store: store, options: o, persist: false)
        let e = m.layout.timed[1].first { $0.event.title == "Standup" }!.event
        m.select(eventID: e.id)
        let before = m.reloadCount
        for t in ["S", "Sp", "Spa", "Span"] { m.updateSelected { $0.title = t } }
        #expect(m.reloadCount == before)                      // nothing written yet
        #expect(m.selectedEvent?.title == "Span")             // but the inspector already shows the text
        m.flushPendingEdit()
        #expect(m.reloadCount == before + 1)                  // one save
        #expect(m.event(id: e.id)?.title == "Span")
    }

    @Test func draggingTheSecondDaySegmentOfAMultiDayEventKeepsItsStart() {
        let m = makeModel()
        let day0 = m.visibleDays[0]
        let start = m.math.date(on: day0, minutes: 22 * 60), end = m.math.date(on: m.visibleDays[1], minutes: 2 * 60)
        let ev = m.createEvent(start: start, end: end)!
        m.updateSelected { $0.title = "Night shift" }
        m.draftEventID = nil
        let g = m.gridGeometry
        let x = 1.5 * g.dayWidth
        m.gridMouseDown(CGPoint(x: x, y: g.yPos(30)))
        m.gridMouseDragged(CGPoint(x: x, y: g.yPos(60)))
        m.gridMouseUp(CGPoint(x: x, y: g.yPos(60)))
        let moved = m.event(id: ev.id) ?? m.layout.timed.flatMap { $0 }.first { $0.event.title == "Night shift" }!.event
        #expect(moved.start == start.addingTimeInterval(30 * 60))
        #expect(moved.end == end.addingTimeInterval(30 * 60))
    }
}

@Suite("Typeface")
struct TypefaceTests {
    @Test func instrumentSansIsBundledAndRegistered() {
        #expect(Typeface.locate() != nil)
        #expect(Typeface.register())
        let f = Typeface.ctFont(13, weight: 600, tabular: true)
        #expect(CTFontCopyFamilyName(f) as String == Typeface.family)
    }
    @Test func oldSettingsDecodeWithDefaults() throws {
        let old = #"{"appearance":"Light","weekStartsOnMonday":true,"defaultDurationMinutes":45,"showDeclined":true,"use24h":true,"firstVisibleHour":7,"reduceMotion":false}"#
        let s = try JSONDecoder().decode(AppSettings.self, from: Data(old.utf8))
        #expect(s.appearance == .light && s.defaultDurationMinutes == 45)
        #expect(!s.showWeekNumbers && s.menuBarDisplay == .titleAndCountdown && s.hourHeight == nil)
    }
}
