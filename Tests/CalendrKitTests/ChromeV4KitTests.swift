import Testing
import Foundation
@testable import CalendrKit

/// v4 Phase 6, kit part: the right column's useful shortcuts and the sidebar's account names.
@Suite("Chrome v4 kit")
struct ChromeV4KitTests {
    @Test func usefulShortcutsAreTheSixInOrder() {
        #expect(Shortcuts.useful.map(\.title) == ["Command menu", "Meet with", "New event", "Menu bar calendar", "Toggle sidebar", "All keyboard shortcuts"])
        #expect(Shortcuts.useful.map(\.keys) == [["\u{2318}", "K"], ["F"], ["C"], ["\u{2303}", "\u{2318}", "K"], ["`"], ["?"]])
        #expect(Shortcuts.useful.map(\.action) == [.commandMenu, .meetWith, .createEvent, .menuBarCalendar, .toggleSidebar, .showShortcuts])
    }

    @Test func eachUsefulShortcutIsWhatItsKeysDo() {
        // The hint must be true: the keys resolve to the row's action.
        let r = { (k: KeyInput) in ShortcutResolver.resolve(k, textFocused: false) }
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
