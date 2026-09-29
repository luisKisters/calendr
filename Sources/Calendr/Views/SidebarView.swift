import SwiftUI
import CalendrKit

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var meetFocused: Bool

    var body: some View {
        @Bindable var m = model
        VStack(spacing: 0) {
            // Titlebar: the real traffic lights sit at the leading edge; the sidebar toggle follows them.
            ZStack(alignment: .topLeading) {
                IconButton(name: "sidebar.left", size: 16) { model.toggleSidebar() }.position(x: 98, y: 26)
            }
            .frame(height: 52)

            HStack(spacing: 0) {
                Wordmark()
                Spacer(minLength: 0)
                IconButton(name: "magnifyingglass", size: 14, box: 26) { model.handle(.focusSearch) }
                IconButton(name: "square.and.pencil", size: 14, box: 26) { model.handle(.createEvent) }
            }
            .padding(.leading, 16).padding(.trailing, 12).frame(height: 36)

            MiniCalendar().padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 6)

            SidebarRow(icon: "link", title: "Scheduling", trailingIcon: "eye") { model.perform(.oneOffLink) }

            // Meet with field: focus is act, never a system ring.
            HStack(spacing: 8) {
                SFIcon(name: "person", size: 13, color: Theme.haze).frame(width: 16)
                TextField("", text: $m.meetQuery, prompt: Text("Meet with\u{2026}").foregroundStyle(Theme.hazeDim))
                    .textFieldStyle(.plain).font(.system(size: 13)).foregroundStyle(Theme.paper)
                    .focused($meetFocused)
                    .onSubmit { pickMeet() }
                Keycap(text: "F")
            }
            .padding(.leading, 10).padding(.trailing, 8).frame(height: 30)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Theme.ink700))
            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(meetFocused ? Theme.act : Theme.hair, lineWidth: meetFocused ? 1.5 : 1))
            .animation(Motion.base, value: meetFocused)
            .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 6)
            .onChange(of: model.focusMeetTick) { _, _ in meetFocused = true }
            .onChange(of: model.blurTick) { _, _ in meetFocused = false }
            .overlay(alignment: .topLeading) {
                if !model.meetQuery.trimmingCharacters(in: .whitespaces).isEmpty { MeetResults().offset(x: 10, y: 40) }
            }
            .zIndex(2)

            if model.authState != .authorized {
                SidebarSkeleton()
                Spacer(minLength: 0)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    CalendarList().padding(.bottom, 56)
                }
            }
        }
        .frame(width: Theme.sidebarWidth)
        .background(Theme.ink800)
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [Theme.ink800.opacity(0), Theme.ink800], startPoint: .top, endPoint: .init(x: 0.5, y: 0.55)).frame(height: 56).allowsHitTesting(false)
        }
        .overlay(alignment: .bottomLeading) { ShortcutsButton().padding(.leading, 12).padding(.bottom, 12) }
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.hair).frame(width: 1) }
        .overlay(alignment: .bottomLeading) {
            if model.notionPopoverVisible { NotionPopover().padding(.leading, 30).padding(.bottom, 56) }
        }
    }

    private func pickMeet() {
        let list = model.filteredTeammates(model.meetQuery)
        guard !list.isEmpty else { return }
        model.showTeammate(list[min(model.meetIndex, list.count - 1)])
        model.meetQuery = ""
    }
}

struct ShortcutsButton: View {
    @Environment(AppModel.self) private var model
    @State private var hover = false
    var body: some View {
        Button { model.handle(.showShortcuts) } label: {
            HStack(spacing: 7) {
                SFIcon(name: "questionmark.circle", size: 14, color: hover ? Theme.paper : Theme.haze)
                Text("Shortcuts").font(.system(size: 12.5, weight: .medium)).foregroundStyle(hover ? Theme.paper : Theme.haze)
                Keycap(text: "?")
            }
            .padding(.leading, 8).padding(.trailing, 6).frame(height: 28)
            .background(Capsule().fill(hover ? Theme.ink600 : Theme.ink700))
            .overlay(Capsule().strokeBorder(Theme.hair, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

/// Shown while there is no calendar access.
struct SidebarSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach([132, 96, 118], id: \.self) { w in
                RoundedRectangle(cornerRadius: 5).fill(Theme.hair).frame(width: CGFloat(w), height: 10).padding(.bottom, 9)
            }
            Text("Your calendars appear here once Calendr can read them.").font(.system(size: 12)).foregroundStyle(Theme.haze).lineSpacing(3).padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(Theme.ink700))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Theme.hair, lineWidth: 1))
        .padding(.horizontal, 14).padding(.top, 8)
    }
}

