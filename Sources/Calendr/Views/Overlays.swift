import SwiftUI
import CalendrKit

extension AnyTransition {
    /// Command menu: scale 0.98 -> 1, y -4 -> 0, fade.
    static var palette: AnyTransition { .scale(scale: 0.98, anchor: .top).combined(with: .offset(y: -4)).combined(with: .opacity) }
    /// Sheets: scale 0.98 -> 1, fade.
    static var sheet: AnyTransition { .scale(scale: 0.98).combined(with: .opacity) }
    static var toast: AnyTransition { .offset(y: 10).combined(with: .opacity) }
}

/// Floating surfaces over the whole window: the command menu (top 168), the sheets (centred), all over the scrim.
struct OverlayHost: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let isSheet: Bool = { if case .command? = model.overlay { return false }; return model.overlay != nil }()
        ZStack(alignment: .top) {
            if let o = model.overlay {
                Theme.scrim.ignoresSafeArea().onTapGesture { model.closeOverlay() }.transition(.opacity)
                switch o {
                case .command: CommandMenu().padding(.top, 168).transition(.palette)
                case .shortcuts: ShortcutsSheet().frame(maxHeight: .infinity).transition(.sheet)
                case .settings: SettingsSheet().frame(maxHeight: .infinity).transition(.sheet)
                case .deleteRecurring(let id): DeleteRecurringDialog(eventID: id).frame(maxHeight: .infinity).transition(.sheet)
                }
            }
        }
        .animation(isSheet ? Motion.slow : Motion.base, value: model.overlay)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// Floating surface: bg1, radius 14, hair2 edge, the big shadow.
private struct SurfaceStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: Radius.surface + 2).fill(Theme.bg1))
            .clipShape(RoundedRectangle(cornerRadius: Radius.surface + 2))
            .overlay(RoundedRectangle(cornerRadius: Radius.surface + 2).strokeBorder(Theme.hair2, lineWidth: 1))
            .popShadow()
    }
}

extension View {
    func surface() -> some View { modifier(SurfaceStyle()) }
}

// MARK: Undo toast

/// Bottom centre of the grid column.
struct ToastHost: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        ZStack {
            if let t = model.toast { ToastView(toast: t).id(t.id).transition(.toast) }
        }
        .padding(.bottom, 20)
        .animation(Motion.spring, value: model.toast)
    }
}

/// 38 pt pill on bg2: message, "Undo ⌘Z" when it can be undone, ×.
struct ToastView: View {
    @Environment(AppModel.self) private var model
    let toast: AppModel.ToastState
    @State private var hoverUndo = false
    var body: some View {
        HStack(spacing: 10) {
            Text(toast.text).font(.ui(12.5)).foregroundStyle(Theme.fg).lineLimit(1)
            if toast.undo {
                Button { model.dismissToast(); model.undo() } label: {
                    HStack(spacing: 7) {
                        Text("Undo").font(.ui(12.5, .semibold)).foregroundStyle(Theme.fg)
                        Keycaps(keys: ["\u{2318}", "Z"], spacing: 10)
                    }
                    .padding(.leading, 9).padding(.trailing, 5).frame(height: 26)
                    .background(Capsule().fill(hoverUndo ? Theme.hover : .clear))
                    .contentShape(Capsule())
                }
                .buttonStyle(PressStyle(scale: 0.97))
                .onHover { hoverUndo = $0 }
                .animation(Motion.fast, value: hoverUndo)
            }
            IconButton(name: "xmark", size: 9.5, box: 24, color: Theme.fg3) { model.dismissToast() }.clipShape(Circle())
        }
        .padding(.leading, 14).padding(.trailing, 5).frame(height: 38)
        .background(Capsule().fill(Theme.bg2))
        .overlay(Capsule().strokeBorder(Theme.hair2, lineWidth: 1))
        .popShadow()
        .fixedSize()
    }
}

// MARK: Command menu

