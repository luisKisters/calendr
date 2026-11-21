import AppKit
import SwiftUI
import HorionKit

/// PR C tours (v4 Phases 4 and 5) on the v4 fixture: `v4-c-1` reply states, `v4-c-2` the "+N" stack, `v4-c-3` the all-day mix,
/// `v4-c-4` selection and the text rules.
@MainActor
extension WalkthroughV4 {
    // MARK: Helpers

    static func scrollGrid(_ d: Driver, _ m: AppModel, to y: Double) {
        m.gridState.scrollTarget = y
        m.gridState.scrollTick += 1
        d.settle(8)
    }

    /// Moves the cursor onto a block and hovers it the way the grid's hover handler does (`hitTest`, then the pointer state).
    static func hoverBlock(_ d: Driver, _ m: AppModel, _ p: PlacedEvent, yFraction: Double = 0.4) -> Bool {
        let g = Walkthrough.centerOf(d, p, yFraction: yFraction)
        d.moveCursor(to: d.windowPoint(fromGrid: g), duration: 0.45)
        d.play(0.25) {
            if case .event(let id, _, _, _, _)? = m.hitTest(g) { m.gridState.pointer.hoveredEventID = id }
        }
        return m.gridState.pointer.hoveredEventID == p.event.id
    }

    static func unhover(_ m: AppModel) {
        m.gridState.pointer.hoveredEventID = nil
    }

    static func style(_ m: AppModel, _ p: PlacedEvent) -> EventStyle {
        m.style(for: p.event, dark: true, now: m.now, selected: p.event.id == m.selectedEventID, overlapping: p.placement.over)
    }

    /// The text plan of a block as it is drawn.
    static func plan(_ m: AppModel, _ p: PlacedEvent) -> BlockTextPlan {
        let r = m.gridGeometry.rect(for: p)
        return EventPainter.plan(p, rect: r, style: style(m, p))
    }

    // MARK: v4-c-1: event styles

    /// Hover across blocks in each reply state: accepted, past next to upcoming, not answered, maybe, declined (in day view).
    static func c1(_ d: Driver, _ m: AppModel) {
        d.section("Reply states")
        d.check(m.viewMode == .week && m.math.day(m.now) == 4, "v4 fixture: the week of Sun 4 Oct")
        scrollGrid(d, m, to: SnapshotV4.defaultScroll + 4 * DemoDataV4.hourHeight)
        d.say("v4 blocks: solid fill, bar, title and time")
        d.frame(hold: 1.2)

        /// Moves onto the block first, then names the state, hovers and holds (the caption follows the cursor).
        func visit(_ title: String, day: Int, _ caption: String, _ expect: EventReply, past: Bool, yFraction: Double = 0.4, hold: Double = 1.6) {
            guard let p = Walkthrough.placed(m, title, day: day) else { d.check(false, "\(title) is on the grid"); return }
            let r = m.gridGeometry.rect(for: p)
            let probe = d.windowPoint(fromGrid: CGPoint(x: r.maxX - 4, y: r.maxY - 4))
            let before = luma(d, at: probe)
            d.moveCursor(to: d.windowPoint(fromGrid: Walkthrough.centerOf(d, p, yFraction: yFraction)), duration: 0.45)
            d.say(caption)
            let ok = hoverBlock(d, m, p, yFraction: yFraction)
            let s = style(m, p)
            d.check(ok && s.reply == expect && s.past == past, "\(title): \(expect), past \(past), hovered")
            if expect != .notAnswered && !past { d.check(luma(d, at: probe) > before, "\(title) shows the hover fill on hover") }
            else if expect != .notAnswered { d.check(abs(luma(d, at: probe) - before) < 0.003, "\(title) keeps its past fill on hover (v5: past blocks have no hover)") }
            d.hold(hold)
        }
        visit("Flat dinner", day: 6, "Accepted: fill 34 percent of the calendar colour", .accepted, past: false)
        visit("Prepare the talk", day: 5, "Past (Sat): fill and bar fade, grey text", .accepted, past: true, hold: 1.4)
        visit("Test", day: 6, "Upcoming (Sun), same calendar: full colour", .accepted, past: false, yFraction: 0.5, hold: 1.4)
        visit("Family dinner", day: 0, "Not answered: hollow, with a thin outline", .notAnswered, past: true)
        visit("Flea market", day: 5, "Maybe: stripes", .maybe, past: true)

        // Declined: Flat cleaning is a narrow block in the busy Wednesday evening; the day view gives it room.
        let wed = m.math.addDays(DemoDataV4.weekStart, 2)
        d.say("Declined, in Wednesday's day view")
        d.play(0.5) { m.go(to: wed); m.setMode(.day) }
        scrollGrid(d, m, to: SnapshotV4.eveningScroll)
        d.check(m.viewMode == .day, "day view of Wednesday")
        visit("Flat cleaning", day: 0, "Declined: solid, faded and struck through", .declined, past: true, yFraction: 0.5, hold: 0.6)
        let flat = Walkthrough.placed(m, "Flat cleaning", day: 0).map { style(m, $0).colors }
        d.check(flat?.strike == true && flat?.barAlpha == 1, "declined: struck text, the past bar (no alpha)")
        unhover(m)
        d.moveCursor(to: CGPoint(x: 1000, y: 820), duration: 0.4)
        d.hold(1.4)
        d.play(0.5) { m.setMode(.week) }
        scrollGrid(d, m, to: SnapshotV4.defaultScroll + 4 * DemoDataV4.hourHeight)
        d.check(m.viewMode == .week, "back to the week")
        d.hold(0.6)
        d.endCaption()
    }

