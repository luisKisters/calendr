import Testing
import Foundation
import CalendrKit
@testable import Calendr

/// v4 Phase 7: the editor's rows, reminders, menus, unsent changes, Send / Save without sending / Discard, delete with guests.
@MainActor
@Suite("v4 editor")
struct PanelV4Tests {
    func open(_ m: AppModel, _ id: String) -> CalendarEvent {
        let e = m.event(id: "v4.\(id)")!
        m.select(eventID: e.id)
        return e
    }
    func store(_ m: AppModel) -> DemoStore { m.store as! DemoStore }
    func stored(_ m: AppModel, _ id: String) -> CalendarEvent? { m.store.searchCorpus(around: m.now).first { $0.id == id } }

    @Test func bufferedEditDoesNotReachTheStoreBeforeSend() {
        let m = makeModelV4()
        let e = open(m, "wg")
        #expect(m.buffersUpdates(e))
        m.setSelectedTitle("Flat dinner and games")
        #expect(m.selectedEvent?.title == "Flat dinner and games" && m.selectedUnsent != nil)
        #expect(stored(m, e.id)?.title == "Flat dinner" && store(m).notices.isEmpty)
        // the grid shows the held change too
        #expect(m.layout.timed[6].contains { $0.event.title == "Flat dinner and games" })
    }

    @Test func sendNotifiesAndSaveWithoutSendingDoesNot() {
        let m = makeModelV4()
        let e = open(m, "wg")
        m.setLocationText("Market Hall, 42 Station Road")
        m.sendUnsent(notify: true)
        #expect(stored(m, e.id)?.location == "Market Hall, 42 Station Road" && m.selectedUnsent == nil)
        #expect(store(m).notices.last.map { $0.id == e.id && $0.kind == "update" && $0.notify } == true)
        m.setSelectedTitle("Dinner")
        m.sendUnsent(notify: false)
        #expect(stored(m, e.id)?.title == "Dinner")
        #expect(store(m).notices.last.map { $0.kind == "update" && !$0.notify } == true)
    }

    @Test func discardRestoresTheEvent() {
        let m = makeModelV4()
        let e = open(m, "wg")
        m.removeSelectedGuest(email: "sam@example.net", name: nil)
        m.removeCall()
        #expect(m.selectedEvent?.attendees.count == 4 && m.selectedEvent?.conferencing.isEmpty == true)
        m.discardUnsent()
        #expect(m.selectedUnsent == nil && m.selectedEvent == stored(m, e.id) && m.selectedEvent?.attendees.count == 5)
        #expect(store(m).notices.isEmpty)
    }

    @Test func myOwnFieldsAreWrittenAtOnceUnderAHeldChange() {
        let m = makeModelV4()
        let e = open(m, "wg")
        m.setSelectedTitle("Held")
        m.toggleReminder(60)
        m.setSelectedColor(nil)
        let s = stored(m, e.id)!
        #expect(s.reminders == [10, 60] && s.colorHex == nil && s.title == "Flat dinner")
        #expect(m.selectedEvent?.title == "Held" && m.selectedEvent?.reminders == [10, 60])
    }

    @Test func eventKitSavesAtOnce() {
        let m = makeModelV4()
        store(m).canSendUpdates = false
        let e = open(m, "wg")
        #expect(!m.buffersUpdates(e))
        m.setSelectedTitle("Saved")
        #expect(stored(m, e.id)?.title == "Saved" && m.selectedUnsent == nil)
    }

    @Test func remindersStayUniqueAndSorted() {
        let m = makeModelV4()
        _ = open(m, "c3")
        m.toggleReminder(1440); m.toggleReminder(0); m.toggleReminder(30)
        #expect(m.selectedEvent?.reminders == [0, 10, 30, 1440])
        m.updateSelected { $0.reminders = [30, 5, 30, 5] }
        #expect(m.selectedEvent?.reminders == [5, 30])
        m.toggleReminder(5); m.removeReminder(30)
        #expect(m.selectedEvent?.reminders.isEmpty == true)
    }

    @Test func deleteWithGuestsOpensTheDialog() {
        let m = makeModelV4()
        let e = open(m, "wg")
        m.requestDeleteSelected()
        #expect(m.overlay == .deleteWithGuests(e.id) && stored(m, e.id) != nil)
        m.openPanelMenu(.deleteSend)
        m.deleteWithGuests(e.id, notify: false)
        #expect(stored(m, e.id) == nil && m.overlay == nil && m.panelMenus.open == nil)
        #expect(store(m).notices.last.map { $0.kind == "delete" && !$0.notify } == true)
    }

