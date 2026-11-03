import SwiftUI
import AppKit
import CalendrKit

// The editor's menus (design/mockup-v4 `.pop`, `popHTML`, `place()`): Theme.pop, radius 12, a hair2 edge, padding 6, 28 pt rows.
// They are drawn in the window (not as NSMenus) so the calendar menu can hold the colour grid and snapshots can show them.

/// The layer over the whole window that draws the open menu next to its anchor. A press outside closes it. `frames` are the anchor
/// preferences resolved in the window (RootView's `overlayPreferenceValue`): they are exact in every layout pass.
struct PanelMenuLayer: View {
    @Environment(AppModel.self) private var model
    static let space = "calendr.root"
    let frames: [String: CGRect]
    /// Measured size per menu: a menu stays invisible until it is measured, so it never shows in the wrong place.
    @State private var sizes: [PanelMenu: CGSize] = [:]

    var body: some View {
        let menus = model.panelMenus
        GeometryReader { geo in
            if let m = menus.open, let a = frames["menu.\(m.rawValue)"] {
                ZStack(alignment: .topLeading) {
                    if m != .places {
                        Color.clear.contentShape(Rectangle()).onTapGesture { model.closePanelMenu() }
                    }
                    let size = sizes[m]
                    PanelMenuContent(menu: m)
                        .padding(6)
                        .frame(width: Self.width(m), alignment: .topLeading)
                        .surface()
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { sizes[m] = $0 }
                        .opacity(size == nil ? 0 : 1)
                        .offset(Self.origin(m, anchor: a, size: size ?? .zero, in: geo.size))
                        .transition(.opacity.combined(with: .offset(y: -4)))
                }
                // the menu's own rows, for the walkthrough's pointer
                .backgroundPreferenceValue(EditorAnchorKey.self) { rows in
                    GeometryReader { g in
                        Color.clear.onChange(of: rows.mapValues { g[$0] }, initial: true) { _, r in menus.frames.merge(r) { _, new in new } }
                    }
                }
            }
        }
        .animation(Motion.fast, value: menus.open)
        .onChange(of: frames, initial: true) { _, f in menus.frames = f }
    }

    static func width(_ m: PanelMenu) -> CGFloat {
        switch m {
        case .calendar: 224
        case .guests: 400
        case .maps: 272
        case .places: 296
        case .reminders: 230
        case .call: 280
        case .send, .inviteSend: 260
        case .deleteSend: 300
        }
    }

    /// Mockup `place()`: "left" menus end 8 pt to the left of the right column, 6 above the anchor; "below" menus line their text up
    /// with the field's text, 4 under it; "above" menus end with the anchor, 6 over it. Always 8 pt inside the window.
    static func origin(_ m: PanelMenu, anchor r: CGRect, size: CGSize, in win: CGSize) -> CGSize {
        let w = width(m), h = size.height
        var x: CGFloat, y: CGFloat
        switch m {
        case .calendar, .guests:
            x = win.width - PanelMetrics.width - w - 8
            y = r.minY - 6
        case .send, .inviteSend:
            x = r.maxX - w
            y = r.minY - h - 6
        case .deleteSend:
            x = r.minX - 8
            y = r.maxY + 4
        case .maps, .places, .reminders, .call:
            // `r` is the field's text frame. The menu's first row text sits 16 in (6 padding, 10 row padding), 40 after a check column,
            // 42 after a 16 pt logo (the maps and call menus line up the item text, not the section heading).
            let menuText: CGFloat = switch m {
            case .reminders: 40
            case .places: 39
            default: 42
            }
            x = r.minX - menuText
            y = r.maxY + 4
            if y + h > win.height - 8 { y = r.minY - h - 4 }
        }
        x = max(8, min(x, win.width - w - 8))
        y = max(8, min(y, win.height - h - 8))
        return CGSize(width: x, height: y)
    }
}

/// Named frames of the editor (`tourAnchor`, `panelMenuAnchor`), as anchors: resolved in the window by RootView.
struct EditorAnchorKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Publishes this control's frame for the menu it opens.
    func panelMenuAnchor(_ m: PanelMenu) -> some View { tourAnchor("menu.\(m.rawValue)") }
    /// Publishes this view's frame under a name (menus, and the walkthrough's pointer: `PanelMenuState.frames`).
    func tourAnchor(_ key: String) -> some View {
        // merged with the names inside it (a row keeps its fields' names)
        transformAnchorPreference(key: EditorAnchorKey.self, value: .bounds) { all, a in if !key.isEmpty { all[key] = a } }
    }
}

