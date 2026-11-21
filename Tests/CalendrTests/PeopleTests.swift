import Testing
import Foundation
import CalendrKit
@testable import Calendr

/// v4 Phase 8c: the People API read through a fake HTTP client, names for bare addresses and guest suggestions. No network.
@MainActor
@Suite("Google people")
struct PeopleTests {
    nonisolated static func fixture(_ name: String) -> Data {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("CalendrKitTests/Fixtures/google/\(name).json")
        return (try? Data(contentsOf: url)) ?? Data()
    }

    @Test func pagesAndMergesConnectionsAndOtherContacts() async throws {
        let http = FakeHTTPClient { s in
            if s.path.hasSuffix("/people/me/connections") { return (Self.fixture(s.query["pageToken"] == "conn-2" ? "people-connections-2" : "people-connections"), 200) }
            if s.path.hasSuffix("/otherContacts") { return (Self.fixture("other-contacts"), 200) }
            return (Data(), 404)
        }
        let api = GooglePeopleAPI(http: http, token: { "t" })
        let p = try await api.people()
        #expect(p.map(\.email).contains("kim.lindqvist@example.org") && p.map(\.email).contains("pia.neumann@example.net"))
        #expect(p.first { $0.email == "dion.k@example.com" }?.name == "Dion Kraft")
        let conn = http.sent.filter { $0.path.hasSuffix("/connections") }
        #expect(conn.count == 2 && conn[0].query["personFields"] == "names,emailAddresses" && conn[1].query["pageToken"] == "conn-2")
        #expect(http.sent.first { $0.path.hasSuffix("/otherContacts") }?.query["readMask"] == "names,emailAddresses")
        #expect(http.sent.allSatisfy { $0.url.host == "people.googleapis.com" && $0.method == "GET" })
    }

    @Test func otherContactsRefusedKeepsTheContacts() async throws {
        let http = FakeHTTPClient { s in s.path.hasSuffix("/otherContacts") ? (Data(), 403) : (Self.fixture("people-connections-2"), 200) }
        let p = try await GooglePeopleAPI(http: http, token: { "t" }).people()
        #expect(p.map(\.name) == ["Kim Lindqvist"])
    }

    func model() -> AppModel {
        let o = LaunchOptions.parse(["Calendr", "--fixture", "v4", "--freeze-clock"])
        return AppModel(store: CompositeStore(base: DemoStore()), options: o, persist: false)
    }

    @Test func googleNamesFillBareAddressesAfterAppleContacts() {
        let m = model()
        let wg = m.event(id: "v4.wg")!
        #expect(EditorRows.withoutName(m.displayed(wg.attendees)) == 2)
        m.connectDemoGoogle()
        #expect(m.services.googlePeople.contains { $0.email == "pia.neumann@example.net" })
        let flat = m.store.searchCorpus(around: m.now).first { $0.title == "Flat dinner" }!
        // Google knows Dion; Sam's iCloud address is only in Apple Contacts
        var shown = m.displayed(flat.attendees)
        #expect(shown.first { $0.email == "dion.k@example.com" }?.name == "Dion Kraft" && EditorRows.withoutName(shown) == 1)
        m.allowContacts()
        shown = m.displayed(flat.attendees)
        #expect(EditorRows.withoutName(shown) == 0 && shown.first { $0.email == "sam@example.net" }?.name == "Sam Rivera")
        #expect(m.services.google.accounts.first?.peopleCount == m.services.googlePeople.count)
    }

    @Test func guestSuggestionsComeFromGoogleToo() {
        let m = model()
        m.connectDemoGoogle()
        let flat = m.store.searchCorpus(around: m.now).first { $0.title == "Flat dinner" }!
        m.select(eventID: flat.id)
        let s = m.guestSuggestions("Pia")
        #expect(s.first?.name == "Pia Neumann" && m.peopleSource(s[0]) == .google)
        // nameless "other contacts" are not suggested; people already on the list are not either
        #expect(m.guestSuggestions("newsletter").isEmpty && !m.guestSuggestions("Mara").contains { $0.email == "mara.hoffmann@example.com" })
        m.disconnectGoogle(DemoGoogleServer.email)
        #expect(m.services.googlePeople.isEmpty && m.guestSuggestions("Pia").isEmpty)
    }
}
