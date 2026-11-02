import Testing
import Foundation
import CalendrKit
@testable import Calendr

/// v4 Phase 5: the v5 layout in the grid, the "+N" button and its stack, the all-day mix (two lanes, "+N more", expand).
@MainActor
@Suite("Grid v5: +N stack and all-day mix")
struct GridV5Tests {
    func model() -> AppModel {
        let m = makeModelV4()
        m.gridGeometry = GridGeometry(dayWidth: 118, hourHeight: 46, dayCount: 7)
        return m
    }

    @Test func wednesdayHasOnePlusOneAt1815() {
        let m = model()
        #expect(m.layout.groups(day: 2) == [OverflowGroup(startMinute: 18 * 60 + 15, ids: ["v4.c5"])])
        let vit = m.layout.timed[2].first { $0.event.id == "v4.c5" }!
        #expect(vit.placement.hidden)
        // Hidden events are not hit: the +1 button is, above every block.
        let r = m.gridGeometry.moreRect(day: 2, group: m.layout.groups(day: 2)[0])
        #expect(m.hitTest(CGPoint(x: r.midX, y: r.midY)) == .more(dayIndex: 2, group: 0))
    }

    @Test func theStackListsTheBusyTimeInOrderWithReplies() {
        let m = model()
        let r = m.gridGeometry.moreRect(day: 2, group: m.layout.groups(day: 2)[0])
        m.gridMouseDown(CGPoint(x: r.midX, y: r.midY)); m.gridMouseUp(CGPoint(x: r.midX, y: r.midY))
        #expect(m.visibleStack?.ref.day == 2)
        let rows = m.stackRows
        #expect(rows.map(\.event.title) == ["Founder meetup", "Idea session", "Flat cleaning", "[P1] Take vitamins"])
        #expect(rows.map { EventReply($0.event).label } == [nil, "maybe", "declined", nil])
        #expect(zip(rows, rows.dropFirst()).allSatisfy { $0.startMinute <= $1.startMinute })
        m.pickFromStack(rows[2].event.id)
        #expect(m.selectedEventID == rows[2].event.id && m.gridState.stack == nil)
    }

    @Test func escAndAClickOutsideCloseTheStackAndPlusOneToggles() {
        let m = model()
        let r = m.gridGeometry.moreRect(day: 2, group: m.layout.groups(day: 2)[0])
        let chip = CGPoint(x: r.midX, y: r.midY)
        m.gridMouseDown(chip)
        #expect(m.gridState.stack != nil)
        #expect(m.handle(.escape))
        #expect(m.gridState.stack == nil)
        m.gridMouseDown(chip)
        m.gridMouseDown(chip)                                  // the open +1 again closes it
        #expect(m.gridState.stack == nil)
        m.gridMouseDown(chip)
        m.gridMouseDown(CGPoint(x: 0.5 * 118, y: m.gridGeometry.yPos(3 * 60)))
        #expect(m.gridState.stack == nil && m.selectedEventID == nil)     // the press only closes the stack
        m.gridMouseDown(chip)
        m.next()
        #expect(m.visibleStack == nil)                         // it belongs to its period
    }

    @Test func allDayHidesAllButTwoLanesPerDay() {
        let m = model()
        #expect(m.allDayFold == 2)
        #expect(m.layout.allDay.collapsed(maxLanes: 2).hiddenPerDay == [0, 0, 0, 0, 2, 5, 2])
        m.toggleAllDayExpanded()
        #expect(m.allDayFold == nil && m.gridState.allDayExpanded)
        m.toggleAllDayExpanded()
        #expect(m.allDayFold == 2)
    }

    @Test func expandedHeightIsAtMostFourAndAHalfLanes() {
        let three: CGFloat = 72, many: CGFloat = 103.5, content: CGFloat = 69   // 3 × 21 + 9, 4.5 × 21 + 9, 4 + 3 × 18 + 2 × 3 + 5
        #expect(AllDayView.expandedHeight(lanes: 3) == three)
        #expect(AllDayView.expandedHeight(lanes: 7) == many)
        #expect(AllDayView.contentHeight(rows: 3) == content)
    }
}
