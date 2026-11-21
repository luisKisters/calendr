import SwiftUI
import CalendrKit

/// Places the open "+N" stack over its day column at the top of the busy time (mockup-v4 `popHTML` 'evmore', `place` 'over' :1725):
/// 2 pt in from the column's left edge, flipped to end at the column's right edge when it would leave the grid.
struct GridStackHost: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    let gutter: CGFloat
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let v = model.visibleStack {
                let rows = model.stackRows
                let w = GridStackPanel.width(dayWidth: g.dayWidth)
                // At the start of the hidden events (`data-top` is their earliest start), not of the first row.
                let lo = v.group.startMinute
                let colLeft = gutter + CGFloat(Double(v.ref.day) * g.dayWidth)
                let x = colLeft + 2 + w > width - 8 ? colLeft + CGFloat(g.dayWidth) - w - 2 : colLeft + 2
                GridStackPanel(rows: rows, width: w)
                    .offset(x: x, y: CGFloat(g.yPos(lo)) - 2)
                    .transition(.scale(scale: 0.98, anchor: .top).combined(with: .opacity))
                    .id("\(v.ref.day)|\(v.ref.startMinute)")
            }
        }
        .frame(width: width, height: CGFloat(g.totalHeight), alignment: .topLeading)
        .animation(Motion.fast, value: model.gridState.stack)
    }
}

/// `.pop.stack`: the pop surface (radius 12) with one row per event of the busy time, in time order, in its reply style.
struct GridStackPanel: View {
    @Environment(AppModel.self) private var model
    let rows: [PlacedEvent]
    let width: CGFloat

    /// Two day columns less 8 pt.
    static func width(dayWidth: Double) -> CGFloat { CGFloat((dayWidth * 2 - 8).rounded()) }

    var body: some View {
        VStack(spacing: 3) {
            ForEach(rows, id: \.id) { GridStackRow(placed: $0) }
        }
        .padding(Space.xs)
        .frame(width: width, alignment: .top)
        .background(RoundedRectangle(cornerRadius: Radius.surface).fill(Theme.pop))
        .overlay(RoundedRectangle(cornerRadius: Radius.surface).strokeBorder(Theme.hair2, lineWidth: 1))
        .popShadow()
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { model.gridState.stackBox.frame = $0 }
    }
}

/// `.pop.stack .sk`: 76 pt time, title, reply word; the fill, stripes or outline of the reply state and the 3 pt bar.
private struct GridStackRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let placed: PlacedEvent
    var body: some View {
        let e = placed.event
        let dark = scheme == .dark
        let reply = EventReply(e)
        let pal = Palettes.palette(barHex: model.calendarColorHex(of: e), fillHex: e.colorHex, dark: dark)
        // The stack rows are never drawn past: `.sk` has no `.past` rule.
        var c = pal.colors(reply: reply, past: false)
        if reply == .declined { c.bar = pal.barRGB; c.barAlpha = 1 }
        let hot = model.gridState.pointer.hoveredStackRow == e.id
        let k = hot ? 1.15 : 1.0
        let span = placed.endMinute > placed.startMinute && e.end > e.start
            ? TextCache.range(model.fmt, placed.startMinute, placed.endMinute) : TextCache.time(model.fmt, minutes: placed.startMinute)
        return Button { model.pickFromStack(e.id) } label: {
            HStack(spacing: Space.s) {
                Text(span).font(.smallTab).foregroundStyle(c.time.color)
                    .lineLimit(1).frame(width: 76, alignment: .leading)
                Text(e.title.isEmpty ? "(No title)" : e.title).font(.event).foregroundStyle(c.title.color)
                    .strikethrough(c.strike, color: c.title.color.opacity(0.7))
                    .lineLimit(1).truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let r = reply.label { Text(r).font(.small).foregroundStyle(Theme.fg3) }
            }
            .padding(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 8))
            .frame(minHeight: Dim.row)
            .background(
                Canvas { ctx, size in
                    ctx.withCGContext { cg in
                        let r = CGRect(origin: .zero, size: size)
                        let shape = EventPainter.roundedPath(r, Radius.row)
                        cg.addPath(shape); cg.setFillColor(Palettes.brighter(c.stripe ?? c.fill, k).cg); cg.fillPath()
                        cg.addPath(shape); cg.clip()
                        if c.stripe != nil { EventPainter.stripes(cg, r, color: Palettes.brighter(c.fill, k).cg) }
                        if let o = c.outline {
                            cg.addPath(EventPainter.roundedPath(r.insetBy(dx: 0.5, dy: 0.5), Radius.row - 0.5)); cg.setStrokeColor(o.cg); cg.setLineWidth(1); cg.strokePath()
                        }
                        let bar = CGRect(x: 3, y: 4, width: 3, height: max(0, size.height - 8))
                        cg.addPath(EventPainter.roundedPath(bar, Radius.bar)); cg.setFillColor(c.bar.cg); cg.fillPath()
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            let p = model.gridState.pointer
            if inside { p.hoveredStackRow = e.id } else if p.hoveredStackRow == e.id { p.hoveredStackRow = nil }
        }
    }
}
