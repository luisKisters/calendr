import SwiftUI
import AppKit
import CalendrKit

/// One drawable, clickable thing in the month grid (`renderMonth` in app-views.js).
struct MonthItem {
    enum Kind { case number, bar, timed, more }
    var kind: Kind
    var rect: CGRect
    var day: Date
    var event: CalendarEvent?
    var text = ""
    var openLeft = false
    var openRight = false
}

/// Layout of the month grid, shared by drawing and hit testing.
struct MonthLayout {
    static let line: CGFloat = 21
    static let top: CGFloat = 32
    var size: CGSize
    var weeks: Int
    var items: [MonthItem] = []
    var cellWidth: CGFloat { size.width / 7 }
    var cellHeight: CGFloat { size.height / CGFloat(max(1, weeks)) }

    func cell(_ p: CGPoint) -> (week: Int, col: Int)? {
        guard p.x >= 0, p.y >= 0, p.x < size.width, p.y < size.height else { return nil }
        return (min(weeks - 1, Int(p.y / cellHeight)), min(6, Int(p.x / cellWidth)))
    }

    @MainActor
    init(size: CGSize, grid: [[Date]], cells: [[CalendarEvent]], month: Date, math: CalendarMath, fmt: Fmt) {
        self.size = size
        weeks = max(1, grid.filter { $0.contains { math.isSameMonth($0, month) } }.count)
        let cw = size.width / 7, ch = size.height / CGFloat(weeks)
        let fit = max(1, Int((ch - Self.top - 4) / Self.line))
        for w in 0..<weeks {
            let y0 = CGFloat(w) * ch
            let days = grid[w]
            // All-day bars of the week, packed into rows.
            var allDay: [String: CalendarEvent] = [:]
            var span: [String: (Int, Int)] = [:]
            var order: [String] = []
            for c in 0..<7 {
                for e in cells[w * 7 + c] where e.isAllDay {
                    if allDay[e.id] == nil { allDay[e.id] = e; order.append(e.id); span[e.id] = (c, c) } else { span[e.id]!.1 = c }
                }
            }
            let packed = AllDayPacker.pack(order.map { AllDayItem(id: $0, firstDay: span[$0]!.0, lastDay: span[$0]!.1) }, dayCount: 7)
            let mine = (0..<7).map { c in packed.placements.filter { $0.firstDay <= c && $0.lastDay >= c } }
            let used = mine.map { $0.map { $0.lane + 1 }.max() ?? 0 }
            let timed = (0..<7).map { c in cells[w * 7 + c].filter { !$0.isAllDay } }
            let room = Self.rooms(fit: fit, used: used, timed: timed.map(\.count), bars: packed.placements)
            for c in 0..<7 {
                let day = days[c]
                let x = CGFloat(c) * cw
                let num = math.day(day) == 1 ? "\(fmt.monthShort(day)) 1" : "\(math.day(day))"
                let nw = TextCache.line(num, .monthNum).width + 10
                items.append(MonthItem(kind: .number, rect: CGRect(x: x + 8, y: y0 + 6, width: max(21, nw), height: 21), day: day, text: num))
                var hidden = mine[c].filter { !Self.fits($0, room) }.count
                for b in mine[c] where (b.firstDay == c || c == 0) && Self.fits(b, room) {
                    guard let e = allDay[b.id] else { continue }
                    let n = CGFloat(b.lastDay - c + 1)
                    let first = math.startOfDay(e.start), last = math.addDays(math.startOfDay(e.end.addingTimeInterval(-1)), 1)
                    items.append(MonthItem(kind: .bar, rect: CGRect(x: x + 4, y: y0 + Self.top + CGFloat(b.lane) * Self.line, width: n * cw - 8, height: 19), day: day, event: e,
                                           openLeft: first < day, openRight: last > math.addDays(days[6], 1)))
                }
                var row = used[c]
                for e in timed[c] {
                    if row >= room[c] { hidden += 1; continue }
                    items.append(MonthItem(kind: .timed, rect: CGRect(x: x + 4, y: y0 + Self.top + CGFloat(row) * Self.line, width: cw - 8, height: 19), day: day, event: e))
                    row += 1
                }
                if hidden > 0 {
                    items.append(MonthItem(kind: .more, rect: CGRect(x: x + 4, y: y0 + Self.top + CGFloat(room[c]) * Self.line, width: cw - 8, height: 19), day: day, text: "\(hidden) more"))
                }
            }
        }
    }

    /// A bar shows only where every day it crosses has room for its lane.
    static func fits(_ b: AllDayPlacement, _ room: [Int]) -> Bool {
        b.lane < (b.firstDay...b.lastDay).map { room[$0] }.min()!
    }

