import Foundation

/// Links that open a location in a maps app (the location row's menu: Apple Maps, Google Maps, Copy).
public enum MapLinks {
    /// Characters a query value keeps as they are: RFC 3986 unreserved. Everything else is percent-encoded, so "&", "+", "#",
    /// "=", "/" and "?" inside an address can never end the parameter or start a new one. Spaces become %20.
    static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    public static func encode(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    /// `https://maps.apple.com/?q=<address>`: opens Apple Maps (or maps.apple.com in a browser).
    public static func apple(_ address: String) -> URL? {
        guard !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(encode(address))")
    }

    /// `https://www.google.com/maps/search/?api=1&query=<address>` (Google's documented search URL).
    public static func google(_ address: String) -> URL? {
        guard !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(encode(address))")
    }
}
