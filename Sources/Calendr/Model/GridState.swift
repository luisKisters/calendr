import Foundation
import Observation
import CalendrKit

/// View state of the GRID area (TimeGridView, EventsCanvas, EventViews, GridInteraction, DayHeaderView, MonthView, CalendrKit/Layout). Stored on `AppModel.gridState`; the area owns this file and grows the struct.
struct GridState: Equatable {
    /// The hour range and height the period on screen opened with ("Fit, then yours").
    var fit: HourFit?
    /// Height of the scrolling grid, published by the view; the fit fills it.
    var viewportHeight: Double = 0
    /// The grid scrolls to `scrollTarget` whenever `scrollTick` changes.
    var scrollTarget: Double = 0
    var scrollTick = 0
    /// The day list opened from "n more" (all-day lane or month cell).
    var dayList: GridDayList?
    /// Window frames of the all-day lane and the month grid, published by the views: the day list is anchored to their "n more".
    var allDayFrame = CGRect.zero
    var monthFrame = CGRect.zero
    /// When a double-click last made a draft: a third quick click belongs to that gesture and must not dismiss it.
    var draftMadeAt: TimeInterval = 0
    /// Gutter zoom in progress.
    var zoom: GutterZoom?
    /// The open "+N" stack panel.
    var stack: StackRef?
    /// Window frame of the stack panel, published by the view (a press outside it closes it). A plain box, not observed state:
    /// the frame changes on every scroll frame and must not invalidate the grid.
    let stackBox = StackBox()
    var stackFrame: CGRect { stackBox.frame }
    /// The all-day section shows every lane (it scrolls past 4.5 lanes) instead of two lanes and "+N more".
    var allDayExpanded = false
    /// The expanded all-day section scrolls to `allDayScrollTarget` whenever `allDayScrollTick` changes.
    var allDayScrollTarget: Double = 0
    var allDayScrollTick = 0
    /// Pointer feedback lives in its own observable object, so hovering redraws only the views that show it.
    let pointer = GridPointer()
    let monthCache = MonthLayoutCache()

    static func == (a: GridState, b: GridState) -> Bool {
        a.fit == b.fit && a.viewportHeight == b.viewportHeight && a.scrollTarget == b.scrollTarget && a.scrollTick == b.scrollTick
            && a.dayList == b.dayList && a.allDayFrame == b.allDayFrame && a.monthFrame == b.monthFrame && a.draftMadeAt == b.draftMadeAt
            && a.zoom == b.zoom && a.stack == b.stack && a.stackBox === b.stackBox && a.allDayExpanded == b.allDayExpanded && a.allDayScrollTarget == b.allDayScrollTarget && a.allDayScrollTick == b.allDayScrollTick && a.pointer === b.pointer && a.monthCache === b.monthCache
    }
}

/// A "+N" group by its day and start, in the period it was opened in.
struct StackRef: Equatable {
    var period: String
    var day: Int
    var startMinute: Int
}

struct GridDayList: Equatable {
    var day: Date
    /// Period it was opened in; it does not show in any other.
    var period: String
}

struct HourFit: Equatable {
    var key: String
    var mode: ViewMode
    /// First and last minute of the fitted range (whole hours).
    var lo: Int
    var hi: Int
    var perHour: Double
    var viewport: Double
}

/// Dragging the hour gutter: the hour under the pointer stays put.
struct GutterZoom: Equatable {
    var startHeight: Double
    var startY: Double
    /// Pointer offset from the top of the viewport and the minute under it.
    var offset: Double
    var minute: Double
    /// Height under the pointer; written to the settings once, when the drag ends.
    var live: Double?
}

@Observable
final class GridPointer {
    /// Snapped minute shown in the gutter pill (hover over empty grid, or the edge being dragged).
    var minute: Int?
    var hoveredEventID: String?
    /// The "+N" button under the pointer (day, group index).
    var hoveredMore: GridMoreRef?
    /// The row of the "+N" stack under the pointer (event id).
    var hoveredStackRow: String?
    /// The day whose all-day "+N more" is under the pointer.
    var hoveredAllDayMore: Int?
}

final class StackBox { var frame = CGRect.zero }

struct GridMoreRef: Equatable { var day: Int; var group: Int }

extension AppModel {
    static let gridMinHourHeight = 20.0
    static let gridMaxHourHeight = 150.0

    /// The hand-set hour height: the one under the pointer during a gutter drag, else the saved one (clamped; a broken value counts as none).
    var gridHandHeight: Double? {
        if let live = gridState.zoom?.live { return live }
        guard let h = settings.hourHeight, h.isFinite, h > 0 else { return nil }
        return min(Self.gridMaxHourHeight, max(Self.gridMinHourHeight, h))
    }

    /// Points per hour on screen: the hand-set height, else the fit of the period.
    var gridHourHeight: Double { gridHandHeight ?? gridState.fit?.perHour ?? 56 }

    /// Used by `reload()`: fits a period the first time it is shown, then cascades its events for the hour height on screen.
    func gridLayout(_ l: RangeLayout) -> RangeLayout {
        // The "+N" stack belongs to the period it was opened in.
        if let s = gridState.stack, s.period != periodID { closeStack() }
        guard viewMode != .month else { return l }
        refitIfNeeded(l)
        return l.repacked(pointsPerHour: gridHourHeight)
    }

