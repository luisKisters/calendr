import SwiftUI
import AppKit
import CalendrKit

struct RightPanelView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.ink800
            if model.selectedEvent != nil {
                InspectorView()
                    .id(model.selectedEventID)
                    .transition(.modifier(active: SlideFade(x: 28, opacity: 0), identity: SlideFade(x: 0, opacity: 1)))
            } else {
                DefaultPanel()
                    .transition(.opacity)
            }
        }
        .animation(Motion.slow, value: model.selectedEvent == nil)
        .animation(Motion.base, value: model.selectedEventID)
        .frame(width: Theme.rightPanelWidth)
        .clipped()
        .overlay(alignment: .leading) { Rectangle().fill(Theme.hair).frame(width: 1) }
    }
}

struct PanelToggle: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        IconButton(name: "sidebar.right", size: 15) { model.toggleRightPanel() }
    }
}

struct DefaultPanel: View {
    @Environment(AppModel.self) private var model
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var m = model
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    SFIcon(name: "magnifyingglass", size: 13, color: Theme.haze).frame(width: 16)
                    TextField("", text: $m.searchText, prompt: Text("Search events").foregroundStyle(Theme.hazeDim))
                        .textFieldStyle(.plain).font(.system(size: 13)).foregroundStyle(Theme.paper)
                        .focused($searchFocused)
                        .onSubmit { if let e = model.searchGroups.first?.events.first { model.openSearchResult(e) } }
                    Keycap(text: "/")
                }
                .padding(.leading, 10).padding(.trailing, 6).frame(height: 30)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(Theme.ink700))
                .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(searchFocused ? Theme.act : Theme.hair, lineWidth: searchFocused ? 1.5 : 1))
                .animation(Motion.base, value: searchFocused)
                PanelToggle()
            }
            .padding(.leading, 16).padding(.trailing, 12).frame(height: Theme.toolbarHeight)
            .onChange(of: model.focusSearchTick) { _, _ in searchFocused = true }
            .onChange(of: model.blurTick) { _, _ in searchFocused = false }

            if model.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    if model.authState == .authorized, let next = model.upcoming.next { UpNextCard(event: next).padding(.bottom, 14) }
                    MicroLabel(text: "Useful shortcuts").padding(.top, 10).padding(.bottom, 6)
                    ShortcutRow("Command menu", ["\u{2318}", "K"])
                    ShortcutRow("Menu bar calendar", ["control", "\u{2318}", "K"])
                    ShortcutRow("Toggle sidebar", ["`"])
                    ShortcutRow("Show teammate calendar", ["P"])
                    ShortcutRow("Go to date", ["."])
                    ShortcutRow("All keyboard shortcuts", ["?"])
                }
                .padding(.horizontal, 16).padding(.top, 6)
            } else {
                SearchResults()
            }
            Spacer(minLength: 0)
        }
        .frame(width: Theme.rightPanelWidth, alignment: .topLeading)
    }
}

/// The next event, lifted into a card: 3 pt calendar-colored bar, imminence in the label.
struct UpNextCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let event: CalendarEvent
    @State private var hover = false
    var body: some View {
        let pal = Palettes.palette(barHex: model.calendarColorHex(of: event), fillHex: nil, dark: scheme == .dark)
        let until = model.upcoming.untilNext
        Button { model.openSearchResult(event) } label: {
            VStack(alignment: .leading, spacing: 0) {
                MicroLabel(text: until == "now" ? "Up next \u{00B7} now" : "Up next \u{00B7} in \(until.replacingOccurrences(of: "min", with: " min"))")
                Text(event.title).font(.system(size: 14, weight: .semibold)).tracking(-0.1).foregroundStyle(Theme.paper).lineLimit(1).padding(.top, 5).padding(.bottom, 3)
                Text(model.fmt.timeRange(event.start, event.end)).font(.calMono(12)).foregroundStyle(Theme.haze)
            }
            .padding(.leading, 16).padding(.trailing, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(hover ? Theme.ink600 : Theme.ink700))
            .overlay(alignment: .leading) { Rectangle().fill(pal.bar).frame(width: 3) }
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Theme.hair, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

struct ShortcutRow: View {
    let title: String
    let keys: [String]
    @State private var hover = false
    init(_ t: String, _ k: [String]) { title = t; keys = k }
    var body: some View {
        HStack {
            Text(title).font(.system(size: 13)).foregroundStyle(hover ? Theme.paper : Theme.haze)
            Spacer()
            Keycaps(keys: keys)
        }
        .padding(.horizontal, 8).frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 8).fill(hover ? Theme.hover : Color.clear))
        .padding(.horizontal, -8)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

struct SearchResults: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        if model.searchGroups.isEmpty {
            VStack(spacing: 6) {
                EmptyArt(kind: .search, size: 64).padding(.bottom, 10)
                Text("No events match \u{201C}\(model.searchText)\u{201D}").font(.system(size: 15, weight: .semibold)).tracking(-0.2).foregroundStyle(Theme.paper).multilineTextAlignment(.center)
                Text("Try a title, a place or a calendar name.\nSearch covers every visible calendar.").font(.system(size: 12.5)).foregroundStyle(Theme.haze).multilineTextAlignment(.center).lineSpacing(3)
                PrimaryButton(title: "Clear search") { model.searchText = "" }.padding(.top, 12)
            }
            .padding(.horizontal, 24).padding(.top, 40).frame(maxWidth: .infinity)
            .transition(.opacity)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.searchGroups) { g in
                        let today = model.math.isSameDay(g.day, model.now)
                        MicroLabel(text: "\(model.fmt.weekdayShort(g.day)), \(model.fmt.monthDay(g.day))" + (today ? " \u{00B7} Today" : ""))
                            .padding(.horizontal, 8).padding(.top, 14).padding(.bottom, 6)
                        ForEach(g.events) { e in SearchRow(e: e) }
                    }
                }.padding(.horizontal, 8).padding(.bottom, 16)
            }
        }
    }
}

