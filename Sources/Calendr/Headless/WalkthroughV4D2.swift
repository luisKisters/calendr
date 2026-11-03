import AppKit
import SwiftUI
import CalendrKit

/// PR D tours of the v4 editor (Phase 7) on the v4 fixture: `v4-d-4` the rows, the title, reminders, calendar and colour;
/// `v4-d-5` the location with its suggestions and maps menu, the call link and Join, Going? and my own participant row;
/// `v4-d-6` unsent changes with Send update and Discard, and the delete dialog for an event with guests.
@MainActor
extension WalkthroughV4 {
    /// A named frame the editor recorded (`tourAnchor`), as a window point: `fx` across, the middle down.
    static func spot(_ m: AppModel, _ key: String, fx: Double = 0.3, dx: Double = 0) -> CGPoint? {
        guard let r = m.panelMenus.frames[key] else { return nil }
        return CGPoint(x: r.minX + r.width * fx + dx, y: r.midY)
    }
    static func menuSpot(_ m: AppModel, _ menu: PanelMenu, fx: Double = 0.5) -> CGPoint? {
        guard let r = m.panelMenus.frames["menu.\(menu.rawValue)"] else { return nil }
        return CGPoint(x: r.minX + r.width * fx, y: r.midY)
    }

    /// Hovers a named control (forced hover, `HoverProbe`) at its frame.
    static func hoverKey(_ d: Driver, _ m: AppModel, _ key: String, fx: Double = 0.3, hold: Double = 0.45) {
        guard let p = spot(m, key, fx: fx) else { d.check(false, "\(key) is on screen"); return }
        probe(d, key, at: p, hold: hold)
    }

    static func openOnGrid(_ d: Driver, _ m: AppModel, _ title: String, day: Int) -> Bool {
        guard let p = Walkthrough.placed(m, title, day: day) else { d.check(false, "\(title) is on the grid"); return false }
        d.clickGrid(Walkthrough.centerOf(d, p))
        d.settle(3)
        d.check(m.selectedEvent?.title == title, "\(title) opens in the right column")
        return true
    }

    /// Clicks a menu row by its key: the cursor goes there, the row lights up, the action runs.
    static func pick(_ d: Driver, _ m: AppModel, _ key: String, hold: Double = 0.35, _ action: () -> Void) {
        guard let p = spot(m, key, fx: 0.35) else { d.check(false, "menu row \(key)"); return }
        probe(d, key, at: p, hold: hold)
        d.click(at: p) { HoverProbe.shared.target = nil; action() }
    }

    // MARK: v4-d-4

    /// Flat dinner: hover every row. Long run: type a new title, add and remove a reminder, the calendar menu and a colour.
    static func d4(_ d: Driver, _ m: AppModel) {
        scrollGrid(d, m, to: SnapshotV4.defaultScroll + 9 * DemoDataV4.hourHeight)
        d.settle(4)
        d.section("Editor rows")
        d.say("The v4 editor: one row per field")
        guard openOnGrid(d, m, "Flat dinner", day: 6) else { return }
        let rows = EditorRows.rows(m.editorContext(m.selectedEvent!))
        d.check(rows == EditorRow.allCases, "Flat dinner shows every row in order (\(rows.count))")
        d.hold(0.6)
        d.say("Hover each row: fields light up where they can change")
        for k in ["field:title", "field:findTime", "guest:me", "namehint", "joinbig", "field:location", "field:notes", "field:calendar", "rem:10"] {
            hoverKey(d, m, k, fx: k == "joinbig" ? 0.5 : 0.25, hold: 0.2)
        }
        HoverProbe.shared.target = nil

        d.section("Title, reminders, calendar")
        scrollGrid(d, m, to: SnapshotV4.defaultScroll)
        d.settle(4)
        guard openOnGrid(d, m, "Long run", day: 6) else { return }
        d.say("Click the title and type")
        if let p = spot(m, "field:title", fx: 0.4) { d.click(at: p) { m.focusEditorField(.title) } }
        d.settle(3)
        d.type("Sunday long run")
        d.check(m.selectedEvent?.title == "Sunday long run" && m.selectedUnsent == nil, "the title is written (no guests: saved at once)")
        d.play(0.3) { d.special("return") }
        d.hold(0.4)
        d.say("Add reminder: a menu of choices")
        if let p = menuSpot(m, .reminders, fx: 0.25) { d.click(at: p) { m.openPanelMenu(.reminders) } }
        d.check(m.panelMenus.open == .reminders, "Add reminder opens its menu")
        d.hold(0.5)
        pick(d, m, "menu:rem60") { m.toggleReminder(60) }
        d.check(m.selectedEvent?.reminders == [10, 60], "1 hour before is added: \(m.selectedEvent?.reminders ?? [])")
        d.hold(0.6)
        d.say("Remove one: the x on hover")
        if let r = m.panelMenus.frames["rem:10"] {
            probe(d, "rem:10", at: CGPoint(x: r.minX + 60, y: r.midY), hold: 0.4)
            d.click(at: CGPoint(x: r.maxX - 14, y: r.midY)) { m.removeReminder(10) }
        }
        HoverProbe.shared.target = nil
        d.check(m.selectedEvent?.reminders == [60], "10 min before is removed")
        d.hold(0.6)
        d.say("Calendar and colour: one menu, 224 pt")
        if let p = menuSpot(m, .calendar, fx: 0.3) { d.click(at: p) { m.openPanelMenu(.calendar) } }
        d.check(m.panelMenus.open == .calendar, "the calendar menu opens")
        d.hold(0.7)
        hoverKey(d, m, "menu:cal:\(DemoDataV4.family)", hold: 0.4)
        let tomato = EventColors.google[0].hex
        if let p = spot(m, "swatch:\(tomato)", fx: 0.5) {
            d.say("Pick a colour: Tomato")
            d.click(at: p) { m.setSelectedColor(tomato) }
        }
        d.check(m.selectedEvent?.colorHex == tomato, "Long run is Tomato")
        d.hold(0.8)
        d.play(0.3) { d.special("esc") }
        d.check(m.panelMenus.open == nil, "Esc closes the menu")
        d.hold(0.8)
        d.endCaption()
    }

