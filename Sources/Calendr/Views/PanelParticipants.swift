import SwiftUI
import AppKit
import CalendrKit

/// Participants (design/mockup-v4 `guests: list`, `people: compact`): a summary ("5 participants", "2 yes, 1 maybe …"), then one line per
/// person: the reply mark (14 pt), the name, the role in grey. No pictures. My own row expands to Going · Maybe · Decline. Guests known
/// only by their address are counted in "N without a name · Allow Contacts". Removed guests of an unsent change stay, struck through.
struct PanelParticipants: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let canEdit: Bool
    var focus: FocusState<PanelFocus?>.Binding

    var body: some View {
        let base = model.panelState.unsent[e.id]?.base
        let cur = e.attendees
        let gone = base.map { b in b.attendees.filter { a in !cur.contains { $0.email == a.email && $0.name == a.name } } } ?? []
        let added = base.map { b in Set(cur.filter { a in !b.attendees.contains { $0.email == a.email && $0.name == a.name } }.map(GuestRow.key)) } ?? []
        let canAdd = canEdit && model.store.canEditParticipants
        VStack(alignment: .leading, spacing: 0) {
            if cur.isEmpty && gone.isEmpty {
                if canAdd { addField(empty: true).padding(.top, -8) } else { Text("No participants").foregroundStyle(Theme.fg3) }
            } else {
                HStack(spacing: 2) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(EditorRows.participantCount(cur.count)).font(.textMedium).foregroundStyle(Theme.fg).frame(height: 20)
                        let sum = EditorRows.replySummary(cur)
                        Text(sum.isEmpty ? "all removed" : sum).font(.small).foregroundStyle(Theme.fg3).frame(height: 16)
                    }
                    Spacer(minLength: 0)
                    PanelIconButton(icon: .mail) { mail() }.help("Email participants")
                    PanelIconButton(icon: .more) { model.copyToPasteboard(cur.map(\.email).filter { !$0.isEmpty }.joined(separator: ", ")); model.showToast("Copied all addresses") }
                        .help("Copy all addresses")
                }
                .frame(height: 40, alignment: .top)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(cur.enumerated()), id: \.offset) { _, a in
                        GuestRow(eventID: e.id, a: a, gone: false, added: added.contains(GuestRow.key(a)), canEdit: canEdit, isDraft: model.isDraftOpen)
                    }
                    ForEach(Array(gone.enumerated()), id: \.offset) { _, a in
                        GuestRow(eventID: e.id, a: a, gone: true, added: false, canEdit: canEdit, isDraft: model.isDraftOpen)
                    }
                }
                .padding(.top, 4)
                // names from Contacts fill the gaps; the hint offers access once (mockup: hidden once Contacts is allowed)
                let bare = EditorRows.withoutName(model.displayed(cur + gone))
                if bare > 0 && !model.services.contacts.isAllowed { NameHint(count: bare) }
                if canAdd { addField(empty: false) }
            }
        }
    }

    /// `.addin`: 32 pt, radius 8, bg2. Typing filters the people the store knows; Return adds the first one, or the typed address.
    private func addField(empty: Bool) -> some View {
        let focused = focus.wrappedValue == .guest
        return TextField("", text: Binding(get: { model.panelMenus.guestQuery }, set: { model.panelMenus.guestQuery = $0; model.panelMenus.open = .guests }), prompt: nil)
            .textFieldStyle(.plain).font(.text).foregroundStyle(Theme.fg)
            .panelPlaceholder(empty ? "Add participants" : "Add participant", when: model.panelMenus.guestQuery.isEmpty)
            .focused(focus, equals: .guest)
            .onSubmit {
                let q = model.panelMenus.guestQuery
                if let first = model.guestSuggestions(q).first, !q.isEmpty { model.addGuest(first) }
                else if !q.trimmingCharacters(in: .whitespaces).isEmpty { model.addGuest(q); model.panelMenus.guestQuery = ""; model.closePanelMenu() }
                after(0.02) { focus.wrappedValue = .guest }
            }
            .padding(.horizontal, 8).frame(height: Dim.field)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(focused ? Theme.bg : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(focused ? Theme.fg3 : Theme.hair2, lineWidth: focused ? 1.5 : 1))
            .padding(.horizontal, -8)
            .padding(.top, 6)
            .panelMenuAnchor(.guests)
            .onChange(of: focused) { _, f in
                if f { model.panelMenus.open = .guests } else if model.panelMenus.open == .guests { after(0.15) { if focus.wrappedValue != .guest && model.panelMenus.open == .guests { model.closePanelMenu() } } }
            }
    }

    private func mail() {
        let to = e.attendees.filter { !$0.isMe && !$0.email.isEmpty }.map(\.email).joined(separator: ",")
        guard !to.isEmpty else { return }
        if !model.opensOutside { model.showToast("Opens Mail"); return }
        if let u = URL(string: "mailto:\(to)?subject=\(MapLinks.encode(e.title))") { NSWorkspace.shared.open(u) }
    }
}

