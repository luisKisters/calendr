import SwiftUI
import AppKit
import HorionKit

/// The right column (mockup-v11 `.right`): 320 wide on the rail, a pane edge at its left. The search field on top; under it the
/// event when one is selected, the search results while the field has text, otherwise Now, Up next and Later today (no heading,
/// no shortcut list: v8 decision C, the shortcuts stay behind ? and ⌘K). Row boxes sit at 12 pt, content edges at 20 pt. The
/// header's right-column button (⌥⌘I) hides it; selecting an event or searching shows it again. The content swaps with a 180 ms fade.
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
            if let e, PanelFoot.shows(model, e) { PanelFoot(e: e).transition(.opacity) }
        }
        .frame(width: PanelMetrics.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.rail)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.hair).frame(width: 1) }
    }
}

/// Column metrics (mockup-v11 `.srch`, `.card.dc`, `.lab2`, `.later`): row boxes 12 pt in from the column, content 20 pt in.
enum ColumnDim {
    static let box: CGFloat = 12
    static let content: CGFloat = 20
    /// `.srch`: padding 10 12 6 around a 28 pt field.
    static let searchRow: CGFloat = 44
    /// `.card.dc .ttl`: a 36 pt time column, a 7 pt bar column, 8 pt gaps; the title starts 51 pt into the content.
    static let timeColumn: CGFloat = 36
    static let barColumn: CGFloat = 7
    static let gap: CGFloat = 8
    /// `.later`: 26 pt rows.
    static let row: CGFloat = 26
}

/// `.srch label`: magnifier, "Search events", the `/` hint; 28 pt, radius 8, on `raised` (Paper adds a hair2 edge). With the
/// keyboard it gets the 2 pt focus ring.
struct ColumnSearchField: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        let q = model.chromeState.columnQuery
        HStack(spacing: Space.s) {
            ChromeIcon(name: .search, size: Dim.iconGlyphSmall, color: Theme.fg3)
            TextField("", text: Binding(get: { model.chromeState.columnQuery }, set: { model.setColumnQuery($0) }),
                      prompt: Text("Search events").foregroundStyle(Theme.fg3))
                .textFieldStyle(.plain).font(.text).tracking(TypeTrack.text).foregroundStyle(Theme.fg).tint(Theme.fg)
                .focused($focused)
                .onSubmit { model.openFirstColumnResult() }
            if !q.isEmpty {
                Button { model.clearColumnSearch() } label: {
                    SFIcon(name: "xmark.circle.fill", size: 11, color: Theme.fg3).frame(width: 16, height: 16).contentShape(Rectangle())
                }
                .buttonStyle(.plain).help("Clear  esc")
            } else {
                Keycap(text: "/")
            }
        }
        .padding(.leading, 10).padding(.trailing, Space.s).frame(height: Dim.row)
        .background(RoundedRectangle(cornerRadius: Radius.control).fill(Theme.bg2))
        .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Theme.searchEdge, lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: Radius.control + 2).strokeBorder(focused ? Theme.focus : Color.clear, lineWidth: 2).padding(-2))
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .padding(.horizontal, ColumnDim.box).padding(.top, 10).padding(.bottom, 6)
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

/// `.lab2`, `.sh`: 11 fg3 (500 in Dark, 400 in Paper), sentence case, on the content edge, line 18.
struct ColumnLabel: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    var body: some View {
        Text(text).font(.smallLabel(dark: scheme == .dark)).tracking(TypeTrack.small).foregroundStyle(Theme.fg3).padding(.horizontal, ColumnDim.content)
            .frame(maxWidth: .infinity, minHeight: TypeSize.textLine, alignment: .leading)
    }
}

