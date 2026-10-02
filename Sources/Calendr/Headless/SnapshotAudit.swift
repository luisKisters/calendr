import Foundation
import CalendrKit

/// Reproducible audit evidence using the same model actions as the UI.
@MainActor
enum SnapshotAudit {
    static func apply(_ state: String, _ m: AppModel) -> Bool {
        switch state {
        case "audit-dst":
            let day = m.math.date(year: 2026, month: 10, day: 25)
            m.go(to: day)
            m.setMode(.day)
            let start = m.math.date(on: day, minutes: 9 * 60)
            m.createEvent(start: start, end: start.addingTimeInterval(3600))
            m.updateSelected { $0.title = "Sunday breakfast with Maya" }
        case "audit-midnight-initial", "audit-midnight-all-day", "audit-midnight-restored":
            let day = m.math.date(year: 2026, month: 10, day: 1)
            m.go(to: day)
            m.setMode(.day)
            let start = m.math.date(on: day, minutes: 22 * 60)
            m.createEvent(start: start, end: m.math.addDays(day, 1))
            m.updateSelected { $0.title = "Evening studio session" }
            if state != "audit-midnight-initial" { m.setSelectedAllDay(true) }
            if state == "audit-midnight-restored" { m.setSelectedAllDay(false) }
        case "audit-overnight":
            let day = m.math.startOfDay(m.now)
            let event = CalendarEvent(calendarID: DemoData.personal, title: "Overnight on-call shift",
                                      start: m.math.addDays(day, -1).addingTimeInterval(22 * 3600), end: day.addingTimeInterval(6 * 3600))
            _ = try? m.store.create(event)
            m.setNow(day.addingTimeInterval(30 * 60))
            m.setMode(.day)
            m.createAtNextFreeSlot()
        case "audit-full-day":
            m.setNow(m.math.date(year: 2026, month: 9, day: 29, hour: 23, minute: 45))
            m.createAtNextFreeSlot()
        default: return false
        }
        return true
    }
}
