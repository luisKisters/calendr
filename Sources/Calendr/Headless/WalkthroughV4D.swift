import AppKit
import SwiftUI
import CalendrKit

/// PR D tours (v4 Phases 6 and 9) on the v4 fixture: `v4-d-1` the sidebar and the right column's search, `v4-d-2` Today, Join,
/// the useful shortcuts and the dialogs, `v4-d-3` the menu bar's Join row with the call logo.
@MainActor
extension WalkthroughV4 {
    /// Window points (1440 x 900, v4 fixture) of the chrome the tours point at.
    enum ChromePoint {
        static let account = CGPoint(x: 58, y: 277)
        static let personal = CGPoint(x: 96, y: 306)
        static let family = CGPoint(x: 90, y: 334)
        static let search = CGPoint(x: 1250, y: 28)
        static func result(_ i: Int) -> CGPoint { CGPoint(x: 1240, y: 98 + Double(i) * 62) }
        static let nowCard = CGPoint(x: 1250, y: 142)
        static let nextCard = CGPoint(x: 1250, y: 222)
        static func shortcut(_ i: Int) -> CGPoint { CGPoint(x: 1200, y: 549 + Double(i) * 28) }
        static let settings = CGPoint(x: 64, y: 878)
    }

    static func probe(_ d: Driver, _ target: String?, at p: CGPoint, hold: Double = 0.5) {
        d.moveCursor(to: p, duration: 0.4)
        d.play(0.25) { HoverProbe.shared.target = target }
        d.hold(hold)
    }

    /// Sidebar rows and the account header, a calendar toggled off and on, `/` into the right column's search, a query whose
    /// results replace Today grouped by day, Esc out and Esc to clear.
    static func d1(_ d: Driver, _ m: AppModel) {
        guard let acc = m.store.accounts.first, let family = acc.calendars.first(where: { $0.title == "Family" }),
              let personal = acc.calendars.first(where: { $0.title == "Personal" }) else { d.check(false, "v4 fixture accounts"); return }
        d.section("Sidebar")
        d.check(m.store.accounts.map { AccountName.display($0.name) } == ["sam.rivera", "sam", "sam"], "accounts show their names without the domain")
        d.say("v4 chrome: the sidebar lists calendars by account")
        d.frame(hold: 1.0)
        d.say("Hover the account: its domain shows")
        probe(d, "acct:\(acc.id)", at: ChromePoint.account, hold: 1.2)
        d.say("Calendar rows are 28 pt, text at 40")
        probe(d, "cal:\(personal.id)", at: ChromePoint.personal, hold: 0.8)
        probe(d, "cal:\(family.id)", at: ChromePoint.family, hold: 0.4)
        d.say("Click a calendar to hide it")
        d.click(at: ChromePoint.family) { m.toggleCalendar(family.id) }
        d.check(m.hiddenCalendars.contains(family.id), "Family is hidden")
        d.hold(1.0)
        d.say("Click again to show it")
        d.click(at: ChromePoint.family) { m.toggleCalendar(family.id) }
        d.check(!m.hiddenCalendars.contains(family.id), "Family is shown again")
        d.hold(0.6)
        HoverProbe.shared.target = nil

        d.section("Search")
        d.say("/ focuses the search field on top of the right column", keys: ["/"])
        d.moveCursor(to: ChromePoint.search, duration: 0.5)
        d.play(0.5) { d.key("/") }
        d.check(m.chromeState.searchFocused && m.overlay == nil, "/ focuses the right column's search")
        d.hold(0.5)
        d.say("Type: results replace Today, grouped by day")
        d.type("walk")
        let groups = m.columnResults
        d.check(m.chromeState.columnQuery == "walk" && groups.map { m.math.day($0.day) } == [28, 30, 1, 4], "walk: Mon, Wed, Thu, Sun (\(groups.count) days)")
        d.hold(1.4)
        if let e = groups.last?.events.first {
            d.say("Hover a result")
            probe(d, "row:\(e.id)", at: ChromePoint.result(3), hold: 1.2)
            HoverProbe.shared.target = nil
        }
        d.say("Esc leaves the field, Esc again clears it", keys: ["esc"])
        d.play(0.5) { d.special("esc") }
        d.check(!m.chromeState.searchFocused && m.columnSearching, "the first Esc leaves the field, the results stay")
        d.hold(0.6)
        d.play(0.6) { d.special("esc") }
        d.check(!m.columnSearching && m.chromeState.columnQuery.isEmpty, "the second Esc clears the search: Today is back")
        d.hold(1.2)
        d.endCaption()
    }

