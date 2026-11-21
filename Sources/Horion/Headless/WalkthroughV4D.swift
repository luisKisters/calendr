import AppKit
import SwiftUI
import HorionKit

/// PR D tours (v4 Phases 6 and 9) on the v4 fixture: `v4-d-1` the sidebar and the right column's search, `v4-d-2` Today, Join,
/// the useful shortcuts and the dialogs, `v4-d-3` the menu bar's Join row with the call logo.
@MainActor
extension WalkthroughV4 {
    /// Window points (1440 x 900, v4 fixture) of the chrome the tours point at.
    enum ChromePoint {
        /// v11 sidebar: the first group header at y 268 … 292, its rows from 294 in 26 pt steps; the eye at x 213.
        static let account = CGPoint(x: 40, y: 280)
        static func row(_ i: Int) -> CGPoint { CGPoint(x: 90, y: 307 + Double(i) * 26) }
        static func eye(_ i: Int) -> CGPoint { CGPoint(x: 213, y: 307 + Double(i) * 26) }
        static let search = CGPoint(x: 1250, y: 24)
        static func result(_ i: Int) -> CGPoint { CGPoint(x: 1240, y: 92 + Double(i) * 62) }
        static let nowCard = CGPoint(x: 1250, y: 92)
        static let nextCard = CGPoint(x: 1250, y: 222)
        static let settings = CGPoint(x: 64, y: 874)
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
        let pi = acc.calendars.firstIndex { $0.id == personal.id } ?? 0, fi = acc.calendars.firstIndex { $0.id == family.id } ?? 1
        d.say("Hover the group header: a chevron shows")
        probe(d, "acct:\(acc.id)", at: ChromePoint.account, hold: 1.0)
        d.say("Click it: the group folds, its count follows the name")
        d.click(at: ChromePoint.account) { m.toggleGroup(acc.id) }
        d.check(m.collapsedGroups.contains(acc.id) && m.hiddenCalendars.isDisjoint(with: acc.calendars.map(\.id)), "the group folds; its calendars stay shown")
        d.hold(1.0)
        d.click(at: ChromePoint.account) { m.toggleGroup(acc.id) }
        d.check(!m.collapsedGroups.contains(acc.id), "a second click unfolds it")
        d.hold(0.6)
        d.say("Calendar rows: 26 pt, a colour square, the name, an eye on hover")
        probe(d, "cal:\(personal.id)", at: ChromePoint.row(pi), hold: 0.8)
        probe(d, "cal:\(family.id)", at: ChromePoint.row(fi), hold: 0.4)
        d.say("Click the eye to hide a calendar")
        probe(d, "eye:\(family.id)", at: ChromePoint.eye(fi), hold: 0.3)
        d.click(at: ChromePoint.eye(fi)) { m.toggleCalendar(family.id) }
        d.check(m.hiddenCalendars.contains(family.id), "Family is hidden: dimmed, with an eye-slash")
        HoverProbe.shared.target = nil
        d.hold(1.0)
        d.say("The eye-slash stays; click it to show the calendar again")
        d.click(at: ChromePoint.eye(fi)) { m.toggleCalendar(family.id) }
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
            d.moveCursor(to: ChromePoint.result(3), duration: 0.4)
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
        d.say("Later that day: the clock moves to 18:40")
        d.hold(0.6)
        d.play(0.8) { m.setNow(m.math.date(on: m.math.startOfDay(m.now), minutes: 18 * 60 + 40)) }
        d.say("Flat dinner is up next, with its Meet call")
        guard let dinner = m.panelState.today.next, dinner.title == "Flat dinner", CallLink.parse(dinner)?.kind == .meet else {
            d.check(false, "Flat dinner with a Meet call is up next at 18:40 (\(m.panelState.today.next?.title ?? "none"))"); return
        }
        d.check(true, "Flat dinner is up next with a Meet call")
        d.hold(1.2)
        let join = CGPoint(x: 1280, y: m.panelState.today.live == nil ? 172 : 252)
        d.say("Join Google Meet, with the call logo")
        probe(d, "join:\(dinner.id)", at: join, hold: 0.9)
        d.click(at: join) { m.joinCall(dinner) }
        d.check(m.toast?.text == "Opens Google Meet in your browser", "Join opens Google Meet (\(m.toast?.text ?? "no toast"))")
        d.hold(1.0)
        HoverProbe.shared.target = nil
        d.play(0.4) { m.toast = nil }      // the clock stays at 18:40 for the rest of the tour

        // v8 decision C (v5 I): no shortcut list in the right column; the shortcuts stay behind ? and ⌘K.
        d.section("Shortcuts")
        d.check(spot(m, "short:Command menu", fx: 0.3) == nil, "the right column has no shortcut list")
        d.say("The shortcuts stay behind ⌘K and ?", keys: ["\u{2318}", "K"])
        d.play(0.6) { d.key("k", cmd: true) }
        d.check(m.overlay == .command, "⌘K opens the command menu")
        d.hold(1.0)
        d.play(0.4) { d.special("esc") }
        d.check(m.overlay == nil, "Esc closes it")
        d.say("? lists every shortcut", keys: ["?"])
        d.play(0.6) { d.key("?") }
        d.check(m.overlay == .shortcuts, "? opens the keyboard shortcuts")
        d.hold(1.0)
        d.play(0.4) { d.special("esc") }
        d.check(m.overlay == nil, "Esc closes them")
        d.hold(0.6)