    /// Rows each day of a week gives to bars and events before its "n more" row (`fit` rows fit in a cell). A day that hides
    /// anything, including a bar that does not fit on a neighbouring day, keeps its last row for "n more".
    static func rooms(fit: Int, used: [Int], timed: [Int], bars: [AllDayPlacement]) -> [Int] {
        var room = (0..<used.count).map { used[$0] + timed[$0] > fit ? fit - 1 : fit }
        while true {
            var changed = false
            for b in bars where !fits(b, room) {
                for c in b.firstDay...b.lastDay where room[c] == fit { room[c] = fit - 1; changed = true }
            }
            if !changed { return room }
        }
    }
}

/// Month view: weekday row, then one row per week of the month. Day numbers open the day; a double-click on a day creates an all-day event.
struct MonthView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // The columns of the grid itself, so the headers follow the model's first weekday.
                let firstWeek = model.monthGrid.first ?? []
                ForEach(firstWeek.indices, id: \.self) { i in
                    Text(model.fmt.weekdayShort(firstWeek[i])).font(.ui(12)).foregroundStyle(Theme.fg2)
                        .padding(.leading, 12).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: 32)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.hair2).frame(height: 1) }
            GeometryReader { geo in
                MonthCanvas(size: geo.size, dark: scheme == .dark)
                    .id(model.periodID)
                    .transition(.periodSlide(model.navDirection))
                    .animation(Motion.base, value: model.periodID)
                    .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { model.gridState.monthFrame = $0 }
            }
            .clipped()
        }
        .overlay { GridDayListHost() }
    }
}

struct MonthCanvas: View {
    @Environment(AppModel.self) private var model
    let size: CGSize
    let dark: Bool
    @State private var hover: Int?