/// One field for commands, dates, events and people. 620 pt, 50 pt input row, 34 pt rows with leading icons, footer hints.
struct CommandMenu: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        let mode = model.chromeState.paletteMode
        let rows = model.paletteRows
        let idx = min(model.chromeState.paletteIndex, max(0, rows.count - 1))
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                ChromeIcon(name: .search)
                if let crumb = Self.crumb(mode) {
                    Text(crumb).font(.ui(12, .medium)).foregroundStyle(Theme.fg)
                        .padding(.horizontal, 8).frame(height: 22)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bg3))
                }
                TextField("", text: Binding(get: { model.chromeState.paletteQuery }, set: { model.setPaletteQuery($0) }),
                          prompt: Text(Self.placeholder(mode)).foregroundStyle(Theme.fg3))
                    .textFieldStyle(.plain).font(.ui(15)).foregroundStyle(Theme.fg).tint(Theme.fg)
                    .focused($focused)
                    .onSubmit { model.runPaletteSelection() }
            }
            .padding(.horizontal, 16).frame(height: 50)
            .overlay(alignment: .bottom) { Hairline() }

            if rows.isEmpty {
                PaletteEmpty(mode: mode, query: model.chromeState.paletteQuery)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                                if i == 0 || rows[i - 1].section != r.section {
                                    MicroLabel(text: r.section, color: Theme.fg3)
                                        .padding(.horizontal, 10).padding(.top, i == 0 ? 5 : 10).padding(.bottom, 5)
                                }
                                PaletteRowView(row: r, current: i == idx) { model.run(r) }
                                    .onHover { if $0 { model.chromeState.paletteIndex = i } }
                                    .id(r.id)
                            }
                        }
                        .padding(6)
                    }
                    .frame(height: Self.listHeight(rows))
                    .onChange(of: idx) { _, i in if rows.indices.contains(i) { proxy.scrollTo(rows[i].id) } }
                }
            }

            HStack(spacing: 16) {
                if rows.indices.contains(idx) { Hint(keys: ["\u{21A9}"], text: rows[idx].verb) }
                Hint(keys: ["\u{2191}", "\u{2193}"], text: "Move")
                if mode != .all { Hint(keys: ["\u{232B}"], text: "Back") }
                Spacer(minLength: 0)
                Hint(keys: ["esc"], text: "Close")
            }
            .padding(.horizontal, 16).frame(height: 36)
            .overlay(alignment: .top) { Hairline() }
        }
        .frame(width: 620)
        .surface()
        .onAppear { focus() }
        .onChange(of: mode) { _, _ in focus() }
        .onChange(of: model.blurTick) { _, _ in focused = false }
    }

    /// Focus the field with the caret after the text (macOS selects it all on focus).
    private func focus() {
        focused = true
        for d in [0.0, 0.05] {
            after(d) { for w in NSApp.windows { (w.firstResponder as? NSTextView)?.moveToEndOfDocument(nil) } }
        }
    }

    static func crumb(_ m: ChromeV3State.PaletteMode) -> String? {
        switch m { case .all: nil; case .goTo: "Go to date"; case .search: "Events"; case .meet: "Meet with" }
    }

    static func placeholder(_ m: ChromeV3State.PaletteMode) -> String {
        switch m {
        case .all: "Search, go to a date, or run a command"
        case .goTo: "oct 12, next friday, w42, 2026-12-24"
        case .search: "Search events"
        case .meet: "Overlay someone\u{2019}s calendar"
        }
    }

    /// Rows are 34 pt, section labels 13 pt of text with their padding; the list stops growing at 392.
    static func listHeight(_ rows: [PaletteRow]) -> CGFloat {
        var h: CGFloat = 12
        for (i, r) in rows.enumerated() {
            if i == 0 || rows[i - 1].section != r.section { h += (i == 0 ? 5 : 10) + 13 + 5 }
            h += 34
        }
        return min(392, h)
    }
}

struct Hint: View {
    let keys: [String]
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Keycaps(keys: keys, spacing: 9)
            Text(text).font(.ui(11.5)).foregroundStyle(Theme.fg3)
        }
    }
}

