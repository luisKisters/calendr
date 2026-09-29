import SwiftUI
import CalendrKit

extension AnyTransition {
    /// Command palette: scale 0.98 -> 1, y -4 -> 0, fade.
    static var palette: AnyTransition { .scale(scale: 0.98, anchor: .top).combined(with: .offset(y: -4)).combined(with: .opacity) }
    /// Sheets (shortcuts, settings, dialogs): y -10 -> 0, fade.
    static var sheet: AnyTransition { .offset(y: -10).combined(with: .opacity) }
    static var toast: AnyTransition { .offset(y: 14).combined(with: .scale(scale: 0.96)).combined(with: .opacity) }
}

struct OverlayHost: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let isSheet: Bool = { switch model.overlay { case .shortcuts?, .settings?, .deleteRecurring?: return true; default: return false } }()
        ZStack(alignment: .top) {
            if let o = model.overlay {
                Theme.scrim.ignoresSafeArea().onTapGesture { model.closeOverlay() }.transition(.opacity)
                Group {
                    switch o {
                    case .command: CommandPalette().padding(.top, 92).transition(.palette)
                    case .teammate: TeammatePalette().padding(.top, 92).transition(.palette)
                    case .goToDate: GoToDatePalette().padding(.top, 92).transition(.palette)
                    case .shortcuts: ShortcutsSheet().padding(.top, 60).transition(.sheet)
                    case .settings: SettingsSheet().padding(.top, 96).transition(.sheet)
                    case .deleteRecurring(let id): DeleteRecurringDialog(eventID: id).padding(.top, 200).transition(.sheet)
                    }
                }
            }
            VStack {
                Spacer()
                if let t = model.toast {
                    ToastView(toast: t).id(t.id).transition(.toast).padding(.bottom, 28)
                }
            }
        }
        .animation(isSheet ? Motion.sheet : Motion.slow, value: model.overlay)
        .animation(Motion.spring, value: model.toast)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct ToastView: View {
    @Environment(AppModel.self) private var model
    let toast: AppModel.ToastState
    var body: some View {
        HStack(spacing: 12) {
            SFIcon(name: "checkmark.circle", size: 16, color: Theme.actLift)
            Text(toast.text).font(.system(size: 13)).foregroundStyle(Theme.paper)
            if toast.undo {
                Button { model.dismissToast(); model.undo() } label: {
                    HStack(spacing: 8) {
                        Text("Undo").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.paper)
                        Keycaps(keys: ["\u{2318}", "Z"])
                    }
                    .padding(.leading, 10).padding(.trailing, 6).frame(height: 28)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.ink600))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.hair, lineWidth: 1))
                    .contentShape(Rectangle())
                }.buttonStyle(PressStyle(scale: 0.97))
            }
        }
        .padding(.leading, 16).padding(.trailing, toast.undo ? 8 : 16).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(Theme.ink700))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Theme.hair, lineWidth: 1))
        .popShadow()
    }
}

struct PaletteFrame<Content: View>: View {
    @Environment(AppModel.self) private var model
    let placeholder: String
    @Binding var text: String
    var width: CGFloat = 640
    @FocusState private var focused: Bool
    let onSubmit: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SFIcon(name: "magnifyingglass", size: 16, color: Theme.haze).frame(width: 18)
                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.hazeDim))
                    .textFieldStyle(.plain).font(.system(size: 15)).foregroundStyle(Theme.paper)
                    .focused($focused).onSubmit(onSubmit)
                Keycap(text: "esc")
            }
            .padding(.horizontal, 18).frame(height: 54)
            Hairline()
            content
            PaletteFooter()
        }
        .frame(width: width)
        .frame(maxHeight: 520)
        .fixedSize(horizontal: false, vertical: true)
        .background(RoundedRectangle(cornerRadius: Radius.surface).fill(Theme.ink800))
        .clipShape(RoundedRectangle(cornerRadius: Radius.surface))
        .overlay(RoundedRectangle(cornerRadius: Radius.surface).strokeBorder(Theme.hair, lineWidth: 1))
        .popShadow()
        .onAppear { focused = true }
        .onChange(of: model.blurTick) { _, _ in focused = false }
    }
}

struct PaletteFooter: View {
    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) { Keycaps(keys: ["\u{2191}", "\u{2193}"]); Text("Navigate") }
            HStack(spacing: 6) { Keycap(text: "\u{21A9}"); Text("Select") }
            HStack(spacing: 6) { Keycap(text: "esc"); Text("Close") }
            Spacer()
        }
        .font(.system(size: 12)).foregroundStyle(Theme.haze)
        .padding(.horizontal, 14).frame(height: 38)
        .background(Theme.ink900)
        .overlay(alignment: .top) { Hairline() }
    }
}

