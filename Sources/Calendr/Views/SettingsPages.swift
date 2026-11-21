import SwiftUI
import CalendrKit

// Settings (design/mockup-v11 `settingsHTML`, app.css `.modal.sheet`): a 900 x 620 dialog on `pop`. On the left a 200 pt `rail` nav
// with the pages; on the right the page: its title, one line of lede in fg2, then groups (`.sbox`: fg1 3.5 % over the dialog,
// radius 12) of rows (`.srow`: at least 44 high, padding 8 x 16, a hairline between rows).

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    static let size = CGSize(width: 900, height: 620)

    var body: some View {
        let page = model.services.settingsPage
        GeometryReader { geo in
            let w = min(Self.size.width, geo.size.width - 48), h = min(Self.size.height, geo.size.height - 48)
            HStack(spacing: 0) {
                SettingsNav(page: page)
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(page.title).font(.title15).tracking(TypeTrack.title).foregroundStyle(Theme.fg)
                            .frame(height: 28)
                        content(page)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 32)
                }
                .scrollIndicators(.automatic)
            }
            .frame(width: w, height: h)
            .overlay(alignment: .topTrailing) {
                IconButton(name: "xmark", help: "Close") { model.closeOverlay() }.padding(12)
            }
            .surface()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private func content(_ page: SettingsPage) -> some View {
        switch page {
        case .general: SettingsGeneralPage()
        case .appearance: SettingsAppearancePage()
        case .calendars: SettingsCalendarsPage()
        case .accounts: SettingsAccountsPage()
        case .contacts: SettingsContactsPage()
        case .menuBar: SettingsMenuBarPage()
        case .shortcuts: SettingsShortcutsPage()
        }
    }
}

/// `.sheet nav`: 200 pt on `rail` with a hair edge, padding 16 x 12, "Settings" then 28 pt rows 2 apart. A row: 15 pt icon in fg3
/// and its name in fg2; hover `hoverRail` and fg1; the open page `selected`, fg1 500, icon fg2.
struct SettingsNav: View {
    @Environment(AppModel.self) private var model
    let page: SettingsPage
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Settings").font(.title15).tracking(TypeTrack.title).foregroundStyle(Theme.fg)
                .padding(.horizontal, 8).padding(.top, 4).padding(.bottom, 16)
            ForEach(SettingsPage.allCases, id: \.self) { p in
                SettingsNavRow(page: p, on: p == page) { model.services.settingsPage = p }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 16)
        .frame(width: 200, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.rail)
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.hair).frame(width: 1) }
        .tourAnchor("settings:pages")
    }
}

private struct SettingsNavRow: View {
    let page: SettingsPage
    let on: Bool
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        let iconColor = on ? Theme.fg2 : Theme.fg3
        Button(action: action) {
            HStack(spacing: 12) {
                icon(iconColor).frame(width: 15, height: 15)
                Text(page.title).font(on ? .textMedium : .text).foregroundStyle(on || hover ? Theme.fg : Theme.fg2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).frame(height: Dim.row)
            .background(RoundedRectangle(cornerRadius: Radius.row).fill(on ? Theme.selected : hover ? Theme.hoverRail : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
        .tourAnchor("settings:nav:\(page.rawValue)")
    }

    @ViewBuilder private func icon(_ c: Color) -> some View {
        switch page {
        case .general: ChromeIcon(name: .gear, size: 15, color: c)
        case .appearance: ChromeIcon(name: .moon, size: 15, color: c)
        case .calendars: ChromeIcon(name: .cal, size: 15, color: c)
        case .accounts: PanelIcon(name: .link, size: 15, color: c)
        case .contacts: PanelIcon(name: .contacts, size: 15, color: c)
        case .menuBar: ChromeIcon(name: .clock, size: 15, color: c)
        case .shortcuts: ChromeIcon(name: .keys, size: 15, color: c)
        }
    }
}

// MARK: Building blocks

/// `.lede2`: one line under the page title, fg2, 24 above the first group.
struct SettingsLede: View {
    let text: String
    var body: some View {
        Text(text).font(.text).foregroundStyle(Theme.fg2).lineSpacing(1).fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4).padding(.bottom, 24)
    }
}

/// `.sbox`: a group of rows, fg1 3.5 % over the dialog, radius 12, 16 under it.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Theme.groupBox))
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .padding(.bottom, 16)
    }
}