struct SidebarRow: View {
    let icon: String
    let title: String
    var trailingIcon: String?
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SFIcon(name: icon, size: 14, color: Theme.haze).frame(width: 16)
                Text(title).font(.system(size: 13)).foregroundStyle(Theme.haze)
                Spacer(minLength: 0)
                if let t = trailingIcon { SFIcon(name: t, size: 12, color: Theme.hazeDim) }
            }
            .padding(.leading, 16).padding(.trailing, 14)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 8).fill(hover ? Theme.hover : Color.clear))
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

/// Weekday row + six week rows in one Canvas with cached CoreText lines; a single tap gesture picks the cell.
/// The visible week is a full-row `act` wash, today a filled act square with a soft halo.
struct MiniCalendar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    static let width: CGFloat = Theme.sidebarWidth - 20
    static let rowHeight: CGFloat = 27
    static let headerHeight: CGFloat = 22

    var body: some View {
        let grid = model.math.monthGrid(for: model.miniMonth)
        let first = model.math.calendar.firstWeekday
        let bandStart = model.viewMode == .month ? nil : model.math.startOfWeek(model.visibleStart)
        let miniMonth = model.miniMonth
        let now = model.now
        let math = model.math
        let dark = scheme == .dark
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                (Text(model.fmt.monthLong(miniMonth)).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.paper)
                 + Text(" ").font(.system(size: 13))
                 + Text(String(math.year(miniMonth))).font(.calMono(13, .medium)).foregroundColor(Theme.haze))
                Spacer(minLength: 0)
                IconButton(name: "chevron.up", size: 12, box: 24) { model.stepMiniMonth(-1) }
                IconButton(name: "chevron.down", size: 12, box: 24) { model.stepMiniMonth(1) }
            }
            .padding(.horizontal, 6).frame(height: 26)

            Canvas { ctx, size in
                let ink = EventPainter.Ink.of(dark)
                ctx.withCGContext { cg in
                    let colW = size.width / 7
                    for i in 0..<7 {
                        let s = Fmt.weekdayShort[(first - 1 + i) % 7].prefix(2).uppercased()
                        let w = TextCache.line(s, .micro).width + 0.6 * 2
                        _ = EventPainter.text(cg, s, .micro, x: (CGFloat(i) + 0.5) * colW - w / 2, top: 0, box: Self.headerHeight, color: ink.hazeDim)
                    }
                    for r in 0..<6 {
                        let y = Self.headerHeight + CGFloat(r) * Self.rowHeight
                        let isBand = bandStart.map { math.isSameDay($0, grid[r][0]) } ?? false
                        if isBand {
                            cg.addPath(EventPainter.roundedPath(CGRect(x: 0, y: y, width: size.width, height: Self.rowHeight), Radius.control))
                            cg.setFillColor(ink.actWash); cg.fillPath()
                        }
                        for col in 0..<7 {
                            let d = grid[r][col]
                            let today = math.isSameDay(d, now)
                            let cx = (CGFloat(col) + 0.5) * colW
                            if today {
                                let halo = CGRect(x: cx - 12, y: y + 2.5, width: 24, height: 22)
                                cg.addPath(EventPainter.roundedPath(halo.insetBy(dx: -3, dy: -3), 10)); cg.setFillColor(ink.act.copy(alpha: 0.18) ?? ink.act); cg.fillPath()
                                cg.addPath(EventPainter.roundedPath(halo, 7)); cg.setFillColor(ink.act); cg.fillPath()
                            }
                            let other = !math.isSameMonth(d, miniMonth)
                            let color = today ? CGColor(gray: 1, alpha: 1) : other ? ink.hazeDim : ink.paper
                            let s = "\(math.day(d))"
                            let w = TextCache.line(s, .dayNum).width
                            _ = EventPainter.text(cg, s, .dayNum, x: cx - w / 2, top: y, box: Self.rowHeight, color: color)
                        }
                    }
                }
            }
            .frame(width: Self.width, height: Self.headerHeight + 6 * Self.rowHeight)
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { p in
                let r = Int((p.y - Self.headerHeight) / Self.rowHeight), c = Int(p.x / (Self.width / 7))
                if (0..<6).contains(r), (0..<7).contains(c) { model.go(to: grid[r][c]) }
            }
        }
    }
}

