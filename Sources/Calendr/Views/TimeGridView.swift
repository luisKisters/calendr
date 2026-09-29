import SwiftUI
import AppKit
import CalendrKit

/// Hour lines, column separators, column tints and hour labels: one Canvas.
struct GridBackground: View {
    let dayCount: Int
    let dayWidth: CGFloat
    let use24h: Bool
    let dark: Bool
    let todayIndex: Int?
    let weekend: [Int]

    var body: some View {
        Canvas { ctx, size in
            let ink = EventPainter.Ink.of(dark)
            let hourH = Theme.hourHeight
            let x0 = Theme.gutterWidth
            ctx.withCGContext { cg in
                for d in weekend where d != todayIndex {
                    cg.setFillColor(RGB(hex: dark ? "#16151D" : "#F3F1EE").cg.copy(alpha: 0.55) ?? ink.ink700)
                    cg.fill(CGRect(x: x0 + CGFloat(d) * dayWidth, y: 0, width: dayWidth, height: size.height))
                }
                if let t = todayIndex {
                    cg.setFillColor(ink.act.copy(alpha: dark ? 0.09 : 0.06) ?? ink.act)
                    cg.fill(CGRect(x: x0 + CGFloat(t) * dayWidth, y: 0, width: dayWidth, height: size.height))
                }
                cg.setStrokeColor(ink.hair); cg.setLineWidth(1)
                for h in 0..<24 {
                    let y = CGFloat(h) * hourH + 0.5
                    cg.move(to: CGPoint(x: x0, y: y)); cg.addLine(to: CGPoint(x: size.width, y: y))
                }
                for d in 0..<dayCount {
                    let x = x0 + CGFloat(d) * dayWidth + 0.5
                    cg.move(to: CGPoint(x: x, y: 0)); cg.addLine(to: CGPoint(x: x, y: size.height))
                }
                cg.strokePath()
                for h in 1..<24 {
                    let label = use24h ? String(format: "%02d:00", h) : "\((h % 12) == 0 ? 12 : h % 12) \(h < 12 ? "AM" : "PM")"
                    let w = TextCache.line(label, .hour).width
                    _ = EventPainter.text(cg, label, .hour, x: x0 - 9 - w, top: CGFloat(h) * hourH - 6, box: 12, color: ink.hazeDim)
                }
            }
        }
        .frame(height: Theme.hourHeight * 24)
        .drawingGroup(opaque: false)
    }
}

struct TimeGridView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var scroll = ScrollPosition(y: 0)
    @State private var didInitialScroll = false

    var body: some View {
        let n = max(1, model.visibleDays.count)
        GeometryReader { geo in
            let dw = max(1, (geo.size.width - Theme.gutterWidth) / CGFloat(n))
            let g = GridGeometry(dayWidth: Double(dw), hourHeight: Double(Theme.hourHeight), dayCount: n)
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    GridBackground(dayCount: n, dayWidth: dw, use24h: model.settings.use24h, dark: scheme == .dark, todayIndex: model.todayIndex,
                                   weekend: model.visibleDays.indices.filter { model.math.isWeekend(model.visibleDays[$0]) })
                        .frame(width: geo.size.width)
                    SlotHighlight(g: g).offset(x: Theme.gutterWidth)
                    ZStack(alignment: .topLeading) {
                        EventsLayer(g: g, dark: scheme == .dark)
                        TeammateLayer(g: g)
                    }
                    .id(model.periodID)
                    .transition(.periodSlide(model.navDirection))
                    .offset(x: Theme.gutterWidth)
                    SelectionRing(g: g).offset(x: Theme.gutterWidth)
                    TaskPop(g: g).offset(x: Theme.gutterWidth)
                    DropSettle(g: g).offset(x: Theme.gutterWidth)
                    NowMarker(g: g, y: nowY, gutter: Theme.gutterWidth, width: geo.size.width)
                    GridGestureLayer(g: g).offset(x: Theme.gutterWidth)
                }
                .frame(width: geo.size.width, height: Theme.hourHeight * 24, alignment: .topLeading)
                .animation(Motion.base, value: model.periodID)
                .clipped()
            }
            .scrollPosition($scroll)
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { model.gridViewport = $0 }
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { _ in model.gridGeometry = g }
            .onAppear {
                model.gridGeometry = g
                model.gridScrollY = CGFloat(model.settings.firstVisibleHour) * Theme.hourHeight - 3
                scroll = ScrollPosition(y: model.gridScrollY)
            }
            .onChange(of: model.scrollToHourTick) { _, _ in
                model.gridScrollY = CGFloat(model.settings.firstVisibleHour) * Theme.hourHeight - 3
                scroll = ScrollPosition(y: model.gridScrollY)
            }
            .onChange(of: n) { _, _ in model.gridGeometry = g }
        }
    }

    private var nowY: CGFloat { CGFloat(model.math.minutesSinceMidnight(model.now)) * CGFloat(Theme.hourHeight) / 60 }
}

