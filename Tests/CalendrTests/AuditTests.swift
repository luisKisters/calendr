import Testing
import Foundation
import CalendrKit
@testable import Calendr

@MainActor
@Suite("DMG audit time boundaries")
struct AuditTests {
    @Test func allDayRoundTripPreservesMidnightAndOvernightTimes() {
        for days in [1, 2] {
            let m = makeModel()
            let start = m.math.date(year: 2026, month: 10, day: 1, hour: 22)
            let end = m.math.date(year: 2026, month: 10, day: 1 + days)
            m.createEvent(start: start, end: end)
            m.setSelectedAllDay(true)
            m.setSelectedAllDay(false)
            #expect(m.selectedEvent?.start == start)
            #expect(m.selectedEvent?.end == end)
        }
    }

    @Test func allDayRoundTripPreservesTheRepeatedHourOccurrence() {
        let m = makeModel()
        let first = m.math.date(year: 2026, month: 10, day: 25, hour: 2, minute: 30)
        let start = first.addingTimeInterval(3600) // second 02:30, after the clocks go back
        let end = start.addingTimeInterval(3600)
        m.createEvent(start: start, end: end)
        m.setSelectedAllDay(true)
        m.setSelectedAllDay(false)
        #expect(m.selectedEvent?.start == start)
        #expect(m.selectedEvent?.end == end)
    }

    @Test func noFreeTimeDoesNotCreateInThePast() {
        let m = makeModel()
        m.setNow(m.math.date(year: 2026, month: 9, day: 29, hour: 23, minute: 45))
        m.createAtNextFreeSlot()
        #expect(m.draft == nil)
        #expect(m.toast?.text == "No free slot left today")
    }

    @Test func ongoingOvernightEventBlocksMorningSlots() throws {
        let m = makeModel()
        let day = m.math.startOfDay(m.now)
        let shift = CalendarEvent(calendarID: DemoData.personal, title: "Overnight on-call shift",
                                  start: m.math.addDays(day, -1).addingTimeInterval(22 * 3600), end: day.addingTimeInterval(6 * 3600))
        try m.store.create(shift)
        m.setNow(day.addingTimeInterval(30 * 60))
        m.createAtNextFreeSlot()
        #expect(m.draft!.start >= shift.end)
    }
}
