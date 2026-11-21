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
        d.say("Allow Contacts (in the real app, macOS asks once)")
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
        d.say("The dot marks a change not sent to the guests yet")
        d.hold(1.6)
        d.endCaption()
    }
}

@MainActor
extension WalkthroughV4 {
    /// A settings page segment (General, Accounts, Contacts) by its share of the switch.
    static func settingsPage(_ d: Driver, _ m: AppModel, _ page: SettingsPage) {
        let fx: Double = switch page { case .general: 0.17; case .accounts: 0.5; case .contacts: 0.83 }
        guard let p = spot(m, "settings:pages", fx: fx) else { d.check(false, "the settings page switch is on screen"); return }
        d.moveCursor(to: p, duration: 0.4)
        d.say(page.title)
        d.click(at: p) { m.services.settingsPage = page }
        d.settle(3)
        d.check(m.services.settingsPage == page, "Settings shows \(page.title)")
    }

    // MARK: v4-e-2

    /// Settings → Contacts (Allow access) and Accounts: Connect Google without a client ID explains what is missing; a demo account
    /// (fake Google server) lists its calendars and hides macOS Calendar's copy; a calendar hidden and shown; Contacts lists its people.
    static func e2(_ d: Driver, _ m: AppModel) {
        d.section("Settings")
        d.say("Settings", keys: ["\u{2318}", ","])
        d.moveCursor(to: CGPoint(x: 720, y: 300))
        d.play(0.5) { d.key(",", cmd: true) }
        d.check(m.overlay == .settings && m.services.settingsPage == .general, "Cmd-, opens Settings on General")
        d.hold(0.6)
        settingsPage(d, m, .contacts)
        d.check(m.services.contacts.access == .notDetermined, "macOS Contacts: not allowed yet")
        d.hold(0.6)
        if let p = spot(m, "settings:contacts", fx: 0.92) {
            d.say("Allow access (in the real app, macOS asks once)")
            d.moveCursor(to: p, duration: 0.4)
            d.click(at: p) { m.allowContacts() }
        }
        d.settle(3)
        d.check(m.services.contacts.isAllowed, "Contacts is allowed")
        d.hold(1.0)
        d.play(0.3) { m.toast = nil }

        d.section("Accounts")
        settingsPage(d, m, .accounts)
        d.check(m.settingsAccounts.count == 3 && m.services.google.accounts.isEmpty, "three accounts through macOS Calendar, no Google account yet")
        d.hold(0.6)
        if let p = spot(m, "settings:connectGoogle", fx: 0.5) {
            d.moveCursor(to: p, duration: 0.5)
            d.click(at: p) { m.connectGoogle() }
        } else { d.check(false, "Connect Google account is on screen") }
        d.settle(4)
        d.say("No client ID in this build: nothing connects")
        d.check(m.services.google.showsClientIDNote && m.services.google.accounts.isEmpty && m.services.google.config.clientID == nil
                && m.toast?.text == "A Google client ID is needed first",
                "no client ID in this build: a toast and a note explain it, nothing connects")
        // `hold` repeats the last frame: let the toast's spring run to the end on video (`animate`), then read it, then let it go
        d.animate(1.0)
        d.hold(1.4)
        d.play(0.6) { m.toast = nil }
        if let p = spot(m, "settings:demoGoogle", fx: 0.5) {
            d.say("Demo mode: a fake Google account, no network")
            d.moveCursor(to: p, duration: 0.6)
            d.hold(0.6)
            d.click(at: p) { m.connectDemoGoogle() }
        } else { d.check(false, "Use demo account is on screen") }
        d.settle(4)
        let g = m.services.google.accounts.first
        d.check(g?.email == "sam.rivera@example.com" && g?.calendarCount == 4, "sam.rivera@example.com connects with 4 calendars")
        d.check(m.hiddenDuplicateAccounts == ["sam.rivera@example.com"], "macOS Calendar's copy of it is hidden")
        d.hold(1.4)
        let family = "google:sam.rivera@example.com/\(DemoDataV4.family)"
        if let p = spot(m, "settings:cal:\(family)", fx: 0.93) {
            d.say("Hide Family, then show it again")
            d.moveCursor(to: p, duration: 0.4)
            d.click(at: p) { m.toggleCalendar(family) }
            d.check(m.hiddenCalendars.contains(family), "Family is hidden")
            d.hold(0.6)
            d.click(at: p) { m.toggleCalendar(family) }
            d.check(!m.hiddenCalendars.contains(family), "Family is shown")
        } else { d.check(false, "the Family row is on screen (\(m.panelMenus.frames.keys.filter { $0.hasPrefix("settings") }.sorted()))") }
        d.hold(0.6)
        settingsPage(d, m, .contacts)
        d.check(!m.services.google.accounts.isEmpty, "Google contacts of sam.rivera@example.com are listed")
        d.hold(1.4)
        d.play(0.4) { d.special("esc") }
        d.check(m.overlay == nil, "Esc closes Settings")
        d.hold(0.6)
        d.endCaption()
    }

