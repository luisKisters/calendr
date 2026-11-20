import SwiftUI
import AppKit
import CalendrKit

/// Week and day view body: the scrolling 24 hour canvas. "Fit, then yours": the period's first to last event fills the viewport
/// when it opens, the hour gutter zooms (see `AppModel.gutterZoomBegan`), and a double-click on the gutter fits again.
struct TimeGridView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var scroll = ScrollPosition(y: 0)

    var body: some View {
        let n = max(1, model.visibleDays.count)
        let gutter = Theme.gutterWidth
        VStack(spacing: 0) {
            // The all-day edge: inside the all-day lane when it has chips (`.ad { box-shadow: inset 0 -1px 0 hairStrong }`), else here.
            if model.layout.allDay.laneCount == 0 { Rectangle().fill(Theme.hair2).frame(height: 1) }
            GeometryReader { geo in
                let dw = max(1, (geo.size.width - gutter) / CGFloat(n))
                let g = GridGeometry(dayWidth: Double(dw), hourHeight: model.gridHourHeight, dayCount: n)
                let dark = scheme == .dark
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        GridLines(g: g, dark: dark, today: model.todayIndex).offset(x: gutter)
                        ZStack(alignment: .topLeading) {
                            EventsLayer(g: g, dark: dark)
                            TeammateLayer(g: g)
                        }
                        .id(model.periodID)
                        .transition(.periodSlide(model.navDirection))
                        .offset(x: gutter)
                        NowLines(g: g, gutter: gutter)
                        GridGestureLayer(g: g).offset(x: gutter)
                        HourGutter(g: g, dark: dark).frame(width: gutter, height: CGFloat(g.totalHeight))
                        GridStackHost(g: g, gutter: gutter, width: geo.size.width)
                    }
                    .frame(width: geo.size.width, height: CGFloat(g.totalHeight), alignment: .topLeading)
                    .animation(Motion.base, value: model.periodID)
                    .clipped()
                }
                .scrollPosition($scroll)
                .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, y in model.gridScrollY = y }
                .overlay(alignment: .leading) { GutterZoomHandle().frame(width: gutter) }
                .overlay { GridEmptyState() }
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { model.gridViewport = $0 }
                .onAppear {
                    model.gridGeometry = g
                    model.setGridViewport(height: Double(geo.size.height))
                    scroll = ScrollPosition(y: model.gridState.scrollTarget)
                }
                .onChange(of: g) { _, v in model.gridGeometry = v }
                .onChange(of: geo.size.height) { _, h in model.setGridViewport(height: Double(h)) }
            }
        }
        .overlay { GridDayListHost() }
        .onChange(of: model.gridState.scrollTick) { _, _ in scroll = ScrollPosition(y: model.gridState.scrollTarget) }
        .onChange(of: model.scrollToHourTick) { _, _ in model.scrollGridToSelectionOrFit() }
        .onChange(of: model.settings.hourHeight) { _, _ in
            // Set from elsewhere (Settings, a snapshot state): cascade for the new height and open on the fit again.
            if model.gridState.zoom == nil && model.layout.pointsPerHour != model.gridHourHeight { model.reload(); model.scrollGridToSelectionOrFit() }
        }
    }
}

/// Today's column tint (`.day.today { background: var(--today-tint) }`, 3.5 percent toward fg1), the hour lines across the columns
/// (10 percent; the locked look has no half-hour line) and the day divider left of every column (7 percent).
private struct GridLines: View {
    let g: GridGeometry
    let dark: Bool
    let today: Int?
    var body: some View {
        Canvas { ctx, size in
            let ink = EventPainter.Ink.of(dark)
            ctx.withCGContext { cg in
                if let t = today {
                    cg.setFillColor(ink.todayTint); cg.fill(CGRect(x: Double(t) * g.dayWidth, y: 0, width: g.dayWidth, height: Double(size.height)))
                }
                cg.setFillColor(ink.hourLine)
                for h in 0...24 { cg.fill(CGRect(x: 0, y: g.yPos(h * 60), width: size.width, height: 1)) }
                cg.setFillColor(ink.dayDivider)
                for d in 0..<g.dayCount { cg.fill(CGRect(x: Double(d) * g.dayWidth, y: 0, width: 1, height: size.height)) }
            }
        }
        .frame(width: CGFloat(g.dayWidth) * CGFloat(g.dayCount), height: CGFloat(g.totalHeight))
        .allowsHitTesting(false)
    }
}

