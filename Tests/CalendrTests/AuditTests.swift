import Testing
import Foundation
import CalendrKit
@testable import Calendr

@MainActor
@Suite("DMG audit time boundaries")
struct AuditTests {
    @Test func allDayRoundTripPreservesMidnightAndOvernightTimes() {
        for days in [1, 2] {
            let m = makeModel()
            let start = m.math.date(year: 2026, month: 10, day: 1, hour: 22)
            let end = m.math.date(year: 2026, month: 10, day: 1 + days)
            m.createEvent(start: start, end: end)
            m.setSelectedAllDay(true)
            m.setSelectedAllDay(false)
            #expect(m.selectedEvent?.start == start)
            #expect(m.selectedEvent?.end == end)
        }
    }

    @Test func allDayRoundTripPreservesTheRepeatedHourOccurrence() {
        let m = makeModel()
        let first = m.math.date(year: 2026, month: 10, day: 25, hour: 2, minute: 30)
        let start = first.addingTimeInterval(3600) // second 02:30, after the clocks go back
        let end = start.addingTimeInterval(3600)
        m.createEvent(start: start, end: end)
        m.setSelectedAllDay(true)
        m.setSelectedAllDay(false)
        #expect(m.selectedEvent?.start == start)
        #expect(m.selectedEvent?.end == end)
    }

    @Test func noFreeTimeDoesNotCreateInThePast() {
        let m = makeModel()
        m.setNow(m.math.date(year: 2026, month: 9, day: 29, hour: 23, minute: 45))
        m.createAtNextFreeSlot()
        #expect(m.draft == nil)
        #expect(m.toast?.text == "No free slot left today")
    }

    @Test func ongoingOvernightEventBlocksMorningSlots() throws {
        let m = makeModel()
        let day = m.math.startOfDay(m.now)
        let shift = CalendarEvent(calendarID: DemoDataV4.personal, title: "Overnight on-call shift",
                                  start: m.math.addDays(day, -1).addingTimeInterval(22 * 3600), end: day.addingTimeInterval(6 * 3600))
        try m.store.create(shift)
        m.setNow(day.addingTimeInterval(30 * 60))
        m.createAtNextFreeSlot()
        #expect(m.draft!.start >= shift.end)
    }

    // MARK: Snapshot and mockup bookkeeping

    static func statesJSON() throws -> (root: URL, json: [String: Any], states: [String: [String: Any]]) {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("design/states.json"))) as! [String: Any]
        return (root, json, json["states"] as! [String: [String: Any]])
    }

    @Test func everyStatesEntryExistsInASnapshotHook() throws {
        let (_, _, states) = try Self.statesJSON()
        #expect(!states.isEmpty)
        for (name, s) in states {
            let state = s["state"] as? String ?? name
            #expect(SnapshotStates.all.contains(state) || SnapshotMenuBar.screens.contains(state), "\(name): \(state) is not in SnapshotStates.all")
            if SnapshotMenuBar.screens.contains(state) { continue }
            let o = LaunchOptions.parse(["Calendr", "--demo", "--freeze-clock"])
            let m = AppModel(store: DemoStore(), options: o, persist: false)
            #expect(SnapshotStates.apply(state, to: m), "\(name): no snapshot hook applies \(state)")
        }
    }

    @Test func everyMockupEntryHasAShotFile() throws {
        let (root, json, states) = try Self.statesJSON()
        let dir = try #require(json["mockupDir"] as? String)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(dir).appendingPathComponent("index.html").path))
        let withMockup = states.filter { $0.value["mockup"] != nil }
        #expect(withMockup.count >= 8)
        for (name, s) in withMockup {
            let m = s["mockup"] as! String
            let shot = s["shot"] as? String ?? m.replacingOccurrences(of: "&", with: "-").replacingOccurrences(of: "=", with: "-")
            let path = root.appendingPathComponent(dir).appendingPathComponent("shots/\(shot).png").path
            #expect(FileManager.default.fileExists(atPath: path), "\(name): missing \(dir)/shots/\(shot).png (run swift scripts/render-mockup.swift)")
        }
    }
}