    // MARK: v4-c-4: selection and text rules

    /// Select a block (rings), then the text rules of narrow, short and two-line blocks.
    static func c4(_ d: Driver, _ m: AppModel) {
        d.check(m.viewMode == .week && m.math.day(m.now) == 4, "v4 fixture: the week of Sun 4 Oct")
        scrollGrid(d, m, to: SnapshotV4.defaultScroll + 4 * DemoDataV4.hourHeight)
        d.frame(hold: 0.6)
        d.section("Selected")
        unhover(m)
        guard let dinner = Walkthrough.placed(m, "Flat dinner", day: 6) else { d.check(false, "Flat dinner is on Sunday"); return }
        d.moveCursor(to: d.windowPoint(fromGrid: Walkthrough.centerOf(d, dinner)), duration: 0.45)
        d.say("Selected: a ring of window colour, then fg")
        d.clickGrid(Walkthrough.centerOf(d, dinner))
        d.check(m.selectedEventID == dinner.event.id && style(m, dinner).selected, "click selects Flat dinner")
        d.hold(1.4)

        d.section("Text rules")
        if let founder = Walkthrough.placed(m, "Founder meetup", day: 2) {
            d.moveCursor(to: d.windowPoint(fromGrid: Walkthrough.centerOf(d, founder)), duration: 0.45)
            d.say("A covered block uses the part that shows: title, then the time")
            _ = hoverBlock(d, m, founder)
            let pl = plan(m, founder)
            d.check(pl.lines == .stacked && pl.time == .start, "Founder meetup: title and its start above Flat cleaning (\(pl.lines), \(pl.time))")
            d.hold(1.6)
        } else { d.check(false, "Founder meetup is on Wednesday") }
        if let task = Walkthrough.placed(m, "Wish Nina a happy birthday", day: 2) {
            d.moveCursor(to: d.windowPoint(fromGrid: Walkthrough.centerOf(d, task, yFraction: 0.5)), duration: 0.45)
            d.say("Short items: a 22 minute block, one centred line")
            _ = hoverBlock(d, m, task, yFraction: 0.5)
            let pl = plan(m, task)
            d.check(style(m, task).isShort && pl.lines == .one && pl.centered && pl.time == .none && task.placement.drawEndMinute == 9 * 60 + 22,
                    "the 09:00 task is one centred line")
            d.hold(1.4)
        } else { d.check(false, "the birthday task is on Wednesday") }
        if let research = Walkthrough.placed(m, "Research interviews", day: 1) {
            d.moveCursor(to: d.windowPoint(fromGrid: Walkthrough.centerOf(d, research)), duration: 0.45)
            d.say("Two-line titles break at a space first")
            _ = hoverBlock(d, m, research)
            let pl = plan(m, research)
            let w = m.gridGeometry.rect(for: research).width - EventPainter.textInset(dark: true) - CGFloat(BlockText.padX)
            let lines = TextCache.wrapTexts("Research interviews", .title, width: w, maxLines: pl.maxTitleLines, hyphenate: pl.hyphenate)
            d.check(pl.hyphenate && lines == ["Research", "interviews"], "Research interviews breaks at the space (\(lines.joined(separator: " | ")))")
            d.hold(1.6)
        } else { d.check(false, "Research interviews is on Tuesday") }
        unhover(m)
        d.hold(0.4)
        d.endCaption()
    }

