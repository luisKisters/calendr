import SwiftUI
import AppKit
import CalendrKit

/// Inline day header ("Tue 29"), one Canvas: 38 pt, text 11 pt into the column on the same rail as event titles.
/// Today's numeral sits in an inverted pill. A click opens that day in day view.
struct DayHeaderView: View {
    static let height: CGFloat = 38
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var hover: Int?

    var body: some View {
        let days = model.visibleDays
        let math = model.math
        let fmt = model.fmt
        let todayStart = math.startOfDay(model.now)
        let dark = scheme == .dark
        let hovered = hover
        let gw = Theme.gutterWidth
        GeometryReader { geo in
            let colW = (geo.size.width - gw) / CGFloat(max(1, days.count))
            Canvas { ctx, size in
                let ink = EventPainter.Ink.of(dark)
                ctx.withCGContext { cg in
                    for (i, d) in days.enumerated() {
                        let x0 = gw + CGFloat(i) * colW
                        if hovered == i {
                            cg.addPath(EventPainter.roundedPath(CGRect(x: x0, y: 0, width: colW, height: size.height), Radius.row)); cg.setFillColor(ink.hover); cg.fillPath()
                        }
                        let today = math.isSameDay(d, todayStart)
                        let past = d < todayStart
                        let wd = fmt.weekdayShort(d), num = "\(math.day(d))"
                        let wdKind: TextCache.Kind = today ? .headerToday : past ? .headerPast : .header
                        let numKind: TextCache.Kind = today ? .headerNumToday : past ? .headerPast : .headerNum
                        let x = x0 + 11
                        let w1 = EventPainter.text(cg, wd, wdKind, x: x, top: 0, box: size.height, color: today ? ink.fg : past ? ink.fg3 : ink.fg2)
                        let nx = x + w1 + 6
                        if today {
                            let nw = TextCache.line(num, numKind).width
                            let pill = CGRect(x: nx - 1, y: (size.height - 22) / 2, width: max(22, nw + 10), height: 22)
                            cg.addPath(EventPainter.roundedPath(pill, 11)); cg.setFillColor(ink.act); cg.fillPath()
                            EventPainter.text(cg, num, numKind, x: pill.midX - nw / 2, top: 0, box: size.height, color: ink.onAct)
                        } else {
                            EventPainter.text(cg, num, numKind, x: nx, top: 0, box: size.height, color: past ? ink.fg3 : ink.fg)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                if case .active(let p) = phase, p.x >= gw { hover = min(days.count - 1, Int((p.x - gw) / colW)) } else { hover = nil }
            }
            .onTapGesture(coordinateSpace: .local) { p in
                guard p.x >= gw else { return }
                let i = min(days.count - 1, Int((p.x - gw) / colW))
                model.go(to: days[i])
                model.setMode(.day)
            }
            .help(hover.map { fmt.inspectorDate(days[min($0, days.count - 1)]) } ?? "")
        }
        .frame(height: Self.height)
        .id(model.periodID)
        .transition(.periodSlide(model.navDirection))
        .animation(Motion.base, value: model.periodID)
        .animation(Motion.fast, value: hover)
        .clipped()
    }
}

/// All-day lane: 23 pt rows of 21 pt chips (tint and bar). At most three rows: with more, the third becomes "n more" per day,
/// unless the selected or new event sits there (`AppModel.allDayFold`). "n more" opens the day list.
struct AllDayView: View {
    static let row: CGFloat = 23
    static let maxRows = 3
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var hoverMore: Int?

    var body: some View {
        let n = max(1, model.visibleDays.count)
        let all = model.layout.allDay
        let fold = model.allDayFold
        let rows = fold.map { $0 + 1 } ?? all.laneCount
        let height = rows == 0 ? 0 : CGFloat(rows) * Self.row + 3
        let dark = scheme == .dark
        HStack(spacing: 0) {
            Text("all-day").font(.ui(9.5)).tracking(0.19).foregroundStyle(Theme.fg3)
                .frame(width: Theme.gutterWidth - 10, height: 22, alignment: .trailing)
                .padding(.trailing, 10)
                .frame(maxHeight: .infinity, alignment: .top)
            GeometryReader { geo in
                let dw = geo.size.width / CGFloat(n)
                let chips = all.placements.filter { fold == nil || $0.lane < fold! }
                let hidden = fold.map { all.collapsed(maxLanes: $0).hiddenPerDay } ?? []
                let hovered = hoverMore
                Canvas { ctx, _ in
                    ctx.withCGContext { cg in
                        for p in chips {
                            guard let e = model.layout.allDayEvents[p.id] else { continue }
                            var s = model.style(for: e, dark: dark, now: model.now, selected: e.id == model.selectedEventID, overlapping: false)
                            s.isDark = dark
                            s.draft = e.id == model.draftEventID
                            AllDayPainter.chip(cg, title: e.title, status: e.status, rect: chipRect(p, dw), style: s, openLeft: p.clippedLeft, openRight: p.clippedRight)
                        }
                        let ink = EventPainter.Ink.of(dark)
                        for (d, count) in hidden.enumerated() where count > 0 {
                            let r = moreRect(d, fold!, dw)
                            if hovered == d { cg.addPath(EventPainter.roundedPath(r, Radius.event)); cg.setFillColor(ink.hover); cg.fillPath() }
                            EventPainter.text(cg, "\(count) more", .more, x: r.minX + 10, top: r.minY, box: r.height, color: hovered == d ? ink.fg : ink.fg3)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    var over: Int?
                    if case .active(let p) = phase, let f = fold {
                        let d = Int(p.x / dw)
                        if hidden.indices.contains(d), hidden[d] > 0, moreRect(d, f, dw).contains(p) { over = d }
                    }
                    if over != hoverMore { hoverMore = over }
                }
                .gesture(SpatialTapGesture(count: 1).onEnded { v in
                    let p = v.location
                    if let c = chips.last(where: { chipRect($0, dw).contains(p) }), let e = model.layout.allDayEvents[c.id] {
                        model.select(eventID: e.id, focusTitle: NSApp.currentEvent?.clickCount == 2)
                    } else if let f = fold, hidden.indices.contains(Int(p.x / dw)), hidden[Int(p.x / dw)] > 0, moreRect(Int(p.x / dw), f, dw).contains(p) {
                        model.openDayList(model.visibleDays[Int(p.x / dw)])
                    } else {
                        model.gridDismiss()
                    }
                })
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { model.gridState.allDayFrame = $0 }
            }
            .id(model.periodID)
            .transition(.periodSlide(model.navDirection))
            .animation(Motion.base, value: model.periodID)
        }
        .frame(height: height)
        .clipped()
    }

    /// `.ad__more`: the day's slot in the fold row.
    private func moreRect(_ d: Int, _ fold: Int, _ dw: CGFloat) -> CGRect {
        CGRect(x: CGFloat(d) * dw + 1, y: CGFloat(fold) * Self.row, width: dw - 3, height: 21)
    }

    private func chipRect(_ p: AllDayPlacement, _ dw: CGFloat) -> CGRect {
        CGRect(x: CGFloat(p.firstDay) * dw + 1, y: CGFloat(p.lane) * Self.row, width: max(4, CGFloat(p.span) * dw - 3), height: 21)
    }
}

enum AllDayPainter {
    /// An all-day chip (`.ev--ad`): tint and bar, title only; square ends where it continues past the visible range.
    @MainActor
    static func chip(_ cg: CGContext, title raw: String, status: ResponseStatus, rect r: CGRect, style: EventStyle, openLeft: Bool, openRight: Bool) {
        let pal = style.palette
        let ink = EventPainter.Ink.of(style.isDark)
        let shape = EventPainter.chipPath(r, Radius.event, squareLeft: openLeft, squareRight: openRight)
        let declined = status == .declined && !style.draft
        cg.saveGState()
        defer { cg.restoreGState() }
        if style.draft {
            cg.addPath(shape); cg.setFillColor(ink.actWash); cg.fillPath()
            cg.saveGState()
            cg.addPath(EventPainter.chipPath(r.insetBy(dx: 0.75, dy: 0.75), Radius.event - 0.75, squareLeft: openLeft, squareRight: openRight))
            cg.setStrokeColor(ink.ring); cg.setLineWidth(1.5); cg.setLineDash(phase: 0, lengths: [4.5, 3]); cg.strokePath()
            cg.restoreGState()
        } else if declined {
            cg.addPath(shape); cg.setFillColor(ink.bg); cg.fillPath()
            cg.addPath(EventPainter.chipPath(r.insetBy(dx: 0.5, dy: 0.5), Radius.event - 0.5, squareLeft: openLeft, squareRight: openRight))
            cg.setStrokeColor(pal.barRGB.cg.copy(alpha: 0.4) ?? pal.barRGB.cg); cg.setLineWidth(1); cg.strokePath()
        } else {
            let fill = style.past && !style.selected ? pal.pastFillRGB : style.selected ? pal.hoverFillRGB : pal.fillRGB
            if style.selected {
                cg.saveGState()
                cg.setShadow(offset: CGSize(width: 0, height: 8), blur: 22, color: ink.liftShadow)
                cg.addPath(shape); cg.setFillColor(fill.cg); cg.fillPath()
                cg.restoreGState()
                cg.addPath(EventPainter.chipPath(r.insetBy(dx: -0.75, dy: -0.75), Radius.event + 0.75, squareLeft: openLeft, squareRight: openRight))
                cg.setStrokeColor(ink.ring); cg.setLineWidth(1.5); cg.strokePath()
            }
            cg.addPath(shape); cg.setFillColor(fill.cg); cg.fillPath()
        }
        cg.addPath(shape); cg.clip()
        if !style.draft && !declined && !openLeft {
            let bar = CGRect(x: r.minX + 3, y: r.minY + 3, width: 3, height: r.height - 6)
            cg.saveGState()
            cg.addPath(EventPainter.roundedPath(bar, 1.5)); cg.clip()
            cg.setFillColor(style.past && !style.selected ? (pal.barRGB.cg.copy(alpha: 0.5) ?? pal.barRGB.cg) : pal.barRGB.cg)
            if status == .tentative {
                var y = bar.minY
                while y < bar.maxY { cg.fill(CGRect(x: bar.minX, y: y, width: 3, height: min(3, bar.maxY - y))); y += 6 }
            } else { cg.fill(bar) }
            cg.restoreGState()
        }
        let title = raw.isEmpty ? (style.draft ? "New event" : "(No title)") : raw
        let color: CGColor = style.draft || style.selected ? ink.fg : declined ? ink.fg3 : style.past ? ink.pastTitle : pal.titleRGB.cg
        let x = r.minX + (style.draft ? 8 : 11)
        EventPainter.truncated(cg, title, declined ? .titleMedium : .title, x: x, top: r.minY + 3, box: 15, color: color, maxWidth: max(1, r.maxX - 6 - x), strike: declined)
    }
}
