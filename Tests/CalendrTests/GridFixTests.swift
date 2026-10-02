import Testing
import Foundation
import CalendrKit
@testable import Calendr

@MainActor
@Suite("Grid fixes: day list, hour height, drag cascade, month rows")
struct GridFixTests {
    func model(viewport: Double = 700) -> AppModel {
        let m = makeModel()
        m.setGridViewport(height: viewport)
        m.gridGeometry = GridGeometry(dayWidth: 150, hourHeight: m.gridHourHeight, dayCount: 7)
        return m
    }

    @Test func moreOpensTheDayListAllDayFirst() {
        let m = model()
        #expect(m.allDayFold == AllDayView.maxRows - 1)
        let sat = DemoData.day(10, 3)
        m.openDayList(sat)
        #expect(m.visibleDayList?.day == m.math.startOfDay(sat))
        let list = m.dayListEvents(sat)
        let firstTimed = list.firstIndex { !$0.isAllDay } ?? list.count
        #expect(list.count > AllDayView.maxRows)
        #expect(list[..<firstTimed].allSatisfy(\.isAllDay) && list[firstTimed...].allSatisfy { !$0.isAllDay })
        #expect(zip(list[firstTimed...], list[firstTimed...].dropFirst()).allSatisfy { $0.start <= $1.start })
    }

    @Test func escClosesTheDayListAsOneLayer() {
        let m = model()
        let e = m.layout.timed[1].first { $0.event.title == "Genetics" }!.event
        m.select(eventID: e.id)
        m.openDayList(DemoData.day(10, 3))
        #expect(m.selectedEventID == nil)           // opening settles the selection, as in the mockup
        m.select(eventID: e.id)
        #expect(m.handle(.escape))
        #expect(m.gridState.dayList == nil && m.selectedEventID == e.id)
        #expect(m.handle(.escape))
        #expect(m.selectedEventID == nil)
    }

    @Test func dayListClosesOnPickPressAndPeriodChange() {
        let m = model()
        let sat = DemoData.day(10, 3)
        m.openDayList(sat)
        let pick = m.dayListEvents(sat)[0]
        m.pickFromDayList(pick.id)
        #expect(m.visibleDayList == nil && m.selectedEventID == pick.id)
        m.openDayList(sat)
        m.gridMouseDown(CGPoint(x: 6.5 * m.gridGeometry.dayWidth, y: m.gridGeometry.yPos(3 * 60)))
        #expect(m.gridState.dayList == nil)
        m.openDayList(sat)
        m.next()
        #expect(m.visibleDayList == nil)
        _ = m.handle(.escape)                         // a list left in another period is dropped, not counted as a layer
        #expect(m.gridState.dayList == nil)
    }

    @Test func dayListHangsBelowItsMoreAndStaysInside() {
        let m = model()
        m.gridState.allDayFrame = CGRect(x: 300, y: 100, width: 700, height: 72)
        let a = m.dayListAnchor(GridDayList(day: DemoData.day(10, 3), period: m.periodID))!
        #expect(a == CGRect(x: 300 + 5 * 100 + 1, y: 100 + 2 * AllDayView.row, width: 97, height: 21))
        let size = CGSize(width: GridDayListPopover.width, height: 200)
        let below = GridDayListHost.origin(anchor: CGRect(x: 40, y: 50, width: 90, height: 21), size: size, in: CGSize(width: 900, height: 700))
        #expect(below == CGPoint(x: 40, y: 77))
        let flipped = GridDayListHost.origin(anchor: CGRect(x: 800, y: 600, width: 90, height: 21), size: size, in: CGSize(width: 900, height: 700))
        #expect(flipped == CGPoint(x: 900 - 286 - 10, y: 600 - 200 - 6))
    }

