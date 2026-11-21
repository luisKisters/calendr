import Testing
import Foundation
@testable import CalendrKit

/// The minute model the timed layout uses (`V5Item`). The v5 algorithm and its "+N" groups are gone (mockup-v14): `OverlapV11Tests`
/// covers the layout.
@Suite("Overlap minute model")
struct OverlapV5Tests {
    @Test func fifteenMinutesOrLessIsShort() {
        #expect(V5Item(id: "x", startMinute: 0, endMinute: 15).isShort && !V5Item(id: "x", startMinute: 0, endMinute: 16).isShort)
        #expect(V5Item(id: "x", startMinute: 60, endMinute: 30).endMinute == 60)      // an end before the start is clamped
    }

    @Test func minutesOnADayAreClampedToTheDay() {
        let math = CalendarMath(timeZone: TimeZone(identifier: "Europe/Berlin")!)
        let day = math.date(year: 2026, month: 11, day: 4)
        let it = V5Item(id: "late", start: math.date(on: day, minutes: 23 * 60), end: math.date(on: math.addDays(day, 1), minutes: 30), day: day, math: math)
        #expect(it.startMinute == 23 * 60 && it.endMinute == 1440 && !it.isShort)
    }
}