    // MARK: v4-d-5

    /// Reading: type a place and pick a suggestion, the maps menu; add a call, edit its link, Join. Office hours: Going? and my row.
    static func d5(_ d: Driver, _ m: AppModel) {
        scrollGrid(d, m, to: SnapshotV4.defaultScroll)
        d.settle(4)
        d.section("Location")
        guard openOnGrid(d, m, "Reading", day: 2) else { return }
        d.say("Type a place: suggestions as you type")
        if let p = spot(m, "field:location", fx: 0.3) { d.click(at: p) { m.focusEditorField(.place) } }
        d.settle(3)
        d.type("Mark")
        d.check(m.panelMenus.open == .places && m.panelMenus.places.count == 5, "five suggestions for Mark (\(m.panelMenus.places.count))")
        d.hold(0.5)
        pick(d, m, "menu:place:Market Hall", hold: 0.5) { m.pickPlace("Market Hall, 42 Station Road") }
        d.check(m.selectedEvent?.location == "Market Hall, 42 Station Road", "the suggestion fills the location")
        d.hold(0.5)
        d.say("Click the place: Apple Maps, Google Maps, Copy")
        if let p = spot(m, "field:location", fx: 0.3) { d.click(at: p) { m.openPanelMenu(.maps) } }
        d.check(m.panelMenus.open == .maps, "the maps menu opens")
        d.hold(0.4)
        hoverKey(d, m, "menu:apple", hold: 0.4)
        pick(d, m, "menu:google") { m.openMaps(.google) }
        d.check(m.toast?.text == "Opens Google Maps", "Google Maps opens the address")
        d.hold(0.6)

        d.section("Call")
        d.say("Add conferencing: Google Meet")
        if let p = menuSpot(m, .call, fx: 0.25) { d.click(at: p) { m.openPanelMenu(.call) } }
        d.hold(0.5)
        pick(d, m, "menu:meet") { m.addMeet() }
        d.check(CallLink.parse(m.selectedEvent!)?.kind == .meet, "a Meet link is made")
        d.hold(0.5)
        d.say("The link is editable: paste a Zoom link")
        if let p = spot(m, "field:link", fx: 0.3) { d.click(at: p) { m.focusEditorField(.video) } }
        d.settle(3)
        d.type("zoom.us/j/5551234567")
        d.play(0.3) { d.special("return") }
        d.check(CallLink.parse(m.selectedEvent!)?.kind == .zoom, "the call is now Zoom (\(m.selectedEvent?.conferencing ?? ""))")
        d.hold(0.4)
        d.say("Join, with the call logo")
        if let p = spot(m, "joinbig", fx: 0.5) {
            probe(d, "joinbig", at: p, hold: 0.4)
            d.click(at: p) { HoverProbe.shared.target = nil; m.joinCall(m.selectedEvent!) }
        }
        d.check(m.toast?.text == "Opens Zoom in your browser", "Join opens Zoom (\(m.toast?.text ?? "no toast"))")
        d.hold(0.6)

        d.section("Invited")
        d.say("Office hours: Jonas invited me")
        guard openOnGrid(d, m, "Office hours", day: 3) else { return }
        d.check(!m.editorCanEdit(m.selectedEvent!), "an invitation: the shared fields are read-only")
        d.hold(0.5)
        if let r = m.panelMenus.frames["row:going"] {
            d.say("Going? Maybe")
            d.click(at: CGPoint(x: r.minX + 146, y: r.midY)) { m.setMyReply(.tentative) }
        }
        d.check(m.selectedEvent?.myReply == .tentative, "Going? Maybe is written")
        d.hold(0.6)
        d.say("Or from my own row: Going · Maybe · Decline")
        if let r = m.panelMenus.frames["guest:me"] {
            probe(d, "guest:me", at: CGPoint(x: r.minX + 80, y: r.midY), hold: 0.4)
            d.click(at: CGPoint(x: r.maxX - 13, y: r.midY)) { m.panelMenus.expandedGuest = "guest:me" }
        }
        d.settle(3)
        d.hold(0.4)
        if let r = m.panelMenus.frames["guest:me"] {
            d.click(at: CGPoint(x: r.minX + 165, y: r.maxY - 17)) { m.setMyReply(.declined) }
        }
        HoverProbe.shared.target = nil
        d.check(m.selectedEvent?.myReply == .declined, "Decline from my row")
        d.hold(1.0)
        d.endCaption()
    }

