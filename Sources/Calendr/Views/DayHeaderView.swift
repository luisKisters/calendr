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
                    // `.dh { border-bottom: 1px solid var(--hair) }`
                    cg.setFillColor(ink.hair); cg.fill(CGRect(x: 0, y: size.height - 1, width: size.width, height: 1))
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

/// All-day section, the mockup-v4 "mix" (`allDay()` :1215): 18 pt chips in 21 pt lanes. Collapsed it shows two lanes and, per day,
/// "+N more" in the third; the gutter's expand button (or "+N more") shows every lane, scrolling past 4.5 lanes, and collapse goes back.
struct AllDayView: View {
    /// Chip height and lane pitch (`--adh` 18 + 3 pt gap).
    static let chip: CGFloat = 18
    static let row: CGFloat = 21
    static let topPad: CGFloat = 4
    static let bottomPad: CGFloat = 5
    /// Lanes before "+N more": two lanes and the "+N more" row.
    static let shownLanes = 2
    static let maxRows = shownLanes + 1
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var hoverToggle = false
    @State private var scroll = ScrollPosition(y: 0)

    /// Height of `rows` grid rows (the content, without scrolling).
    static func contentHeight(rows: Int) -> CGFloat { rows == 0 ? 0 : topPad + CGFloat(rows) * row - 3 + bottomPad }
    /// The expanded section: min(lanes, 4.5) lanes and the padding; taller content scrolls.
    static func expandedHeight(lanes: Int) -> CGFloat { min(CGFloat(lanes), 4.5) * row + 9 }

