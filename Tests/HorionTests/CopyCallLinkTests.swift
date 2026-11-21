import Testing
import Foundation
import AppKit
import HorionKit
@testable import Horion

/// design/call-link round 3: Copy next to the call link and beside Join on the Up next card. Plain text, no toast.
@MainActor
@Suite("Copy call link")
struct CopyCallLinkTests {
    func board() -> NSPasteboard { let p = NSPasteboard(name: .init("horion.tests.copy-call-link")); p.clearContents(); return p }

    func withCall(_ m: AppModel, _ link: String) -> CalendarEvent {
        let e = m.event(id: "v4.c2")!
        m.select(eventID: e.id)
        m.updateSelected { $0.conferencing = link }
        return m.selectedEvent!
    }

    @Test func copiesTheCallURLAsPlainText() {
        let m = makeModelV4(), pb = board()
        let e = withCall(m, "  https://meet.google.com/kpd-tzwx-qmf \n")
        #expect(m.copyCallLink(e, to: pb))
        #expect(pb.string(forType: .string) == "https://meet.google.com/kpd-tzwx-qmf")
        #expect(pb.types?.contains(.string) == true && pb.types?.contains(.URL) != true && pb.types?.contains(.rtf) != true)
    }

    @Test func noToastTheButtonShowsTheCheck() {
        let m = makeModelV4(), pb = board()
        let e = withCall(m, "https://zoom.us/j/84512093377")
        m.copyCallLink(e, to: pb)
        #expect(m.toast == nil)
        #expect(CopyLinkButton.feedback == 1.5)
    }

    @Test func defaultsToTheSelectedEvent() {
        let m = makeModelV4(), pb = board()
        _ = withCall(m, "https://teams.microsoft.com/l/meetup-join/abc")
        #expect(m.copyCallLink(to: pb))
        #expect(pb.string(forType: .string)?.hasPrefix("https://teams.microsoft.com/") == true)
    }

    @Test func aWebLinkThatIsNotACallIsCopiedAsTyped() {
        let m = makeModelV4(), pb = board()
        let e = withCall(m, " example.com/agenda ")
        #expect(CallLink.parse(e) == nil)
        #expect(m.copyCallLink(e, to: pb) && pb.string(forType: .string) == "example.com/agenda")
    }

    @Test func nothingToCopyLeavesThePasteboardAlone() {
        let m = makeModelV4(), pb = board()
        pb.setString("keep", forType: .string)
        let e = withCall(m, "   ")
        #expect(!m.copyCallLink(e, to: pb))
        #expect(pb.string(forType: .string) == "keep")
    }

    @Test func headlessRunsNeverTouchTheGeneralPasteboard() {
        let m = makeModelV4()
        let e = withCall(m, "https://meet.google.com/kpd-tzwx-qmf")
        let before = NSPasteboard.general.changeCount
        #expect(m.copyCallLink(e))
        #expect(NSPasteboard.general.changeCount == before)
    }
}
