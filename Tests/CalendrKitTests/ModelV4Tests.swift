import Testing
import Foundation
@testable import CalendrKit

/// v4 Phase 2: replies, attendees, reminders and call links.
@Suite("Model v4")
struct ModelV4Tests {
    func ev(attendees: [Attendee] = [], status: ResponseStatus = .confirmed, conferencing: String = "", notes: String = "", location: String = "") -> CalendarEvent {
        CalendarEvent(id: "x", calendarID: "c", title: "x", start: d(2026, 9, 30, 19), end: d(2026, 9, 30, 20), status: status,
                      location: location, notes: notes, attendees: attendees, conferencing: conferencing)
    }
    static func boiler(_ code: String) -> String {
        "-::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-\nJoin with Google Meet: https://meet.google.com/\(code)\n\nLearn more about Meet at: "
            + "https://support.google.com/a/users/answer/9282720\n\nPlease do not edit this section.\n-::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-"
    }

    // MARK: Replies

    @Test func pendingMapsToNeedsAction() {
        #expect(EventKitMapping.responseStatus(myStatus: .pending, eventTentative: false, eventCanceled: false) == .needsAction)
        // Only when I am on the guest list: no entry of mine is my own event.
        #expect(EventKitMapping.responseStatus(myStatus: nil, eventTentative: false, eventCanceled: false) == .confirmed)
        #expect(EventKitMapping.status(of: .pending) == .needsAction && EventKitMapping.status(of: .accepted) == .confirmed)
    }

    @Test func organizerMapsToConfirmed() {
        #expect(EventKitMapping.responseStatus(myStatus: .pending, iAmOrganizer: true, eventTentative: false, eventCanceled: false) == .confirmed)
        // The organizer's reply counts as accepted even when the stored status says otherwise.
        let mine = ev(attendees: [Attendee(email: "me@example.com", isOrganizer: true, isMe: true), Attendee(email: "a@example.com")], status: .needsAction)
        #expect(mine.iAmOrganizer && mine.myReply == .confirmed && !mine.isUnaccepted)
    }

    @Test func canceledMapsToDeclined() {
        #expect(EventKitMapping.responseStatus(myStatus: .accepted, iAmOrganizer: true, eventTentative: false, eventCanceled: true) == .declined)
    }

    @Test func unacceptedIsDeclinedOrNoReply() {
        let invite = [Attendee(email: "o@example.com", isOrganizer: true, status: .confirmed), Attendee(email: "me@example.com", isMe: true)]
        #expect(ev(attendees: invite, status: .needsAction).isUnaccepted)
        #expect(ev(attendees: invite, status: .declined).isUnaccepted)
        #expect(!ev(attendees: invite, status: .tentative).isUnaccepted)
        #expect(!ev(attendees: invite, status: .confirmed).isUnaccepted)
    }

    @Test func statusKeepsMyAttendeeEntryInStep() {
        var e = ev(attendees: [Attendee(email: "o@example.com", isOrganizer: true), Attendee(email: "me@example.com", isMe: true)], status: .needsAction)
        e.status = .tentative
        #expect(e.attendees[1].status == .tentative)
    }

    // MARK: Attendees

    @Test func eventKitAttendeesWithOrganizer() {
        let org = RawParticipant(name: "Nils Bauer", email: "n.bauer@club.example", status: .accepted)
        let raw = [RawParticipant(name: "Nils Bauer", email: "n.bauer@club.example", role: .chair, status: .accepted),
                   RawParticipant(name: "Sam Rivera", email: "sam.rivera@example.com", isCurrentUser: true, status: .pending),
                   RawParticipant(name: "ida.sommer@example.org", email: "ida.sommer@example.org", role: .optional, status: .declined),
                   RawParticipant(name: nil, email: nil)]
        let a = EventKitMapping.attendees(raw, organizer: org)
        #expect(a.count == 3)
        #expect(a[0].isOrganizer && a[0].label == "Nils Bauer" && a[0].status == .confirmed && !a[0].isMe)
        #expect(a[1].isMe && a[1].status == .needsAction)
        #expect(a[2].isOptional && a[2].name == nil && a[2].label == "ida.sommer@example.org" && a[2].status == .declined)
    }

