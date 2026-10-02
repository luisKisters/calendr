import Testing
import Foundation
@testable import CalendrKit

let berlin = CalendarMath(timeZone: TimeZone(identifier: "Europe/Berlin")!)
func d(_ y: Int, _ m: Int, _ dd: Int, _ h: Int = 0, _ mi: Int = 0) -> Date { berlin.date(year: y, month: m, day: dd, hour: h, minute: mi) }
let now = d(2026, 9, 29, 2, 32)  // Tuesday

@Suite("Date math")
struct DateMathTests {
    @Test func weekStartsOnMonday() {
        #expect(berlin.startOfWeek(d(2026, 9, 29, 15)) == d(2026, 9, 28))
        #expect(berlin.startOfWeek(d(2026, 10, 4, 23, 59)) == d(2026, 9, 28))   // Sunday belongs to the week before
        #expect(berlin.startOfWeek(d(2026, 9, 28)) == d(2026, 9, 28))
    }
    @Test func sundayWeekStartOption() {
        let us = CalendarMath(timeZone: berlin.timeZone, firstWeekday: 1)
        #expect(us.startOfWeek(d(2026, 9, 29)) == d(2026, 9, 27))
    }
    @Test func miniMonthGridMatchesReference() {
        let g = berlin.monthGrid(for: d(2026, 9, 29))
        #expect(g.count == 6)
        #expect(g[0].map { berlin.day($0) } == [31, 1, 2, 3, 4, 5, 6])
        #expect(g[5].map { berlin.day($0) } == [5, 6, 7, 8, 9, 10, 11])
    }
    @Test func daysBetweenAcrossDST() {
        // Europe/Berlin leaves DST on Oct 25 2026: that day has 25 hours.
        #expect(berlin.daysBetween(d(2026, 10, 24, 23), d(2026, 10, 26, 1)) == 2)
        #expect(berlin.addDays(d(2026, 10, 24, 10), 1) == d(2026, 10, 25, 10))
    }
    @Test func snapAndSteps() {
        #expect(CalendarMath.snap(37) == 30)
        #expect(CalendarMath.snap(38) == 45)
        #expect(berlin.step(mode: .week, anchor: d(2026, 9, 29), direction: 1) == d(2026, 10, 6))
        #expect(berlin.step(mode: .month, anchor: d(2026, 12, 15), direction: 1) == d(2027, 1, 1))
        #expect(berlin.step(mode: .custom(3), anchor: d(2026, 9, 29), direction: -1) == d(2026, 9, 26))
    }
    @Test func leftAlignedWeekStartsToday() {
        #expect(berlin.visibleStart(mode: .week, anchor: d(2026, 9, 29, 12), leftAligned: true) == d(2026, 9, 29))
        #expect(berlin.visibleStart(mode: .week, anchor: d(2026, 9, 29, 12), leftAligned: false) == d(2026, 9, 28))
    }
    @Test func nextHalfHour() {
        #expect(berlin.nextHalfHour(after: d(2026, 9, 29, 10, 10)) == d(2026, 9, 29, 10, 30))
        #expect(berlin.nextHalfHour(after: d(2026, 9, 29, 10, 30)) == d(2026, 9, 29, 11, 0))
    }
}

@Suite("Overlap layout")
struct OverlapTests {
    func p(_ ps: [Placement], _ id: String) -> Placement { ps.first { $0.id == id }! }

