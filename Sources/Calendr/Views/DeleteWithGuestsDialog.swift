import SwiftUI
import CalendrKit

/// Deleting an event I organise with guests (design/mockup-v4 `del: modal`): the guest list, Cancel, and a red split button
/// "Delete event | ▾ Delete without cancellation email". The plain button sends the cancellation email.
struct DeleteWithGuestsDialog: View {
    @Environment(AppModel.self) private var model
    let eventID: String

    var body: some View {
        if let e = model.event(id: eventID) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Delete event \u{201C}\(e.title.isEmpty ? "(No title)" : e.title)\u{201D}").font(.title18).tracking(-0.27).foregroundStyle(Theme.fg).lineLimit(1)
                    Text("Delete the event and send a cancellation email, or delete it without an email.").font(.text).foregroundStyle(Theme.fg2)
                        .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 18)
                Hairline()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(e.attendees.enumerated()), id: \.offset) { _, a in
                        HStack(spacing: 10) {
                            Avatar(a: a)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(a.label).strikethrough().foregroundStyle(Theme.fg3).lineLimit(1)
                                if a.isOrganizer { Text("Organizer").font(.small).foregroundStyle(Theme.fg3).strikethrough() }
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 40)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 4)
                HStack(spacing: 8) {
                    Spacer()
                    PlainButton(title: "Cancel") { model.closePanelMenu(); model.closeOverlay() }
                    SplitButton(title: "Delete event", menu: .deleteSend, red: true, help: "Guests get a cancellation email") {
                        model.deleteWithGuests(eventID, notify: true)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 20)
            }
            .frame(width: 520)
            .surface()
        }
    }
}

/// `.av`: 26 pt round initials with a reply badge (the delete dialog's guest list).
struct Avatar: View {
    let a: Attendee
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(PanelText.initials(a.label)).font(.smallSemibold).foregroundStyle(Theme.fg)
                .frame(width: 26, height: 26).background(Circle().fill(Theme.bg3))
            let s: ResponseStatus = a.isOrganizer ? .confirmed : a.status
            if s != .needsAction {
                Circle().fill(s == .confirmed ? Theme.replyYes : s == .tentative ? Theme.replyMaybe : Theme.danger)
                    .frame(width: 13, height: 13)
                    .overlay { PanelIcon(name: s == .confirmed ? .check : s == .tentative ? .q : .x, size: 9, color: Theme.onDanger) }
                    .overlay(Circle().strokeBorder(Theme.pop, lineWidth: 2).padding(-2))
                    .offset(x: 3, y: 3)
            }
        }
        .frame(width: 26, height: 26)
    }
}
