import SwiftUI
import AppKit
import CalendrKit

/// The event in the right column (design/mockup-v4 `detail()`): a 20 pt icon column (x 20 to 36) and a text column from 48, 20 pt
/// line boxes in 32 pt rows; fields and hover boxes bleed 8 pt. Every row is always there (`EditorRows`); an empty one shows its
/// placeholder in fg3. Order: title, when, repeat, "Find a new time", participants, Going?, call, location, notes, calendar, reminders.
/// While `draftEventID` is the selected event it is the new event: title focused, the foot (`PanelFoot`) has Discard and Save.
struct PanelDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let e: CalendarEvent
    @FocusState private var focus: PanelFocus?

    var body: some View {
        let canEdit = model.editorCanEdit(e)
        let rows = EditorRows.rows(model.editorContext(e))
        VStack(alignment: .leading, spacing: 0) {
            top(canEdit: canEdit)
            ForEach(rows.filter { $0 != .title }, id: \.self) { r in
                if r == .participants || r == .calendar { EditorRule() }
                row(r, canEdit: canEdit).tourAnchor("row:\(r.rawValue)")
            }
        }
        .padding(.top, 12).padding(.leading, 20).padding(.trailing, 14).padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear { if model.titleFocusPending { focus = .title } }
        .onChange(of: model.focusTitleTick) { _, _ in if model.titleFocusPending { focus = .title } }
        // Esc itself is KeyRouter's: it leaves the field and peels one layer (`escapeOneLayer`).
        .onChange(of: model.blurTick) { _, _ in focus = nil }
        .onChange(of: model.panelMenus.focusTick) { _, _ in focus = model.panelMenus.focusRequest }
        .onChange(of: focus) { old, new in
            if old == .place && new != .place, model.panelMenus.open == .places || model.panelMenus.open == .maps {
                after(0.15) { if focus != .place && (model.panelMenus.open == .places) { model.closePanelMenu() } }
            }
        }
        .background(ResignFocusOnInsert(skip: { model.titleFocusPending }))
    }

    // MARK: Title

    private func top(canEdit: Bool) -> some View {
        let bar = Palettes.cc(model.hexColor(of: e), dark: scheme == .dark).color
        return HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: Radius.bar).fill(bar).frame(width: 3, height: 22).padding(.leading, 6.5).padding(.trailing, 14.5)
            Group {
                if canEdit {
                    TextField("", text: Binding(get: { model.selectedEvent?.title ?? "" }, set: { model.setSelectedTitle($0) }), prompt: nil)
                        .textFieldStyle(.plain)
                        .panelPlaceholder(model.isDraftOpen ? "New event" : "(No title)", when: e.title.isEmpty, font: .title18)
                        .focused($focus, equals: .title)
                        .onSubmit { model.isDraftOpen ? model.saveDraft() : (focus = nil) }
                        .editorField(focused: focus == .title, editable: true, key: "field:title")
                } else {
                    Text(e.title.isEmpty ? "(No title)" : e.title).lineLimit(1).truncationMode(.tail)
                }
            }
            .font(.title18).tracking(-0.27).foregroundStyle(Theme.fg)
            .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
            if model.isWritable(e) && !model.isDraftOpen { PanelIconButton(icon: .trash) { model.requestDeleteSelected() }.help("Delete event  \u{232B}") }
            PanelIconButton(icon: .x) { model.closePanel() }.help("Close  esc")
        }
        .frame(height: 26)
        .padding(.bottom, 8)
        .tourAnchor("row:title")
    }

    // MARK: Rows

    @ViewBuilder
    private func row(_ r: EditorRow, canEdit: Bool) -> some View {
        switch r {
        case .title: EmptyView()
        case .when:
            EditorRowBox(icon: .clock) {
                VStack(alignment: .leading, spacing: 0) {
                    when(canEdit: canEdit)
                    if canEdit { PanelSwitch(label: "All day", isOn: e.isAllDay) { model.setSelectedAllDay(!e.isAllDay) }.frame(height: 20).padding(.top, 6).padding(.bottom, 4) }
                }
            }
        case .repeats:
            EditorRowBox(icon: .repeats) {
                let text = PanelText.editorRepeats(e, model.fmt)
                Text(text ?? EditorRow.repeats.placeholder!).foregroundStyle(text == nil ? Theme.fg3 : Theme.fg).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .findTime:
            EditorRowBox(icon: .sparkle) {
                Button { model.findNewTime() } label: {
                    Text("Find a new time").foregroundStyle(Theme.fg2).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .editorField(focused: false, editable: true, key: "field:findTime")
            }
        case .participants:
            EditorRowBox(icon: .users) { PanelParticipants(e: e, canEdit: canEdit, focus: $focus) }
        case .going:
            EditorRowBox(icon: .reply) { PanelGoingRow(e: e) }
        case .call:
            let hasCall = !e.conferencing.isEmpty || CallLink.parse(e) != nil || model.panelState.newMeet.contains(e.id)
            EditorRowBox(icon: .video, tall: hasCall) { PanelCallRow(e: e, canEdit: canEdit, focus: $focus) }
        case .location:
            EditorRowBox(icon: .pin) { PanelLocationRow(e: e, canEdit: canEdit, focus: $focus) }
        case .notes:
            EditorRowBox(icon: .notes) { notes(canEdit: canEdit) }
        case .calendar:
            EditorRowBox(icon: .calendar) { calendar() }
        case .reminders:
            EditorRowBox(icon: .bell) { PanelReminders(e: e) }
        }
    }

    /// Date, start → end, length. All-day events show the date and "all day" (or "3 days").
    private func when(canEdit: Bool) -> some View {
        let m = model.math
        let days = e.isAllDay ? max(1, m.daysBetween(e.start, e.end)) : 1
        let dateText = days > 1 ? "\(PanelText.day(e.start, model.fmt)) \u{2013} \(PanelText.day(m.addDays(e.start, days - 1), model.fmt))" : PanelText.day(e.start, model.fmt)
        return HStack(spacing: 0) {
            PanelCommitField(value: dateText, minWidth: 84, editable: canEdit && days == 1, focusKey: .date, focus: $focus,
                             commit: { model.setSelectedDay($0) }, onReturn: submit)
            if !e.isAllDay {
                Color.clear.frame(width: 4, height: 1)
                PanelCommitField(value: model.fmt.time(e.start), width: 52, centered: true, tabular: true, editable: canEdit, focusKey: .start, focus: $focus,
                                 commit: { t in TimeParser.parse(t).map { model.setSelectedStart($0); return true } ?? false }, onReturn: submit)
                PanelIcon(name: .arrow).frame(width: 16)
                PanelCommitField(value: model.fmt.time(e.end), width: 52, centered: true, tabular: true, editable: canEdit, focusKey: .end, focus: $focus,
                                 commit: { t in TimeParser.parse(t).map { model.setSelectedEnd($0) } ?? false }, onReturn: submit)
            }
            Text(e.isAllDay ? (days > 1 ? "\(days) days" : "all day") : PanelText.editorDuration(e.durationMinutes))
                .font(.smallTab).foregroundStyle(Theme.fg3).lineLimit(1).fixedSize().padding(.leading, 8)
        }
        .fixedSize()
        .frame(height: 26)
    }

    /// The notes (Return adds a line), 18.75 pt lines. A text until clicked, then a field. Google's Meet block is hidden: one line says so.
    private func notes(canEdit: Bool) -> some View {
        let v = MeetNotes.visible(e.notes)
        let editing = focus == .notes
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if editing {
                    TextField("", text: Binding(get: { MeetNotes.visible(model.selectedEvent?.notes ?? "").text }, set: { model.setSelectedNotes($0) }), axis: .vertical)
                        .textFieldStyle(.plain).font(.text).foregroundStyle(Theme.fg).lineLimit(1...14)
                        .focused($focus, equals: .notes)
                } else {
                    Text(v.text.isEmpty ? EditorRow.notes.placeholder! : v.text).font(.text).foregroundStyle(v.text.isEmpty ? Theme.fg3 : Theme.fg)
                        .lineSpacing(3.75).fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, -1.9)
                        .contentShape(Rectangle())
                        .onTapGesture { if canEdit { focus = .notes } }
                    // keeps the focus target alive so a click can move the keyboard here
                    TextField("", text: .constant("")).focused($focus, equals: .notes).opacity(0).frame(width: 1, height: 1).allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 20, alignment: .topLeading)
            .editorField(focused: editing, editable: canEdit, key: "field:notes")
            if v.hidden {
                HStack(spacing: 10) {
                    CallLogo(kind: .meet, size: 12)
                    Text("Google Meet details hidden").font(.small).foregroundStyle(Theme.fg3)
                }
                .frame(height: 20)
                .padding(.top, 10)
                .help("Google's joining instructions are in the notes. Calendr shows the call above.")
            }
        }
    }

    /// `.calsel`: the event's colour, the calendar's name, a chevron; opens the calendar and colour menu. Under it availability and
    /// visibility (`.pair`).
    private func calendar() -> some View {
        let cal = model.calendarInfo(e.calendarID)
        let writable = model.isWritable(e)
        return VStack(alignment: .leading, spacing: 0) {
            Button { if writable { model.openPanelMenu(.calendar) } } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: Radius.swatch).fill(Palettes.cc(model.hexColor(of: e), dark: scheme == .dark).color).frame(width: 12, height: 12)
                    Text(cal?.title ?? "Calendar").foregroundStyle(Theme.fg).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    if writable { PanelIcon(name: .down, size: 12) } else {
                        HStack(spacing: 4) { PanelIcon(name: .lock); Text("read-only").font(.small).foregroundStyle(Theme.fg3) }
                    }
                }
                .padding(.leading, 8).padding(.trailing, 13)
                .frame(height: Dim.field)
                .background(HoverFill(key: "field:calendar", on: model.panelMenus.open == .calendar, enabled: writable, fill: Theme.bg2, radius: Radius.control))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .panelMenuAnchor(.calendar)
            .tourAnchor("field:calendar")
            .padding(.horizontal, -8).padding(.top, -5)
            HStack(spacing: 22) {
                Menu {
                    ForEach(Availability.allCases, id: \.self) { a in Button(a == .busy ? "Busy" : "Free") { model.updateSelected { $0.availability = a } } }
                } label: { pairLabel(e.availability == .busy ? "Busy" : "Free", key: "field:busy") }
                Menu {
                    ForEach(EventVisibility.allCases, id: \.self) { v in Button(Self.visibility(v)) { model.updateSelected { $0.visibility = v } } }
                } label: { pairLabel(Self.visibility(e.visibility), key: "field:vis") }
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .disabled(!writable)
            .padding(.top, 6)
        }
    }

    static func visibility(_ v: EventVisibility) -> String {
        switch v {
        case .standard: "Default visibility"
        case .public: "Public"
        case .private: "Private"
        }
    }

    private func pairLabel(_ text: String, key: String) -> some View {
        HStack(spacing: 4) { Text(text).foregroundStyle(Theme.fg); PanelIcon(name: .down, size: 12) }
            .frame(minHeight: 20)
            .editorField(focused: false, editable: true, key: key)
    }

    /// Return in a single-line field: saves the new event, or leaves the field.
    private func submit() {
        if model.isDraftOpen { model.saveDraft() } else { focus = nil }
    }
}