struct PaletteRow<Label: View, Trailing: View>: View {
    let selected: Bool
    var icon: String?
    let action: () -> Void
    let label: Label
    let trailing: Trailing
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon { SFIcon(name: icon, size: 14, color: selected ? Theme.actLift : Theme.haze).frame(width: 16) }
                label
                Spacer(minLength: 8)
                trailing
            }
            .padding(.leading, 12).padding(.trailing, 10)
            .frame(height: 36)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(selected ? Theme.actWash : (hover ? Theme.hover : Color.clear)))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hover = $0 }
        .animation(Motion.fast, value: selected)
    }
}

extension CommandID {
    var symbol: String {
        switch self {
        case .createEvent: "plus"
        case .meetWith, .showTeammate: "person"
        case .recurringLink, .oneOffLink: "link"
        case .addNotionDatabase: "tablecells.badge.ellipsis"
        case .goToDate: "calendar"
        case .goToToday: "clock"
        case .leftAlignToday, .previousPeriod: "chevron.left"
        case .nextPeriod: "chevron.right"
        case .viewDay, .viewWeek, .viewMonth: "rectangle.split.3x1"
        case .toggleSidebar: "sidebar.left"
        case .toggleRightPanel: "sidebar.right"
        case .settings: "gearshape"
        }
    }
}

struct CommandPalette: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var m = model
        let sections = model.commandSections
        let flat = CommandRegistry.flat(sections)
        PaletteFrame(placeholder: "Type a command\u{2026}", text: $m.commandQuery, onSubmit: {
            if !flat.isEmpty { model.perform(flat[min(model.commandIndex, flat.count - 1)].id) }
        }) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if sections.isEmpty {
                            Text("No commands found").font(.system(size: 12.5)).foregroundStyle(Theme.haze).padding(.horizontal, 12).padding(.top, 8).frame(height: 32)
                        }
                        ForEach(Array(sections.enumerated()), id: \.element.id) { si, sec in
                            CommandSectionView(section: sec, first: si == 0, flat: flat)
                        }
                    }.padding(.horizontal, 8).padding(.top, 6).padding(.bottom, 8)
                }
                .onChange(of: model.commandIndex) { _, i in proxy.scrollTo(i) }
            }
        }
    }
}

struct CommandSectionView: View {
    @Environment(AppModel.self) private var model
    let section: CommandSection
    let first: Bool
    let flat: [Command]
    var body: some View {
        MicroLabel(text: section.title).padding(.horizontal, 12).padding(.top, first ? 8 : 12).padding(.bottom, 5)
        ForEach(section.commands) { c in
            let idx = flat.firstIndex(where: { $0.id == c.id }) ?? 0
            CommandRowView(c: c, selected: idx == model.commandIndex).id(idx)
        }
    }
}

struct CommandRowView: View {
    @Environment(AppModel.self) private var model
    let c: Command
    let selected: Bool
    var body: some View {
        PaletteRow(selected: selected, icon: c.id.symbol, action: { model.perform(c.id) },
                   label: Text(c.title).font(.system(size: 13.5)).foregroundStyle(Theme.paper),
                   trailing: Keycaps(keys: c.chips))
    }
}

struct TeammateAvatar: View {
    let name: String
    let color: Color
    var body: some View {
        let initials = name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
        Text(initials).font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "#0F0E14"))
            .frame(width: 24, height: 24).background(Circle().fill(color))
    }
}

struct TeammatePalette: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var m = model
        let list = model.filteredTeammates(model.teammateQuery)
        PaletteFrame(placeholder: "Show teammate calendar\u{2026}", text: $m.teammateQuery, onSubmit: {
            if !list.isEmpty { model.showTeammate(list[min(model.teammateIndex, list.count - 1)]) }
        }) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if list.isEmpty {
                            Text(model.store.teammates.isEmpty ? "No teammates found in your calendars yet" : "No teammates found").font(.system(size: 12.5)).foregroundStyle(Theme.haze).padding(.horizontal, 12).frame(height: 32)
                        }
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, t in
                            PaletteRow(selected: i == model.teammateIndex, action: { model.showTeammate(t) },
                                       label: HStack(spacing: 12) {
                                    TeammateAvatar(name: t.name, color: Color(hex: AppModel.teammatePalette[i % AppModel.teammatePalette.count]))
                                    Text(t.name).font(.system(size: 13.5)).foregroundStyle(Theme.paper)
                                    Text(t.email).font(.system(size: 12)).foregroundStyle(Theme.haze)
                                }.lineLimit(1),
                                       trailing: Group { if model.shownTeammates.contains(t) { SFIcon(name: "checkmark", size: 12, color: Theme.actLift) } }).id(i)
                        }
                    }.padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 8)
                }
                .onChange(of: model.teammateIndex) { _, i in proxy.scrollTo(i) }
            }
        }
    }
}

