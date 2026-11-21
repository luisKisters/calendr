import Foundation
import CalendrKit

/// The base store (EventKit for iCloud, local and other calendars; the demo store in headless runs) plus one `GoogleStore` per connected
/// Google account (v4 Phase 8b, plan Q2 default). A Google account that macOS Calendar also syncs over CalDAV would show every event
/// twice: the base store's account with the same address is hidden while the Google account is connected.
/// Every call goes to the store that owns the calendar.
@MainActor
final class CompositeStore: CalendarStore {
    let base: CalendarStore
    private(set) var google: [GoogleStore] = []
    var onChange: (() -> Void)? { didSet { wire() } }

    init(base: CalendarStore, google: [GoogleStore] = []) {
        self.base = base
        self.google = google
        wire()
    }

    private func wire() {
        base.onChange = { [weak self] in self?.onChange?() }
        for g in google { g.onChange = { [weak self] in self?.onChange?() } }
    }

    func add(_ g: GoogleStore) {
        google.removeAll { $0.email.lowercased() == g.email.lowercased() }
        google.append(g)
        wire()
        onChange?()
    }

    func remove(email: String) {
        google.removeAll { $0.email.lowercased() == email.lowercased() }
        onChange?()
    }

    /// The addresses of the connected Google accounts.
    var googleEmails: Set<String> { Set(google.map { $0.email.lowercased() }) }

    /// Base-store accounts hidden because a connected Google account syncs them directly (same address; EventKit names a
    /// Google CalDAV source after the account's address).
    var hiddenBaseAccounts: [CalendarAccount] {
        let mails = googleEmails
        return base.accounts.filter { mails.contains($0.name.lowercased()) }
    }
    private var hiddenBaseCalendarIDs: Set<String> { Set(hiddenBaseAccounts.flatMap { $0.calendars.map(\.id) }) }

    private func owner(_ calendarID: String) -> CalendarStore {
        google.first { $0.googleCalendar(calendarID) != nil } ?? base
    }

    // MARK: CalendarStore

    var accounts: [CalendarAccount] {
        let mails = googleEmails
        return base.accounts.filter { !mails.contains($0.name.lowercased()) } + google.flatMap(\.accounts)
    }
    var teammates: [Teammate] { base.teammates }
    /// A connected Google account is enough to use the app: no EventKit access needed for it.
    var authorization: StoreAuthorization { google.isEmpty ? base.authorization : .authorized }
    var defaultCalendarID: String? {
        if let d = base.defaultCalendarID, !hiddenBaseCalendarIDs.contains(d) { return d }
        return google.lazy.compactMap(\.defaultCalendarID).first ?? base.defaultCalendarID
    }
    var canEditParticipants: Bool { base.canEditParticipants || !google.isEmpty }
    var canSendUpdates: Bool { base.canSendUpdates || !google.isEmpty }
    var canRespond: Bool { base.canRespond || !google.isEmpty }
    var coalescesTextEdits: Bool { base.coalescesTextEdits || !google.isEmpty }
    var searchCorpusIsAsync: Bool { base.searchCorpusIsAsync }
    var isDemo: Bool { base.isDemo }

    func canSendUpdates(calendarID: String) -> Bool { owner(calendarID).canSendUpdates(calendarID: calendarID) }
    func canRespond(calendarID: String) -> Bool { owner(calendarID).canRespond(calendarID: calendarID) }
    func canEditParticipants(calendarID: String) -> Bool { owner(calendarID).canEditParticipants(calendarID: calendarID) }
    func canCreateMeetLinks(calendarID: String) -> Bool { owner(calendarID).canCreateMeetLinks(calendarID: calendarID) }
    func canUndoSeriesDelete(calendarID: String) -> Bool { owner(calendarID).canUndoSeriesDelete(calendarID: calendarID) }

    func requestAccess() async { await base.requestAccess() }
    func refresh() { base.refresh(); for g in google { g.refresh() } }

    /// Base events that a connected Google account also brings: the accounts with the same address (the rule above, a fallback
    /// since EventKit names a CalDAV source after the address only by habit), and any event whose iCalUID (EventKit's external
    /// identifier) a Google calendar has.
    private func visible(_ list: [CalendarEvent]) -> [CalendarEvent] {
        guard !google.isEmpty else { return list }
        let hidden = hiddenBaseCalendarIDs
        let uids = googleUIDs
        return list.filter { !hidden.contains($0.calendarID) && !($0.externalID.map(uids.contains) ?? false) }
    }
    private var googleUIDs: Set<String> { Set(google.flatMap { $0.externalIDs }) }

    func events(in range: DateInterval) -> [CalendarEvent] {
        let b = visible(base.events(in: range))
        return google.isEmpty ? b : b + google.flatMap { $0.events(in: range) }
    }
    func teammateEvents(_ email: String, in range: DateInterval) -> [CalendarEvent] { base.teammateEvents(email, in: range) }
    func searchCorpus(around date: Date) -> [CalendarEvent] { visible(base.searchCorpus(around: date)) + google.flatMap { $0.searchCorpus(around: date) } }
    func loadSearchCorpus(around date: Date) async -> [CalendarEvent] {
        let b = await base.loadSearchCorpus(around: date)
        return visible(b) + google.flatMap { $0.searchCorpus(around: date) }
    }

    func create(_ event: CalendarEvent) throws -> CalendarEvent { try owner(event.calendarID).create(event) }
    func update(_ event: CalendarEvent, span: EditSpan) throws -> CalendarEvent { try route(event).update(event, span: span) }
    func delete(_ event: CalendarEvent, span: EditSpan) throws { try route(event).delete(event, span: span) }
    func create(_ event: CalendarEvent, notify: Bool) throws -> CalendarEvent { try owner(event.calendarID).create(event, notify: notify) }
    func update(_ event: CalendarEvent, span: EditSpan, notify: Bool) throws -> CalendarEvent { try route(event).update(event, span: span, notify: notify) }
    func delete(_ event: CalendarEvent, span: EditSpan, notify: Bool) throws { try route(event).delete(event, span: span, notify: notify) }
    func series(of event: CalendarEvent) -> [CalendarEvent] { route(event).series(of: event) }

    /// An existing event belongs to the store whose id it carries (a move to another calendar is that store's business).
    private func route(_ e: CalendarEvent) -> CalendarStore {
        google.first { e.id.hasPrefix("google:\($0.email)/") } ?? owner(e.calendarID)
    }
}
