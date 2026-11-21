import Foundation
import AppKit
import AuthenticationServices
import Security
import CalendrKit

/// Where refresh tokens live: the Keychain, one item per Google account. Tests and demo runs use `MemoryTokenStore`.
protocol TokenStore: AnyObject {
    func refreshToken(for email: String) -> String?
    /// False when the token could not be stored: the account is then not recorded.
    @discardableResult func save(refreshToken: String, for email: String) -> Bool
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

    @discardableResult
    func save(refreshToken: String, for email: String) -> Bool {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: email]
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = Data(refreshToken.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        add[kSecAttrLabel as String] = "Calendr Google account \(email)"
        // the account list only records an account whose token is in the Keychain
        guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { return false }
        var order = emails().filter { $0 != email }
        order.append(email)
        UserDefaults.standard.set(order, forKey: orderKey)
        return true
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
    var failsSaves = false
    @discardableResult
    func save(refreshToken: String, for email: String) -> Bool {
        guard !failsSaves else { return false }
        tokens.removeAll { $0.0 == email }; tokens.append((email, refreshToken))
        return true
    }
    func remove(_ email: String) { tokens.removeAll { $0.0 == email } }
    func emails() -> [String] { tokens.map(\.0) }
}

/// Access tokens for one account: refreshed with the refresh token when the cached one is about to expire.
actor GoogleTokenProvider {
    let clientID: String
    private(set) var refreshToken: String
    let http: HTTPClient
    /// Google sent a new refresh token (rotation): the caller stores it.
    let onRotate: @Sendable (String) -> Void
    /// Pause between retries (tests: zero).
    let retryDelay: UInt64
    private var access: (token: String, expires: Date)?

    init(clientID: String, refreshToken: String, http: HTTPClient, initial: GoogleOAuth.TokenResponse? = nil,
         retryDelay: UInt64 = 500_000_000, onRotate: @escaping @Sendable (String) -> Void = { _ in }) {
        self.clientID = clientID; self.refreshToken = refreshToken; self.http = http; self.onRotate = onRotate; self.retryDelay = retryDelay
        if let i = initial { access = (i.access_token, Date().addingTimeInterval(Double(i.expires_in ?? 3600) - 60)) }
    }

    /// A valid access token. Transport errors and 5xx are retried twice; `invalid_grant` (a revoked or expired refresh token) means
    /// the account must sign in again (`needsReconnect`) and is not retried.
    func token() async throws -> String {
        if let a = access, a.expires > Date() { return a.token }
        var r = URLRequest(url: GoogleOAuth.tokenEndpoint)
        r.httpMethod = "POST"
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        r.httpBody = GoogleOAuth.refreshRequestBody(refreshToken: refreshToken, clientID: clientID)
        var attempt = 0
        while true {
            attempt += 1
            let answer: (Data, Int)
            do { answer = try await http.send(r) } catch {
                if attempt < 3 { try? await Task.sleep(nanoseconds: retryDelay); continue }
                throw error
            }
            let (d, status) = answer
            if status >= 500 && attempt < 3 { try? await Task.sleep(nanoseconds: retryDelay); continue }
            if status == 200, let t = try? JSONDecoder().decode(GoogleOAuth.TokenResponse.self, from: d) {
                access = (t.access_token, Date().addingTimeInterval(Double(t.expires_in ?? 3600) - 60))
                if let rt = t.refresh_token, rt != refreshToken { refreshToken = rt; onRotate(rt) }
                return t.access_token
            }
            let err = (try? JSONSerialization.jsonObject(with: d) as? [String: Any])?["error"] as? String
            if err == "invalid_grant" || status == 401 { throw GoogleCalendarAPI.APIError.needsReconnect }
            throw GoogleCalendarAPI.APIError.status(status, String(decoding: d.prefix(200), as: UTF8.self))
        }
    }

    /// Remove account: the refresh token is revoked at Google (best effort).
    func revoke() async {
        var r = URLRequest(url: GoogleOAuth.revokeEndpoint)
        r.httpMethod = "POST"
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        r.httpBody = GoogleOAuth.form(["token": refreshToken])
        _ = try? await http.send(r)
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