struct GoToDatePalette: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var m = model
        PaletteFrame(placeholder: "Go to date\u{2026}", text: $m.goToText, onSubmit: { model.submitGoToDate() }) {
            VStack(alignment: .leading, spacing: 0) {
                if model.goToText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Try \u{201C}oct 12\u{201D}, \u{201C}12.10.\u{201D}, \u{201C}next friday\u{201D}, \u{201C}tomorrow\u{201D} or \u{201C}2026-12-24\u{201D}").font(.system(size: 12.5)).foregroundStyle(Theme.haze).padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 12)
                } else if let d = model.goToPreview {
                    MicroLabel(text: "Preview").padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 5)
                    PaletteRow(selected: true, icon: "calendar", action: { model.submitGoToDate() },
                               label: Text("Go to \(model.fmt.fullDate(d))").font(.system(size: 13.5)).foregroundStyle(Theme.paper),
                               trailing: Keycap(text: "\u{21A9}"))
                    .padding(.horizontal, 8).padding(.bottom, 8)
                } else {
                    Text("No date found for \u{201C}\(model.goToText)\u{201D}").font(.system(size: 12.5)).foregroundStyle(Theme.haze).padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 12)
                }
            }
        }
    }
}

struct SheetFrame<Content: View>: View {
    @Environment(AppModel.self) private var model
    let title: String
    let width: CGFloat
    var closable = true
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold)).tracking(-0.2).foregroundStyle(Theme.paper)
                Spacer()
                if closable { IconButton(name: "xmark", size: 12, box: 28) { model.closeOverlay() } }
            }
            .padding(.leading, 20).padding(.trailing, 14).frame(height: 54)
            .overlay(alignment: .bottom) { Hairline() }
            content
        }
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: Radius.surface).fill(Theme.ink800))
        .clipShape(RoundedRectangle(cornerRadius: Radius.surface))
        .overlay(RoundedRectangle(cornerRadius: Radius.surface).strokeBorder(Theme.hair, lineWidth: 1))
        .popShadow()
    }
}

struct ShortcutsSheet: View {
    static let groups: [(String, [(String, [String])])] = [
        ("Navigation", [("Go to today", ["T"]), ("Left-align today in view", ["option", "T"]), ("Next period", ["J", "or", "\u{2192}"]), ("Previous period", ["K", "or", "\u{2190}"]),
                        ("Go to date", ["."]), ("Day view", ["D"]), ("Week view", ["W"]), ("Month view", ["M"])]),
        ("Calendar", [("Create event", ["C"]), ("Meet with\u{2026}", ["F"]), ("Show teammate calendar", ["P"]), ("Scheduling link", ["S"]),
                      ("Add Notion database", ["O"]), ("Undo", ["\u{2318}", "Z"]), ("Delete event", ["\u{232B}"])]),
        ("Windows", [("Command menu", ["\u{2318}", "K"]), ("Menu bar calendar", ["control", "\u{2318}", "K"]), ("Main window", ["\u{2318}", "1"]), ("Settings", ["\u{2318}", ","]),
                     ("Toggle sidebar", ["`"]), ("Toggle right panel", ["\u{2318}", "/"]), ("Refresh calendars", ["\u{2318}", "R"]), ("Search events", ["/"]), ("All keyboard shortcuts", ["?"]), ("Deselect or close", ["esc"])]),
    ]
    var body: some View {
        SheetFrame(title: "Keyboard shortcuts", width: 640) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Self.groups, id: \.0) { g in
                        MicroLabel(text: g.0).padding(.top, 16).padding(.bottom, 4)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 44), GridItem(.flexible())], spacing: 0) {
                            ForEach(g.1, id: \.0) { r in
                                HStack {
                                    Text(r.0).font(.system(size: 13)).foregroundStyle(Theme.paper)
                                    Spacer()
                                    Keycaps(keys: r.1)
                                }.frame(height: 30)
                            }
                        }
                    }
                }.padding(.horizontal, 22).padding(.bottom, 20)
            }.frame(maxHeight: 620)
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    var subtitle: String?
    var last = false
    @ViewBuilder var content: Content
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13.5)).foregroundStyle(Theme.paper)
                if let subtitle { Text(subtitle).font(.system(size: 11.5)).foregroundStyle(Theme.haze) }
            }
            Spacer(); content
        }
        .padding(.horizontal, 20).frame(minHeight: 50)
        .overlay(alignment: .bottom) { if !last { Hairline() } }
    }
}

