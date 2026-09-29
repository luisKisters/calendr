import SwiftUI
import CalendrKit

/// Period change: content slides 36 pt in the direction of travel while fading in (180 ms). The old content is removed at once,
/// so nothing is laid out twice during the animation.
struct SlideFade: ViewModifier {
    var x: CGFloat
    var opacity: Double
    func body(content: Content) -> some View { content.offset(x: x).opacity(opacity) }
}

extension AnyTransition {
    static func periodSlide(_ direction: Int) -> AnyTransition {
        .asymmetric(insertion: .modifier(active: SlideFade(x: CGFloat(direction) * 36, opacity: 0), identity: SlideFade(x: 0, opacity: 1)), removal: .identity)
    }
}

struct CenterView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView().frame(height: Theme.toolbarHeight)
            if model.authState != .authorized {
                AccessEmptyState()
            } else if model.viewMode == .month {
                MonthView()
            } else {
                DayHeaderView().frame(height: Dim.dayHeaderHeight)
                AllDayView()
                TimeGridView()
            }
        }
        .background(Theme.ink900)
    }
}

struct ToolbarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                let parts = model.headerParts
                Text(parts.month).font(.calTitle).tracking(-0.4).foregroundStyle(Theme.paper)
                Text(parts.year).font(.calMono(20, .medium)).tracking(-0.6).foregroundStyle(Theme.haze).padding(.leading, 6)
                if model.viewMode != .month && model.authState == .authorized {
                    Text(model.weekLabel).font(.calMono(11)).foregroundStyle(Theme.haze)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.ink700))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.hair, lineWidth: 1))
                        .padding(.leading, 9)
                }
            }
            .id(model.headerTitle)
            .transition(.opacity)
            .animation(Motion.base, value: model.headerTitle)
            .padding(.leading, model.sidebarVisible ? 0 : 96)
            .animation(Motion.slow, value: model.sidebarVisible)
            Spacer(minLength: 0)
            Avatar().frame(width: 26, height: 26).padding(.trailing, 4)
            Segmented(options: [(ViewMode.day, "Day"), (ViewMode.week, "Week"), (ViewMode.month, "Month")],
                      selection: model.viewMode.baseMode) { model.setMode($0) }
            TodayButton()
            HStack(spacing: 2) {
                IconButton(name: "chevron.left", size: 13) { model.previous() }
                IconButton(name: "chevron.right", size: 13) { model.next() }
            }
            if !model.rightPanelVisible {
                IconButton(name: "sidebar.right", size: 15) { model.toggleRightPanel() }
            }
        }
        .padding(.leading, 20).padding(.trailing, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct TodayButton: View {
    @Environment(AppModel.self) private var model
    @State private var hover = false
    var body: some View {
        Button { model.goToToday() } label: {
            Text("Today").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.paper)
                .padding(.horizontal, 14).frame(height: 30)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(hover ? Theme.ink600 : Theme.ink700))
                .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Theme.hairStrong, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

extension ViewMode {
    /// Custom N-day ranges map onto Week in the segmented control.
    var baseMode: ViewMode { if case .custom = self { return .week }; return self }
}

struct Avatar: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: "#E9DDF7"))
            Circle().fill(Color(hex: "#C98F6B")).frame(width: 12.5, height: 12.5).offset(y: -1.5)
            Capsule().fill(Color(hex: "#3b2418")).frame(width: 12, height: 6).offset(y: -6)
            Ellipse().fill(Color(hex: "#1a1a1a")).frame(width: 18, height: 10).offset(y: 10)
        }
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Theme.ink600, lineWidth: 1.5))
    }
}

