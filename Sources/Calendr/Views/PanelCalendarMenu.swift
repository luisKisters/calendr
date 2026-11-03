import SwiftUI
import CalendrKit

/// Calendar and colour in one menu, 224 pt (design/mockup-v4 `cal` with `calmenu: one`, `calw: 224`): the writable calendars under
/// their account (name without the domain), then "Event colour" with the calendar's colour and the 11 Google colours, 6 to a row.
struct PanelCalendarMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let e = model.selectedEvent {
            ForEach(model.store.accounts) { a in
                let cals = a.calendars.filter(\.isWritable)
                if !cals.isEmpty {
                    PopSection(text: AccountName.display(a.name), indent: true)
                    ForEach(cals) { c in
                        PopItem(check: e.calendarID == c.id, key: "menu:cal:\(c.id)", action: { model.setSelectedCalendar(c.id) }) {
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: Radius.swatch).fill(Palettes.cc(c.colorHex, dark: scheme == .dark).color).frame(width: 12, height: 12)
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

/// `.sw11`: 20 pt swatches (radius 6) in 6 columns, spread across the row, 8 between rows. The first is the calendar's own colour
/// (an outline); the chosen one has a ring.
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
            ZStack {
                if let hex {
                    RoundedRectangle(cornerRadius: Radius.row).fill(Color(hex: hex))
                } else {
                    RoundedRectangle(cornerRadius: Radius.row).strokeBorder(Theme.fg3, lineWidth: 1.5)
                }
                if on { PanelIcon(name: .check, size: 11, color: hex == nil ? Theme.fg3 : Theme.onDanger) }
            }
            .frame(width: 20, height: 20)
            .overlay {
                if on { RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Theme.fg2, lineWidth: 1.5).padding(-3) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(name)
        .tourAnchor("swatch:\(hex ?? "none")")
    }
}