struct PaletteRowView: View {
    let row: PaletteRow
    let current: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ChromeIcon(name: row.icon, color: row.colorHex.map { Color(hex: $0) } ?? Theme.fg3).frame(width: 16)
                Text(row.title + (row.more ? "\u{2026}" : "")).font(.ui(13)).foregroundStyle(row.past ? Theme.fg2 : Theme.fg)
                    .lineLimit(1).truncationMode(.tail)
                if let sub = row.sub { Text(sub).font(.calMono(11.5)).foregroundStyle(Theme.fg3).lineLimit(1).fixedSize() }
                if row.shown { Text("shown").font(.ui(11.5)).foregroundStyle(Theme.fg3) }
                Spacer(minLength: 0)
                if !row.keys.isEmpty { Keycaps(keys: row.keys) }
            }
            .padding(.leading, 10).padding(.trailing, 9).frame(height: 34)
            .background(RoundedRectangle(cornerRadius: Radius.row).fill(current ? Theme.actWash : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct PaletteEmpty: View {
    let mode: ChromeV3State.PaletteMode
    let query: String
    var body: some View {
        let q = !query.trimmingCharacters(in: .whitespaces).isEmpty
        let (title, line): (String, String) = switch mode {
        case .goTo: ("No date in that", "Try \u{201C}12 oct\u{201D}, \u{201C}next friday\u{201D}, \u{201C}w42\u{201D} or \u{201C}2026-12-24\u{201D}.")
        case .search: q ? ("No events match", "Search looks at titles and places in the calendars that are shown.") : ("Search events", "Type part of a title or a place.")
        case .meet: ("Nobody by that name", "Only people from your accounts can be overlaid.")
        case .all: ("Nothing matches", "Try a command, an event title, or a date like \u{201C}12 oct\u{201D}.")
        }
        VStack(spacing: 5) {
            Text(title).font(.ui(13.5, .semibold)).foregroundStyle(Theme.fg)
            Text(line).font(.ui(12.5)).foregroundStyle(Theme.fg3).multilineTextAlignment(.center).frame(maxWidth: 340)
        }
        .padding(.horizontal, 20).padding(.top, 30).padding(.bottom, 34)
        .frame(maxWidth: .infinity)
    }
}

// MARK: Sheets

/// Centred sheet: 17 pt title, a small close button, content below.
struct SheetFrame<Content: View>: View {
    @Environment(AppModel.self) private var model
    let title: String
    let width: CGFloat
    var closable = true
    var bottom: CGFloat = 18
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title).font(.ui(17, .semibold)).tracking(-0.37).foregroundStyle(Theme.fg)
                Spacer()
                if closable { IconButton(name: "xmark", size: 10, box: 24) { model.closeOverlay() } }
            }
            .frame(height: 24)
            content
        }
        .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, bottom)
        .frame(width: width)
        .surface()
    }
}

/// Section label of a sheet: 10.5 / 600 caps in fg3.
struct SheetLabel: View {
    let text: String
    var body: some View { MicroLabel(text: text, color: Theme.fg3) }
}

