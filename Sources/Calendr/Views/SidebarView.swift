import SwiftUI
import CalendrKit

/// Month and calendars: a 56 pt top with the hide button, the mini month, the calendar list by account, Settings at the foot.
struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                IconButton(name: "sidebar.left", size: 14, help: "Hide sidebar  `") { model.toggleSidebar() }
            }
            .padding(.horizontal, 12).frame(height: 56)

            MiniMonth().padding(.horizontal, 14)
            Hairline().padding(.horizontal, 16).padding(.top, 14)

            if model.authState != .authorized {
                SidebarSkeleton()
                Spacer(minLength: 0)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    CalendarList().padding(.bottom, 14)
                }
            }
            SidebarFoot()
        }
        .frame(width: ChromeDim.sidebarWidth)
        .background(Theme.bg)
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.hair2).frame(width: 1) }
    }
}

/// Shown while there is no calendar access.
struct SidebarSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach([132, 96, 118], id: \.self) { w in
                RoundedRectangle(cornerRadius: 5).fill(Theme.hair).frame(width: CGFloat(w), height: 10).padding(.bottom, 9)
            }
            Text("Your calendars appear here once Calendr can read them.").font(.ui(12)).foregroundStyle(Theme.fg2).lineSpacing(3).padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(Theme.bg1))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Theme.hair, lineWidth: 1))
        .padding(.horizontal, 14).padding(.top, 14)
    }
}

/// Numerals only: today an inverted 22 pt pill, the visible week banded, other months in fg3.
/// With week numbers on, a 24 pt column of ISO week numbers opens that week.
struct MiniMonth: View {
    @Environment(AppModel.self) private var model
    @State private var hoverDay: Date?
    @State private var hoverWeek: Date?
    /// The grid on screen, read by the day buttons' actions when they run: the buttons are not re-rendered when only the month
    /// changes, so their closures must not capture the dates.
    @State private var shown = MiniMonthGrid()
    static let cell: CGFloat = 28

    /// Natural height of the mini month for `rows` week rows: title 28 + 4, weekday letters 22, rows of `cell`.
    static func height(rows: Int) -> CGFloat { 28 + 4 + 22 + CGFloat(rows) * cell }
    static let width: CGFloat = ChromeDim.sidebarWidth - 28

    var body: some View {
        let math = model.math
        let month = model.miniMonth
        let grid = math.monthGrid(for: month)
        let rows = grid.indices.filter { $0 < 5 || math.isSameMonth(grid[$0][0], month) }
        let weeks = model.settings.showWeekNumbers
        let band = model.viewMode.baseMode == .week ? math.startOfWeek(model.visibleStart) : nil
        let first = math.calendar.firstWeekday
        let now = model.now
        let selectedDay: Date? = model.viewMode == .day ? model.visibleStart : nil
        let shown = shown
        let _ = shown.grid = grid
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button { model.miniMonth = math.startOfMonth(model.visibleStart) } label: {
                    (Text(verbatim: model.fmt.monthLong(month)).font(.ui(12.5, .semibold)).foregroundColor(Theme.fg)
                     + Text(verbatim: " " + String(math.year(month))).font(.calMono(12.5)).foregroundColor(Theme.fg3))
                        .padding(.leading, 8).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain).help("Back to the visible \(model.viewMode.title.lowercased())")
                IconButton(name: "chevron.left", size: 11, box: 24) { model.stepMiniMonth(-1) }
                IconButton(name: "chevron.right", size: 11, box: 24) { model.stepMiniMonth(1) }
            }
            .frame(height: 28).padding(.bottom, 4)

            HStack(spacing: 0) {
                if weeks { Color.clear.frame(width: 24) }
                ForEach(0..<7, id: \.self) { i in
                    Text(String(Fmt.weekdayShort[(first - 1 + i) % 7].prefix(1)))
                        .font(.ui(10, .medium)).foregroundStyle(Theme.fg3).frame(maxWidth: .infinity)
                }
            }
            .frame(height: 22)