/// `.srow`: at least 44 high, padding 8 x 16, 12 between parts; title (500 when `strong`) with an explanatory `small` line in fg3,
/// the control on the right; a hairline above every row but the first of its group. `lead` is a 12 pt calendar square or a 28 pt
/// icon tile (`.pv`).
struct SettingsRow<Lead: View, Content: View>: View {
    let title: String
    var detail: String?
    var strong = false
    var first = false
    @ViewBuilder var lead: Lead
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 12) {
            lead
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(strong ? .textMedium : .text).foregroundStyle(Theme.fg).fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail).font(.small).foregroundStyle(Theme.fg3).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            content.fixedSize()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .frame(minHeight: 44)
        .overlay(alignment: .top) { if !first { Rectangle().fill(Theme.hair).frame(height: 1) } }
    }
}

extension SettingsRow where Lead == EmptyView {
    init(title: String, detail: String? = nil, strong: Bool = false, first: Bool = false, @ViewBuilder content: () -> Content) {
        self.init(title: title, detail: detail, strong: strong, first: first, lead: { EmptyView() }, content: content)
    }
}

/// `.pv`: a 28 pt tile on `surface`, radius 8, with a 15 pt icon in fg2.
struct SettingsTile<Icon: View>: View {
    @ViewBuilder var icon: Icon
    var body: some View {
        icon.frame(width: 15, height: 15).frame(width: 28, height: 28)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Theme.bg1))
    }
}

/// A small `fg2` status at the end of a row.
private struct SettingsStatus: View {
    let text: String
    var body: some View { Text(text).font(.small).foregroundStyle(Theme.fg2) }
}

// MARK: Pages

struct SettingsGeneralPage: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let s = model.settings
        SettingsLede(text: "How the calendar grid looks and behaves.")
        SettingsGroup {
            SettingsRow(title: "Show week numbers", detail: "A column in the mini month. Click a number to open that week.", first: true) {
                PanelSwitch(label: "", isOn: s.showWeekNumbers) { model.settings.showWeekNumbers.toggle() }
            }
            SettingsRow(title: "Show declined events", detail: "Declined invitations stay in the grid, faded and struck through.") {
                PanelSwitch(label: "", isOn: s.showDeclined) { model.settings.showDeclined.toggle() }
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
        }
    }
}

struct SettingsAppearancePage: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        SettingsLede(text: "Calendr has two themes: Dark and Paper (light).")
        SettingsGroup {
            SettingsRow(title: "Theme", first: true) {
                Segmented(options: [(false, "Dark"), (true, "Paper")], selection: model.isPaper) { model.settings.appearance = $0 ? .light : .dark }
            }
            SettingsRow(title: "Reduce motion", detail: "Views change at once instead of sliding and fading. macOS's own setting also turns this on.") {
                PanelSwitch(label: "", isOn: model.settings.reduceMotion) { model.settings.reduceMotion.toggle() }
            }
        }
    }
}

