import Foundation
import AppKit
import SwiftUI
import Observation
import CalendrKit

/// Main-thread delayed call on a common-mode Timer. (GCD `asyncAfter` on the main queue cannot run while the headless drivers
/// pump a nested run loop from inside a main-queue block, and a Timer also keeps firing while menus track events.)
@MainActor
func after(_ delay: TimeInterval, _ block: @escaping @MainActor () -> Void) {
    let t = Timer(timeInterval: delay, repeats: false) { _ in MainActor.assumeIsolated { block() } }
    RunLoop.main.add(t, forMode: .common)
}

enum Overlay: Equatable {
    case command, shortcuts, settings
    case deleteRecurring(String)   // event id
}

/// Everything the views bind to. Derived data (layouts, month cells, upcoming) is computed in `reload()`
/// and never inside a view body.
@MainActor @Observable
final class AppModel {
    // MARK: Environment
    let store: CalendarStore
    let options: LaunchOptions
    private let persist: Bool
    private(set) var math: CalendarMath
    var settings: AppSettings { didSet { settingsChanged(old: oldValue) } }
    /// -1 / 0 / +1: direction of the last period change (drives the slide).
    private(set) var navDirection = 0
    var fmt: Fmt { Fmt(math: math, use24h: use24h) }
    /// From the system locale; demo mode pins 24-hour time (and a Monday week start) so snapshots are deterministic.
    var use24h: Bool

    // MARK: Time
    private(set) var now: Date
    private let bootClock = Date()
    private var clockTimer: Timer?
    private var clockObservers: [NSObjectProtocol] = []

    // MARK: Navigation
    var anchor: Date
    var viewMode: ViewMode = .week
    var leftAligned = false

    // MARK: Visibility
    var hiddenCalendars: Set<String>
    var shownTeammates: [Teammate] = []

    // MARK: Selection
    /// Selecting anything else settles the draft, so a draft is always the selected event.
    var selectedEventID: String? { didSet { if let d = draft, selectedEventID != d.id { settleDraft() } } }
    var selectedSlot: Date?
    private(set) var pendingEdit: (event: CalendarEvent, span: EditSpan)?
    private var editTimer: Timer?
    var focusTitleTick = 0
    var titleFocusPending = false

    // MARK: Chrome
    var sidebarVisible = true
    var overlay: Overlay? {
        didSet {
            // The palette fades out over 260 ms; its text field must not keep the keyboard meanwhile.
            if oldValue == .command && overlay != .command { searchText = "" }
            if overlay == nil && oldValue != nil {
                // Submitting with Return re-focuses the field after the action returns, so resign now and again once the event is done.
                resignTextFocus()
                for d in [0.02, 0.08] { after(d) { [weak self] in if self?.overlay == nil { self?.resignTextFocus() } } }
            }
        }
    }
    var searchText = "" { didSet { if searchText != oldValue { runSearch() } } }
    struct ToastState: Equatable { var id = UUID(); var text: String; var undo = false }
    var toast: ToastState?
    var scrollToHourTick = 0
    var secondTimeZoneVisible = false

    // MARK: v3 area state (each area owns its struct and file)
    /// The event being created (drag, double-click, C): drawn dashed on the grid, shown with Save / Discard in the panel.
    /// It lives only here until it is saved (`saveDraft`, `settleDraft`); set by `createEvent`, cleared by the draft functions in PanelV3State.swift.
    var draft: CalendarEvent?
    /// Setting nil settles the draft (kept with a title, dropped without).
    var draftEventID: String? {
        get { draft?.id }
        set { if newValue == nil { settleDraft() } }
    }
    var gridState = GridV3State()
    var chromeState = ChromeV3State()
    var panelState = PanelV3State()
    /// Bumped on every store change, for observers that read the store directly (the menu bar item).
    private(set) var storeVersion = 0

