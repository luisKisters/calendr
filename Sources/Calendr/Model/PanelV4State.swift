import Foundation
import AppKit
import MapKit
import CalendrKit

/// The editor's menus (design/mockup-v4 `popHTML`): one open at a time, drawn by `PanelMenuLayer` over the window and anchored to
/// the control that opened it.
enum PanelMenu: String, Hashable, CaseIterable {
    case calendar, reminders, maps, places, call, guests, send, inviteSend, deleteSend
}

/// Edits to an event with guests that are not sent yet (v4 Phase 7b): `base` is what the store has, `edited` what the editor shows.
struct UnsentEdit: Equatable {
    var base: CalendarEvent
    var edited: CalendarEvent
}

/// The open menu and the frames of the controls menus anchor to. A class of its own so that frames changing while the column scrolls
/// re-render only the menu layer, not every view that reads `panelState`.
@MainActor @Observable
final class PanelMenuState {
    var open: PanelMenu?
    /// The location field's suggestions (`places` menu).
    var places: [PlaceSuggestion] = []
    /// The text the suggestions are for.
    var placeQuery = ""
    /// Place search: MapKit's completer in the app, the demo list in demo mode, snapshots and tests (no network).
    var completer: PlaceCompleting?
    /// The guest field's text (`guests` menu).
    var guestQuery = ""
    /// The participant row that shows its details (my own: Going · Maybe · Decline).
    var expandedGuest: String?
    /// "Paste a link…" was chosen: the call row shows a link field.
    var pastingLink = false

    /// Frames (window points, top-left origin) of the editor's rows and controls by name: "menu.<menu>" for the control a menu
    /// opens from, the rest for the walkthrough to point at. Written by `PanelMenuLayer` from the anchor preferences; not observed.
    @ObservationIgnored var frames: [String: CGRect] = [:]
    /// A field the editor should focus (the walkthrough, and "Paste a link…").
    var focusRequest: PanelFocus?
    var focusTick = 0
}

/// Place search behind a protocol, so tests and snapshots never reach the network.
@MainActor
protocol PlaceCompleting: AnyObject {
    var onResults: (([PlaceSuggestion]) -> Void)? { get set }
    func search(_ query: String)
}

/// The demo places (mockup `PLACES`), answered at once.
@MainActor
final class DemoPlaceCompleter: PlaceCompleting {
    var onResults: (([PlaceSuggestion]) -> Void)?
    func search(_ query: String) { onResults?(PlaceSuggestion.filter(PlaceSuggestion.demo, query)) }
}

/// `MKLocalSearchCompleter` (MapKit is a system framework): addresses and places as you type.
@MainActor
final class MapKitPlaceCompleter: NSObject, PlaceCompleting, MKLocalSearchCompleterDelegate {
    var onResults: (([PlaceSuggestion]) -> Void)?
    private let completer = MKLocalSearchCompleter()
    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }
    func search(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.count < 2 { completer.cancel(); onResults?([]); return }
        completer.queryFragment = q
    }
    nonisolated func completerDidUpdateResults(_ c: MKLocalSearchCompleter) {
        let list = c.results.prefix(5).map { PlaceSuggestion(title: $0.title, subtitle: $0.subtitle) }
        MainActor.assumeIsolated { onResults?(Array(list)) }
    }
    nonisolated func completer(_ c: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated { onResults?([]) }
    }
}

/// The v4 editor: what may change, menus, the location, the call, reminders, colour, replies, unsent changes and the delete dialog.
extension AppModel {
    // MARK: What may change

    /// The shared fields (title, time, guests, call, place, notes) change only on a writable calendar, and only for the organizer when
    /// the event has one (an invitation: my reply, reminders, colour and calendar stay mine).
    func editorCanEdit(_ e: CalendarEvent) -> Bool {
        isWritable(e) && (e.organizer == nil || e.iAmOrganizer)
    }

    func editorContext(_ e: CalendarEvent) -> EditorContext {
        EditorContext(e, canEdit: editorCanEdit(e), isDraft: draft?.id == e.id)
    }

    /// Edits to an event I organise with guests wait for "Send update" when the store can send updates (Google). EventKit saves at once.
    func buffersUpdates(_ e: CalendarEvent) -> Bool {
        store.canSendUpdates && e.iAmOrganizer && e.attendees.contains { !$0.isMe } && draft?.id != e.id
    }

    /// The store writes my reply (Google). EventKit shows Going? read-only.
    var canRespond: Bool { store.canRespond }

    // MARK: Menus

    func openPanelMenu(_ m: PanelMenu) {
        panelMenus.open = panelMenus.open == m ? nil : m
    }
    func closePanelMenu() { panelMenus.open = nil }

    /// Moves the keyboard to an editor field.
    func focusEditorField(_ f: PanelFocus) { panelMenus.focusRequest = f; panelMenus.focusTick += 1 }

    // MARK: Unsent changes

    var selectedUnsent: UnsentEdit? { selectedEventID.flatMap { panelState.unsent[$0] } }