/// Hour labels (11 / 400 fg2, 8 pt from the gutter's right edge, centred on their line; none at 00:00), the live time pill and the
/// hover pill. A label that would collide with the one above it is skipped; a label within 20 minutes of now gives way to the now pill
/// (mockup `timeGrid`), and all labels fade back while the hover pill shows.
private struct HourGutter: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    let dark: Bool

    var body: some View {
        let fmt = model.fmt
        let nowMinute: Int? = model.todayIndex.map { _ in model.math.minutesSinceMidnight(model.now) }
        let nowY: Double? = nowMinute.map { g.yPos($0) }
        let nowText = fmt.time(model.now)
        let hover = model.gridState.pointer.minute
        Canvas { ctx, size in
            let ink = EventPainter.Ink.of(dark)
            let right = size.width
            ctx.withCGContext { cg in
                cg.saveGState()
                if hover != nil { cg.setAlpha(0.25) }
                var lastY = -99.0
                for h in 1..<24 {
                    let y = g.yPos(h * 60)
                    if y - lastY < 20 { continue }
                    lastY = y
                    if let nm = nowMinute, abs(h * 60 - nm) <= 20 { continue }
                    let s = TextCache.time(fmt, minutes: h * 60)
                    let w = TextCache.line(s, .hour).width
                    EventPainter.text(cg, s, .hour, x: right - 8 - w, top: y - 7, box: 14, color: ink.hourLabel)
                }
                cg.restoreGState()
                if let ny = nowY { pill(cg, nowText, .hourBold, y: ny, right: right - 4, fill: ink.live, color: ink.onLive) }
                if let m = hover { pill(cg, TextCache.time(fmt, minutes: m), .hour, y: g.yPos(m), right: right - 4, fill: ink.bg3, color: ink.fg) }
            }
        }
        .allowsHitTesting(false)
    }

    @MainActor
    /// `.gut .now`: 16 pt tall, 5 pt either side, radius 4, centred on the line.
    private func pill(_ cg: CGContext, _ s: String, _ kind: TextCache.Kind, y: Double, right: Double, fill: CGColor, color: CGColor) {
        let w = TextCache.line(s, kind).width + 10
        let r = CGRect(x: right - w, y: y - 8, width: w, height: 16)
        cg.addPath(EventPainter.roundedPath(r, Radius.nowPill)); cg.setFillColor(fill); cg.fillPath()
        EventPainter.text(cg, s, kind, x: r.minX + 5, top: r.minY, box: 16, color: color)
    }
}

/// The now line, above the events (`.nowl`, z 60), in `live` red only: on the other days of the week 1 pt at 38 percent, on today
/// 2 pt with a 0.5 pt window-coloured edge and an 8 pt dot ringed 1.5 pt in the window colour at the column's left edge.
private struct NowLines: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let g: GridGeometry
    let gutter: CGFloat
    var body: some View {
        if let today = model.todayIndex {
            let y = g.yPos(model.math.minutesSinceMidnight(model.now))
            let dark = scheme == .dark
            Canvas { ctx, _ in
                let ink = EventPainter.Ink.of(dark)
                ctx.withCGContext { cg in
                    let dw = g.dayWidth, gx = Double(gutter)
                    cg.setFillColor(ink.live.copy(alpha: 0.38) ?? ink.live)
                    for d in 0..<g.dayCount where d != today { cg.fill(CGRect(x: gx + Double(d) * dw + 1, y: y, width: dw - 1, height: 1)) }
                    let x0 = gx + Double(today) * dw
                    cg.setFillColor(ink.bg.copy(alpha: 0.6) ?? ink.bg); cg.fill(CGRect(x: x0 + 0.5, y: y - 1.5, width: dw, height: 3))
                    cg.setFillColor(ink.live); cg.fill(CGRect(x: x0 + 1, y: y - 1, width: dw - 1, height: 2))
                    let dot = CGRect(x: x0 - 4, y: y - 4, width: 8, height: 8)
                    cg.setFillColor(ink.bg); cg.fillEllipse(in: dot.insetBy(dx: -1.5, dy: -1.5))
                    cg.setFillColor(ink.live); cg.fillEllipse(in: dot)
                }
            }
            .frame(width: gutter + CGFloat(g.dayWidth) * CGFloat(g.dayCount), height: CGFloat(g.totalHeight))
            .allowsHitTesting(false)
        }
    }
}

