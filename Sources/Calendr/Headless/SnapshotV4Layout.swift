import AppKit
import SwiftUI
import CalendrKit

/// `--snapshot v4-b-layout`: a debug picture of `OverlapV5` (v4 PR B) on the v4 fixture's Wednesday evening, 17:00-21:30.
/// It is not app UI: boxes at the V5 placements (left, width, indent, level, cut), the "+N" button of each overflow group,
/// and a table of the numbers, so a reviewer can see the algorithm before the grid uses it (Phase 5).
@MainActor
enum SnapshotV4Layout {
    static let screens = ["v4-b-layout"]
    static let from = 17 * 60, to = 21 * 60 + 30

    struct Row: Identifiable {
        var event: CalendarEvent
        var place: V5Placement?
        var id: String { event.id }
    }

    /// Renders the debug screen instead of the window. Nil for every other state.
    static func run(_ state: String, _ m: AppModel, _ o: LaunchOptions, out: String) -> Int32? {
        guard screens.contains(state) else { return nil }
        let w = OffscreenWindow(view(m), size: CGSize(width: 1440, height: 900), dark: true, chrome: false)
        w.settle(6)
        let ok = w.writePNG(to: out, scale: o.scale)
        print(ok ? "wrote \(out)" : "failed \(out)")
        return ok ? 0 : 1
    }

    /// The fixture Wednesday's events and their V5 layout.
    static func wednesday(_ m: AppModel) -> (events: [CalendarEvent], items: [V5Item], result: OverlapV5.Result) {
        let math = m.math
        let wed = math.addDays(DemoDataV4.weekStart, 2)
        let events = m.store.events(in: DateInterval(start: wed, end: math.addDays(wed, 1))).filter { !$0.isAllDay && math.isSameDay($0.start, wed) }
        let items = events.map {
            V5Item(id: $0.id, startMinute: math.minutesSinceMidnight($0.start), endMinute: math.minutesSinceMidnight($0.end), isUnaccepted: $0.isUnaccepted)
        }
        return (events, items, OverlapV5.layout(items))
    }

    /// The 1440x900 debug screen (also shown at the end of the v4-b tour).
    static func view(_ m: AppModel) -> some View {
        let (events, items, r) = wednesday(m)
        let math = m.math
        let byID = Dictionary(uniqueKeysWithValues: r.placements.map { ($0.id, $0) })
        let rows = events.filter { e in
            let s = math.minutesSinceMidnight(e.start)
            return s < to && max(math.minutesSinceMidnight(e.end), s + OverlapV5.shortSpan) > from
        }.sorted { $0.start < $1.start }.map { Row(event: $0, place: byID[$0.id]) }
        let groups = r.groups.filter { $0.startMinute >= from && $0.startMinute < to }
        let stacks = groups.map { g in g.stackRows(dayEvents: items).compactMap { it in events.first { $0.id == it.id } } }
        return LayoutDebugView(rows: rows, groups: groups, stacks: stacks, color: { Color(hex: m.calendarColorHex(of: $0)) }, fmt: m.fmt)
    }
}

private struct LayoutDebugView: View {
    let rows: [SnapshotV4Layout.Row]
    let groups: [OverflowGroup]
    let stacks: [[CalendarEvent]]
    let color: (CalendarEvent) -> Color
    let fmt: Fmt

    static let colW: CGFloat = 560, perHour: CGFloat = 168, top: CGFloat = 92, left: CGFloat = 96
    func y(_ minute: Int) -> CGFloat { Self.top + CGFloat(minute - SnapshotV4Layout.from) / 60 * Self.perHour }

