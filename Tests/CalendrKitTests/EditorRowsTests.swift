import Testing
import Foundation
@testable import CalendrKit

@Suite("v4 editor rows")
struct EditorRowsTests {
    let all: [EditorRow] = [.title, .when, .repeats, .findTime, .participants, .going, .call, .location, .notes, .calendar, .reminders]

    @Test func rowOrderFollowsTheMockup() {
        #expect(EditorRow.allCases == all)
        // an organizer with guests sees every row in order
        #expect(EditorRows.rows(EditorContext(hasOthers: true, canEdit: true, isDraft: false, hasMyEntry: true)) == all)
    }

    @Test func emptyRowsArePresent() {
        // a bare event: no guests, no call, no place, no notes, no reminder. Every field row is still there.
        let rows = EditorRows.rows(EditorContext(hasOthers: false, canEdit: true, isDraft: false, hasMyEntry: false))
        #expect(rows == [.title, .when, .repeats, .participants, .call, .location, .notes, .calendar, .reminders])
        #expect(rows.compactMap(\.placeholder) == ["(No title)", "Does not repeat", "Add participants", "Add conferencing", "Add location", "Add notes", "Add reminder"])
    }

    @Test func invitedAndDraftRows() {
        // invited: Going? but no "Find a new time" (I cannot move the event)
        let invited = EditorRows.rows(EditorContext(hasOthers: true, canEdit: false, isDraft: false, hasMyEntry: true))
        #expect(invited.contains(.going) && !invited.contains(.findTime))
        // a new event with guests: nothing to answer yet
        let draft = EditorRows.rows(EditorContext(hasOthers: true, canEdit: true, isDraft: true, hasMyEntry: true))
        #expect(!draft.contains(.going) && draft.contains(.findTime))
    }

    @Test func sharedFieldsAreTheOnesToSend() {
        let s = Date(timeIntervalSince1970: 0)
        let a = CalendarEvent(calendarID: "c", title: "A", start: s, end: s.addingTimeInterval(3600),
                              attendees: [Attendee(email: "me@x.example", isOrganizer: true, isMe: true), Attendee(email: "o@x.example")])
        var b = a
        b.reminders = [5, 30]; b.colorHex = "#5FB97E"; b.calendarID = "d"; b.availability = .free
        #expect(!EditorRows.sharedChanged(a, b))
        b.attendees[1].status = .declined
        #expect(!EditorRows.sharedChanged(a, b))
        b.location = "Market Hall"
        #expect(EditorRows.sharedChanged(a, b))
        var c = a; c.attendees.removeLast()
        #expect(EditorRows.sharedChanged(a, c))
        let p = EditorRows.personal(of: b, onto: a)
        #expect(p.reminders == [5, 30] && p.calendarID == "d" && p.location.isEmpty)
    }

    @Test func participantTexts() {
        let list = [Attendee(email: "me@x.example", isOrganizer: true, isMe: true, status: .confirmed), Attendee(email: "m@x.example", name: "Mara", status: .confirmed),
                    Attendee(email: "j@x.example", name: "Jonas", status: .tentative), Attendee(email: "d@x.example", status: .declined),
                    Attendee(email: "s@x.example", isOptional: true)]
        #expect(EditorRows.replySummary(list) == "2 yes, 1 maybe, 1 no, 1 awaiting")
        #expect(EditorRows.participantCount(5) == "5 participants" && EditorRows.participantCount(1) == "1 participant")
        #expect(EditorRows.role(list[0]) == "organizer · you" && EditorRows.role(list[4]) == "optional" && EditorRows.role(list[1]).isEmpty)
        #expect(EditorRows.withoutName(list) == 2)      // me (no name either) is never counted
    }

    @Test func reminderLabelsAndToggling() {
        #expect(Reminders.choices.map(Reminders.label) == ["At start", "5 min before", "10 min before", "15 min before", "30 min before", "1 hour before", "1 day before"])
        #expect(Reminders.amount(120) == "2 hours" && Reminders.amount(2880) == "2 days")
        #expect(Reminders.toggled([10], 60) == [10, 60] && Reminders.toggled([10, 60], 10) == [60] && Reminders.toggled([60], 5) == [5, 60])
    }

    @Test func elevenGoogleColours() {
        #expect(EventColors.google.count == 11 && EventColors.google.first?.name == "Tomato" && EventColors.google.last?.name == "Graphite")
        #expect(Set(EventColors.google.map(\.hex)).count == 11 && EventColors.columns == 6)
    }

    @Test func meetNotesHideAndKeepTheBlock() {
        let notes = "Everyone brings something.\n\n" + MeetNotes.boilerplate("cmv-hjhb-qgb")
        let v = MeetNotes.visible(notes)
        #expect(v.hidden && v.text == "Everyone brings something.")
        let edited = MeetNotes.replacingVisible(in: notes, with: "Bring plates.")
        #expect(edited == "Bring plates.\n\n" + MeetNotes.boilerplate("cmv-hjhb-qgb") && MeetNotes.visible(edited).text == "Bring plates.")
        #expect(MeetNotes.replacingVisible(in: "plain", with: "new") == "new" && !MeetNotes.visible("plain").hidden)
    }

    @Test func placeSuggestions() {
        let r = PlaceSuggestion.filter(PlaceSuggestion.demo, "Mark")
        #expect(r.count == 5 && r.first?.text == "Northwind Studio, 40 Market Street")
        #expect(PlaceSuggestion.filter(PlaceSuggestion.demo, "M").isEmpty)
        #expect(PlaceSuggestion.filter(PlaceSuggestion.demo, "Market Hall, 42 Station Road").isEmpty)
    }

    @Test func trailingNewLinesSurviveTheHiddenBlock() {
        let notes = MeetNotes.replacingVisible(in: "Hi.\n\n" + MeetNotes.boilerplate("abc-defg-hij"), with: "Hi.\n")
        #expect(MeetNotes.visible(notes) == ("Hi.\n", true))
        let two = MeetNotes.replacingVisible(in: notes, with: "Hi.\n\n")
        #expect(MeetNotes.visible(two).text == "Hi.\n\n")
    }

    @Test func withoutANameNeverCountsMe() {
        let list = [Attendee(email: "me@x.example", isOrganizer: true, isMe: true), Attendee(email: "a@x.example"), Attendee(email: "b@x.example"),
                    Attendee(email: "c@x.example", name: "Cleo")]
        #expect(EditorRows.withoutName(list) == 2)
    }

    @Test func callLinksComeOutOfText() {
        #expect(CallLink.removingCalls(from: "Agenda in the doc.\nJoin: https://zoom.us/j/123") == "Agenda in the doc.")
        #expect(CallLink.removingCalls(from: "Room 4 (meet.google.com/abc-defg-hij)") == "Room 4")
        #expect(CallLink.removingCalls(from: "See https://example.com/agenda") == "See https://example.com/agenda")
    }
}