private struct TeammateLayer: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    var body: some View {
        AbsoluteLayout(size: CGSize(width: CGFloat(g.dayWidth) * CGFloat(g.dayCount), height: CGFloat(g.totalHeight))) {
            ForEach(model.flatOverlay) { p in
                // `.mate`: 46 percent of the column, 2 pt from its right edge.
                let w = (g.dayWidth - 1) * 0.46
                let x = Double(p.dayIndex + 1) * g.dayWidth - 2 - w
                let y = g.yPos(p.startMinute)
                let r = CGRect(x: x, y: y, width: w, height: max(4, g.yPos(p.endMinute) - y - 1))
                TeammateCell(size: r.size, hue: Color(hex: model.teammateColor(p.event.ownerEmail))).equatable().placed(r)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct EventsLayer: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    let dark: Bool

    var body: some View {
        let drag = model.gridPreviewLayout()
        let m = model
        let selected = model.selectedEventID, draft = model.draftEventID, hovered = model.gridState.pointer.hoveredEventID
        let now = model.now
        let open = model.visibleStack.map { s in GridMoreRef(day: s.ref.day, group: model.layout.groups(day: s.ref.day).firstIndex(of: s.group) ?? -1) }
        return EventsCanvas(events: drag.events, geometry: g, dark: dark, fmt: model.fmt, dayView: model.viewMode == .day,
                            preview: drag.preview, creating: model.dragPreview?.kind == .create, rank: { m.paintRank($0) },
                            groups: drag.groups, hotMore: [model.gridState.pointer.hoveredMore, open].compactMap { $0 },
                            styles: { p in
                                var s = m.style(for: p.event, dark: dark, now: now, selected: p.event.id == selected, overlapping: p.placement.over)
                                s.isDark = dark
                                s.hovered = p.event.id == hovered
                                s.draft = p.event.id == draft
                                return s
                            })
    }
}

/// Single gesture surface for the whole grid. The gesture only forwards points to the model; the walkthrough
/// drives the very same model entry points.
private struct GridGestureLayer: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    @State private var down = false

    var body: some View {
        Color.clear
            .frame(width: CGFloat(g.dayWidth) * CGFloat(g.dayCount), height: CGFloat(g.totalHeight))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { v in
                    if !down {
                        down = true
                        model.gridGeometry = g
                        model.gridMouseDown(v.startLocation, clickCount: NSApp.currentEvent?.clickCount ?? 1)
                    }
                    model.gridMouseDragged(v.location)
                }
                .onEnded { v in
                    down = false
                    model.gridMouseUp(v.location)
                })
            .onContinuousHover { phase in
                let pointer = model.gridState.pointer
                switch phase {
                case .active(let p):
                    guard model.press == nil else { return }
                    switch model.hitTest(p) {
                    case .event(let id, _, _, _, let edge)?:
                        if edge != nil { NSCursor.resizeUpDown.set() } else { NSCursor.arrow.set() }
                        if pointer.hoveredEventID != id { pointer.hoveredEventID = id }
                        if pointer.minute != nil { pointer.minute = nil }
                        if pointer.hoveredMore != nil { pointer.hoveredMore = nil }
                    case .more(let d, let i)?:
                        NSCursor.arrow.set()
                        let ref = GridMoreRef(day: d, group: i)
                        if pointer.hoveredMore != ref { pointer.hoveredMore = ref }
                        if pointer.hoveredEventID != nil { pointer.hoveredEventID = nil }
                        if pointer.minute != nil { pointer.minute = nil }
                    case .empty(_, let m)?:
                        NSCursor.arrow.set()
                        if pointer.hoveredEventID != nil { pointer.hoveredEventID = nil }
                        if pointer.hoveredMore != nil { pointer.hoveredMore = nil }
                        let snap: Int? = model.draftEventID == nil ? g.snapped(m) : nil
                        if pointer.minute != snap { pointer.minute = snap }
                    case nil: break
                    }
                case .ended:
                    NSCursor.arrow.set()
                    if model.press == nil { pointer.minute = nil }
                    pointer.hoveredEventID = nil
                    pointer.hoveredMore = nil
                }
            }
    }
}

/// The hour gutter is the zoom handle: drag down for taller hours, up for shorter; double-click fits the period again.
private struct GutterZoomHandle: View {
    @Environment(AppModel.self) private var model
    @State private var down = false

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { v in
                    if !down {
                        down = true
                        if (NSApp.currentEvent?.clickCount ?? 1) >= 2 { model.fitHourScale(); return }
                        model.gutterZoomBegan(y: Double(v.startLocation.y))
                    }
                    model.gutterZoomChanged(y: Double(v.location.y))
                }
                .onEnded { _ in
                    down = false
                    model.gutterZoomEnded()
                })
            .onContinuousHover { phase in
                if case .active = phase { NSCursor.resizeUpDown.set() } else { NSCursor.arrow.set() }
            }
            .help("Drag to change the hour height. Double-click to fit the week again.")
    }
}

/// An empty period says so, and says how to fill it.
private struct GridEmptyState: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        if model.layout.timedCount == 0 && model.layout.allDay.placements.isEmpty && model.dragPreview == nil {
            GeometryReader { geo in
                VStack(spacing: 6) {
                    Text(model.visibleDays.count == 1 ? "Nothing on this day" : "Nothing this week").font(.title15).tracking(TypeTrack.title).foregroundStyle(Theme.fg)
                    HStack(spacing: 5) {
                        Text("Drag on the grid, or press")
                        Keycap(text: "C")
                        Text("for a new event.")
                    }
                    .font(.text).foregroundStyle(Theme.fg3)
                }
                .padding(.leading, Theme.gutterWidth)
                .frame(width: geo.size.width)
                .offset(y: geo.size.height * 0.3)
            }
            .allowsHitTesting(false)
        }
    }
}