/// `live` red, and only this: the current-time line across the week (faint) and today (strong), the dot with a slow halo, the gutter pill.
private struct NowMarker: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    let y: CGFloat
    let gutter: CGFloat
    let width: CGFloat
    @State private var halo = false
    var body: some View {
        if let i = model.todayIndex {
            let x0 = gutter + CGFloat(i) * CGFloat(g.dayWidth)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Theme.live.opacity(0.28)).frame(width: width - gutter, height: 1).offset(x: gutter, y: y - 0.5)
                Rectangle().fill(Theme.live).frame(width: CGFloat(g.dayWidth), height: 1.5).offset(x: x0, y: y - 0.75)
                ZStack {
                    Circle().fill(Theme.live).frame(width: 9, height: 9).scaleEffect(halo ? 2.8 : 1).opacity(halo ? 0 : 0.55)
                    Circle().fill(Theme.live).frame(width: 9, height: 9)
                }.offset(x: x0 - 4.5, y: y - 4.5)
                Text(model.fmt.time(model.now)).font(.calMono(10, .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 5).frame(height: 16)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Theme.live))
                    .offset(x: gutter - 5 - 36, y: y - 8)
            }
            .allowsHitTesting(false)
            .onAppear { startHalo() }
            .onChange(of: Motion.reduced) { _, _ in startHalo() }
        }
    }
    private func startHalo() {
        if Motion.reduced { halo = false; return }
        withAnimation(Animation.timingCurve(0.22, 0.61, 0.36, 1, duration: 3.2).repeatForever(autoreverses: false)) { halo = true }
    }
}

private struct SlotHighlight: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    var body: some View {
        if let slot = model.selectedSlot, let d = model.visibleDays.firstIndex(where: { model.math.isSameDay($0, slot) }) {
            RoundedRectangle(cornerRadius: Radius.event).fill(Theme.actWash)
                .frame(width: CGFloat(g.dayWidth) - CGFloat(g.leftInset + g.rightInset), height: CGFloat(g.hourHeight) / 2 - 1)
                .offset(x: CGFloat(d) * CGFloat(g.dayWidth) + CGFloat(g.leftInset), y: CGFloat(g.yPos(model.math.minutesSinceMidnight(slot))))
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(Motion.base, value: slot)
        }
    }
}

/// 1.5 pt `act` ring around the selected event with a lift shadow; fades in over 180 ms.
private struct SelectionRing: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let id = model.selectedEventID, let p = model.flatTimed.first(where: { $0.event.id == id }), p.event.kind != .task || true {
                let r = g.rect(for: p)
                let radius = p.event.kind == .task ? r.height / 2 : Radius.event
                RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.act, lineWidth: 1.5)
                    .padding(-0.75)
                    .frame(width: r.width, height: r.height)
                    .liftShadow()
                    .offset(x: r.minX, y: r.minY)
                    .id(id)
                    .transition(.opacity)
            }
        }
        .animation(Motion.base, value: model.selectedEventID)
        .allowsHitTesting(false)
    }
}

