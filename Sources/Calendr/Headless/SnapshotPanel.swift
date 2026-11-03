import AppKit
import CalendrKit

/// Snapshot states of the PANEL area. `SnapshotStates.apply` falls through to this for names it does not know.
@MainActor
enum SnapshotPanel {
    /// The editor scenes (design/mockup-v4 `preset()`). "v4-event" and "v4-delete" are in `SnapshotV4`.
    static let v4States = ["v4-invited", "v4-call", "v4-location", "v4-maps", "v4-calendar", "v4-reminders", "v4-guests", "v4-invite", "v4-pending"]
    /// The other panel states: a new event, the recurring delete question, an event on a read-only calendar.
    static let states = ["create-event", "delete-recurring", "readonly-event"]

    /// Puts the model into the named state. Returns false for names this area does not define.
    static func apply(_ state: String, _ m: AppModel) -> Bool {
        func open(_ id: String) { if let e = SnapshotV4.event(m, id) { m.select(eventID: e.id) } }
        switch state {
        case "create-event":
            // Thu 1 Oct 12:00-13:00, created the way C or a drag creates: selected, title focused.
            let s = m.math.date(on: DemoDataV4.day(10, 1), minutes: 12 * 60)
            m.createEvent(start: s, end: s.addingTimeInterval(3600))
        case "delete-recurring":
            // Long run repeats every Sunday; the fixture holds one week, so the series gets its next occurrence first.
            if let e = SnapshotV4.event(m, "g1") {
                var next = e; next.id = "v4.g1.next"; next.start = m.math.addDays(e.start, 7); next.end = m.math.addDays(e.end, 7)
                _ = try? m.store.create(next)
                m.storeChanged()
                m.select(eventID: e.id); m.requestDeleteSelected()
            }
        case "readonly-event":
            // Family as a read-only (subscribed) calendar: Lunch on Thursday shows its fields without editing.
            (m.store as? DemoStore)?.makeReadOnly(DemoDataV4.family)
            m.storeChanged()
            open("d3")
        case "v4-invited": open("d4")                                   // Office hours: Jonas organises, Going? answered Yes
        case "v4-call": open("c3"); m.openPanelMenu(.call)              // Lunch with Theo: no call yet, the call menu
        case "v4-location":
            // Lunch with Theo, "Mark" typed into the location: the suggestions (the demo list stands in for MapKit)
            if var e = SnapshotV4.event(m, "c3") { e.location = "Mark"; _ = try? m.store.update(e, span: .this); m.storeChanged(); m.select(eventID: e.id) }
            m.searchPlaces("Mark")
        case "v4-maps": open("wg"); m.openPanelMenu(.maps)
        case "v4-calendar": open("wg"); m.openPanelMenu(.calendar)
        case "v4-reminders": open("wg"); m.openPanelMenu(.reminders)
        case "v4-guests": open("wg"); m.openPanelMenu(.guests)
        case "v4-invite":
            // A new event on Saturday 18:00 with Mara and Theo, "Talk rehearsal", a Meet link made on save
            let s = m.math.date(on: m.math.addDays(DemoDataV4.weekStart, 5), minutes: 18 * 60)
            m.createEvent(start: s, end: s.addingTimeInterval(3600))
            m.updateSelected { e in
                e.title = "Talk rehearsal"
                let me = DemoDataV4.person("me")
                e.attendees = [Attendee(email: me.email, name: me.name, isOrganizer: true, isMe: true, status: .confirmed)]
                    + ["mara", "theo"].map { DemoDataV4.person($0) }.map { Attendee(email: $0.email, name: $0.name) }
            }
            m.addMeet()
            m.blurTick += 1
            m.titleFocusPending = false
            SnapshotV4.scroll(m, to: 18 * DemoDataV4.hourHeight - 160)
            return true
        case "v4-pending":
            // Flat dinner with Sam's iCloud address and the call removed, not sent yet: the split button's menu
            open("wg")
            m.updateSelected { e in e.attendees.removeAll { $0.email == DemoDataV4.person("icloud").email }; e.conferencing = "" ; e.notes = MeetNotes.visible(e.notes).text }
            m.openPanelMenu(.send)
        default: return false
        }
        SnapshotV4.scroll(m, to: SnapshotV4.defaultScroll)
        return true
    }
}