    // MARK: Derived (cached)
    private(set) var visibleStart: Date
    var miniMonth: Date
    private(set) var visibleDays: [Date] = []
    private(set) var layout: RangeLayout = .empty
    private(set) var overlayLayout: RangeLayout = .empty
    private(set) var flatTimed: [PlacedEvent] = []
    private(set) var flatOverlay: [PlacedEvent] = []
    private(set) var monthGrid: [[Date]] = []
    private(set) var monthEvents: [[CalendarEvent]] = []      // index = row*7+col
    private(set) var upcoming: UpcomingSummary
    private(set) var searchGroups: [SearchGroup] = []
    private(set) var layoutGeneration = 0
    private var eventsByID: [String: CalendarEvent] = [:]
    private var windowRange = DateInterval(start: .distantPast, end: .distantPast)
    private var windowEvents: [CalendarEvent] = []
    private var corpus: [CalendarEvent]?
    private(set) var reloadCount = 0
    private(set) var authState: StoreAuthorization = .authorized

    // MARK: Interaction
    var dragPreview: DragPreview?
    var undoStack = UndoStack()
    var gridGeometry = GridGeometry(dayWidth: 180, hourHeight: 48, dayCount: 7)
    /// Frame of the scrolling grid in window coordinates (top-left origin) and its scroll offset. Published by the view; used by the walkthrough to aim real mouse events.
    var gridViewport = CGRect.zero
    var gridScrollY: CGFloat = 0
    var press: GridPress?
    var lastClick: (time: TimeInterval, day: Int, minute: Int, id: String?)?

    struct DragPreview: Equatable {
        enum Kind { case create, move, resize }
        var kind: Kind
        var eventID: String?
        var dayIndex: Int
        var startMinute: Int
        var endMinute: Int
    }

    init(store: CalendarStore, options: LaunchOptions, persist: Bool = true) {
        self.store = store
        self.options = options
        self.persist = persist
        let s = persist ? AppSettings.load() : AppSettings()
        settings = s
        Motion.override = s.reduceMotion
        let m = options.demo ? DemoData.math : CalendarMath.system
        use24h = options.demo || Fmt.uses24h()
        math = m
        let n = options.now ?? Date()
        now = n
        anchor = m.startOfDay(n)
        visibleStart = m.startOfWeek(n)
        miniMonth = m.startOfMonth(n)
        hiddenCalendars = Set(store.allCalendars.filter { !$0.isVisibleByDefault }.map(\.id))
        upcoming = UpcomingSummary(next: nil, sections: [])
        authState = store.authorization
        store.onChange = { [weak self] in self?.storeChanged() }
        reload()
        refreshUpcoming()
        if !options.freezeClock { startClock() }
    }

    // MARK: Clock

