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

    // Review fixes

    @Test func anOverflowingDraftShowsOnTheRightHalfAndIsHitOnlyThere() {
        let m = model()
        let wed = m.math.addDays(DemoDataV4.weekStart, 2)
        let s = m.math.date(on: wed, minutes: 17 * 60 + 30)
        m.createEvent(start: s, end: s.addingTimeInterval(3600))
        let id = m.draftEventID!
        let p = m.layout.timed[2].first { $0.event.id == id }!
        #expect(!p.placement.hidden && p.placement.left == 0.5 && p.placement.width == 0.5)
        #expect(!m.layout.groups(day: 2).contains { $0.ids.contains(id) })
        let r = m.gridGeometry.rect(for: p)
        if case .event(let hit, _, _, _, _)? = m.hitTest(CGPoint(x: r.midX, y: r.midY)) { #expect(hit == id) } else { Issue.record("the draft is not hit") }
        let left = CGPoint(x: 2 * 118 + 10, y: r.midY)
        if case .event(let hit, _, _, _, _)? = m.hitTest(left) { #expect(hit != id) }
    }

    @Test func theStackClosesWhenThePeriodOrViewChanges() {
        let m = model()
        m.toggleStack(day: 2, group: 0)
        m.next()
        #expect(m.gridState.stack == nil)
        m.previous()
        m.toggleStack(day: 2, group: 0)
        m.setMode(.day)
        #expect(m.gridState.stack == nil)
    }

    @Test func aClickOutsideTheGridAndTheStackClosesIt() {
        let m = model()
        m.toggleStack(day: 2, group: 0)
        let size = CGSize(width: 1440, height: 900)
        m.gridViewport = CGRect(x: 236, y: 160, width: 884, height: 740)
        m.gridState.stackBox.frame = CGRect(x: 530, y: 600, width: 228, height: 130)
        func bl(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: size.height - y) }   // window points, bottom-left origin
        #expect(PanelClickAway.closesStack(at: bl(100, 500), in: size, model: m))             // the sidebar
        #expect(!PanelClickAway.closesStack(at: bl(600, 650), in: size, model: m))            // inside the stack
        #expect(!PanelClickAway.closesStack(at: bl(400, 400), in: size, model: m))            // the grid handles its own presses
        m.closeStack()
        #expect(!PanelClickAway.closesStack(at: bl(100, 500), in: size, model: m))
    }

    @Test func theCreatePreviewLaysOutLikeTheSavedEvent() {
        let m = model()
        let g = m.gridGeometry
        let a = CGPoint(x: 0.3 * g.dayWidth, y: g.yPos(21 * 60) + 2), b = CGPoint(x: 0.3 * g.dayWidth, y: g.yPos(22 * 60))
        m.gridMouseDown(a)
        m.gridMouseDragged(b)
        let r = m.gridPreviewLayout()
        let walkID = m.layout.timed[0].first { $0.event.title == "Evening walk" }!.id
        let previewWalk = r.events.first { $0.id == walkID }!.placement
        let ghost = r.preview!.placement
        // 60 minutes, not a zero-length short item: the walk 30 minutes later cascades over it (a short ghost would sit beside it).
        #expect(ghost.drawEndMinute == 22 * 60 && ghost.width == 1 && previewWalk.level == 1 && previewWalk.indent == OverlapV5.indentStep)
        m.gridMouseUp(b)
        let saved = m.layout.timed[0].first { $0.event.id == m.draftEventID }!.placement
        let walk = m.layout.timed[0].first { $0.id == walkID }!.placement
        #expect(saved.left == ghost.left && saved.width == ghost.width && saved.level == ghost.level && saved.indent == ghost.indent)
        #expect(walk.left == previewWalk.left && walk.width == previewWalk.width)
    }

    @Test func theSelectedAllDayEventIsNeverFolded() {
        let m = model()
        let low = m.layout.allDay.placements.first { $0.lane >= 2 }!
        m.select(eventID: low.id)
        #expect(m.allDayFold == nil)
        m.deselect()
        #expect(m.allDayFold == 2)
    }
}
