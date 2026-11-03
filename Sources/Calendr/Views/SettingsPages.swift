import SwiftUI
import CalendrKit

/// Settings → Contacts (design/mockup-v4 `contacts` scene): where "Add participant" finds people and where names for bare addresses
/// come from. Apple Contacts first (macOS asks once), then each Google account's contacts, then the people of recent events.
struct SettingsContactsPage: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let c = model.services.contacts
        VStack(alignment: .leading, spacing: 0) {
            Text("Where \u{201C}Add participant\u{201D} finds people, and where names for bare addresses come from: Apple Contacts first, then Google contacts.")
                .font(.small).foregroundStyle(Theme.fg3).fixedSize(horizontal: false, vertical: true).padding(.top, 12)
            SheetLabel(text: "Contacts").padding(.top, 16).padding(.bottom, 2)
            SettingsRow(title: "macOS Contacts", detail: Self.contactsDetail(c.access), first: true, icon: .contacts) {
                switch c.access {
                case .allowed: Text("Allowed").font(.small).foregroundStyle(Theme.fg2)
                case .notDetermined: PrimaryButton(title: "Allow access\u{2026}", small: true) { model.allowContacts() }
                case .denied: SecondaryButton(title: "Open System Settings", small: true) { model.allowContacts() }
                }
            }
            .tourAnchor("settings:contacts")
            ForEach(model.services.google.accounts, id: \.email) { a in
                SettingsRow(title: "Google contacts \u{00B7} \(a.email)", detail: "Contacts and \u{201C}other contacts\u{201D} (people you emailed). Read only.", icon: .google) {
                    Text(a.peopleCount > 0 ? "\(a.peopleCount) people" : "Connected").font(.small).foregroundStyle(Theme.fg2)
                }
            }
            if model.services.google.accounts.isEmpty {
                SettingsRow(title: "Google contacts", detail: "Connect a Google account under Accounts to find the people you email.", icon: .google) {
                    SecondaryButton(title: "Accounts", small: true) { model.services.settingsPage = .accounts }
                }
            }
            SettingsRow(title: "Recent guests", detail: "People from your recent events.", icon: .history) {
                Text("On").font(.small).foregroundStyle(Theme.fg2)
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


/// Settings → Accounts (design/mockup-v4 `settings` scene, "Calendars & accounts"): every account with its calendars, shown or hidden.
/// Google accounts connect through the Google Calendar API (replies, guests, Meet links, updates to guests); everything else comes
/// through macOS Calendar. Without a Google client ID the connect button explains what is missing and does nothing.
struct SettingsAccountsPage: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let g = model.services.google
        // the store is not observable: its version (and the Google list) make this page follow connects, syncs and removals
        let _ = model.storeVersion
        let googleAccounts = g.accounts
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                Text("Add accounts, show or hide calendars. Google accounts connect directly; iCloud and others come through macOS Calendar.")
                    .font(.small).foregroundStyle(Theme.fg3).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                PrimaryButton(title: "Connect Google account", small: true) { model.connectGoogle() }
                    .tourAnchor("settings:connectGoogle")
            }
            .padding(.top, 12)
            if g.config.clientID == nil && g.showsClientIDNote {
                HStack(alignment: .top, spacing: 8) {
                    PanelIcon(name: .google, size: 14, color: Theme.fg2)
                    Text(GoogleConfig.missingClientIDText).font(.small).foregroundStyle(Theme.fg2).fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: Radius.row).fill(Theme.bg2))
                .padding(.top, 10)
                .tourAnchor("settings:clientIDNote")
            }
            ForEach(model.settingsAccounts, id: \.id) { a in
                let google = googleAccounts.first { $0.accountID == a.id }
                // not a SheetLabel: it would lower-case the address and "macOS"
                Text(google != nil ? "Google \u{00B7} \(a.name)" : "macOS Calendar \u{00B7} \(a.name)").font(.small).foregroundStyle(Theme.fg3)
                    .padding(.top, 16).padding(.bottom, 2)
                if let google {
                    SettingsRow(title: a.name, detail: google.statusLine, first: true, icon: .google) {
                        HStack(spacing: 6) {
                            if google.needsReconnect { PrimaryButton(title: "Connect again", small: true) { model.services.google.reconnect(google.email) } }
                            SecondaryButton(title: "Remove", small: true) { model.disconnectGoogle(google.email) }
                        }
                    }
                    .tourAnchor("settings:google:\(google.email)")
                }
                ForEach(Array(a.calendars.enumerated()), id: \.element.id) { i, cal in
                    SettingsCalendarRow(cal: cal, first: google == nil && i == 0)
                }
            }
            if !model.hiddenDuplicateAccounts.isEmpty {
                Text("Hidden from macOS Calendar because Google syncs them directly: \(model.hiddenDuplicateAccounts.joined(separator: ", ")).")
                    .font(.small).foregroundStyle(Theme.fg3).fixedSize(horizontal: false, vertical: true).padding(.top, 12)
            }
        }
        .tourAnchor("settings:accounts")
    }
}

/// One calendar: its colour, its name and Shown / Hidden.
struct SettingsCalendarRow: View {
    @Environment(AppModel.self) private var model
    let cal: CalendarInfo
    let first: Bool
    var body: some View {
        let shown = !model.hiddenCalendars.contains(cal.id)
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: Radius.check).fill(Color(hex: cal.colorHex)).frame(width: 12, height: 12)
            Text(cal.title).font(.text).foregroundStyle(Theme.fg)
            Spacer(minLength: 0)
            PanelSwitch(label: shown ? "Shown" : "Hidden", isOn: shown) { model.toggleCalendar(cal.id) }
        }
        .frame(height: 36)
        .overlay(alignment: .top) { if !first { Hairline() } }
        .tourAnchor("settings:cal:\(cal.id)")
    }
}
