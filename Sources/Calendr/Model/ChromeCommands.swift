import Foundation
import AppKit
import CalendrKit

/// One row of the command menu: a command, a date to go to, an event, or a person to overlay.
struct PaletteRow: Identifiable, Equatable {
    enum Kind: Equatable {
        case command(Command)
        case date(Date)
        case event(CalendarEvent)
        case mate(Teammate)
    }
    var kind: Kind
    var title: String
    var section: String
    /// The leading icon in its 16 pt column.
    var icon: ChromeIcon.Name
    var colorHex: String?
    var sub: String?
    var keys: [String] = []
    var past = false
    /// A person whose calendar is already overlaid.
    var shown = false
    var id: String {
        switch kind {
        case .command(let c): "c:\(c.id.rawValue)"
        case .date(let d): "d:\(d.timeIntervalSince1970)|\(title)"
        case .event(let e): "e:\(e.id)"
        case .mate(let t): "m:\(t.email)"
        }
    }
    var more: Bool { if case .command(let c) = kind { return c.more }; return false }
    /// Footer hint for Return.
    var verb: String {
        switch kind {
        case .event: "Open"
        case .date: "Go"
        case .mate: shown ? "Hide" : "Overlay"
        case .command(let c): c.more ? "Continue" : "Run"
        }
    }
}

extension CommandID {
    /// The mockup's `COMMANDS[].i`.
    var icon: ChromeIcon.Name {
        switch self {
        case .newEvent: .plus
        case .today, .goToDate, .viewDay, .viewWeek, .viewMonth: .cal
        case .nextPeriod: .right
        case .previousPeriod: .left
        case .toggleSidebar: .side
        case .switchAppearance: .moon
        case .searchEvents: .search
        case .meetWith: .users
        case .undo: .ret
        case .deleteSelected: .trash
        case .settings: .gear
        case .fitWeek: .clock
        case .shortcuts: .keys
        }
    }
}

// MARK: Command menu

extension AppModel {
    func openPalette(_ mode: ChromeV3State.PaletteMode = .all) {
        let mode = mode == .meet && !store.canOverlayTeammates ? .all : mode
        chromeState.paletteMode = mode
        chromeState.paletteQuery = ""
        chromeState.paletteIndex = 0
        searchText = ""
        if mode == .meet && store.teammates.isEmpty { loadTeammates() }
        overlay = .command
    }

    /// The field's text. Events are searched through `searchText`, which loads the corpus (off the main thread for EventKit).
    func setPaletteQuery(_ q: String) {
        chromeState.paletteQuery = q
        let t = q.trimmingCharacters(in: .whitespaces)
        switch chromeState.paletteMode {
        case .search: searchText = t
        case .all: searchText = t.count > 1 ? t : ""
        case .goTo, .meet: searchText = ""
        }
    }

    /// Backspace on an empty field leaves a mode.
    func paletteBack() -> Bool {
        guard chromeState.paletteMode != .all, chromeState.paletteQuery.isEmpty else { return false }
        openPalette(.all)
        return true
    }

    func movePaletteSelection(_ d: Int) {
        let n = paletteRows.count
        guard n > 0 else { return }
        chromeState.paletteIndex = (chromeState.paletteIndex + d + n) % n
    }

    func runPaletteSelection() {
        let rows = paletteRows
        guard !rows.isEmpty else { return }
        run(rows[min(chromeState.paletteIndex, rows.count - 1)])
    }

    var paletteRows: [PaletteRow] {
        let key = PaletteCache.Key(mode: chromeState.paletteMode, query: chromeState.paletteQuery, hasSelection: selectedEventID != nil,
                                   layoutGeneration: layoutGeneration, searchText: searchText, searchHits: searchGroups.reduce(0) { $0 + $1.events.count },
                                   teammates: store.teammates.map(\.email), shown: shownTeammates.map(\.email), now: now)
        return chromeState.paletteCache.rows(for: key, build: buildPaletteRows)
    }

