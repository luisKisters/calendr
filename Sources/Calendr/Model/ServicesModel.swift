import Foundation
import AppKit
import CalendrKit

/// The SERVICES area's model functions (v4 Phase 8): Contacts access, names for bare addresses, the people the guest field suggests.
extension AppModel {
    /// "N without a name · Allow Contacts", the guest menu's foot and Settings → Contacts: macOS asks once; after a "Don't Allow"
    /// only System Settings can change it.
    func allowContacts() {
        let c = services.contacts
        c.refreshAccess()
        switch c.access {
        case .allowed:
            showToast("Contacts already allowed")
        case .denied:
            if options.isHeadless || options.demo { showToast("Opens System Settings → Privacy → Contacts"); return }
            if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") { NSWorkspace.shared.open(u) }
        case .notDetermined:
            c.requestAccess { [weak self] ok in
                guard let self else { return }
                self.showToast(ok ? "Contacts allowed. Names now come from Contacts." : "Contacts not allowed. Addresses stay bare.")
                if self.panelMenus.open == .guests { self.focusEditorField(.guest) }
            }
        }
    }

    /// A guest as the editor shows it: a missing name filled from Apple Contacts, then Google contacts.
    func displayed(_ a: Attendee) -> Attendee { services.resolved(a) }
    func displayed(_ list: [Attendee]) -> [Attendee] { services.resolved(list) }

    /// Everyone the guest field can suggest, without duplicates: the store's people (recent guests), Apple Contacts (once allowed),
    /// then Google contacts. The first entry for an address wins.
    func peopleDirectory() -> [Teammate] {
        var seen = Set<String>()
        var out: [Teammate] = []
        for t in store.teammates + services.contacts.people() + services.googlePeople where seen.insert(t.email.lowercased()).inserted { out.append(t) }
        return out
    }

    /// Where a suggestion comes from, for its icon: recent (the store), Contacts or Google.
    func peopleSource(_ t: Teammate) -> PeopleSource {
        let mail = t.email.lowercased()
        if store.teammates.contains(where: { $0.email.lowercased() == mail }) { return .recent }
        if services.contacts.people().contains(where: { $0.email.lowercased() == mail }) { return .contacts }
        return .google
    }
}

extension AppModel {
    /// Called once from `init`: Google accounts join the app's `CompositeStore`, their errors become toasts, and the real app polls.
    func wireServices() {
        let g = services.google
        g.onError = { [weak self] m in self?.showToast(m) }
        g.onPeople = { [weak self] p in self?.services.setGooglePeople(p) }
        // demo runs (fake Google server): every write shows the request it made, as a debug line
        if options.demo { g.onRequest = { [weak self] line in self?.showToast(line) } }
        guard let c = store as? CompositeStore else { return }
        g.attach(c, zone: math.timeZone, restore: !options.demo)
        if !options.demo && !options.isHeadless { g.startPolling() }
    }

    /// Settings → Accounts → "Connect Google account". Without a client ID it only explains what is missing.
    func connectGoogle() {
        services.google.connect()
        if services.google.config.clientID == nil { showToast("A Google client ID is needed first") }
    }

    func disconnectGoogle(_ email: String) {
        services.google.disconnect(email)
        storeChanged()
        showToast("Removed \(email)")
    }

    /// The accounts Settings lists: the store's (duplicates of connected Google accounts already left out).
    var settingsAccounts: [CalendarAccount] { store.accounts }

    /// macOS Calendar accounts hidden because a connected Google account syncs them directly.
    var hiddenDuplicateAccounts: [String] { (store as? CompositeStore)?.hiddenBaseAccounts.map(\.name) ?? [] }

    /// Headless runs: connects the demo Google account (fake server) and waits until its first sync is in.
    @discardableResult
    func connectDemoGoogle() -> GoogleStore? {
        guard store is CompositeStore else { return nil }
        let s = services.google.connectDemo()
        let until = Date().addingTimeInterval(5)
        while !services.google.isIdle && Date() < until { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
        storeChanged()
        return s
    }
}

enum PeopleSource { case recent, contacts, google }