    @Test func participantsAreTheOtherGuests() {
        var e = ev(attendees: [Attendee(email: "me@example.com", name: "Me", isOrganizer: true, isMe: true),
                               Attendee(email: "mara@example.com", name: "Mara", status: .confirmed)])
        #expect(e.participants == ["Mara"])
        e.participants.append("Theo Park <theo@example.com>")
        #expect(e.attendees.count == 3 && e.attendees[0].isMe && e.attendees[1].status == .confirmed)
        #expect(e.attendees[2].email == "theo@example.com" && e.attendees[2].name == "Theo Park" && e.attendees[2].status == .needsAction)
        e.participants.remove(at: 0)
        #expect(e.participants == ["Theo Park"] && e.attendees.count == 2)
        // The old `participants:` argument still builds a guest list.
        #expect(CalendarEvent(calendarID: "c", title: "t", start: .now, end: .now, participants: ["Sam Okafor", "a@example.com"]).participants == ["Sam Okafor", "a@example.com"])
    }

    // MARK: Reminders

    @Test func alarmsGiveSortedUniqueReminders() {
        #expect(EventKitMapping.reminders(alarmOffsetSeconds: [-600, -3600, 60]) == [10, 60])
        #expect(EventKitMapping.reminders(alarmOffsetSeconds: [-600, -600]) == [10])
        #expect(EventKitMapping.alarmOffsets(reminders: [10, 60]) == [-600, -3600])
    }

    @Test func remindersStayUniqueAndSorted() {
        var e = CalendarEvent(calendarID: "c", title: "t", start: .now, end: .now, reminders: [60, 10, 10])
        #expect(e.reminders == [10, 60] && e.reminderMinutes == 10)
        e.reminders.append(5)
        #expect(e.reminders == [5, 10, 60])
        e.reminderMinutes = 30
        #expect(e.reminders == [30])
        e.reminderMinutes = nil
        #expect(e.reminders.isEmpty)
        #expect(CalendarEvent(calendarID: "c", title: "t", start: .now, end: .now, reminderMinutes: 15).reminders == [15])
    }

    // MARK: Call links

    @Test func meetCodeFromTheBoilerplate() {
        let c = CallLink.parse(conferencing: "", notes: "Bring snacks.\n\n" + Self.boiler("oet-mzpa-wdr"))
        #expect(c?.kind == .meet && c?.code == "oet-mzpa-wdr" && c?.display == "meet.google.com/oet-mzpa-wdr" && c?.name == "Google Meet")
    }

    @Test func zoomOnASubdomain() {
        let c = CallLink.parse(conferencing: "https://us02web.zoom.us/j/88123456789?pwd=abc")
        #expect(c?.kind == .zoom && c?.code == "88123456789")
        #expect(CallLink.parse(conferencing: "", notes: "", location: "Join (zoom.us/j/123456).")?.code == "123456")
        #expect(CallLink.parse(conferencing: "https://teams.microsoft.com/l/meetup-join/xyz")?.kind == .teams)
        #expect(CallLink.parse(conferencing: "meet.example.com/sam-alex")?.kind == .other)
    }

    @Test func aWebsiteIsNoCall() {
        #expect(CallLink.parse(conferencing: "https://example.com/agenda", notes: "See https://docs.example.org/doc and notzoom.us.example.com") == nil)
        #expect(CallLink.parse(conferencing: "", notes: "Plain text, no link.") == nil)
        #expect(CallLink.parse(conferencing: "mailto:meet.google.com") == nil)
    }

