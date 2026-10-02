import Testing
import Foundation
import CalendrKit
@testable import Calendr

@MainActor
@Suite("Grid: hour scale and pointer")
struct GridTests {
    func model(viewport: Double = 700) -> AppModel {
        let m = makeModel()
        m.setGridViewport(height: viewport)
        m.gridGeometry = GridGeometry(dayWidth: 150, hourHeight: m.gridHourHeight, dayCount: 7)
        return m
    }

    @Test func fitsTheWeekFromFirstToLastEvent() {
        let m = model()
        let f = m.gridState.fit!
        #expect(f.lo == 7 * 60)                                   // Meal prep 07:30
        #expect(f.hi == 23 * 60)                                  // Evening journal 22:45 - 23:00
        #expect(abs(f.perHour - max(38, 680 / Double(f.hi - f.lo) * 60)) < 1e-9)
        #expect(m.gridHourHeight == f.perHour)
        #expect(abs(m.gridState.scrollTarget - Double(f.lo) / 60 * f.perHour) < 1e-9)
        #expect(m.layout.pointsPerHour == f.perHour)
    }

    @Test func emptyPeriodFitsNineToSix() {
        let m = model()
        m.go(to: DemoData.day(6, 7, year: 2028))
        #expect(m.gridState.fit?.lo == 9 * 60 && m.gridState.fit?.hi == 18 * 60)
        #expect(m.gridHourHeight == 680.0 / 9)
    }

    @Test func editingNeverRefits() {
        let m = model()
        let before = m.gridState.fit
        let s = m.math.date(on: m.visibleDays[2], minutes: 2 * 60)
        m.createEvent(start: s, end: s.addingTimeInterval(3600))
        m.setGridViewport(height: 600)                           // the all-day lane grew
        #expect(m.gridState.fit == before)
    }

    @Test func handSetHeightCarriesAndFitAgainForgetsIt() {
        let m = model()
        let fitted = m.gridHourHeight
        m.settings.hourHeight = 80
        m.next()
        #expect(m.gridHourHeight == 80 && m.layout.pointsPerHour == 80)
        m.previous()
        m.fitHourScale()
        #expect(m.settings.hourHeight == nil && m.gridHourHeight == fitted)
    }

    @Test func gutterZoomKeepsTheHourUnderThePointer() {
        let m = model()
        let per0 = m.gridHourHeight
        m.gridScrollY = 300
        m.gutterZoomBegan(y: 100)
        let minute = (300 + 100 - GridGeometry.pad) / per0 * 60
        m.gutterZoomChanged(y: 200)
        let per = per0 * exp(100.0 / 220)
        #expect(abs(m.gridHourHeight - per) < 1e-9 && m.settings.hourHeight == nil)
        #expect(abs(m.gridState.scrollTarget - (GridGeometry.pad + minute / 60 * per - 100)) < 1e-9)
        m.gutterZoomChanged(y: 5000)
        #expect(m.gridHourHeight == AppModel.gridMaxHourHeight)
        // Esc puts the fit back.
        #expect(m.handle(.escape))
        #expect(m.settings.hourHeight == nil && m.gridState.zoom == nil)
    }

    @Test func clickOnEmptyGridOnlyDismisses() {
        let m = model()
        let e = m.layout.timed[1].first { $0.event.title == "Genetics" }!.event
        m.select(eventID: e.id)
        let g = m.gridGeometry, count = m.layout.timedCount
        let p = CGPoint(x: 6.5 * g.dayWidth, y: g.yPos(3 * 60))
        m.gridMouseDown(p); m.gridMouseUp(p)
        #expect(m.selectedEventID == nil && m.selectedSlot == nil && m.layout.timedCount == count)
    }

    @Test func doubleClickCreatesAtTheHalfHourWithTheDefaultLength() {
        let m = model()
        m.settings.defaultDurationMinutes = 45
        let g = m.gridGeometry
        let p = CGPoint(x: 5.5 * g.dayWidth, y: g.yPos(10 * 60 + 20))
        m.gridMouseDown(p); m.gridMouseUp(p)
        m.gridMouseDown(p, clickCount: 2); m.gridMouseUp(p)
        let e = m.selectedEvent!
        #expect(m.fmt.time(e.start) == "10:00" && m.fmt.time(e.end) == "10:45")
        #expect(m.draftEventID == e.id)
        // A third quick click belongs to the same gesture and keeps the draft.
        m.gridMouseDown(p); m.gridMouseUp(p)
        #expect(m.draftEventID == e.id)
    }

    @Test func upwardDragCreates() {
        let m = model()
        let g = m.gridGeometry
        let x = 5.5 * g.dayWidth
        m.gridMouseDown(CGPoint(x: x, y: g.yPos(15 * 60 + 5)))
        m.gridMouseDragged(CGPoint(x: x, y: g.yPos(13 * 60 + 50)))
        #expect(m.gridState.pointer.minute == 13 * 60 + 45)
        m.gridMouseUp(CGPoint(x: x, y: g.yPos(13 * 60 + 50)))
        let e = m.selectedEvent!
        #expect(m.fmt.time(e.start) == "13:45" && m.fmt.time(e.end) == "15:15")
    }

    @Test func escapeCancelsADrag() {
        let m = model()
        let g = m.gridGeometry, count = m.layout.timedCount
        let x = 5.5 * g.dayWidth
        m.gridMouseDown(CGPoint(x: x, y: g.yPos(14 * 60)))
        m.gridMouseDragged(CGPoint(x: x, y: g.yPos(16 * 60)))
        #expect(m.dragPreview != nil)
        #expect(m.handle(.escape))
        m.gridMouseUp(CGPoint(x: x, y: g.yPos(16 * 60)))
        #expect(m.dragPreview == nil && m.layout.timedCount == count)
    }

    @Test func topEdgeResizesTheStart() {
        let m = model()
        let pe = m.layout.timed[1].first { $0.event.title == "Sam / Alex" }!
        let g = m.gridGeometry
        let r = g.rect(for: pe)
        let p = CGPoint(x: r.midX, y: r.minY + 2)
        guard case .event(_, _, _, _, .top?)? = m.hitTest(p) else { Issue.record("no top edge"); return }
        m.gridMouseDown(p)
        m.gridMouseDragged(CGPoint(x: r.midX, y: g.yPos(13 * 60 + 30)))
        m.gridMouseUp(CGPoint(x: r.midX, y: g.yPos(13 * 60 + 30)))
        let e = m.event(id: pe.event.id)!
        #expect(m.fmt.time(e.start) == "13:30" && m.fmt.time(e.end) == "15:00")
    }

    @Test func monthDoubleClickMakesAnAllDayDraft() {
        let m = model()
        m.setMode(.month)
        m.createAllDay(on: DemoData.day(9, 24))
        let e = m.selectedEvent!
        #expect(e.isAllDay && m.draftEventID == e.id)
    }
}