    var body: some View {
        let n = max(1, model.visibleDays.count)
        let all = model.layout.allDay
        let expanded = model.gridState.allDayExpanded && all.laneCount > Self.shownLanes
        let fold = model.allDayFold
        let rows = fold.map { $0 + 1 } ?? all.laneCount
        let height = all.laneCount == 0 ? 0 : expanded ? Self.expandedHeight(lanes: all.laneCount) : Self.contentHeight(rows: rows)
        let dark = scheme == .dark
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                if expanded || fold != nil {
                    Button { model.toggleAllDayExpanded() } label: {
                        AllDayToggleIcon(expand: !expanded).stroke(hoverToggle ? Theme.fg : Theme.fg2,
                                                                     style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                            .frame(width: Dim.iconGlyphSmall, height: Dim.iconGlyphSmall)
                            .frame(width: Dim.iconButtonSmall, height: Dim.iconButtonSmall)
                            .background(RoundedRectangle(cornerRadius: Radius.row).fill(hoverToggle ? Theme.hover : .clear))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { hoverToggle = $0 }
                    .help(expanded ? "Collapse all-day section" : "Expand all-day section")
                }
                Text("all-day").font(.small).tracking(0.19).foregroundStyle(Theme.fg3)
            }
            .padding(.top, 5)
            .frame(width: Theme.gutterWidth)
            .frame(maxHeight: .infinity, alignment: .top)
            GeometryReader { geo in
                let dw = geo.size.width / CGFloat(n)
                let content = Self.contentHeight(rows: expanded ? all.laneCount : rows)
                let lanes = fold ?? Int.max
                let chips = all.placements.filter { $0.lane < lanes }
                let hidden = fold.map { all.collapsed(maxLanes: $0).hiddenPerDay } ?? []
                let hovered = model.gridState.pointer.hoveredAllDayMore
                let canvas = Canvas { ctx, size in
                    ctx.withCGContext { cg in
                        let ink = EventPainter.Ink.of(dark)
                        cg.setFillColor(ink.hair)
                        for d in 0..<n { cg.fill(CGRect(x: CGFloat(d) * dw, y: 0, width: 1, height: size.height)) }
                        for p in chips {
                            guard let e = model.layout.allDayEvents[p.id] else { continue }
                            var s = model.style(for: e, dark: dark, now: model.now, selected: e.id == model.selectedEventID, overlapping: false)
                            s.isDark = dark
                            s.draft = e.id == model.draftEventID
                            AllDayPainter.chip(cg, title: e.title, reply: s.reply, rect: Self.chipRect(p, dw), style: s, openLeft: p.clippedLeft, openRight: p.clippedRight)
                        }
                        for (d, count) in hidden.enumerated() where count > 0 {
                            let r = Self.moreRect(d, fold!, dw)
                            let hot = hovered == d
                            if hot { cg.addPath(EventPainter.roundedPath(r, Radius.row)); cg.setFillColor(ink.hover); cg.fillPath() }
                            EventPainter.text(cg, "+\(count) more", .more, x: r.minX + 10, top: r.minY, box: r.height, color: hot ? ink.fg : ink.fg2)
                        }
                    }
                }
                .frame(width: geo.size.width, height: max(content, geo.size.height))
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    var over: Int?
                    if case .active(let p) = phase, let f = fold {
                        let d = Int(p.x / dw)
                        if hidden.indices.contains(d), hidden[d] > 0, Self.moreRect(d, f, dw).contains(p) { over = d }
                    }
                    if over != model.gridState.pointer.hoveredAllDayMore { model.gridState.pointer.hoveredAllDayMore = over }
                }
                .gesture(SpatialTapGesture(count: 1).onEnded { v in
                    let p = v.location
                    if let c = chips.last(where: { Self.chipRect($0, dw).contains(p) }), let e = model.layout.allDayEvents[c.id] {
                        model.select(eventID: e.id, focusTitle: NSApp.currentEvent?.clickCount == 2)
                    } else if let f = fold, hidden.indices.contains(Int(p.x / dw)), hidden[Int(p.x / dw)] > 0, Self.moreRect(Int(p.x / dw), f, dw).contains(p) {
                        model.toggleAllDayExpanded()
                    } else {
                        model.gridDismiss()
                    }
                })
                Group {
                    if expanded {
                        ScrollView(.vertical, showsIndicators: true) { canvas }.scrollPosition($scroll)
                    } else {
                        canvas
                    }
                }
                    .onChange(of: expanded) { _, _ in scroll = ScrollPosition(y: 0) }
                    .onChange(of: model.gridState.allDayScrollTick) { _, _ in scroll = ScrollPosition(y: model.gridState.allDayScrollTarget) }
                    .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { model.gridState.allDayFrame = $0 }
            }
            .id(model.periodID)
            .transition(.periodSlide(model.navDirection))
            .animation(Motion.base, value: model.periodID)
        }
        .frame(height: height)
        .clipped()
    }

    /// `.ad .more`: the day's slot in the third row.
    static func moreRect(_ d: Int, _ fold: Int, _ dw: CGFloat) -> CGRect {
        CGRect(x: CGFloat(d) * dw + 2, y: topPad + CGFloat(fold) * row, width: dw - 5, height: chip)
    }

    /// `.adi`: margin 0 3 0 2 inside its grid columns.
    static func chipRect(_ p: AllDayPlacement, _ dw: CGFloat) -> CGRect {
        CGRect(x: CGFloat(p.firstDay) * dw + 2, y: topPad + CGFloat(p.lane) * row, width: max(4, CGFloat(p.span) * dw - 5), height: chip)
    }
}

/// The mockup's `expand` (two chevrons apart) and `collapse` (two chevrons together) glyphs, 16 unit box.
struct AllDayToggleIcon: Shape {
    var expand: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        let k = r.width / 16
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * k, y: r.minY + y * k) }
        if expand {
            p.move(to: pt(5, 6)); p.addLine(to: pt(8, 3)); p.addLine(to: pt(11, 6))
            p.move(to: pt(5, 10)); p.addLine(to: pt(8, 13)); p.addLine(to: pt(11, 10))
        } else {
            p.move(to: pt(5, 3)); p.addLine(to: pt(8, 6)); p.addLine(to: pt(11, 3))
            p.move(to: pt(5, 13)); p.addLine(to: pt(8, 10)); p.addLine(to: pt(11, 13))
        }
        return p
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