    @Test func conferencingWinsOverNotes() {
        let c = CallLink.parse(conferencing: "https://zoom.us/j/1", notes: Self.boiler("abc-defg-hij"))
        #expect(c?.kind == .zoom)
    }

    @Test func strippingTheBoilerplateKeepsTheUsersText() {
        let notes = "Bring snacks.\nAgenda in the doc.\n\n" + Self.boiler("oet-mzpa-wdr") + "\n\nParking behind the hall."
        let (clean, had) = CallLink.stripMeetBoilerplate(notes)
        #expect(had && clean == "Bring snacks.\nAgenda in the doc.\n\nParking behind the hall.")
        let (only, had2) = CallLink.stripMeetBoilerplate(Self.boiler("abc-defg-hij"))
        #expect(had2 && only.isEmpty)
        let plain = "No call here.\n\n-::~:~::-\nnot meet\n-::~:~::-"
        #expect(CallLink.stripMeetBoilerplate(plain) == (plain, false))
    }

    @Test func menuBarJoinComesFromTheCallLink() {
        let e = ev(attendees: [Attendee(email: "o@example.com", isOrganizer: true), Attendee(email: "me@example.com", isMe: true)], notes: Self.boiler("oet-mzpa-wdr"))
        #expect(MenuBarMenu.videoURL(e)?.absoluteString == "https://meet.google.com/oet-mzpa-wdr")
        #expect(MenuBarMenu.guestAddresses(e) == ["o@example.com"])
    }

    // MARK: Review fixes

    @Test func myAnswerUsesOneMapping() {
        func r(_ s: RawParticipantStatus?, tentative: Bool = false) -> ResponseStatus {
            EventKitMapping.responseStatus(myStatus: s, eventTentative: tentative, eventCanceled: false)
        }
        #expect(r(.unknown) == .needsAction && r(.inProcess) == .needsAction && r(.pending) == .needsAction)
        #expect(r(.delegated) == .declined && r(.completed) == .confirmed && r(.accepted) == .confirmed)
        #expect(r(.accepted, tentative: true) == .tentative && r(nil, tentative: true) == .tentative && r(.declined, tentative: true) == .declined)
        #expect(EventKitMapping.myAnswer(.delegated) == .declined && EventKitMapping.status(of: .delegated) == .confirmed)
    }

    @Test func organizerOfATentativeEventIsConfirmed() {
        #expect(EventKitMapping.responseStatus(myStatus: nil, iAmOrganizer: true, eventTentative: true, eventCanceled: false) == .confirmed)
    }

    @Test func onlyEventKitsOrganizerIsTheOrganizerAndRoomsAreNoGuests() {
        let raw = [RawParticipant(name: "Chair", email: "chair@example.com", role: .chair, status: .accepted),
                   RawParticipant(name: "Room 4", email: "room4@example.com", status: .accepted, kind: .room),
                   RawParticipant(name: "Projector", email: "proj@example.com", status: .accepted, kind: .resource),
                   RawParticipant(name: "Me", email: "me@example.com", isCurrentUser: true, status: .delegated)]
        let a = EventKitMapping.attendees(raw, organizer: nil)
        #expect(a.map(\.label) == ["Chair", "Me"])
        #expect(!a.contains { $0.isOrganizer })
        #expect(a[1].isMe && a[1].status == .declined)
    }

    @Test func initPutsTheStatusIntoMyEntry() {
        let e = ev(attendees: [Attendee(email: "o@example.com", isOrganizer: true), Attendee(email: "me@example.com", isMe: true, status: .confirmed)],
                   status: .needsAction)
        #expect(e.attendees[1].status == .needsAction)
    }