struct CalendarList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !model.shownTeammates.isEmpty {
                AccountLabel(text: "Teammates")
                ForEach(model.shownTeammates) { t in
                    TeammateRow(t: t)
                }
            }
            ForEach(model.store.accounts) { acc in
                AccountLabel(text: acc.name)
                ForEach(acc.calendars) { c in CalendarRow(cal: c) }
            }
            SidebarLinkRow(icon: "plus", title: "Add calendar account") { model.addCalendarAccount() }.padding(.top, 10)
        }
        .frame(width: Theme.sidebarWidth - 1, alignment: .leading)
    }
}

struct AccountLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11.5)).foregroundStyle(Theme.hazeDim).lineLimit(1).truncationMode(.tail)
            .padding(.leading, 22).padding(.trailing, 14).padding(.top, 14).padding(.bottom, 4)
    }
}

struct SidebarLinkRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SFIcon(name: icon, size: 13, color: Theme.hazeDim).frame(width: 16)
                Text(title).font(.system(size: 13)).foregroundStyle(hover ? Theme.paper : Theme.haze)
                Spacer(minLength: 0)
            }
            .padding(.leading, 16).frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 8).fill(hover ? Theme.hover : Color.clear))
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

/// Calendar checkbox: 14 pt rounded square, full calendar color when on, hollow when hidden.
struct CalendarCheckbox: View {
    let color: Color
    let on: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(on ? color : Color.clear)
            RoundedRectangle(cornerRadius: 5).strokeBorder(on ? color : Theme.hazeDim, lineWidth: 1.5)
            Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)).foregroundStyle(Color(hex: "#0F0E14")).opacity(on ? 1 : 0)
        }
        .frame(width: 14, height: 14)
        .animation(Motion.fast, value: on)
    }
}

struct CalendarRow: View {
    @Environment(AppModel.self) private var model
    let cal: CalendarInfo
    @State private var hover = false
    var body: some View {
        let off = model.hiddenCalendars.contains(cal.id)
        Button { model.toggleCalendar(cal.id) } label: {
            HStack(spacing: 10) {
                CalendarCheckbox(color: Color(hex: cal.colorHex), on: !off)
                Text(cal.title).font(.system(size: 13)).foregroundStyle(off ? Theme.hazeDim : Theme.paper).lineLimit(1)
                Spacer(minLength: 4)
                if off { SFIcon(name: "eye.slash", size: 12, color: Theme.hazeDim) }
                else if cal.isDefault { Text("Default").font(.system(size: 11.5)).foregroundStyle(Theme.hazeDim) }
            }
            .padding(.leading, 16).padding(.trailing, 14)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 8).fill(hover ? Theme.hover : Color.clear))
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

struct TeammateRow: View {
    @Environment(AppModel.self) private var model
    let t: Teammate
    var body: some View {
        HStack(spacing: 10) {
            CalendarCheckbox(color: Color(hex: model.teammateColor(t.email)), on: true)
            Text(t.name).font(.system(size: 13)).foregroundStyle(Theme.paper).lineLimit(1)
            Spacer(minLength: 4)
            IconButton(name: "xmark", size: 9, box: 20) { model.removeTeammate(t) }
        }
        .padding(.leading, 24).padding(.trailing, 20).frame(height: 28)
    }
}

struct MeetResults: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let list = Array(model.filteredTeammates(model.meetQuery).prefix(6))
        VStack(alignment: .leading, spacing: 0) {
            if list.isEmpty { Text("No teammates found").font(.system(size: 13)).foregroundStyle(Theme.haze).padding(10) }
            ForEach(Array(list.enumerated()), id: \.element.id) { i, t in
                Button { model.showTeammate(t); model.meetQuery = "" } label: {
                    HStack(spacing: 6) {
                        Text(t.name).font(.system(size: 13)).foregroundStyle(Theme.paper).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10).frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 8).fill(i == model.meetIndex ? Theme.actWash : Color.clear))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(width: Theme.sidebarWidth - 20)
        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.ink700))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.hairStrong, lineWidth: 1))
        .popShadow()
        .transition(.opacity.combined(with: .offset(y: -4)))
    }
}

struct NotionPopover: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notion is not connected").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.paper)
            Text("Notion databases are not available in Calendr yet.").font(.system(size: 12)).foregroundStyle(Theme.haze).fixedSize(horizontal: false, vertical: true)
            Button("Not connected") { model.notionPopoverVisible = false }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Theme.actLift).padding(.top, 4)
        }
        .padding(12).frame(width: 190, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.ink700))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.hairStrong, lineWidth: 1))
        .popShadow()
    }
}
