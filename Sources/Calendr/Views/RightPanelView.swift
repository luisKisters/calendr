import SwiftUI
import AppKit
import CalendrKit

/// The right column (design/mockup-v4 `.right`): one width, always present. The search field on top; under it the event when one
/// is selected, the search results while the field has text, otherwise Today and the useful shortcuts. Box edges sit at 8 pt,
/// content edges at 20 pt. The content swaps with a 180 ms fade; the grid never changes width.
struct RightPanelView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let e = model.selectedEvent
        let searching = model.columnSearching
        let key = e.map { "d:\($0.id)" } ?? (searching ? "search" : "today")
        VStack(spacing: 0) {
            ColumnSearchField()
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    if let e { PanelDetailView(e: e) } else if searching { ColumnSearchResults() } else { PanelTodayView() }
                }
                .id(key)
                .transition(.asymmetric(insertion: .opacity, removal: .identity))
            }
            .animation(Motion.base, value: key)
        }
        .padding(.leading, 1)
        .frame(width: PanelMetrics.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.hair).frame(width: 1) }
    }
}

/// Column metrics (`.srch`, `.today-h`, `.card`, `.later`, `.short`): boxes 8 pt in from the column, content 20 pt in.
enum ColumnDim {
    static let box: CGFloat = 8
    static let content: CGFloat = 20
    /// `.srch`: 12 above the field, 6 below.
    static let searchRow: CGFloat = 50
}

/// `.srch`: magnifier, "Search events", 32 pt, radius 8, a hairline edge (quiet chrome) that turns into a 1.5 pt fg3 ring with the keyboard.
struct ColumnSearchField: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        let q = model.chromeState.columnQuery
        HStack(spacing: Space.s) {
            ChromeIcon(name: .search, size: 15, color: Theme.fg3)
            TextField("", text: Binding(get: { model.chromeState.columnQuery }, set: { model.setColumnQuery($0) }),
                      prompt: Text("Search events").foregroundStyle(Theme.fg3))
                .textFieldStyle(.plain).font(.text).foregroundStyle(Theme.fg).tint(Theme.fg)
                .focused($focused)
                .onSubmit { model.openFirstColumnResult() }
            if !q.isEmpty {
                Button { model.clearColumnSearch() } label: {
                    SFIcon(name: "xmark.circle.fill", size: 11, color: Theme.fg3).frame(width: 16, height: 16).contentShape(Rectangle())
                }
                .buttonStyle(.plain).help("Clear  esc")
            }
        }
        .padding(.horizontal, Space.m).frame(height: Dim.field)
        .background(RoundedRectangle(cornerRadius: Radius.control).fill(focused ? Theme.bg : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(focused ? Theme.fg3 : Theme.hair2, lineWidth: focused ? 1.5 : 1))
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .padding(.horizontal, ColumnDim.box).padding(.top, 12).padding(.bottom, 6)
        .frame(height: ColumnDim.searchRow)
        .help("Search events  /")
        .onChange(of: model.chromeState.searchFocusTick) { _, _ in focus() }
        .onChange(of: focused) { _, f in if model.chromeState.searchFocused != f { model.chromeState.searchFocused = f } }
        .onChange(of: model.chromeState.searchFocused) { _, f in if !f { focused = false } }
        .onChange(of: model.blurTick) { _, _ in focused = false }
        .animation(Motion.fast, value: focused)
    }

    /// Takes the keyboard, again after the command menu has closed (closing it resigns the first responder for 80 ms).
    private func focus() {
        focused = true
        for d in [0.0, 0.05, 0.12] {
            after(d) {
                guard model.chromeState.searchFocused else { return }
                focused = true
                for w in NSApp.windows { (w.firstResponder as? NSTextView)?.moveToEndOfDocument(nil) }
            }
        }
    }
}

