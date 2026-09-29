import Foundation
import CalendrKit

/// In-memory store used for `--demo`, tests, snapshots, the walkthrough and perf runs.
@MainActor
final class DemoStore: CalendarStore {
    private(set) var accounts: [CalendarAccount] = DemoData.accounts
    let teammates: [Teammate] = DemoData.teammates
    var authorization: StoreAuthorization = .authorized
    let defaultCalendarID: String? = DemoData.personal
    let canEditParticipants = true
    /// Tests flip this to exercise the debounced write path that EventKit uses.
    var coalescesTextEdits = false
    var onChange: (() -> Void)?

    private var events: [CalendarEvent]          // sorted by start
    private var maxDuration: TimeInterval = 0
    private let teamEvents: [String: [CalendarEvent]]
    private let math = DemoData.math
    private(set) var refreshCount = 0

    init(dense: Bool = false, authorization: StoreAuthorization = .authorized) {
        self.authorization = authorization
        let t0 = CFAbsoluteTimeGetCurrent()
        events = DemoData.buildEvents(dense: dense)
        if ProcessInfo.processInfo.environment["CALENDR_PROF"] != nil { print(String(format: "buildEvents %.0f ms (%d events)", (CFAbsoluteTimeGetCurrent() - t0) * 1000, events.count)) }
        let t1 = CFAbsoluteTimeGetCurrent()
        var byMail: [String: [CalendarEvent]] = [:]
        for e in DemoData.teammateEvents() { byMail[e.ownerEmail ?? "", default: []].append(e) }
        teamEvents = byMail
        if ProcessInfo.processInfo.environment["CALENDR_PROF"] != nil { print(String(format: "teammates %.0f ms", (CFAbsoluteTimeGetCurrent() - t1) * 1000)) }
        recomputeMax()
    }

    private func recomputeMax() { maxDuration = events.reduce(0) { max($0, $1.end.timeIntervalSince($1.start)) } }

    private func lowerBound(_ t: Date) -> Int {
        var lo = 0, hi = events.count
        while lo < hi { let m = (lo + hi) / 2; if events[m].start < t { lo = m + 1 } else { hi = m } }
        return lo
    }

    func requestAccess() async {}
    func refresh() { refreshCount += 1; onChange?() }

    func events(in range: DateInterval) -> [CalendarEvent] {
        var out: [CalendarEvent] = []
        var i = lowerBound(range.start.addingTimeInterval(-maxDuration))
        while i < events.count, events[i].start < range.end {
            if events[i].end > range.start || (events[i].end == events[i].start && events[i].start >= range.start) { out.append(events[i]) }
            i += 1
        }
        return out
    }

    func teammateEvents(_ email: String, in range: DateInterval) -> [CalendarEvent] {
        (teamEvents[email] ?? []).filter { $0.end > range.start && $0.start < range.end }
    }

    func searchCorpus(around date: Date) -> [CalendarEvent] { events }

    func series(of event: CalendarEvent) -> [CalendarEvent] {
        guard let sid = event.seriesID else { return [event] }
        return events.filter { $0.seriesID == sid }
    }

    @discardableResult
    func create(_ event: CalendarEvent) throws -> CalendarEvent {
        insert(event)
        onChange?()
        return event
    }

    private func insert(_ e: CalendarEvent) {
        let i = lowerBound(e.start)
        events.insert(e, at: i)
        maxDuration = max(maxDuration, e.end.timeIntervalSince(e.start))
    }

    @discardableResult
    func update(_ event: CalendarEvent, span: EditSpan) throws -> CalendarEvent {
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return event }
        let old = events[idx]
        var targets: [Int] = [idx]
        if span != .this, let sid = old.seriesID {
            targets = events.indices.filter { events[$0].seriesID == sid && (span == .all || events[$0].start >= old.start) }
        }
        let dayDelta = math.daysBetween(old.start, event.start)
        let startMin = math.minutesSinceMidnight(event.start)
        let dur = event.end.timeIntervalSince(event.start)
        for t in targets {
            var e = event
            if events[t].id != event.id {
                e.id = events[t].id
                if !event.isAllDay {
                    let day = math.addDays(events[t].start, dayDelta)
                    e.start = math.date(on: day, minutes: startMin)
                    e.end = e.start.addingTimeInterval(dur)
                } else {
                    e.start = math.addDays(events[t].start, dayDelta)
                    e.end = e.start.addingTimeInterval(dur)
                }
            }
            events[t] = e
        }
        events.sort { $0.start != $1.start ? $0.start < $1.start : $0.id < $1.id }
        recomputeMax()
        onChange?()
        return event
    }

    func delete(_ event: CalendarEvent, span: EditSpan) throws {
        if span == .this || event.seriesID == nil {
            events.removeAll { $0.id == event.id }
        } else if let sid = event.seriesID {
            events.removeAll { $0.seriesID == sid && (span == .all || $0.start >= event.start) }
        }
        onChange?()
    }
}
