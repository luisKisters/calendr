import Testing
import Foundation
@testable import CalendrKit

@Suite("Locale: clock style and first weekday")
struct CrossLocaleTests {
    @Test func clockStyleFollowsLocale() {
        #expect(!Fmt.uses24h(Locale(identifier: "en_US")))
        #expect(Fmt.uses24h(Locale(identifier: "de_DE")))
        #expect(Fmt.uses24h(Locale(identifier: "en_US@hours=h23")))
        #expect(!Fmt.uses24h(Locale(identifier: "de_DE@hours=h12")))
    }
    @Test func firstWeekdayIsTaken() {
        let sat = CalendarMath(timeZone: berlin.timeZone, firstWeekday: 7)
        #expect(sat.startOfWeek(d(2026, 9, 29)) == d(2026, 9, 26))
        #expect(sat.weekdayIndex(d(2026, 9, 26)) == 0)
    }
    @Test func systemMathUsesCurrentCalendar() {
        let m = CalendarMath.system
        #expect(m.timeZone == TimeZone.current)
        #expect(m.calendar.firstWeekday == Calendar.autoupdatingCurrent.firstWeekday)
    }
}
