import SwiftUI
import CalendrKit

/// Calendar and colour in one menu, 224 pt (design/mockup-v4 `cal` with `calmenu: one`, `calw: 224`): the writable calendars under
/// their account (name without the domain), then "Event colour" with the calendar's colour and the 11 Google colours, 6 to a row.
struct PanelCalendarMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let e = model.selectedEvent {
            ForEach(model.store.accounts) { a in
                let cals = a.calendars.filter(\.isWritable)
                if !cals.isEmpty {
                    PopSection(text: AccountName.display(a.name), indent: true)
                    ForEach(cals) { c in
                        PopItem(check: e.calendarID == c.id, key: "menu:cal:\(c.id)", action: { model.setSelectedCalendar(c.id) }) {
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: Radius.swatch).fill(Theme.calendarMark(c.colorHex)).frame(width: 12, height: 12)
                                Text(c.title).lineLimit(1).truncationMode(.tail)
                            }
                        }
                    }
                }
            }
            PopSep()
            PopSection(text: "Event colour", indent: true)
            SwatchGrid(current: e.colorHex, calendarHex: model.calendarColorHex(of: e)) { model.setSelectedColor($0) }
                .padding(.leading, 34).padding(.trailing, 10).padding(.top, 6).padding(.bottom, 10)
        }
    }
}

/// `.sw12`: 20 pt swatches (radius 4, like the calendar squares) in 6 columns, spread across the row, 8 between rows. Every swatch is drawn in the calendar-colour
/// recipe (`Theme.calendarMark`), the same colour the sidebar, the calendar rows above and the settings show, so a colour picked
/// here looks like the calendar it matches. The first is the calendar's own colour (no event colour); the chosen one has a ring:
/// 2 pt of the menu, then 1.5 pt fg1.
struct SwatchGrid: View {
    let current: String?
    let calendarHex: String
    let pick: (String?) -> Void

    var body: some View {
        let items: [String?] = [nil] + EventColors.google.map(\.hex)
        let rows = stride(from: 0, to: items.count, by: EventColors.columns).map { Array(items[$0..<min($0 + EventColors.columns, items.count)]) }
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { i, hex in
                        if i > 0 { Spacer(minLength: 0) }
                        swatch(hex)
                    }
                    ForEach(row.count..<EventColors.columns, id: \.self) { _ in Spacer(minLength: 0); Color.clear.frame(width: 20, height: 20) }
                }
            }
        }
    }

    private func swatch(_ hex: String?) -> some View {
        let on = current?.uppercased() == hex?.uppercased()
        let name = hex.flatMap { h in EventColors.google.first { $0.hex == h }?.name } ?? "Calendar colour"
        return Button { pick(hex) } label: {
            RoundedRectangle(cornerRadius: Radius.small).fill(Theme.calendarMark(hex ?? calendarHex))
                .frame(width: 20, height: 20)
                .overlay {
                    if on { RoundedRectangle(cornerRadius: Radius.small + 3.5).strokeBorder(Theme.fg, lineWidth: 1.5).padding(-3.5) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(name)
        .tourAnchor("swatch:\(hex ?? "none")")
    }
}