        // v5 I: the v11 chrome heights, and the header's right-column button (⌥⌘I, mockup C6).
        d.section("Right column")
        d.check(abs(m.gridState.allDayFrame.minY - (Dim.toolbarHeight + Dim.dayHeaderHeight)) < 0.5,
                "header 48 + day header 32: the all-day lane starts at \(m.gridState.allDayFrame.minY)")
        let wide = m.gridViewport.width
        let toggle = CGPoint(x: 1095, y: 24)
        d.say("The header's right-column button hides the column", keys: ["\u{2325}", "\u{2318}", "I"])
        probe(d, "togRight", at: toggle, hold: 0.3)
        d.click(at: toggle) { m.toggleRightColumn() }
        HoverProbe.shared.target = nil
        d.settle(8)
        d.check(!m.rightColumnVisible && abs(m.gridViewport.width - wide - PanelMetrics.width) < 1, "the grid takes the column's 320 pt")
        d.hold(1.0)
        d.say("⌥⌘I brings it back")
        d.play(0.6) { d.key("i", cmd: true, opt: true) }
        d.settle(8)
        d.check(m.rightColumnVisible && abs(m.gridViewport.width - wide) < 1, "⌥⌘I shows the column again")
        d.hold(0.6)

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

    /// The menu bar menu (drawn as the preview screen, like the other tours): open it, the Join row with the Meet logo, hover and
    /// click Join, then a Zoom event's head row with the Zoom logo.
    static func d3(_ d: Driver, _ m: AppModel) {
        let f = m.fmt
        var backdrop: NSImage?
        var bar: OffscreenWindow?
        func clock() -> String { "\(f.weekdayShort(m.now)) \(m.math.day(m.now)) \(f.monthShort(m.now))  \(f.time(m.now))" }
        func show(_ menu: MenuBarMenuModel, open: Bool, highlight: Int? = nil, join: Bool = false) {
            let v = MenuBarScreenPreview(menu: menu, display: m.settings.menuBarDisplay, clock: clock(), backdrop: backdrop,
                                         highlight: highlight, open: open, joinHover: join)
            if let bar { bar.host.rootView = AnyView(v); bar.settle(4); d.source = bar } else {
                let w = OffscreenWindow(AnyView(v), size: CGSize(width: 1440, height: 900), chrome: false)
                w.settle(6)
                bar = w
                d.source = w
            }
            d.refreshFrame()
        }
        func snapBackdrop() { backdrop = d.win.image(scale: 2).map { NSImage(cgImage: $0, size: NSSize(width: 1440, height: 900)) } }
        let item = CGPoint(x: 1130, y: 15)

        d.section("Menu bar")
        snapBackdrop()
        var menu = m.menuBarMenu
        guard let ji = menu.joinIndex, let jr = menu.joinRow else { d.check(false, "the menu has a Join row"); return }
        d.check(jr.title == "Flat dinner" && jr.call?.kind == .meet && jr.logo == "meet", "Join row: Flat dinner, Google Meet logo")
        d.cursor = CGPoint(x: 900, y: 300)
        show(menu, open: false)
        d.say("The menu bar calendar")
        d.frame(hold: 0.8)
        d.say("Click the item: the native menu opens")
        d.moveCursor(to: item, duration: 0.5)
        d.recordClick()
        d.play(0.3) { show(menu, open: true) }
        d.hold(0.8)
        let rowY = 32 + Double(MenuBarMenuPreview.rowTop(ji, in: menu)) + Double(MenuBarMenu.rowHeight) / 2
        d.say("Today's rows with a call get Join and the call logo")
        d.moveCursor(to: CGPoint(x: 1150, y: rowY), duration: 0.5)
        show(menu, open: true, highlight: ji)
        d.hold(1.4)
        d.say("Hover Join")
        let joinP = CGPoint(x: 1309, y: rowY)
        d.moveCursor(to: joinP, duration: 0.4)
        show(menu, open: true, highlight: nil, join: true)
        d.hold(1.0)
        d.say("Click Join: the menu closes, Horion hands the call to the browser")
        d.recordClick()
        d.play(0.3) { show(menu, open: false) }
        d.source = d.win
        d.play(0.4) { m.joinCall(jr.event) }
        d.check(m.toast?.text == "Opens Google Meet in your browser", "the menu's Join opens Google Meet (\(m.toast?.text ?? "no toast"))")
        d.hold(1.6)
        d.play(0.3) { m.toast = nil }

        d.section("Zoom")
        d.say("Another moment: the clock goes back to Thursday 17:20")
        let thu = m.math.addDays(m.math.startOfDay(m.now), -3)
        d.hold(0.6)
        d.play(0.8) { m.setNow(m.math.date(on: thu, minutes: 17 * 60 + 20)) }
        d.say("Thursday 17:20: Client call on Zoom is next")
        snapBackdrop()
        menu = m.menuBarMenu
        guard menu.joinIndex == 0, let zr = menu.joinRow else { d.check(false, "the head row has Join at 17:20 (\(menu.head?.title ?? "none"))"); return }
        d.check(zr.title == "Client call" && zr.call?.kind == .zoom && zr.logo == "zoom", "head row: Client call with the Zoom logo")
        d.moveCursor(to: item, duration: 0.5)
        d.recordClick()
        d.play(0.3) { show(menu, open: true) }
        d.hold(0.8)
        let headY = 32 + Double(MenuBarMenuPreview.rowTop(0, in: menu)) + Double(MenuBarMenu.rowHeight) / 2
        d.say("The head row: the countdown, Join with the Zoom logo")
        d.moveCursor(to: CGPoint(x: 1309, y: headY), duration: 0.5)
        show(menu, open: true, join: true)
        d.hold(2.0)
        d.endCaption()
    }
}