/// `.sres`: the results grouped by day, each day a label and `.later` rows ("all day" for all-day events). They replace Today.
struct ColumnSearchResults: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let groups = model.columnResults
        VStack(alignment: .leading, spacing: 0) {
            if groups.isEmpty {
                Text("No events match \u{201C}\(model.chromeState.columnQuery.trimmingCharacters(in: .whitespaces))\u{201D}.")
                    .font(.text).foregroundStyle(Theme.fg3)
                    .padding(.horizontal, ColumnDim.content).padding(.vertical, Space.xl)
            } else {
                ForEach(groups) { g in
                    ColumnLabel(text: model.chromeDay(g.day)).padding(.top, Space.l).padding(.bottom, Space.xs)
                    ForEach(g.events) { e in
                        PanelLaterRow(event: e, time: e.isAllDay ? "all day" : nil, match: model.chromeState.columnQuery) { model.openColumnResult(e) }
                    }
                }
            }
        }
        .padding(.bottom, Space.l)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// `.lab2`, `.sh`, `.short b`: 11.5 / 600 in fg3, sentence case, on the content edge.
struct ColumnLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.smallSemibold).foregroundStyle(Theme.fg3).padding(.horizontal, ColumnDim.content)
            .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
    }
}

/// Nothing selected: Today (title 18), the Now and Up next cards with Join, Later, then the useful shortcuts. No frames.
struct PanelTodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let t = model.panelState.today
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today").font(.title18).tracking(-0.35).foregroundStyle(Theme.fg)
                Spacer(minLength: 0)
                Text(PanelText.day(model.now, model.fmt)).font(.smallTab).foregroundStyle(Theme.fg3)
            }
            .frame(height: 26)
            .padding(.horizontal, ColumnDim.content).padding(.top, 14).padding(.bottom, Space.s)
            if let live = t.live { PanelNextCard(event: live, live: true) }
            if let next = t.next { PanelNextCard(event: next, live: false) }
            if t.live == nil && t.next == nil {
                Text("Nothing else today.").font(.text).foregroundStyle(Theme.fg3).padding(.horizontal, ColumnDim.content).padding(.top, Space.xs)
            }
            if !t.later.isEmpty {
                ColumnLabel(text: "Later").padding(.top, Space.xl).padding(.bottom, 6)
                ForEach(t.later) { e in PanelLaterRow(event: e) }
            }
            // `.short`: 24 above its box, 16 inside it
            UsefulShortcutsView().padding(.top, Space.xl + Space.l)
        }
        .padding(.bottom, Space.l)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// `.card` without its frame (round 3): the label with the countdown, the bar with title and times, Join with the call logo.
struct PanelNextCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let event: CalendarEvent
    let live: Bool
    @State private var hover = false

    var body: some View {
        let minutes = Countdown.minutes(from: model.now, to: live ? event.end : event.start)
        let soon = live || minutes <= 15
        let bar = Palettes.cc(model.hexColor(of: event), dark: scheme == .dark).color
        let length = Int(event.end.timeIntervalSince(event.start) / 60)
        let guests = event.attendees.filter { !$0.isMe }.count
        let hot = hover || HoverProbe.shared.target == "card:\(event.id)"
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Text(live ? "Now" : "Up next").font(.smallSemibold).foregroundStyle(Theme.fg3)
                Text(live ? "\(MenuBarMenu.span(minutes)) left" : "in \(MenuBarMenu.span(minutes))")
                    .font(.smallTab).foregroundStyle(soon ? Theme.live : Theme.fg2)
                Spacer(minLength: 0)
            }
            .frame(height: 17)
            Button { model.panelOpen(event) } label: {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: Radius.bar).fill(bar).frame(width: 3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title).font(.textSemibold).foregroundStyle(Theme.fg).lineLimit(1).frame(height: 18)
                        Text("\(model.fmt.time(event.start))\u{2013}\(model.fmt.time(event.end)) \u{00B7} \(MenuBarMenu.span(length))"
                             + (guests > 0 ? " \u{00B7} \(guests + 1) people" : ""))
                            .font(.smallTab).foregroundStyle(Theme.fg2).lineLimit(1).frame(height: 17)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, Space.s)
            if let call = CallLink.parse(event) {
                JoinCallButton(event: event, call: call).padding(.top, 10)
            }
        }
        .padding(.horizontal, Space.m).padding(.vertical, Space.s)
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(hot ? Theme.hover : Color.clear))
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hot)
        .padding(.horizontal, ColumnDim.box).padding(.bottom, Space.xs)
    }
}

