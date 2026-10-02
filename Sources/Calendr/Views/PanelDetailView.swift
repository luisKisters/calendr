import SwiftUI
import AppKit
import CalendrKit

/// The event in the right column, "Icon rows": only fields with a value; the empty ones are "add" chips.
/// While `draftEventID` is the selected event it is the new event: title focused, Discard / Save at the foot.
struct PanelDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let e: CalendarEvent
    @FocusState private var focus: PanelFocus?
    @State private var guest = ""

    var body: some View {
        let writable = model.isWritable(e)
        let draft = model.isDraftOpen
        let adds = writable ? PanelField.allCases.filter { !model.panelShows($0, e) && ($0 != .guests || model.store.canEditParticipants) } : []
        VStack(alignment: .leading, spacing: 12) {
            top(writable: writable, draft: draft)
            fields(writable: writable)
            if !adds.isEmpty {
                PanelFlow(spacing: 4) {
                    ForEach(adds, id: \.self) { f in PanelAddChip(title: f.label) { add(f) } }
                }
                .padding(.leading, -7).padding(.top, 10)
                .overlay(alignment: .top) { Hairline().padding(.leading, -7) }
            }
            if draft { foot(border: adds.isEmpty) }
        }
        .padding(.top, 14).padding(.leading, 16).padding(.trailing, 14).padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear { if model.titleFocusPending { focus = .title } }
        .onChange(of: model.focusTitleTick) { _, _ in if model.titleFocusPending { focus = .title } }
        // Esc itself is KeyRouter's: it leaves the field and peels one layer (`escapeOneLayer`).
        .onChange(of: model.blurTick) { _, _ in focus = nil }
        .background(ResignFocusOnInsert(skip: { model.titleFocusPending }))
    }

    // MARK: Top row

    private func top(writable: Bool, draft: Bool) -> some View {
        let bar = Palettes.cc(model.calendarColorHex(of: e), dark: scheme == .dark).color
        return HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5).fill(bar).frame(width: 3, height: 20).padding(.trailing, 7)
            Group {
                if writable {
                    TextField("", text: Binding(get: { model.selectedEvent?.title ?? "" }, set: { v in model.updateSelected { $0.title = v } }),
                              prompt: nil)
                        .textFieldStyle(.plain)
                        .panelPlaceholder("Title", when: e.title.isEmpty, font: .ui(17))
                        .focused($focus, equals: .title)
                        .onSubmit { draft ? model.saveDraft() : (focus = nil) }
                } else {
                    Text(e.title).lineLimit(1).truncationMode(.tail)
                }
            }
            .font(.ui(17, .semibold)).tracking(-0.37).foregroundStyle(Theme.fg)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            if writable && !draft { PanelIconButton(icon: .trash) { model.requestDeleteSelected() } }
            PanelIconButton(icon: .x) { model.closePanel() }
        }
    }

    // MARK: Rows

    private func fields(writable: Bool) -> some View {
        let fmt = model.fmt
        let canGuests = writable && model.store.canEditParticipants
        return VStack(alignment: .leading, spacing: 6) {
            row(.clock) {
                VStack(alignment: .leading, spacing: 0) {
                    when(writable: writable)
                    if writable { PanelSwitch(label: "All day", isOn: e.isAllDay) { model.setSelectedAllDay(!e.isAllDay) } }
                }
            }
            if let r = PanelText.repeats(e, fmt) {
                row(.repeats) { Text(r).font(.ui(12.5)).foregroundStyle(Theme.fg).lineLimit(1) }
            }
            if model.panelShows(.place, e) {
                row(.pin) {
                    TextField("", text: Binding(get: { model.selectedEvent?.location ?? "" }, set: { v in model.updateSelected { $0.location = v } }),
                              axis: .vertical)
                        .textFieldStyle(.plain).font(.ui(12.5)).foregroundStyle(Theme.fg).lineLimit(1...3)
                        .panelPlaceholder("Add a place", when: e.location.isEmpty)
                        .focused($focus, equals: .place).disabled(!writable)
                        .onSubmit(submit)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .panelInput(focused: focus == .place, editable: writable, height: nil)
                        .padding(.trailing, -7)
                }
            }
            if model.panelShows(.guests, e) && (canGuests || !e.participants.isEmpty) {
                row(.users) {
                    PanelFlow(spacing: 4) {
                        ForEach(Array(e.participants.enumerated()), id: \.offset) { i, g in
                            PanelGuestChip(name: g, removable: canGuests) { model.updateSelected { $0.participants.remove(at: i) } }
                                .padding(.trailing, i == e.participants.count - 1 ? 8 : 0)
                        }
                        if canGuests {
                            TextField("", text: $guest)
                                .textFieldStyle(.plain).font(.ui(12.5)).foregroundStyle(Theme.fg)
                                .panelPlaceholder("Add a guest", when: guest.isEmpty)
                                .focused($focus, equals: .guest)
                                .onSubmit { model.addGuest(guest); guest = ""; focus = .guest }
                                .panelInput(focused: focus == .guest, editable: true, hang: false)
                                .panelFill(min: 90)
                        }
                    }
                }
            }
            if model.panelShows(.video, e) {
                row(.video) {
                    if e.conferencing.isEmpty {
                        if writable && model.canInventVideoLink {
                            PanelLineButton(title: "Create a video link") { model.createVideoLink() }
                        } else if writable {
                            PanelCommitField(value: "", minWidth: 220, placeholder: "Paste a video link", editable: true, focusKey: .video, focus: $focus,
                                             commit: { model.setVideoLink($0) }, onReturn: submit)
                        }
                    } else {
                        HStack(spacing: 10) {
                            Button { model.joinCall(e) } label: {
                                Text(e.conferencing).font(.ui(12)).foregroundStyle(Theme.fg).lineLimit(1).truncationMode(.tail)
                                    .underline(color: Theme.fg.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                            PanelFillButton(title: "Join", small: true) { model.joinCall(e) }
                        }
                    }
                }
            }
            if !e.participants.isEmpty || e.status != .confirmed {
                row(.help) {
                    if model.canChangeResponse {
                        PanelRSVP(status: e.status, editable: writable) { s in model.updateSelected { $0.status = s } }
                    } else {
                        // The store cannot write the answer: show it.
                        HStack(spacing: 6) {
                            Text("Going?").font(.ui(12.5)).foregroundStyle(Theme.fg3)
                            Text(PanelText.response(e.status)).font(.ui(12.5)).foregroundStyle(Theme.fg)
                        }
                    }
                }
            }
            row(.calendar) { calendar(writable: writable) }
            if model.panelShows(.notes, e) {
                row(.notes) {
                    TextField("", text: Binding(get: { model.selectedEvent?.notes ?? "" }, set: { v in model.updateSelected { $0.notes = v } }),
                              axis: .vertical)
                        .textFieldStyle(.plain).font(.ui(12.5)).foregroundStyle(Theme.fg).lineSpacing(3).lineLimit(2...14)
                        .panelPlaceholder("Add notes", when: e.notes.isEmpty)
                        .focused($focus, equals: .notes).disabled(!writable)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
                        .padding(.vertical, 5)
                        .panelInput(focused: focus == .notes, editable: writable, height: nil)
                        .padding(.trailing, -7)
                }
            }
        }
    }

    private func row<C: View>(_ icon: PanelIcon.Name, @ViewBuilder _ content: () -> C) -> some View {
        HStack(alignment: .top, spacing: 11) {
            PanelIcon(name: icon).frame(width: 18, height: 28)
            content().frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        }
    }

    /// Date, start → end, length. All-day events show the date and "all day" (or "3 days").
    private func when(writable: Bool) -> some View {
        let m = model.math
        let days = e.isAllDay ? max(1, m.daysBetween(e.start, e.end)) : 1
        let dateText = days > 1 ? "\(PanelText.day(e.start, model.fmt)) \u{2013} \(PanelText.day(m.addDays(e.start, days - 1), model.fmt))" : PanelText.day(e.start, model.fmt)
        return HStack(spacing: 0) {
            PanelCommitField(value: dateText, minWidth: 84, editable: writable && days == 1, focusKey: .date, focus: $focus,
                             commit: { model.setSelectedDay($0) }, onReturn: submit)
            if !e.isAllDay {
                Color.clear.frame(width: 4, height: 1)
                PanelCommitField(value: model.fmt.time(e.start), width: 52, centered: true, tabular: true, editable: writable, focusKey: .start, focus: $focus,
                                 commit: { t in TimeParser.parse(t).map { model.setSelectedStart($0); return true } ?? false }, onReturn: submit)
                PanelIcon(name: .arrow).frame(width: 16)
                PanelCommitField(value: model.fmt.time(e.end), width: 52, centered: true, tabular: true, editable: writable, focusKey: .end, focus: $focus,
                                 commit: { t in TimeParser.parse(t).map { model.setSelectedEnd($0) } ?? false }, onReturn: submit)
            }
            Text(e.isAllDay ? (days > 1 ? "\(days) days" : "all day") : PanelText.duration(e.durationMinutes))
                .font(.calMono(11.5)).foregroundStyle(Theme.fg3).lineLimit(1).fixedSize().padding(.leading, 8)
        }
        .fixedSize()
    }

    /// Writable: the calendar as a menu of writable calendars by account. Read-only: the name, a lock, "read-only".
    @ViewBuilder
    private func calendar(writable: Bool) -> some View {
        let cal = model.calendarInfo(e.calendarID)
        let dot = Circle().fill(Palettes.cc(cal?.colorHex ?? model.calendarColorHex(of: e), dark: scheme == .dark).color).frame(width: 8, height: 8)
        if writable {
            Menu {
                ForEach(model.store.accounts) { a in
                    let cals = a.calendars.filter(\.isWritable)
                    if !cals.isEmpty {
                        Section(a.name) {
                            ForEach(cals) { c in
                                Button { model.updateSelected { $0.calendarID = c.id } } label: {
                                    Label { Text(c.title) } icon: { Image(nsImage: PanelDot.image(c.colorHex)) }
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    dot
                    Text(cal?.title ?? "Calendar").font(.ui(12.5)).foregroundStyle(Theme.fg).lineLimit(1)
                    PanelIcon(name: .down)
                }
                .padding(.trailing, -2)
                .panelInput(focused: false, editable: true)
                .contentShape(Rectangle())
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        } else {
            HStack(spacing: 7) {
                dot
                Text(cal?.title ?? "Calendar").font(.ui(12.5)).foregroundStyle(Theme.fg).lineLimit(1)
                HStack(spacing: 4) {
                    PanelIcon(name: .lock)
                    Text("read-only").font(.ui(11)).foregroundStyle(Theme.fg3)
                }
                .padding(.leading, 6)
            }
            .frame(height: 28)
        }
    }

    // MARK: Foot

    private func foot(border: Bool) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                PanelKbd(text: "esc")
                Text("Discard").font(.ui(11.5)).foregroundStyle(Theme.fg3)
            }
            .contentShape(Rectangle())
            .onTapGesture { model.discardDraft() }
            Spacer(minLength: 0)
            PanelFillButton(title: "Save", key: "\u{21A9}") { model.saveDraft() }
        }
        .padding(.top, border ? 10 : 0)
        .overlay(alignment: .top) { if border { Hairline() } }
    }

    // MARK: Actions

    /// Return in a single-line field: saves the new event, or leaves the field.
    private func submit() {
        if model.isDraftOpen { model.saveDraft() } else { focus = nil }
    }

    private func add(_ f: PanelField) {
        model.addPanelField(f)
        let target: PanelFocus? = switch f {
        case .place: .place
        case .guests: model.store.canEditParticipants ? .guest : nil
        case .notes: .notes
        case .video: model.canInventVideoLink ? nil : .video
        }
        if let target { after(0.02) { focus = target } }
    }
}

/// A freshly inserted panel must not steal the keyboard: SwiftUI focuses the first text field of a new hierarchy on macOS, which would
/// swallow single-key shortcuts (Delete, T, J ...). Resign it shortly after insertion unless a new event asked for title focus.
struct ResignFocusOnInsert: NSViewRepresentable {
    let skip: () -> Bool
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        for delay in [0.0, 0.03, 0.09, 0.18] {
            after(delay) { [weak v] in
                guard !skip(), let w = v?.window, w.firstResponder is NSText else { return }
                w.makeFirstResponder(nil)
            }
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