/// Nothing selected: the Now card (the lead, with Join and a pane edge under it), Up next, then "Later today". No frames.
struct PanelTodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let t = model.panelState.today
        VStack(alignment: .leading, spacing: 0) {
            if let live = t.live { PanelNextCard(event: live, live: true, lead: true) }
            if let next = t.next { PanelNextCard(event: next, live: false, lead: t.live == nil) }
            if t.live == nil && t.next == nil {
                Text("Nothing else today.").font(.text).foregroundStyle(Theme.fg3).padding(.horizontal, ColumnDim.content).padding(.top, Space.m)
            }
            if !t.later.isEmpty {
                // `.lab2 { padding: 16px 20px 4px }` (24 minus the card's 4 pt margin and its 4 pt bottom).
                ColumnLabel(text: "Later today").padding(.top, Space.l).padding(.bottom, Space.xs)
                ForEach(t.later) { e in PanelLaterRow(event: e) }
            }
        }
        .padding(.bottom, Space.l)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// `.card.dc` without a frame: the label with the countdown, then the time column (start fg2, end fg3), a 3 pt bar in the
/// calendar's mark colour and the title with its length and guests. The lead card (Now, or Up next when nothing runs) has a
/// 12 / 600 title, the Join button and a pane edge under it.
struct PanelNextCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let event: CalendarEvent
    let live: Bool
    var lead = false

    var body: some View {
        let dark = scheme == .dark
        let minutes = Countdown.minutes(from: model.now, to: live ? event.end : event.start)
        let place = event.location.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        let mark = Palettes.cc(model.hexColor(of: event), dark: dark).color
        let length = Int(event.end.timeIntervalSince(event.start) / 60)
        let guests = event.attendees.filter { !$0.isMe }.count
        let textEdge = ColumnDim.timeColumn + ColumnDim.barColumn + 2 * ColumnDim.gap
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.s) {
                Text(live ? "Now" : "Up next").font(.smallMedium).tracking(TypeTrack.small).foregroundStyle(Theme.fg3)
                Text(live ? "\(MenuBarMenu.span(minutes)) left" : "in \(MenuBarMenu.span(minutes))")
                    .font(.smallTabMedium).tracking(TypeTrack.small).foregroundStyle(live ? Theme.live : Theme.fg2)
                Spacer(minLength: 0)
            }
            .frame(height: TypeSize.textLine)
            Button { model.panelOpen(event) } label: {
                HStack(alignment: .top, spacing: ColumnDim.gap) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(model.fmt.time(event.start)).font(.smallTab).foregroundStyle(Theme.fg2).frame(height: TypeSize.smallLine)
                        Text(model.fmt.time(event.end)).font(.smallLabelTab(dark: dark)).foregroundStyle(Theme.fg3).frame(height: TypeSize.smallLine)
                    }
                    .padding(.top, 3)
                    .frame(width: ColumnDim.timeColumn, alignment: .trailing)
                    RoundedRectangle(cornerRadius: Radius.leadBar).fill(mark).frame(width: 3).padding(.vertical, 2)
                        .frame(width: ColumnDim.barColumn)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title).font(lead ? .textSemibold : .textMedium).tracking(lead ? TypeTrack.heading : TypeTrack.text)
                            .foregroundStyle(Theme.fg).lineLimit(1).frame(height: TypeSize.headingLine)
                        Text(MenuBarMenu.span(length) + (guests > 0 ? " \u{00B7} \(guests) guest\(guests == 1 ? "" : "s")" : "")
                             + (place.isEmpty ? "" : " \u{00B7} \(place)"))
                            .font(.smallTab).tracking(TypeTrack.small).foregroundStyle(Theme.fg2).lineLimit(1).frame(height: TypeSize.smallLine)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            if let call = CallLink.parse(event) {
                // design/call-link round 3: Copy beside the wide Join.
                HStack(spacing: Space.xs) {
                    JoinCallButton(event: event, call: call, ghost: !live)
                    CopyLinkButton { model.copyCallLink(event) }
                }
                .padding(.top, Space.m).padding(.leading, textEdge)
            }
        }
        // `.card.dc.lead`: margin 2 20 6, padding 10 0 16, a pane edge below; the others margin 0 20 4, padding 8 0 10.
        .padding(.top, lead ? 10 : Space.s).padding(.bottom, lead ? Space.l + 1 : 10)
        .overlay(alignment: .bottom) { if lead { Rectangle().fill(Theme.hair).frame(height: 1) } }
        .padding(.horizontal, ColumnDim.content)
        .padding(.top, lead ? 2 : 0).padding(.bottom, lead ? 6 : Space.xs)
        .tourAnchor("card:\(event.id)")
    }
}

