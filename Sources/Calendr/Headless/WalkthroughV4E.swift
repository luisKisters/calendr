import AppKit
import SwiftUI
import CalendrKit

/// PR E tours (v4 Phase 8) on the v4 fixture. `v4-e-1`: Allow Contacts fills bare addresses (fake Contacts book) and adds Contacts
/// people to the guest field. Later tours: Settings → Contacts and Accounts, Google replies and updates (fake Google server), People.
@MainActor
extension WalkthroughV4 {
    // MARK: v4-e-1

    static func e1(_ d: Driver, _ m: AppModel) {
        scrollGrid(d, m, to: SnapshotV4.defaultScroll + 9 * DemoDataV4.hourHeight)
        d.settle(4)
        d.section("Names for bare addresses")
        d.say("Flat dinner: two guests are bare addresses")
        guard openOnGrid(d, m, "Flat dinner", day: 6) else { return }
        let e = m.selectedEvent!
        d.check(EditorRows.withoutName(m.displayed(e.attendees)) == 2 && m.services.contacts.access == .notDetermined,
                "2 without a name, Contacts not asked yet")
        d.hold(0.4)
        hoverKey(d, m, "guest:dion.k@example.com", fx: 0.3, hold: 0.5)
        hoverKey(d, m, "guest:sam@example.net", fx: 0.3, hold: 0.4)
        HoverProbe.shared.target = nil
        d.say("Allow Contacts: macOS asks once")
        if let p = spot(m, "namehint", fx: 0.85) {
            probe(d, "namehint", at: p, hold: 0.5)
            d.click(at: p) { HoverProbe.shared.target = nil; m.allowContacts() }
        } else { d.check(false, "the name hint is on screen") }
        d.settle(4)
        d.check(m.services.contacts.isAllowed, "Contacts is allowed")
        let shown = m.displayed(m.selectedEvent!.attendees)
        d.check(EditorRows.withoutName(shown) == 0 && shown.contains { $0.name == "Dion Kraft" } && shown.contains { $0.email == "sam@example.net" && $0.name == "Sam Rivera" },
                "Dion Kraft and Sam Rivera come from Contacts")
        d.check(m.selectedEvent!.attendees.contains { $0.email == "dion.k@example.com" && $0.name == nil }, "the stored guest keeps the bare address")
        d.check(m.toast?.text.hasPrefix("Contacts allowed") == true, "a toast says so")
        d.hold(1.0)
        d.say("Details show the address behind the name")
        if let r = m.panelMenus.frames["guest:dion.k@example.com"] {
            probe(d, "guest:dion.k@example.com", at: CGPoint(x: r.minX + 80, y: r.midY), hold: 0.4)
            d.click(at: CGPoint(x: r.maxX - 13, y: r.midY)) { m.panelMenus.expandedGuest = "\(e.id)|guest:dion.k@example.com" }
        }
        d.settle(3)
        d.hold(1.0)
        HoverProbe.shared.target = nil

        d.section("Guest field")
        d.say("Add participant: Contacts people too")
        if let p = menuSpot(m, .guests, fx: 0.3) { d.click(at: p) { m.focusEditorField(.guest); m.panelMenus.open = .guests } }
        d.settle(3)
        d.type("Kim")
        let s = m.guestSuggestions("Kim")
        d.check(m.panelMenus.open == .guests && s.first?.name == "Kim Lindqvist" && m.peopleSource(s[0]) == .contacts, "Kim Lindqvist, from Contacts")
        d.hold(1.2)
        if let t = s.first { pick(d, m, "menu:guest:\(t.email)", hold: 0.4) { m.addGuest(t) } }
        d.check(m.selectedEvent!.attendees.contains { $0.email == "kim.lindqvist@example.org" }, "Kim is on the list (not sent yet)")
        d.hold(1.2)
        d.endCaption()
    }
}