/// `.pop .it`: 28 pt, padding 4 x 10, radius 6, hover wash. An optional check column (14 pt) leads.
struct PopItem<Label: View, End: View>: View {
    var check: Bool?
    var key = ""
    var danger = false
    var alignTop = false
    /// The keyboard's row (Return picks it).
    var highlighted = false
    let action: () -> Void
    @ViewBuilder var label: Label
    @ViewBuilder var end: End
    @State private var hover = false

    var body: some View {
        let h = hover || highlighted || (!key.isEmpty && HoverProbe.shared.target == key)
        Button(action: action) {
            HStack(alignment: alignTop ? .top : .center, spacing: 10) {
                if let check {
                    PanelIcon(name: .check, size: 14, color: Theme.fg).opacity(check ? 1 : 0).frame(width: 14)
                }
                label
                Spacer(minLength: 0)
                end
            }
            .font(.text).foregroundStyle(danger ? Theme.replyNo : Theme.fg)
            .padding(.horizontal, 10).padding(.vertical, alignTop ? 7 : 4)
            .frame(maxWidth: .infinity, minHeight: Dim.row, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.row).fill(h ? Theme.hover : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .tourAnchor(key)
    }
}

extension PopItem where End == EmptyView {
    init(check: Bool? = nil, key: String = "", danger: Bool = false, alignTop: Bool = false, highlighted: Bool = false, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.init(check: check, key: key, danger: danger, alignTop: alignTop, highlighted: highlighted, action: action, label: label, end: { EmptyView() })
    }
}

/// `.pop .sec`: small fg3 heading, 8 above and 4 under; `indent` lines it up with the text after a check column.
struct PopSection: View {
    let text: String
    var indent = false
    var body: some View {
        Text(text).font(.small).foregroundStyle(Theme.fg3).lineLimit(1).truncationMode(.tail)
            .padding(.leading, indent ? 34 : 10).padding(.trailing, 10).padding(.top, 8).padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `.pop .sep`
struct PopSep: View {
    var body: some View { Rectangle().fill(Theme.hair).frame(height: 1).padding(.vertical, 6).padding(.horizontal, 4) }
}

/// Title and a second line in fg3 (`.mt` with `.sub2`).
struct PopTwoLine: View {
    let title: Text
    let sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            title.lineLimit(1).frame(height: 18)
            if !sub.isEmpty { Text(sub).font(.small).foregroundStyle(Theme.fg3).lineLimit(1).frame(height: 16) }
        }
    }
}

/// The contents of each menu.
struct PanelMenuContent: View {
    @Environment(AppModel.self) private var model
    let menu: PanelMenu

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch menu {
            case .calendar: PanelCalendarMenu()
            case .reminders: reminders
            case .maps: maps
            case .places: places
            case .call: call
            case .guests: PanelGuestMenu()
            case .send:
                PopItem(key: "menu:discard", danger: true, action: { model.discardUnsent() }) { Text("Discard changes") }
                PopItem(key: "menu:quiet", action: { model.sendUnsent(notify: false) }) { Text("Save without sending") } end: {
                    PanelIcon(name: .help, size: 15).help("Saves the change in Google. Nobody gets an email.")
                }
            case .inviteSend:
                PopItem(key: "menu:noinvite", action: { model.closePanelMenu(); model.saveDraft(notify: false) }) { Text("Save without sending invite") } end: {
                    PanelIcon(name: .help, size: 15).help("Saves the event. Guests get nothing yet.")
                }
            case .deleteSend:
                PopItem(key: "menu:noemail", action: {
                    if case .deleteWithGuests(let id)? = model.overlay { model.deleteWithGuests(id, notify: false) }
                }) { Text("Delete without cancellation email") } end: {
                    PanelIcon(name: .help, size: 15).help("Guests keep the event in their calendars.")
                }
            }
        }
    }