    @Test func nonOverlappingUseFullWidth() {
        let ps = OverlapLayout.layout([TimeSpan(id: "a", startMinute: 480, endMinute: 585), TimeSpan(id: "b", startMinute: 600, endMinute: 700)])
        #expect(ps.allSatisfy { $0.left == 0 && $0.width == 1 && $0.columns == 1 })
    }
    @Test func twoOverlappingCascade() {
        let ps = OverlapLayout.layout([TimeSpan(id: "a", startMinute: 450, endMinute: 465), TimeSpan(id: "b", startMinute: 450, endMinute: 465)])
        let a = p(ps, "a"), b = p(ps, "b")
        #expect(a.left == 0 && a.z == 0)
        #expect(b.left > 0.3 && b.z == 1)               // later event is offset and on top
        #expect(abs(b.left + b.width - 1) < 1e-9)       // and reaches the right edge
        #expect(a.width < 1)
    }
    @Test func shortEventsStillCollideWhenAdjacent() {
        // 15-minute pills 10 minutes apart overlap in time.
        let ps = OverlapLayout.layout([TimeSpan(id: "a", startMinute: 1200, endMinute: 1215), TimeSpan(id: "b", startMinute: 1210, endMinute: 1225)])
        #expect(ps.allSatisfy { $0.columns == 2 })
    }
    @Test func chainReusesColumns() {
        // a overlaps b, b overlaps c, a does not overlap c: c goes back into column 0.
        let ps = OverlapLayout.layout([TimeSpan(id: "a", startMinute: 0, endMinute: 60), TimeSpan(id: "b", startMinute: 30, endMinute: 100), TimeSpan(id: "c", startMinute: 70, endMinute: 120)])
        #expect(p(ps, "c").column == 0)
        #expect(p(ps, "b").column == 1)
        #expect(ps.allSatisfy { $0.columns == 2 })
    }
    @Test func separateClustersDoNotShareColumns() {
        let ps = OverlapLayout.layout([TimeSpan(id: "a", startMinute: 0, endMinute: 60), TimeSpan(id: "b", startMinute: 30, endMinute: 60), TimeSpan(id: "c", startMinute: 300, endMinute: 400)])
        #expect(p(ps, "c").columns == 1 && p(ps, "c").width == 1)
    }
    @Test func wednesdayCluster() {
        // Climbing 16:30-18:30, Family dinner 16:30-18:30, Water the plants 18:00 pill -> three columns.
        let ps = OverlapLayout.layout([TimeSpan(id: "b", startMinute: 990, endMinute: 1110), TimeSpan(id: "f", startMinute: 990, endMinute: 1110), TimeSpan(id: "v", startMinute: 1080, endMinute: 1095)])
        #expect(ps.allSatisfy { $0.columns == 3 })
        #expect(Set(ps.map(\.column)) == [0, 1, 2])
    }
}

@Suite("All-day lanes")
struct AllDayTests {
    @Test func packsWithoutGaps() {
        // Mirrors Fri-Sun of the reference week: two 3-day banners, then one-day items fill lanes below.
        let l = AllDayPacker.pack([
            AllDayItem(id: "birthday", firstDay: 5, lastDay: 5),
            AllDayItem(id: "unity", firstDay: 5, lastDay: 5),
            AllDayItem(id: "at", firstDay: 4, lastDay: 6),
            AllDayItem(id: "away", firstDay: 4, lastDay: 6),
            AllDayItem(id: "know", firstDay: 4, lastDay: 4),
        ], dayCount: 7)
        func lane(_ id: String) -> Int { l.placements.first { $0.id == id }!.lane }
        #expect(lane("at") == 0 && lane("away") == 1 && lane("know") == 2)
        #expect(lane("birthday") == 2 && lane("unity") == 3)
        #expect(l.laneCount == 4)
    }
    @Test func clipsToVisibleRange() {
        let l = AllDayPacker.pack([AllDayItem(id: "x", firstDay: -3, lastDay: 10), AllDayItem(id: "out", firstDay: 8, lastDay: 9)], dayCount: 7)
        #expect(l.placements.count == 1)
        let x = l.placements[0]
        #expect(x.firstDay == 0 && x.lastDay == 6 && x.clippedLeft && x.clippedRight)
    }
    @Test func collapsedCountsHiddenPerDay() {
        let l = AllDayPacker.pack((0..<4).map { AllDayItem(id: "e\($0)", firstDay: 1, lastDay: 2) }, dayCount: 7)
        let c = l.collapsed(maxLanes: 2)
        #expect(c.visible.count == 2)
        #expect(c.hiddenPerDay == [0, 2, 2, 0, 0, 0, 0])
    }
}

