import Testing
import Foundation
import CalendrKit

/// v4 Phase 8c: Google contacts (People API) to people, merged by address.
@Suite("People mapping")
struct PeopleMappingTests {
    @Test func connectionsMapEveryAddressOfANamedPerson() throws {
        let page = try googleFixture("people-connections", as: GConnectionsPage.self)
        #expect(page.nextPageToken == "conn-2")
        let p = PeopleMapping.people(page.connections ?? [])
        // Dion has two addresses; "No Address" has none and is left out
        #expect(p.map(\.email) == ["dion.k@example.com", "dion@club.example", "Ida.Sommer@example.org"])
        #expect(p.allSatisfy { !$0.name.isEmpty })
    }

    @Test func otherContactsWithoutANameAreLeftOut() throws {
        let o = PeopleMapping.people(try googleFixture("other-contacts", as: GOtherContactsPage.self).otherContacts ?? [])
        #expect(o.map(\.name) == ["Dion K.", "Pia Neumann"])
    }

    @Test func mergeKeepsTheFirstNameForAnAddress() throws {
        let c = PeopleMapping.people(try googleFixture("people-connections", as: GConnectionsPage.self).connections ?? [])
            + PeopleMapping.people(try googleFixture("people-connections-2", as: GConnectionsPage.self).connections ?? [])
        let o = PeopleMapping.people(try googleFixture("other-contacts", as: GOtherContactsPage.self).otherContacts ?? [])
        let m = PeopleMapping.merge([c, o])
        // contacts win over "other contacts"; sorted by name; one entry per address, any case
        #expect(m.first { $0.email == "dion.k@example.com" }?.name == "Dion Kraft")
        #expect(m.map(\.name) == ["Dion Kraft", "Dion Kraft", "Ida Sommer", "Kim Lindqvist", "Pia Neumann"])
        let again = PeopleMapping.merge([m, [Teammate(name: "Ida S.", email: "ida.sommer@EXAMPLE.org")]])
        #expect(again.count == m.count)
        let names = PeopleMapping.names(m)
        #expect(names["ida.sommer@example.org"] == "Ida Sommer")
        // as a NameResolver source: Apple Contacts first, then these
        let r = NameResolver([TableNameSource(["ida.sommer@example.org": "Ida (Contacts)"]), TableNameSource(names)])
        #expect(r.name(forEmail: "Ida.Sommer@example.org") == "Ida (Contacts)" && r.name(forEmail: "pia.neumann@example.net") == "Pia Neumann")
    }
}
