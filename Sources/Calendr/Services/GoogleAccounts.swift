import Foundation
import AppKit
import Observation
import CalendrKit

/// One connected Google account as Settings shows it.
struct GoogleAccountInfo: Equatable {
    var email: String
    var accountID: String
    var calendarCount: Int
    var peopleCount: Int
    var lastSync: Date?
    var error: String?
    var statusLine: String {
        if let error { return "Could not sync: \(error.prefix(80))" }
        let cals = "\(calendarCount) calendar\(calendarCount == 1 ? "" : "s")"
        return lastSync == nil ? "Google Calendar API · syncing…" : "Google Calendar API · \(cals) · replies, guests and Meet links"
    }
}

/// Connected Google accounts (v4 Phase 8b): sign-in, the Keychain, one `GoogleStore` each inside the app's `CompositeStore`, and the
/// sync schedule (every 60 s, when the window becomes active, ⌘R). Without a client ID nothing here reaches Google.
@MainActor @Observable
final class GoogleAccounts {
    let config: GoogleConfig
    @ObservationIgnored let tokens: TokenStore
    @ObservationIgnored let http: HTTPClient
    @ObservationIgnored private(set) weak var composite: CompositeStore?
    /// "Connect Google account" was pressed without a client ID: Settings shows what is missing.
    var showsClientIDNote = false
    private(set) var accounts: [GoogleAccountInfo] = []
    private(set) var connecting = false
    /// Every finished Google request, newest last (the demo shows it as a debug line).
    private(set) var lastRequest: String?
    /// Called when Google contacts arrive for an account (Phase 8c).
    @ObservationIgnored var onConnected: ((GoogleStore) -> Void)?
    @ObservationIgnored var onError: ((String) -> Void)?
    @ObservationIgnored var onRequest: ((String) -> Void)?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var zone: TimeZone = .current
    @ObservationIgnored private var peopleCounts: [String: Int] = [:]

    init(config: GoogleConfig, tokens: TokenStore, http: HTTPClient) {
        self.config = config; self.tokens = tokens; self.http = http
    }

    /// The app's store: Google accounts join it. Restores the accounts the Keychain knows (real app only).
    func attach(_ c: CompositeStore, zone: TimeZone, restore: Bool) {
        composite = c
        self.zone = zone
        if restore, let id = config.clientID {
            for mail in tokens.emails() {
                guard let rt = tokens.refreshToken(for: mail) else { continue }
                add(makeStore(email: mail, provider: GoogleTokenProvider(clientID: id, refreshToken: rt, http: http), cache: GoogleStore.cacheURL(for: mail)))
            }
        }
        refreshInfo()
    }

    private func makeStore(email: String, provider: GoogleTokenProvider, cache: URL?, http override: HTTPClient? = nil) -> GoogleStore {
        let api = GoogleCalendarAPI(http: override ?? http, token: { try await provider.token() })
        return GoogleStore(email: email, api: api, zone: zone, cacheURL: cache)
    }

    private func add(_ s: GoogleStore) {
        s.onError = { [weak self] m in self?.onError?(m) }
        s.onRequest = { [weak self] line in self?.lastRequest = line; self?.onRequest?(line) }
        composite?.add(s)
        s.sync()
        loadPeople(s)
        onConnected?(s)
        refreshInfo()
    }

    // MARK: People (Phase 8c)

    @ObservationIgnored private var peopleByAccount: [String: [Teammate]] = [:]
    /// Google contacts of every account, merged (the first account wins for an address).
    @ObservationIgnored var onPeople: (([Teammate]) -> Void)?

    /// Reads the account's contacts and other contacts (People API) in the background.
    func loadPeople(_ s: GoogleStore) {
        let api = GooglePeopleAPI(http: s.api.http, token: s.api.token)
        let email = s.email
        s.track(+1)
        Task.detached {
            let r = try? await api.people()
            s.deliver { [weak self] in
                s.track(-1)
                guard let self, let r else { return }
                self.peopleByAccount[email] = r
                self.peopleCounts[email] = r.count
                self.onPeople?(PeopleMapping.merge(self.stores.map(\.email).compactMap { self.peopleByAccount[$0] }))
                self.refreshInfo()
            }
        }
    }

    /// "Connect Google account". Without a client ID: explains and does nothing else.
    func connect() {
        guard config.clientID != nil else { showsClientIDNote = true; return }
        guard !connecting else { return }
        connecting = true
        let auth = GoogleAuth(config: config, http: http)
        Task { @MainActor in
            defer { connecting = false }
            do {
                let (email, t) = try await auth.signIn()
                guard let rt = t.refresh_token, let id = config.clientID else { onError?("Google sent no refresh token"); return }
                tokens.save(refreshToken: rt, for: email)
                add(makeStore(email: email, provider: GoogleTokenProvider(clientID: id, refreshToken: rt, http: http, initial: t), cache: GoogleStore.cacheURL(for: email)))
            } catch GoogleAuth.AuthError.cancelled {
            } catch { onError?("Could not connect Google: \(error)") }
        }
    }

    /// Headless tours and snapshots: sam.rivera@example.com, answered by `DemoGoogleServer` through a fake HTTP client.
    @discardableResult
    func connectDemo(server: DemoGoogleServer = DemoGoogleServer()) -> GoogleStore {
        let s = makeStore(email: DemoGoogleServer.email, provider: GoogleTokenProvider(clientID: "demo", refreshToken: "demo", http: server.client,
                                                                                         initial: .init(access_token: "demo", expires_in: 3600)),
                          cache: nil, http: server.client)
        add(s)
        return s
    }

    func disconnect(_ email: String) {
        if let s = composite?.google.first(where: { $0.email == email }) { s.deleteCache() }
        composite?.remove(email: email)
        tokens.remove(email)
        peopleCounts[email] = nil
        peopleByAccount[email] = nil
        onPeople?(PeopleMapping.merge(stores.compactMap { peopleByAccount[$0.email] }))
        refreshInfo()
    }

    func setPeopleCount(_ n: Int, for email: String) { peopleCounts[email] = n; refreshInfo() }

    /// Re-reads the stores (after a sync).
    func refreshInfo() {
        let a = (composite?.google ?? []).map {
            GoogleAccountInfo(email: $0.email, accountID: $0.accountID, calendarCount: $0.accounts.first?.calendars.count ?? 0,
                              peopleCount: peopleCounts[$0.email] ?? 0, lastSync: $0.lastSync, error: $0.lastError)
        }
        if a != accounts { accounts = a }
    }

    var stores: [GoogleStore] { composite?.google ?? [] }

    /// Tests and tours: every request has come back.
    var isIdle: Bool { stores.allSatisfy { $0.inFlight == 0 } }

    /// Every 60 s and whenever the app becomes active (⌘R goes through `CalendarStore.refresh`).
    func startPolling() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.syncAll() } }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncAll() }
        }
    }

    func syncAll() { for s in stores { s.sync() } }
}