    @Test func monthMoreOpensTheDayListForThatCell() {
        let m = makeModel()
        m.setMode(.month)
        let lay = m.gridState.monthCache.layout(for: m, size: CGSize(width: 1000, height: 500))
        #expect(m.gridState.monthCache.layout(for: m, size: CGSize(width: 1000, height: 500)).items.count == lay.items.count)
        guard let more = lay.items.first(where: { $0.kind == .more }) else { Issue.record("no n more at this size"); return }
        m.gridState.monthFrame = CGRect(x: 10, y: 20, width: 1000, height: 500)
        m.openDayList(more.day)
        #expect(m.dayListAnchor(m.visibleDayList!) == more.rect.offsetBy(dx: 10, dy: 20))
        let idx = m.visibleDays.firstIndex { m.math.isSameDay($0, more.day) }!
        #expect(m.dayListEvents(more.day).count == m.monthEvents[idx].count)
    }

    @Test func monthHeadersFollowTheGridsFirstWeekday() {
        let m = makeModel()
        m.setMode(.month)
        #expect(m.math.calendar.component(.weekday, from: m.monthGrid[0][0]) == m.math.calendar.firstWeekday)
    }

    @Test func gutterDragWritesTheSettingsOnceAndEscRestores() {
        let m = model()
        let fitted = m.gridHourHeight
        m.gutterZoomBegan(y: 100)
        m.gutterZoomChanged(y: 200)
        #expect(m.settings.hourHeight == nil && m.gridHourHeight > fitted && m.layout.pointsPerHour == m.gridHourHeight)
        let live = m.gridHourHeight
        m.gutterZoomEnded()
        #expect(m.settings.hourHeight == live && m.gridHourHeight == live)
        m.gutterZoomBegan(y: 100)
        m.gutterZoomChanged(y: 0)
        #expect(m.handle(.escape))
        #expect(m.settings.hourHeight == live && m.gridHourHeight == live && m.layout.pointsPerHour == live)
    }

    @Test func savedHourHeightIsClamped() {
        let m = model()
        let fitted = m.gridState.fit!.perHour
        m.settings.hourHeight = 0
        #expect(m.gridHourHeight == fitted)
        m.settings.hourHeight = .nan
        #expect(m.gridHourHeight == fitted)
        m.settings.hourHeight = 900
        #expect(m.gridHourHeight == AppModel.gridMaxHourHeight)
        m.settings.hourHeight = 5
        #expect(m.gridHourHeight == AppModel.gridMinHourHeight)
    }

    @Test func handSetHeightKeepsTheScrollAcrossPeriods() {
        let m = model()
        m.settings.hourHeight = 80
        m.reload()
        let tick = m.gridState.scrollTick
        m.next()
        #expect(m.gridState.scrollTick == tick)
        m.setMode(.day)
        #expect(m.gridState.scrollTick > tick)       // a new view opens on the fit
        m.fitHourScale()
        let fitted = m.gridState.scrollTick
        m.next()
        #expect(m.gridState.scrollTick > fitted)     // fitted: every period opens on its fit
    }

    @Test func dragPreviewRecascadesTheDaysItTouches() {
        let m = model()
        let mon = m.layout.timed[0].first { $0.event.title == "Statistics" }!
        let thu = m.layout.timed[3].first { $0.event.title == "Statistics" }!
        #expect(thu.placement.columns == 1)
        m.dragPreview = AppModel.DragPreview(kind: .move, eventID: mon.event.id, dayIndex: 3, startMinute: thu.startMinute, endMinute: thu.endMinute)
        let r = m.gridPreviewLayout()
        #expect(r.preview?.placement.columns == 2 && r.preview?.dayIndex == 3)
        #expect(r.events.first { $0.id == thu.id }?.placement.columns == 2)
        #expect(!r.events.contains { $0.event.id == mon.event.id })
        #expect(r.events.count == m.flatTimed.count - 1)
        m.dragPreview = nil
        #expect(m.gridPreviewLayout().preview == nil)
    }

    @Test func monthBarHidesWhereAnyDayOfItsSpanIsFull() {
        // Day 1 is full (its last row becomes "n more"), so the lane-2 bar across days 0 and 1 hides on both.
        let bar = AllDayPlacement(id: "b", lane: 2, firstDay: 0, lastDay: 1, clippedLeft: false, clippedRight: false)
        let room = MonthLayout.rooms(fit: 3, used: [3, 3, 0], timed: [0, 1, 0], bars: [bar])
        #expect(room == [2, 2, 3])
        #expect(!MonthLayout.fits(bar, room))
    }
}
