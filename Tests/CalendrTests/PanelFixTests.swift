import Testing
import Foundation
import CalendrKit
@testable import Calendr

@MainActor
@Suite("Panel fixes: the in-memory draft, settling, fields")
struct PanelFixTests {
    func draft(_ m: AppModel, day: Int = 1, hour: Int = 12) -> CalendarEvent {
        let s = m.math.date(on: DemoData.day(10, day), minutes: hour * 60)
        return m.createEvent(start: s, end: s.addingTimeInterval(3600))!
    }
    func inStore(_ m: AppModel, _ id: String) -> Bool {
        m.store.events(in: DateInterval(start: DemoData.day(1, 1), end: DemoData.day(1, 1, year: 2028))).contains { $0.id == id }
    }

    @Test func theDraftIsOnlyWrittenWhenSaved() {
        let m = makeModel()
        let e = draft(m)
        #expect(!inStore(m, e.id) && m.undoStack.isEmpty)
        #expect(m.event(id: e.id) == e && m.selectedEvent == e)
        #expect(m.layout.timed[3].contains { $0.event.id == e.id })
        m.updateSelected { $0.title = "Lunch" }
        m.setSelectedStart(13 * 60)
        #expect(!inStore(m, e.id))
        #expect(m.layout.timed[3].contains { $0.event.id == e.id && $0.event.title == "Lunch" && $0.startMinute == 13 * 60 })
        m.saveDraft()
        #expect(inStore(m, e.id) && m.event(id: e.id)?.title == "Lunch")
        #expect(m.layout.timed[3].contains { $0.event.id == e.id })
        m.undo()
        #expect(!inStore(m, e.id))
    }

    @Test func discardingNeverWrites() {
        let m = makeModel()
        let e = draft(m)
        m.updateSelected { $0.title = "Lunch" }
        let reloads = m.reloadCount
        m.discardDraft()
        #expect(!inStore(m, e.id) && m.undoStack.isEmpty && m.event(id: e.id) == nil)
        #expect(m.reloadCount == reloads + 1)          // a redraw, no store change
        #expect(m.layout.timed[3].allSatisfy { $0.event.id != e.id })
    }

    @Test func aSecondDraftSettlesTheFirst() {
        let m = makeModel()
        let a = draft(m)
        let b = draft(m, hour: 15)
        #expect(m.draftEventID == b.id && m.event(id: a.id) == nil && !inStore(m, a.id))
        m.updateSelected { $0.title = "Kept" }
        m.handle(.createEvent)                           // C (or Cmd-K New event) while a titled draft is open
        #expect(inStore(m, b.id) && m.event(id: b.id)?.title == "Kept")
        #expect(m.draftEventID != nil && m.draftEventID != b.id)
    }

    @Test func navigationSettlesTheDraft() {
        let m = makeModel()
        let a = draft(m)
        m.next()
        #expect(m.draftEventID == nil && !inStore(m, a.id))
        m.previous()
        let b = draft(m)
        m.updateSelected { $0.title = "Titled" }
        m.setMode(.month)
        #expect(m.draftEventID == nil && inStore(m, b.id) && m.selectedEventID == nil)
        m.setMode(.week)
        let c = draft(m)
        m.go(to: DemoData.day(11, 20))
        #expect(m.draftEventID == nil && !inStore(m, c.id))
    }

    @Test func movingTheDraftToAnotherWeekKeepsIt() {
        let m = makeModel()
        let e = draft(m)
        #expect(m.setSelectedDay("oct 14"))
        #expect(m.draftEventID == e.id && m.isDraftOpen && !inStore(m, e.id))
        #expect(m.visibleDays.contains { m.math.isSameDay($0, DemoData.day(10, 14)) })
        #expect(m.layout.timed.flatMap { $0 }.contains { $0.event.id == e.id })
    }

    @Test func whitespaceTitleIsDroppedOnClickAway() {
        let m = makeModel()
        let e = draft(m)
        m.updateSelected { $0.title = "   " }
        m.gridDismiss()
        #expect(m.draftEventID == nil && !inStore(m, e.id) && m.undoStack.isEmpty)
    }

    @Test func selectingAnotherEventSettlesTheDraft() {
        let m = makeModel()
        let e = draft(m)
        m.updateSelected { $0.title = "Titled" }
        let other = SnapshotStates.find(m, "Thursday sync", day: 3)!
        m.select(eventID: other.id)
        #expect(m.draftEventID == nil && inStore(m, e.id) && m.selectedEventID == other.id)
    }

    @Test func deleteKeyOnTheDraftDiscardsIt() {
        let m = makeModel()
        let e = draft(m)
        m.updateSelected { $0.title = "Lunch" }
        m.handle(.deleteSelection)
        #expect(m.draftEventID == nil && !inStore(m, e.id) && m.undoStack.isEmpty && m.toast == nil)
    }

    @Test func monthViewDrawsAnAllDayDraft() {
        let m = makeModel()
        m.setMode(.month)
        m.createAllDay(on: DemoData.day(9, 24))
        let id = m.draftEventID!
        #expect(m.monthEvents.contains { cell in cell.contains { $0.id == id } })
        #expect(!inStore(m, id))
    }