/// Menu-backed select in the `sel2` style: mono value + chevrons.
struct SelectField<T: Hashable>: View {
    let value: T
    let label: String
    var mono = false
    let options: [(T, String)]
    let onSelect: (T) -> Void
    var body: some View {
        Menu {
            ForEach(Array(options.enumerated()), id: \.offset) { _, o in Button(o.1) { onSelect(o.0) } }
        } label: {
            HStack(spacing: 8) {
                Text(label).font(mono ? .calMono(12.5) : .system(size: 12.5)).foregroundStyle(Theme.paper)
                SFIcon(name: "chevron.up.chevron.down", size: 9, color: Theme.haze)
            }
            .padding(.horizontal, 10).frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.ink700))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.hair, lineWidth: 1))
            .contentShape(Rectangle())
        }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
    }
}

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        SheetFrame(title: "Settings", width: 580) {
            VStack(spacing: 0) {
                SettingsRow(title: "Appearance") {
                    Segmented(options: AppearanceSetting.allCases.map { ($0, $0.rawValue) }, selection: model.settings.appearance, height: 28) { model.settings.appearance = $0 }
                }
                SettingsRow(title: "Week starts on") {
                    Segmented(options: [(true, "Monday"), (false, "Sunday")], selection: model.settings.weekStartsOnMonday, height: 28) { model.settings.weekStartsOnMonday = $0 }
                }
                SettingsRow(title: "Time format") {
                    Segmented(options: [(true, "24-hour"), (false, "12-hour")], selection: model.settings.use24h, height: 28) { model.settings.use24h = $0 }
                }
                SettingsRow(title: "Default event duration") {
                    SelectField(value: model.settings.defaultDurationMinutes, label: "\(model.settings.defaultDurationMinutes) min", mono: true,
                                options: [15, 30, 45, 60, 90, 120].map { ($0, "\($0) min") }) { model.settings.defaultDurationMinutes = $0 }
                }
                SettingsRow(title: "First visible hour") {
                    SelectField(value: model.settings.firstVisibleHour, label: String(format: "%02d:00", model.settings.firstVisibleHour), mono: true,
                                options: (0..<13).map { ($0, String(format: "%02d:00", $0)) }) { model.settings.firstVisibleHour = $0 }
                }
                SettingsRow(title: "Show declined events") {
                    Toggle("", isOn: Binding(get: { model.settings.showDeclined }, set: { model.settings.showDeclined = $0 })).toggleStyle(ActToggleStyle()).labelsHidden()
                }
                SettingsRow(title: "Reduce motion", subtitle: "Follows System Settings, Accessibility, Display") {
                    Toggle("", isOn: Binding(get: { model.settings.reduceMotion }, set: { model.settings.reduceMotion = $0 })).toggleStyle(ActToggleStyle()).labelsHidden()
                }
                SettingsRow(title: "Default calendar", last: true) {
                    let cals = model.store.allCalendars.filter(\.isWritable)
                    let cur = model.settings.defaultCalendarID ?? model.store.defaultCalendarID ?? ""
                    SelectField(value: cur, label: cals.first { $0.id == cur }?.title ?? "Calendar", options: cals.map { ($0.id, $0.title) }) { model.settings.defaultCalendarID = $0 }
                }
            }
        }
    }
}

struct DeleteRecurringDialog: View {
    @Environment(AppModel.self) private var model
    let eventID: String
    var body: some View {
        SheetFrame(title: "Delete recurring event", width: 400, closable: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("This event repeats. Which events should be deleted?").font(.system(size: 13)).foregroundStyle(Theme.haze).padding(.horizontal, 20).padding(.top, 16)
                HStack(spacing: 8) {
                    Spacer()
                    DialogButton(title: "Cancel") { model.closeOverlay() }
                    DialogButton(title: "This event") { if let e = model.event(id: eventID) { model.delete(e, span: .this) } }
                    DialogButton(title: "All events", primary: true) { if let e = model.event(id: eventID) { model.delete(e, span: .all) } }
                }.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)
            }
        }
    }
}

struct DialogButton: View {
    let title: String
    var primary = false
    let action: () -> Void
    var body: some View {
        if primary { PrimaryButton(title: title, action: action) } else { SecondaryButton(title: title, action: action) }
    }
}
