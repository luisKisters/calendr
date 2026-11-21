import Testing
import Foundation
@testable import HorionKit

/// v4 Phase 6, kit part (v5 I): the chrome's shortcuts and the sidebar's account names.
@Suite("Chrome v4 kit")
struct ChromeV4KitTests {
    @Test func theChromeShortcutsResolve() {
        // v5 I: the right column's shortcut list is gone (v8 decision C); these keys stay, plus ⌥⌘I (right column) and ⌘J (Join).
        let r = { (k: KeyInput) in ShortcutResolver.resolve(k, textFocused: false) }
        #expect(r(KeyInput(characters: "i", command: true, option: true)) == .toggleRightColumn)
        #expect(r(KeyInput(characters: "i", command: true, option: true, shift: true)) == nil)
        #expect(r(KeyInput(characters: "j", command: true)) == .joinCall)
        #expect(r(KeyInput(characters: "k", command: true)) == .commandMenu)
        #expect(r(KeyInput(characters: "f")) == .meetWith)
        #expect(r(KeyInput(characters: "c")) == .createEvent)
        #expect(r(KeyInput(characters: "k", command: true, control: true)) == .menuBarCalendar)
        #expect(r(KeyInput(characters: "`")) == .toggleSidebar)
        #expect(r(KeyInput(characters: "?", shift: true)) == .showShortcuts)
    }

    @Test func accountNameDropsTheDomain() {
        #expect(AccountName.display("sam@northwind.example") == "sam")
        #expect(AccountName.display("sam.rivera@example.com") == "sam.rivera")
        #expect(AccountName.display("Work") == "Work")
        #expect(AccountName.display("@odd") == "@odd")
    }
}