/// `.join` (v11 looks.css, calm): 30 pt, radius 8, on `raised` with a 1 pt edge and a small shadow, the call logo, "Join Google Meet"
/// 12 / 500 fg1 and the ⌘J hint in fg3; hover mixes fg1 5 % into the fill. Not a white or black slab. On an Up next card it is the
/// `ghost`: no fill, a 1 pt hair2 edge, the rail hover.
struct JoinCallButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let event: CalendarEvent
    let call: CallLink
    var ghost = false
    @State private var hover = false

    var body: some View {
        let hot = hover || HoverProbe.shared.target == "join:\(event.id)"
        let dark = scheme == .dark
        let fill: Color = ghost ? (hot ? Theme.hoverRail : .clear) : (hot ? Theme.joinHover : Theme.bg2)
        Button { model.joinCall(event) } label: {
            HStack(spacing: 7) {
                CallLogo(kind: call.kind, size: 14)
                Text(call.kind == .other ? "Join call" : "Join \(call.name)").font(.textMedium).tracking(TypeTrack.text).foregroundStyle(Theme.fg)
                Keycaps(keys: ["\u{2318}J"])
            }
            .frame(maxWidth: .infinity).frame(height: 30)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(fill)
                .shadow(color: InkRGB.black.color.opacity(dark && !ghost ? 0.3 : 0), radius: 0.5, y: 1)
                .shadow(color: InkRGB.paperShadow.color.opacity(dark || ghost ? 0 : 0.08), radius: 1, y: 1))
            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(ghost ? Theme.hair2 : Theme.joinEdge, lineWidth: 1).padding(dark || ghost ? 0 : -1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hot)
        .help("Join \(call.name)  \u{2318}J")
    }
}

/// `.later`: the start time (36 pt, right-aligned, fg2), a 3 × 14 bar in the calendar's mark colour, the title (12 / 400 fg1);
/// 26 pt, the hover box 12 pt in from the column. Selects the event.
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
            HStack(spacing: ColumnDim.gap) {
                Text(time ?? model.fmt.time(event.start)).font(.smallTab).foregroundStyle(Theme.fg2).lineLimit(1)
                    .frame(width: ColumnDim.timeColumn, alignment: .trailing)
                RoundedRectangle(cornerRadius: Radius.bar).fill(Palettes.cc(model.hexColor(of: event), dark: scheme == .dark).color)
                    .frame(width: 3, height: 14).padding(.horizontal, 2)
                Self.title(event.title, match: match).tracking(TypeTrack.text).foregroundStyle(declined ? Theme.fg2 : Theme.fg).strikethrough(declined, color: Theme.fg2)
                    .lineLimit(1).truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // `.later .vid`: a call, in fg3.
                if CallLink.parse(event) != nil { SFIcon(name: "video", size: 10.5, color: Theme.fg3) }
            }
            .padding(.horizontal, Space.s).frame(height: ColumnDim.row)
            .background(RoundedRectangle(cornerRadius: Radius.row).fill(selected ? Theme.selected : hot ? Theme.hoverRail : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hot)
        .padding(.horizontal, ColumnDim.box)
    }
}

extension PanelLaterRow {
    /// The title in 12, with every occurrence of `match` (case and accents ignored) in 500.
    static func title(_ t: String, match: String?) -> Text {
        let q = (match ?? "").trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Text(t).font(.text) }
        var out = Text(verbatim: "")
        var rest = t[...]
        while let r = rest.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) {
            out = out + Text(verbatim: String(rest[..<r.lowerBound])).font(.text) + Text(verbatim: String(rest[r])).font(.textMedium)
            rest = rest[r.upperBound...]
        }
        return out + Text(verbatim: String(rest)).font(.text)
    }
}