    // MARK: v4-e-3

    /// A Google account (fake server): answer an invitation (a PATCH of my own entry), then change an event with guests and send
    /// the update (PATCH with sendUpdates=all). Each write shows the request it made.
    static func e3(_ d: Driver, _ m: AppModel) {
        d.section("Google account")
        d.say("sam.rivera@example.com through the Google API (fake server)")
        m.connectDemoGoogle()
        scrollGrid(d, m, to: SnapshotV4.defaultScroll + 9 * DemoDataV4.hourHeight)
        d.settle(4)
        d.check(m.store.canRespond(calendarID: "google:sam.rivera@example.com/\(DemoDataV4.family)"), "the Google calendars write replies")
        d.hold(0.8)

        d.section("Reply")
        d.say("Family dinner: Nina invited me")
        guard openOnGrid(d, m, "Family dinner", day: 0) else { return }
        let inv = m.selectedEvent!
        d.check(inv.id.hasPrefix("google:") && inv.status == .needsAction && m.canRespond(inv), "a Google invitation, not answered, Going? is live")
        d.hold(0.5)
        if let r = m.panelMenus.frames["row:going"] {
            d.say("Going? Yes")
            d.click(at: CGPoint(x: r.minX + 98, y: r.midY)) { m.setMyReply(.confirmed) }
        } else { d.check(false, "Going? is on screen") }
        waitGoogle(d, m)
        d.check(m.selectedEvent?.status == .confirmed, "my reply is Yes")
        d.check(m.toast?.text.hasPrefix("PATCH /calendars/…/events/w8") == true && m.toast?.text.contains("sendUpdates") == false,
                "a PATCH of my own entry, no update to the guests: \(m.toast?.text ?? "-")")
        d.hold(2.0)

        d.section("Send update")
        d.say("Flat dinner: I organise it, with guests")
        guard openOnGrid(d, m, "Flat dinner", day: 6) else { return }
        if let p = spot(m, "field:title", fx: 0.4) { d.click(at: p) { m.focusEditorField(.title) } }
        d.settle(3)
        d.type("Flat dinner and games")
        d.play(0.3) { d.special("return") }
        d.check(m.selectedUnsent != nil && m.selectedEvent?.title == "Flat dinner and games", "the change waits: Not sent yet")
        d.hold(0.8)
        d.say("Send update: guests get an email", keys: ["\u{2318}", "\u{21A9}"])
        if let p = menuSpot(m, .send, fx: 0.4) {
            probe(d, "split:Send update", at: p, hold: 0.3)
            d.click(at: p) { HoverProbe.shared.target = nil; m.sendUnsent(notify: true) }
        }
        waitGoogle(d, m)
        d.check(m.selectedUnsent == nil && m.toast?.text.hasPrefix("PATCH /calendars/…/events/wg?sendUpdates=all") == true,
                "PATCH … sendUpdates=all: \(m.toast?.text ?? "-")")
        let stored = m.store.searchCorpus(around: m.now).first { $0.id == m.selectedEventID }
        d.check(stored?.title == "Flat dinner and games", "Google has the new title")
        d.hold(2.4)
        d.endCaption()
    }