/// `.gr.one`: 28 pt, the reply mark, the name and the role; copy, details and remove show on hover.
struct GuestRow: View {
    @Environment(AppModel.self) private var model
    let eventID: String
    let a: Attendee
    let gone: Bool
    let added: Bool
    let canEdit: Bool
    let isDraft: Bool
    @State private var hover = false

    static func key(_ a: Attendee) -> String { "\(a.email)|\(a.name ?? "")" }

    var body: some View {
        let key = "guest:\(a.isMe ? "me" : (a.email.isEmpty ? a.label : a.email))"
        let h = hover || HoverProbe.shared.target == key
        // expanded per event: another event's "me" row never opens by itself
        let open = model.panelMenus.expandedGuest == "\(eventID)|\(key)"
        // the name from Contacts or Google when the event has none (display only: the stored guest keeps its bare address)
        let shown = model.displayed(a)
        HStack(alignment: .center, spacing: 8) {
            ReplyMark(status: gone ? nil : (a.isOrganizer ? .confirmed : a.status)).padding(.top, open ? 0 : 0)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(shown.label).foregroundStyle(gone ? Theme.fg3 : Theme.fg).strikethrough(gone).lineLimit(1).truncationMode(.tail)
                    let role = EditorRows.role(a)
                    if !role.isEmpty { Text(role).font(.small).foregroundStyle(Theme.fg3).lineLimit(1).fixedSize() }
                }
                .frame(minHeight: 20)
                if open {
                    if a.isMe {
                        if !isDraft {
                            Segmented(options: [(ResponseStatus.confirmed, "Going"), (.tentative, "Maybe"), (.declined, "Decline")], selection: a.status,
                                      enabled: model.canRespond && !a.isOrganizer) { model.setMyReply($0) }
                                .padding(.top, 4).padding(.bottom, 2)
                        }
                    } else if shown.name != nil && !a.email.isEmpty {
                        Text(a.email).font(.small).foregroundStyle(Theme.fg3).lineLimit(1).frame(height: 16)
                    }
                }
            }
            Spacer(minLength: 0)
            if gone || added { UnsentDot(removed: gone) }
            if h {
                HStack(spacing: 0) {
                    if gone {
                        PanelIconButton(icon: .history) { model.restoreGuest(a) }.help("Keep this guest")
                    } else {
                        if !a.email.isEmpty { PanelIconButton(icon: .copy) { model.copyGuestAddress(a) }.help("Copy address") }
                        PanelIconButton(icon: open ? .collapse : .expand) {
                            model.panelMenus.expandedGuest = open ? nil : "\(eventID)|\(key)"
                        }
                        .help(open ? "Less" : (a.isMe ? "My reply" : "Details"))
                        if canEdit && !a.isMe && !a.isOrganizer && model.store.canEditParticipants {
                            PanelIconButton(icon: .x) { model.removeSelectedGuest(email: a.email, name: a.name) }.help("Remove")
                        }
                    }
                }
            }
        }
        .padding(.leading, 8).padding(.vertical, 2)
        .frame(minHeight: 28)
        .background(RoundedRectangle(cornerRadius: Radius.row).fill(h ? Theme.hover : Color.clear))
        .padding(.leading, -8)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .tourAnchor(key)
    }
}

/// The 14 pt reply mark: going (check), maybe (question), declined (cross), no reply (clock).
struct ReplyMark: View {
    let status: ResponseStatus?
    var body: some View {
        Group {
            switch status {
            case .confirmed?: PanelIcon(name: .check, size: 13, color: Theme.replyYes)
            case .tentative?: PanelIcon(name: .help, size: 13, color: Theme.replyMaybe)
            case .declined?: PanelIcon(name: .x, size: 12, color: Theme.replyNo)
            case .needsAction?: PanelIcon(name: .clock, size: 13, color: Theme.fg3)
            case nil: Color.clear
            }
        }
        .frame(width: 14, height: 14)
        .help(status.map { PanelText.replyName($0) } ?? "")
    }
}

/// `.namehint`: guests known only by their address, and one way to fix that: Allow Contacts (macOS asks once).
struct NameHint: View {
    @Environment(AppModel.self) private var model
    let count: Int
    var body: some View {
        Button { model.allowContacts() } label: {
            HStack(spacing: 8) {
                PanelIcon(name: .contacts, size: 14, color: Theme.fg2)
                Text("\(count) without a name").foregroundStyle(Theme.fg2)
                Spacer(minLength: 0)
                Text("Allow Contacts").font(.smallMedium).foregroundStyle(Theme.fg)
            }
            .font(.small)
            .padding(.horizontal, 8).frame(height: 32)
            .background(HoverFill(key: "namehint"))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, -8).padding(.top, 4)
        .tourAnchor("namehint")
    }
}