struct SearchRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let e: CalendarEvent
    @State private var hover = false
    var body: some View {
        let pal = e.kind == .task ? Palettes.gray(scheme == .dark) : Palettes.palette(barHex: model.calendarColorHex(of: e), fillHex: nil, dark: scheme == .dark)
        Button { model.openSearchResult(e) } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(pal.bar).frame(width: 3, height: 16)
                Text(e.kind == .task ? TaskTitle.split(e.title).text : e.title).font(.system(size: 13)).foregroundStyle(Theme.paper).lineLimit(1)
                Spacer(minLength: 0)
                Text(e.isAllDay ? "All day" : model.fmt.time(e.start)).font(.calMono(11)).foregroundStyle(Theme.haze)
            }
            .padding(.horizontal, 10).frame(height: 34)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(model.selectedEventID == e.id ? Theme.actWash : (hover ? Theme.hover : Color.clear)))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

// MARK: - Inspector

struct InspectorRow<Content: View>: View {
    var icon: String?
    var muted = false
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 12) {
            if let icon { SFIcon(name: icon, size: 14, color: muted ? Theme.hazeDim : Theme.haze).frame(width: 16) } else { Color.clear.frame(width: 16, height: 1) }
            content
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 34)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Mono field chip (times, date): ink-700, 26 pt, radius 7.
struct MonoField<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.font(.calMono(12.5, .medium)).foregroundStyle(Theme.paper)
            .padding(.horizontal, 8).frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 7).fill(Theme.ink700))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.hair, lineWidth: 1))
    }
}

struct InspectorView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var titleFocused: Bool

    var body: some View {
        if let e = model.selectedEvent {
            let writable = model.isWritable(e)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text(e.kind == .task ? "Task" : "Event").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.haze)
                        SFIcon(name: "chevron.down", size: 10, color: Theme.haze, weight: .semibold)
                    }.padding(.horizontal, 8).frame(height: 28)
                    Spacer(minLength: 0)
                    EventMenu(e: e, writable: writable)
                    PanelToggle()
                }
                .padding(.leading, 14).padding(.trailing, 12).frame(height: Theme.toolbarHeight)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("", text: Binding(get: { model.selectedEvent?.title ?? "" }, set: { v in model.updateSelected { $0.title = v } }), prompt: Text("New event").foregroundStyle(Theme.hazeDim))
                            .textFieldStyle(.plain).font(.system(size: 16, weight: .semibold)).tracking(-0.25).foregroundStyle(Theme.paper)
                            .focused($titleFocused)
                            .padding(.horizontal, 16).frame(height: 44)
                            .disabled(!writable)
                            .onChange(of: model.focusTitleTick) { _, _ in focusTitleIfPending() }
                            .onChange(of: model.blurTick) { _, _ in titleFocused = false }
                            .onSubmit { titleFocused = false }
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3).fill(Color(hex: model.calendarColorHex(of: e))).frame(width: 8, height: 8)
                            Text(model.calendarInfo(e.calendarID)?.title ?? "Calendar").font(.system(size: 12)).foregroundStyle(Theme.haze).lineLimit(1)
                        }.padding(.horizontal, 16).padding(.bottom, 12)
                        Section1(e: e, writable: writable)
                        Section2(e: e, writable: writable)
                        Description(e: e, writable: writable)
                        Section3(e: e, writable: writable)
                    }
                }
            }
            .frame(width: Theme.rightPanelWidth, alignment: .topLeading)
            .onAppear { focusTitleIfPending() }
            .background(ResignFocusOnInsert(skip: { model.titleFocusPending }))
        }
    }

    private func focusTitleIfPending() {
        if model.titleFocusPending { titleFocused = true }
    }
}

