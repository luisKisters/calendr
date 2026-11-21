import Foundation
import Security

/// One-time move of a user's data from the app's former name (Calendr, bundle ID com.luiskisters.calendr) to Horion.
/// The bundle ID change gives the app a fresh defaults domain, so without this settings, the Google account list,
/// the Keychain refresh tokens and the Application Support cache would all be orphaned.
/// Calendar and Contacts permission (TCC) is keyed by bundle ID and cannot be carried over: macOS asks again.
enum LegacyMigration {
    static let oldBundleID = "com.luiskisters.calendr"
    static let oldKeychainService = "com.luiskisters.calendr.google"
    static let oldSupportFolder = "Calendr"
    static let doneKey = "horion.migratedFromCalendr"
    /// Defaults keys whose name carried the old prefix.
    static let renamedKeys = ["calendr.settings.v2": AppSettings.key]

    /// Runs once per user; later launches return straight away.
    static func run(defaults: UserDefaults = .standard,
                    oldDomain: [String: Any]? = UserDefaults.standard.persistentDomain(forName: oldBundleID),
                    supportDir: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
                    tokens: TokenStore = KeychainTokenStore(),
                    oldToken: (String) -> String? = readOldToken,
                    removeOldToken: (String) -> Void = deleteOldToken) {
        guard !defaults.bool(forKey: doneKey) else { return }
        defer { defaults.set(true, forKey: doneKey) }

        // 1. defaults: copy what the new domain does not have yet
        for (k, v) in oldDomain ?? [:] {
            let key = renamedKeys[k] ?? k
            if defaults.object(forKey: key) == nil { defaults.set(v, forKey: key) }
        }

        // 2. Keychain: re-save each account's refresh token under the new service (macOS may ask once to allow access)
        for email in tokens.emails() where tokens.refreshToken(for: email) == nil {
            guard let rt = oldToken(email), tokens.save(refreshToken: rt, for: email) else { continue }
            removeOldToken(email)
        }

        // 3. Application Support/Calendr → Application Support/Horion
        if let dir = supportDir {
            let old = dir.appendingPathComponent(oldSupportFolder), new = dir.appendingPathComponent("Horion")
            let fm = FileManager.default
            if fm.fileExists(atPath: old.path), !fm.fileExists(atPath: new.path) { try? fm.moveItem(at: old, to: new) }
        }
    }

    private static func oldQuery(_ email: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: oldKeychainService, kSecAttrAccount as String: email]
    }

    static func readOldToken(_ email: String) -> String? {
        var q = oldQuery(email)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func deleteOldToken(_ email: String) { SecItemDelete(oldQuery(email) as CFDictionary) }
}
