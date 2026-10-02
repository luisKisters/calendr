import SwiftUI
import AppKit
import CalendrKit

/// The right column: one width, always present. Today when nothing is selected, the event when one is, the new event while it is
/// being created. The content swaps with a 180 ms fade; the grid never changes width.
struct RightPanelView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let e = model.selectedEvent
        let key = e.map { "d:\($0.id)" } ?? "today"
        ScrollView(.vertical, showsIndicators: false) {
            Group {
                if let e { PanelDetailView(e: e) } else { PanelTodayView() }
            }
            .id(key)
            .transition(.asymmetric(insertion: .opacity, removal: .identity))
            .padding(.top, 12)
        }
        .animation(Motion.base, value: key)
        .padding(.leading, 1)
        .frame(width: PanelMetrics.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.hair2).frame(width: 1) }
    }
}

/// Nothing selected: Now (time left), Up next (countdown), Later.
struct PanelTodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let t = model.panelState.today
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today").font(.ui(16, .semibold)).tracking(-0.35).foregroundStyle(Theme.fg)
                Spacer(minLength: 0)
                Text(PanelText.day(model.now, model.fmt)).font(.calMono(11.5)).foregroundStyle(Theme.fg3)
            }
            .padding(.leading, 7).padding(.trailing, 8).padding(.top, 3).frame(height: 33, alignment: .top).padding(.bottom, 14)
            VStack(spacing: 8) {
                if let live = t.live { PanelNextCard(event: live, live: true) }
                if let next = t.next { PanelNextCard(event: next, live: false) }
            }
            if t.live == nil && t.next == nil {
                Text("Nothing else today.").font(.ui(12.5)).foregroundStyle(Theme.fg3).padding(.horizontal, 9)
            }
            if !t.later.isEmpty {
                MicroLabel(text: "Later").padding(.horizontal, 9).padding(.top, 18).padding(.bottom, 5)
                ForEach(t.later) { e in PanelLaterRow(event: e) }
            }
        }
        .padding(.top, 14).padding(.horizontal, 12).padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// `.nx`: Now / Up next card with the countdown, the event, and Join when it has a call.
struct PanelNextCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let event: CalendarEvent
    let live: Bool

    var body: some View {
        let minutes = Countdown.minutes(from: model.now, to: live ? event.end : event.start)
        let soon = live || minutes <= 15
        let bar = Palettes.cc(model.calendarColorHex(of: event), dark: scheme == .dark).color
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                MicroLabel(text: live ? "Now" : "Up next")
                Text(live ? "\(minutes) min left" : PanelText.until(minutes))
                    .font(.calMono(11.5, .medium)).foregroundStyle(soon ? Theme.live : Theme.fg2)
                Spacer(minLength: 0)
            }
            .frame(height: 20)
            Button { model.panelOpen(event) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title).font(.ui(13.5, .semibold)).foregroundStyle(Theme.fg).lineLimit(1).frame(height: 18)
                    HStack(spacing: 0) {
                        Text("\(model.fmt.time(event.start)) \u{2013} \(model.fmt.time(event.end))").font(.calMono(11.5))
                        if let place = PanelText.place(event.location) { Text(" \u{00B7} " + place).font(.ui(11.5)) }
                    }
                    .foregroundStyle(Theme.fg2).lineLimit(1).truncationMode(.tail).frame(height: 15.5)
                }
                .padding(.leading, 12).padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 1.5).fill(bar).frame(width: 3).padding(.vertical, 2) }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            if !event.conferencing.isEmpty {
                PanelFillButton(title: "Join", small: true, fullWidth: true) { model.joinCall(event) }.padding(.top, 10)
            }
        }
        .padding(.top, 10).padding(.bottom, 10).padding(.leading, 11).padding(.trailing, 10)
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(Theme.bg1))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Theme.hair, lineWidth: 1))
    }
}

/// `.ag__r`: start time, calendar bar, title. Selects the event.
struct PanelLaterRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let event: CalendarEvent
    @State private var hover = false

    var body: some View {
        let selected = model.selectedEventID == event.id
        Button { model.panelOpen(event) } label: {
            HStack(spacing: 8) {
                Text(model.fmt.time(event.start)).font(.calMono(11)).foregroundStyle(Theme.fg2).frame(width: 40, alignment: .leading)
                RoundedRectangle(cornerRadius: 2).fill(Palettes.cc(model.calendarColorHex(of: event), dark: scheme == .dark).color).frame(width: 3, height: 14)
                Text(event.title).font(.ui(12.5)).foregroundStyle(Theme.fg).lineLimit(1).truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 9).frame(height: 30)
            .background(RoundedRectangle(cornerRadius: Radius.row).fill(selected ? Theme.actWash : (hover ? Theme.hover : Color.clear)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}