    var body: some View {
        let math = model.math
        let lay = model.gridState.monthCache.layout(for: model, size: size)
        let today = math.startOfDay(model.now)
        let month = model.visibleStart
        let selected = model.selectedEventID, draft = model.draftEventID
        let hovered = hover
        let m = model
        let now = model.now
        return Canvas { ctx, _ in
            ctx.withCGContext { cg in
                MonthPainter.draw(cg, lay: lay, dark: dark, math: math, month: month, today: today, selected: selected, draft: draft, hover: hovered, fmt: m.fmt,
                                  style: { e in m.style(for: e, dark: dark, now: now, selected: false, overlapping: false) })
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            if case .active(let p) = phase { hover = lay.items.lastIndex { $0.rect.contains(p) } } else { hover = nil }
        }
        .gesture(SpatialTapGesture(count: 1).onEnded { v in tap(v.location, lay, double: (NSApp.currentEvent?.clickCount ?? 1) >= 2) })
    }

    private func tap(_ p: CGPoint, _ lay: MonthLayout, double: Bool) {
        if let it = lay.items.last(where: { $0.rect.contains(p) }) {
            switch it.kind {
            case .number: model.go(to: it.day); model.setMode(.day); return
            case .more: model.openDayList(it.day); return
            case .bar, .timed:
                if let e = it.event { model.select(eventID: e.id, focusTitle: double) }
                return
            }
        }
        guard let c = lay.cell(p) else { return }
        // The second click of a double-click makes an all-day event; a click alone only dismisses.
        if double && model.selectedEventID == nil && model.draftEventID == nil { model.createAllDay(on: model.monthGrid[c.week][c.col]) } else { model.gridDismiss() }
    }
}

enum MonthPainter {
    @MainActor
    static func draw(_ cg: CGContext, lay: MonthLayout, dark: Bool, math: CalendarMath, month: Date, today: Date, selected: String?, draft: String?,
                     hover: Int?, fmt: Fmt, style: (CalendarEvent) -> EventStyle) {
        let ink = EventPainter.Ink.of(dark)
        cg.setFillColor(ink.hair)
        for w in 0..<lay.weeks - 1 { cg.fill(CGRect(x: 0, y: CGFloat(w + 1) * lay.cellHeight - 1, width: lay.size.width, height: 1)) }
        for c in 1..<7 { cg.fill(CGRect(x: CGFloat(c) * lay.cellWidth, y: 0, width: 1, height: lay.size.height)) }
        for (i, it) in lay.items.enumerated() {
            let r = it.rect
            let hovered = hover == i
            switch it.kind {
            case .number:
                let isToday = math.isSameDay(it.day, today)
                let out = !math.isSameMonth(it.day, month)
                let past = it.day < today
                if isToday {
                    cg.addPath(EventPainter.roundedPath(r, 11)); cg.setFillColor(ink.act); cg.fillPath()
                } else if hovered {
                    cg.addPath(EventPainter.roundedPath(r, 11)); cg.setFillColor(ink.hover); cg.fillPath()
                }
                let numColor = isToday ? ink.onAct : out ? ink.fg3 : past ? ink.fg2 : ink.fg
                let kind: TextCache.Kind = isToday ? .monthNumToday : .monthNum
                if math.day(it.day) == 1 {
                    let mon = fmt.monthShort(it.day)
                    let mw = EventPainter.text(cg, mon, .monthTitle, x: r.minX + 5, top: r.minY, box: r.height, color: isToday ? ink.onAct : out ? ink.fg3 : ink.fg2)
                    EventPainter.text(cg, "1", kind, x: r.minX + 5 + mw + 4, top: r.minY, box: r.height, color: numColor)
                } else {
                    let w = TextCache.line(it.text, kind).width
                    EventPainter.text(cg, it.text, kind, x: r.minX + max(5, (r.width - w) / 2), top: r.minY, box: r.height, color: numColor)
                }
            case .bar:
                guard let e = it.event else { continue }
                var s = style(e)
                s.isDark = dark
                let past = s.past
                let shape = EventPainter.chipPath(r, Radius.event, squareLeft: it.openLeft, squareRight: it.openRight)
                if e.id == draft {
                    cg.addPath(shape); cg.setFillColor(ink.actWash); cg.fillPath()
                    dashed(cg, r, ink)
                } else if e.id == selected {
                    cg.addPath(shape); cg.setFillColor(ink.actWash); cg.fillPath()
                    ring(cg, r, ink)
                } else {
                    cg.addPath(shape); cg.setFillColor((past ? s.palette.pastFillRGB : hovered ? s.palette.hoverFillRGB : s.palette.fillRGB).cg); cg.fillPath()
                }
                let color: CGColor = e.status == .declined || past ? ink.fg3 : e.id == draft ? ink.fg : s.palette.titleRGB.cg
                EventPainter.truncated(cg, e.title.isEmpty ? "New event" : e.title, .title, x: r.minX + 7, top: r.minY, box: r.height, color: color, maxWidth: r.width - 13, strike: e.status == .declined)
            case .timed:
                guard let e = it.event else { continue }
                let s = style(e)
                let shape = EventPainter.roundedPath(r, Radius.event)
                if e.id == draft { cg.addPath(shape); cg.setFillColor(ink.actWash); cg.fillPath(); dashed(cg, r, ink) }
                else if e.id == selected { cg.addPath(shape); cg.setFillColor(ink.actWash); cg.fillPath(); ring(cg, r, ink) }
                else if hovered { cg.addPath(shape); cg.setFillColor(ink.hover); cg.fillPath() }
                let dot = s.palette.barRGB.cg
                cg.setFillColor(s.past ? (dot.copy(alpha: 0.5) ?? dot) : dot)
                cg.fillEllipse(in: CGRect(x: r.minX + 7, y: r.midY - 3, width: 6, height: 6))
                let time = TextCache.time(fmt, minutes: math.minutesSinceMidnight(e.start))
                let tw = TextCache.line(time, .time).width
                EventPainter.text(cg, time, .time, x: r.maxX - 6 - tw, top: r.minY, box: r.height, color: ink.fg3)
                let tx = r.minX + 7 + 6 + 6
                let declined = e.status == .declined
                EventPainter.truncated(cg, e.title.isEmpty ? "New event" : e.title, .monthTitle, x: tx, top: r.minY, box: r.height,
                                       color: declined || s.past ? ink.fg3 : ink.fg, maxWidth: max(1, r.maxX - 6 - tw - 6 - tx), strike: declined)
            case .more:
                if hovered { cg.addPath(EventPainter.roundedPath(r, 5)); cg.setFillColor(ink.hover); cg.fillPath() }
                EventPainter.text(cg, it.text, .more, x: r.minX + 7, top: r.minY, box: r.height, color: hovered ? ink.fg : ink.fg3)
            }
        }
    }

    private static func ring(_ cg: CGContext, _ r: CGRect, _ ink: EventPainter.Ink) {
        cg.addPath(EventPainter.roundedPath(r.insetBy(dx: -0.75, dy: -0.75), Radius.event + 0.75)); cg.setStrokeColor(ink.ring); cg.setLineWidth(1.5); cg.strokePath()
    }

    private static func dashed(_ cg: CGContext, _ r: CGRect, _ ink: EventPainter.Ink) {
        cg.saveGState()
        cg.addPath(EventPainter.roundedPath(r.insetBy(dx: 0.75, dy: 0.75), Radius.event - 0.75))
        cg.setStrokeColor(ink.ring); cg.setLineWidth(1.5); cg.setLineDash(phase: 0, lengths: [4.5, 3]); cg.strokePath()
        cg.restoreGState()
    }
}