    /// Called by `updateSelected`: keeps a change to the shared fields in the editor until it is sent. My own fields (reminders,
    /// colour, calendar, reply) are written at once, under the held change. Returns false when the change is not held.
    func holdUnsent(before: CalendarEvent, after e: CalendarEvent) -> Bool {
        let held = panelState.unsent[e.id]
        guard held != nil || (buffersUpdates(e) && EditorRows.sharedChanged(before, e)) else { return false }
        let base = held?.base ?? before
        let mine = EditorRows.personal(of: e, onto: base)
        panelState.unsent[e.id] = EditorRows.sharedChanged(base, e) ? UnsentEdit(base: mine, edited: e) : nil
        if mine != base {
            flushPendingEdit()
            commit(mine, span: .this, old: nil)
        } else {
            reload()
        }
        return true
    }

    /// Send update (notify) or Save without sending: the held change goes to the store.
    func sendUnsent(notify: Bool) {
        guard let id = selectedEventID, let u = panelState.unsent[id] else { return }
        closePanelMenu()
        panelState.unsent[id] = nil
        do {
            try store.update(u.edited, span: .this, notify: notify)
            showToast(notify ? "Update sent" : "Saved without sending")
        } catch { showToast("Could not save event") }
        storeChanged()
    }

    /// Discard: the event goes back to what the store has.
    func discardUnsent() {
        guard let id = selectedEventID, panelState.unsent[id] != nil else { return }
        closePanelMenu()
        panelState.unsent[id] = nil
        storeChanged()
    }

    /// ⌘↩: send the held change, or save (and invite) the event being created.
    func sendShortcut() -> Bool {
        if selectedUnsent != nil { sendUnsent(notify: true); return true }
        if isDraftOpen { saveDraft(); return true }
        return false
    }

    // MARK: Delete with guests

    /// Deleting an event I organise with guests asks first: guests get a cancellation email, or not.
    func deleteNeedsGuestDialog(_ e: CalendarEvent) -> Bool {
        store.canSendUpdates && e.iAmOrganizer && e.attendees.contains { !$0.isMe }
    }

    func deleteWithGuests(_ id: String, notify: Bool) {
        closePanelMenu()
        guard let e = event(id: id) else { overlay = nil; return }
        panelState.unsent[id] = nil
        delete(e, span: .this, notify: notify)
    }

    // MARK: Fields

    func setSelectedTitle(_ t: String) { updateSelected { $0.title = t } }

    /// The notes as typed: Google's Meet block stays at the end, hidden.
    func setSelectedNotes(_ text: String) { updateSelected { $0.notes = MeetNotes.replacingVisible(in: $0.notes, with: text) } }

    func toggleReminder(_ m: Int) { updateSelected { $0.reminders = Reminders.toggled($0.reminders, m) } }
    func removeReminder(_ m: Int) { updateSelected { $0.reminders.removeAll { $0 == m } } }

    func setSelectedCalendar(_ id: String) { updateSelected { $0.calendarID = id } }
    /// Nil: the calendar's colour.
    func setSelectedColor(_ hex: String?) { updateSelected { $0.colorHex = hex } }

    /// My reply (Going? or my own participant row). Not an update to send: Google patches my entry only.
    func setMyReply(_ s: ResponseStatus) {
        guard canRespond, let e = selectedEvent, !e.iAmOrganizer else { return }
        updateSelected { $0.status = s }
    }

    // MARK: Location

    func setLocationText(_ text: String) {
        updateSelected { $0.location = text }
        searchPlaces(text)
    }

    func searchPlaces(_ text: String) {
        if panelMenus.completer == nil { panelMenus.completer = store is DemoStore ? DemoPlaceCompleter() : MapKitPlaceCompleter() }
        panelMenus.placeQuery = text
        panelMenus.completer?.onResults = { [weak self] list in
            guard let self, self.panelMenus.placeQuery == text else { return }
            self.panelMenus.places = list
            if !list.isEmpty { self.panelMenus.open = .places } else if self.panelMenus.open == .places { self.panelMenus.open = nil }
        }
        panelMenus.completer?.search(text)
    }

    func pickPlace(_ text: String) {
        panelMenus.places = []
        panelMenus.placeQuery = text
        closePanelMenu()
        updateSelected { $0.location = text }
        blurTick += 1
    }

    enum MapsApp { case apple, google }
    func openMaps(_ app: MapsApp) {
        closePanelMenu()
        guard let loc = selectedEvent?.location, let url = app == .apple ? MapLinks.apple(loc) : MapLinks.google(loc) else { return }
        if !opensOutside { showToast(app == .apple ? "Opens Apple Maps" : "Opens Google Maps"); return }
        NSWorkspace.shared.open(url)
    }

    func copyLocation() {
        closePanelMenu()
        guard let loc = selectedEvent?.location, !loc.isEmpty else { return }
        copyToPasteboard(loc)
        showToast("Copied address")
    }

    /// Headless runs and unit tests (no application object) never open other apps or touch the pasteboard.
    var opensOutside: Bool { !options.isHeadless && NSApp != nil }