    // MARK: v4-c-2: the cascade (v5 H; "+N" and the stack are gone, mockup-v14)

    /// v5 H: the v11 cascade. Wednesday evening shows every block (nothing is folded into "+N"): a block that starts later
    /// indents one step and is drawn on top with a 1 pt window-coloured ring, one that starts within a title line takes the right
    /// half, and a block plans its text on the part above the first block drawn over it (mockup-v14). Each block is hit where it shows.
    static func c2(_ d: Driver, _ m: AppModel) {
        d.section("Cascade")
        scrollGrid(d, m, to: SnapshotV4.eveningScroll)
        d.say("Wednesday evening: overlapping events cascade")
        d.moveCursor(to: CGPoint(x: 590, y: 380), duration: 0.6)
        d.hold(1.0)
        let titles = ["Founder meetup", "Idea session", "Flat cleaning", "[P1] Take vitamins", "Dinner break", "Club board meeting", "Project sync", "Practice quiz"]
        for t in titles {
            guard let p = Walkthrough.placed(m, t, day: 2) else { d.check(false, "\(t) is on Wednesday"); continue }
            let r = m.gridGeometry.rect(for: p)
            // The visible part of a block: its top title line, right of anything drawn above it.
            let g = CGPoint(x: r.maxX - 6, y: r.minY + 4)
            d.moveCursor(to: d.windowPoint(fromGrid: g), duration: 0.3)
            var hit: String?
            d.play(0.2) {
                if case .event(let id, _, _, _, _)? = m.hitTest(g) { hit = id; m.gridState.pointer.hoveredEventID = id }
            }
            d.check(hit == p.event.id, "\(t) shows and is hit at its title")
            d.hold(0.3)
        }
        if let idea = Walkthrough.placed(m, "Idea session", day: 2), let flat = Walkthrough.placed(m, "Flat cleaning", day: 2),
           let founder = Walkthrough.placed(m, "Founder meetup", day: 2) {
            d.say("Within a title line: the right half. Later: one indent step")
            d.check(idea.placement.left == 0.5 && flat.placement.indent == 2 * OverlapV11.indentStep && flat.placement.over,
                    "Idea session takes the right half; Flat cleaning cascades two steps")
            d.check(!founder.placement.covered && founder.placement.visibleMinutes == 60 && plan(m, founder).time != .none,
                    "Idea session beside it does not cover Founder meetup; its text uses the hour above Flat cleaning, time shown")
            d.hold(1.2)
        }
        unhover(m)
        d.endCaption()
    }

    // MARK: v4-c-3: all-day mix

