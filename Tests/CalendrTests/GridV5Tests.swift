import Testing
import Foundation
import CalendrKit
@testable import Calendr

/// The v11 cascade in the grid (v5 H: nothing is folded into "+N" any more) and the all-day mix (two lanes, "+N more", expand).
@MainActor
@Suite("Grid: v11 cascade and all-day mix")
struct GridV5Tests {
    func model() -> AppModel {
        let m = makeModelV4()
        m.gridGeometry = GridGeometry(dayWidth: 118, hourHeight: 46, dayCount: 7)
        return m
    }

    /// v5 H: the v11 cascade folds nothing into "+N" (mockup-v11 `cascade`): every block of the busy Wednesday evening shows.
    @Test func wednesdayEveningCascades() {
        let m = model()
        let wed = m.layout.timed[2]
        func p(_ t: String) -> Placement { wed.first { $0.event.title == t }!.placement }
        // Founder meetup 17:00 is the base; Idea session 17:15 starts within one title line, so it takes the right half.
        #expect(p("Founder meetup").indent == 0 && !p("Founder meetup").over && p("Founder meetup").width == 0.5)
        #expect(p("Idea session").left == 0.5 && p("Idea session").over)
        // Flat cleaning 18:00 runs over both: one more cascade step.
        #expect(p("Flat cleaning").indent == 2 * OverlapV11.indentStep && p("Flat cleaning").over)
        // Idea session sits beside Founder meetup, so it does not cover it (mockup-v14); Flat cleaning at 18:00 does, an hour in,
        // so Founder meetup plans its text on that hour.
        #expect(!p("Founder meetup").covered && p("Founder meetup").visibleMinutes == 60)
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
        // v11 lanes: 19 pt chips + 3 pt (22 pt), 3 pt above the first, 8 pt below the last (the mockup's 52 pt lane for two rows).
        let three: CGFloat = 75, many: CGFloat = 108, content: CGFloat = 74   // 3 × 22 + 9, 4.5 × 22 + 9, 3 + 3 × 19 + 2 × 3 + 8
        #expect(AllDayView.expandedHeight(lanes: 3) == three)
        #expect(AllDayView.expandedHeight(lanes: 7) == many)
        #expect(AllDayView.contentHeight(rows: 3) == content)
        #expect(AllDayView.contentHeight(rows: 2) == 52)
    }

    // Review fixes

    @Test func aDraftInABusyEveningCascadesAndIsHit() {
        let m = model()
        let wed = m.math.addDays(DemoDataV4.weekStart, 2)
        let s = m.math.date(on: wed, minutes: 17 * 60 + 30)
        m.createEvent(start: s, end: s.addingTimeInterval(3600))
        let id = m.draftEventID!
        let p = m.layout.timed[2].first { $0.event.id == id }!
        #expect(p.placement.over)
        let r = m.gridGeometry.rect(for: p)
        if case .event(let hit, _, _, _, _)? = m.hitTest(CGPoint(x: r.midX, y: r.midY)) { #expect(hit == id) } else { Issue.record("the draft is not hit") }
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
        #expect(ghost.drawEndMinute == 22 * 60 && ghost.width == 1 && previewWalk.indent == OverlapV11.indentStep)
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
