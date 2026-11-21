import AppKit
import SwiftUI
import CalendrKit

/// The v4 feature tours (`--walkthrough v4-a --record <mov>`), one per PR of the v4 stack, on the v4 fixture (Sun 4 Oct 2026 15:10).
/// Each is 10-25 s at real speed and asserts every step, like the end-to-end tour (`Walkthrough.tour`).
@MainActor
enum WalkthroughV4 {
    /// Window points of the header's Day / Week / Month segments and of the settings rows (1440x900 window, v4 tokens).
    /// v5 I: the v11 header (48 pt, the right-column button after ‹ Today ›) puts the segments at these centres.
    static let tabs: [(ViewMode, String, CGPoint)] = [(.day, "Day", CGPoint(x: 817, y: 24)), (.week, "Week", CGPoint(x: 863, y: 24)),
                                                      (.month, "Month", CGPoint(x: 917, y: 24))]
    static let weekNumbersOn = CGPoint(x: 975, y: 413)

    /// Brightness (0...1) of the frame at a window point: hover and selection fills change it.
    static func luma(_ d: Driver, at p: CGPoint) -> Double {
        d.settle(2)
        guard let img = d.win.image(scale: 1), let data = img.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return -1 }
        let x = Int(p.x), y = Int(p.y), bpp = img.bitsPerPixel / 8
        let o = y * img.bytesPerRow + x * bpp
        return (Double(bytes[o]) + Double(bytes[o + 1]) + Double(bytes[o + 2])) / (3 * 255)
    }

    /// Mean brightness (0...1) of a segment's label box: v11 hover only turns the label fg1 (no fill).
    static func labelLuma(_ d: Driver, at p: CGPoint) -> Double {
        d.settle(2)
        guard let img = d.win.image(scale: 1), let data = img.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return -1 }
        let bpp = img.bitsPerPixel / 8
        var sum = 0.0, n = 0.0
        for y in Int(p.y) - 5...Int(p.y) + 5 { for x in Int(p.x) - 14...Int(p.x) + 14 {
            let o = y * img.bytesPerRow + x * bpp
            sum += (Double(bytes[o]) + Double(bytes[o + 1]) + Double(bytes[o + 2])) / (3 * 255); n += 1
        } }
        return sum / n
    }

    static func hover(_ d: Driver, _ target: String?, at p: CGPoint) {
        d.moveCursor(to: p, duration: 0.4)
        d.play(0.25) { HoverProbe.shared.target = target }
    }

    /// PR A, the design tokens (v5: the #0B0B0C canvas, Geist text), the one Segmented, grey key hints, the 12 pt dialog surfaces.
    static func a(_ d: Driver, _ m: AppModel) {
        func tab(_ t: String) -> (ViewMode, String, CGPoint) { tabs.first { $0.1 == t }! }

        d.section("v4 tokens")
        d.check(m.viewMode == .week && m.math.day(m.now) == 4 && m.settings.hourHeight == 46, "v4 fixture: the week of Sun 4 Oct, 46 pt hours")
        let bg = InkRGB.dark.bg
        // v5 I: sampled in the day header (the canvas behind the grid), clear of events at any scroll.
        d.check(abs(luma(d, at: CGPoint(x: 740, y: 64)) - (bg.r + bg.g + bg.b) / 3) < 0.003, "the grid background is the v5 canvas (#0B0B0C)")
        d.say("v5 tokens: near-black canvas, Geist, one segmented control")
        d.frame(hold: 1.6)

        d.section("Segmented view switch")
        for name in ["Month", "Day", "Week"] {
            let (mode, title, p) = tab(name)
            d.say("Hover, then click \(title)")
            let before = labelLuma(d, at: p), track = luma(d, at: CGPoint(x: p.x, y: p.y - 9.5))
            hover(d, title, at: p)
            d.check(labelLuma(d, at: p) > before && abs(luma(d, at: CGPoint(x: p.x, y: p.y - 9.5)) - track) < 0.003,
                    "\(title) brightens its label on hover, with no fill")
            d.hold(0.5)
            HoverProbe.shared.target = nil
            d.clickPoint(p, seconds: 0.6)
            d.check(m.viewMode.baseMode == mode, "the \(title) segment switches to \(title)")
            d.hold(name == "Week" ? 0.6 : 1.0)
        }

        d.section("Command menu")
        d.say("Command menu", keys: ["\u{2318}", "K"])
        d.moveCursor(to: CGPoint(x: 720, y: 200))
        d.play(0.5) { d.key("k", cmd: true) }
        d.check(m.overlay == .command, "Cmd-K opens the command menu")
        d.hold(0.6)
        d.say("Type a query")
        d.type("flat")
        d.check(m.chromeState.paletteQuery == "flat" && !m.paletteRows.isEmpty, "the query filters the rows (\(m.paletteRows.count))")
        d.hold(1.2)
        d.play(0.4) { d.special("esc") }
        d.check(m.overlay == nil, "Esc closes the command menu")

        d.section("Settings")
        d.say("Settings", keys: ["\u{2318}", ","])
        d.play(0.6) { d.key(",", cmd: true) }
        d.check(m.overlay == .settings, "Cmd-, opens Settings")
        d.hold(0.6)
        d.say("Every switch is the same segmented control")
        let before = labelLuma(d, at: weekNumbersOn)
        hover(d, "On", at: weekNumbersOn)
        d.check(labelLuma(d, at: weekNumbersOn) > before, "On brightens its label on hover (no fill)")
        d.hold(0.4)
        HoverProbe.shared.target = nil
        d.clickPoint(weekNumbersOn, seconds: 0.5)
        d.check(m.settings.showWeekNumbers, "week numbers are on")
        d.hold(1.2)
        d.say("Esc closes Settings", keys: ["esc"])
        d.play(0.5) { d.special("esc") }
        d.check(m.overlay == nil, "Esc closes Settings")
        d.say("Week numbers in the mini month")
        d.moveCursor(to: CGPoint(x: 30, y: 160), duration: 0.5)
        d.hold(1.4)
        d.endCaption()
    }

    /// PR B, the data model and OverlapV5. What the current UI already shows: an unanswered invitation has no Going? answer,
    /// the call row and Join come from `CallLink`, the organizer counts as accepted, the menu bar's Join comes from the same link.
    static func b(_ d: Driver, _ m: AppModel) {
        d.section("No reply")
        d.check(m.viewMode == .week && m.math.day(m.now) == 4, "v4 fixture: the week of Sun 4 Oct")
        m.gridState.scrollTarget = SnapshotV4.eveningScroll
        m.gridState.scrollTick += 1
        d.settle(8)
        guard let board = Walkthrough.placed(m, "Club board meeting", day: 2) else { d.check(false, "Club board meeting is on Wednesday"); return }
        d.say("v4 data: an invitation Sam has not answered")
        d.clickGrid(Walkthrough.centerOf(d, board))
        guard let e = m.selectedEvent, e.title == "Club board meeting" else { d.check(false, "click selects Club board meeting"); return }
        d.check(e.status == .needsAction && e.myReply == .needsAction && e.isUnaccepted, "Club board meeting: myReply is needsAction")
        d.check(e.organizer?.label == "Nils Bauer" && e.participants == ["Nils Bauer", "ida.sommer@example.org", "Tom Richter"],
                "guests from attendees, Sam left out (Ida's name is only in Contacts)")
        d.hold(0.8)
        d.say("Going? shows no answer yet")
        d.moveCursor(to: CGPoint(x: 1233, y: 304), duration: 0.5)
        d.check(![ResponseStatus.confirmed, .tentative, .declined].contains(m.selectedEvent?.status ?? .confirmed), "no Going? segment is selected")
        d.hold(1.4)

        d.section("Call link")
        let call = CallLink.parse(e)
        d.check(call?.kind == .meet && call?.code == "oet-mzpa-wdr" && call?.display == "meet.google.com/oet-mzpa-wdr", "CallLink: Meet oet-mzpa-wdr")
        d.say("The call row and Join come from the call link")
        d.moveCursor(to: CGPoint(x: 1260, y: 270), duration: 0.5)
        d.hold(0.6)
        d.click(at: CGPoint(x: 1386, y: 270)) { m.joinCall(e) }
        d.check(m.toast?.text == "Opens Google Meet in your browser", "Join opens Google Meet (\(m.toast?.text ?? "no toast"))")
        d.hold(1.4)

        d.section("Organizer")
        guard let dinner = Walkthrough.placed(m, "Flat dinner", day: 6) else { d.check(false, "Flat dinner is on Sunday"); return }
        d.say("Sam organises Flat dinner: it counts as accepted")
        d.clickGrid(Walkthrough.centerOf(d, dinner))
        let fd = m.selectedEvent
        d.check(fd?.title == "Flat dinner" && fd?.iAmOrganizer == true && fd?.myReply == .confirmed && fd?.isUnaccepted == false, "Flat dinner: organizer, accepted")
        d.check(fd?.attendees.contains { $0.status == .needsAction } == true, "a guest of Flat dinner has not answered")
        d.hold(1.4)

        d.section("Menu bar")
        d.play(0.5) { m.toast = nil }      // the Join toast above times out (the frozen clock keeps it otherwise)
        let backdrop = d.win.image(scale: 2).map { NSImage(cgImage: $0, size: NSSize(width: 1440, height: 900)) }
        let menu = m.menuBarMenu
        let f = m.fmt
        let clock = "\(f.weekdayShort(m.now)) \(m.math.day(m.now)) \(f.monthShort(m.now))  \(f.time(m.now))"
        func screen(highlight: Int?, submenu: [MenuBarSubItem]?, sub: Int? = nil) -> AnyView {
            AnyView(MenuBarScreenPreview(menu: menu, display: m.settings.menuBarDisplay, clock: clock, backdrop: backdrop, highlight: highlight,
                                         submenu: submenu, open: true, subHighlight: sub))
        }
        guard let i = menu.rows.firstIndex(where: { $0.title == "Flat dinner" }) else { d.check(false, "Flat dinner is in the menu"); return }
        let row = menu.rows[i].event
        let sub = m.menuBarSubmenu(for: row)
        guard let j = sub.firstIndex(where: { if case .join = $0 { true } else { false } }) else { d.check(false, "Flat dinner menu has Join call"); return }
        d.check(sub[j] == .join(URL(string: "https://meet.google.com/cmv-hjhb-qgb")!), "Flat dinner menu: Join call to its Meet link")
        let bar = OffscreenWindow(screen(highlight: i, submenu: sub), size: CGSize(width: 1440, height: 900), chrome: false)
        bar.settle(6)
        d.source = bar
        d.say("The menu bar's Join call uses the same link")
        d.cursor = CGPoint(x: 1180, y: 32 + Double(MenuBarMenuPreview.rowTop(i, in: menu)) + 11)
        d.frame(hold: 0.6)
        let joinY = Double(MenuBarScreenPreview.submenuItemTop(j, items: sub, row: i, in: menu))
        d.moveCursor(to: CGPoint(x: 940, y: joinY), duration: 0.5)
        bar.host.rootView = screen(highlight: i, submenu: sub, sub: j)
        bar.settle(4)
        d.refreshFrame()
        d.hold(0.8)
        d.say("Click Join call: Google Meet opens")
        d.recordClick()
        d.play(0.2) {}
        d.source = d.win
        d.play(0.4) { m.joinCall(row) }
        d.check(m.toast?.text == "Opens Google Meet in your browser", "the menu's Join call opens Google Meet (\(m.toast?.text ?? "no toast"))")
        d.hold(1.6)

        d.endCaption()
    }
}
