import Foundation
import CalendrKit

extension CalendarStore {
    /// Only a store that can read other people's calendars offers Meet with. EventKit only knows the events of your own
    /// calendars that someone attends, which would draw ghost copies of your own events instead of their availability.
    var canOverlayTeammates: Bool { self is DemoStore }
}

// MARK: Keyboard selection (Tab, arrows, Return, Option-arrows)

extension AppModel {
    static let meetWithUnavailable = "Meet with needs a calendar account that shares availability"

    /// The events Tab and the arrows walk: what the grid shows from a week before the period to a week after it.
    private func walkableEvents(padDays: Int) -> [CalendarEvent] {
        let q = periodRange
        let range = DateInterval(start: math.addDays(q.start, -padDays), end: math.addDays(q.end, padDays))
        return store.events(in: range).filter {
            !hiddenCalendars.contains($0.calendarID) && (settings.showDeclined || $0.status != .declined) && $0.id != draftEventID
                && ($0.end > range.start && $0.start < range.end)
        }
    }

    /// The days of the period: the month in month view (not the neighbours' days it shows), otherwise the visible days.
    private var periodRange: DateInterval {
        if viewMode == .month { return DateInterval(start: math.startOfMonth(visibleStart), end: math.addMonths(math.startOfMonth(visibleStart), 1)) }
        return DateInterval(start: visibleStart, end: math.addDays(visibleDays.last ?? visibleStart, 1))
    }

    /// Tab / Shift-Tab.
    func selectByTab(_ direction: Int) {
        let q = periodRange
        let inPeriod = walkableEvents(padDays: 0).filter { $0.start < q.end && ($0.end > q.start || $0.start >= q.start) }
        guard let e = KeyboardSelection.tab(from: selectedEventID, in: inPeriod, now: now, direction: direction, math: math) else { return }
        keyboardSelect(e)
    }

    /// Arrow keys: with a selection they walk it (never the period); without one, left and right page.
    @discardableResult
    func arrowKey(dx: Int, dy: Int) -> Bool {
        guard let e = selectedEvent else {
            if dx != 0 { step(dx); return true }
            return false
        }
        if let n = KeyboardSelection.neighbour(of: e, in: walkableEvents(padDays: 7), dx: dx, dy: dy, math: math) { keyboardSelect(n) }
        return true
    }

    /// Option-arrows: move the selected event by a day or 15 minutes, with undo and the same toast as a drag.
    @discardableResult
    func nudgeSelected(dx: Int, dy: Int) -> Bool {
        guard let old = selectedEvent else { return arrowKey(dx: dx, dy: dy) }
        guard isWritable(old) else { showToast("This calendar is read-only"); return true }
        guard let moved = KeyboardSelection.nudged(old, days: dx, minutes: dy * GridGeometry.snap, math: math) else { return true }
        flushPendingEdit()
        commit(moved, span: .this, old: old)
        if let e = selectedEvent { keepVisible(e) }
        return true
    }

    /// Return: the selected event's title takes the keyboard with its text selected.
    @discardableResult
    func editSelectedTitle() -> Bool {
        guard let e = selectedEvent else { return false }
        if isWritable(e) { requestTitleFocus() }
        return true
    }

    private func keyboardSelect(_ e: CalendarEvent) {
        select(eventID: e.id)
        keepVisible(e)
    }

    /// The period follows the selection; the grid scrolls only as far as needed to show it.
    private func keepVisible(_ e: CalendarEvent) {
        if viewMode == .month {
            if !math.isSameMonth(e.start, visibleStart) { go(to: e.start) }
            return
        }
        if !visibleDays.contains(where: { math.isSameDay($0, e.start) }) { go(to: e.start) }
        guard !e.isAllDay, let p = flatTimed.first(where: { $0.event.id == e.id }), gridViewport.height > 0 else { return }
        let pph = gridHourHeight
        let top = GridGeometry.pad + Double(p.startMinute) / 60 * pph - 6, bottom = GridGeometry.pad + Double(p.endMinute) / 60 * pph + 6
        let y = Double(gridScrollY), h = Double(gridViewport.height)
        let target: Double
        if top < y { target = top } else if bottom > y + h { target = bottom - h } else { return }
        gridState.scrollTarget = max(0, target)
        gridState.scrollTick += 1
    }
}