/// Every account with its calendars, shown or hidden.
struct SettingsCalendarsPage: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let _ = model.storeVersion
        let googleAccounts = model.services.google.accounts
        SettingsLede(text: "Hidden calendars stay hidden in search and the menu bar too.")
        ForEach(model.settingsAccounts, id: \.id) { a in
            let google = googleAccounts.contains { $0.accountID == a.id }
            SettingsGroup {
                SettingsRow(title: AccountName.display(a.name), detail: google ? "Google \u{00B7} \(a.name)" : "macOS Calendar \u{00B7} \(a.name)", strong: true, first: true) {
                    EmptyView()
                }
                ForEach(a.calendars, id: \.id) { cal in SettingsCalendarRow(cal: cal) }
            }
        }
        if !model.hiddenDuplicateAccounts.isEmpty {
            Text("Hidden from macOS Calendar because Google syncs them directly: \(model.hiddenDuplicateAccounts.joined(separator: ", ")).")
                .font(.small).foregroundStyle(Theme.fg3).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One calendar: its colour (the same square as the sidebar), its name and a switch.
struct SettingsCalendarRow: View {
    @Environment(AppModel.self) private var model
    let cal: CalendarInfo
    var body: some View {
        let shown = !model.hiddenCalendars.contains(cal.id)
        SettingsRow(title: cal.title, detail: cal.isWritable ? nil : "Read only") {
            RoundedRectangle(cornerRadius: Radius.swatch).fill(Theme.calendarMark(cal.colorHex)).frame(width: 12, height: 12)
        } content: {
            PanelSwitch(label: "", isOn: shown) { model.toggleCalendar(cal.id) }
                .help(shown ? "Hide \(cal.title)" : "Show \(cal.title)")
        }
        .tourAnchor("settings:cal:\(cal.id)")
    }
}

/// Google accounts connect through the Google Calendar API (replies, guests, Meet links, updates to guests); everything else comes
/// through macOS Calendar. Without a Google client ID the connect button explains what is missing and does nothing.
struct SettingsAccountsPage: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let g = model.services.google
        let _ = model.storeVersion
        SettingsLede(text: "macOS Calendar stays the source: iCloud, Google (CalDAV) and subscriptions show through it. Connecting Google directly adds replies, guests, Meet links and updates to guests.")
        SettingsGroup {
            ForEach(Array(g.accounts.enumerated()), id: \.element.email) { i, google in
                SettingsRow(title: google.email, detail: google.statusLine, strong: true, first: i == 0) {
                    SettingsTile { PanelIcon(name: .google, size: 15, color: Theme.fg2) }
                } content: {
                    HStack(spacing: 6) {
                        if google.needsReconnect { PrimaryButton(title: "Connect again", small: true) { model.services.google.reconnect(google.email) } }
                        SecondaryButton(title: "Remove", small: true) { model.disconnectGoogle(google.email) }
                    }
                }
                .tourAnchor("settings:google:\(google.email)")
            }
            SettingsRow(title: g.accounts.isEmpty ? "Google" : "Another Google account",
                        detail: g.accounts.isEmpty ? "Not connected \u{00B7} your Google calendars still show through macOS Calendar" : nil,
                        strong: true, first: g.accounts.isEmpty) {
                SettingsTile { PanelIcon(name: .google, size: 15, color: Theme.fg2) }
            } content: {
                PrimaryButton(title: "Connect Google account", small: true) { model.connectGoogle() }
                    .tourAnchor("settings:connectGoogle")
            }
            SettingsRow(title: "macOS Calendar", detail: "iCloud, Google (CalDAV), subscriptions, birthdays", strong: true) {
                SettingsTile { ChromeIcon(name: .cal, size: 15, color: Theme.fg2) }
            } content: {
                PanelIcon(name: .check, size: 15, color: Theme.replyYes)
            }
        }
        if g.config.clientID == nil && g.showsClientIDNote {
            SettingsGroup {
                SettingsRow(title: GoogleConfig.missingClientIDText, first: true) {
                    SettingsTile { PanelIcon(name: .google, size: 15, color: Theme.fg2) }
                } content: { EmptyView() }
                // demo runs only (`--demo`, tours): a Google account answered by an in-memory fake server, no network
                if model.canUseDemoGoogle && g.accounts.isEmpty {
                    SettingsRow(title: "Demo mode", detail: "Try a fake Google account (no network).") {
                        SecondaryButton(title: "Use demo account", small: true) { model.connectDemoGoogle() }
                            .tourAnchor("settings:demoGoogle")
                    }
                }
            }
            .tourAnchor("settings:clientIDNote")
        }
    }
}