struct Divider0: View {
    var body: some View { Hairline() }
}

struct EventMenu: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let writable: Bool
    var body: some View {
        Menu {
            Button("Duplicate") { model.duplicateSelected() }
            Button("Copy details") { model.copySelectedDetails() }
            Divider()
            Button("Delete", role: .destructive) { model.requestDeleteSelected() }.disabled(!writable)
        } label: {
            SFIcon(name: "ellipsis", size: 14).frame(width: 28, height: 28).contentShape(Rectangle())
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
    }
}

struct Section1: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let writable: Bool
    @State private var showDate = false

    var body: some View {
        let fmt = model.fmt
        VStack(alignment: .leading, spacing: 0) {
            InspectorRow(icon: "clock") {
                HStack(spacing: 8) {
                    TimeField(minutes: model.math.minutesSinceMidnight(e.start), fmt: fmt, writable: writable && !e.isAllDay) { m in
                        model.updateSelected { ev in
                            let dur = ev.end.timeIntervalSince(ev.start)
                            ev.start = model.math.date(on: ev.start, minutes: m); ev.end = ev.start.addingTimeInterval(dur)
                        }
                    }.frame(width: 62)
                    SFIcon(name: "arrow.right", size: 11, color: Theme.hazeDim)
                    TimeField(minutes: model.math.minutesSinceMidnight(e.end), fmt: fmt, writable: writable && !e.isAllDay) { m in
                        model.updateSelected { ev in
                            var end = model.math.date(on: ev.end, minutes: m)
                            if end <= ev.start { end = ev.start.addingTimeInterval(15 * 60) }
                            ev.end = end
                        }
                    }.frame(width: 62)
                    Text(e.isAllDay ? "" : DurationText.minutes(e.durationMinutes)).font(.calMono(12)).foregroundStyle(Theme.haze)
                }
                .opacity(e.isAllDay ? 0.35 : 1)
                .animation(Motion.base, value: e.isAllDay)
            }
            InspectorRow(icon: "calendar") {
                Button { if writable { showDate = true } } label: {
                    MonoField { Text(fmt.inspectorDate(e.start)) }
                }.buttonStyle(.plain)
                .popover(isPresented: $showDate) {
                    DatePicker("", selection: Binding(get: { e.start }, set: { d in
                        model.updateSelected { ev in
                            let delta = model.math.daysBetween(ev.start, d)
                            ev.start = model.math.addDays(ev.start, delta); ev.end = model.math.addDays(ev.end, delta)
                        }
                    }), displayedComponents: .date).datePickerStyle(.graphical).labelsHidden().padding(8)
                }
            }
            InspectorRow {
                Toggle("", isOn: Binding(get: { model.selectedEvent?.isAllDay ?? false }, set: { on in
                    model.updateSelected { ev in
                        ev.isAllDay = on
                        if on { ev.start = model.math.startOfDay(ev.start); ev.end = model.math.addDays(ev.start, 1) }
                        else { ev.start = model.math.date(on: ev.start, minutes: 9 * 60); ev.end = ev.start.addingTimeInterval(Double(model.settings.defaultDurationMinutes) * 60) }
                    }
                })).toggleStyle(ActToggleStyle()).labelsHidden().disabled(!writable)
                Text("All-day").font(.system(size: 13)).foregroundStyle(Theme.paper)
            }
            InspectorRow(icon: "globe") {
                HStack(spacing: 8) {
                    Text(fmt.gmtLabel(e.start)).font(.calMono(12.5)).foregroundStyle(Theme.paper)
                    Text(fmt.timeZoneCity()).font(.system(size: 13)).foregroundStyle(Theme.haze)
                }
            }
            InspectorRow(icon: "arrow.triangle.2.circlepath") {
                if let r = e.recurrence {
                    let t = RecurrenceDescriber.describe(r, start: e.start, fmt: fmt)
                    HStack(spacing: 6) {
                        Text(t.lead).font(.system(size: 13)).foregroundStyle(Theme.paper)
                        Text(t.rest).font(.system(size: 13)).foregroundStyle(Theme.haze).lineLimit(1).truncationMode(.tail)
                    }
                } else if e.seriesID != nil {
                    Text("Repeats").font(.system(size: 13)).foregroundStyle(Theme.paper)
                } else {
                    Text("Does not repeat").font(.system(size: 13)).foregroundStyle(Theme.haze)
                }
                Spacer(minLength: 0)
                if e.isRecurring {
                    HStack(spacing: 0) {
                        IconButton(name: "chevron.left", size: 11, box: 26) { model.selectOccurrence(-1) }
                        IconButton(name: "chevron.right", size: 11, box: 26) { model.selectOccurrence(1) }
                    }.padding(.trailing, -8)
                }
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Hairline() }
    }
}