/// The day header row is one Canvas (14 SwiftUI Text views with backgrounds cost ~9 ms per week change).
struct DayHeaderView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let days = model.visibleDays
        let math = model.math
        let fmt = model.fmt
        let now = model.now
        let todayStart = math.startOfDay(now)
        let gmt = fmt.gmtLabel(now)
        let dark = scheme == .dark
        Canvas { ctx, size in
            let ink = EventPainter.Ink.of(dark)
            ctx.withCGContext { cg in
                let gw = Theme.gutterWidth
                let gl = TextCache.line(gmt, .hour).width
                _ = EventPainter.text(cg, gmt, .hour, x: gw - 8 - gl, top: size.height - 8 - 13, box: 13, color: ink.hazeDim)
                let colW = (size.width - gw) / CGFloat(max(1, days.count))
                for (i, d) in days.enumerated() {
                    let today = math.isSameDay(d, now)
                    let past = d < todayStart
                    let dow = fmt.weekdayShort(d).uppercased()
                    let num = "\(math.day(d))"
                    let w1 = TextCache.line(dow, .micro).width + 0.63 * CGFloat(dow.count)
                    let w2 = TextCache.line(num, .badge).width
                    let boxW = max(26, w2 + 8)
                    let total = w1 + 7 + boxW
                    let x0 = gw + CGFloat(i) * colW + (colW - total) / 2
                    let cy = size.height / 2
                    _ = EventPainter.text(cg, dow, .micro, x: x0, top: cy - 7, box: 14, color: today ? RGB(hex: dark ? "#A78BFA" : "#6D28D9").cg : (past ? ink.hazeDim : ink.haze), kern: 0.63)
                    let bx = x0 + w1 + 7
                    if today {
                        cg.addPath(EventPainter.roundedPath(CGRect(x: bx - 3, y: cy - 14, width: boxW + 6, height: 28), 10)); cg.setFillColor(ink.act.copy(alpha: dark ? 0.18 : 0.12) ?? ink.act); cg.fillPath()
                        cg.addPath(EventPainter.roundedPath(CGRect(x: bx, y: cy - 11, width: boxW, height: 22), 7)); cg.setFillColor(ink.act); cg.fillPath()
                    }
                    _ = EventPainter.text(cg, num, .badge, x: bx + (boxW - w2) / 2, top: cy - 11, box: 22, color: today ? CGColor(gray: 1, alpha: 1) : (past ? ink.hazeDim : ink.paper))
                }
            }
        }
        .frame(height: Dim.dayHeaderHeight)
        .id(model.periodID)
        .transition(.periodSlide(model.navDirection))
        .animation(Motion.base, value: model.periodID)
        .clipped()
        .overlay(alignment: .bottom) { Hairline() }
    }
}

struct AllDayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let n = max(1, model.visibleDays.count)
        let lanes = model.layout.allDay.laneCount
        let collapsed = model.allDayCollapsed
        let collapsedResult = model.layout.allDay.collapsed(maxLanes: 1)
        let rows = max(1, collapsed ? (lanes > 1 ? 2 : 1) : lanes)
        let height = CGFloat(rows) * 22 + 8
        HStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Button { model.allDayCollapsed.toggle() } label: {
                    ChevronPair(outward: collapsed).stroke(Theme.hazeDim, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)).frame(width: 14, height: 14)
                        .frame(width: 22, height: 22).contentShape(Rectangle())
                }.buttonStyle(PressStyle()).padding(.trailing, 6).padding(.top, 3)
            }.frame(width: Theme.gutterWidth, height: height, alignment: .topTrailing)
            GeometryReader { geo in
                let dw = geo.size.width / CGFloat(n)
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(0..<n, id: \.self) { i in
                            Rectangle().fill(model.todayIndex == i ? Theme.actSoft : Color.clear).frame(maxWidth: .infinity)
                                .overlay(alignment: .leading) { Rectangle().fill(Theme.hair).frame(width: 1) }
                        }
                    }
                    ZStack(alignment: .topLeading) {
                        let placements = collapsed ? collapsedResult.visible : model.layout.allDay.placements
                        ForEach(placements, id: \.id) { p in
                            if let e = model.layout.allDayEvents[p.id] {
                                let x = CGFloat(p.firstDay) * dw + Double(3)
                                let w = CGFloat(p.span) * dw - 11
                                AllDayChip(title: e.title.isEmpty ? "(No title)" : e.title, width: max(8, w),
                                           style: model.style(for: e, dark: scheme == .dark, now: model.now, selected: model.selectedEventID == e.id, faded: false, overlapping: false),
                                           isTask: e.kind == .task, done: model.isDone(e.id), height: 19,
                                           onCheck: { model.toggleTask(e.id) })
                                    .offset(x: x, y: 4 + CGFloat(p.lane) * 22)
                                    .onTapGesture { model.select(eventID: e.id, focusTitle: NSApp.currentEvent?.clickCount == 2) }
                            }
                        }
                        if collapsed {
                            ForEach(0..<n, id: \.self) { i in
                                if collapsedResult.hiddenPerDay[i] > 0 {
                                    Text("+\(collapsedResult.hiddenPerDay[i]) more").font(.system(size: 11)).foregroundStyle(Theme.haze)
                                        .offset(x: CGFloat(i) * dw + 8, y: 4 + 22)
                                }
                            }
                        }
                    }
                    .id(model.periodID)
                    .transition(.periodSlide(model.navDirection))
                }
                .animation(Motion.base, value: model.periodID)
                .clipped()
            }.frame(height: height)
        }
        .frame(height: height)
        .animation(Motion.base, value: collapsed)
        .overlay(alignment: .bottom) { Hairline() }
        .clipped()
    }
}

