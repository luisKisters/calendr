import Testing
import Foundation
import CalendrKit
@testable import Calendr

/// v4 Phase 8a: Allow Contacts, names for bare addresses in the editor, guest suggestions from Contacts. Fakes only: no `CNContactStore`.
@MainActor
@Suite("Contacts")
struct ContactsTests {
    func model(access: ContactsAccess = .notDetermined, grants: Bool = true) -> (AppModel, FakeContacts) {
        let o = LaunchOptions.parse(["Calendr", "--fixture", "v4", "--freeze-clock"])
        let fake = FakeContacts(["dion.k@example.com": "Dion Kraft", "sam@example.net": "Sam Rivera", "kim.lindqvist@example.org": "Kim Lindqvist"],
                                access: access, grants: grants)
        return (AppModel(store: DemoStore(), options: o, persist: false, services: Services(contacts: fake)), fake)
    }

    @Test func allowContactsFillsTheBareAddresses() {
        let (m, fake) = model()
        let e = m.event(id: "v4.wg")!
        // Flat dinner: Dion and Sam's iCloud address are bare
        #expect(EditorRows.withoutName(m.displayed(e.attendees)) == 2)
        #expect(fake.lookups == 0)
        m.allowContacts()
        #expect(m.services.contacts.access == .allowed && fake.requests == 1)
        let shown = m.displayed(e.attendees)
        #expect(EditorRows.withoutName(shown) == 0)
        #expect(shown.contains { $0.email == "dion.k@example.com" && $0.name == "Dion Kraft" })
        // display only: the stored guest list keeps the bare address
        #expect(m.event(id: "v4.wg")!.attendees.contains { $0.email == "dion.k@example.com" && $0.name == nil })
        #expect(m.toast?.text.hasPrefix("Contacts allowed") == true)
    }

    @Test func lookupsAreCached() {
        let (m, fake) = model(access: .allowed)
        let a = Attendee(email: "dion.k@example.com")
        for _ in 0..<5 { _ = m.displayed(a) }
        #expect(fake.lookups == 1)
    }

    @Test func deniedKeepsAddressesBareAndPointsToSystemSettings() {
        let (m, fake) = model(grants: false)
        m.allowContacts()
        #expect(m.services.contacts.access == .denied)
        #expect(EditorRows.withoutName(m.displayed(m.event(id: "v4.wg")!.attendees)) == 2)
        m.allowContacts()
        #expect(fake.requests == 1)     // macOS asks once
        #expect(m.toast?.text.contains("System Settings") == true)
    }

    @Test func guestSuggestionsAddContactsOnceAllowed() {
        let (m, _) = model()
        m.select(eventID: "v4.d4")
        #expect(!m.guestSuggestions("Kim").contains { $0.email == "kim.lindqvist@example.org" })
        m.allowContacts()
        let s = m.guestSuggestions("Kim")
        #expect(s.first?.email == "kim.lindqvist@example.org")
        #expect(m.peopleSource(s[0]) == .contacts)
        // the store's people stay first and are not repeated
        let all = m.peopleDirectory()
        #expect(Set(all.map { $0.email.lowercased() }).count == all.count)
    }
}