/// Where "Add participant" finds people and where names for bare addresses come from: Apple Contacts first (macOS asks once), then
/// each Google account's contacts, then the people of recent events.
struct SettingsContactsPage: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let c = model.services.contacts
        SettingsLede(text: "Where \u{201C}Add participant\u{201D} finds people, and where names for bare addresses come from: Apple Contacts first, then Google contacts.")
        SettingsGroup {
            SettingsRow(title: "macOS Contacts", detail: Self.contactsDetail(c.access), strong: true, first: true) {
                SettingsTile { PanelIcon(name: .contacts, size: 15, color: Theme.fg2) }
            } content: {
                switch c.access {
                case .allowed: SettingsStatus(text: "Allowed")
                case .notDetermined: PrimaryButton(title: "Allow access\u{2026}", small: true) { model.allowContacts() }
                case .denied: SecondaryButton(title: "Open System Settings", small: true) { model.allowContacts() }
                }
            }
            .tourAnchor("settings:contacts")
            ForEach(model.services.google.accounts, id: \.email) { a in
                SettingsRow(title: "Google contacts \u{00B7} \(a.email)", detail: "Contacts and \u{201C}other contacts\u{201D} (people you emailed). Read only.", strong: true) {
                    SettingsTile { PanelIcon(name: .google, size: 15, color: Theme.fg2) }
                } content: {
                    SettingsStatus(text: a.peopleCount > 0 ? "\(a.peopleCount) people" : "Connected")
                }
            }
            if model.services.google.accounts.isEmpty {
                SettingsRow(title: "Google contacts", detail: "Connect a Google account under Accounts to find the people you email.", strong: true) {
                    SettingsTile { PanelIcon(name: .google, size: 15, color: Theme.fg2) }
                } content: {
                    SecondaryButton(title: "Accounts", small: true) { model.services.settingsPage = .accounts }
                }
            }
            SettingsRow(title: "Recent guests", detail: "People from your recent events.", strong: true) {
                SettingsTile { PanelIcon(name: .history, size: 15, color: Theme.fg2) }
            } content: {
                SettingsStatus(text: "On")
            }
        }
    }

    static func contactsDetail(_ a: ContactsAccess) -> String {
        switch a {
        case .allowed: "Allowed. Names and addresses for guests."
        case .notDetermined: "Not allowed yet. macOS asks once."
        case .denied: "Not allowed. Only System Settings can change this now."
        }
    }
}

struct SettingsMenuBarPage: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        SettingsLede(text: "The calendar in the menu bar.")
        SettingsGroup {
            SettingsRow(title: "Show in the menu bar", detail: "What sits next to the clock while an event is coming up.", first: true) {
                Segmented(options: [(MenuBarDisplay.titleAndCountdown, "Title and countdown"), (.countdown, "Countdown"), (.icon, "Icon only")],
                          selection: model.settings.menuBarDisplay) { model.settings.menuBarDisplay = $0 }
            }
        }
    }
}

struct SettingsShortcutsPage: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        SettingsLede(text: "Every shortcut, also under ? in the app. Single keys work whenever the caret is not in a field.")
        ForEach(ShortcutsSheet.groups(meetWith: model.store.canOverlayTeammates), id: \.0) { g in
            SettingsGroup {
                SettingsRow(title: g.0, strong: true, first: true) { EmptyView() }
                ForEach(g.1, id: \.1) { k, t in
                    SettingsRow(title: t) {
                        HStack(spacing: 11) {
                            ForEach(Array(k.split(separator: " ").enumerated()), id: \.offset) { Keycap(text: String($0.element)) }
                        }
                    }
                }
            }
        }
    }
}