            VStack(spacing: 0) {
                // All six rows always exist; a row the month does not need collapses (the original inserted and removed it, which
                // rebuilt seven buttons on every month change between five and six weeks).
                ForEach(grid.indices, id: \.self) { r in
                    let week = grid[r]
                    let visible = rows.contains(r)
                    HStack(spacing: 0) {
                        if weeks {
                            MiniWeekNumber(week: week[0], number: model.isoWeek(week[0]), hovered: hoverWeek == week[0],
                                           action: { model.openWeek(week[0]) },
                                           onHover: { hoverWeek = $0 ? week[0] : (hoverWeek == week[0] ? nil : hoverWeek) })
                                .equatable()
                        }
                        // Cells keep their place (identity by column) when the month changes: they update instead of being rebuilt.
                        ForEach(0..<7, id: \.self) { c in
                            let d = week[c]
                            MiniDay(today: math.isSameDay(d, now), selected: selectedDay.map { math.isSameDay(d, $0) } == true, hovered: hoverDay == d,
                                    action: { model.go(to: shown.grid[r][c]) },
                                    onHover: { on in
                                        let d = shown.grid[r][c]
                                        hoverDay = on ? d : (hoverDay == d ? nil : hoverDay)
                                    })
                                .equatable()
                                .accessibilityLabel(String(math.day(d)))   // the numeral, which the canvas draws
                                .help(model.chromeDay(d, long: true))
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 8).fill(band.map { math.isSameDay($0, week[0]) } == true ? Theme.actWash : .clear))
                    .frame(height: visible ? Self.cell : 0, alignment: .top)
                    .opacity(visible ? 1 : 0)
                    .allowsHitTesting(visible)
                    .accessibilityHidden(!visible)
                }
            }
            .overlay {
                MiniMonthNumerals(phase: Double(MiniMonthNumerals.index(month, math)), month: month, today: math.startOfDay(now), leading: weeks ? 24 : 0, math: math)
                    .equatable()
            }
        }
        // A fixed size keeps the rest of the window from re-measuring the mini month on every navigation.
        .frame(width: Self.width, height: Self.height(rows: rows.count))
        .animation(Motion.base, value: band)
    }
}

/// One mini-month day: hover and today circles, the day-view ring, the button (its tooltip is set by `MiniMonth`). The numeral is
/// drawn by `MiniMonthNumerals`. Equatable on what it shows, so neither a week step nor a month change re-renders 42 buttons.
private struct MiniDay: View, Equatable {
    let today: Bool
    let selected: Bool
    let hovered: Bool
    let action: () -> Void
    let onHover: (Bool) -> Void

    static func == (a: Self, b: Self) -> Bool { a.today == b.today && a.selected == b.selected && a.hovered == b.hovered }

    var body: some View {
        Button(action: action) {
            Color.clear
                .frame(width: 22, height: 22)
                .background(Circle().fill(today ? Theme.act : hovered ? Theme.hover : .clear))
                .overlay(Circle().strokeBorder(selected && !today ? Theme.ring : .clear, lineWidth: 1.5))
                .frame(maxWidth: .infinity).frame(height: MiniMonth.cell)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .animation(Motion.fast, value: hovered)
    }
}

/// See `MiniMonth.shown`.
private final class MiniMonthGrid {
    var grid: [[Date]] = []
}

/// The mini month's numerals in one Canvas. Each numeral is a `Text` symbol (1 to 31 in fg and fg3, today's in its pill style),
/// laid out once and reused, so a month change redraws one canvas instead of re-resolving 42 texts.
/// `phase` is the month as a month index and is animatable: when the month changes inside an animation (the week band moving into
/// another month), the old and new numerals cross-fade the way the per-day views they replace faded out and in.
private struct MiniMonthNumerals: View, Equatable, Animatable {
    var phase: Double
    let month: Date
    let today: Date
    let leading: CGFloat
    let math: CalendarMath
    @Environment(\.displayScale) private var scale

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    static func index(_ month: Date, _ math: CalendarMath) -> Int { math.year(month) * 12 + math.month(month) - 1 }

    static func == (a: Self, b: Self) -> Bool {
        a.phase == b.phase && a.month == b.month && a.today == b.today && a.leading == b.leading && a.math.calendar == b.math.calendar
    }

    /// Symbol ids of the visible cells of the month `offset` months from `month`, row by row: the day, plus 100 outside the month,
    /// or 200 for today (the rows shown are those `MiniMonth` shows).
    private func cells(_ offset: Int) -> [Int] {
        let m = math.addMonths(month, offset)
        let grid = math.monthGrid(for: m)
        return grid.indices.filter { $0 < 5 || math.isSameMonth(grid[$0][0], m) }.flatMap { r in
            grid[r].map { d in math.isSameDay(d, today) ? 200 + math.day(d) : math.isSameMonth(d, m) ? math.day(d) : 100 + math.day(d) }
        }
    }

    var body: some View {
        let scale = scale
        let target = Double(Self.index(month, math))
        let lo = phase.rounded(.down), f = phase - lo
        // Settled: the month itself. Mid-animation: the two months the phase lies between, each at its share of the fade.
        let layers: [([Int], Double)] = f < 1e-9 ? [(cells(Int(lo - target)), 1)] : [(cells(Int(lo - target)), 1 - f), (cells(Int(lo - target) + 1), f)]
        let todayNumber = math.day(today)
        Canvas { ctx, size in
            let cw = (size.width - leading) / 7
            func px(_ v: CGFloat) -> CGFloat { (v * scale).rounded() / scale }
            for (codes, opacity) in layers {
                if opacity < 1 { ctx.opacity = opacity }
                for (i, code) in codes.enumerated() {
                    guard let sym = ctx.resolveSymbol(id: code) else { continue }
                    let x = px(leading + CGFloat(i % 7) * cw + (cw - 22) / 2), y = px(CGFloat(i / 7) * MiniMonth.cell + (MiniMonth.cell - 22) / 2)
                    ctx.draw(sym, in: CGRect(x: x, y: y, width: 22, height: 22))
                }
            }
        } symbols: {
            ForEach(1...31, id: \.self) { n in numeral(n, today: false, color: Theme.fg).tag(n) }
            ForEach(101...131, id: \.self) { code in numeral(code - 100, today: false, color: Theme.fg3).tag(code) }
            numeral(todayNumber, today: true, color: Theme.onAct).tag(200 + todayNumber)
        }
        .allowsHitTesting(false)
    }

