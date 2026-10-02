import Testing
import Foundation
import CalendrKit
@testable import Calendr

@MainActor
@Suite("Right column: Today, event fields, creating")
struct PanelTests {
    func newDraft(_ m: AppModel) -> CalendarEvent {
        let s = m.math.date(on: DemoData.day(10, 1), minutes: 12 * 60)
        return m.createEvent(start: s, end: s.addingTimeInterval(3600))!
    }

    @Test func todayColumnMatchesMockup() {
        let m = makeModel()
        let t = m.panelState.today
        #expect(t.live?.title == "Genetics")
        #expect(t.next?.title == "Calculus")
        #expect(t.later.first?.title == "Sam / Alex")
        #expect(t.later.last?.title == "Evening journal")
        m.setNow(m.math.date(on: m.now, minutes: 23 * 60 + 30))
        #expect(m.panelState.today == PanelToday())
    }

    @Test func texts() {
        let m = makeModel()
        #expect(PanelText.day(DemoData.day(9, 29), m.fmt) == "Tue 29 Sep")
        #expect(PanelText.duration(90) == "1h 30m" && PanelText.duration(60) == "1h" && PanelText.duration(45) == "45m")
        #expect(PanelText.until(12) == "in 12 min" && PanelText.until(125) == "in 2h 5m")
        #expect(PanelText.initials("Sam Okafor") == "SO" && PanelText.initials("mateo.alvarez@northwind.example.com") == "MA")
        #expect(PanelText.place("Halden College, North Campus,\n12 Example Street") == "Halden College, North Campus")
        let sam = SnapshotStates.find(m, "Sam / Alex", day: 1)!
        #expect(PanelText.repeats(sam, m.fmt) == "Weekly on Tue")
    }

    @Test func returnSavesTheDraft() {
        let m = makeModel()
        let e = newDraft(m)
        #expect(m.isDraftOpen)
        m.updateSelected { $0.title = "Lunch" }
        #expect(m.layout.timed[3].contains { $0.event.title == "Lunch" })
        m.saveDraft()
        #expect(m.draftEventID == nil && m.selectedEventID == nil)
        #expect(m.event(id: e.id)?.title == "Lunch")
    }

    @Test func untitledSaveIsNewEvent() {
        let m = makeModel()
        let e = newDraft(m)
        m.saveDraft()
        #expect(m.event(id: e.id)?.title == "New event")
    }

    @Test func escapeDiscardsEvenWithTitle() {
        let m = makeModel()
        let e = newDraft(m)
        m.updateSelected { $0.title = "Lunch" }
        m.handle(.escape)
        #expect(m.draftEventID == nil && m.selectedEventID == nil)
        #expect(m.event(id: e.id) == nil)
        #expect(m.undoStack.isEmpty)
    }

    @Test func clickingElsewhereKeepsTitledDropsUntitled() {
        let m = makeModel()
        let a = newDraft(m)
        m.updateSelected { $0.title = "Kept" }
        m.deselect()
        #expect(m.draftEventID == nil && m.event(id: a.id)?.title == "Kept")
        let b = newDraft(m)
        m.deselect()
        #expect(m.draftEventID == nil && m.event(id: b.id) == nil)
    }

    @Test func timeAndDateFields() {
        let m = makeModel()
        let e = SnapshotStates.find(m, "Thursday sync", day: 3)!
        m.select(eventID: e.id)
        m.setSelectedStart(TimeParser.parse("3pm")!)
        #expect(m.fmt.time(m.selectedEvent!.start) == "15:00" && m.selectedEvent!.durationMinutes == 90)
        #expect(!m.setSelectedEnd(TimeParser.parse("14")!))
        #expect(m.setSelectedEnd(TimeParser.parse("17:30")!))
        #expect(m.selectedEvent!.durationMinutes == 150)
        #expect(m.setSelectedDay("fri"))
        #expect(m.math.isSameDay(m.selectedEvent!.start, DemoData.day(10, 2)))
        #expect(m.setSelectedDay("Thu 1 Oct"))
        #expect(m.math.isSameDay(m.selectedEvent!.start, DemoData.day(10, 1)))
        #expect(!m.setSelectedDay("someday"))
        m.setSelectedAllDay(true)
        m.setSelectedAllDay(false)
        #expect(m.fmt.time(m.selectedEvent!.start) == "15:00" && m.fmt.time(m.selectedEvent!.end) == "17:30")
    }

    @Test func addChipsShowEmptyRows() {
        let m = makeModel()
        let e = SnapshotStates.find(m, "Sam / Alex", day: 1)!
        m.select(eventID: e.id)
        #expect(!m.panelShows(.place, e) && m.panelShows(.guests, e) && m.panelShows(.video, e))
        m.addPanelField(.place)
        #expect(m.panelShows(.place, m.selectedEvent!))
        m.addGuest("Maya Sterling")
        #expect(m.selectedEvent!.participants == ["Sam Okafor", "Maya Sterling"])
    }
}