    /// Hover "+N more", expand with the gutter button, scroll the expanded section, collapse.
    static func c3(_ d: Driver, _ m: AppModel) {
        d.section("All-day mix")
        let f = { m.gridState.allDayFrame }
        let dw = f().width / CGFloat(max(1, m.visibleDays.count))
        let hidden = m.layout.allDay.collapsed(maxLanes: 2).hiddenPerDay
        d.check(m.allDayFold == 2 && hidden == [0, 0, 0, 0, 2, 5, 2], "two lanes, then +N more (\(hidden))")
        d.say("All-day: two lanes, then \u{201C}+N more\u{201D}")
        d.moveCursor(to: CGPoint(x: f().minX + 3 * dw, y: f().minY + 20), duration: 0.6)
        d.hold(1.0)
        let more = AllDayView.moreRect(5, 2, dw).offsetBy(dx: f().minX, dy: f().minY)
        let moreP = CGPoint(x: more.minX + 30, y: more.midY)
        let before = luma(d, at: CGPoint(x: more.maxX - 8, y: more.midY))
        d.say("Saturday has five more")
        d.moveCursor(to: moreP, duration: 0.5)
        d.play(0.25) { m.gridState.pointer.hoveredAllDayMore = 5 }
        d.settle(4)
        d.check(luma(d, at: CGPoint(x: more.maxX - 8, y: more.midY)) > before, "+5 more shows the hover fill")
        d.hold(1.2)
        m.gridState.pointer.hoveredAllDayMore = nil

        d.section("Expand")
        // v5 I: the toggle sits under the right-aligned "all-day" label, 4 pt from the first day.
        let toggle = CGPoint(x: f().minX - (AllDayView.labelInset - 4) - Dim.iconButtonSmall / 2, y: f().minY + AllDayView.labelTop + AllDayView.labelLine + 2 + Dim.iconButtonSmall / 2)
        let collapsedH = f().height
        d.say("Expand from the gutter")
        d.clickPoint(toggle, seconds: 0.6)
        d.settle(6)
        d.check(m.gridState.allDayExpanded && m.allDayFold == nil, "the gutter button expands the section")
        let lanes = m.layout.allDay.laneCount
        d.check(abs(f().height - AllDayView.expandedHeight(lanes: lanes)) < 1.5 && f().height > collapsedH,
                "expanded: min(\(lanes), 4.5) lanes (\(Int(f().height)) pt)")
        d.hold(1.4)
        d.say("Taller than 4.5 lanes: it scrolls")
        let content = AllDayView.contentHeight(rows: lanes)
        let maxScroll = max(0, Double(content - f().height))
        d.check(maxScroll > 0, "the expanded section scrolls (\(Int(maxScroll)) pt)")
        d.moveCursor(to: CGPoint(x: f().minX + 5.5 * dw, y: f().midY), duration: 0.4)
        d.gesture(0.8) { t in
            m.gridState.allDayScrollTarget = maxScroll * t
            m.gridState.allDayScrollTick += 1
        }
        d.hold(1.2)
        d.gesture(0.6) { t in
            m.gridState.allDayScrollTarget = maxScroll * (1 - t)
            m.gridState.allDayScrollTick += 1
        }
        d.hold(0.6)

        d.section("Collapse")
        d.say("Collapse again")
        d.clickPoint(toggle, seconds: 0.6)
        d.settle(6)
        d.check(!m.gridState.allDayExpanded && m.allDayFold == 2 && abs(f().height - collapsedH) < 1.5, "collapse goes back to two lanes")
        d.hold(1.2)
        d.say("+N more expands too")
        d.clickPoint(moreP, seconds: 0.6)
        d.check(m.gridState.allDayExpanded, "+5 more expands the section")
        d.hold(1.2)
        d.clickPoint(toggle, seconds: 0.5)
        d.check(!m.gridState.allDayExpanded, "collapsed")
        d.hold(0.8)
        d.endCaption()
    }
}
