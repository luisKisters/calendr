import Foundation
import Observation
import CalendrKit

/// The SERVICES area (v4 Phase 8): Apple Contacts, Google accounts and Google contacts. Stored on `AppModel.services`.
/// Demo, snapshot and test runs get fakes: nothing here touches Contacts, the Keychain or the network unless the real app asks for it.
@MainActor @Observable
final class Services {
    let contacts: ContactsResolver
    /// Google contacts (People API): address to name, filled when a Google account syncs its people (Phase 8c).
    @ObservationIgnored let googleNames = TableNameSource()
    /// Bumped when the Google names change.
    private(set) var googleNamesVersion = 0
    /// Google contacts as guest suggestions (Phase 8c).
    private(set) var googlePeople: [Teammate] = []

    /// Settings sheet page (General, Accounts, Contacts).
    var settingsPage: SettingsPage = .general

    init(contacts: ContactsBackend) {
        self.contacts = ContactsResolver(backend: contacts)
    }

    /// Apple Contacts, then Google contacts, then the bare address.
    var names: NameResolver { NameResolver([contacts, googleNames]) }

    /// A guest as the list shows it: the name filled from the chain. Reads the versions so views re-render when access or names change.
    func resolved(_ a: Attendee) -> Attendee {
        _ = contacts.version; _ = googleNamesVersion
        return names.resolve(a)
    }
    func resolved(_ list: [Attendee]) -> [Attendee] {
        _ = contacts.version; _ = googleNamesVersion
        let n = names
        return list.map(n.resolve)
    }

    /// Google contacts (People API): names for bare addresses and guest suggestions.
    func setGooglePeople(_ people: [Teammate]) {
        googlePeople = people
        googleNames.set(Dictionary(people.map { ($0.email, $0.name) }, uniquingKeysWith: { a, _ in a }))
        googleNamesVersion += 1
    }

    /// The services for a run: the real ones for the app, fakes for `--demo`, snapshots, tours and tests.
    static func make(_ o: LaunchOptions) -> Services {
        // Real Contacts only inside the app bundle (the usage description lives in its Info.plist): never in `swift test` or `swift run`.
        o.demo || !Bundle.main.bundlePath.hasSuffix(".app") ? demo(o.fixture) : Services(contacts: SystemContacts())
    }

    /// The demo Contacts book: the names the v4 fixture keeps only in Contacts (mockup `cname`), not allowed yet.
    static func demo(_ fixture: DemoFixture = .v4, access: ContactsAccess = .notDetermined) -> Services {
        var table: [String: String] = [:]
        if fixture == .v4 {
            for p in DemoDataV4.people where p.contactsOnly { table[p.email] = p.name }
            // a few more people only Contacts knows, for the guest field
            table["kim.lindqvist@example.org"] = "Kim Lindqvist"
        }
        return Services(contacts: FakeContacts(table, access: access))
    }
}

enum SettingsPage: String, CaseIterable { case general, contacts
    var title: String {
        switch self {
        case .general: "General"
        case .contacts: "Contacts"
        }
    }
}