    private func buildPaletteRows() -> [PaletteRow] {
        let q = chromeState.paletteQuery.trimmingCharacters(in: .whitespaces)
        var out: [PaletteRow] = []
        switch chromeState.paletteMode {
        case .goTo:
            if let d = GoToDateParser.parse(q, now: now, math: math) { out.append(dateRow(d)) }
            else if q.isEmpty {
                let today = math.startOfDay(now)
                for (label, d) in [("Today", today), ("Tomorrow", math.addDays(today, 1)), ("Next week", math.addDays(math.startOfWeek(today), 7)),
                                   ("Next month", math.startOfMonth(math.addMonths(today, 1)))] {
                    var r = dateRow(d); r.title = label; r.sub = chromeDay(d); out.append(r)
                }
            }
        case .search:
            out += eventRows(q, limit: 9)
        case .meet:
            out += store.teammates.compactMap { t in (q.isEmpty ? 1 : FuzzyMatcher.rank(q, in: t.name)).map { (t, $0) } }
                .enumerated().sorted { $0.element.1 != $1.element.1 ? $0.element.1 > $1.element.1 : $0.offset < $1.offset }
                .map { _, x in
                    PaletteRow(kind: .mate(x.0), title: x.0.name, section: "People", icon: .users, colorHex: mateColorHex(x.0), sub: x.0.email,
                               shown: shownTeammates.contains(x.0))
                }
        case .all:
            let cmds = CommandRegistry.matching(q, hasSelection: selectedEventID != nil).filter { $0.id != .meetWith || store.canOverlayTeammates }
            if q.isEmpty {
                out = cmds.map { commandRow($0, section: $0.group) }
            } else {
                if let d = GoToDateParser.parse(q, now: now, math: math) { out.append(dateRow(d)) }
                out += cmds.prefix(6).map { commandRow($0, section: "Commands") }
                if q.count > 1 { out += eventRows(q, limit: 5) }
            }
        }
        // sections keep the order of their first row
        var order: [String] = []
        for r in out where !order.contains(r.section) { order.append(r.section) }
        return order.flatMap { s in out.filter { $0.section == s } }
    }

    private func commandRow(_ c: Command, section: String) -> PaletteRow {
        PaletteRow(kind: .command(c), title: c.title, section: section, icon: c.id.icon, keys: c.keys)
    }

    private func dateRow(_ d: Date) -> PaletteRow {
        PaletteRow(kind: .date(d), title: chromeDay(d, long: true, year: true), section: "Go to", icon: .cal,
                   sub: math.isSameDay(d, now) ? "today" : "W\(isoWeek(d))")
    }

    private func eventRows(_ q: String, limit: Int) -> [PaletteRow] {
        EventSearch.nearest(searchGroups.flatMap(\.events), query: q, today: now, math: math, limit: limit).map { e in
            PaletteRow(kind: .event(e), title: e.title.isEmpty ? "(No title)" : e.title, section: "Events", icon: .cal, colorHex: hexColor(of: e),
                       sub: chromeDay(e.start) + (e.isAllDay ? "" : " \u{00B7} " + fmt.time(e.start)), past: e.end <= now)
        }
    }

    func run(_ row: PaletteRow) {
        switch row.kind {
        case .command(let c): run(c.id)
        case .date(let d): overlay = nil; go(to: d); deselect()
        case .event(let e): overlay = nil; openSearchResult(e)
        case .mate(let t):
            overlay = nil
            toggleMate(t)
            if viewMode == .month { setMode(.week) }
        }
    }

    func run(_ id: CommandID) {
        switch id {
        case .goToDate: openPalette(.goTo); return
        case .searchEvents: openPalette(.search); return
        case .meetWith: openPalette(.meet); return
        case .settings: overlay = .settings; return
        case .shortcuts: overlay = .shortcuts; return
        default: break
        }
        overlay = nil
        switch id {
        case .newEvent: createAtNextFreeSlot()
        case .today: goToToday(); deselect()
        case .nextPeriod: next()
        case .previousPeriod: previous()
        case .viewDay: setMode(.day)
        case .viewWeek: setMode(.week)
        case .viewMonth: setMode(.month)
        case .toggleSidebar: toggleSidebar()
        case .switchAppearance: settings.appearance = isPaper ? .dark : .light
        case .undo: undo()
        case .deleteSelected: requestDeleteSelected()
        case .fitWeek: fitHourScale()
        case .goToDate, .searchEvents, .meetWith, .settings, .shortcuts: break
        }
    }

    /// Ink (dark) or Paper (light).
    var isPaper: Bool { settings.appearance == .light }

    // MARK: Keys

