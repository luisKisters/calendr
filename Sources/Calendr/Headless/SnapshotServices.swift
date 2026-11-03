import AppKit
import CalendrKit

/// Snapshot states of the SERVICES area (v4 Phase 8) on the v4 fixture: Settings → Contacts and Settings → Accounts.
@MainActor
enum SnapshotServices {
    static let states = ["v4-contacts"]

    static func apply(_ state: String, _ m: AppModel) -> Bool {
        switch state {
        case "v4-contacts":
            m.services.settingsPage = .contacts
            m.overlay = .settings
            SnapshotV4.scroll(m, to: SnapshotV4.defaultScroll)
        default: return false
        }
        return true
    }
}
