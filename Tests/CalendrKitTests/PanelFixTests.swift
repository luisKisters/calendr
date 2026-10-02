import Testing
import Foundation
@testable import CalendrKit

@Suite("Panel fixes: time parsing, countdown")
struct PanelKitFixTests {
    @Test func timesAsTheMockupParsesThem() {
        #expect(TimeParser.parse("24") == 1440 && TimeParser.parse("24:00") == 1440 && TimeParser.parse("2400") == 1440)
        #expect(TimeParser.parse("24:30") == nil && TimeParser.parse("25") == nil)
        #expect(TimeParser.parse("9h30") == 570 && TimeParser.parse("0930") == 570 && TimeParser.parse("9:30pm") == 21 * 60 + 30)
        #expect(TimeParser.parse("9:5") == nil && TimeParser.parse("9:") == nil && TimeParser.parse("9:60") == nil)
        #expect(TimeParser.parse(" 12pm ") == 720 && TimeParser.parse("0am") == nil)
    }

    @Test func countdownRoundsUpAndStopsAtZero() {
        let t = Date(timeIntervalSince1970: 1_000_000)
        #expect(Countdown.minutes(from: t, to: t.addingTimeInterval(11 * 60 + 1)) == 12)
        #expect(Countdown.minutes(from: t, to: t.addingTimeInterval(12 * 60)) == 12)
        #expect(Countdown.minutes(from: t, to: t.addingTimeInterval(5)) == 1)
        #expect(Countdown.minutes(from: t, to: t) == 0 && Countdown.minutes(from: t, to: t.addingTimeInterval(-90)) == 0)
    }
}
