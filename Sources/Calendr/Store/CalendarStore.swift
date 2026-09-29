import Foundation
import CalendrKit

enum StoreAuthorization: Equatable { case authorized, notDetermined, denied }

/// Which occurrences of a recurring event an edit or delete applies to.
enum EditSpan { case this, future, all }

@MainActor
protocol CalendarStore: AnyObject {
    var accounts: [CalendarAccount] { get }
    var teammates: [Teammate] { get }
    var authorization: StoreAuthorization { get }
    var defaultCalendarID: String? { get }
    /// EventKit cannot add attendees; the inspector shows them read-only and says so.
    var canEditParticipants: Bool { get }
    var onChange: (() -> Void)? { get set }
    /// True when every save is a network sync (EventKit): the model debounces text edits.
    var coalescesTextEdits: Bool { get }
    /// True when `loadSearchCorpus` does real background work (the model then shows results when it arrives).
    var searchCorpusIsAsync: Bool { get }

    func requestAccess() async
    /// Cmd-R: asks the system to re-sync remote sources (Google, iCloud) and reloads.
    func refresh()
    func events(in range: DateInterval) -> [CalendarEvent]
    func teammateEvents(_ email: String, in range: DateInterval) -> [CalendarEvent]
    /// Everything searchable around `date` (demo: all events, EventKit: +/- 1 year).
    func searchCorpus(around date: Date) -> [CalendarEvent]
    /// Same as `searchCorpus` but must not block the main thread.
    func loadSearchCorpus(around date: Date) async -> [CalendarEvent]
    @discardableResult func create(_ event: CalendarEvent) throws -> CalendarEvent
    @discardableResult func update(_ event: CalendarEvent, span: EditSpan) throws -> CalendarEvent
    func delete(_ event: CalendarEvent, span: EditSpan) throws
    func series(of event: CalendarEvent) -> [CalendarEvent]
}

extension CalendarStore {
    var coalescesTextEdits: Bool { false }
    var searchCorpusIsAsync: Bool { false }
    func loadSearchCorpus(around date: Date) async -> [CalendarEvent] { searchCorpus(around: date) }
    func calendar(_ id: String) -> CalendarInfo? {
        for a in accounts { if let c = a.calendars.first(where: { $0.id == id }) { return c } }
        return nil
    }
    var allCalendars: [CalendarInfo] { accounts.flatMap(\.calendars) }
}
