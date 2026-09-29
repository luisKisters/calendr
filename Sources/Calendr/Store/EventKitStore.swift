import Foundation
import EventKit
import CalendrKit

/// Real calendars via EventKit. Google accounts added in System Settings > Internet Accounts (CalDAV), iCloud and
/// "On My Mac" all show up here. This file only copies fields between EventKit and CalendrKit values; grouping,
/// colors and status decisions live in `EventKitMapping` (tested).
@MainActor
final class EventKitStore: CalendarStore {
    private let store = EKEventStore()
    private let math: CalendarMath
    private(set) var accounts: [CalendarAccount] = []
    private(set) var teammates: [Teammate] = []
    private var attendeeIndex: [String: [CalendarEvent]] = [:]
    var onChange: (() -> Void)?
    let canEditParticipants = false
    var coalescesTextEdits: Bool { true }
    var searchCorpusIsAsync: Bool { true }
    private var cache: [String: EKEvent] = [:]
    private var observer: NSObjectProtocol?

    var authorization: StoreAuthorization {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .authorized
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    var defaultCalendarID: String? { authorization == .authorized ? store.defaultCalendarForNewEvents?.calendarIdentifier : nil }

    init(math: CalendarMath = CalendarMath(timeZone: .current)) {
        self.math = math
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reloadCalendars()
                self?.onChange?()
            }
        }
        if authorization == .authorized { reloadCalendars() }
    }

    func requestAccess() async {
        _ = try? await store.requestFullAccessToEvents()
        reloadCalendars()
        onChange?()
    }

    func refresh() {
        store.refreshSourcesIfNecessary()
        reloadCalendars()
        onChange?()
    }

    // MARK: Calendars

    private func reloadCalendars() {
        guard authorization == .authorized else { accounts = []; return }
        let cals = store.calendars(for: .event)
        var rawSources: [String: RawSource] = [:]
        var rawCals: [RawCalendar] = []
        for c in cals {
            guard let s = c.source else { continue }
            rawSources[s.sourceIdentifier] = RawSource(id: s.sourceIdentifier, title: s.title, type: Self.map(s.sourceType))
            let rgb = (c.color ?? .gray).usingColorSpace(.sRGB)
            rawCals.append(RawCalendar(id: c.calendarIdentifier, sourceID: s.sourceIdentifier, title: c.title, type: Self.map(c.type),
                                       red: Double(rgb?.redComponent ?? 0.5), green: Double(rgb?.greenComponent ?? 0.5), blue: Double(rgb?.blueComponent ?? 0.5),
                                       allowsContentModifications: c.allowsContentModifications))
        }
        accounts = EventKitMapping.accounts(sources: Array(rawSources.values), calendars: rawCals, defaultCalendarID: store.defaultCalendarForNewEvents?.calendarIdentifier)
    }

    nonisolated static func map(_ t: EKSourceType) -> RawSourceType {
        switch t {
        case .local: .local
        case .exchange: .exchange
        case .calDAV: .calDAV
        case .mobileMe: .mobileMe
        case .subscribed: .subscribed
        case .birthdays: .birthdays
        @unknown default: .local
        }
    }
    nonisolated static func map(_ t: EKCalendarType) -> RawCalendarType {
        switch t {
        case .local: .local
        case .calDAV: .calDAV
        case .exchange: .exchange
        case .subscription: .subscription
        case .birthday: .birthday
        @unknown default: .local
        }
    }
    nonisolated static func map(_ s: EKParticipantStatus) -> RawParticipantStatus {
        switch s {
        case .unknown: .unknown
        case .pending: .pending
        case .accepted: .accepted
        case .declined: .declined
        case .tentative: .tentative
        case .delegated: .delegated
        case .completed: .completed
        case .inProcess: .inProcess
        @unknown default: .unknown
        }
    }

    // MARK: Reading

    func events(in range: DateInterval) -> [CalendarEvent] {
        guard authorization == .authorized else { return [] }
        let p = store.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
        return store.events(matching: p).map(convert)
    }

    func teammateEvents(_ email: String, in range: DateInterval) -> [CalendarEvent] {
        events(in: range).filter { e in e.participants.contains { $0.lowercased().contains(email.lowercased()) } }
    }

    func searchCorpus(around date: Date) -> [CalendarEvent] {
        let r = DateInterval(start: math.addDays(date, -365), end: math.addDays(date, 365))
        let evs = events(in: r)
        rebuildTeammates(from: evs)
        return evs
    }

    /// A year each way can be thousands of occurrences: fetch and convert them on a background thread with a private
    /// EKEventStore (the identifiers match the main store's, so search results still resolve to editable events).
    func loadSearchCorpus(around date: Date) async -> [CalendarEvent] {
        guard authorization == .authorized else { return [] }
        let math = self.math
        let range = DateInterval(start: math.addDays(date, -365), end: math.addDays(date, 365))
        let evs = await Task.detached(priority: .userInitiated) { () -> [CalendarEvent] in
            let bg = EKEventStore()
            let p = bg.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
            return bg.events(matching: p).map { Self.makeEvent($0, math: math) }
        }.value
        rebuildTeammates(from: evs)
        return evs
    }

    private func rebuildTeammates(from evs: [CalendarEvent]) {
        var seen: [String: Teammate] = [:]
        for e in evs { for p in e.participants {
            let (name, mail) = Self.split(p)
            if !mail.isEmpty, seen[mail] == nil { seen[mail] = Teammate(name: name.isEmpty ? mail : name, email: mail) }
        } }
        teammates = seen.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated static func split(_ label: String) -> (String, String) {
        if let lt = label.firstIndex(of: "<"), let gt = label.firstIndex(of: ">"), lt < gt {
            return (label[..<lt].trimmingCharacters(in: .whitespaces), String(label[label.index(after: lt)..<gt]))
        }
        return label.contains("@") ? ("", label) : (label, "")
    }

    func series(of event: CalendarEvent) -> [CalendarEvent] {
        guard let sid = event.seriesID else { return [event] }
        return events(in: DateInterval(start: math.addDays(event.start, -365), end: math.addDays(event.start, 365))).filter { $0.seriesID == sid }
    }

    private func convert(_ ev: EKEvent) -> CalendarEvent {
        let out = Self.makeEvent(ev, math: math)
        cache[out.id] = ev
        return out
    }

    nonisolated static func makeEvent(_ ev: EKEvent, math: CalendarMath) -> CalendarEvent {
        let baseID = ev.eventIdentifier ?? ev.calendarItemIdentifier
        let id = "\(baseID)@\(Int(ev.startDate.timeIntervalSince1970))"
        let others = (ev.attendees ?? []).filter { !$0.isCurrentUser }
        let participants = others.compactMap { a -> String? in
            let mail = a.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
            return EventKitMapping.participantLabel(name: a.name, email: mail.contains("@") ? mail : nil)
        }
        let mine = (ev.attendees ?? []).first(where: { $0.isCurrentUser }).map { Self.map($0.participantStatus) }
        let status = EventKitMapping.responseStatus(myStatus: mine, eventTentative: ev.status == .tentative, eventCanceled: ev.status == .canceled)
        var start = ev.startDate ?? Date(), end = ev.endDate ?? start
        if ev.isAllDay {
            start = math.startOfDay(start)
            end = math.addDays(math.startOfDay(end.addingTimeInterval(-1)), 1)
            if end <= start { end = math.addDays(start, 1) }
        }
        let cal = ev.calendar
        let calIsTasks = cal?.title.lowercased() == "tasks" || cal?.title.lowercased() == "reminders"
        return CalendarEvent(
            id: id, seriesID: ev.hasRecurrenceRules ? baseID : nil, calendarID: cal?.calendarIdentifier ?? "",
            title: ev.title ?? "", start: start, end: end, isAllDay: ev.isAllDay,
            kind: EventKitMapping.kind(forTitle: ev.title ?? "", calendarIsTasks: calIsTasks), status: status,
            location: ev.location ?? "", notes: ev.notes ?? "", recurrence: ev.recurrenceRules?.first.flatMap(Self.convert),
            participants: participants, conferencing: ev.url?.absoluteString ?? "",
            reminderMinutes: EventKitMapping.reminderMinutes(alarmOffsetSeconds: (ev.alarms ?? []).map(\.relativeOffset)),
            availability: ev.availability == .free ? .free : .busy, visibility: .standard,
            timeZoneID: ev.timeZone?.identifier ?? math.timeZone.identifier)
    }

    nonisolated static func convert(_ r: EKRecurrenceRule) -> Recurrence {
        let f: Recurrence.Frequency
        switch r.frequency { case .daily: f = .daily; case .weekly: f = .weekly; case .monthly: f = .monthly; case .yearly: f = .yearly; @unknown default: f = .weekly }
        return Recurrence(frequency: f, interval: r.interval, weekdays: (r.daysOfTheWeek ?? []).map { $0.dayOfTheWeek.rawValue }, until: r.recurrenceEnd?.endDate)
    }

    // MARK: Writing

    @discardableResult
    func create(_ event: CalendarEvent) throws -> CalendarEvent {
        let ek = EKEvent(eventStore: store)
        ek.calendar = store.calendar(withIdentifier: event.calendarID) ?? store.defaultCalendarForNewEvents
        apply(event, to: ek)
        try store.save(ek, span: .thisEvent, commit: true)
        return convert(ek)
    }

    @discardableResult
    func update(_ event: CalendarEvent, span: EditSpan) throws -> CalendarEvent {
        guard let ek = cache[event.id] else { return event }
        if span == .all, let master = ek.eventIdentifier.flatMap({ store.event(withIdentifier: $0) }) {
            var shifted = event
            let delta = event.start.timeIntervalSince(ek.startDate)
            shifted.start = master.startDate.addingTimeInterval(delta)
            shifted.end = shifted.start.addingTimeInterval(event.end.timeIntervalSince(event.start))
            apply(shifted, to: master)
            try store.save(master, span: .futureEvents, commit: true)
            return convert(master)
        }
        apply(event, to: ek)
        try store.save(ek, span: span == .this ? .thisEvent : .futureEvents, commit: true)
        return convert(ek)
    }

    func delete(_ event: CalendarEvent, span: EditSpan) throws {
        guard let ek = cache[event.id] else { return }
        if span == .all, let master = ek.eventIdentifier.flatMap({ store.event(withIdentifier: $0) }) {
            try store.remove(master, span: .futureEvents, commit: true)
        } else {
            try store.remove(ek, span: span == .this ? .thisEvent : .futureEvents, commit: true)
        }
        cache[event.id] = nil
    }

    private func apply(_ e: CalendarEvent, to ek: EKEvent) {
        ek.title = e.title
        ek.location = e.location.isEmpty ? nil : e.location
        ek.notes = e.notes.isEmpty ? nil : e.notes
        ek.isAllDay = e.isAllDay
        ek.startDate = e.start
        ek.endDate = e.isAllDay ? e.end.addingTimeInterval(-1) : e.end
        ek.availability = e.availability == .free ? .free : .busy
        ek.url = e.conferencing.isEmpty ? nil : URL(string: e.conferencing)
        if e.isAllDay { ek.timeZone = nil }      // all-day events are floating dates
        else if let tz = TimeZone(identifier: e.timeZoneID) { ek.timeZone = tz }
        if let cal = store.calendar(withIdentifier: e.calendarID), cal.allowsContentModifications, ek.calendar?.calendarIdentifier != cal.calendarIdentifier { ek.calendar = cal }
        for a in ek.alarms ?? [] { ek.removeAlarm(a) }
        if let off = EventKitMapping.alarmOffsetSeconds(minutes: e.reminderMinutes) { ek.addAlarm(EKAlarm(relativeOffset: off)) }
    }
}