// MARK: Row and field chrome

/// `.prow`: the icon (16, fg3) at the left edge, 8 pt down (14 next to the big Join button); the content from 48 with 6 above and below.
struct EditorRowBox<Content: View>: View {
    let icon: PanelIcon.Name
    var tall = false
    @ViewBuilder var content: Content
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PanelIcon(name: icon, size: 16).padding(.top, tall ? 14 : 8)
            content.padding(.vertical, 6).frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
        }
        .frame(minHeight: 32, alignment: .top)
    }
}

/// `.hr` inside the editor.
struct EditorRule: View {
    var body: some View {
        // "space instead of boxes" (mockup `po-quiet`): the rule is space only, 4 above and below.
        Color.clear.frame(height: 1).padding(.vertical, 4)
    }
}

/// A hover (or open) fill. `key` lets the walkthrough name it (`HoverProbe`).
struct HoverFill: View {
    var key: String = ""
    var on = false
    var enabled = true
    var fill: Color = Theme.hover
    var radius: CGFloat = Radius.row
    @State private var hover = false
    var body: some View {
        let h = enabled && (on || hover || (!key.isEmpty && HoverProbe.shared.target == key))
        RoundedRectangle(cornerRadius: radius).fill(h ? fill : Color.clear)
            .onHover { hover = $0 }
            .animation(Motion.fast, value: h)
    }
}