    private func numeral(_ n: Int, today: Bool, color: Color) -> some View {
        Text(verbatim: String(n)).font(.calMono(11.5, today ? .semibold : .regular)).foregroundStyle(color).frame(width: 22, height: 22)
    }
}

/// ISO week number left of a mini-month row (week numbers on): opens that week.
private struct MiniWeekNumber: View, Equatable {
    let week: Date
    let number: Int
    let hovered: Bool
    let action: () -> Void
    let onHover: (Bool) -> Void

    static func == (a: Self, b: Self) -> Bool { a.week == b.week && a.number == b.number && a.hovered == b.hovered }

    var body: some View {
        Button(action: action) {
            Text(verbatim: String(number)).font(.calMono(9.5))
                .foregroundStyle(hovered ? Theme.fg : Theme.fg3)
                .frame(width: 24, height: MiniMonth.cell)
                .background(RoundedRectangle(cornerRadius: 6).fill(hovered ? Theme.hover : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .help("Week \(number)")
    }
}

/// Every calendar, hidden ones included, under its account's short name; the address shows on hover.
struct CalendarList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.store.accounts) { acc in AccountSection(account: acc) }
        }
        .frame(width: ChromeDim.sidebarWidth - 1, alignment: .leading)
    }
}

struct AccountSection: View {
    @Environment(AppModel.self) private var model
    let account: CalendarAccount
    @State private var hover = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(model.shortName(of: account).uppercased()).font(.ui(10.5, .semibold)).tracking(0.53).foregroundStyle(Theme.fg3)
                Text(account.name.split(separator: "@").last.map(String.init) ?? "").font(.ui(10.5)).foregroundStyle(Theme.fg3)
                    .lineLimit(1).truncationMode(.tail).opacity(hover ? 1 : 0)
            }
            .lineLimit(1)
            .padding(.leading, 17).padding(.trailing, 16).padding(.top, 14).padding(.bottom, 4)
            .help(account.name)
            ForEach(account.calendars) { CalendarRow(cal: $0) }
        }
        .onHover { hover = $0 }
        .animation(Motion.base, value: hover)
    }
}

/// 14 pt rounded checkbox in the calendar colour: filled with a dark check when shown, an fg3 outline when hidden.
struct CalendarCheckbox: View {
    let color: Color
    let on: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(on ? color : Color.clear)
            RoundedRectangle(cornerRadius: 4).strokeBorder(on ? Color.clear : Theme.fg3, lineWidth: 1.5)
            Image(systemName: "checkmark").font(.system(size: 7.5, weight: .bold)).foregroundStyle(Color.dyn("#121216", "#15151A")).opacity(on ? 1 : 0)
        }
        .frame(width: 14, height: 14)
        .animation(Motion.base, value: on)
    }
}

struct CalendarRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let cal: CalendarInfo
    @State private var hover = false
    var body: some View {
        let off = model.hiddenCalendars.contains(cal.id)
        Button { model.toggleCalendar(cal.id) } label: {
            HStack(spacing: 10) {
                CalendarCheckbox(color: Palettes.cc(cal.colorHex, dark: scheme == .dark).color, on: !off).padding(.leading, -2)
                Text(cal.title).font(.ui(12.5)).foregroundStyle(off ? Theme.fg3 : Theme.fg).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 0)
                if cal.icon == .feed { SFIcon(name: "dot.radiowaves.up.forward", size: 9.5, color: Theme.fg3).opacity(hover ? 1 : 0) }
                if cal.isDefault { Text("default").font(.ui(10.5)).foregroundStyle(Theme.fg3) }
            }
            .padding(.leading, 17).padding(.trailing, 12)
            .frame(height: 28)
            .background(hover ? Theme.hover : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
        .help("\(off ? "Show" : "Hide") \(cal.title)\(cal.icon == .feed ? " (read-only feed)" : "")")
    }
}

/// 40 pt foot row: gear, "Settings", ⌘, on hover.
struct SidebarFoot: View {
    @Environment(AppModel.self) private var model
    @State private var hover = false
    var body: some View {
        Button { model.overlay = .settings } label: {
            HStack(spacing: 9) {
                SFIcon(name: "gearshape", size: 12.5, color: Theme.fg3)
                Text("Settings").font(.ui(12.5)).foregroundStyle(hover ? Theme.fg : Theme.fg2)
                Spacer(minLength: 0)
                Keycaps(keys: ["\u{2318}", ","]).opacity(hover ? 1 : 0)
            }
            .padding(.leading, 16).padding(.trailing, 12).frame(height: 40)
            .background(hover ? Theme.hover : Color.clear)
            .overlay(alignment: .top) { Hairline() }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
        .help("Settings  \u{2318},")
    }
}
