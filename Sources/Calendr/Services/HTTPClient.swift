import Foundation

/// The one way the Google code reaches the network, so tests and headless runs can answer with fixtures (`FakeHTTPClient`).
protocol HTTPClient: Sendable {
    /// The body and the HTTP status. Throws only for transport errors; a 4xx/5xx is a normal answer.
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

struct URLSessionHTTPClient: HTTPClient {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (d, r) = try await URLSession.shared.data(for: request)
        return (d, (r as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

/// Answers requests from a handler and records them. Used by the tests and by the headless demo Google account; never touches the network.
final class FakeHTTPClient: HTTPClient, @unchecked Sendable {
    struct Sent: Equatable {
        var method: String
        var url: URL
        var body: Data?
        var query: [String: String] { Dictionary((URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a }) }
        var path: String { url.path }
        var json: [String: Any]? { body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } }
    }
    private let lock = NSLock()
    private var _sent: [Sent] = []
    var handler: @Sendable (Sent) -> (Data, Int)

    init(handler: @escaping @Sendable (Sent) -> (Data, Int)) { self.handler = handler }

    var sent: [Sent] { lock.withLock { _sent } }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let s = Sent(method: request.httpMethod ?? "GET", url: request.url!, body: request.httpBody)
        lock.withLock { _sent.append(s) }
        return handler(s)
    }
}
