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

