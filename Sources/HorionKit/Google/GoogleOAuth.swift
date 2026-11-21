import Foundation

/// Google OAuth 2.0 for a native app (an "iOS" type client, which macOS apps use): the authorization code flow with PKCE and a
/// custom URL scheme redirect made from the reversed client ID. No client secret. Pure: builds URLs and bodies, parses responses.
public enum GoogleOAuth {
    public static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    public static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    public static let revokeEndpoint = URL(string: "https://oauth2.googleapis.com/revoke")!

    /// Calendar events (read and write, replies, guests, Meet links), the calendar list (read), contacts and "other contacts" (read),
    /// and the address of the account. All but `email` are sensitive scopes in Google's terms.
    public static let scopes = [
        "openid", "email",
        "https://www.googleapis.com/auth/calendar.events",
        "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
        "https://www.googleapis.com/auth/contacts.readonly",
        "https://www.googleapis.com/auth/contacts.other.readonly",
    ]

    /// "1234-abc.apps.googleusercontent.com" -> "com.googleusercontent.apps.1234-abc" (the URL scheme Google registers for the client).
    public static func reversedClientID(_ clientID: String) -> String? {
        let suffix = ".apps.googleusercontent.com"
        guard clientID.hasSuffix(suffix), clientID.count > suffix.count else { return nil }
        return "com.googleusercontent.apps." + clientID.dropLast(suffix.count)
    }

    /// "com.googleusercontent.apps.1234-abc:/oauth2redirect"
    public static func redirectURI(_ clientID: String) -> String? { reversedClientID(clientID).map { "\($0):/oauth2redirect" } }

    public static func authorizationURL(clientID: String, challenge: String, state: String, loginHint: String? = nil) -> URL? {
        guard let redirect = redirectURI(clientID), var c = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false) else { return nil }
        var q = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            // a refresh token, and the consent screen again when the scopes grow
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        if let h = loginHint { q.append(URLQueryItem(name: "login_hint", value: h)) }
        c.queryItems = q
        return c.url
    }

    /// The code from the redirect, after checking `state`. Nil when the user cancelled, Google sent an error, or the state differs.
    public static func code(from redirect: URL, state: String) -> String? {
        let items = URLComponents(url: redirect, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == state else { return nil }
        return items.first { $0.name == "code" }?.value
    }

    public static func tokenRequestBody(code: String, verifier: String, clientID: String) -> Data {
        form(["grant_type": "authorization_code", "code": code, "code_verifier": verifier, "client_id": clientID, "redirect_uri": redirectURI(clientID) ?? ""])
    }

    public static func refreshRequestBody(refreshToken: String, clientID: String) -> Data {
        form(["grant_type": "refresh_token", "refresh_token": refreshToken, "client_id": clientID])
    }

    /// application/x-www-form-urlencoded, keys sorted.
    public static func form(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let s = fields.keys.sorted().map { k in "\(k)=\(fields[k]!.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }.joined(separator: "&")
        return Data(s.utf8)
    }

    public struct TokenResponse: Codable, Equatable, Sendable {
        public var access_token: String
        public var expires_in: Int?
        public var refresh_token: String?
        public var scope: String?
        public var token_type: String?
        public var id_token: String?
        public init(access_token: String, expires_in: Int? = nil, refresh_token: String? = nil, scope: String? = nil, token_type: String? = nil, id_token: String? = nil) {
            self.access_token = access_token; self.expires_in = expires_in; self.refresh_token = refresh_token; self.scope = scope; self.token_type = token_type; self.id_token = id_token
        }
    }

    /// The `email` claim of an ID token (the token comes straight from Google over TLS, so the payload is read without checking the signature).
    public static func email(fromIDToken t: String) -> String? {
        let parts = t.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        guard let d = Data(base64Encoded: b), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        return o["email"] as? String
    }
}
