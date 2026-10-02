import Testing
import Foundation
@testable import CalendrKit

@Suite("Chrome fixes: go to date as typed")
struct ChromeGoToDateFixTests {
    func parse(_ s: String) -> Date? { GoToDateParser.parse(s, now: now, math: berlin) }   // now: Tue 29 Sep 2026

    @Test func prefixesParseWhileTyping() {
        #expect(parse("fr") == d(2026, 10, 2))
        #expect(parse("mo") == d(2026, 10, 5))
        #expect(parse("thurs") == d(2026, 10, 1))
        #expect(parse("octob 12") == d(2026, 10, 12))
        #expect(parse("12 nov") == d(2026, 11, 12))
        #expect(parse("oct. 12") == d(2026, 10, 12))
        #expect(parse("f") == nil)       // one letter is not a weekday yet
        #expect(parse("oc 12") == nil)   // two letters are not a month yet
    }

    @Test func weekdaysFollowTheMockup() {
        #expect(parse("tu") == d(2026, 10, 6))           // today's weekday: next week
        #expect(parse("this friday") == d(2026, 10, 2))
        #expect(parse("this monday") == d(2026, 9, 28))  // this week's, even though it has passed
        #expect(parse("next friday") == d(2026, 10, 9))
        #expect(parse("last tuesday") == d(2026, 9, 22))
    }

    @Test func yearlessDatesRollOverAfterAMonth() {
        #expect(parse("29.8.") == d(2026, 8, 29))   // 31 days ago stays
        #expect(parse("28.8.") == d(2027, 8, 28))   // 32 days ago rolls to next year
        #expect(parse("aug 1") == d(2027, 8, 1))
        #expect(parse("september") == d(2026, 9, 1))
        #expect(parse("may") == d(2027, 5, 1))
        #expect(parse("october 2027") == d(2027, 10, 1))
    }
}

@Suite("Chrome fixes: keyboard selection")
struct ChromeKeyboardFixTests {
    func ev(_ id: String, _ day: Int, _ h: Int, _ mins: Int = 60, allDay: Bool = false) -> CalendarEvent {
        let s = allDay ? d(2026, 9, day) : d(2026, 9, day, h)
        return CalendarEvent(id: id, calendarID: "c", title: id, start: s, end: allDay ? berlin.addDays(s, 1) : s.addingTimeInterval(Double(mins) * 60), isAllDay: allDay)
    }

    @Test func shortcutsResolve() {
        func r(_ code: UInt16, opt: Bool = false, shift: Bool = false, text: Bool = false) -> ShortcutAction? {
            ShortcutResolver.resolve(KeyInput(characters: "", keyCode: code, option: opt, shift: shift), textFocused: text)
        }
        #expect(r(126) == .arrow(dx: 0, dy: -1)); #expect(r(125) == .arrow(dx: 0, dy: 1))
        #expect(r(123, opt: true) == .nudge(dx: -1, dy: 0)); #expect(r(125, opt: true) == .nudge(dx: 0, dy: 1))
        #expect(r(48) == .selectNext); #expect(r(48, shift: true) == .selectPrevious)
        #expect(r(36) == .editTitle)
        #expect(r(48, text: true) == nil); #expect(r(36, text: true) == nil); #expect(r(124, opt: true, text: true) == nil)
    }

    @Test func tabStartsAtTheNextEventAndWraps() {
        let list = [ev("b", 29, 9), ev("a", 28, 10), ev("all", 29, 0, allDay: true), ev("c", 30, 8)]
        let at = d(2026, 9, 29, 8)
        #expect(KeyboardSelection.tabOrder(list, math: berlin).map(\.id) == ["a", "all", "b", "c"])
        #expect(KeyboardSelection.tab(from: nil, in: list, now: at, direction: 1, math: berlin)?.id == "all")
        #expect(KeyboardSelection.tab(from: nil, in: list, now: at, direction: -1, math: berlin)?.id == "a")
        #expect(KeyboardSelection.tab(from: "c", in: list, now: at, direction: 1, math: berlin)?.id == "a")
        #expect(KeyboardSelection.tab(from: "a", in: list, now: at, direction: -1, math: berlin)?.id == "c")
    }

    @Test func arrowsWalkNeighbours() {
        let x = ev("x", 29, 10), list = [ev("up", 29, 8), x, ev("down", 29, 14), ev("far", 30, 18), ev("near", 30, 11), ev("week", 22, 10)]
        #expect(KeyboardSelection.neighbour(of: x, in: list, dx: 0, dy: -1, math: berlin)?.id == "up")
        #expect(KeyboardSelection.neighbour(of: x, in: list, dx: 0, dy: 1, math: berlin)?.id == "down")
        #expect(KeyboardSelection.neighbour(of: x, in: list, dx: 1, dy: 0, math: berlin)?.id == "near")
        #expect(KeyboardSelection.neighbour(of: x, in: list, dx: -1, dy: 0, math: berlin)?.id == "week")   // the closest day with one, up to a week back
        #expect(KeyboardSelection.neighbour(of: list[0], in: list, dx: 0, dy: -1, math: berlin) == nil)
    }

    @Test func nudgeStaysInsideTheDay() {
        let e = ev("e", 29, 23)
        #expect(KeyboardSelection.nudged(e, days: 0, minutes: 15, math: berlin) == nil)
        #expect(KeyboardSelection.nudged(e, days: 0, minutes: -15, math: berlin)?.start == d(2026, 9, 29, 22, 45))
        #expect(KeyboardSelection.nudged(e, days: 1, minutes: 0, math: berlin)?.start == d(2026, 9, 30, 23))
        let a = ev("a", 29, 0, allDay: true)
        #expect(KeyboardSelection.nudged(a, days: -1, minutes: 0, math: berlin).map { ($0.start, $0.end) } ?? (.distantPast, .distantPast) == (d(2026, 9, 28), d(2026, 9, 29)))
        #expect(KeyboardSelection.nudged(a, days: 0, minutes: 15, math: berlin) == nil)
    }
}
