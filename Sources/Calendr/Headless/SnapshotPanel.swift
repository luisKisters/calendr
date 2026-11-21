import AppKit
import CalendrKit

/// Snapshot states of the PANEL area. `SnapshotStates.apply` falls through to this for names it does not know.
@MainActor
enum SnapshotPanel {
    /// Puts the model into the named state. Returns false for names this area does not define.
    static func apply(_ state: String, _ m: AppModel) -> Bool {
        switch state {
        case "panel-sync":          // mockup: select(... "Thursday sync")
            if let e = SnapshotStates.find(m, "Thursday sync", day: 3) { m.select(eventID: e.id) }
        case "panel-readonly":      // mockup: select(... "Day of German Unity")
            if let e = m.layout.allDayEvents.values.first(where: { $0.title == "Day of German Unity" }) { m.select(eventID: e.id) }
        case "panel-long-title":
            if let e = SnapshotStates.find(m, "Sam / Alex", day: 1) {
                m.select(eventID: e.id)
                m.updateSelected { $0.title = "Quarterly planning with the studio team and everyone from Northwind" }
            }
        case "panel-added":         // v4: no "add" chips; the empty place and notes rows show their placeholders
            if let e = SnapshotStates.find(m, "Sam / Alex", day: 1) { m.select(eventID: e.id) }
        case "panel-create-titled":
            let s = m.math.date(on: DemoData.day(10, 1), minutes: 12 * 60)
            m.createEvent(start: s, end: s.addingTimeInterval(3600))
            m.updateSelected { $0.title = "Lunch with Maya" }
        case "panel-nothing-left":  // 23:30: the day is over
            m.setNow(m.math.date(on: m.now, minutes: 23 * 60 + 30))
        case "panel-light-detail":
            m.settings.appearance = .light
            if let e = SnapshotStates.find(m, "Thursday sync", day: 3) { m.select(eventID: e.id) }
        default: return applyV4(state, m)
        }
        return true
    }

    /// v4 editor scenes (design/mockup-v4 `preset()`), on the v4 fixture. "v4-event" and "v4-delete" are in `SnapshotV4`.
    static let v4States = ["v4-invited", "v4-call", "v4-location", "v4-maps", "v4-calendar", "v4-reminders", "v4-guests", "v4-invite", "v4-pending"]

    static func applyV4(_ state: String, _ m: AppModel) -> Bool {
        func open(_ id: String) { if let e = SnapshotV4.event(m, id) { m.select(eventID: e.id) } }
        switch state {
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