@Suite("Range layout")
struct RangeLayoutTests {
    @Test func splitsMidnightCrossingEventAcrossDays() {
        let ev = CalendarEvent(calendarID: "c", title: "Night", start: d(2026, 9, 29, 22), end: d(2026, 9, 30, 2))
        let days = berlin.days(from: d(2026, 9, 28), count: 7)
        let l = RangeLayoutBuilder.build(events: [ev], days: days, math: berlin)
        #expect(l.timed[1].count == 1 && l.timed[1][0].startMinute == 1320 && l.timed[1][0].endMinute == 1440)
        #expect(l.timed[2].count == 1 && l.timed[2][0].startMinute == 0 && l.timed[2][0].endMinute == 120)
    }
    @Test func eventEndingAtMidnightDoesNotSpill() {
        let ev = CalendarEvent(calendarID: "c", title: "Late", start: d(2026, 9, 29, 23), end: d(2026, 9, 30, 0))
        let l = RangeLayoutBuilder.build(events: [ev], days: berlin.days(from: d(2026, 9, 28), count: 7), math: berlin)
        #expect(l.timed[2].isEmpty)
        #expect(l.timed[1][0].endMinute == 1440)
    }
    @Test func allDayEndIsExclusive() {
        let ev = CalendarEvent(calendarID: "c", title: "Trip", start: d(2026, 10, 2), end: d(2026, 10, 5), isAllDay: true)
        let l = RangeLayoutBuilder.build(events: [ev], days: berlin.days(from: d(2026, 9, 28), count: 7), math: berlin)
        #expect(l.allDay.placements[0].firstDay == 4 && l.allDay.placements[0].lastDay == 6)
    }
}

@Suite("Go to date")
struct GoToDateTests {
    func parse(_ s: String) -> Date? { GoToDateParser.parse(s, now: now, math: berlin) }
    @Test func keywords() {
        #expect(parse("today") == d(2026, 9, 29))
        #expect(parse("Tomorrow") == d(2026, 9, 30))
        #expect(parse("yesterday") == d(2026, 9, 28))
    }
    @Test func monthNames() {
        #expect(parse("oct 12") == d(2026, 10, 12))
        #expect(parse("October 12th") == d(2026, 10, 12))
        #expect(parse("12 oct") == d(2026, 10, 12))
        #expect(parse("dec 24 2027") == d(2027, 12, 24))
    }
    @Test func germanAndIso() {
        #expect(parse("12.10.") == d(2026, 10, 12))
        #expect(parse("12.10.2026") == d(2026, 10, 12))
        #expect(parse("2026-12-24") == d(2026, 12, 24))
        #expect(parse("24.12.27") == d(2027, 12, 24))
    }
    @Test func weekdays() {
        #expect(parse("friday") == d(2026, 10, 2))
        #expect(parse("next friday") == d(2026, 10, 9))     // Tue -> Friday of next calendar week
        #expect(parse("tuesday") == d(2026, 10, 6))      // the same weekday means next week
        #expect(parse("last monday") == d(2026, 9, 28))
    }
    @Test func relative() {
        #expect(parse("in 3 days") == d(2026, 10, 2))
        #expect(parse("in 2 weeks") == d(2026, 10, 13))
        #expect(parse("next week") == d(2026, 10, 5))
    }
    @Test func rejectsGarbageAndImpossibleDates() {
        #expect(parse("") == nil)
        #expect(parse("banana") == nil)
        #expect(parse("31.02.") == nil)
        #expect(parse("2026-13-01") == nil)
    }
    @Test func pastDatesRollToNextYearOnlyWhenFarBehind() {
        #expect(parse("sep 1") == d(2026, 9, 1))     // 28 days ago stays
        #expect(parse("jan 5") == d(2027, 1, 5))     // 267 days ago rolls forward
    }
}