struct TimeField: View {
    let minutes: Int
    let fmt: Fmt
    let writable: Bool
    let commit: (Int) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool
    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain).font(.calMono(12.5, .medium)).foregroundStyle(Theme.paper)
            .focused($focused)
            .disabled(!writable)
            .padding(.horizontal, 8).frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 7).fill(Theme.ink700))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(focused ? Theme.act : Theme.hair, lineWidth: focused ? 1.5 : 1))
            .animation(Motion.base, value: focused)
            .onAppear { text = fmt.time(minutes: minutes) }
            .onChange(of: minutes) { _, m in if !focused { text = fmt.time(minutes: m) } }
            .onChange(of: focused) { _, f in if !f { apply() } }
            .onSubmit { apply() }
    }
    private func apply() {
        if let m = TimeParser.parse(text) { commit(m); text = fmt.time(minutes: m) } else { text = fmt.time(minutes: minutes) }
    }
}

struct Section2: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let writable: Bool
    @State private var newParticipant = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorRow(icon: "person", muted: true) {
                TextField("", text: $newParticipant, prompt: Text("Participants").foregroundStyle(Theme.hazeDim))
                    .textFieldStyle(.plain).font(.system(size: 13)).foregroundStyle(Theme.paper)
                    .disabled(!writable || !model.store.canEditParticipants)
                    .onSubmit {
                        let v = newParticipant.trimmingCharacters(in: .whitespaces)
                        guard !v.isEmpty else { return }
                        model.updateSelected { $0.participants.append(v) }; newParticipant = ""
                    }
            }
            ForEach(e.participants, id: \.self) { p in
                HStack(spacing: 6) {
                    Text(p).font(.system(size: 13)).foregroundStyle(Theme.paper).lineLimit(1)
                    Spacer()
                    if model.store.canEditParticipants && writable {
                        IconButton(name: "xmark", size: 9, box: 20) { model.updateSelected { $0.participants.removeAll { $0 == p } } }
                    }
                }.padding(.leading, 44).padding(.trailing, 12).frame(height: 26)
            }
            if !model.store.canEditParticipants && !e.participants.isEmpty {
                Text("Attendees are read-only (EventKit cannot edit them).").font(.system(size: 11)).foregroundStyle(Theme.hazeDim).padding(.leading, 44).padding(.bottom, 4)
            }
            InspectorRow(icon: "video", muted: true) {
                TextField("", text: Binding(get: { model.selectedEvent?.conferencing ?? "" }, set: { v in model.updateSelected { $0.conferencing = v } }), prompt: Text("Conferencing").foregroundStyle(Theme.hazeDim))
                    .textFieldStyle(.plain).font(.system(size: 13)).foregroundStyle(Theme.paper).disabled(!writable)
            }
            InspectorRow(icon: "waveform.and.mic", muted: true) { Text("Add AI meeting notes").font(.system(size: 13)).foregroundStyle(Theme.hazeDim) }
            LocationRow(e: e, writable: writable)
            InspectorRow(icon: "link", muted: true) { Text("Add links and attachments").font(.system(size: 13)).foregroundStyle(Theme.hazeDim) }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Hairline() }
    }
}

struct LocationRow: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let writable: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { model.openInMaps(e.location) } label: {
                SFIcon(name: "mappin.and.ellipse", size: 14, color: e.location.isEmpty ? Theme.hazeDim : Theme.haze).frame(width: 16)
            }.buttonStyle(.plain).padding(.top, 2)
            TextField("", text: Binding(get: { model.selectedEvent?.location ?? "" }, set: { v in model.updateSelected { $0.location = v } }), prompt: Text("Add location").foregroundStyle(Theme.hazeDim), axis: .vertical)
                .textFieldStyle(.plain).font(.system(size: 13)).foregroundStyle(Theme.paper).lineSpacing(3)
                .lineLimit(1...4).disabled(!writable)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .frame(minHeight: 34, alignment: .topLeading)
    }
}