    // MARK: v4-d-6

    /// Flat dinner: an edit waits as "Not sent yet"; the split menu; Send update. Another edit, Discard. Delete with guests: the dialog,
    /// its split menu, Cancel.
    static func d6(_ d: Driver, _ m: AppModel) {
        scrollGrid(d, m, to: SnapshotV4.defaultScroll + 9 * DemoDataV4.hourHeight)
        d.settle(4)
        d.section("Unsent changes")
        guard openOnGrid(d, m, "Flat dinner", day: 6) else { return }
        d.say("Flat dinner has guests: edits wait until you send them")
        if let p = spot(m, "field:title", fx: 0.4) { d.click(at: p) { m.focusEditorField(.title) } }
        d.settle(3)
        d.type("Flat dinner and games")
        d.play(0.3) { d.special("return") }
        let id = m.selectedEventID ?? ""
        let stored = { m.store.searchCorpus(around: m.now).first { $0.id == id } }
        d.check(m.selectedUnsent != nil && stored()?.title == "Flat dinner", "the change is held: Not sent yet")
        d.hold(0.8)
        d.say("The split button's menu")
        if let p = menuSpot(m, .send, fx: 0.93) {
            probe(d, "split:send", at: p, hold: 0.3)
            d.click(at: p) { m.openPanelMenu(.send) }
        }
        d.check(m.panelMenus.open == .send, "the menu: Discard changes, Save without sending")
        hoverKey(d, m, "menu:quiet", hold: 0.6)
        d.play(0.3) { HoverProbe.shared.target = nil; d.special("esc") }
        d.say("Send update", keys: ["\u{2318}", "\u{21A9}"])
        if let p = menuSpot(m, .send, fx: 0.4) {
            probe(d, "split:Send update", at: p, hold: 0.3)
            d.click(at: p) { HoverProbe.shared.target = nil; m.sendUnsent(notify: true) }
        }
        d.check(m.selectedUnsent == nil && stored()?.title == "Flat dinner and games" && (m.store as? DemoStore)?.notices.last?.notify == true,
                "Send update writes it and tells the guests")
        d.hold(0.8)

        d.section("Discard")
        d.say("Remove a guest: struck through until sent")
        if let r = m.panelMenus.frames["guest:sam@example.net"] {
            probe(d, "guest:sam@example.net", at: CGPoint(x: r.minX + 80, y: r.midY), hold: 0.4)
            d.click(at: CGPoint(x: r.maxX - 13, y: r.midY)) { m.removeSelectedGuest(email: "sam@example.net", name: nil) }
        }
        HoverProbe.shared.target = nil
        d.check(m.selectedUnsent?.edited.attendees.count == 4, "the guest is removed, not sent yet")
        d.hold(0.6)
        if let p = menuSpot(m, .send, fx: 0.93) { d.click(at: p) { m.openPanelMenu(.send) } }
        pick(d, m, "menu:discard", hold: 0.4) { m.discardUnsent() }
        d.check(m.selectedUnsent == nil && m.selectedEvent?.attendees.count == 5, "Discard puts the guest back")
        d.hold(0.6)

        d.section("Delete with guests")
        d.say("Delete: guests get a cancellation email, or not")
        if let r = m.panelMenus.frames["row:title"] {
            d.click(at: CGPoint(x: r.maxX - 43, y: r.midY - 4)) { m.requestDeleteSelected() }
        }
        d.check(m.overlay == .deleteWithGuests(id), "the delete dialog opens with the guest list")
        d.hold(0.9)
        if let p = menuSpot(m, .deleteSend, fx: 0.88) {
            probe(d, "split:deleteSend", at: p, hold: 0.3)
            d.click(at: p) { m.openPanelMenu(.deleteSend) }
        }
        d.check(m.panelMenus.open == .deleteSend, "the split menu: Delete without cancellation email")
        hoverKey(d, m, "menu:noemail", hold: 0.7)
        HoverProbe.shared.target = nil
        d.play(0.3) { m.closePanelMenu() }
        if let p = spot(m, "btn:Cancel", fx: 0.5) {
            probe(d, "btn:Cancel", at: p, hold: 0.3)
            d.click(at: p) { HoverProbe.shared.target = nil; m.closeOverlay() }
        }
        d.check(m.overlay == nil && stored() != nil, "Cancel keeps the event")
        d.hold(0.9)
        d.endCaption()
    }
}
