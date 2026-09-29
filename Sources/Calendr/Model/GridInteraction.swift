import Foundation
import CalendrKit

/// Geometry of the time grid content (x = 0 at the first day column's left edge, y = 0 at 00:00).
struct GridGeometry: Equatable {
    var dayWidth: Double
    var hourHeight: Double
    var dayCount: Int
    /// Left inset of events inside a day column; the right inset leaves room to click-create next to a full-width event.
    var leftInset: Double = 3
    var rightInset: Double = 8
    var bottomGap: Double = 3
    /// Height of pills (events shorter than 30 minutes).
    var minEventHeight: Double = 17

    var totalHeight: Double { hourHeight * 24 }
    func yPos(_ m: Int) -> Double { Double(m) / 60 * hourHeight }
    func minute(forY y: Double) -> Int { Int((y / hourHeight * 60).rounded(.down)) }

    func rect(for p: PlacedEvent) -> CGRect {
        let x0 = Double(p.dayIndex) * dayWidth
        if p.placement.chip {
            // checkbox-only chip at the event's trailing edge
            return CGRect(x: x0 + dayWidth - rightInset - 19, y: yPos(p.startMinute), width: 19, height: 19)
        }
        let inner = dayWidth - leftInset - rightInset
        let x = x0 + leftInset + p.placement.left * inner
        let w = max(4, p.placement.width * inner)
        let y = yPos(p.displayStart)
        let h = p.event.kind == .task && p.isPill ? minEventHeight : max(minEventHeight, yPos(p.endMinute) - y - bottomGap)
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

enum GridHit: Equatable {
    case event(id: String, dayIndex: Int, startMinute: Int, endMinute: Int, resize: Bool)
    case empty(dayIndex: Int, minute: Int)
    /// The round checkbox of a task capsule.
    case checkbox(id: String)
}

struct GridPress {
    var hit: GridHit
    var origin: CGPoint
    var grabMinutes: Int
    var dragging = false
    var clickCount: Int
}

extension AppModel {
    func hitTest(_ p: CGPoint) -> GridHit? {
        let g = gridGeometry
        guard p.x >= 0, p.y >= 0, g.dayWidth > 0 else { return nil }
        let day = min(g.dayCount - 1, Int(p.x / g.dayWidth))
        guard day >= 0, day < layout.timed.count else { return nil }
        let minute = min(1439, max(0, g.minute(forY: p.y)))
        for pe in layout.timed[day].reversed() {
            let r = g.rect(for: pe)
            if r.contains(p) {
                if pe.event.kind == .task, EventPainter.checkboxRect(in: r).insetBy(dx: -3, dy: -3).contains(p) { return .checkbox(id: pe.event.id) }
                let nearBottom = pe.endMinute - pe.startMinute >= 30 && p.y > r.maxY - 6 && !pe.continuesToNext
                return .event(id: pe.event.id, dayIndex: day, startMinute: pe.startMinute, endMinute: pe.endMinute, resize: nearBottom)
            }
        }
        return .empty(dayIndex: day, minute: minute)
    }

    // The SwiftUI gesture and the walkthrough driver both call exactly these three functions.

    func gridMouseDown(_ p: CGPoint, clickCount: Int = 1) {
        guard let hit = hitTest(p) else { return }
        var grab = 0
        if case .event(_, _, let s, _, _) = hit { grab = gridGeometry.minute(forY: p.y) - s }
        press = GridPress(hit: hit, origin: p, grabMinutes: grab, clickCount: clickCount)
    }

    func gridMouseDragged(_ p: CGPoint) {
        guard var pr = press else { return }
        if !pr.dragging {
            guard hypot(p.x - pr.origin.x, p.y - pr.origin.y) > 4 else { return }
            pr.dragging = true
        }
        press = pr
        let g = gridGeometry
        let day = max(0, min(g.dayCount - 1, Int(p.x / g.dayWidth)))
        let minute = g.minute(forY: p.y)
        switch pr.hit {
        case .checkbox: return
        case .empty(let d0, let m0):
            let a = (m0 / 15) * 15
            let cur = (minute / 15) * 15
            let lo = min(a, cur), hi = max(a + 15, cur + 15)
            dragPreview = DragPreview(kind: .create, eventID: nil, dayIndex: d0, startMinute: max(0, lo), endMinute: min(1440, hi))
        case .event(let id, _, let s, let e, let resize):
            guard let ev = event(id: id), isWritable(ev) else { return }
            if resize {
                let end = max(s + 15, CalendarMath.snap(minute, to: 15))
                dragPreview = DragPreview(kind: .resize, eventID: id, dayIndex: pr.hit.dayIndex, startMinute: s, endMinute: min(1440, end))
            } else {
                let dur = e - s
                let start = max(0, min(1440 - min(dur, 1440), CalendarMath.snap(minute - pr.grabMinutes, to: 15)))
                dragPreview = DragPreview(kind: .move, eventID: id, dayIndex: day, startMinute: start, endMinute: min(1440, start + dur))
            }
        }
    }

    func gridMouseUp(_ p: CGPoint) {
        defer { press = nil; dragPreview = nil }
        guard let pr = press else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if !pr.dragging {
            switch pr.hit {
            case .event(let id, let d, let s, _, _):
                let double = pr.clickCount >= 2 || (lastClick.map { now - $0.time < 0.4 && $0.id == id } ?? false)
                select(eventID: id, focusTitle: double)
                lastClick = double ? nil : (now, d, s, id)
            case .checkbox(let id):
                toggleTask(id)
            case .empty(let d, let m):
                select(eventID: nil)
                deselect()
                selectedSlot = math.date(on: visibleDays[d], minutes: (m / 30) * 30)
                lastClick = (now, d, m, nil)
            }
            return
        }
        guard let prev = dragPreview else { return }
        dropSettle = (prev.dayIndex, prev.startMinute, prev.endMinute, (dropSettle?.tick ?? 0) + 1)
        switch prev.kind {
        case .create:
            let day = visibleDays[prev.dayIndex]
            createEvent(start: math.date(on: day, minutes: prev.startMinute), end: math.date(on: day, minutes: prev.endMinute))
        case .move, .resize:
            guard let id = prev.eventID, let old = event(id: id) else { return }
            var e = old
            let day = visibleDays[prev.dayIndex]
            if prev.kind == .move {
                // Move by the drag delta, measured from the segment that was grabbed: a multi-day event dragged by its
                // second-day segment must keep its own start instead of snapping the start to the new position.
                var segStart = 0
                if case .event(_, _, let s0, _, _) = pr.hit { segStart = s0 }
                let dayShift = math.daysBetween(visibleDays[pr.hit.dayIndex], day)
                let dur = old.end.timeIntervalSince(old.start)
                e.start = math.addDays(old.start, dayShift).addingTimeInterval(Double(prev.startMinute - segStart) * 60)
                e.end = e.start.addingTimeInterval(dur)
            } else {
                e.end = math.date(on: day, minutes: prev.endMinute)
            }
            if e.start != old.start || e.end != old.end {
                commit(e, span: .this, old: old)
            }
        }
    }
}

extension GridHit {
    var dayIndex: Int {
        switch self { case .event(_, let d, _, _, _): d; case .empty(let d, _): d; case .checkbox: 0 }
    }
}
