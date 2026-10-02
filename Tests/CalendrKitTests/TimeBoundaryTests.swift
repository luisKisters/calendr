import Testing
import Foundation
import CalendrKit

@Suite("Wall clock dates at DST boundaries")
struct TimeBoundaryTests {
    @Test(arguments: [("Europe/Berlin", 3, 29), ("Europe/Berlin", 10, 25),
                      ("America/New_York", 3, 8), ("America/New_York", 11, 1)])
    func slotsKeepTheirWallClockTime(zone: String, month: Int, day: Int) {
        let math = CalendarMath(timeZone: TimeZone(identifier: zone)!)
        let date = math.date(year: 2026, month: month, day: day)
        let slot = math.date(on: date, minutes: 9 * 60 + 30)
        #expect(math.minutesSinceMidnight(slot) == 9 * 60 + 30)
        #expect(math.isSameDay(slot, date))
        #expect(math.date(on: date, minutes: 1440) == math.addDays(date, 1))
    }

    @Test func normalizedOffsetsAndMissingHour() {
        let math = CalendarMath()
        let spring = math.date(year: 2026, month: 3, day: 29)
        #expect(math.date(on: spring, minutes: 150) == math.date(year: 2026, month: 3, day: 29, hour: 3))
        #expect(math.date(on: spring, minutes: -30) == math.date(year: 2026, month: 3, day: 28, hour: 23, minute: 30))
        #expect(math.date(on: spring, minutes: 1500) == math.date(year: 2026, month: 3, day: 30, hour: 1))
        let fall = math.date(year: 2026, month: 10, day: 25)
        #expect(math.date(on: fall, minutes: 150) == fall.addingTimeInterval(150 * 60)) // first 02:30
    }
}
