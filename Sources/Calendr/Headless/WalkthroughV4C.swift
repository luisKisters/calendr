import AppKit
import SwiftUI
import CalendrKit

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
        m.gridState.pointer.hoveredMore = nil
        m.gridState.pointer.hoveredStackRow = nil
    }

    static func style(_ m: AppModel, _ p: PlacedEvent) -> EventStyle {
        m.style(for: p.event, dark: true, now: m.now, selected: p.event.id == m.selectedEventID, overlapping: p.placement.over)
    }

    /// The text plan of a block as it is drawn.
    static func plan(_ m: AppModel, _ p: PlacedEvent) -> BlockTextPlan {
        let r = m.gridGeometry.rect(for: p)
        return BlockText.plan(height: Double(r.height), width: Double(r.width), isShort: style(m, p).isShort)
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
            if expect != .notAnswered { d.check(luma(d, at: probe) > before, "\(title) brightens on hover (mockup brightness 1.12)") }
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
        d.check(flat?.strike == true && flat?.barAlpha == 0.45, "declined: struck text, bar at .45")
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
            d.say("Narrow blocks: one title line with an ellipsis, start time only")
            _ = hoverBlock(d, m, founder)
            let pl = plan(m, founder)
            d.check(pl.narrow && pl.maxTitleLines == 1 && pl.time == .start, "Founder meetup is narrow: one line, start time")
            d.hold(1.6)
        } else { d.check(false, "Founder meetup is on Wednesday") }
        if let task = Walkthrough.placed(m, "Wish Nina a happy birthday", day: 2) {
            d.moveCursor(to: d.windowPoint(fromGrid: Walkthrough.centerOf(d, task, yFraction: 0.5)), duration: 0.45)
            d.say("Short items: a 22 minute block, one row")
            _ = hoverBlock(d, m, task, yFraction: 0.5)
            let pl = plan(m, task)
            d.check(style(m, task).isShort && pl.lines == .one && pl.time == .start && task.placement.drawEndMinute == 9 * 60 + 22, "the 09:00 task is one row with its start")
            d.hold(1.4)
        } else { d.check(false, "the birthday task is on Wednesday") }
        if let research = Walkthrough.placed(m, "Research interviews", day: 1) {
            d.moveCursor(to: d.windowPoint(fromGrid: Walkthrough.centerOf(d, research)), duration: 0.45)
            d.say("Two-line titles break at syllables")
            _ = hoverBlock(d, m, research)
            let pl = plan(m, research)
            let w = m.gridGeometry.rect(for: research).width - 17
            let lines = TextCache.wrapTexts("Research interviews", .title, width: w, maxLines: pl.maxTitleLines, hyphenate: pl.hyphenate)
            d.check(pl.hyphenate && lines.first?.hasSuffix("-") == true, "Research interviews hyphenates (\(lines.joined(separator: " | ")))")
            d.hold(1.6)
        } else { d.check(false, "Research interviews is on Tuesday") }
        unhover(m)
        d.hold(0.4)
        d.endCaption()
    }

    // MARK: v4-c-2: "+N" and the stack

    static func moreWindowPoint(_ d: Driver, _ m: AppModel, day: Int, group: Int) -> (grid: CGPoint, window: CGPoint)? {
        let groups = m.layout.groups(day: day)
        guard groups.indices.contains(group) else { return nil }
        let r = m.gridGeometry.moreRect(day: day, group: groups[group])
        let g = CGPoint(x: r.midX, y: r.midY)
        return (g, d.windowPoint(fromGrid: g))
    }

    /// The centre of the i-th row of the open stack, in window points.
    static func stackRow(_ m: AppModel, _ i: Int) -> CGPoint {
        let f = m.gridState.stackFrame
        return CGPoint(x: f.midX, y: f.minY + 4 + CGFloat(i) * (Dim.row + 3) + Dim.row / 2)
    }

    /// Wednesday evening: hover "+1", open the stack, hover its rows, pick one, Esc; open again and click outside.
    static func c2(_ d: Driver, _ m: AppModel) {
        d.section("+N")
        scrollGrid(d, m, to: SnapshotV4.eveningScroll)
        d.check(m.layout.groups(day: 2) == [OverflowGroup(startMinute: 18 * 60 + 15, ids: ["v4.c5"])], "Wednesday has one +1 at 18:15")
        d.say("Wednesday evening: at most two events side by side")
        d.moveCursor(to: CGPoint(x: 590, y: 380), duration: 0.6)
        d.hold(1.0)
        guard let chip = moreWindowPoint(d, m, day: 2, group: 0) else { d.check(false, "the +1 is laid out"); return }
        d.say("The rest goes into +1")
        let before = luma(d, at: chip.window)
        d.moveCursor(to: chip.window, duration: 0.5)
        d.play(0.25) {
            if case .more(let day, let i)? = m.hitTest(chip.grid) { m.gridState.pointer.hoveredMore = GridMoreRef(day: day, group: i) }
        }
        d.check(m.gridState.pointer.hoveredMore == GridMoreRef(day: 2, group: 0), "hovering +1")
        d.check(luma(d, at: CGPoint(x: chip.window.x - 7, y: chip.window.y)) > before, "+1 inverts on hover")
        d.hold(1.0)

        d.section("Stack")
        d.say("Click: the busy time as a stack")
        d.recordClick()
        d.play(0.4) { m.gridMouseDown(chip.grid); m.gridMouseUp(chip.grid) }
        d.settle(4)
        let rows = m.stackRows
        d.check(m.visibleStack != nil && rows.map(\.event.title) == ["Founder meetup", "Idea session", "Flat cleaning", "[P1] Take vitamins"],
                "the stack lists the busy time in order (\(rows.map(\.event.title).joined(separator: ", ")))")
        d.check(m.gridState.stackFrame.width > 200, "the stack spans two columns (\(Int(m.gridState.stackFrame.width)) pt)")
        d.hold(0.8)
        d.say("Rows in their reply style: maybe, declined")
        for i in rows.indices {
            let p = stackRow(m, i)
            d.moveCursor(to: p, duration: 0.35)
            d.play(0.2) { m.gridState.pointer.hoveredStackRow = rows[i].event.id }
            d.hold(0.45)
        }
        d.check(m.gridState.pointer.hoveredStackRow == rows.last?.event.id, "hovering the rows")
        d.say("Click a row to open the event")
        let pick = rows[1].event
        d.clickPoint(stackRow(m, 1), seconds: 0.6)
        d.check(m.selectedEventID == pick.id && m.gridState.stack == nil, "the row selects \(pick.title) and closes the stack")
        d.hold(1.2)

        d.section("Close")
        d.say("Open again; Esc closes it", keys: ["esc"])
        d.moveCursor(to: chip.window, duration: 0.4)
        d.recordClick()
        d.play(0.4) { m.gridMouseDown(chip.grid); m.gridMouseUp(chip.grid) }
        d.check(m.visibleStack != nil, "+1 opens the stack again")
        d.hold(0.8)
        d.play(0.4) { d.special("esc") }
        d.check(m.gridState.stack == nil, "Esc closes the stack")
        d.hold(0.6)
        d.say("Open it once more")
        d.moveCursor(to: chip.window, duration: 0.3)
        d.recordClick()
        d.play(0.4) { m.gridMouseDown(chip.grid); m.gridMouseUp(chip.grid) }
        d.check(m.visibleStack != nil, "open")
        d.hold(0.8)
        d.say("A click outside closes it")
        let outside = CGPoint(x: 120, y: 700)
        d.click(at: outside) {
            let size = d.size
            if PanelClickAway.closesStack(at: CGPoint(x: outside.x, y: size.height - outside.y), in: size, model: m) { m.closeStack() }
        }
        d.check(m.gridState.stack == nil, "a click in the sidebar closes the stack")
        unhover(m)
        d.hold(1.2)
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
        let toggle = CGPoint(x: f().minX - Theme.gutterWidth / 2, y: f().minY + 5 + Dim.iconButtonSmall / 2)
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
