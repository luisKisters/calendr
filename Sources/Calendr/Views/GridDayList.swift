import SwiftUI
import CalendrKit

/// The month layout of the period on screen, rebuilt only when the events or the size change (not on hover or selection).
final class MonthLayoutCache {
    private var key: (generation: Int, size: CGSize)?
    private(set) var layout: MonthLayout?

    @MainActor
    func layout(for m: AppModel, size: CGSize) -> MonthLayout {
        if let k = key, let l = layout, k.generation == m.layoutGeneration, k.size == size { return l }
        let l = MonthLayout(size: size, grid: m.monthGrid, cells: m.monthEvents, month: m.visibleStart, math: m.math, fmt: m.fmt)
        key = (m.layoutGeneration, size)
        layout = l
        return l
    }
}

extension AppModel {
    /// The row of the all-day lane that turns into "n more", or nil when every row shows (also when the selected or new event sits there).
    var allDayFold: Int? {
        let all = layout.allDay
        guard all.laneCount > AllDayView.maxRows else { return nil }
        if let held = all.placements.first(where: { $0.id == selectedEventID || $0.id == draftEventID }), held.lane >= AllDayView.maxRows - 1 { return nil }
        return AllDayView.maxRows - 1
    }

    /// "n more" in the all-day lane or a month cell: the day's events in a list under it. Settles the draft and the selection first.
    func openDayList(_ day: Date) {
        gridDismiss()
        gridState.dayList = GridDayList(day: math.startOfDay(day), period: periodID)
    }

    /// A row of the day list: select that event and close the list.
    func pickFromDayList(_ id: String) {
        gridState.dayList = nil
        select(eventID: id)
    }

    /// The day list, while it belongs to the period on screen and nothing is being created or dragged.
    var visibleDayList: GridDayList? {
        guard let l = gridState.dayList, l.period == periodID, draftEventID == nil, dragPreview == nil else { return nil }
        return l
    }

    /// Every event of `day`: all-day first, then by start.
    func dayListEvents(_ day: Date) -> [CalendarEvent] {
        guard let i = visibleDays.firstIndex(where: { math.isSameDay($0, day) }) else { return [] }
        var list: [CalendarEvent] = []
        if viewMode == .month {
            if monthEvents.indices.contains(i) { list = monthEvents[i] }
        } else {
            list = layout.allDay.placements.filter { $0.firstDay <= i && $0.lastDay >= i }.compactMap { layout.allDayEvents[$0.id] }
            if layout.timed.indices.contains(i) {
                var seen = Set<String>()
                list += layout.timed[i].map(\.event).filter { seen.insert($0.id).inserted }
            }
        }
        return list.enumerated().sorted { a, b in
            if a.element.isAllDay != b.element.isAllDay { return a.element.isAllDay }
            if a.element.start != b.element.start { return a.element.start < b.element.start }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// Window frame of the "n more" the list hangs from.
    func dayListAnchor(_ l: GridDayList) -> CGRect? {
        if viewMode == .month {
            guard let it = gridState.monthCache.layout?.items.first(where: { $0.kind == .more && math.isSameDay($0.day, l.day) }) else { return nil }
            return it.rect.offsetBy(dx: gridState.monthFrame.minX, dy: gridState.monthFrame.minY)
        }
        guard let i = visibleDays.firstIndex(where: { math.isSameDay($0, l.day) }), let fold = allDayFold else { return nil }
        let f = gridState.allDayFrame
        let dw = f.width / CGFloat(max(1, visibleDays.count))
        return CGRect(x: f.minX + CGFloat(i) * dw + 1, y: f.minY + CGFloat(fold) * AllDayView.row, width: dw - 3, height: 21)
    }
}

/// Places the day list below its "n more" (above it when there is no room below), inside the view it overlays.
struct GridDayListHost: View {
    @Environment(AppModel.self) private var model
    static let margin: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if let l = model.visibleDayList, let a = model.dayListAnchor(l) {
                    let events = model.dayListEvents(l.day)
                    let frame = geo.frame(in: .global)
                    let pos = Self.origin(anchor: a.offsetBy(dx: -frame.minX, dy: -frame.minY), size: CGSize(width: GridDayListPopover.width, height: GridDayListPopover.height(rows: events.count)), in: geo.size)
                    GridDayListPopover(day: l.day, events: events)
                        .offset(x: pos.x, y: pos.y)
                        .transition(.scale(scale: 0.98, anchor: .top).combined(with: .offset(y: 3)).combined(with: .opacity))
                        .id(l.day)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .animation(Motion.slow, value: model.visibleDayList)
        }
    }

    /// `place()` of app-views.js for `side: 'below'`: 6 pt under the anchor, flipped above it when it would leave the bottom, kept `margin` inside.
    static func origin(anchor a: CGRect, size: CGSize, in bounds: CGSize) -> CGPoint {
        var y = a.maxY + 6
        if y + size.height > bounds.height - margin { y = a.minY - size.height - 6 }
        let x = min(max(margin, a.minX), bounds.width - size.width - margin)
        return CGPoint(x: x, y: y)
    }
}

/// `.pl` of app.css with `.ag__r` rows: the long date and the count, then one row per event (time or "all day", bar, title).
struct GridDayListPopover: View {
    @Environment(AppModel.self) private var model
    static let width: CGFloat = 286
    static let rowHeight: CGFloat = 30
    static let headerHeight: CGFloat = 30
    let day: Date
    let events: [CalendarEvent]

    static func height(rows: Int) -> CGFloat { min(420, 12 + headerHeight + CGFloat(rows) * rowHeight) }

    var body: some View {
        let fmt = model.fmt
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(fmt.weekdayLong(day)) \(model.math.day(day)) \(fmt.monthLong(day))").font(.ui(12.5, .semibold)).foregroundStyle(Theme.fg)
                Spacer(minLength: 8)
                Text("\(events.count)").font(.calMono(11)).foregroundStyle(Theme.fg3)
            }
            .padding(.horizontal, 9)
            .frame(height: Self.headerHeight)
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(events, id: \.id) { GridDayListRow(event: $0) }
                }
            }
            .scrollIndicators(.never)
        }
        .padding(6)
        .frame(width: Self.width, height: Self.height(rows: events.count), alignment: .top)
        .background(RoundedRectangle(cornerRadius: Radius.surface).fill(Theme.bg1))
        .overlay(RoundedRectangle(cornerRadius: Radius.surface).strokeBorder(Theme.hair2, lineWidth: 1))
        .popShadow()
    }
}

private struct GridDayListRow: View {
    @Environment(AppModel.self) private var model
    let event: CalendarEvent
    @State private var hover = false

    var body: some View {
        let e = event
        let past = e.end <= model.now
        let selected = model.selectedEventID == e.id
        Button { model.pickFromDayList(e.id) } label: {
            HStack(spacing: 8) {
                Text(e.isAllDay ? "all day" : model.fmt.time(e.start)).font(.calMono(11)).foregroundStyle(Theme.fg2)
                    .frame(width: 40, alignment: .leading)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: model.hexColor(of: e))).frame(width: 3, height: 14)
                Text(e.title.isEmpty ? "(No title)" : e.title).font(.ui(12.5)).foregroundStyle(past ? Theme.fg3 : Theme.fg)
                    .lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(height: GridDayListPopover.rowHeight)
            .background(RoundedRectangle(cornerRadius: Radius.row).fill(selected ? Theme.actWash : hover ? Theme.hover : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}