    func copyToPasteboard(_ s: String) {
        guard opensOutside else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    // MARK: Call

    /// Google Meet for a new event: the link is made when it is saved (demo store: a made-up code).
    func addMeet() {
        closePanelMenu()
        guard let e = selectedEvent else { return }
        if isDraftOpen { panelState.newMeet.insert(e.id); reload(); return }
        updateSelected { $0.conferencing = "https://meet.google.com/" + Self.meetCode(e.id) }
    }

    /// A made-up Meet code ("abc-defg-hij") from the event id.
    static func meetCode(_ seed: String) -> String {
        var h: UInt64 = 1469598103934665603
        for b in seed.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        let a = Array("abcdefghijkmnopqrstuvwxyz")
        let letters = (0..<10).map { i in a[Int((h >> UInt64(i * 6)) % UInt64(a.count))] }
        return String(letters[0..<3]) + "-" + String(letters[3..<7]) + "-" + String(letters[7..<10])
    }

    func startPastingLink() { closePanelMenu(); panelMenus.pastingLink = true }

    /// The link field under Join: a web address replaces the call; empty text removes it. Returns false for anything else.
    func setCallLink(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { removeCall(); return true }
        panelMenus.pastingLink = false
        return setVideoLink(t)
    }

    func removeCall() {
        guard let e = selectedEvent else { return }
        panelState.newMeet.remove(e.id)
        panelMenus.pastingLink = false
        updateSelected { ev in
            ev.conferencing = ""
            if let c = CallLink.parse(conferencing: "", notes: ev.notes, location: ""), c.kind == .meet { ev.notes = MeetNotes.visible(ev.notes).text }
        }
        reload()
    }

    func copyCallLink() {
        guard let e = selectedEvent, let c = CallLink.parse(e) else { return }
        copyToPasteboard(c.url.absoluteString)
        showToast("Copied link")
    }

    // MARK: Participants

    func removeSelectedGuest(email: String, name: String?) {
        updateSelected { ev in
            if let i = ev.attendees.firstIndex(where: { !$0.isMe && $0.email == email && $0.name == name }) { ev.attendees.remove(at: i) }
        }
    }

    /// Puts back a guest removed in the unsent change.
    func restoreGuest(_ a: Attendee) { updateSelected { ev in if !ev.attendees.contains(a) { ev.attendees.append(a) } } }

    func restoreCall() {
        guard let u = selectedUnsent else { return }
        updateSelected { $0.conferencing = u.base.conferencing }
    }

    /// The people the guest field suggests: the store's people not on the list yet, matched by name or address.
    func guestSuggestions(_ q: String) -> [Teammate] {
        guard let e = selectedEvent else { return [] }
        let on = Set(e.attendees.map { $0.email.lowercased() })
        let list = store.teammates.filter { !on.contains($0.email.lowercased()) }
        let query = q.trimmingCharacters(in: .whitespaces)
        // empty field: the four most recent people (the demo order stands in for recency)
        return query.isEmpty ? Array(list.prefix(4)) : Array(FuzzyMatcher.filter(list, query: query) { "\($0.name) \($0.email)" }.prefix(6))
    }

    func addGuest(_ t: Teammate) {
        updateSelected { $0.attendees.append(Attendee(email: t.email, name: t.name)) }
        panelMenus.guestQuery = ""
        closePanelMenu()
    }

    /// "N without a name · Allow Contacts": the Contacts request itself comes with v4 Phase 8a.
    func allowContacts() { showToast("Contacts access comes in a later update") }

    /// "Find a new time": the guests' calendars side by side (Meet with).
    func findNewTime() { store.canOverlayTeammates ? openPalette(.meet) : showToast(Self.meetWithUnavailable) }

    func copyGuestAddress(_ a: Attendee) {
        guard !a.email.isEmpty else { return }
        copyToPasteboard(a.email)
        showToast("Copied \(a.email)")
    }
}

extension PanelText {
    /// The editor's length (mockup `dur`): "1 h", "1 h 30 min", "45 min".
    static func editorDuration(_ minutes: Int) -> String {
        let m = max(0, minutes)
        return m >= 60 ? "\(m / 60) h" + (m % 60 > 0 ? " \(m % 60) min" : "") : "\(m) min"
    }

    /// The editor's repeat line: "Every week on Sun" for one weekday, else the general text.
    static func editorRepeats(_ e: CalendarEvent, _ fmt: Fmt) -> String? {
        guard let t = repeats(e, fmt) else { return nil }
        if t.hasPrefix("Weekly on "), !t.contains(",") { return "Every week on " + t.dropFirst("Weekly on ".count) }
        return t
    }

    /// A guest's reply as the participant list's tooltip names it.
    static func replyName(_ s: ResponseStatus) -> String {
        switch s {
        case .confirmed: "Going"
        case .tentative: "Maybe"
        case .declined: "Declined"
        case .needsAction: "Awaiting"
        }
    }
}
