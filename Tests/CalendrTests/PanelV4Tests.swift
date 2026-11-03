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
}
