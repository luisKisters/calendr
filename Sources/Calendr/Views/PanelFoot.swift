import SwiftUI
import CalendrKit

/// The editor's foot (design/mockup-v4 `.pfoot`, `send: split`): pinned under the column, a hairline on top, 12 x 14 padding.
/// A new event: Discard and Save (with guests: a split "Send invite | ▾ Save without sending invite"). An event with unsent changes:
/// "Not sent yet" and a split "Send update | ▾" (Discard changes, Save without sending). ⌘↩ sends.
struct PanelFoot: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent

    static func shows(_ m: AppModel, _ e: CalendarEvent) -> Bool { m.draft?.id == e.id || m.panelState.unsent[e.id] != nil }

    var body: some View {
        HStack(spacing: 8) {
            if model.draft?.id == e.id {
                Spacer(minLength: 0)
                GhostButton(title: "Discard", key: "esc") { model.discardDraft() }
                if model.store.canSendUpdates(calendarID: e.calendarID) && e.attendees.contains(where: { !$0.isMe }) {
                    SplitButton(title: "Send invite", menu: .inviteSend, help: "Send invite  \u{2318}\u{21A9}") { model.saveDraft() }
                } else {
                    PanelFillButton(title: "Save", key: "\u{21A9}") { model.saveDraft() }.frame(height: Dim.field)
                }
            } else {
                Text("Not sent yet").font(.small).foregroundStyle(Theme.fg3)
                Spacer(minLength: 0)
                SplitButton(title: "Send update", menu: .send, help: "Send update  \u{2318}\u{21A9}") { model.sendUnsent(notify: true) }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Theme.bg)
        .overlay(alignment: .top) { Hairline() }
    }
}

/// `.btn.ghost`: fg2 text, a wash on hover, 32 pt.
struct GhostButton: View {
    let title: String
    var key: String?
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        let h = hover || HoverProbe.shared.target == "btn:\(title)"
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(.textMedium).foregroundStyle(h ? Theme.fg : Theme.fg2)
                if let key { Keycap(text: key) }
            }
            .padding(.horizontal, 12).frame(height: Dim.field)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(h ? Theme.hover : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .onHover { hover = $0 }
        .tourAnchor("btn:\(title)")
    }
}

/// `.btn`: bg2, 32 pt, radius 8, 500.
struct PlainButton: View {
    let title: String
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        let h = hover || HoverProbe.shared.target == "btn:\(title)"
        Button(action: action) {
            Text(title).font(.textMedium).foregroundStyle(Theme.fg)
                .padding(.horizontal, 12).frame(height: Dim.field)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(h ? Theme.bg3 : Theme.bg2))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .onHover { hover = $0 }
        .tourAnchor("btn:\(title)")
    }
}

/// `.split`: one 32 pt button in two parts: the action, and a chevron (32 wide, a 25 % line between) that opens its menu.
/// `red`: the destructive colour (Delete event).
struct SplitButton: View {
    @Environment(AppModel.self) private var model
    let title: String
    let menu: PanelMenu
    var red = false
    var help = ""
    let action: () -> Void
    @State private var hoverA = false
    @State private var hoverB = false

    var body: some View {
        let fill = red ? Theme.danger : Theme.act
        let ink = red ? Theme.onDanger : Theme.onAct
        let ha = hoverA || HoverProbe.shared.target == "split:\(title)"
        let hb = hoverB || HoverProbe.shared.target == "split:\(menu.rawValue)" || model.panelMenus.open == menu
        HStack(spacing: 0) {
            Button(action: action) {
                Text(title).font(.textSemibold).foregroundStyle(ink)
                    .padding(.horizontal, 12).frame(maxHeight: .infinity)
                    .background(ink.opacity(ha ? 0.1 : 0))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).help(help)
            .onHover { hoverA = $0 }
            Rectangle().fill(ink.opacity(0.25)).frame(width: 1)
            Button { model.openPanelMenu(menu) } label: {
                PanelIcon(name: .down, size: 14, color: ink).frame(width: 32).frame(maxHeight: .infinity)
                    .background(ink.opacity(hb ? 0.1 : 0))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hoverB = $0 }
        }
        .frame(height: Dim.field)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: Radius.control))
        .panelMenuAnchor(menu)
    }
}