    /// Today without frames: hover the cards, Join with the call logo (later in the day), the useful shortcuts, the command menu
    /// from its row, and Settings on the 12 pt pop surface.
    static func d2(_ d: Driver, _ m: AppModel) {
        d.section("Today")
        let t = m.panelState.today
        d.check(t.live?.title == "Test" && t.next?.title == "[P0] Weekly review", "Now: Test, Up next: [P0] Weekly review")
        d.say("Today: no frames, Now and Up next")
        d.frame(hold: 0.8)
        if let live = t.live { probe(d, "card:\(live.id)", at: ChromePoint.nowCard, hold: 0.9) }
        if let next = t.next { probe(d, "card:\(next.id)", at: ChromePoint.nextCard, hold: 0.9) }
        HoverProbe.shared.target = nil

        d.section("Join")
        d.say("At 18:40 Flat dinner is up next, with its Meet call")
        d.play(0.6) { m.setNow(m.math.date(on: m.math.startOfDay(m.now), minutes: 18 * 60 + 40)) }
        guard let dinner = m.panelState.today.next, dinner.title == "Flat dinner", CallLink.parse(dinner)?.kind == .meet else {
            d.check(false, "Flat dinner with a Meet call is up next at 18:40 (\(m.panelState.today.next?.title ?? "none"))"); return
        }
        d.check(true, "Flat dinner is up next with a Meet call")
        d.hold(0.6)
        let join = CGPoint(x: 1280, y: m.panelState.today.live == nil ? 172 : 252)
        d.say("Join Google Meet, with the call logo")
        probe(d, "join:\(dinner.id)", at: join, hold: 0.9)
        d.click(at: join) { m.joinCall(dinner) }
        d.check(m.toast?.text == "Opens Google Meet in your browser", "Join opens Google Meet (\(m.toast?.text ?? "no toast"))")
        d.hold(1.0)
        HoverProbe.shared.target = nil
        d.play(0.4) { m.toast = nil; m.setNow(DemoDataV4.now) }

        d.section("Useful shortcuts")
        d.say("Useful shortcuts under Today")
        let rows = m.usefulShortcuts
        d.check(rows.map(\.title) == Shortcuts.useful.map(\.title), "six useful shortcuts in order")
        for i in [0, 2, 3, 5] { probe(d, "short:\(rows[i].title)", at: ChromePoint.shortcut(i), hold: 0.35) }
        d.say("Each row runs its shortcut: Command menu")
        probe(d, "short:\(rows[0].title)", at: ChromePoint.shortcut(0), hold: 0.3)
        d.clickPoint(ChromePoint.shortcut(0), seconds: 0.6)
        HoverProbe.shared.target = nil
        d.check(m.overlay == .command, "the Command menu row opens the command menu")
        d.hold(1.2)
        d.play(0.4) { d.special("esc") }
        d.check(m.overlay == nil, "Esc closes it")

        d.section("Settings")
        d.say("Settings: the 12 pt pop surface")
        probe(d, "settings", at: ChromePoint.settings, hold: 0.4)
        d.clickPoint(ChromePoint.settings, seconds: 0.6)
        HoverProbe.shared.target = nil
        d.check(m.overlay == .settings, "the sidebar foot opens Settings")
        d.hold(1.4)
        d.play(0.5) { d.special("esc") }
        d.check(m.overlay == nil, "Esc closes Settings")
        d.hold(0.4)
        d.endCaption()
    }
}