    @Test func coalescedTypingReachesTheGridAtOnce() {
        let store = DemoStore()
        store.coalescesTextEdits = true
        var o = LaunchOptions(); o.demo = true; o.freezeClock = true; o.now = DemoData.defaultNow
        let m = AppModel(store: store, options: o, persist: false)
        let e = m.layout.timed[1].first { $0.event.title == "Data Structures" }!.event
        m.select(eventID: e.id)
        let gen = m.layoutGeneration
        m.updateSelected { $0.title = "Span" }
        #expect(m.layout.timed[1].contains { $0.event.id == e.id && $0.event.title == "Span" })
        #expect(m.flatTimed.contains { $0.event.id == e.id && $0.event.title == "Span" })
        #expect(m.layoutGeneration > gen)
        #expect(store.events(in: DateInterval(start: e.start, end: e.end)).first { $0.id == e.id }?.title == "Data Structures")
        m.flushPendingEdit()
    }

    @Test func titleFocusNudgesStopOnceTyped() {
        let m = makeModel()
        _ = draft(m)
        #expect(m.titleFocusPending && !m.panelState.titleTyped)
        m.updateSelected { $0.title = "L" }
        #expect(m.panelState.titleTyped)
    }

    @Test func refusedTimesAndDates() {
        let m = makeModel()
        let e = SnapshotStates.find(m, "Thursday sync", day: 3)!
        m.select(eventID: e.id)
        let before = m.selectedEvent!
        #expect(TimeParser.parse("9:5") == nil && TimeParser.parse("25") == nil)
        #expect(!m.setSelectedEnd(m.math.minutesSinceMidnight(before.start)))
        #expect(!m.setSelectedDay("someday") && !m.setSelectedDay("31 Feb"))
        #expect(m.selectedEvent == before)
        #expect(m.setSelectedEnd(TimeParser.parse("24")!))
        #expect(m.selectedEvent!.end == DemoData.day(10, 2))
    }

    @Test func aDateWithoutYearKeepsTheEventsYear() {
        let m = makeModel()
        let e = SnapshotStates.find(m, "Thursday sync", day: 3)!
        m.select(eventID: e.id)
        #expect(m.setSelectedDay("2026-01-06"))
        #expect(m.setSelectedDay("Tue 13 Jan"))
        #expect(m.math.isSameDay(m.selectedEvent!.start, DemoData.day(1, 13)))
        // words still count from today
        #expect(m.setSelectedDay("tomorrow"))
        #expect(m.math.isSameDay(m.selectedEvent!.start, m.math.addDays(m.math.startOfDay(m.now), 1)))
    }

    @Test func videoLinksArePastedNotInvented() {
        #expect(PanelText.videoLink("meet.google.com/abc-defg-hij") == "https://meet.google.com/abc-defg-hij")
        #expect(PanelText.videoLink(" https://zoom.us/j/123 ") == "https://zoom.us/j/123")
        #expect(PanelText.videoLink("call me") == nil && PanelText.videoLink("zoom") == nil && PanelText.videoLink("ftp://x.com") == nil)
        let m = makeModel()
        #expect(m.canInventVideoLink)
        let e = SnapshotStates.find(m, "Thursday sync", day: 3)!
        m.select(eventID: e.id)
        #expect(!m.setVideoLink("tomorrow"))
        #expect(m.setVideoLink("zoom.us/j/42") && m.selectedEvent?.conferencing == "https://zoom.us/j/42")
    }

    @Test func todayIncludesAnEventRunningPastMidnight() {
        let m = makeModel()
        let today = m.math.startOfDay(m.now)
        let night = CalendarEvent(calendarID: "x", title: "Night shift", start: m.math.addDays(today, -1).addingTimeInterval(22 * 3600),
                                  end: today.addingTimeInterval(2 * 3600))
        let early = today.addingTimeInterval(3600)
        #expect(PanelToday.build([night], now: early, math: m.math).live == night)
        #expect(PanelToday.build([night], now: today.addingTimeInterval(3 * 3600), math: m.math) == PanelToday())
    }

    @Test func panelCountdownRoundsUp() {
        let m = makeModel()
        let next = m.panelState.today.next!
        // 11:48 now, 12:00 start
        #expect(Countdown.minutes(from: m.now, to: next.start) == 12)
        #expect(Countdown.minutes(from: m.now.addingTimeInterval(30), to: next.start) == 12)
    }

    @Test func pressesInTheSidebarAndHeaderSettle() {
        let m = makeModel()
        let size = CGSize(width: 1440, height: 900)
        func top(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: size.height - y) }
        #expect(!PanelClickAway.settles(at: top(100, 400), in: size, model: m))       // no draft
        _ = draft(m)
        #expect(PanelClickAway.settles(at: top(100, 400), in: size, model: m))        // sidebar
        #expect(PanelClickAway.settles(at: top(700, 30), in: size, model: m))         // header
        #expect(!PanelClickAway.settles(at: top(700, 400), in: size, model: m))       // grid
        #expect(!PanelClickAway.settles(at: top(1300, 30), in: size, model: m))       // panel
        m.overlay = .command
        #expect(!PanelClickAway.settles(at: top(100, 400), in: size, model: m))
    }
}
