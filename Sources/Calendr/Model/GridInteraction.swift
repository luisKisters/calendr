import Foundation
import CalendrKit

/// Geometry of the time grid content (x = 0 at the first day column's left edge, y = 0 at the top of the canvas, 00:00 is `pad` below it).
struct GridGeometry: Equatable {
    var dayWidth: Double
    var hourHeight: Double
    var dayCount: Int

    /// Space above 00:00 and below 24:00.
    static let pad = 10.0
    static let snap = 15

    var totalHeight: Double { hourHeight * 24 + Self.pad * 2 }
    func yPos(_ m: Int) -> Double { yPos(Double(m)) }
    func yPos(_ m: Double) -> Double { Self.pad + m / 60 * hourHeight }
    /// Minute of day at `y`, unrounded and clamped to the day.
    func minute(atY y: Double) -> Double { min(1440, max(0, (y - Self.pad) / hourHeight * 60)) }
    func snapped(_ m: Double) -> Int { min(1440, max(0, Int((m / Double(Self.snap)).rounded()) * Self.snap)) }

    /// A block inside its day column (`.ev` in app.css): 1 pt in from the column's hairline, 3 pt narrower than its share, at least 19 pt tall, 1 pt gap below.
    func rect(day: Int, start: Int, end: Int, left: Double = 0, width: Double = 1) -> CGRect {
        let inner = dayWidth - 1
        let y0 = yPos(start), y1 = max(yPos(end), y0 + OverlapLayout.minHeight)
        return CGRect(x: Double(day) * dayWidth + 2 + left * inner, y: y0, width: max(4, width * inner - 3), height: y1 - y0 - 1)
    }

    func rect(for p: PlacedEvent) -> CGRect {
        rect(day: p.dayIndex, start: p.startMinute, end: p.endMinute, left: p.placement.left, width: p.placement.width)
    }
}

enum GridHit: Equatable {
    enum Edge { case top, bottom }
    case event(id: String, dayIndex: Int, startMinute: Int, endMinute: Int, edge: Edge?)
    case empty(dayIndex: Int, minute: Double)
}

struct GridPress {
    var hit: GridHit
    var origin: CGPoint
    var grabMinutes: Double
    var dragging = false
    var clickCount: Int
    /// This press dismissed a selection or draft, so it cannot be the second click of a double-click.
    var dismissed = false
}

extension AppModel {
    func hitTest(_ p: CGPoint) -> GridHit? {
        let g = gridGeometry
        guard p.x >= 0, p.y >= 0, g.dayWidth > 0 else { return nil }
        let day = min(g.dayCount - 1, Int(p.x / g.dayWidth))
        guard day >= 0, day < layout.timed.count else { return nil }
        // Paint order is ascending, so the topmost block is the last one that contains the point.
        let order = layout.timed[day].sorted { paintRank($0) < paintRank($1) }
        for pe in order.reversed() {
            let r = gridGeometry.rect(for: pe)
            guard r.contains(p) else { continue }
            var edge: GridHit.Edge?
            if pe.event.id != draftEventID, isWritable(pe.event) {
                if p.y > r.maxY - 5 && !pe.continuesToNext { edge = .bottom } else if p.y < r.minY + 5 && !pe.continuesFromPrevious { edge = .top }
            }
            return .event(id: pe.event.id, dayIndex: day, startMinute: pe.startMinute, endMinute: pe.endMinute, edge: edge)
        }
        return .empty(dayIndex: day, minute: g.minute(atY: p.y))
    }

    /// The selected event and the draft paint above everything else.
    func paintRank(_ p: PlacedEvent) -> Int { p.event.id == selectedEventID || p.event.id == draftEventID ? 100 : p.placement.z }

    /// A press on empty grid closes the day list, dismisses the selection and settles the draft (kept when it has a title, dropped when not).
    @discardableResult
    func gridDismiss() -> Bool {
        let had = selectedEventID != nil || draftEventID != nil || selectedSlot != nil || visibleDayList != nil
        gridState.dayList = nil
        deselect()
        draftEventID = nil
        return had
    }

