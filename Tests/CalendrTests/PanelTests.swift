import Testing
import Foundation
import CalendrKit
@testable import Calendr

@MainActor
@Suite("Right column: Today, event fields, creating")
struct PanelTests {
    func newDraft(_ m: AppModel) -> CalendarEvent {
        let s = m.math.date(on: DemoDataV4.day(10, 1), minutes: 12 * 60)
        return m.createEvent(start: s, end: s.addingTimeInterval(3600))!
    }

    @Test func todayColumnMatchesMockup() {
        let m = makeModel()
        let t = m.panelState.today
        #expect(t.live?.title == "Test")
        #expect(t.next?.title == "[P0] Weekly review")
        #expect(t.later.first?.title == "[P1] Take vitamins")
        #expect(t.later.last?.title == "Bedtime")
        m.setNow(m.math.date(on: m.now, minutes: 23 * 60 + 30))
        #expect(m.panelState.today == PanelToday())
    }

    @Test func texts() {
        let m = makeModel()
        #expect(PanelText.day(DemoDataV4.day(9, 29), m.fmt) == "Tue 29 Sep")
        #expect(PanelText.duration(90) == "1h 30m" && PanelText.duration(60) == "1h" && PanelText.duration(45) == "45m")
        #expect(PanelText.until(12) == "in 12 min" && PanelText.until(125) == "in 2h 5m")
        #expect(PanelText.initials("Sam Okafor") == "SO" && PanelText.initials("mateo.alvarez@northwind.example.com") == "MA")
        #expect(PanelText.place("Halden College, North Campus,\n12 Example Street") == "Halden College, North Campus")
        let hours = SnapshotStates.find(m, "Office hours", day: 3)!
        #expect(PanelText.repeats(hours, m.fmt) == "Weekly on Thu")
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
        let e = SnapshotStates.find(m, "Deep work", day: 3)!       // 08:00-09:30
        m.select(eventID: e.id)
        m.setSelectedStart(TimeParser.parse("3pm")!)
        #expect(m.fmt.time(m.selectedEvent!.start) == "15:00" && m.selectedEvent!.durationMinutes == 90)
        #expect(!m.setSelectedEnd(TimeParser.parse("14")!))
        #expect(m.setSelectedEnd(TimeParser.parse("17:30")!))
        #expect(m.selectedEvent!.durationMinutes == 150)
        #expect(m.setSelectedDay("fri"))           // the next Friday after today (Sun 4 Oct)
        #expect(m.math.isSameDay(m.selectedEvent!.start, DemoDataV4.day(10, 9)))
        #expect(m.setSelectedDay("Thu 1 Oct"))
        #expect(m.math.isSameDay(m.selectedEvent!.start, DemoDataV4.day(10, 1)))
        #expect(!m.setSelectedDay("someday"))
        m.setSelectedAllDay(true)
        m.setSelectedAllDay(false)
        #expect(m.fmt.time(m.selectedEvent!.start) == "15:00" && m.fmt.time(m.selectedEvent!.end) == "17:30")
    }

    @Test func emptyRowsArePresentWithoutAddChips() {
        let m = makeModel()
        let e = SnapshotStates.find(m, "Pitch rehearsal", day: 4)!
        m.select(eventID: e.id)
        // v4: no "+ Place" chips; the empty location and notes rows are there with their placeholders
        let rows = EditorRows.rows(m.editorContext(e))
        #expect(rows.contains(.location) && rows.contains(.notes) && rows.contains(.participants) && rows.contains(.call))
        #expect(e.location.isEmpty && EditorRow.location.placeholder == "Add location")
        m.addGuest("Nina Hale")
        #expect(m.selectedEvent!.participants == ["Ines Duarte", "Lea Brandt", "Nina Hale"])
    }
}
