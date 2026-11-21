import Testing
import Foundation
@testable import Horion

/// The rename from Calendr: settings, accounts, tokens and the disk cache move over once.
@Suite("Legacy migration")
struct LegacyMigrationTests {
    @Test func movesDataOnce() throws {
        let suite = "horion.test.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let oldCache = dir.appendingPathComponent("Calendr/google")
        try FileManager.default.createDirectory(at: oldCache, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: oldCache.appendingPathComponent("a@x.com.json"))

        let tokens = MemoryTokenStore()
        var removed: [String] = []
        let old: [String: Any] = ["calendr.settings.v2": Data("s".utf8), "other": 3]
        LegacyMigration.run(defaults: defaults, oldDomain: old, supportDir: dir, tokens: TokenListStub(tokens, ["a@x.com"]),
                            oldToken: { $0 == "a@x.com" ? "rt" : nil }, removeOldToken: { removed.append($0) })

        #expect(defaults.data(forKey: AppSettings.key) == Data("s".utf8))
        #expect(defaults.integer(forKey: "other") == 3)
        #expect(tokens.refreshToken(for: "a@x.com") == "rt")
        #expect(removed == ["a@x.com"])
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Horion/google/a@x.com.json").path))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("Calendr").path))

        // second launch: nothing is copied again
        LegacyMigration.run(defaults: defaults, oldDomain: ["other": 9], supportDir: dir, tokens: tokens, oldToken: { _ in nil }, removeOldToken: { _ in })
        #expect(defaults.integer(forKey: "other") == 3)
    }
}

/// Reports the migrated account list (in the app it comes from the copied defaults) and stores into a MemoryTokenStore.
private final class TokenListStub: TokenStore {
    let inner: MemoryTokenStore; let list: [String]
    init(_ inner: MemoryTokenStore, _ list: [String]) { self.inner = inner; self.list = list }
    func refreshToken(for email: String) -> String? { inner.refreshToken(for: email) }
    func save(refreshToken: String, for email: String) -> Bool { inner.save(refreshToken: refreshToken, for: email) }
    func remove(_ email: String) { inner.remove(email) }
    func emails() -> [String] { list }
}