/// `.join` (logo pick): 32 pt, radius 8, the act colour, the call logo and "Join Google Meet".
struct JoinCallButton: View {
    @Environment(AppModel.self) private var model
    let event: CalendarEvent
    let call: CallLink
    @State private var hover = false

    var body: some View {
        let hot = hover || HoverProbe.shared.target == "join:\(event.id)"
        Button { model.joinCall(event) } label: {
            HStack(spacing: 7) {
                CallLogo(kind: call.kind, size: 15)
                Text(call.kind == .other ? "Join call" : "Join \(call.name)").font(.smallSemibold).foregroundStyle(Theme.onAct)
            }
            .frame(maxWidth: .infinity).frame(height: Dim.field)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(hot ? Theme.actHover : Theme.act))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hot)
        .help("Join \(call.name)")
    }
}

/// `.later`: start time, calendar bar, title, a video mark for calls; 28 pt, the hover box on the 8 pt edge. Selects the event.
struct PanelLaterRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let event: CalendarEvent
    /// Replaces the start time ("all day" in the search results).
    var time: String?
    /// The search query: its occurrences in the title are bold (`hl()` in the mockup).
    var match: String?
    var action: (() -> Void)?
    @State private var hover = false

    var body: some View {
        let selected = model.selectedEventID == event.id
        let hot = hover || HoverProbe.shared.target == "row:\(event.id)"
        let declined = event.myReply == .declined
        Button { if let action { action() } else { model.panelOpen(event) } } label: {
            HStack(spacing: Space.s) {
                Text(time ?? model.fmt.time(event.start)).font(.smallTab).foregroundStyle(Theme.fg2).frame(width: 40, alignment: .leading)
                RoundedRectangle(cornerRadius: Radius.bar).fill(Palettes.cc(model.hexColor(of: event), dark: scheme == .dark).color).frame(width: 3, height: 14)
                Self.title(event.title, match: match).foregroundStyle(declined ? Theme.fg3 : Theme.fg).strikethrough(declined, color: Theme.fg3)
                    .lineLimit(1).truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if CallLink.parse(event) != nil { SFIcon(name: "video", size: 10.5, color: Theme.fg3).opacity(0.7) }
            }
            .padding(.horizontal, Space.m).frame(height: Dim.row)
            .background(RoundedRectangle(cornerRadius: Radius.row).fill(selected || hot ? Theme.hover : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hot)
        .padding(.horizontal, ColumnDim.box)
    }
}

extension PanelLaterRow {
    /// The title in 12.5, with every occurrence of `match` (case and accents ignored) in 600.
    static func title(_ t: String, match: String?) -> Text {
        let q = (match ?? "").trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Text(t).font(.text) }
        var out = Text(verbatim: "")
        var rest = t[...]
        while let r = rest.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) {
            out = out + Text(verbatim: String(rest[..<r.lowerBound])).font(.text) + Text(verbatim: String(rest[r])).font(.textSemibold)
            rest = rest[r.upperBound...]
        }
        return out + Text(verbatim: String(rest)).font(.text)
    }
}

/// `.short`: "Useful shortcuts", then six 28 pt rows of label and grey key hint. Each row runs its shortcut.
struct UsefulShortcutsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ColumnLabel(text: "Useful shortcuts").padding(.bottom, Space.xs)
            ForEach(model.usefulShortcuts, id: \.title) { UsefulShortcutRow(shortcut: $0) }
        }
    }
}

struct UsefulShortcutRow: View {
    @Environment(AppModel.self) private var model
    let shortcut: UsefulShortcut
    @State private var hover = false

    var body: some View {
        let hot = hover || HoverProbe.shared.target == "short:\(shortcut.title)"
        Button { model.runUseful(shortcut) } label: {
            HStack(spacing: Space.s) {
                Text(shortcut.title).font(.small).foregroundStyle(hot ? Theme.fg : Theme.fg2).lineLimit(1)
                Spacer(minLength: 0)
                Keycaps(keys: shortcut.keys, spacing: 4)
            }
            .padding(.horizontal, Space.m).frame(height: Dim.row)
            .background(RoundedRectangle(cornerRadius: Radius.row).fill(hot ? Theme.hover : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hot)
        .padding(.horizontal, ColumnDim.box)
    }
}