    // The SwiftUI gesture and the walkthrough driver both call exactly these three functions.

    func gridMouseDown(_ p: CGPoint, clickCount: Int = 1) {
        guard let hit = hitTest(p) else { return }
        if case .event = hit { gridState.dayList = nil }
        let now = ProcessInfo.processInfo.systemUptime
        switch hit {
        case .event(let id, _, let s, _, _):
            if id == draftEventID { requestTitleFocus(); return }      // the block under construction hands the keyboard back to its field
            press = GridPress(hit: hit, origin: p, grabMinutes: gridGeometry.minute(atY: p.y) - Double(s), clickCount: clickCount)
        case .empty:
            if draftEventID != nil && now - gridState.draftMadeAt < 0.5 { requestTitleFocus(); return }
            press = GridPress(hit: hit, origin: p, grabMinutes: 0, clickCount: clickCount, dismissed: gridDismiss())
        }
    }

    func gridMouseDragged(_ p: CGPoint) {
        guard var pr = press else { return }
        if !pr.dragging {
            guard hypot(p.x - pr.origin.x, p.y - pr.origin.y) >= 4 else { return }
            pr.dragging = true
            press = pr
            if case .event(let id, _, _, _, _) = pr.hit, let e = event(id: id), isWritable(e), selectedEventID != id { select(eventID: id) }
        }
        let g = gridGeometry
        let day = max(0, min(g.dayCount - 1, Int(p.x / g.dayWidth)))
        let m = g.minute(atY: p.y)
        let cur = g.snapped(m)
        let snap = GridGeometry.snap
        switch pr.hit {
        case .empty(let d0, let m0):
            // Anchored at the slot that was pressed; dragging upwards works too.
            let t0 = min(1440 - snap, Int(m0) / snap * snap)
            let (a, b) = cur < t0 ? (cur, t0 + snap) : (t0, max(t0 + snap, cur))
            dragPreview = DragPreview(kind: .create, eventID: nil, dayIndex: d0, startMinute: a, endMinute: b)
            gridState.pointer.minute = cur < t0 ? a : b
        case .event(let id, let d, let s, let e, let edge):
            guard let ev = event(id: id), isWritable(ev) else { return }
            switch edge {
            case .bottom?:
                dragPreview = DragPreview(kind: .resize, eventID: id, dayIndex: d, startMinute: s, endMinute: min(1440, max(s + snap, cur)))
                gridState.pointer.minute = dragPreview?.endMinute
            case .top?:
                dragPreview = DragPreview(kind: .resize, eventID: id, dayIndex: d, startMinute: max(0, min(e - snap, cur)), endMinute: e)
                gridState.pointer.minute = dragPreview?.startMinute
            case nil:
                let dur = min(e - s, 1440)
                let start = max(0, min(1440 - dur, Int(((m - pr.grabMinutes) / Double(snap)).rounded()) * snap))
                dragPreview = DragPreview(kind: .move, eventID: id, dayIndex: day, startMinute: start, endMinute: start + dur)
                gridState.pointer.minute = start
            }
        }
    }

