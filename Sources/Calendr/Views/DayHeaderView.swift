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
                        let x = x0 + 12
                        let w1 = EventPainter.text(cg, wd, wdKind, x: x, top: 0, box: size.height, color: today ? ink.fg : past ? ink.fg3 : ink.fg2)
                        let nx = x + w1 + 6
                        if today {
                            // `.dh .c.today .n`: the accent pill, radius 6, 1 pt above and below the text and 6 pt either side.
                            let nw = TextCache.line(num, numKind).width
                            let pill = CGRect(x: nx, y: (size.height - EventPainter.lineHeight) / 2 - 1, width: nw + 12, height: EventPainter.lineHeight + 2)
                            cg.addPath(EventPainter.roundedPath(pill, Radius.row)); cg.setFillColor(ink.act); cg.fillPath()
                            EventPainter.text(cg, num, numKind, x: pill.minX + 6, top: 0, box: size.height, color: ink.onAct)
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
            Text("all-day").font(.small).tracking(0.19).foregroundStyle(Theme.fg3)
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
                            AllDayPainter.chip(cg, title: e.title, reply: s.reply, rect: chipRect(p, dw), style: s, openLeft: p.clippedLeft, openRight: p.clippedRight)
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
    /// An all-day chip (mockup-v4 `.adi`): 18 pt, radius 6, fill and bar, the title in 11.5 / 500; square ends where it continues past
    /// the visible range. Replies (round 2 `.adi.st-*`): not answered is hollow with a 1.5 pt dashed `dash` outline, declined is fill
    /// 32 percent over the window colour with struck fg3 text, maybe looks accepted. Selected: the bg and fg rings of a block.
    @MainActor
    static func chip(_ cg: CGContext, title raw: String, reply: EventReply, rect r: CGRect, style: EventStyle, openLeft: Bool, openRight: Bool) {
        let ink = EventPainter.Ink.of(style.isDark)
        let path = { (inset: CGFloat) in EventPainter.chipPath(r.insetBy(dx: inset, dy: inset), Radius.row - inset, squareLeft: openLeft, squareRight: openRight) }
        let shape = path(0)
        var c = style.palette.colors(reply: reply == .maybe ? .accepted : reply, past: style.past)
        var dashed = false
        if reply == .notAnswered { c.outline = nil; dashed = true }
        if reply == .declined { c.fill = style.palette.bgRGB.mixed(with: style.palette.fillRGB, 0.32); c.barAlpha = 1 }
        if style.hovered { c.fill = Palettes.brighter(c.fill) }
        cg.saveGState()
        defer { cg.restoreGState() }
        EventPainter.rings(cg, path, selected: style.selected && !style.draft, cut: false, ink: ink)
        if style.draft {
            cg.addPath(shape); cg.setFillColor(ink.actWash); cg.fillPath()
            cg.saveGState()
            cg.addPath(path(0.75)); cg.setStrokeColor(ink.ring); cg.setLineWidth(1.5); cg.setLineDash(phase: 0, lengths: [4.5, 3]); cg.strokePath()
            cg.restoreGState()
        } else {
            cg.addPath(shape); cg.setFillColor(c.fill.cg); cg.fillPath()
            if dashed {
                cg.saveGState()
                cg.addPath(path(0.75)); cg.setStrokeColor(style.palette.dashRGB.cg); cg.setLineWidth(1.5); cg.setLineDash(phase: 0, lengths: [4.5, 3]); cg.strokePath()
                cg.restoreGState()
            }
        }
        cg.addPath(shape); cg.clip()
        if !style.draft && !openLeft {
            let bar = CGRect(x: r.minX + 3, y: r.minY + 3, width: 3, height: r.height - 6)
            cg.addPath(EventPainter.roundedPath(bar, Radius.bar)); cg.setFillColor(c.bar.cg.copy(alpha: c.barAlpha) ?? c.bar.cg); cg.fillPath()
        }
        let title = raw.isEmpty ? (style.draft ? "New event" : "(No title)") : raw
        let color: CGColor = style.draft || dashed ? ink.fg : c.title.cg
        let x = r.minX + 10
        EventPainter.truncated(cg, title, .title, x: x, top: r.minY, box: r.height, color: color, maxWidth: max(1, r.maxX - 7 - x), strike: c.strike && !style.draft)
    }
}