/// Layout of the month grid, shared by drawing and hit testing.
struct MonthGeometry {
    var size: CGSize
    var cellWidth: CGFloat { size.width / 7 }
    var cellHeight: CGFloat { size.height / 6 }
    static let chipHeight: CGFloat = 17
    static let chipPitch: CGFloat = 19
    static let headerHeight: CGFloat = 23        // day number row incl. top padding

    func cellRect(_ i: Int) -> CGRect { CGRect(x: CGFloat(i % 7) * cellWidth, y: CGFloat(i / 7) * cellHeight, width: cellWidth, height: cellHeight) }
    var maxChips: Int { max(1, Int((cellHeight - 28) / Self.chipPitch)) }
    func shownCount(_ n: Int) -> Int { n > maxChips ? maxChips - 1 : n }
    func chipRect(cell i: Int, index k: Int) -> CGRect {
        let c = cellRect(i)
        return CGRect(x: c.minX + 5, y: c.minY + 4 + Self.headerHeight + 2 + CGFloat(k) * Self.chipPitch, width: c.width - 10, height: Self.chipHeight)
    }
    func hit(_ p: CGPoint, counts: [Int]) -> (cell: Int, chip: Int?)? {
        guard p.x >= 0, p.y >= 0, p.x < size.width, p.y < size.height else { return nil }
        let i = min(41, Int(p.y / cellHeight) * 7 + Int(p.x / cellWidth))
        for k in 0..<shownCount(counts[i]) where chipRect(cell: i, index: k).contains(p) { return (i, k) }
        return (i, nil)
    }
}

/// The month grid is one Canvas (day numbers, chips, "+N more"); a tap gesture resolves cell/chip through `MonthGeometry`.
struct MonthView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(Fmt.weekdayShort[(model.math.calendar.firstWeekday - 1 + i) % 7].uppercased()).font(.calMicro).tracking(0.63)
                        .foregroundStyle(Theme.haze).frame(maxWidth: .infinity)
                }
            }
            .frame(height: 30)
            .overlay(alignment: .bottom) { Hairline() }
            GeometryReader { geo in
                MonthCanvas(size: geo.size, dark: scheme == .dark)
                    .id(model.periodID)
                    .transition(.periodSlide(model.navDirection))
                    .animation(Motion.base, value: model.periodID)
            }
            .clipped()
        }
    }
}

struct MonthCanvas: View {
    @Environment(AppModel.self) private var model
    let size: CGSize
    let dark: Bool