    /// Returns true when the key was consumed.
    @discardableResult
    func handle(_ action: ShortcutAction) -> Bool {
        switch action {
        case .escape: return escapeOneLayer()
        case .commandMenu: overlay == .command ? (overlay = nil) : openPalette(.all)
        case .goToDate: openPalette(.goTo)
        case .searchEvents: openPalette(.search)
        case .meetWith: store.canOverlayTeammates ? openPalette(.meet) : showToast(Self.meetWithUnavailable)
        case .showShortcuts: overlay = .shortcuts
        case .settings: overlay = .settings
        case .today: goToToday()
        case .nextPeriod: next()
        case .previousPeriod: previous()
        case .createEvent: createAtNextFreeSlot()
        case .viewDay: setMode(.day)
        case .viewWeek: setMode(.week)
        case .viewMonth: setMode(.month)
        case .toggleSidebar: toggleSidebar()
        case .menuBarCalendar: if !MenuBarControl.open() { showToast("Menu bar calendar: click the menu bar item") }
        case .mainWindow: NSApp.activate(ignoringOtherApps: true)
        case .undo: undo()
        case .refresh: store.refresh(); showToast("Refreshed")
        case .deleteSelection: requestDeleteSelected()
        case .arrow(let dx, let dy): return arrowKey(dx: dx, dy: dy)
        case .nudge(let dx, let dy): return nudgeSelected(dx: dx, dy: dy)
        case .selectNext: selectByTab(1)
        case .selectPrevious: selectByTab(-1)
        case .editTitle: return editSelectedTitle()
        }
        return true
    }

    /// Esc peels one layer: command menu or sheet, then the event being created, then the selection, then the toast.
    func escapeOneLayer() -> Bool {
        if gridCancelDrag() {}
        else if overlay != nil { overlay = nil }
        else if draftEventID != nil { discardDraft() }
        else if selectedEventID != nil || selectedSlot != nil { deselect() }
        else if toast != nil { toast = nil }
        else { return false }
        return true
    }

    // discardDraft() lives in PanelV3State.swift (the panel owns the draft's lifecycle).

    // MARK: Teammates

    /// One person at a time: choosing someone overlays their calendar, choosing them again removes it.
    func toggleMate(_ t: Teammate) {
        shownTeammates = shownTeammates.contains(t) ? [] : [t]
        reload()
    }

    func mateColorHex(_ t: Teammate) -> String { teammateColor(t.email) }

    private func loadTeammates() {
        // EventKit derives teammates from attendees; load them off the main thread.
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.store.loadSearchCorpus(around: self.now)
            self.chromeState.paletteIndex = 0
        }
    }

    // MARK: Header

    /// "Sep – Oct" / "September" for a week, "Tuesday, 29 September" for a day, the month for a month; the year of the last day.
    var chromeTitle: (main: String, year: String) {
        switch viewMode {
        case .month: return (fmt.monthLong(visibleStart), String(math.year(visibleStart)))
        case .day: return ("\(fmt.weekdayLong(visibleStart)), \(math.day(visibleStart)) \(fmt.monthLong(visibleStart))", String(math.year(visibleStart)))
        default:
            let a = visibleStart, b = visibleDays.last ?? visibleStart
            if math.month(a) == math.month(b) { return (fmt.monthLong(a), String(math.year(b))) }
            return ("\(fmt.monthShort(a)) \u{2013} \(fmt.monthShort(b))", String(math.year(b)))
        }
    }

    /// Today is already on screen: the Today button goes quiet.
    var chromeShowsToday: Bool {
        viewMode == .month ? math.isSameMonth(visibleStart, now) : isCurrentPeriodToday
    }

    func isoWeek(_ d: Date) -> Int {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = math.timeZone
        return iso.component(.weekOfYear, from: d)
    }

    /// "Tue 29 Sep", or "Tuesday 29 September 2026".
    func chromeDay(_ d: Date, long: Bool = false, year: Bool = false) -> String {
        let s = long ? "\(fmt.weekdayLong(d)) \(math.day(d)) \(fmt.monthLong(d))" : "\(fmt.weekdayShort(d)) \(math.day(d)) \(fmt.monthShort(d))"
        return year ? "\(s) \(math.year(d))" : s
    }

    /// Undo toast after a move or resize: "Moved to Thu 1 Oct, 13:00" or "Ends 14:00".
    func undoToastText(old: CalendarEvent, new: CalendarEvent) -> String {
        if old.start == new.start && old.end != new.end { return "Ends \(fmt.time(new.end))" }
        return "Moved to \(chromeDay(new.start))" + (new.isAllDay ? "" : ", \(fmt.time(new.start))")
    }

    /// The account's short name for the sidebar: its default calendar, else its first writable one (the address shows on hover).
    func shortName(of acc: CalendarAccount) -> String {
        (acc.calendars.first(where: \.isDefault) ?? acc.calendars.first(where: \.isWritable))?.title ?? acc.name
    }

    /// Opens the week of a mini-month week number.
    func openWeek(_ d: Date) {
        go(to: d)
        setMode(.week)
    }
}
