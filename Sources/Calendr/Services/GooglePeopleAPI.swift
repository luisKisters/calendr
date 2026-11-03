import Foundation
import CalendrKit

/// Google People API v1, read only (v4 Phase 8c): the account's contacts (`people/me/connections`, scope `contacts.readonly`) and
/// "other contacts", the people it emailed (`otherContacts`, scope `contacts.other.readonly`). Names for bare addresses and guest
/// suggestions; nothing is written.
struct GooglePeopleAPI: Sendable {
    static let base = URL(string: "https://people.googleapis.com/v1")!
    let http: HTTPClient
    let token: @Sendable () async throws -> String

    static func request(_ path: String, query: [(String, String)], token: String) -> URLRequest {
        var c = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        c.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        var r = URLRequest(url: c.url!)
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return r
    }

    private func get<T: Decodable>(_ path: String, _ query: [(String, String)]) async throws -> T {
        let (d, status) = try await http.send(Self.request(path, query: query, token: try await token()))
        guard (200..<300).contains(status) else { throw GoogleCalendarAPI.APIError.status(status, String(decoding: d.prefix(200), as: UTF8.self)) }
        return try JSONDecoder().decode(T.self, from: d)
    }

    func connections() async throws -> [GPeoplePerson] {
        var out: [GPeoplePerson] = []
        var page: String?
        repeat {
            var q = [("personFields", "names,emailAddresses"), ("pageSize", "1000")]
            if let p = page { q.append(("pageToken", p)) }
            let r: GConnectionsPage = try await get("people/me/connections", q)
            out += r.connections ?? []
            page = r.nextPageToken
        } while page != nil && out.count < 20000
        return out
    }

    func otherContacts() async throws -> [GPeoplePerson] {
        var out: [GPeoplePerson] = []
        var page: String?
        repeat {
            var q = [("readMask", "names,emailAddresses"), ("pageSize", "1000")]
            if let p = page { q.append(("pageToken", p)) }
            let r: GOtherContactsPage = try await get("otherContacts", q)
            out += r.otherContacts ?? []
            page = r.nextPageToken
        } while page != nil && out.count < 20000
        return out
    }

    /// Contacts first, then other contacts, merged by address. "Other contacts" may be refused (the scope is optional): then contacts only.
    func people() async throws -> [Teammate] {
        let c = PeopleMapping.people(try await connections())
        let o = (try? await otherContacts()).map(PeopleMapping.people) ?? []
        return PeopleMapping.merge([c, o])
    }
}