/// `.in` / `.fld`: looks like text until hovered (wash) or focused (window colour, 1.5 pt fg3 ring); radius 6, 8 pt side and 3 pt
/// top and bottom padding that hang outside the text column.
struct EditorFieldChrome: ViewModifier {
    var focused: Bool
    var editable: Bool
    var key = ""
    /// Its menu is open: the hover wash stays.
    var held = false
    @State private var hover = false
    func body(content: Content) -> some View {
        let h = editable && (held || hover || (!key.isEmpty && HoverProbe.shared.target == key))
        content
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: Radius.row).fill(focused && editable ? Theme.bg : (h ? Theme.hover : Color.clear)))
            .overlay(RoundedRectangle(cornerRadius: Radius.row).strokeBorder(focused && editable ? Theme.fg3 : Color.clear, lineWidth: 1.5))
            .padding(.horizontal, -8).padding(.vertical, -3)
            .onHover { hover = $0 }
            .animation(Motion.fast, value: h)
            .animation(Motion.fast, value: focused)
            .tourAnchor(key)
    }
}

extension View {
    func editorField(focused: Bool, editable: Bool, key: String = "", held: Bool = false) -> some View {
        modifier(EditorFieldChrome(focused: focused, editable: editable, key: key, held: held))
    }
}

// MARK: Going?, reminders