    @Test func removingOneOfTwoSameNameGuestsRemovesThatOne() {
        var e = ev(attendees: [Attendee(email: "sam1@example.com", name: "Sam"), Attendee(email: "sam2@example.com", name: "Sam"),
                               Attendee(email: "me@example.com", isMe: true)])
        e.removeGuest(at: 0)
        #expect(e.attendees.map(\.email) == ["sam2@example.com", "me@example.com"])
        var f = ev(attendees: [Attendee(email: "sam1@example.com", name: "Sam"), Attendee(email: "sam2@example.com", name: "Sam")])
        f.participants.removeLast()
        #expect(f.attendees.map(\.email) == ["sam1@example.com"])
        f.addGuest("Lea <lea@example.org>")
        f.addGuest("   ")
        #expect(f.participants == ["Sam", "Lea"] && f.attendees[1].status == .needsAction)
        #expect(Attendee.parse("<>") == nil && Attendee.parse(" < > ") == nil && Attendee.parse("") == nil)
        #expect(Attendee.parse("<a@example.com>")?.email == "a@example.com")
    }

    @Test func savingRemindersKeepsOtherAlarmsAndUnchangedOnes() {
        let abs = RawAlarm(relativeOffset: 0, isAbsolute: true), after = RawAlarm(relativeOffset: 60), ten = RawAlarm(relativeOffset: -600)
        #expect(EventKitMapping.reminders(alarms: [abs, after, ten]) == [10])
        #expect(EventKitMapping.alarmChanges(existing: [abs, after, ten], reminders: [10]) == nil)
        let c = EventKitMapping.alarmChanges(existing: [abs, after, ten], reminders: [60, 10])
        #expect(c?.remove == [2] && c?.add == [-600, -3600])
        // A sub-minute offset that already gives the reminder is not rewritten.
        #expect(EventKitMapping.alarmChanges(existing: [RawAlarm(relativeOffset: -630)], reminders: [11]) == nil)
        let cleared = EventKitMapping.alarmChanges(existing: [abs, ten], reminders: [])
        #expect(cleared?.remove == [1] && cleared?.add == [])
    }

    @Test func meetCodeOnlyForTheMeetingCodeShape() {
        #expect(CallLink.parse(conferencing: "https://meet.google.com/lookup/abcdef")?.code == nil)
        #expect(CallLink.parse(conferencing: "https://meet.google.com/lookup/abcdef")?.kind == .meet)
        #expect(CallLink.parse(conferencing: "meet.google.com/abcd-efgh-ijk")?.code == nil)
        #expect(CallLink.parse(conferencing: "meet.google.com/abc-defg-hij")?.code == "abc-defg-hij")
    }

    @Test func strippingHandlesCRLFFencesOfTheUserAndKeepsOtherBlankLines() {
        let crlf = ("Line one\n\n\nLine two\n\n" + Self.boiler("abc-defg-hij")).replacingOccurrences(of: "\n", with: "\r\n")
        let (c, had) = CallLink.stripMeetBoilerplate(crlf)
        #expect(had && c == "Line one\r\n\r\n\r\nLine two")
        let fence = "-::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-"
        let mine = "\(fence)\nMy own divider\n\n" + Self.boiler("abc-defg-hij") + "\nAfter."
        let (m, had2) = CallLink.stripMeetBoilerplate(mine)
        #expect(had2 && m == "\(fence)\nMy own divider\n\nAfter.")
    }

    @Test func overnightEventsEndAtMidnightOfTheirDay() {
        let day = d(2026, 9, 30)
        let s = d(2026, 9, 30, 23), e = d(2026, 10, 1, 0, 30)
        #expect(berlin.minutesOnDay(s, e, day: day) == (1380, 1440))
        #expect(berlin.minutesOnDay(s, e, day: d(2026, 10, 1)) == (0, 30))
        #expect(berlin.minutesOnDay(d(2026, 9, 29, 12), d(2026, 10, 2), day: day) == (0, 1440))
        let it = V5Item(id: "x", start: s, end: e, day: day, math: berlin)
        #expect(it.startMinute == 1380 && it.endMinute == 1440 && !it.isShort)
        #expect(V5Item(id: "t", start: s, end: s, day: day, math: berlin).isShort)
    }
}