struct Description: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let writable: Bool
    var body: some View {
        TextField("", text: Binding(get: { model.selectedEvent?.notes ?? "" }, set: { v in model.updateSelected { $0.notes = v } }), prompt: Text("Add description").foregroundStyle(Theme.hazeDim), axis: .vertical)
            .textFieldStyle(.plain).font(.system(size: 13)).foregroundStyle(Theme.paper).lineLimit(2...10).lineSpacing(3)
            .disabled(!writable)
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8).frame(minHeight: 82, alignment: .topLeading)
            .overlay(alignment: .top) { Hairline() }
    }
}

struct Section3: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let writable: Bool
    var body: some View {
        let cal = model.calendarInfo(e.calendarID)
        VStack(alignment: .leading, spacing: 0) {
            Menu {
                ForEach(model.store.accounts) { a in
                    Section(a.name) {
                        ForEach(a.calendars.filter(\.isWritable)) { c in
                            Button(c.title) { model.updateSelected { $0.calendarID = c.id } }
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: cal?.colorHex ?? "#6F97F0")).frame(width: 16, height: 12)
                    Text(cal?.title ?? "Calendar").font(.system(size: 13)).foregroundStyle(Theme.paper).lineLimit(1)
                    Spacer(minLength: 0)
                }.padding(.horizontal, 16).frame(height: 34).contentShape(Rectangle())
            }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).disabled(!writable)
            HStack(spacing: 8) {
                Menu {
                    Button("Busy") { model.updateSelected { $0.availability = .busy } }
                    Button("Free") { model.updateSelected { $0.availability = .free } }
                } label: { Text(e.availability == .busy ? "Busy" : "Free").font(.system(size: 13)).foregroundStyle(Theme.paper).contentShape(Rectangle()) }
                    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize().disabled(!writable)
                Menu {
                    Button("Default visibility") { model.updateSelected { $0.visibility = .standard } }
                    Button("Public") { model.updateSelected { $0.visibility = .public } }
                    Button("Private") { model.updateSelected { $0.visibility = .private } }
                } label: { Text(e.visibility == .standard ? "Default visibility" : e.visibility == .public ? "Public" : "Private").font(.system(size: 13)).foregroundStyle(Theme.haze).contentShape(Rectangle()) }
                    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize().disabled(!writable)
            }.padding(.leading, 44).frame(height: 34)
            InspectorRow(icon: "bell", muted: true) { Text("Reminders").font(.system(size: 13)).foregroundStyle(Theme.hazeDim) }
            Menu {
                ForEach([(nil, "None"), (0, "At time of event"), (1, "1 min before"), (5, "5 min before"), (10, "10 min before"), (15, "15 min before"), (30, "30 min before"), (60, "1 h before"), (1440, "1 day before")] as [(Int?, String)], id: \.1) { m, t in
                    Button(t) { model.updateSelected { $0.reminderMinutes = m } }
                }
            } label: {
                HStack(spacing: 6) {
                    if let m = e.reminderMinutes {
                        Text(m == 0 ? "At time" : Self.reminder(m)).font(.calMono(12.5)).foregroundStyle(Theme.paper)
                        Text(m == 0 ? "" : "before").font(.system(size: 13)).foregroundStyle(Theme.haze)
                    } else { Text("None").font(.system(size: 13)).foregroundStyle(Theme.hazeDim) }
                }.contentShape(Rectangle())
            }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize().padding(.leading, 44).frame(height: 34).disabled(!writable)
            if !writable {
                Text("This calendar is read-only.").font(.system(size: 11)).foregroundStyle(Theme.hazeDim).padding(.leading, 16).padding(.vertical, 6)
            }
        }
        .padding(.vertical, 8).padding(.bottom, 40)
        .overlay(alignment: .top) { Hairline() }
    }
    static func reminder(_ m: Int) -> String { m >= 1440 && m % 1440 == 0 ? "\(m / 1440) day" : (m >= 60 && m % 60 == 0 ? "\(m / 60) h" : "\(m) min") }
}

/// A freshly inserted inspector must not steal the keyboard: SwiftUI focuses the first text field of a new hierarchy on macOS, which would
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
