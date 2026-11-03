import Foundation
import AppKit
import AuthenticationServices
import Security
import CalendrKit

/// Where refresh tokens live: the Keychain, one item per Google account. Tests and demo runs use `MemoryTokenStore`.
protocol TokenStore: AnyObject {
    func refreshToken(for email: String) -> String?
    func save(refreshToken: String, for email: String)
    func remove(_ email: String)
    /// The connected accounts, in the order they were added.
    func emails() -> [String]
}

final class KeychainTokenStore: TokenStore {
    let service = "com.luiskisters.calendr.google"
    private let orderKey = "googleAccounts"

    func refreshToken(for email: String) -> String? {
        var out: AnyObject?
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: email,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    func save(refreshToken: String, for email: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: email]
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = Data(refreshToken.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        add[kSecAttrLabel as String] = "Calendr Google account \(email)"
        SecItemAdd(add as CFDictionary, nil)
        var order = emails().filter { $0 != email }
        order.append(email)
        UserDefaults.standard.set(order, forKey: orderKey)
    }

    func remove(_ email: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: email]
        SecItemDelete(q as CFDictionary)
        UserDefaults.standard.set(emails().filter { $0 != email }, forKey: orderKey)
    }

    func emails() -> [String] { UserDefaults.standard.stringArray(forKey: orderKey) ?? [] }
}

final class MemoryTokenStore: TokenStore {
    private var tokens: [(String, String)] = []
    func refreshToken(for email: String) -> String? { tokens.first { $0.0 == email }?.1 }
    func save(refreshToken: String, for email: String) { tokens.removeAll { $0.0 == email }; tokens.append((email, refreshToken)) }
    func remove(_ email: String) { tokens.removeAll { $0.0 == email } }
    func emails() -> [String] { tokens.map(\.0) }
}

/// Access tokens for one account: refreshed with the refresh token when the cached one is about to expire.
actor GoogleTokenProvider {
    let clientID: String
    let refreshToken: String
    let http: HTTPClient
    private var access: (token: String, expires: Date)?

    init(clientID: String, refreshToken: String, http: HTTPClient, initial: GoogleOAuth.TokenResponse? = nil) {
        self.clientID = clientID; self.refreshToken = refreshToken; self.http = http
        if let i = initial { access = (i.access_token, Date().addingTimeInterval(Double(i.expires_in ?? 3600) - 60)) }
    }

    func token() async throws -> String {
        if let a = access, a.expires > Date() { return a.token }
        var r = URLRequest(url: GoogleOAuth.tokenEndpoint)
        r.httpMethod = "POST"
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        r.httpBody = GoogleOAuth.refreshRequestBody(refreshToken: refreshToken, clientID: clientID)
        let (d, status) = try await http.send(r)
        guard status == 200, let t = try? JSONDecoder().decode(GoogleOAuth.TokenResponse.self, from: d) else { throw GoogleCalendarAPI.APIError.unauthorized }
        access = (t.access_token, Date().addingTimeInterval(Double(t.expires_in ?? 3600) - 60))
        return t.access_token
    }
}

/// Sign-in: `ASWebAuthenticationSession` with PKCE, redirected to the reversed-client-ID scheme. Returns the account's address and
/// the tokens. Only runs in the real app with a client ID (`GoogleConfig`).
@MainActor
final class GoogleAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    let config: GoogleConfig
    let http: HTTPClient
    private var session: ASWebAuthenticationSession?

    init(config: GoogleConfig, http: HTTPClient) { self.config = config; self.http = http }

    enum AuthError: Error { case noClientID, cancelled, noCode, tokenExchange(Int), noEmail }

    func signIn() async throws -> (email: String, tokens: GoogleOAuth.TokenResponse) {
        guard let clientID = config.clientID, let scheme = config.callbackScheme else { throw AuthError.noClientID }
        let verifier = PKCE.verifier()
        let state = PKCE.verifier()
        guard let url = GoogleOAuth.authorizationURL(clientID: clientID, challenge: PKCE.challenge(for: verifier), state: state) else { throw AuthError.noClientID }
        let redirect: URL = try await withCheckedThrowingContinuation { cont in
            let s = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { u, err in
                if let u { cont.resume(returning: u) } else { cont.resume(throwing: err ?? AuthError.cancelled) }
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false
            session = s
            s.start()
        }
        session = nil
        guard let code = GoogleOAuth.code(from: redirect, state: state) else { throw AuthError.noCode }
        var r = URLRequest(url: GoogleOAuth.tokenEndpoint)
        r.httpMethod = "POST"
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        r.httpBody = GoogleOAuth.tokenRequestBody(code: code, verifier: verifier, clientID: clientID)
        let (d, status) = try await http.send(r)
        guard status == 200, let t = try? JSONDecoder().decode(GoogleOAuth.TokenResponse.self, from: d) else { throw AuthError.tokenExchange(status) }
        guard let email = t.id_token.flatMap(GoogleOAuth.email(fromIDToken:)) else { throw AuthError.noEmail }
        return (email, t)
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { NSApp.keyWindow ?? NSApp.windows.first ?? NSWindow() }
    }
}
