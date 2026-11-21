import Testing
import CalendrKit

/// v4 Phase 8a: names for bare addresses come from Apple Contacts, then Google contacts, then the address stays bare.
@Suite("Name resolver")
struct NameResolverTests {
    /// A source that may be switched off (Contacts access denied) and counts its lookups.
    final class Source: NameSource {
        var table: [String: String]
        var allowed = true
        var asked = 0
        init(_ t: [String: String]) { table = t }
        func name(forEmail email: String) -> String? { asked += 1; return allowed ? table[email.lowercased()] : nil }
    }

    @Test func chainOrderAppleThenGoogleThenBare() {
        let apple = Source(["dion.k@example.com": "Dion Kraft (Contacts)"])
        let google = Source(["dion.k@example.com": "Dion K", "ida.sommer@example.org": "Ida Sommer"])
        let r = NameResolver([apple, google])
        #expect(r.name(forEmail: "dion.k@example.com") == "Dion Kraft (Contacts)")
        #expect(r.name(forEmail: "Ida.Sommer@example.org") == "Ida Sommer")
        #expect(r.name(forEmail: "nobody@example.com") == nil)
        #expect(r.label(Attendee(email: "nobody@example.com")) == "nobody@example.com")
    }

    @Test func deniedContactsFallBackToGoogle() {
        let apple = Source(["dion.k@example.com": "Dion Kraft"])
        apple.allowed = false
        let google = Source(["dion.k@example.com": "Dion K"])
        let r = NameResolver([apple, google])
        #expect(r.name(forEmail: "dion.k@example.com") == "Dion K")
        google.allowed = false
        #expect(r.name(forEmail: "dion.k@example.com") == nil)
    }

    @Test func ownNameWinsAndBlankNamesAreSkipped() {
        let apple = Source(["mara.hoffmann@example.com": "Mara H.", "x@example.com": "  "])
        let google = Source(["x@example.com": "Xavier"])
        let r = NameResolver([apple, google])
        let mara = Attendee(email: "mara.hoffmann@example.com", name: "Mara Hoffmann")
        #expect(r.resolve(mara).name == "Mara Hoffmann")
        #expect(apple.asked == 0)
        #expect(r.resolve(Attendee(email: "x@example.com")).name == "Xavier")
        // a guest known only by a name is never looked up
        #expect(r.resolve(Attendee(email: "", name: "Kim")).label == "Kim")
    }

    @Test func resolvingKeepsEverythingButTheName() {
        let r = NameResolver([TableNameSource(["dion.k@example.com": "Dion Kraft"])])
        let a = Attendee(email: "dion.k@example.com", isOptional: true, status: .declined)
        let b = r.resolve(a)
        #expect(b.name == "Dion Kraft" && b.email == a.email && b.isOptional && b.status == .declined)
        #expect(EditorRows.withoutName([a]) == 1 && EditorRows.withoutName(r.resolve([a])) == 0)
    }
}