/// The checkbox pops (scale .7 -> 1.15 -> 1) when a task is completed.
private struct TaskPop: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    @State private var scale: CGFloat = 1
    @State private var shownTick = 0
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let pop = model.taskPop, pop.tick == shownTick, model.isDone(pop.id), let p = model.flatTimed.first(where: { $0.event.id == pop.id }) {
                let c = EventPainter.checkboxRect(in: g.rect(for: p))
                ZStack {
                    Circle().fill(Theme.act)
                    Image(systemName: "checkmark").font(.system(size: 7.5, weight: .heavy)).foregroundStyle(.white)
                }
                .frame(width: c.width, height: c.height).scaleEffect(scale).offset(x: c.minX, y: c.minY)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: model.taskPop?.tick) { _, t in
            guard let t else { return }
            shownTick = t
            scale = 0.7
            withAnimation(Motion.spring) { scale = 1 }
        }
    }
}

/// On drop the ghost eases into the event's final rect in 120 ms.
private struct DropSettle: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    @State private var arrived = true
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let s = model.dropSettle {
                let from = CGRect(x: CGFloat(s.dayIndex) * CGFloat(g.dayWidth) + CGFloat(g.leftInset), y: CGFloat(g.yPos(s.startMinute)),
                                  width: CGFloat(g.dayWidth) - CGFloat(g.leftInset + g.rightInset), height: max(17, CGFloat(g.yPos(s.endMinute) - g.yPos(s.startMinute)) - 3))
                let to = model.selectedEventID.flatMap { id in model.flatTimed.first { $0.event.id == id } }.map { g.rect(for: $0) } ?? from
                let r = arrived ? to : from
                RoundedRectangle(cornerRadius: Radius.event).fill(Theme.actWash)
                    .overlay(RoundedRectangle(cornerRadius: Radius.event).strokeBorder(Theme.act, lineWidth: 1.5))
                    .frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY)
                    .opacity(arrived ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: model.dropSettle?.tick) { _, _ in
            arrived = false
            withAnimation(Motion.fast) { arrived = true }
        }
    }
}

private struct TeammateLayer: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    var body: some View {
        AbsoluteLayout(size: CGSize(width: CGFloat(g.dayWidth) * CGFloat(g.dayCount), height: CGFloat(g.totalHeight))) {
            ForEach(model.flatOverlay) { p in
                let bandX = CGFloat(g.dayWidth) * 0.46
                let bandW = CGFloat(g.dayWidth) * 0.54 - 8
                let x = CGFloat(p.dayIndex) * CGFloat(g.dayWidth) + bandX + CGFloat(p.placement.left) * bandW
                let y = CGFloat(g.yPos(p.startMinute))
                let h = max(14, CGFloat(g.yPos(p.endMinute)) - y - 3)
                TeammateCell(title: p.event.title, time: "\(model.fmt.time(minutes: p.startMinute))\u{2013}\(model.fmt.time(minutes: p.endMinute))", rect: CGRect(x: x, y: y, width: max(8, CGFloat(p.placement.width) * bandW), height: h), hue: Color(hex: model.teammateColor(p.event.ownerEmail)))
                    .equatable()
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
        let moving = model.dragPreview.flatMap { $0.kind == .create ? nil : $0.eventID }
        var ghost: (EventPalette, String, String)?
        if let d = model.dragPreview {
            let e = model.event(id: d.eventID)
            let pal = Palettes.palette(barHex: e.map { model.calendarColorHex(of: $0) } ?? model.defaultCalendarHex, fillHex: e?.colorHex, dark: dark)
            ghost = (pal, e.map { $0.title.isEmpty ? "(No title)" : $0.title } ?? "(No title)", "\(model.fmt.time(minutes: d.startMinute))\u{2013}\(model.fmt.time(minutes: d.endMinute))")
        }
        let m = model
        return EventsCanvas(events: model.flatTimed, geometry: g, dark: dark, now: model.now, selectedID: model.selectedEventID, movingID: moving,
                            preview: model.dragPreview, fmt: model.fmt,
                            styles: { e, dark, sel, faded, overl in
                                var s = m.style(for: e, dark: dark, now: m.now, selected: sel, faded: faded, overlapping: overl)
                                s.isDark = dark
                                return s
                            }, ghost: ghost)
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
                switch phase {
                case .active(let p):
                    if case .event(_, _, _, _, true)? = model.hitTest(p) { NSCursor.resizeUpDown.set() } else { NSCursor.arrow.set() }
                case .ended: NSCursor.arrow.set()
                }
            }
    }
}