struct ShortcutsSheet: View {
    @Environment(AppModel.self) private var model
    /// Meet with is listed only where it exists.
    static func groups(meetWith: Bool) -> [(String, [(String, String)])] {
        all.map { g in (g.0, g.1.filter { meetWith || $0.1 != "Meet with" }) }
    }
    static let all: [(String, [(String, String)])] = [
        ("Move around", [("T", "Today"), ("J  \u{2192}", "Next period"), ("K  \u{2190}", "Previous period"), ("D  W  M", "Day, week, month"),
                         (".", "Go to date"), ("`", "Sidebar")]),
        ("Events", [("C", "New event at the next free slot"), ("\u{21E5}  \u{21E7}\u{21E5}", "Select next, previous event"),
                    ("\u{2191} \u{2193} \u{2190} \u{2192}", "Move the selection"), ("\u{21A9}", "Edit the title"), ("\u{2325} \u{2191} \u{2193}", "Move by 15 minutes"),
                    ("\u{2325} \u{2190} \u{2192}", "Move by a day"), ("\u{232B}", "Delete"), ("\u{2318} Z", "Undo")]),
        ("Find", [("\u{2318} K", "Command menu"), ("/", "Search events"), ("F", "Meet with"), ("\u{2318} ,", "Settings"), ("?", "This sheet"),
                  ("esc", "Close, then deselect")]),
    ]
    var body: some View {
        SheetFrame(title: "Keyboard shortcuts", width: 820) {
            HStack(alignment: .top, spacing: 32) {
                ForEach(Self.groups(meetWith: model.store.canOverlayTeammates), id: \.0) { g in
                    VStack(alignment: .leading, spacing: 0) {
                        SheetLabel(text: g.0).padding(.bottom, 6)
                        ForEach(g.1, id: \.1) { k, t in
                            // `.sh__r`: the label takes the room, the caps (8 pt gap plus kbd's 3) keep their size
                            HStack(spacing: 12) {
                                Text(t).font(.ui(12.5)).foregroundStyle(Theme.fg).lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading).layoutPriority(1)
                                HStack(spacing: 11) {
                                    ForEach(Array(k.split(separator: " ").enumerated()), id: \.offset) { Keycap(text: String($0.element)) }
                                }
                                .fixedSize()
                            }
                            .frame(height: 30)
                            .overlay(alignment: .top) { Hairline() }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 14)
            // `.win p` resets `.sh__n`'s margin: the note sits right under the rows
            Text("Single keys work whenever the caret is not in a field.").font(.ui(11.5)).foregroundStyle(Theme.fg3)
        }
    }
}

/// A settings row: title and an explanatory line on the left, the control on the right; hairline between rows of a group.
struct SettingsRow<Content: View>: View {
    let title: String
    var detail: String?
    var first = false
    @ViewBuilder var content: Content
    var body: some View {
        // `.st__r`: the text column takes all the room the control leaves
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.ui(13, .medium)).foregroundStyle(Theme.fg)
                if let detail { Text(detail).font(.ui(11.5)).foregroundStyle(Theme.fg3).fixedSize(horizontal: false, vertical: true) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            content.fixedSize()
        }
        .padding(.vertical, 8.5).frame(minHeight: 46)
        .overlay(alignment: .top) { if !first { Hairline() } }
    }
}

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let s = model.settings
        SheetFrame(title: "Settings", width: 600, bottom: 20) {
            SheetLabel(text: "General").padding(.top, 16).padding(.bottom, 2)
            SettingsRow(title: "Appearance", first: true) {
                Segmented(options: [(false, "Ink"), (true, "Paper")], selection: model.isPaper) { model.settings.appearance = $0 ? .light : .dark }
            }
            SheetLabel(text: "Calendar").padding(.top, 16).padding(.bottom, 2)
            SettingsRow(title: "Show week numbers", detail: "A column in the mini month. Click a number to open that week.", first: true) {
                Toggle("", isOn: Binding(get: { model.settings.showWeekNumbers }, set: { model.settings.showWeekNumbers = $0 }))
                    .toggleStyle(ActToggleStyle()).labelsHidden()
            }
            SettingsRow(title: "New events last", detail: "For C and double-click. A drag sets its own length.") {
                Segmented(options: AppSettings.durationChoices.map { ($0, $0 == 60 ? "1 hour" : "\($0) min") }, selection: s.defaultDurationMinutes) {
                    model.settings.defaultDurationMinutes = $0
                }
            }
            SettingsRow(title: "Hour height", detail: s.hourHeight == nil ? "Fits each week when it opens. Drag the hour gutter to change it."
                        : "Set by hand. The grid keeps this height in every week.") {
                TextButton(title: "Fit again", small: true, disabled: s.hourHeight == nil) { model.fitHourScale() }
            }
            SheetLabel(text: "Menu bar").padding(.top, 16).padding(.bottom, 2)
            SettingsRow(title: "Show in the menu bar", detail: "What sits next to the clock while an event is coming up.", first: true) {
                Segmented(options: [(MenuBarDisplay.titleAndCountdown, "Title and countdown"), (.countdown, "Countdown"), (.icon, "Icon only")],
                          selection: s.menuBarDisplay) { model.settings.menuBarDisplay = $0 }
            }
            Text("Accounts and calendar access live in System Settings. Calendr reads what macOS knows.")
                .font(.ui(11.5)).foregroundStyle(Theme.fg3)
        }
    }
}

struct DeleteRecurringDialog: View {
    @Environment(AppModel.self) private var model
    let eventID: String
    var body: some View {
        SheetFrame(title: "Delete recurring event", width: 400, closable: false, bottom: 20) {
            Text("This event repeats. Which events should be deleted?").font(.ui(13)).foregroundStyle(Theme.fg2).padding(.top, 12)
            HStack(spacing: 8) {
                Spacer()
                SecondaryButton(title: "Cancel") { model.closeOverlay() }
                SecondaryButton(title: "This event") { if let e = model.event(id: eventID) { model.delete(e, span: .this) } }
                PrimaryButton(title: "All events") { if let e = model.event(id: eventID) { model.delete(e, span: .all) } }
            }
            .padding(.top, 16)
        }
    }
}
