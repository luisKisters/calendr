import Testing
import Foundation
import CalendrKit
@testable import Calendr

@MainActor
func makeModelV4() -> AppModel {
    let o = LaunchOptions.parse(["Calendr", "--fixture", "v4", "--freeze-clock"])
    return AppModel(store: DemoStore(fixture: .v4), options: o, persist: false)
}

/// design/mockup-v4/index.html, read from the source tree.
func mockupV4HTML() throws -> String {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("design/mockup-v4/index.html")
    return try String(contentsOf: url, encoding: .utf8)
}

@MainActor
@Suite("v4 fixture matches design/mockup-v4")
struct FixtureV4Tests {
    @Test func launchOptionsPinTheMockupClockAndHourHeight() {
        let m = makeModelV4()
        #expect(m.fmt.time(m.now) == "15:10" && m.math.day(m.now) == 4 && m.math.month(m.now) == 10)
        #expect(m.settings.hourHeight == 46)
        #expect(m.visibleDays.first.map { m.math.day($0) } == 28)
    }

    @Test func weekHasTheMockupCountsOfTimedAndAllDayEvents() throws {
        let store = DemoStore(fixture: .v4)
        let week = DateInterval(start: DemoDataV4.weekStart, end: DemoDataV4.math.addDays(DemoDataV4.weekStart, 7))
        let events = store.events(in: week)
        #expect(events.filter { !$0.isAllDay }.count == 53)
        #expect(events.filter(\.isAllDay).count == 14)
        // The same counts as the mockup's RAW and RAW_AD tables.
        let html = try mockupV4HTML()
        let rawRows = html.matches(of: #/\['\w+', \d, '\d\d:\d\d', '\d\d:\d\d', /#).count
        let block = html.range(of: "const RAW_AD = [").map { html[$0.upperBound...] }.flatMap { s in s.range(of: "];").map { s[..<$0.lowerBound] } } ?? ""
        let adRows = block.matches(of: #/\[\d, \d, '/#).count
        #expect(rawRows == 53 && adRows == 14)
    }

    @Test func wednesdayHasFlatCleaningAndClubBoardMeeting() {
        let m = makeModelV4()
        let wed = m.layout.timed[2].map(\.event.title)
        #expect(wed.contains("Flat cleaning") && wed.contains("Club board meeting"))
        let cleaning = m.layout.timed[2].first { $0.event.title == "Flat cleaning" }!.event
        #expect(cleaning.status == .declined && m.fmt.timeRange(cleaning.start, cleaning.end).hasPrefix("18:00"))
        // Club board meeting is not answered yet.
        let board = m.layout.timed[2].first { $0.event.title == "Club board meeting" }!.event
        #expect(board.status == .needsAction && board.myReply == .needsAction && board.isUnaccepted && board.isRecurring && board.conferencing.contains("oet-mzpa-wdr"))
    }

    @Test func flatDinnerCarriesTheMockupDetails() {
        let e = DemoDataV4.buildEvents().first { $0.id == "v4.wg" }!
        #expect(e.colorHex == "#5FB97E" && e.participants == ["Mara Hoffmann", "Jonas Weber", "dion.k@example.com", "sam@example.net"])
        #expect(e.iAmOrganizer && e.myReply == .confirmed && e.attendees.count == 5 && e.attendees.last?.status == .needsAction)
        #expect(e.location == "Kitchen, 12 Harbour Street" && e.reminderMinutes == 10 && e.recurrence?.weekdays == [1])
    }

    @Test func everyAddressUsesAReservedExampleDomain() {
        let reserved = ["example.com", "example.org", "example.net"]
        func ok(_ email: String) -> Bool {
            let domain = email.split(separator: "@").last.map(String.init) ?? ""
            return reserved.contains(domain) || domain.hasSuffix(".example") || domain == "example"
        }
        let all = DemoDataV4.people.map(\.email) + DemoDataV4.accounts.map(\.name) + DemoDataV4.teammates.map(\.email)
        #expect(all.count > 10)
        for a in all { #expect(ok(a), "\(a) is not a reserved example domain") }
    }

    @Test func wednesdayEveningGivesOnePlusOneAt1815WithTheV5Layout() {
        let math = DemoDataV4.math
        let wed = math.addDays(DemoDataV4.weekStart, 2)
        let items = DemoDataV4.buildEvents().filter { !$0.isAllDay && math.isSameDay($0.start, wed) }.map {
            V5Item(id: $0.id, start: $0.start, end: $0.end, day: wed, math: math, isUnaccepted: $0.isUnaccepted)
        }
        let unaccepted = Set(items.filter(\.isUnaccepted).map(\.id))
        #expect(unaccepted == ["v4.w3", "v4.w5"])
        let r = OverlapV5.layout(items)
        #expect(r.groups == [OverflowGroup(startMinute: 18 * 60 + 15, ids: ["v4.c5"])])
    }
}