    /// Lets the fake server's answers come back (they arrive on the run loop).
    static func waitGoogle(_ d: Driver, _ m: AppModel) {
        for _ in 0..<40 where !m.services.google.isIdle { d.settle(1) }
        d.settle(3)
    }
}

@MainActor
extension WalkthroughV4 {
    // MARK: v4-e-4

    /// Google contacts (People API, fake server): a bare address gets its Google name without Contacts, the guest field suggests
    /// Google people (and "other contacts"), then Allow Contacts names the rest (Apple Contacts first, then Google).
    static func e4(_ d: Driver, _ m: AppModel) {
        d.section("Google contacts")
        d.say("A Google account: its contacts come along (People API, fake server)")
        m.connectDemoGoogle()
        d.check(m.services.googlePeople.count >= 10 && m.services.google.accounts.first?.peopleCount == m.services.googlePeople.count,
                "\(m.services.googlePeople.count) people from contacts and other contacts")
        scrollGrid(d, m, to: SnapshotV4.defaultScroll + 9 * DemoDataV4.hourHeight)
        d.settle(4)
        d.hold(0.6)
        d.say("Flat dinner: Google names Dion, one address stays bare")
        guard openOnGrid(d, m, "Flat dinner", day: 6) else { return }
        let shown = m.displayed(m.selectedEvent!.attendees)
        d.check(shown.first { $0.email == "dion.k@example.com" }?.name == "Dion Kraft" && EditorRows.withoutName(shown) == 1 && !m.services.contacts.isAllowed,
                "Dion Kraft from Google contacts, 1 without a name")
        hoverKey(d, m, "guest:dion.k@example.com", fx: 0.3, hold: 0.8)
        HoverProbe.shared.target = nil
        d.hold(0.4)

        d.section("Guest suggestions")
        d.say("Add participant: people you emailed are suggested too")
        if let p = menuSpot(m, .guests, fx: 0.3) { d.click(at: p) { m.focusEditorField(.guest); m.panelMenus.open = .guests } }
        d.settle(3)
        d.type("Pi")
        let s = m.guestSuggestions("Pi")
        d.check(m.panelMenus.open == .guests && s.first?.name == "Pia Neumann" && m.peopleSource(s[0]) == .google, "Pia Neumann, a Google \u{201C}other contact\u{201D}")
        d.say("The G at the end of the row: from Google contacts")
        if let first = s.first, let r = m.panelMenus.frames["menu:guest:\(first.email)"] {
            d.moveCursor(to: CGPoint(x: r.maxX - 18, y: r.midY), duration: 0.4)
        }
        d.hold(1.6)
        if let t = s.first { pick(d, m, "menu:guest:\(t.email)", hold: 0.4) { m.addGuest(t) } }
        d.check(m.selectedEvent!.attendees.contains { $0.email == "pia.neumann@example.net" && $0.name == "Pia Neumann" }, "Pia is added with her name")
        d.say("The dot: not sent to the guests yet")
        d.hold(1.2)

        d.section("Apple Contacts first")
        d.say("Allow Contacts: Apple Contacts names the last bare address")
        if let p = spot(m, "namehint", fx: 0.85) {
            probe(d, "namehint", at: p, hold: 0.4)
            d.click(at: p) { HoverProbe.shared.target = nil; m.allowContacts() }
        } else { d.check(false, "the name hint is on screen") }
        d.settle(4)
        let all = m.displayed(m.selectedEvent!.attendees)
        d.check(EditorRows.withoutName(all) == 0 && all.first { $0.email == "sam@example.net" }?.name == "Sam Rivera", "everyone has a name")
        d.hold(1.6)
        d.endCaption()
    }
}