    func reply(_ e: CalendarEvent) -> String {
        switch e.myReply {
        case .declined: "declined"
        case .needsAction: "no reply"
        case .tentative: "maybe"
        case .confirmed: e.iAmOrganizer ? "organizer" : e.attendees.isEmpty ? "" : "yes"
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.bg
            VStack(alignment: .leading, spacing: 4) {
                Text("OverlapV5 on the v4 fixture: Wed 30 Sep, 17:00\u{2013}21:30").font(.title18).foregroundStyle(Theme.fg)
                Text("Debug render of CalendrKit OverlapV5.layout (PR B). Picks: smart, unaccepted right, +N stack, short block. Not app UI.")
                    .font(.small).foregroundStyle(Theme.fg3)
            }
            .offset(x: 32, y: 24)

            // Hour lines and labels.
            ForEach(Array(stride(from: SnapshotV4Layout.from, through: SnapshotV4Layout.to, by: 30)), id: \.self) { mi in
                Rectangle().fill(mi % 60 == 0 ? Theme.hair2 : Theme.hair).frame(width: Self.colW, height: 1).offset(x: Self.left, y: y(mi))
                Text(String(format: "%02d:%02d", mi / 60, mi % 60)).font(.smallTab).foregroundStyle(mi % 60 == 0 ? Theme.fg2 : Theme.fg3)
                    .frame(width: 56, alignment: .trailing).offset(x: Self.left - 64, y: y(mi) - 8)
            }
            Rectangle().strokeBorder(Theme.hair2, lineWidth: 1)
                .frame(width: Self.colW, height: y(SnapshotV4Layout.to) - y(SnapshotV4Layout.from)).offset(x: Self.left, y: y(SnapshotV4Layout.from))

            // Placements, lowest level first.
            ForEach(rows.filter { $0.place != nil }.sorted { $0.place!.level < $1.place!.level }) { row in box(row.event, row.place!) }

            // "+N" buttons.
            ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                Text("+\(g.ids.count)").font(.smallTabSemibold).foregroundStyle(Theme.onAct)
                    .padding(.horizontal, 7).frame(height: 20)
                    .background(RoundedRectangle(cornerRadius: Radius.row).fill(Theme.act))
                    .offset(x: Self.left + Self.colW + 8, y: y(g.startMinute) + 2)
                Rectangle().fill(Theme.live.opacity(0.6)).frame(width: Self.colW, height: 1).offset(x: Self.left, y: y(g.startMinute))
            }

            table.offset(x: Self.left + Self.colW + 72, y: Self.top - 8)
        }
        .frame(width: 1440, height: 900, alignment: .topLeading)
    }

    private func box(_ e: CalendarEvent, _ p: V5Placement) -> some View {
        let x: CGFloat = Self.left + CGFloat(p.left) * Self.colW + 2 + CGFloat(p.indent)
        let w: CGFloat = CGFloat(p.width) * Self.colW - 5 - CGFloat(p.indent)
        let h = max(y(p.endMinute) - y(p.startMinute) - 2, 18)
        let c = color(e)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Radius.event).fill(Theme.bg)
            RoundedRectangle(cornerRadius: Radius.event).fill(c.opacity(e.isUnaccepted ? 0.16 : 0.32))
            RoundedRectangle(cornerRadius: Radius.event).strokeBorder(e.isUnaccepted ? Theme.fg2 : c, style: StrokeStyle(lineWidth: 1, dash: e.isUnaccepted ? [4, 3] : []))
            if p.cut { Rectangle().fill(Theme.bg).frame(width: 2).padding(.vertical, 1) }
            VStack(alignment: .leading, spacing: 1) {
                Text(e.title).font(.event).foregroundStyle(Theme.fg).lineLimit(1)
                Text("\(fmt.time(e.start))\(e.end > e.start ? "\u{2013}" + fmt.time(e.end) : "") \(reply(e))").font(.eventTab).foregroundStyle(Theme.fg2).lineLimit(1)
                if h > 46 {
                    Text(String(format: "L%d  %.2f+%.2f  +%.0fpt%@", p.level, p.left, p.width, p.indent, p.cut ? "  cut" : ""))
                        .font(.eventTab).foregroundStyle(Theme.fg3).lineLimit(1)
                }
            }
            .padding(.leading, 6).padding(.top, 3)
        }
        .frame(width: w, height: h)
        .offset(x: x, y: y(p.startMinute) + 1)
    }

    private var table: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                cell("Event", 170); cell("Time", 92); cell("Reply", 74); cell("left", 44); cell("width", 48); cell("indent", 50); cell("level", 42); cell("cut", 30)
            }
            .font(.smallSemibold).foregroundStyle(Theme.fg2).frame(height: 24)
            Rectangle().fill(Theme.hair2).frame(height: 1)
            ForEach(rows) { row in
                HStack(spacing: 0) {
                    cell(row.event.title, 170)
                    cell("\(fmt.time(row.event.start))\(row.event.end > row.event.start ? "\u{2013}" + fmt.time(row.event.end) : "")", 92)
                    cell(reply(row.event), 74)
                    if let p = row.place {
                        cell(String(format: "%.2f", p.left), 44); cell(String(format: "%.2f", p.width), 48); cell(String(format: "%.0f", p.indent), 50)
                        cell("\(p.level)", 42); cell(p.cut ? "yes" : "", 30)
                    } else {
                        cell("in +N", 214).foregroundStyle(Theme.live)
                    }
                }
                .font(.smallTab).foregroundStyle(Theme.fg).frame(height: 24)
                Rectangle().fill(Theme.hair).frame(height: 1)
            }
            ForEach(Array(groups.enumerated()), id: \.offset) { i, g in
                VStack(alignment: .leading, spacing: 4) {
                    Text("+\(g.ids.count) at \(String(format: "%02d:%02d", g.startMinute / 60, g.startMinute % 60)): stack rows (every event over the busy time, by start)")
                        .font(.smallSemibold).foregroundStyle(Theme.fg)
                    ForEach(stacks[i], id: \.id) { e in
                        Text("\(fmt.time(e.start))\(e.end > e.start ? "\u{2013}" + fmt.time(e.end) : "")  \(e.title)  \(reply(e))")
                            .font(.smallTab).foregroundStyle(g.ids.contains(e.id) ? Theme.live : Theme.fg2)
                    }
                }
                .padding(.top, 18)
            }
        }
    }

    private func cell(_ s: String, _ w: CGFloat) -> some View { Text(s).lineLimit(1).frame(width: w, alignment: .leading) }
}
