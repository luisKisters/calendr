import SwiftUI
import CalendrKit

/// The location field (design/mockup-v4 `loc: list`, `locopen: menu`). Typing suggests places (`MKLocalSearchCompleter`, the demo list in
/// demo mode); a click on a filled field opens Apple Maps, Google Maps and Copy.
struct PanelLocationRow: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let canEdit: Bool
    var focus: FocusState<PanelFocus?>.Binding

    var body: some View {
        let focused = focus.wrappedValue == .place
        let open = model.panelMenus.open
        TextField("", text: Binding(get: { model.selectedEvent?.location ?? "" }, set: { model.setLocationText($0) }), axis: .vertical)
            .textFieldStyle(.plain).font(.text).foregroundStyle(Theme.fg).lineLimit(1...3)
            .panelPlaceholder(EditorRow.location.placeholder!, when: e.location.isEmpty)
            .focused(focus, equals: .place).disabled(!canEdit)
            .onSubmit {
                if open == .places, let first = model.panelMenus.places.first { model.pickPlace(first.text) } else { focus.wrappedValue = nil }
            }
            .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
            .editorField(focused: focused && open != .maps, editable: canEdit || !e.location.isEmpty, key: "field:location", held: open == .maps)
            .panelMenuAnchor(.maps)
            .panelMenuAnchor(.places)
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded {
                if !e.location.isEmpty && open != .places { model.openPanelMenu(.maps) }
            })
            .onChange(of: focused) { _, f in if !f && open == .places { model.closePanelMenu() } }
    }
}
