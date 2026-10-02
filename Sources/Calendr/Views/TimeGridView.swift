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
            Rectangle().fill(Theme.hair2).frame(height: 1)
            GeometryReader { geo in
                let dw = max(1, (geo.size.width - gutter) / CGFloat(n))
                let g = GridGeometry(dayWidth: Double(dw), hourHeight: model.gridHourHeight, dayCount: n)
                let dark = scheme == .dark
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        GridLines(g: g, dark: dark).offset(x: gutter)
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

/// Hour lines across the columns and the hairline left of every column.
private struct GridLines: View {
    let g: GridGeometry
    let dark: Bool
    var body: some View {
        Canvas { ctx, size in
            let ink = EventPainter.Ink.of(dark)
            ctx.withCGContext { cg in
                cg.setFillColor(ink.hair)
                for h in 0...24 { cg.fill(CGRect(x: 0, y: g.yPos(h * 60), width: size.width, height: 1)) }
                for d in 0..<g.dayCount { cg.fill(CGRect(x: Double(d) * g.dayWidth, y: 0, width: 1, height: size.height)) }
            }
        }
        .frame(width: CGFloat(g.dayWidth) * CGFloat(g.dayCount), height: CGFloat(g.totalHeight))
        .allowsHitTesting(false)
    }
}

/// Hour labels, the live time pill and the hover pill. A label that would collide with the one above it is skipped; the label
/// nearest the now pill gives way, and all labels fade back while the hover pill shows.
private struct HourGutter: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    let dark: Bool

    var body: some View {
        let fmt = model.fmt
        let nowY: Double? = model.todayIndex.map { _ in g.yPos(model.math.minutesSinceMidnight(model.now)) }
        let nowText = fmt.time(model.now)
        let hover = model.gridState.pointer.minute
        Canvas { ctx, size in
            let ink = EventPainter.Ink.of(dark)
            let right = size.width
            ctx.withCGContext { cg in
                cg.saveGState()
                if hover != nil { cg.setAlpha(0.25) }
                var lastY = -99.0
                for h in 0..<24 {
                    let y = g.yPos(h * 60)
                    if y - lastY < 20 { continue }
                    lastY = y
                    if let ny = nowY, abs(y - ny) < 13 { continue }
                    let s = TextCache.time(fmt, minutes: h * 60)
                    let w = TextCache.line(s, .hour).width
                    EventPainter.text(cg, s, .hour, x: right - 10 - w, top: y - 7, box: 14, color: ink.fg3)
                }
                cg.restoreGState()
                if let ny = nowY { pill(cg, nowText, .hourBold, y: ny, right: right - 5, fill: ink.live, color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)) }
                if let m = hover { pill(cg, TextCache.time(fmt, minutes: m), .hour, y: g.yPos(m), right: right - 5, fill: ink.bg3, color: ink.fg) }
            }
        }
        .allowsHitTesting(false)
    }

    @MainActor
    private func pill(_ cg: CGContext, _ s: String, _ kind: TextCache.Kind, y: Double, right: Double, fill: CGColor, color: CGColor) {
        let w = TextCache.line(s, kind).width + 10
        let r = CGRect(x: right - w, y: y - 8.5, width: w, height: 17)
        cg.addPath(EventPainter.roundedPath(r, 4)); cg.setFillColor(fill); cg.fillPath()
        EventPainter.text(cg, s, kind, x: r.minX + 5, top: r.minY, box: 17, color: color)
    }
}

/// `live` red, and only this: 1 pt at 30 percent across the week, 2 pt with an 8 pt dot in today's column.
private struct NowLines: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    let gutter: CGFloat
    var body: some View {
        if let i = model.todayIndex {
            let y = CGFloat(g.yPos(model.math.minutesSinceMidnight(model.now)))
            let x0 = gutter + CGFloat(i) * CGFloat(g.dayWidth)
            let w = CGFloat(g.dayWidth) * CGFloat(g.dayCount)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Theme.live.opacity(0.3)).frame(width: w, height: 1).offset(x: gutter, y: y)
                RoundedRectangle(cornerRadius: 1).fill(Theme.live).frame(width: CGFloat(g.dayWidth), height: 2).offset(x: x0, y: y - 1)
                Circle().fill(Theme.live).frame(width: 8, height: 8).offset(x: x0 - 4, y: y - 4)
            }
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
        return EventsCanvas(events: drag.events, geometry: g, dark: dark, fmt: model.fmt, dayView: model.viewMode == .day,
                            preview: drag.preview, creating: model.dragPreview?.kind == .create, rank: { m.paintRank($0) },
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
                    case .empty(_, let m)?:
                        NSCursor.arrow.set()
                        if pointer.hoveredEventID != nil { pointer.hoveredEventID = nil }
                        let snap: Int? = model.draftEventID == nil ? g.snapped(m) : nil
                        if pointer.minute != snap { pointer.minute = snap }
                    case nil: break
                    }
                case .ended:
                    NSCursor.arrow.set()
                    if model.press == nil { pointer.minute = nil }
                    pointer.hoveredEventID = nil
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
                    Text(model.visibleDays.count == 1 ? "Nothing on this day" : "Nothing this week").font(.ui(16, .semibold)).tracking(-0.35).foregroundStyle(Theme.fg)
                    HStack(spacing: 5) {
                        Text("Drag on the grid, or press")
                        Keycap(text: "C")
                        Text("for a new event.")
                    }
                    .font(.ui(12.5)).foregroundStyle(Theme.fg3)
                }
                .padding(.leading, Theme.gutterWidth)
                .frame(width: geo.size.width)
                .offset(y: geo.size.height * 0.3)
            }
            .allowsHitTesting(false)
        }
    }
}
