import Foundation

/// Somewhere a guest's name can come from: Apple Contacts, Google contacts, a test table.
public protocol NameSource: AnyObject {
    /// Nil when this source does not know the address (or may not look, e.g. Contacts access was denied).
    func name(forEmail email: String) -> String?
}

/// A name source backed by a table (lower-cased addresses). Used for the Google people list and in tests.
public final class TableNameSource: NameSource {
    public private(set) var names: [String: String]
    public init(_ names: [String: String] = [:]) { self.names = Dictionary(names.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { a, _ in a }) }
    public func set(_ names: [String: String]) { self.names = Dictionary(names.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { a, _ in a }) }
    public func name(forEmail email: String) -> String? { names[email.lowercased()] }
}

/// Names for bare addresses (DECISIONS "Names for bare addresses": Apple Contacts, then Google contacts, then the bare address).
/// A name the event already carries always wins; the chain only fills the gaps, and only for display: the stored guest list is not changed.
public struct NameResolver {
    public var sources: [NameSource]
    public init(_ sources: [NameSource]) { self.sources = sources }

    /// The first non-blank name a source knows for the address, in chain order. Nil: the list shows the bare address.
    public func name(forEmail email: String) -> String? {
        let mail = email.trimmingCharacters(in: .whitespaces)
        guard !mail.isEmpty else { return nil }
        for s in sources {
            if let n = s.name(forEmail: mail)?.trimmingCharacters(in: .whitespaces), !n.isEmpty { return n }
        }
        return nil
    }

    /// The guest with a name filled in when it had none and a source knows one.
    public func resolve(_ a: Attendee) -> Attendee {
        guard (a.name ?? "").trimmingCharacters(in: .whitespaces).isEmpty, let n = name(forEmail: a.email) else { return a }
        var r = a
        r.name = n
        return r
    }

    public func resolve(_ list: [Attendee]) -> [Attendee] { list.map(resolve) }

    /// What the guest list shows for one guest: its own name, a resolved name, else the address.
    public func label(_ a: Attendee) -> String { resolve(a).label }
}