    private var reminders: some View {
        let on = model.selectedEvent?.reminders ?? []
        return ForEach(Reminders.choices, id: \.self) { r in
            PopItem(check: on.contains(r), key: "menu:rem\(r)", action: { model.toggleReminder(r) }) {
                Text(Reminders.label(r)).font(.textTab)
            }
        }
    }

    @ViewBuilder private var maps: some View {
        let loc = model.selectedEvent?.location ?? ""
        PopSection(text: loc)
        PopItem(key: "menu:apple", action: { model.openMaps(.apple) }) { HStack(spacing: 10) { MapLogo(kind: .apple); Text("Open in Apple Maps") } }
        PopItem(key: "menu:google", action: { model.openMaps(.google) }) { HStack(spacing: 10) { MapLogo(kind: .google); Text("Open in Google Maps") } }
        PopSep()
        PopItem(key: "menu:copy", action: { model.copyLocation() }) { HStack(spacing: 10) { PanelIcon(name: .copy, size: 15, color: Theme.fg2); Text("Copy address") } }
    }

    @ViewBuilder private var places: some View {
        let q = model.panelMenus.placeQuery.trimmingCharacters(in: .whitespaces)
        ForEach(Array(model.panelMenus.places.enumerated()), id: \.element) { i, p in
            PopItem(key: "menu:place:\(p.title)", alignTop: true, highlighted: i == 0, action: { model.pickPlace(p.text) }) {
                HStack(alignment: .top, spacing: 10) {
                    PanelIcon(name: .pin, size: 15).padding(.top, 1)
                    PopTwoLine(title: PanelMenuContent.highlight(p.title, q), sub: p.subtitle)
                }
            }
        }
        PopSep()
        PopItem(key: "menu:asis", action: { model.pickPlace(model.panelMenus.placeQuery) }) {
            HStack(spacing: 10) {
                PanelIcon(name: .notes, size: 15)
                Text("Use \u{201C}\(model.panelMenus.placeQuery)\u{201D} as written").foregroundStyle(Theme.fg2).lineLimit(1)
            }
        }
    }

    @ViewBuilder private var call: some View {
        if model.canInventVideoLink {
            PopItem(key: "menu:meet", alignTop: true, action: { model.addMeet() }) {
                HStack(alignment: .top, spacing: 10) {
                    CallLogo(kind: .meet, size: 16).padding(.top, 2)
                    PopTwoLine(title: Text("Google Meet"), sub: model.isDraftOpen ? "Link made when you save" : "A new meeting link")
                }
            }
            PopSep()
        }
        PopItem(key: "menu:paste", action: { model.startPastingLink() }) {
            HStack(spacing: 10) { PanelIcon(name: .link, size: 16); Text("Paste a link\u{2026}") }
        }
    }

    /// The query in bold inside a name (mockup `hl`).
    static func highlight(_ text: String, _ q: String) -> Text {
        guard !q.isEmpty, let r = text.range(of: q, options: .caseInsensitive) else { return Text(text) }
        return Text(text[..<r.lowerBound]) + Text(text[r]).font(.textSemibold) + Text(text[r.upperBound...])
    }
}

/// The guest field's suggestions: people not on the list yet, "Recent" when the field is empty.
struct PanelGuestMenu: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let q = model.panelMenus.guestQuery
        let list = model.guestSuggestions(q)
        if q.trimmingCharacters(in: .whitespaces).isEmpty { PopSection(text: "Recent") }
        else if list.isEmpty { PopSection(text: "Nobody found. Type a full address to invite it.").padding(.bottom, 4) }
        ForEach(Array(list.enumerated()), id: \.element) { i, t in
            PopItem(key: "menu:guest:\(t.email)", highlighted: i == 0, action: { model.addGuest(t) }) {
                PopTwoLine(title: PanelMenuContent.highlight(t.name, q.trimmingCharacters(in: .whitespaces)), sub: t.email)
            } end: {
                PanelIcon(name: .history, size: 14).help("Recent guest")
            }
        }
        PopSep()
        PopItem(key: "menu:contacts", action: { model.closePanelMenu(); model.allowContacts() }) {
            HStack(spacing: 10) { PanelIcon(name: .contacts, size: 15, color: Theme.fg2); Text("Allow Contacts access to find more people").foregroundStyle(Theme.fg2) }
        }
    }
}