    private func refitIfNeeded(_ l: RangeLayout) {
        let key = periodID
        let viewport = gridState.viewportHeight
        // A period keeps the fit it opened with; only the first real viewport height of a period refits it.
        if let f = gridState.fit, f.key == key, f.viewport > 0 || viewport == 0 { return }
        let old = gridState.fit
        var lo = 9 * 60, hi = 18 * 60
        for day in l.timed { for p in day where p.event.id != draftEventID { lo = min(lo, p.startMinute); hi = max(hi, p.endMinute) } }
        if visibleDays.contains(where: { math.isSameDay($0, now) }) {
            let n = math.minutesSinceMidnight(now)
            lo = min(lo, n - 30); hi = max(hi, n + 30)
        }
        lo = max(0, lo / 60 * 60); hi = min(1440, (hi + 59) / 60 * 60)
        let per = max(38, (viewport - GridGeometry.pad * 2) / (Double(hi - lo) / 60))
        gridState.fit = HourFit(key: key, mode: viewMode, lo: lo, hi: hi, perHour: per, viewport: viewport)
        // A fitted grid opens every period at the top of its fit; a hand-set height keeps the scroll position, except in a new view.
        let hand = gridHandHeight
        if hand == nil || old == nil || old?.mode != viewMode { scrollGridToFit(perHour: hand ?? per) }
    }

    private func scrollGridToFit(perHour: Double) {
        guard let f = gridState.fit else { return }
        gridState.scrollTarget = Double(f.lo) / 60 * perHour
        gridState.scrollTick += 1
    }

    /// Settings > Hour height > Fit again, the command, and a double-click on the hour gutter: forget the hand-set height and fit the period again.
    func fitHourScale() {
        settings.hourHeight = nil
        gridState.fit = nil
        reload()
    }

    /// The scrolling grid's height, published by the view. A period opened before the grid had a height is fitted again once it has one.
    func setGridViewport(height: Double) {
        guard abs(height - gridState.viewportHeight) >= 1 else { return }
        gridState.viewportHeight = height
        if (gridState.fit?.viewport ?? 0) == 0 { reload() }
    }

    /// Scroll for "go to" actions: the selected event an hour from the top if it is on screen, else the top of the fit.
    func scrollGridToSelectionOrFit() {
        let pph = gridHourHeight
        if let id = selectedEventID, let p = flatTimed.first(where: { $0.event.id == id }) {
            gridState.scrollTarget = max(0, Double(p.startMinute - 60) / 60 * pph)
            gridState.scrollTick += 1
        } else {
            scrollGridToFit(perHour: pph)
        }
    }

    // MARK: Gutter zoom

    /// `y` is measured from the top of the scrolling viewport.
    func gutterZoomBegan(y: Double) {
        let pph = gridHourHeight
        gridState.zoom = GutterZoom(startHeight: pph, startY: y, offset: y, minute: (Double(gridScrollY) + y - GridGeometry.pad) / pph * 60)
    }

    /// Only the grid follows the pointer; the settings are written once, in `gutterZoomEnded`.
    func gutterZoomChanged(y: Double) {
        guard let z = gridState.zoom else { return }
        let per = min(Self.gridMaxHourHeight, max(Self.gridMinHourHeight, z.startHeight * exp((y - z.startY) / 220)))
        guard per != gridHourHeight else { return }
        gridState.zoom?.live = per
        reload()
        gridState.scrollTarget = max(0, GridGeometry.pad + z.minute / 60 * per - z.offset)
        gridState.scrollTick += 1
    }

    func gutterZoomEnded() {
        if let live = gridState.zoom?.live { settings.hourHeight = live }
        gridState.zoom = nil
    }

    /// Esc during a drag (create, move, resize or gutter zoom) puts everything back, and Esc closes the day list.
    /// Returns false when there was nothing to undo or close.
    func gridCancelDrag() -> Bool {
        if visibleStack != nil { closeStack(); return true }
        if let z = gridState.zoom {
            gridState.zoom = nil
            if z.live != nil { reload() }
            return true
        }
        if overlay == nil, let list = gridState.dayList {
            gridState.dayList = nil
            if list.period == periodID { return true }
        }
        guard press?.dragging == true else { return false }
        press = nil
        dragPreview = nil
        gridState.pointer.minute = nil
        return true
    }
}

// MARK: "+N" stack

extension AppModel {
    /// The open stack while it belongs to the period on screen, with its day's group.
    var visibleStack: (ref: StackRef, group: OverflowGroup)? {
        guard let s = gridState.stack, s.period == periodID, let g = layout.groups(day: s.day).first(where: { $0.startMinute == s.startMinute }) else { return nil }
        return (s, g)
    }

    /// The rows of the open stack: every event of the busy time, in time order.
    var stackRows: [PlacedEvent] {
        guard let v = visibleStack else { return [] }
        return layout.stackRows(day: v.ref.day, group: v.group)
    }

    /// A click on "+N": opens its stack over the day, or closes it when it is the open one.
    func toggleStack(day: Int, group i: Int) {
        let groups = layout.groups(day: day)
        guard groups.indices.contains(i) else { return }
        let ref = StackRef(period: periodID, day: day, startMinute: groups[i].startMinute)
        if gridState.stack == ref { closeStack(); return }
        gridState.dayList = nil
        gridState.stack = ref
    }

    func closeStack() {
        gridState.stack = nil
        gridState.pointer.hoveredMore = nil
        gridState.pointer.hoveredStackRow = nil
    }

    /// A row of the stack: select that event and close the stack.
    func pickFromStack(_ id: String) {
        closeStack()
        select(eventID: id)
    }
}