/// Going? Yes · Maybe · No. Read-only (the answer as text) when the store cannot write my reply (EventKit).
struct PanelGoingRow: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    var body: some View {
        HStack(spacing: 10) {
            Text("Going?").foregroundStyle(Theme.fg3)
            if model.canRespond {
                Segmented(options: [(ResponseStatus.confirmed, "Yes"), (.tentative, "Maybe"), (.declined, "No")], selection: e.myReply,
                          enabled: !e.iAmOrganizer) { model.setMyReply($0) }
            } else {
                Text(PanelText.response(e.myReply)).foregroundStyle(Theme.fg)
                    .help("macOS Calendar cannot send your reply. Answer in Google Calendar.")
            }
        }
        .frame(minHeight: 20)
    }
}

/// One row per reminder ("10 min before", the remove button on hover), then "Add reminder" (the menu of choices).
struct PanelReminders: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    var body: some View {
        let writable = model.isWritable(e)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(e.reminders, id: \.self) { r in ReminderRow(minutes: r, removable: writable) }
            if writable {
                Button { model.openPanelMenu(.reminders) } label: {
                    Text(EditorRow.reminders.placeholder!).foregroundStyle(Theme.fg3).frame(maxWidth: .infinity, minHeight: 20, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .editorField(focused: false, editable: true, key: "field:addReminder", held: model.panelMenus.open == .reminders)
                .panelMenuAnchor(.reminders)
                .padding(.top, e.reminders.isEmpty ? 0 : 7)
            } else if e.reminders.isEmpty {
                Text("No reminder").foregroundStyle(Theme.fg3)
            }
        }
    }
}

struct ReminderRow: View {
    @Environment(AppModel.self) private var model
    let minutes: Int
    let removable: Bool
    @State private var hover = false
    var body: some View {
        let key = "rem:\(minutes)"
        let h = hover || HoverProbe.shared.target == key
        HStack(spacing: 4) {
            Text(Reminders.amount(minutes)).font(.textTab).foregroundStyle(Theme.fg)
            if minutes > 0 { Text("before").foregroundStyle(Theme.fg3) }
            Spacer(minLength: 0)
            if removable {
                Button { model.removeReminder(minutes) } label: {
                    PanelIcon(name: .x, size: 11, color: Theme.fg2).frame(width: 20, height: 20)
                        .background(RoundedRectangle(cornerRadius: Radius.row).fill(Theme.hover)).contentShape(Rectangle())
                }
                .buttonStyle(.plain).help("Remove").opacity(h ? 1 : 0)
            }
        }
        .padding(.horizontal, 8).frame(height: 28)
        .background(RoundedRectangle(cornerRadius: Radius.row).fill(h && removable ? Theme.hover : Color.clear))
        .padding(.horizontal, -8).padding(.vertical, -3)
        .onHover { hover = $0 }
        .tourAnchor(key)
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
