import Testing
import Foundation
import CalendrKit
@testable import Calendr

@MainActor
@Suite("Cross-cutting fixes")
struct CrossFixTests {
    @Test func demoModePinsTwentyFourHourMondayWeeks() {
        let m = makeModel()
        #expect(m.use24h && m.fmt.time(DemoData.defaultNow) == "11:48")
        #expect(m.math.calendar.firstWeekday == 2 && m.visibleStart == DemoData.refWeekStart)
    }
    @Test func realModeFollowsTheSystemLocale() {
        var o = LaunchOptions(); o.freezeClock = true; o.now = DemoData.defaultNow
        let m = AppModel(store: DemoStore(), options: o, persist: false)
        #expect(m.use24h == Fmt.uses24h(.current))
        #expect(m.math.calendar.firstWeekday == Calendar.autoupdatingCurrent.firstWeekday)
        #expect(m.math.timeZone == TimeZone.current)
    }
    @Test func savedSystemAppearanceOpensInInk() throws {
        let s = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"appearance":"System"}"#.utf8))
        #expect(s.appearance == .dark)
        #expect(AppearanceSetting.allCases == [.dark, .light])
    }
    @Test func droppedLocaleSettingsAreNotSaved() throws {
        let json = String(decoding: try JSONEncoder().encode(AppSettings()), as: UTF8.self)
        #expect(!json.contains("use24h") && !json.contains("weekStartsOnMonday") && !json.contains("firstVisibleHour"))
        #expect(json.contains("showDeclined") && AppSettings().showDeclined)
    }
    @Test func menuBarBackdropMatchesCSSAngle() {
        // menubar.html `.screen`: linear-gradient(160deg, ...) on 1440 x 900.
        let l = MenuBarScreenPreview.cssLinear(degrees: 160)
        #expect(abs(l.start.x - 0.3411) < 0.001 && abs(l.start.y - -0.1988) < 0.001)
        #expect(abs(l.end.x - 0.6589) < 0.001 && abs(l.end.y - 1.1988) < 0.001)
    }
}