    var body: some View {
        let geo = MonthGeometry(size: size)
        let grid = model.monthGrid
        let events = model.monthEvents
        let math = model.math
        let now = model.now
        let today = math.startOfDay(now)
        let visibleStart = model.visibleStart
        let selected = model.selectedEventID
        let selectedDay = model.selectedSlot.map { math.startOfDay($0) }
        let fmt = model.fmt
        let m = model
        let done = model.completedTasks
        let counts = events.map(\.count)
        return Canvas { ctx, sz in
            ctx.withCGContext { cg in
                MonthPainter.draw(cg, geo: geo, dark: dark, grid: grid, events: events, math: math, today: today, visibleStart: visibleStart,
                                  selected: selected, selectedDay: selectedDay, done: done, fmt: fmt, style: { e in m.style(for: e, dark: dark, now: now, selected: false, faded: false, overlapping: false) })
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, coordinateSpace: .local) { p in
            if let h = geo.hit(p, counts: counts), h.chip == nil { model.go(to: grid[h.cell / 7][h.cell % 7]); model.setMode(.day) }
        }
        .onTapGesture(coordinateSpace: .local) { p in
            guard let h = geo.hit(p, counts: counts) else { return }
            if let k = h.chip {
                let e = events[h.cell][k]
                let r = geo.chipRect(cell: h.cell, index: k)
                if e.kind == .task, p.x < r.minX + 20 { model.toggleTask(e.id) } else { model.select(eventID: e.id) }
            }
            else { model.deselect(); model.selectedSlot = math.date(on: grid[h.cell / 7][h.cell % 7], minutes: 9 * 60) }
        }
    }
}

enum MonthPainter {
    @MainActor
    static func draw(_ cg: CGContext, geo: MonthGeometry, dark: Bool, grid: [[Date]], events: [[CalendarEvent]], math: CalendarMath, today: Date,
                     visibleStart: Date, selected: String?, selectedDay: Date?, done: Set<String>, fmt: Fmt, style: (CalendarEvent) -> EventStyle) {
        let ink = EventPainter.Ink.of(dark)
        cg.setStrokeColor(ink.hair); cg.setLineWidth(1)
        for i in 0..<42 {
            let r = geo.cellRect(i)
            cg.move(to: CGPoint(x: r.maxX - 0.5, y: r.minY)); cg.addLine(to: CGPoint(x: r.maxX - 0.5, y: r.maxY))
            cg.move(to: CGPoint(x: r.minX, y: r.maxY - 0.5)); cg.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 0.5))
        }
        cg.strokePath()
        for i in 0..<42 {
            let d = grid[i / 7][i % 7]
            let r = geo.cellRect(i)
            let other = !math.isSameMonth(d, visibleStart)
            let isToday = math.isSameDay(d, today)
            let past = math.startOfDay(d) < today
            if let sd = selectedDay, math.isSameDay(sd, d) { cg.setFillColor(ink.act.copy(alpha: dark ? 0.09 : 0.06) ?? ink.act); cg.fill(r.insetBy(dx: 0, dy: 0).offsetBy(dx: 0, dy: 0)) }
            // day number: mono 12/500, right aligned in a 22pt box
            let s = "\(math.day(d))"
            let w = TextCache.line(s, .dayNum).width
            let boxW = max(22, w + 8)
            let px = r.maxX - 5 - boxW
            if isToday {
                cg.addPath(EventPainter.roundedPath(CGRect(x: px - 3, y: r.minY + 2, width: boxW + 6, height: 28), 10)); cg.setFillColor(ink.act.copy(alpha: dark ? 0.18 : 0.12) ?? ink.act); cg.fillPath()
                cg.addPath(EventPainter.roundedPath(CGRect(x: px, y: r.minY + 5, width: boxW, height: 22), 7)); cg.setFillColor(ink.act); cg.fillPath()
            }
            _ = EventPainter.text(cg, s, .dayNum, x: px + (boxW - w) / 2, top: r.minY + 5, box: 22, color: isToday ? CGColor(gray: 1, alpha: 1) : (other ? ink.hazeDim : ink.paper))
            let list = events[i]
            let shown = geo.shownCount(list.count)
            for k in 0..<shown {
                let e = list[k]
                let cr = geo.chipRect(cell: i, index: k)
                let st = style(e)
                let pal = st.palette
                cg.saveGState()
                if past { cg.setAlpha(dark ? 0.55 : 0.5) }
                let title = e.title.isEmpty ? "(No title)" : e.title
                if e.kind == .task {
                    let shape = EventPainter.roundedPath(cr, cr.height / 2)
                    cg.addPath(shape); cg.setFillColor(ink.ink700); cg.fillPath()
                    cg.addPath(EventPainter.roundedPath(cr.insetBy(dx: 0.5, dy: 0.5), cr.height / 2)); cg.setStrokeColor(ink.hairStrong); cg.setLineWidth(1); cg.strokePath()
                    EventPainter.checkbox(cg, CGRect(x: cr.minX + 4, y: cr.midY - 5, width: 10, height: 10), ink: ink, done: done.contains(e.id))
                    let parts = TaskTitle.split(title)
                    _ = EventPainter.truncated(cg, parts.text, .label11, x: cr.minX + 20, top: cr.minY + 1.5, box: 14, color: done.contains(e.id) ? ink.hazeDim : ink.paper, maxWidth: cr.width - 26, strike: done.contains(e.id))
                } else if e.status == .declined {
                    cg.addPath(EventPainter.roundedPath(cr.insetBy(dx: 0.5, dy: 0.5), 5)); cg.setStrokeColor(pal.barRGB.cg.copy(alpha: 0.75) ?? pal.barRGB.cg)
                    cg.setLineWidth(1); cg.setLineDash(phase: 0, lengths: [3, 2]); cg.strokePath(); cg.setLineDash(phase: 0, lengths: [])
                    _ = EventPainter.truncated(cg, title, .label11, x: cr.minX + 9, top: cr.minY + 1.5, box: 14, color: ink.haze, maxWidth: cr.width - 14, strike: true)
                } else {
                    let shape = EventPainter.roundedPath(cr, 5)
                    cg.addPath(shape); cg.setFillColor((e.id == selected ? pal.hoverFillRGB : pal.fillRGB).cg); cg.fillPath()
                    cg.saveGState(); cg.addPath(shape); cg.clip()
                    cg.setFillColor(pal.barRGB.cg); cg.fill(CGRect(x: cr.minX, y: cr.minY, width: 3, height: cr.height))
                    let timeText = e.isAllDay ? "" : fmt.time(e.start)
                    let timeW = timeText.isEmpty ? 0 : TextCache.line(timeText, .chipTime).width + 5
                    let avail = cr.width - 9 - 6 - timeW
                    let tw = EventPainter.truncated(cg, title, .label11, x: cr.minX + 9, top: cr.minY + 1.5, box: 14, color: ink.paper, maxWidth: avail)
                    if !timeText.isEmpty { _ = EventPainter.text(cg, timeText, .chipTime, x: cr.minX + 9 + tw + 5, top: cr.minY + 1.5, box: 14, color: ink.haze) }
                    cg.restoreGState()
                }
                cg.restoreGState()
                if e.id == selected {
                    cg.addPath(EventPainter.roundedPath(cr.insetBy(dx: -0.75, dy: -0.75), e.kind == .task ? cr.height / 2 : 5.5)); cg.setStrokeColor(ink.act); cg.setLineWidth(1.5); cg.strokePath()
                }
            }
            if list.count > shown {
                let cr = geo.chipRect(cell: i, index: shown)
                _ = EventPainter.text(cg, "+\(list.count - shown) more", .label11, x: cr.minX + 4, top: cr.minY + 1.5, box: 14, color: ink.haze)
            }
        }
    }
}

/// The all-day collapse/expand glyph from the mockup: two chevrons pointing at each other (collapse) or apart (expand).
struct ChevronPair: Shape {
    var outward: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        let s = r.width / 24
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * s, y: r.minY + y * s) }
        if outward {   // expand: top chevron up, bottom chevron down
            p.move(to: pt(8, 9)); p.addLine(to: pt(12, 5)); p.addLine(to: pt(16, 9))
            p.move(to: pt(8, 15)); p.addLine(to: pt(12, 19)); p.addLine(to: pt(16, 15))
        } else {       // collapse: top chevron down, bottom chevron up
            p.move(to: pt(8, 4.5)); p.addLine(to: pt(12, 8.5)); p.addLine(to: pt(16, 4.5))
            p.move(to: pt(8, 19.5)); p.addLine(to: pt(12, 15.5)); p.addLine(to: pt(16, 19.5))
        }
        return p
    }
}
