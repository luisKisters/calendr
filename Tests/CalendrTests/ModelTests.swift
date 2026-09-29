import Testing
import Foundation
import CalendrKit
@testable import Calendr

@MainActor
func makeModel() -> AppModel {
    var o = LaunchOptions(); o.demo = true; o.freezeClock = true; o.now = DemoData.defaultNow
    return AppModel(store: DemoStore(), options: o, persist: false)
}

@MainActor
@Suite("Demo week matches the reference screenshot")
struct DemoWeekTests {
    @Test func tuesdayTimedTitlesInOrder() {
        let m = makeModel()
        let tue = m.layout.timed[1].map(\.event).sorted { $0.start < $1.start }.map { "\(m.fmt.time($0.start)) \($0.title)" }
        #expect(tue == ["07:30 Meal Prep", "07:30 Gym bag", "08:00 Data Structures", "10:10 Genetics", "12:00 Calculus", "14:00 Sam / Alex", "16:00 [P1] Book a haircut",
                        "16:15 Public Policy", "18:00 [P1] Water the plants - every day until done", "20:00 [P1] Plan the weekend trip with Jamie",
                        "22:00 Call with Jamie", "22:49 Evening journal", "23:00 [P0] Stretch for ten minutes"])
    }
    @Test func allDayLanesForFriSun() {
        let m = makeModel()
        let byTitle = Dictionary(uniqueKeysWithValues: m.layout.allDay.placements.map { (m.layout.allDayEvents[$0.id]!.title, $0) })
        #expect(byTitle["OFFSITE?? (maybe, see desc)"]?.span == 3)
        #expect(byTitle["Sam away"]?.lane == 1)
        #expect(m.layout.allDay.laneCount == 5)
    }
    @Test func wednesdayHasDeclinedClimbing() {
        let m = makeModel()
        #expect(m.layout.timed[2].contains { $0.event.title == "Climbing" && $0.event.status == .declined })
    }
    @Test func inspectorSampleIsRecurringPolicy() {
        let m = makeModel()
        let policy = m.layout.timed[2].first { $0.event.title == "Public Policy" }!.event
        #expect(policy.recurrence?.frequency == .weekly)
        #expect(policy.location.hasPrefix("Halden College"))
        let t = RecurrenceDescriber.describe(policy.recurrence!, start: policy.start, fmt: m.fmt)
        #expect(t.lead == "Every week" && t.rest.hasPrefix("on Wed until"))
    }
    @Test func menuBarLabelMatchesReference() {
        let m = makeModel()
        #expect(Upcoming.menuBarLabel(m.upcoming) == "Calculus \u{00B7} in 12m")
        #expect(m.upcoming.sections.map(\.title).prefix(3) == ["Today", "Tomorrow", "Thu Oct 1"])
        #expect(m.upcoming.sections[0].events.first?.title == "Sam / Alex")
    }
    @Test func sidebarAccountsMatchSpec() {
        let m = makeModel()
        #expect(m.store.accounts.map(\.name) == ["alex.rivera@mail.example.com", "alex.rivera.studio@mail.example.com", "alex.rivera@northwind.example.com"])
        #expect(m.store.accounts[0].calendars.count == 7 && m.store.accounts[1].calendars.count == 4)
        #expect(m.hiddenCalendars.count == 3)
        #expect(m.store.teammates.count == 11)
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
        m.setMode(.month); #expect(m.monthEvents.count == 42 && m.headerTitle == "September 2026")
        m.next(); #expect(m.headerTitle == "October 2026")
    }
    @Test func leftAlignStartsAtToday() {
        let m = makeModel()
        m.leftAlignToday()
        #expect(m.math.day(m.visibleStart) == 29)
        m.next(); #expect(m.math.day(m.visibleStart) == 6)
    }
    @Test func createMoveResizeDeleteUndo() {
        let m = makeModel()
        // Drag-create on Saturday 14:00-15:00 through the same entry points the gesture uses.
        m.gridGeometry = GridGeometry(dayWidth: 180, hourHeight: 48, dayCount: 7)
        let g = m.gridGeometry
        m.gridMouseDown(CGPoint(x: 5.5 * g.dayWidth, y: g.yPos(14 * 60) + 2))
        m.gridMouseDragged(CGPoint(x: 5.5 * g.dayWidth, y: g.yPos(14 * 60 + 50)))
        m.gridMouseUp(CGPoint(x: 5.5 * g.dayWidth, y: g.yPos(14 * 60 + 50)))
        let created = m.selectedEvent
        #expect(created != nil && m.fmt.time(created!.start) == "14:00" && m.fmt.time(created!.end) == "15:00")
        #expect(m.layout.timed[5].contains { $0.event.id == created!.id })
        // Move it to Sunday 15:00.
        let id = created!.id
        m.gridMouseDown(CGPoint(x: 5.5 * g.dayWidth, y: g.yPos(14 * 60 + 20)))
        m.gridMouseDragged(CGPoint(x: 6.5 * g.dayWidth, y: g.yPos(15 * 60 + 20)))
        m.gridMouseUp(CGPoint(x: 6.5 * g.dayWidth, y: g.yPos(15 * 60 + 20)))
        let moved = m.event(id: id)!
        #expect(m.math.weekdayIndex(moved.start) == 6 && m.fmt.time(moved.start) == "15:00" && m.fmt.time(moved.end) == "16:00")
        // Resize by the bottom edge to 17:00.
        m.gridMouseDown(CGPoint(x: 6.5 * g.dayWidth, y: g.yPos(16 * 60) - 5))
        m.gridMouseDragged(CGPoint(x: 6.5 * g.dayWidth, y: g.yPos(17 * 60) + 3))
        m.gridMouseUp(CGPoint(x: 6.5 * g.dayWidth, y: g.yPos(17 * 60) + 3))
        #expect(m.fmt.time(m.event(id: id)!.end) == "17:00")
        // Undo resize, undo move, undo create.
        m.undo(); #expect(m.fmt.time(m.event(id: id)!.end) == "16:00")
        m.undo(); #expect(m.math.weekdayIndex(m.event(id: id)!.start) == 5)
        m.undo(); #expect(m.layout.timed[5].allSatisfy { $0.event.id != id })
    }
    @Test func deleteAndUndoRestores() {
        let m = makeModel()
        let ev = m.layout.timed[0].first { $0.event.title == "Chemistry Lab" }!.event
        m.select(eventID: ev.id)
        m.requestDeleteSelected()       // recurring: asks first
        #expect(m.overlay == .deleteRecurring(ev.id))
        m.delete(ev, span: .this)
        #expect(m.layout.timed[0].allSatisfy { $0.event.id != ev.id })
        m.undo()
        #expect(m.layout.timed[0].contains { $0.event.id == ev.id })
    }
    @Test func deleteAllRemovesSeries() {
        let m = makeModel()
        let ev = m.layout.timed[0].first { $0.event.title == "Chemistry Lab" }!.event
        m.delete(ev, span: .all)
        m.next()
        #expect(m.layout.timed.flatMap { $0 }.allSatisfy { $0.event.title != "Chemistry Lab" || $0.event.seriesID != ev.seriesID })
    }
    @Test func untitledDraftIsDiscardedOnDeselect() {
        let m = makeModel()
        let s = m.math.date(year: 2026, month: 10, day: 3, hour: 12)
        let e = m.createEvent(start: s, end: s.addingTimeInterval(3600))!
        m.deselect()
        #expect(m.event(id: e.id) == nil || !m.layout.timed[5].contains { $0.event.id == e.id })
        #expect(m.undoStack.isEmpty)
    }
    @Test func inspectorEditWritesThrough() {
        let m = makeModel()
        let ev = m.layout.timed[2].first { $0.event.title == "Public Policy" }!.event
        m.select(eventID: ev.id)
        m.updateSelected { $0.title = "Public Policy 2"; $0.location = "Room 5" }
        #expect(m.layout.timed[2].contains { $0.event.title == "Public Policy 2" && $0.event.location == "Room 5" })
    }
    @Test func createShortcutPicksNextFreeHalfHour() {
        let m = makeModel()
        m.handle(.createEvent)
        let e = m.selectedEvent!
        #expect(m.fmt.time(e.start) == "15:00")     // now is 11:48; 12:00-13:40 Calculus and 14:00 Sam are busy
        #expect(e.durationMinutes == 60)
    }
    @Test func hiddenCalendarsAndTeammatesAffectLayout() {
        let m = makeModel()
        let before = m.layout.timedCount
        m.toggleCalendar(DemoData.tasks)
        #expect(m.layout.timedCount < before)
        m.toggleCalendar(DemoData.tasks)
        #expect(m.layout.timedCount == before)
        m.showTeammate(m.store.teammates[0])
        #expect(m.overlayLayout.timedCount > 0)
    }
    @Test func searchFindsAcrossWeeksAndNavigates() {
        let m = makeModel()
        m.searchText = "Bike repair"
        #expect(!m.searchGroups.isEmpty)
        let hit = m.searchGroups.flatMap(\.events).first { $0.start > m.now }!
        m.openSearchResult(hit)
        #expect(m.selectedEventID == hit.id)
        #expect(m.visibleDays.contains { m.math.isSameDay($0, hit.start) })
    }
    @Test func commandFlowGoToDate() {
        let m = makeModel()
        m.handle(.goToDate)
        m.goToText = "oct 12"
        #expect(m.goToPreview != nil)
        m.submitGoToDate()
        #expect(m.overlay == nil && m.math.day(m.visibleStart) == 12)
    }
    @Test func escapeUnwindsLayers() {
        let m = makeModel()
        m.handle(.commandMenu); #expect(m.overlay == .command)
        m.handle(.escape); #expect(m.overlay == nil)
        m.select(eventID: m.layout.timed[1][0].event.id)
        m.handle(.escape); #expect(m.selectedEventID == nil)
    }
    @Test func readOnlyCalendarEventsCannotBeMovedOrEdited() {
        let m = makeModel()
        m.setMode(.week); m.go(to: m.math.date(year: 2026, month: 10, day: 3))
        let holiday = m.layout.allDayEvents.values.first { $0.title == "Tag der Deutschen Einheit" }!
        #expect(!m.isWritable(holiday))
        m.select(eventID: holiday.id)
        m.updateSelected { $0.title = "x" }
        #expect(m.selectedEvent?.title == "Tag der Deutschen Einheit")
    }
}


@MainActor
@Suite("Write paths")
struct WritePathTests {
    @Test func typingIsCoalescedIntoOneStoreWriteWhenTheStoreSyncsOverTheNetwork() {
        let store = DemoStore()
        store.coalescesTextEdits = true
        var o = LaunchOptions(); o.demo = true; o.freezeClock = true; o.now = DemoData.defaultNow
        let m = AppModel(store: store, options: o, persist: false)
        let e = m.layout.timed[1].first { $0.event.title == "Data Structures" }!.event
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
