import Foundation
import CryptoKit

/// Proof Key for Code Exchange (RFC 7636) with the S256 method: the app keeps a random verifier and sends its SHA-256 (the challenge)
/// with the sign-in; the token request then proves it started the sign-in. Native apps have no client secret, so this is the protection.
public enum PKCE {
    /// 32 random bytes as base64url: 43 characters from the unreserved set (RFC 7636 §4.1).
    public static func verifier(bytes: [UInt8]? = nil) -> String {
        var b = bytes ?? []
        if b.isEmpty {
            var g = SystemRandomNumberGenerator()
            b = (0..<32).map { _ in UInt8.random(in: 0...255, using: &g) }
        }
        return base64url(Data(b))
    }

    /// BASE64URL(SHA256(ASCII(verifier))) (RFC 7636 §4.2).
    public static func challenge(for verifier: String) -> String {
        base64url(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    /// Base64 with the URL alphabet and no padding.
    public static func base64url(_ d: Data) -> String {
        d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