    func gridMouseUp(_ p: CGPoint) {
        defer { press = nil; dragPreview = nil; gridState.pointer.minute = nil }
        guard let pr = press else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if !pr.dragging {
            switch pr.hit {
            case .event(let id, let d, let s, _, _):
                let double = pr.clickCount >= 2 || (lastClick.map { now - $0.time < 0.42 && $0.id == id } ?? false)
                select(eventID: id, focusTitle: double)
                lastClick = double ? nil : (now, d, s, id)
            case .empty(let d, let m):
                // A click only dismisses; the second click of a double-click creates an event at the half hour under the pointer.
                let twice = !pr.dismissed && (pr.clickCount >= 2 || (lastClick.map { now - $0.time < 0.42 && $0.id == nil && $0.day == d && abs(Double($0.minute) - m) < 10 } ?? false))
                lastClick = twice ? nil : (now, d, Int(m), nil)
                guard twice, visibleDays.indices.contains(d) else { return }
                let dur = settings.defaultDurationMinutes
                let s = max(0, min(1440 - dur, Int(m) / 30 * 30))
                let start = math.date(on: visibleDays[d], minutes: s)
                createEvent(start: start, end: start.addingTimeInterval(Double(dur) * 60))
                gridState.draftMadeAt = now
            }
            return
        }
        guard let prev = dragPreview else { return }
        switch prev.kind {
        case .create:
            let day = visibleDays[prev.dayIndex]
            createEvent(start: math.date(on: day, minutes: prev.startMinute), end: math.date(on: day, minutes: prev.endMinute))
        case .move, .resize:
            guard let id = prev.eventID, let old = event(id: id) else { return }
            var e = old
            let day = visibleDays[prev.dayIndex]
            guard case .event(_, let d0, let s0, let e0, _) = pr.hit else { return }
            if prev.kind == .move {
                // Move by the drag delta, measured from the segment that was grabbed: a multi-day event dragged by its
                // second-day segment must keep its own start instead of snapping the start to the new position.
                let dayShift = math.daysBetween(visibleDays[d0], day)
                let dur = old.end.timeIntervalSince(old.start)
                e.start = math.addDays(old.start, dayShift).addingTimeInterval(Double(prev.startMinute - s0) * 60)
                e.end = e.start.addingTimeInterval(dur)
            } else if prev.startMinute != s0 {
                e.start = math.date(on: day, minutes: prev.startMinute)
            } else if prev.endMinute != e0 {
                e.end = math.date(on: day, minutes: prev.endMinute)
            }
            if e.start != old.start || e.end != old.end {
                commit(e, span: .this, old: old)
            }
        }
    }

    /// While dragging, the day columns the drag touches are cascaded again with the preview in place of the event (as the
    /// mockup re-packs on every move). Returns the events to draw and the preview with its placement.
    func gridPreviewLayout() -> (events: [PlacedEvent], preview: PlacedEvent?) {
        guard let pv = dragPreview, layout.timed.indices.contains(pv.dayIndex) else { return (flatTimed, nil) }
        let moving = pv.kind == .create ? nil : pv.eventID
        var touched: Set<Int> = [pv.dayIndex]
        if let id = moving { for p in flatTimed where p.event.id == id { touched.insert(p.dayIndex) } }
        let e = moving.flatMap { event(id: $0) } ?? CalendarEvent(id: "", calendarID: "", title: "", start: visibleDays[pv.dayIndex], end: visibleDays[pv.dayIndex])
        let ghost = PlacedEvent(id: "\(e.id)|preview", event: e, dayIndex: pv.dayIndex, startMinute: pv.startMinute, endMinute: pv.endMinute,
                                placement: Placement(id: "", column: 0, columns: 1))
        var out: [PlacedEvent] = []
        out.reserveCapacity(flatTimed.count)
        var preview: PlacedEvent?
        for d in layout.timed.indices {
            guard touched.contains(d) else { out += layout.timed[d]; continue }
            var day = layout.timed[d].filter { $0.event.id != moving }
            if d == pv.dayIndex { day.append(ghost) }
            for p in RangeLayoutBuilder.pack(day, pointsPerHour: layout.pointsPerHour) {
                if p.id == ghost.id { preview = p } else { out.append(p) }
            }
        }
        return (out, preview)
    }

    /// Month view: a double-click on a day cell creates an all-day event there.
    func createAllDay(on day: Date) {
        let d = math.startOfDay(day)
        createEvent(start: d, end: math.addDays(d, 1), allDay: true)
        gridState.draftMadeAt = ProcessInfo.processInfo.systemUptime
    }
}

extension GridHit {
    var dayIndex: Int {
        switch self { case .event(_, let d, _, _, _): d; case .empty(let d, _): d }
    }
}
