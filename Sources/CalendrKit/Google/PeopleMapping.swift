import Foundation

// Google People API v1, read only (https://developers.google.com/people/api/rest): `people.connections.list` (the contacts) and
// `otherContacts.list` (people you emailed), each with names and email addresses.

public struct GPeopleName: Codable, Hashable, Sendable {
    public var displayName: String?
    public init(displayName: String? = nil) { self.displayName = displayName }
}

public struct GPeopleEmail: Codable, Hashable, Sendable {
    public var value: String?
    public init(value: String? = nil) { self.value = value }
}

public struct GPeoplePerson: Codable, Hashable, Sendable {
    public var resourceName: String?
    public var names: [GPeopleName]?
    public var emailAddresses: [GPeopleEmail]?
    public init(resourceName: String? = nil, names: [GPeopleName]? = nil, emailAddresses: [GPeopleEmail]? = nil) {
        self.resourceName = resourceName; self.names = names; self.emailAddresses = emailAddresses
    }
}

/// `people/me/connections` page.
public struct GConnectionsPage: Codable, Hashable, Sendable {
    public var connections: [GPeoplePerson]?
    public var nextPageToken: String?
    public init(connections: [GPeoplePerson]? = nil, nextPageToken: String? = nil) { self.connections = connections; self.nextPageToken = nextPageToken }
}

/// `otherContacts` page.
public struct GOtherContactsPage: Codable, Hashable, Sendable {
    public var otherContacts: [GPeoplePerson]?
    public var nextPageToken: String?
    public init(otherContacts: [GPeoplePerson]? = nil, nextPageToken: String? = nil) { self.otherContacts = otherContacts; self.nextPageToken = nextPageToken }
}

/// Google contacts as people the app can name and suggest (v4 Phase 8c).
public enum PeopleMapping {
    /// One entry per address of each person with a name; people without a name or an address are left out.
    public static func people(_ list: [GPeoplePerson]) -> [Teammate] {
        list.flatMap { p -> [Teammate] in
            guard let n = p.names?.lazy.compactMap({ $0.displayName?.trimmingCharacters(in: .whitespaces) }).first(where: { !$0.isEmpty }) else { return [] }
            return (p.emailAddresses ?? []).compactMap { $0.value?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.map { Teammate(name: n, email: $0) }
        }
    }

    /// Lists merged by address (any case): earlier lists win (contacts before "other contacts", the first account before the next),
    /// then sorted by name.
    public static func merge(_ lists: [[Teammate]]) -> [Teammate] {
        var seen = Set<String>()
        var out: [Teammate] = []
        for l in lists { for t in l where seen.insert(t.email.lowercased()).inserted { out.append(t) } }
        return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Address to name, for the `NameResolver` chain.
    public static func names(_ people: [Teammate]) -> [String: String] {
        Dictionary(people.map { ($0.email.lowercased(), $0.name) }, uniquingKeysWith: { a, _ in a })
    }
}