    private func startClock() {
        let t = Timer(timeInterval: 20, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)      // keeps firing while a menu or the menu bar popover tracks events
        clockTimer = t
        // After sleep the timer may be minutes late, and the clock or day can jump: re-read the time right away.
        let refresh: @Sendable (Notification) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        clockObservers = [
            NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: refresh),
            NotificationCenter.default.addObserver(forName: .NSSystemClockDidChange, object: nil, queue: .main, using: refresh),
            NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main, using: refresh),
            NotificationCenter.default.addObserver(forName: NSNotification.Name.NSSystemTimeZoneDidChange, object: nil, queue: .main, using: refresh),
            NotificationCenter.default.addObserver(forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.localeChanged() }
            },
        ]
    }

    /// Language and Region changed: re-read the clock style and the first weekday.
    private func localeChanged() {
        guard !options.demo else { return }
        use24h = Fmt.uses24h()
        math = .system
        windowRange = DateInterval(start: .distantPast, end: .distantPast)
        reload()
    }

    private func tick() {
        let n = currentTime()
        if math.minutesSinceMidnight(n) != math.minutesSinceMidnight(now) || !math.isSameDay(n, now) {
            now = n
            refreshUpcoming()
        }
    }

    private func currentTime() -> Date {
        if let pinned = options.now { return pinned.addingTimeInterval(Date().timeIntervalSince(bootClock)) }
        return Date()
    }

    func setNow(_ d: Date) { now = d; refreshUpcoming() }

    // MARK: Store reload

    func storeChanged() {
        // Do not let a store refresh (our own saves fire it too) revert text the user is still typing.
        authState = store.authorization
        styleCache.removeAll()
        windowRange = DateInterval(start: .distantPast, end: .distantPast)
        corpus = nil
        corpusGeneration += 1
        storeVersion += 1
        reload()
        refreshUpcoming()
        if !searchText.isEmpty { runSearch() }
    }

    func hexColor(of event: CalendarEvent) -> String {
        if let o = event.colorHex { return o }
        return calendarInfo(event.calendarID)?.colorHex ?? teammateColor(event.ownerEmail)
    }

    func calendarInfo(_ id: String) -> CalendarInfo? { store.calendar(id) }

    func calendarColorHex(of event: CalendarEvent) -> String {
        calendarInfo(event.calendarID)?.colorHex ?? teammateColor(event.ownerEmail)
    }

    static let teammatePalette = ["#C58AF9", "#5EC0C9", "#F28B82", "#8AB4F8", "#F6AE4C", "#7BD88F", "#E78FD0", "#A3B1C2", "#D9B26F", "#87C7A2", "#C9A0DC"]
    func teammateColor(_ email: String?) -> String {
        guard let email, let i = store.teammates.firstIndex(where: { $0.email == email }) else { return "#8A8A8A" }
        return Self.teammatePalette[i % Self.teammatePalette.count]
    }

    var defaultCalendarHex: String {
        (settings.defaultCalendarID.flatMap { store.calendar($0) } ?? store.defaultCalendarID.flatMap { store.calendar($0) } ?? store.allCalendars.first)?.colorHex ?? "#B9B6C9"
    }

    private struct StyleKey: Hashable { var cal: String; var fill: String?; var dark: Bool; var owner: String? }
    private var styleCache: [StyleKey: EventPalette] = [:]

    /// Palette lookups are cached per (calendar, override colors, appearance): the grid asks for hundreds per frame.
    func style(for e: CalendarEvent, dark: Bool, now: Date, selected: Bool, overlapping: Bool) -> EventStyle {
        let key = StyleKey(cal: e.calendarID, fill: e.colorHex, dark: dark, owner: e.ownerEmail)
        let pal: EventPalette
        if let hit = styleCache[key] { pal = hit } else {
            pal = Palettes.palette(barHex: calendarColorHex(of: e), fillHex: e.colorHex, dark: dark)
            styleCache[key] = pal
        }
        return EventStyle(palette: pal, past: e.end <= now && !(e.end == e.start && e.start > now), selected: selected, overlapping: overlapping)
    }

    func isWritable(_ e: CalendarEvent) -> Bool {
        if e.ownerEmail != nil { return false }
        return calendarInfo(e.calendarID)?.isWritable ?? true
    }

    /// Recompute everything derived from (range, mode, hidden calendars, teammates, settings, store).
    func reload() {
        reloadCount += 1
        let start = math.visibleStart(mode: viewMode, anchor: anchor, leftAligned: leftAligned)
        if !math.isSameMonth(start, visibleStart) { miniMonth = math.startOfMonth(start) }
        visibleStart = start
        let q = math.queryRange(mode: viewMode, start: start)
        if !(windowRange.start <= q.start && windowRange.end >= q.end) {
            windowRange = DateInterval(start: math.addDays(q.start, -7), end: math.addDays(q.end, 7))
            windowEvents = store.events(in: windowRange)
            eventsByID.removeAll(keepingCapacity: true)
            for e in windowEvents { eventsByID[e.id] = e }
        }
        // Filter and sort by index: CalendarEvent is a large reference-heavy struct, so copying it around is the real cost.
        let showDeclined = settings.showDeclined
        let hidden = hiddenCalendars
        var visibleIdx: [Int] = []
        visibleIdx.reserveCapacity(windowEvents.count / 2)
        windowEvents.withUnsafeBufferPointer { buf in
            for i in buf.indices {
                let e = buf[i]
                guard e.end > q.start && e.start < q.end || (e.end == e.start && e.start >= q.start && e.start < q.end) else { continue }
                if hidden.contains(e.calendarID) || (!showDeclined && e.status == .declined) { continue }
                visibleIdx.append(i)
            }
        }

        visibleDays = viewMode == .month ? math.days(from: q.start, count: 42) : math.days(from: start, count: viewMode.dayCount)
        if viewMode == .month {
            monthGrid = math.monthGrid(for: start)
            let starts = visibleDays          // 42 day starts
            var cells = [[CalendarEvent]](repeating: [], count: 42)
            // Sort once (all-day, then timed; by start) and bucket stably instead of sorting 42 lists.
            let ordered: [Int] = windowEvents.withUnsafeBufferPointer { buf in
                var keyed: [(key: Double, idx: Int)] = visibleIdx.map { i in
                    let e = buf[i]
                    let cls: Double = e.isAllDay ? 0 : 1
                    return (cls * 1e11 + e.start.timeIntervalSince1970, i)
                }
                keyed.sort { $0.key != $1.key ? $0.key < $1.key : $0.idx < $1.idx }
                return keyed.map(\.idx)
            }
            for i in ordered {
                let e = windowEvents[i]
                let first = max(0, RangeLayoutBuilder.dayIndex(e.start, starts: starts))
                let lastInstant = e.end > e.start ? e.end.addingTimeInterval(-1) : e.end
                let last = min(41, RangeLayoutBuilder.dayIndex(lastInstant, starts: starts))
                if last >= first { for d in first...last { cells[d].append(e) } }
            }
            if let d = draft {
                let first = max(0, RangeLayoutBuilder.dayIndex(d.start, starts: starts))
                let last = min(41, RangeLayoutBuilder.dayIndex(d.end > d.start ? d.end.addingTimeInterval(-1) : d.end, starts: starts))
                if last >= first {
                    for i in first...last {
                        let at = cells[i].firstIndex { d.isAllDay ? !$0.isAllDay : (!$0.isAllDay && $0.start > d.start) } ?? cells[i].count
                        cells[i].insert(d, at: at)
                    }
                }
            }
            monthEvents = cells
            layout = .empty
        } else {
            var shown = visibleIdx.map { windowEvents[$0] }
            if let d = draft { shown.append(d) }
            layout = gridLayout(RangeLayoutBuilder.build(events: shown, days: visibleDays, math: math))
        }

        var teamEvents: [CalendarEvent] = []
        for t in shownTeammates {
            for var e in store.teammateEvents(t.email, in: q) { e.ownerEmail = t.email; teamEvents.append(e); eventsByID[e.id] = e }
        }
        overlayLayout = viewMode == .month ? .empty : RangeLayoutBuilder.build(events: teamEvents, days: visibleDays, math: math)
        flatTimed = layout.timed.flatMap { $0 }
        flatOverlay = overlayLayout.timed.flatMap { $0 }
        layoutGeneration += 1
        if let p = pendingEdit { patchLayout(p.event) }
    }

    /// Puts an edited event into the drawn layout without rebuilding it (text edits: title, place, notes).
    private func patchLayout(_ e: CalendarEvent) {
        if draft?.id != e.id { eventsByID[e.id] = e }
        for d in layout.timed.indices {
            for i in layout.timed[d].indices where layout.timed[d][i].event.id == e.id { layout.timed[d][i].event = e }
        }
        if layout.allDayEvents[e.id] != nil { layout.allDayEvents[e.id] = e }
        for c in monthEvents.indices {
            for i in monthEvents[c].indices where monthEvents[c][i].id == e.id { monthEvents[c][i] = e }
        }
        flatTimed = layout.timed.flatMap { $0 }
        layoutGeneration += 1
    }

    func refreshUpcoming() {
        let today = math.startOfDay(now)
        let evs = store.events(in: DateInterval(start: math.addDays(today, -1), end: math.addDays(today, 8)))
            .filter { !hiddenCalendars.contains($0.calendarID) }
        upcoming = Upcoming.summarize(events: evs, now: now, fmt: fmt)
        refreshPanelToday(evs)
        for e in evs { eventsByID[e.id] = eventsByID[e.id] ?? e }
    }

    private func settingsChanged(old: AppSettings) {
        if old.reduceMotion != settings.reduceMotion { Motion.override = settings.reduceMotion }
        if persist { settings.save() }
        if old.showDeclined != settings.showDeclined {
            windowRange = DateInterval(start: .distantPast, end: .distantPast)
            reload()
        }
    }

    // MARK: Lookup

    func event(id: String?) -> CalendarEvent? {
        guard let id else { return nil }
        if let d = draft, d.id == id { return d }
        return eventsByID[id]
    }
    var selectedEvent: CalendarEvent? { event(id: selectedEventID) }

    // MARK: Navigation

    func goToToday() { settleDraft(); setDirection(to: math.startOfDay(now)); anchor = math.startOfDay(now); leftAligned = false; reload(); scrollToHourTick += 1 }
    private func setDirection(to d: Date) { navDirection = d > anchor ? 1 : (d < anchor ? -1 : 0) }
    func leftAlignToday() {
        settleDraft()
        anchor = math.startOfDay(now); leftAligned = true
        if viewMode == .month { viewMode = .week }
        reload()
    }
    /// Navigation settles the draft, except when the draft itself moves to another day (`settling: false`).
    func go(to date: Date, settling: Bool = true) {
        if settling { settleDraft() }
        setDirection(to: math.startOfDay(date))
        anchor = math.startOfDay(date)
        leftAligned = false
        reload()
    }
    func step(_ direction: Int) {
        settleDraft()
        navDirection = direction
        let mode = viewMode
        if mode == .week && leftAligned { anchor = math.addDays(anchor, 7 * direction) }
        else { anchor = math.step(mode: mode, anchor: mode == .month ? anchor : (mode == .week ? visibleStart : anchor), direction: direction) }
        reload()
    }
    func next() { step(1) }
    func previous() { step(-1) }
    func setMode(_ m: ViewMode) {
        guard m != viewMode else { return }
        settleDraft()
        navDirection = 0
        viewMode = m
        if m != .week { leftAligned = false }
        reload()
    }
    /// Mini calendar month chevrons: moves the anchor by whole months.
    func stepMiniMonth(_ d: Int) { miniMonth = math.addMonths(miniMonth, d) }
    func toggleCalendar(_ id: String) {
        if hiddenCalendars.contains(id) { hiddenCalendars.remove(id) } else { hiddenCalendars.insert(id) }
        reload()
        refreshUpcoming()
    }

    /// Identity of what the grid shows: a change slides the content in.
    var periodID: String { "\(viewMode.title)|\(visibleStart.timeIntervalSince1970)" }

    var isCurrentPeriodToday: Bool { visibleDays.contains { math.isSameDay($0, now) } }
    var todayIndex: Int? { visibleDays.firstIndex { math.isSameDay($0, now) } }

    /// The reference shows "September 2026" for Mon Sep 28 - Sun Oct 4, so the title follows the first visible day.
    var headerTitle: String { fmt.monthTitle(visibleStart) }

    // MARK: Teammates

    func showTeammate(_ t: Teammate) {
        if !shownTeammates.contains(t) { shownTeammates.append(t) }
        overlay = nil
        reload()
    }
    func removeTeammate(_ t: Teammate) { shownTeammates.removeAll { $0 == t }; reload() }

    func filteredTeammates(_ q: String) -> [Teammate] {
        let query = q.trimmingCharacters(in: .whitespaces)
        return FuzzyMatcher.filter(store.teammates, query: query) { "\($0.name) \($0.email)" }
    }

    // MARK: Selection & mutation

    func select(eventID: String?, focusTitle: Bool = false) {
        if eventID != selectedEventID { flushPendingEdit() }
        selectedEventID = eventID
        if eventID != nil { selectedSlot = nil }
        if focusTitle && eventID != nil { requestTitleFocus() }
    }

    func resignTextFocus() {
        blurTick += 1
        guard NSApp != nil else { return }      // unit tests run without an application object
        for w in NSApp.windows where w.firstResponder is NSText { w.makeFirstResponder(nil) }
    }

    /// The inspector may still be sliding in when a new event is created: nudge the title field a few times, then give up.
    /// The nudges stop once the user has typed, so focusing again cannot select (and replace) what was typed.
    func requestTitleFocus() {
        titleFocusPending = true; panelState.titleTyped = false; focusTitleTick += 1
        for delay in [0.03, 0.08, 0.16] {
            after(delay) { [weak self] in if let self, self.titleFocusPending, !self.panelState.titleTyped { self.focusTitleTick += 1 } }
        }
        after(0.25) { [weak self] in self?.titleFocusPending = false }
    }

    func deselect() {
        flushPendingEdit()
        settleDraft()
        selectedEventID = nil
        selectedSlot = nil
    }

    /// Starts a draft: nothing is written to the store until it is saved. An open draft is settled first.
    @discardableResult
    func createEvent(start: Date, end: Date, allDay: Bool = false) -> CalendarEvent? {
        settleDraft()
        let cal = settings.defaultCalendarID.flatMap { store.calendar($0) }?.id ?? store.defaultCalendarID
            ?? store.allCalendars.first(where: { $0.isWritable })?.id ?? ""
        let e = CalendarEvent(calendarID: cal, title: "", start: start, end: end, isAllDay: allDay, reminderMinutes: 10, timeZoneID: math.timeZone.identifier)
        draft = e
        select(eventID: e.id, focusTitle: true)
        reload()
        return e
    }

    /// `C`: next free half hour on the selected slot's day, or today.
    func createAtNextFreeSlot() {
        settleDraft()
        let day: Date = selectedSlot.map { math.startOfDay($0) } ?? math.startOfDay(now)
        var from = selectedSlot.map { math.minutesSinceMidnight($0) } ?? math.minutesSinceMidnight(now)
        if selectedSlot == nil, !math.isSameDay(day, now) { from = 9 * 60 }
        let dur = settings.defaultDurationMinutes
        let dayEvents = store.events(in: DateInterval(start: day, end: math.addDays(day, 1)))
            .filter { !$0.isAllDay && !hiddenCalendars.contains($0.calendarID) }
            .map { (start: $0.start < day ? 0 : math.minutesSinceMidnight($0.start),
                    end: $0.end >= math.addDays(day, 1) ? 1440 : math.minutesSinceMidnight($0.end)) }
        let startMin: Int
        if selectedSlot != nil { startMin = from }
        else if let free = FreeSlot.next(from: from + 1, duration: dur, busy: dayEvents) { startMin = free }
        else { showToast("No free slot left today"); return }
        if !visibleDays.contains(where: { math.isSameDay($0, day) }) { go(to: day) }
        let s = math.date(on: day, minutes: startMin)
        createEvent(start: s, end: s.addingTimeInterval(Double(dur) * 60))
    }

    /// Write-through edit from the inspector. Not undoable (text editing has its own undo).
    func updateSelected(span: EditSpan = .this, _ change: (inout CalendarEvent) -> Void) {
        guard var e = selectedEvent, isWritable(e) else { return }
        let before = e
        change(&e)
        if e.end < e.start { e.end = e.start }
        if e == before { return }
        if e.title != before.title && !panelState.titleTyped { panelState.titleTyped = true }
        let textOnly = e.start == before.start && e.end == before.end && e.isAllDay == before.isAllDay && e.calendarID == before.calendarID
        if draft?.id == e.id {
            draft = e
            if textOnly { patchLayout(e) } else { reload() }
            return
        }
        // Real stores (EventKit -> Google/iCloud) sync every save over the network: coalesce text typing into one write.
        if store.coalescesTextEdits && textOnly {
            pendingEdit = (e, span)
            patchLayout(e)
            editTimer?.invalidate()
            let t = Timer(timeInterval: 0.6, repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?.flushPendingEdit() } }
            RunLoop.main.add(t, forMode: .common)
            editTimer = t
            return
        }
        flushPendingEdit()
        commit(e, span: span, old: nil)
    }

    /// Writes a coalesced text edit to the store now (called by the debounce timer, before selection changes, undo, delete and quit).
    func flushPendingEdit() {
        editTimer?.invalidate(); editTimer = nil
        guard let p = pendingEdit else { return }
        pendingEdit = nil
        commit(p.event, span: p.span, old: nil)
    }

    func commit(_ e: CalendarEvent, span: EditSpan, old: CalendarEvent?) {
        do {
            let saved = try store.update(e, span: span)
            eventsByID[saved.id] = saved
            if let old { undoStack.push(.updated(old: old, new: saved)); showToast(undoToastText(old: old, new: saved), undo: true) }
            selectedEventID = saved.id
        } catch { showToast("Could not save event") }
    }

    func requestDeleteSelected() {
        guard let e = selectedEvent, isWritable(e) else { return }
        if isDraftOpen { discardDraft(); return }
        if e.isRecurring && store.series(of: e).count > 1 { overlay = .deleteRecurring(e.id) } else { delete(e, span: .this) }
    }

    func delete(_ e: CalendarEvent, span: EditSpan) {
        flushPendingEdit()
        let removed: [CalendarEvent]
        switch span {
        case .this: removed = [e]
        case .all: removed = store.series(of: e)
        case .future: removed = store.series(of: e).filter { $0.start >= e.start }
        }
        do {
            try store.delete(e, span: span)
            undoStack.push(.deleted(removed))
            selectedEventID = nil
            overlay = nil
            showToast("Deleted \u{201C}\(e.title.isEmpty ? "(No title)" : e.title)\u{201D}", undo: true)
        } catch { showToast("Could not delete event") }
    }

    func undo() {
        flushPendingEdit()
        guard let change = undoStack.pop() else { showToast("Nothing to undo"); return }
        switch change {
        case .created(let e): try? store.delete(e, span: .this); if selectedEventID == e.id { selectedEventID = nil }
        case .deleted(let es): for e in es { _ = try? store.create(e) }; selectedEventID = es.first?.id
        case .updated(let old, let new):
            // Undo the move/resize only: text typed into the inspector since then stays.
            var cur = event(id: new.id) ?? new
            cur.start = old.start; cur.end = old.end; cur.isAllDay = old.isAllDay; cur.calendarID = old.calendarID
            if let saved = try? store.update(cur, span: .this) { eventsByID[saved.id] = saved; selectedEventID = saved.id } else { showToast("Could not undo") }
        }
    }

    // MARK: Search

    private func runSearch() {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { searchGroups = []; return }
        if corpus == nil {
            if store.searchCorpusIsAsync {
                // A year of real calendar data can take a while to fetch: never block the main thread on it.
                guard !corpusLoading else { return }
                corpusLoading = true
                let generation = corpusGeneration
                let around = now
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let loaded = await self.store.loadSearchCorpus(around: around)
                    self.corpusLoading = false
                    guard generation == self.corpusGeneration else { if !self.searchText.isEmpty { self.runSearch() }; return }
                    self.corpus = loaded
                    self.runSearch()
                }
                return
            }
            corpus = store.searchCorpus(around: now)
        }
        searchGroups = EventSearch.search((corpus ?? []).filter { !hiddenCalendars.contains($0.calendarID) }, query: q, math: math, near: now)
    }
    private var corpusLoading = false
    private var corpusGeneration = 0

    func openSearchResult(_ e: CalendarEvent) {
        go(to: e.start)
        if viewMode == .month { viewMode = .week; reload() }
        eventsByID[e.id] = e
        select(eventID: e.id)
        scrollToHourTick += 1
    }

    /// Menu bar: open main window at that event.
    func open(event e: CalendarEvent) {
        searchText = ""
        openSearchResult(e)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Toast

    func showToast(_ text: String, undo: Bool = false) {
        let t = ToastState(text: text, undo: undo)
        toast = t
        if options.freezeClock { return }
        after(6) { [weak self] in
            if self?.toast?.id == t.id { self?.toast = nil }
        }
    }
    func dismissToast() { toast = nil }

    private var isoCalendar = Calendar(identifier: .iso8601)
    /// ISO week number of the first visible day ("W40").
    var weekLabel: String {
        if isoCalendar.timeZone != math.timeZone { isoCalendar.timeZone = math.timeZone }
        return "W\(isoCalendar.component(.weekOfYear, from: visibleStart))"
    }

    // MARK: Commands

    func toggleSidebar() { sidebarVisible.toggle() }

    func closeOverlay() { overlay = nil }

    /// Bumped to make every focus-owning field resign (Esc while typing).
    var blurTick = 0
}

extension AppModel {
    /// Prev/next chevrons in the recurrence row.
    func selectOccurrence(_ dir: Int) {
        guard let e = selectedEvent else { return }
        let all = store.series(of: e).sorted { $0.start < $1.start }
        guard let i = all.firstIndex(where: { $0.id == e.id }) else { return }
        let j = i + dir
        guard all.indices.contains(j) else { return }
        openSearchResult(all[j])
    }
}

extension AppModel {
    func requestAccess() { Task { await store.requestAccess(); storeChanged() } }
    func openPrivacySettings() {
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") { NSWorkspace.shared.open(u) }
    }
}
