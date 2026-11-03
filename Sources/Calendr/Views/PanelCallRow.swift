import SwiftUI
import AppKit
import CalendrKit

/// The call row (design/mockup-v4 `callui: big`): a big Join button (32 pt, radius 8, act, the call logo) with the meeting link under it,
/// editable. Without a call: "Add conferencing" opens the call menu (Google Meet where a link can be made, "Paste a link…").
struct PanelCallRow: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let canEdit: Bool
    var focus: FocusState<PanelFocus?>.Binding

    var body: some View {
        let call = CallLink.parse(e)
        let link = e.conferencing.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = model.panelState.unsent[e.id]?.base
        let gone = base.flatMap { CallLink.parse($0) }
        VStack(alignment: .leading, spacing: 0) {
            if model.panelState.newMeet.contains(e.id) {
                HStack(spacing: 8) {
                    CallLogo(kind: .meet, size: 16)
                    Text("Meet link is made when you save").font(.textMedium).foregroundStyle(Theme.fg2)
                }
                .frame(maxWidth: .infinity).frame(height: Dim.field)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(Theme.bg2))
                LinkField(value: "", editable: false, focus: focus, unsentAdded: false, copy: {}, remove: { model.removeCall() }) { _ in false }
                    .padding(.top, 8)
            } else if let call {
                JoinBigButton(call: call) { model.joinCall(e) }
                LinkField(value: call.display, editable: canEdit, focus: focus, unsentAdded: base != nil && (base.map { CallLink.parse($0) == nil } ?? false),
                          copy: { model.copyCallLink() }, remove: canEdit ? { model.removeCall() } : nil) { model.setCallLink($0) }
                    .padding(.top, 8)
            } else if !link.isEmpty {
                // a web address that is not a call: the link only
                LinkField(value: link, editable: canEdit, focus: focus, unsentAdded: false, copy: { model.copyToPasteboard(link) },
                          remove: canEdit ? { model.removeCall() } : nil) { model.setCallLink($0) }
            } else if let gone, base != nil {
                HStack(spacing: 4) {
                    Text(gone.kind == .meet ? "Google Meet \(gone.code ?? "")" : gone.display).strikethrough().foregroundStyle(Theme.fg3).lineLimit(1)
                    Spacer(minLength: 0)
                    UnsentDot(removed: true)
                    PanelIconButton(icon: .history) { model.restoreCall() }.help("Keep the call")
                }
                .frame(minHeight: 20)
            } else if model.panelMenus.pastingLink {
                PanelCommitField(value: "", placeholder: "Paste a Zoom, Teams or other link, then Return", editable: true, focusKey: .video, focus: focus,
                                 commit: { model.setCallLink($0) })
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onAppear { after(0.02) { focus.wrappedValue = .video } }
            } else if canEdit {
                Button { model.openPanelMenu(.call) } label: {
                    Text(EditorRow.call.placeholder!).foregroundStyle(Theme.fg3).frame(maxWidth: .infinity, minHeight: 20, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .editorField(focused: false, editable: true, key: "field:call", held: model.panelMenus.open == .call)
                .panelMenuAnchor(.call)
            } else {
                Text("No video call").foregroundStyle(Theme.fg3)
            }
        }
    }
}

/// `.joinbig`: the whole width, 32 pt, radius 8, act fill, the call logo and "Join Google Meet".
struct JoinBigButton: View {
    let call: CallLink
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        let h = hover || HoverProbe.shared.target == "joinbig"
        Button(action: action) {
            HStack(spacing: 8) {
                CallLogo(kind: call.kind, size: 16, glyphColor: Theme.onAct)
                Text(call.kind == .other ? "Join call" : "Join \(call.name)").font(.textSemibold)
            }
            .foregroundStyle(Theme.onAct)
            .frame(maxWidth: .infinity).frame(height: Dim.field)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(h ? Theme.actHover : Theme.act))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .onHover { hover = $0 }
        .animation(Motion.fast, value: h)
        .help("Join \(call.name)")
        .tourAnchor("joinbig")
    }
}

/// `.linkrow`: the meeting link in fg2 small, editable; copy and remove show on hover.
struct LinkField: View {
    let value: String
    let editable: Bool
    var focus: FocusState<PanelFocus?>.Binding
    let unsentAdded: Bool
    let copy: () -> Void
    let remove: (() -> Void)?
    let commit: (String) -> Bool
    @State private var text = ""
    @State private var hover = false

    var body: some View {
        let focused = focus.wrappedValue == .video
        let h = hover || HoverProbe.shared.target == "field:link" || focused
        HStack(spacing: 2) {
            TextField("", text: $text, prompt: nil)
                .textFieldStyle(.plain).font(.small).foregroundStyle(focused ? Theme.fg : Theme.fg2).lineLimit(1)
                .focused(focus, equals: .video).disabled(!editable)
                .onSubmit { if !commit(text) { text = value }; focus.wrappedValue = nil }
                .panelPlaceholder("Meeting link", when: text.isEmpty, font: .small)
                .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
                .editorField(focused: focused, editable: editable, key: "field:link")
                .padding(.trailing, 8)
            if unsentAdded { UnsentDot(removed: false) }
            PanelIconButton(icon: .copy, action: copy).help("Copy link").opacity(h ? 1 : 0)
            if let remove { PanelIconButton(icon: .x, action: remove).help("Remove call").opacity(h ? 1 : 0) }
        }
        .frame(height: 26)
        .onHover { hover = $0 }
        .onAppear { text = value }
        .onChange(of: value) { _, v in if !focused { text = v } }
        .onChange(of: focused) { _, f in if !f && text != value { if !commit(text) { text = value } } }
    }
}

/// `.dot`: a change that is not sent yet (a guest or a call added or removed).
struct UnsentDot: View {
    let removed: Bool
    var body: some View {
        Circle().fill(Theme.fg2).frame(width: 7, height: 7).padding(.trailing, 6)
            .help(removed ? "Removed, not sent yet" : "Added, not sent yet")
    }
}