    @Test func deleteWithoutGuestsKeepsTheCurrentFlow() {
        let m = makeModelV4()
        let e = open(m, "a1")      // Deep work: no guests
        m.requestDeleteSelected()
        #expect(m.overlay == nil && stored(m, e.id) == nil && m.toast?.undo == true)
        // EventKit cannot choose: no dialog either
        let k = makeModelV4()
        (k.store as! DemoStore).canSendUpdates = false
        let w = open(k, "wg")
        k.requestDeleteSelected()
        #expect(k.overlay == nil && stored(k, w.id) == nil)
    }

    @Test func goingIsReadOnlyWithoutRSVP() {
        let m = makeModelV4()
        let e = open(m, "d4")       // invited by Jonas
        #expect(!m.editorCanEdit(e) && EditorRows.rows(m.editorContext(e)).contains(.going))
        m.setMyReply(.tentative)
        #expect(stored(m, e.id)?.status == .tentative && m.selectedUnsent == nil)
        store(m).canRespond = false
        m.setMyReply(.declined)
        #expect(stored(m, e.id)?.status == .tentative)
    }

    @Test func locationSuggestionsUseTheFakeCompleterAndTheMapsLinks() {
        let m = makeModelV4()
        _ = open(m, "c3")
        m.searchPlaces("Mark")
        #expect(m.panelMenus.open == .places && m.panelMenus.places.count == 5)
        m.pickPlace(m.panelMenus.places[4].text)
        #expect(m.selectedEvent?.location == "Market Hall, 42 Station Road" && m.panelMenus.open == nil)
        m.openPanelMenu(.maps)
        m.openMaps(.google)
        #expect(m.toast?.text == "Opens Google Maps" && m.panelMenus.open == nil)
    }

    @Test func calendarAndColour() {
        let m = makeModelV4()
        let e = open(m, "wg")
        m.setSelectedCalendar(DemoDataV4.family)
        m.setSelectedColor(EventColors.google[0].hex)
        let s = stored(m, e.id)!
        #expect(s.calendarID == DemoDataV4.family && s.colorHex == "#D9443A" && m.selectedUnsent == nil)
    }

    @Test func meetNotesStayHiddenWhenEditing() {
        let m = makeModelV4()
        let e = open(m, "wg")
        store(m).canSendUpdates = false
        m.setSelectedNotes("Bring plates.")
        let n = stored(m, e.id)!.notes
        #expect(MeetNotes.visible(n) == ("Bring plates.", true) && n.contains("meet.google.com/cmv-hjhb-qgb"))
    }

    @Test func sendShortcutSendsTheHeldChange() {
        let m = makeModelV4()
        let e = open(m, "wg")
        #expect(!m.sendShortcut())
        m.setSelectedTitle("Sent")
        #expect(m.sendShortcut() && stored(m, e.id)?.title == "Sent" && store(m).notices.last?.notify == true)
    }

    @Test func newEventMeetLinkIsMadeOnSave() {
        let m = makeModelV4()
        let s = m.math.date(on: m.math.addDays(DemoDataV4.weekStart, 5), minutes: 18 * 60)
        let d = m.createEvent(start: s, end: s.addingTimeInterval(3600))!
        m.setSelectedTitle("Talk rehearsal")
        m.addMeet()
        #expect(m.panelState.newMeet.contains(d.id) && m.selectedEvent?.conferencing.isEmpty == true)
        m.saveDraft()
        let saved = stored(m, d.id)!
        #expect(CallLink.parse(saved)?.kind == .meet && m.panelState.newMeet.isEmpty)
    }

    // MARK: Review fixes

    @Test func aFailedSendKeepsTheHeldChange() {
        let m = makeModelV4()
        let e = open(m, "wg")
        m.setSelectedTitle("Kept")
        store(m).failWrites = true
        m.sendUnsent(notify: true)
        #expect(m.selectedUnsent?.edited.title == "Kept" && stored(m, e.id)?.title == "Flat dinner")
        m.requestDeleteSelected()
        m.deleteWithGuests(e.id, notify: true)
        #expect(m.selectedUnsent != nil && stored(m, e.id) != nil)
        store(m).failWrites = false
        m.overlay = nil
        m.sendUnsent(notify: true)
        #expect(m.selectedUnsent == nil && stored(m, e.id)?.title == "Kept")
    }