@Suite("Commands")
struct CommandTests {
    @Test func emptyQueryKeepsTheMockupOrder() {
        let ids = CommandRegistry.matching("", hasSelection: false).map(\.id)
        #expect(ids.first == .newEvent && ids.last == .shortcuts)
        #expect(!ids.contains(.deleteSelected))
        #expect(CommandRegistry.matching("", hasSelection: true).map(\.id).contains(.deleteSelected))
    }
    @Test func contiguousMatchOutranksSubsequence() {
        #expect(CommandRegistry.matching("mont", hasSelection: false).first?.id == .viewMonth)
        #expect(CommandRegistry.matching("gtd", hasSelection: false).first?.id == .goToDate)
    }
    @Test func noMatchIsEmpty() { #expect(CommandRegistry.matching("zzzq", hasSelection: false).isEmpty) }
    @Test func keycapsMatchTheMockup() {
        #expect(CommandRegistry.all.first { $0.id == .undo }!.keys == ["\u{2318}", "Z"])
        #expect(CommandRegistry.all.first { $0.id == .goToDate }!.more)
    }
}

@Suite("Upcoming")
struct UpcomingTests {
    let fmt = Fmt(math: berlin)
    func ev(_ t: String, _ start: Date, mins: Int = 30, allDay: Bool = false, status: ResponseStatus = .confirmed) -> CalendarEvent {
        CalendarEvent(calendarID: "c", title: t, start: start, end: start.addingTimeInterval(Double(mins) * 60), isAllDay: allDay, status: status)
    }
    @Test func nextEventIsLifted() {
        let s = Upcoming.summarize(events: [
            ev("Pack gym bag", d(2026, 9, 29, 7, 30)), ev("Meal Prep", d(2026, 9, 29, 7, 30)),
            ev("Data Structures", d(2026, 9, 29, 8)), ev("Public Policy", d(2026, 9, 30, 10, 10)),
        ], now: now, fmt: fmt)
        #expect(s.next?.title == "Meal Prep")
        #expect(s.sections.map(\.title) == ["Today", "Tomorrow"])
        #expect(s.sections[0].events.map(\.title) == ["Pack gym bag", "Data Structures"])
    }
    @Test func skipsAllDayDeclinedAndPast() {
        let s = Upcoming.summarize(events: [
            ev("Holiday", d(2026, 9, 29), allDay: true), ev("Declined", d(2026, 9, 29, 9), status: .declined),
            ev("Past", d(2026, 9, 28, 9)), ev("Real", d(2026, 9, 29, 9)),
        ], now: now, fmt: fmt)
        #expect(s.next?.title == "Real")
        #expect(s.sections.isEmpty)
    }
    @Test func laterDaysUseWeekdayDate() {
        let s = Upcoming.summarize(events: [ev("A", d(2026, 10, 1, 8)), ev("B", d(2026, 10, 1, 9))], now: now, fmt: fmt)
        #expect(s.sections.map(\.title) == ["Thu Oct 1"])
    }
    @Test func noEvents() {
        let s = Upcoming.summarize(events: [], now: now, fmt: fmt)
        #expect(s.next == nil && s.sections.isEmpty)
    }
    @Test func ongoingEventIsNext() {
        let s = Upcoming.summarize(events: [ev("Now", d(2026, 9, 29, 2, 0), mins: 60)], now: now, fmt: fmt)
        #expect(s.next?.title == "Now" && s.sections.isEmpty)
    }
}

@Suite("Text formatting")
struct FormatTests {
    let fmt = Fmt(math: berlin)
    @Test func durations() {
        #expect(DurationText.minutes(100) == "1h 40min")
        #expect(DurationText.minutes(45) == "45min")
        #expect(DurationText.minutes(120) == "2h")
        #expect(DurationText.short(298) == "4h 58m")
        #expect(DurationText.short(12) == "12m")
        #expect(DurationText.short(1500) == "1d 1h")
    }
    @Test func recurrenceText() {
        let start = d(2026, 9, 30, 10, 10)
        let t = RecurrenceDescriber.describe(Recurrence(frequency: .weekly, until: d(2026, 12, 18)), start: start, fmt: fmt)
        #expect(t.lead == "Every week")
        #expect(t.rest == "on Wed until Dec 18")
        #expect(RecurrenceDescriber.describe(Recurrence(frequency: .daily), start: start, fmt: fmt).full == "Every day")
        #expect(RecurrenceDescriber.describe(Recurrence(frequency: .weekly, interval: 2, weekdays: [4, 2]), start: start, fmt: fmt).full == "Every 2 weeks on Mon, Wed")
        #expect(RecurrenceDescriber.describe(Recurrence(frequency: .weekly, weekdays: [2, 3, 4, 5, 6]), start: start, fmt: fmt).lead == "Every weekday")
    }
    @Test func timeAndDates() {
        #expect(fmt.time(d(2026, 9, 29, 7, 5)) == "07:05")
        #expect(Fmt(math: berlin, use24h: false).time(d(2026, 9, 29, 15, 5)) == "3:05 PM")
        #expect(fmt.monthTitle(d(2026, 9, 29)) == "September 2026")
        #expect(fmt.inspectorDate(d(2026, 9, 30)) == "Wed Sep 30")
        #expect(fmt.gmtLabel(d(2026, 9, 29)) == "GMT+2")
        #expect(fmt.gmtLabel(d(2026, 12, 29)) == "GMT+1")
        #expect(fmt.timeZoneCity() == "Berlin")
    }
}

@Suite("Search and undo")
struct SearchUndoTests {
    @Test func searchIsDiacriticInsensitiveAndAllWordsMustMatch() {
        let evs = [
            CalendarEvent(calendarID: "c", title: "SEND HALF-YEAR NOTES", start: d(2026, 9, 30, 7, 30), end: d(2026, 9, 30, 8)),
            CalendarEvent(calendarID: "c", title: "Calculus", start: d(2026, 9, 29, 12), end: d(2026, 9, 29, 13), location: "Room 2"),
            CalendarEvent(calendarID: "c", title: "Calculus", start: d(2026, 9, 29, 15), end: d(2026, 9, 29, 16)),
        ]
        #expect(EventSearch.search(evs, query: "half year", math: berlin).flatMap(\.events).count == 1)
        #expect(EventSearch.search(evs, query: "calculus room", math: berlin).flatMap(\.events).count == 1)
        #expect(EventSearch.search(evs, query: "calculus", math: berlin).count == 1)     // grouped in one day
        #expect(EventSearch.search(evs, query: "  ", math: berlin).isEmpty)
    }
    @Test func searchLimitKeepsEventsNearestReference() {
        let evs = (0..<50).map { CalendarEvent(calendarID: "c", title: "Daily", start: d(2026, 9, 1).addingTimeInterval(Double($0) * 86400), end: d(2026, 9, 1).addingTimeInterval(Double($0) * 86400 + 60)) }
        let g = EventSearch.search(evs, query: "daily", math: berlin, near: d(2026, 10, 15), limit: 5).flatMap(\.events)
        #expect(g.count == 5 && g.allSatisfy { $0.start >= d(2026, 10, 8) })
    }
    @Test func undoStackCapsAndPopsNewestFirst() {
        var u = UndoStack(limit: 2)
        let e = CalendarEvent(calendarID: "c", title: "x", start: now, end: now)
        u.push(.created(e)); u.push(.deleted([e])); u.push(.updated(old: e, new: e))
        #expect(u.changes.count == 2)
        if case .updated = u.pop()! {} else { Issue.record("expected updated first") }
    }
}

@Suite("EventKit mapping")
struct EventKitMappingTests {
    @Test func hexFromComponents() {
        #expect(EventKitMapping.hex(red: 1, green: 0.5, blue: 0) == "#FF8000")
        #expect(EventKitMapping.hex(red: 2, green: -1, blue: 0.2) == "#FF0033")
    }
    @Test func groupsCalendarsUnderGoogleAccountAndPutsDefaultFirst() {
        let sources = [RawSource(id: "s2", title: "Holidays", type: .subscribed),
                       RawSource(id: "s1", title: "alex@mail.example.com", type: .calDAV),
                       RawSource(id: "s0", title: "Empty", type: .calDAV)]
        let cals = [RawCalendar(id: "c2", sourceID: "s1", title: "Zeta", type: .calDAV, red: 0, green: 0, blue: 1, allowsContentModifications: true),
                    RawCalendar(id: "c1", sourceID: "s1", title: "Personal", type: .calDAV, red: 1, green: 0, blue: 0, allowsContentModifications: true),
                    RawCalendar(id: "c3", sourceID: "s2", title: "Feiertage", type: .subscription, red: 0, green: 1, blue: 0, allowsContentModifications: false)]
        let a = EventKitMapping.accounts(sources: sources, calendars: cals, defaultCalendarID: "c2")
        #expect(a.map(\.name) == ["alex@mail.example.com", "Subscribed calendars"])   // empty source dropped, subscribed last
        #expect(a[0].calendars.map(\.title) == ["Zeta", "Personal"])
        #expect(a[0].calendars[0].isDefault)
        #expect(a[1].calendars[0].icon == .feed && !a[1].calendars[0].isWritable)
    }
    @Test func readOnlyCalendarsAreNotWritable() {
        let c = RawCalendar(id: "c", sourceID: "s", title: "Shared", type: .calDAV, red: 0, green: 0, blue: 0, allowsContentModifications: false)
        let a = EventKitMapping.accounts(sources: [RawSource(id: "s", title: "iCloud", type: .mobileMe)], calendars: [c], defaultCalendarID: nil)
        #expect(a[0].calendars[0].isWritable == false)
    }
    @Test func localSourceGetsFriendlyName() {
        #expect(EventKitMapping.accountName(RawSource(id: "l", title: "Default", type: .local)) == "On My Mac")
    }
    @Test func attendeeDeclineMakesDeclinedEvenIfConfirmed() {
        #expect(EventKitMapping.responseStatus(myStatus: .declined, eventTentative: false, eventCanceled: false) == .declined)
        #expect(EventKitMapping.responseStatus(myStatus: .accepted, eventTentative: true, eventCanceled: false) == .tentative)
        #expect(EventKitMapping.responseStatus(myStatus: nil, eventTentative: false, eventCanceled: true) == .declined)
        #expect(EventKitMapping.responseStatus(myStatus: .pending, eventTentative: false, eventCanceled: false) == .confirmed)
    }
    @Test func alarmOffsets() {
        #expect(EventKitMapping.reminderMinutes(alarmOffsetSeconds: [-900, -60]) == 1)
        #expect(EventKitMapping.reminderMinutes(alarmOffsetSeconds: []) == nil)
        #expect(EventKitMapping.alarmOffsetSeconds(minutes: 10) == -600)
    }
    @Test func participantLabels() {
        #expect(EventKitMapping.participantLabel(name: "Sam", email: "sam@x.example.com") == "Sam <sam@x.example.com>")
        #expect(EventKitMapping.participantLabel(name: "max@x.de", email: "max@x.de") == "max@x.de")
        #expect(EventKitMapping.participantLabel(name: nil, email: nil) == nil)
    }
}

@Suite("Shortcuts")
struct ShortcutTests {
    func r(_ c: String, code: UInt16 = 0, cmd: Bool = false, opt: Bool = false, ctrl: Bool = false, shift: Bool = false, text: Bool = false) -> ShortcutAction? {
        ShortcutResolver.resolve(KeyInput(characters: c, keyCode: code, command: cmd, option: opt, control: ctrl, shift: shift), textFocused: text)
    }
    @Test func singleKeys() {
        #expect(r("t") == .today); #expect(r("j") == .nextPeriod); #expect(r("k") == .previousPeriod)
        #expect(r("c") == .createEvent); #expect(r("w") == .viewWeek); #expect(r(".") == .goToDate)
        #expect(r("?", shift: true) == .showShortcuts); #expect(r("`") == .toggleSidebar); #expect(r("f") == .meetWith); #expect(r("/") == .searchEvents); #expect(r("p") == nil)
        #expect(r("", code: 124) == .arrow(dx: 1, dy: 0)); #expect(r("", code: 123) == .arrow(dx: -1, dy: 0))
    }
    @Test func bareKeysAreSwallowedByTextFields() {
        #expect(r("t", text: true) == nil)
        #expect(r("c", text: true) == nil)
        #expect(r("", code: 51, text: true) == nil)   // backspace edits text, does not delete the event
    }
    @Test func commandKeysWorkWhileTyping() {
        #expect(r("k", cmd: true, text: true) == .commandMenu)
        #expect(r(",", cmd: true, text: true) == .settings)
        #expect(r("", code: 53, text: true) == .escape)
    }
    @Test func modifiedVariants() {
        #expect(r("t", opt: true) == nil)
        #expect(r("k", cmd: true, ctrl: true) == .menuBarCalendar)
        #expect(r(",", cmd: true) == .settings)
        #expect(r("1", cmd: true) == .mainWindow)
        #expect(r("z", cmd: true) == .undo)
        #expect(r("z", cmd: true, text: true) == nil)  // text field owns its own undo
        #expect(r("r", cmd: true) == .refresh)
    }
}

@Suite("Free slot")
struct FreeSlotTests {
    @Test func skipsBusyBlocks() {
        #expect(FreeSlot.next(from: 600, duration: 60, busy: [(600, 700)]) == 720)
        #expect(FreeSlot.next(from: 610, duration: 30, busy: []) == 630)
        #expect(FreeSlot.next(from: 1400, duration: 60, busy: []) == nil)
        #expect(FreeSlot.next(from: 0, duration: 30, busy: [(0, 1440)]) == nil)
    }
}

@Suite("Time parser")
struct TimeParserTests {
    @Test func formats() {
        #expect(TimeParser.parse("9") == 540); #expect(TimeParser.parse("930") == 570); #expect(TimeParser.parse("09:30") == 570)
        #expect(TimeParser.parse("9.30") == 570); #expect(TimeParser.parse("9:30 pm") == 21 * 60 + 30); #expect(TimeParser.parse("12am") == 0)
        #expect(TimeParser.parse("25:00") == nil); #expect(TimeParser.parse("abc") == nil); #expect(TimeParser.parse("13pm") == nil)
    }
}
