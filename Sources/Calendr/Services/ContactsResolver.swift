import Foundation
import Contacts
import Observation
import CalendrKit

/// Whether Calendr may read Apple Contacts. macOS asks once; after a "Don't Allow" only System Settings can change it.
enum ContactsAccess: Equatable { case notDetermined, allowed, denied }

/// What the resolver needs from Apple Contacts. `SystemContacts` is the real one (`CNContactStore`); tests and the demo use `FakeContacts`.
protocol ContactsBackend: AnyObject {
    var access: ContactsAccess { get }
    /// Shows the system prompt (once). Returns whether access is allowed afterwards.
    func requestAccess() async -> Bool
    /// The answer without waiting, when the backend has one at hand (the fake): headless runs pump the run loop from inside a main-queue
    /// block, so a main-actor Task would never run there. Nil: ask with `requestAccess()`.
    func requestAccessNow() -> Bool?
    /// The display name of the first contact with this address, or nil.
    func name(forEmail email: String) -> String?
    /// Everyone in Contacts with an address, for the guest field's suggestions.
    func people() -> [Teammate]
}

/// Apple Contacts through `CNContactStore`. Only touched after the user asked for it (Allow Contacts); never in tests or headless runs.
final class SystemContacts: ContactsBackend {
    private let store = CNContactStore()
    private let keys: [CNKeyDescriptor] = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactEmailAddressesKey as CNKeyDescriptor,
                                           CNContactOrganizationNameKey as CNKeyDescriptor]

    var access: ContactsAccess {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited: .allowed
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func requestAccess() async -> Bool { (try? await store.requestAccess(for: .contacts)) ?? false }
    func requestAccessNow() -> Bool? { nil }

    func name(forEmail email: String) -> String? {
        guard access == .allowed,
              let c = try? store.unifiedContacts(matching: CNContact.predicateForContacts(matchingEmailAddress: email), keysToFetch: keys).first else { return nil }
        return Self.display(c)
    }

    func people() -> [Teammate] {
        guard access == .allowed else { return [] }
        var out: [Teammate] = []
        let req = CNContactFetchRequest(keysToFetch: keys)
        try? store.enumerateContacts(with: req) { c, stop in
            guard let n = Self.display(c) else { return }
            for e in c.emailAddresses { out.append(Teammate(name: n, email: e.value as String)) }
            if out.count >= 5000 { stop.pointee = true }
        }
        return out
    }

    static func display(_ c: CNContact) -> String? {
        let n = CNContactFormatter.string(from: c, style: .fullName) ?? ""
        let s = n.isEmpty ? c.organizationName : n
        return s.isEmpty ? nil : s
    }
}

/// A Contacts stand-in: a fixed table, and a prompt that answers `grants`.
final class FakeContacts: ContactsBackend {
    var access: ContactsAccess
    var grants: Bool
    let table: [String: String]
    private(set) var requests = 0
    private(set) var lookups = 0

    init(_ table: [String: String], access: ContactsAccess = .notDetermined, grants: Bool = true) {
        self.table = Dictionary(table.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { a, _ in a })
        self.access = access; self.grants = grants
    }

    func requestAccess() async -> Bool {
        requests += 1
        if access == .notDetermined { access = grants ? .allowed : .denied }
        return access == .allowed
    }

    func requestAccessNow() -> Bool? {
        requests += 1
        if access == .notDetermined { access = grants ? .allowed : .denied }
        return access == .allowed
    }

    func name(forEmail email: String) -> String? {
        guard access == .allowed else { return nil }
        lookups += 1
        return table[email.lowercased()]
    }

    func people() -> [Teammate] {
        access == .allowed ? table.map { Teammate(name: $0.value, email: $0.key) }.sorted { $0.name < $1.name } : []
    }
}

/// Address to name through Apple Contacts, with a cache (the guest list asks on every render). The first link of the `NameResolver` chain.
@MainActor @Observable
final class ContactsResolver: NameSource {
    @ObservationIgnored let backend: ContactsBackend
    private(set) var access: ContactsAccess
    /// Bumped when access changes, so views that show resolved names re-render.
    private(set) var version = 0
    @ObservationIgnored private var cache: [String: String?] = [:]
    @ObservationIgnored private var peopleCache: [Teammate]?

    init(backend: ContactsBackend) {
        self.backend = backend
        access = backend.access
    }

    var isAllowed: Bool { access == .allowed }

    /// The system prompt (once). Returns whether access is allowed.
    @discardableResult
    func requestAccess() async -> Bool {
        let ok = await backend.requestAccess()
        setAccess(backend.access)
        return ok
    }

    /// Asks for access and calls back on the main actor: at once for the fake, after the system prompt for the real one.
    func requestAccess(then done: @escaping @MainActor (Bool) -> Void) {
        if let now = backend.requestAccessNow() { setAccess(backend.access); done(now); return }
        Task { @MainActor in done(await requestAccess()) }
    }

    /// Re-reads the status (the user may have changed it in System Settings).
    func refreshAccess() { setAccess(backend.access) }

    private func setAccess(_ a: ContactsAccess) {
        guard a != access else { return }
        access = a
        cache.removeAll(); peopleCache = nil
        version += 1
    }

    nonisolated func name(forEmail email: String) -> String? {
        MainActor.assumeIsolated { lookup(email) }
    }

    private func lookup(_ email: String) -> String? {
        guard access == .allowed else { return nil }
        let key = email.lowercased()
        if let hit = cache[key] { return hit }
        let n = backend.name(forEmail: email)
        cache[key] = .some(n)
        return n
    }

    /// Everyone in Contacts with an address (read once, after access).
    func people() -> [Teammate] {
        guard access == .allowed else { return [] }
        if let p = peopleCache { return p }
        let p = backend.people()
        peopleCache = p
        return p
    }
}