    @Test func gridDragAndNudgeWaitWithTheHeldChange() {
        let m = makeModelV4()
        let e = open(m, "wg")
        m.nudgeSelected(dx: 0, dy: 1)
        #expect(m.selectedUnsent != nil && stored(m, e.id)?.start == e.start && store(m).notices.isEmpty)
        #expect(m.selectedEvent.map { m.fmt.time($0.start) } == "19:15")
        // a drag on the grid: the same hold
        let k = makeModelV4()
        let w = open(k, "wg")
        let p = k.layout.timed[6].first { $0.event.id == w.id }!
        let r = k.gridGeometry.rect(for: p)
        let a = CGPoint(x: r.midX, y: r.minY + 10), b = CGPoint(x: r.midX, y: r.minY + 10 + k.gridGeometry.hourHeight)
        k.gridMouseDown(a); k.gridMouseDragged(CGPoint(x: a.x, y: a.y + 20)); k.gridMouseDragged(b); k.gridMouseUp(b)
        #expect(k.panelState.unsent[w.id] != nil && stored(k, w.id)?.start == w.start && store(k).notices.isEmpty)
        #expect(k.event(id: w.id).map { k.fmt.time($0.start) } == "20:00")
    }

    @Test func recurringDeleteWithGuestsLetsYouSkipTheEmail() {
        let m = makeModelV4()
        let base = m.event(id: "v4.wg")!
        var next = base
        next.id = "v4.wg.next"; next.start = m.math.addDays(base.start, 7); next.end = m.math.addDays(base.end, 7)
        _ = try? m.store.create(next)
        m.storeChanged()
        m.select(eventID: base.id)
        m.requestDeleteSelected()
        #expect(m.overlay == .deleteRecurring(base.id))
        m.deleteRecurring(base.id, span: .all, notify: false)
        #expect(stored(m, base.id) == nil && stored(m, next.id) == nil)
        #expect(store(m).notices.last.map { $0.kind == "delete" && !$0.notify } == true)
    }

    @Test func saveWithoutSendingInviteDoesNotNotify() {
        let m = makeModelV4()
        let s = m.math.date(on: m.math.addDays(DemoDataV4.weekStart, 5), minutes: 18 * 60)
        let d = m.createEvent(start: s, end: s.addingTimeInterval(3600))!
        m.updateSelected { $0.attendees = [Attendee(email: "sam.rivera@example.com", isOrganizer: true, isMe: true), Attendee(email: "theo.park@example.com")] }
        m.saveDraft(notify: false)
        #expect(stored(m, d.id) != nil && store(m).notices.last.map { $0.kind == "create" && !$0.notify } == true)
    }

    @Test func menuBarRepliesUseTheEditorGuards() {
        let m = makeModelV4()
        let mine = m.event(id: "v4.wg")!          // I organise it: nothing to answer
        m.setResponse(.declined, for: mine)
        #expect(stored(m, mine.id)?.status == .confirmed)
        let invite = m.event(id: "v4.d4")!
        m.setResponse(.tentative, for: invite)
        #expect(stored(m, invite.id)?.status == .tentative)
        store(m).canRespond = false
        m.setResponse(.declined, for: invite)
        #expect(stored(m, invite.id)?.status == .tentative)
    }

    @Test func editorStateDoesNotCarryOverToAnotherEvent() {
        let m = makeModelV4()
        let wg = open(m, "wg")
        m.panelMenus.expandedGuest = "\(wg.id)|guest:me"
        m.panelMenus.guestQuery = "the"
        m.searchPlaces("Mark")
        m.openPanelMenu(.places)
        let other = open(m, "c2")
        #expect(m.panelMenus.open == nil && m.panelMenus.expandedGuest == nil && m.panelMenus.guestQuery.isEmpty)
        #expect(m.panelMenus.places.isEmpty && m.panelMenus.placeQuery.isEmpty && !m.panelMenus.pastingLink)
        #expect(stored(m, other.id)?.location.isEmpty == true)
    }

    @Test func removingACallTakesItOutOfNotesAndLocation() {
        let m = makeModelV4()
        let e = open(m, "c2")       // Reading: no guests
        m.updateSelected { $0.notes = "Bring the book.\nCall: https://zoom.us/j/5551234 (backup)"; $0.location = "Online, teams.microsoft.com/l/meetup-join/abc" }
        #expect(CallLink.parse(m.selectedEvent!)?.kind == .zoom)
        m.removeCall()
        let s = stored(m, e.id)!
        #expect(CallLink.parse(s) == nil && s.notes.hasPrefix("Bring the book.") && s.location == "Online")
    }
}
