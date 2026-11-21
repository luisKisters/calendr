import SwiftUI
import HorionKit

/// Sidebar metrics (mockup-v11 `.side`: 236 wide, padding 8 12 12). Rows and group headers reach 4 pt past the padding
/// (x 8 … 228); their content starts at 16 (square, labels) and the names at 38. Trailing buttons end at 224.
enum SidebarDim {
    static let top: CGFloat = 8
    static let pad: CGFloat = 12
    static let bottom: CGFloat = 12
    /// The 28 pt top row (`.wtop`) with the hide button.
    static let topRow: CGFloat = 28
    /// `.cal`: 26 pt; `.grp`: 24 pt with 12 above and 2 below.
    static let row: CGFloat = 26
    static let groupRow: CGFloat = 24
    static let groupTop: CGFloat = 12
    static let groupBottom: CGFloat = 2
    /// The calendar square (`.cal .cb`) and the gap to the name.
    static let square: CGFloat = 12
    static let squareGap: CGFloat = 10
    /// Rows reach 4 pt outside the pane padding; their leading padding is 8 (content at 16), trailing 4 (buttons end at 224).
    static let rowOutset: CGFloat = 4
    static let rowLeading: CGFloat = 8
    static let rowTrailing: CGFloat = 4
    /// Content edge (16) and the name edge (38).
    static let glyph: CGFloat = pad + rowLeading - rowOutset
    static let text: CGFloat = glyph + square + squareGap
}

/// Month and calendars: the top row with the hide button, the mini month, the calendar groups by account, Settings at the foot.
struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ChromeIconButton(icon: .side, small: true, rail: true, probe: "hideSidebar", help: "Hide sidebar  `") { model.toggleSidebar() }
            }
            .frame(height: SidebarDim.topRow)
            .padding(.bottom, Space.m)

            MiniMonth()

            if model.authState != .authorized {
                SidebarSkeleton()
                Spacer(minLength: 0)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    CalendarList().padding(.bottom, Space.m)
                }
                .padding(.top, Space.s)
            }
            SidebarFoot()
        }
        .padding(.top, SidebarDim.top).padding(.horizontal, SidebarDim.pad).padding(.bottom, SidebarDim.bottom)
        .frame(width: ChromeDim.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.rail)
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.hair).frame(width: 1) }
    }
}

/// Shown while there is no calendar access.
struct SidebarSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach([132, 96, 118], id: \.self) { w in
                RoundedRectangle(cornerRadius: Radius.mark).fill(Theme.hair).frame(width: CGFloat(w), height: 10).padding(.bottom, 9)
            }
            Text("Your calendars appear here once Horion can read them.").font(.text).foregroundStyle(Theme.fg2).lineSpacing(3).padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(Theme.bg1))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Theme.hair, lineWidth: 1))
        .padding(.top, 14)
    }
}

/// Mockup-v11 `.mm-h` + `.mm`: the title (12 / 500, the year 400 fg3) with ‹ ›, the weekday letters (11, fg3, 500 in Dark),
/// six rows of 24 pt day cells 2 pt apart (11 tabular: fg2 in the month, fg3 outside, fg1 in the visible week, whose cells sit on
/// one rounded `hoverRail` band). Today is a `selected` cell with a 1 pt `segRing` edge and a 600 numeral; in day view the open
/// day has a 1 pt fg3 ring. With week numbers on, a 20 pt column of ISO week numbers opens that week.
struct MiniMonth: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var hoverDay: Date?
    @State private var hoverWeek: Date?
    /// The grid on screen, read by the day buttons' actions when they run: the buttons are not re-rendered when only the month
    /// changes, so their closures must not capture the dates.
    @State private var shown = MiniMonthGrid()
    /// Day cell height and the row pitch (`.mm .d { height: 24 }`, `row-gap: 2`).
    static let cell: CGFloat = 24
    static let rowGap: CGFloat = 2
    static let pitch: CGFloat = cell + rowGap
    /// `.mm-h`: a 22 pt row and 4 below; the weekday letters 18 (+ the 2 pt row gap).
    static let titleRow: CGFloat = 22
    static let weekdayRow: CGFloat = 18
    /// `.mm.wn`: the week-number column.
    static let weekColumn: CGFloat = 20

    /// Natural height of the mini month for `rows` week rows: title 22 + 4, weekday letters 18, rows of 2 + 24.
    static func height(rows: Int) -> CGFloat { titleRow + 4 + weekdayRow + CGFloat(rows) * pitch }
    static let width: CGFloat = ChromeDim.sidebarWidth - 2 * SidebarDim.pad

    var body: some View {
        let math = model.math
        let month = model.miniMonth
        let grid = math.monthGrid(for: month)
        let rows = Array(grid.indices)     // always six rows, as the mockup's mini month (42 cells)
        let weeks = model.settings.showWeekNumbers
        let lead = weeks ? Self.weekColumn : 0
        let band = model.viewMode.baseMode == .week ? math.startOfWeek(model.visibleStart) : nil
        let first = math.calendar.firstWeekday
        let now = model.now
        let dark = scheme == .dark
        let selectedDay: Date? = model.viewMode == .day ? model.visibleStart : nil
        let shown = shown
        let _ = shown.grid = grid
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                Button { model.miniMonth = math.startOfMonth(model.visibleStart) } label: {
                    (Text(verbatim: model.fmt.monthLong(month)).font(.textMedium).tracking(TypeTrack.text).foregroundColor(Theme.fg)
                     + Text(verbatim: " " + String(math.year(month))).font(.textTab).tracking(TypeTrack.text).foregroundColor(Theme.fg3))
                        .padding(.leading, SidebarDim.rowOutset).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain).help("Back to the visible \(model.viewMode.title.lowercased())")
                ChromeIconButton(icon: .left, small: true, rail: true, help: "Previous month") { model.stepMiniMonth(-1) }
                ChromeIconButton(icon: .right, small: true, rail: true, help: "Next month") { model.stepMiniMonth(1) }
            }
            .frame(height: Self.titleRow).padding(.bottom, 4)

            HStack(spacing: 0) {
                if weeks { Color.clear.frame(width: Self.weekColumn) }
                ForEach(0..<7, id: \.self) { i in
                    Text(String(Fmt.weekdayShort[(first - 1 + i) % 7].prefix(1)))
                        .font(.smallLabel(dark: dark)).tracking(TypeTrack.small).foregroundStyle(Theme.fg3).frame(maxWidth: .infinity)
                }
            }
            .frame(height: Self.weekdayRow)

            VStack(spacing: 0) {
                // All six rows always exist; a row the month does not need collapses (the original inserted and removed it, which
                // rebuilt seven buttons on every month change between five and six weeks).
                ForEach(grid.indices, id: \.self) { r in
                    let week = grid[r]
                    let visible = rows.contains(r)
                    let banded = band.map { math.isSameDay($0, week[0]) } == true
                    HStack(spacing: 0) {
                        if weeks {
                            MiniWeekNumber(week: week[0], number: model.isoWeek(week[0]), hovered: hoverWeek == week[0], dark: dark,
                                           action: { model.openWeek(week[0]) },
                                           onHover: { hoverWeek = $0 ? week[0] : (hoverWeek == week[0] ? nil : hoverWeek) })
                                .equatable()
                        }
                        // Cells keep their place (identity by column) when the month changes: they update instead of being rebuilt.
                        HStack(spacing: 0) {
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
                        // `.mm .wk`: the visible week's seven cells on one band, rounded at its ends.
                        .background(RoundedRectangle(cornerRadius: Radius.small).fill(banded ? Theme.hoverRail : .clear))
                    }
                    .frame(height: Self.cell)
                    .padding(.top, Self.rowGap)
                    .frame(height: visible ? Self.pitch : 0, alignment: .top)
                    .opacity(visible ? 1 : 0)
                    .allowsHitTesting(visible)
                    .accessibilityHidden(!visible)
                }
            }
            .overlay {
                MiniMonthNumerals(phase: Double(MiniMonthNumerals.index(month, math)), month: month, today: math.startOfDay(now),
                                  band: band, hover: hoverDay, leading: lead, math: math)
                    .equatable()
            }
        }
        // A fixed size keeps the rest of the window from re-measuring the mini month on every navigation.
        .frame(width: Self.width, height: Self.height(rows: rows.count))
        .animation(Motion.base, value: band)
    }
}

/// One mini-month day: the hover and today cells, the day-view ring, the button (its tooltip is set by `MiniMonth`). The numeral
/// is drawn by `MiniMonthNumerals`. Equatable on what it shows, so neither a week step nor a month change re-renders 42 buttons.
private struct MiniDay: View, Equatable {
    let today: Bool
    let selected: Bool
    let hovered: Bool
    let action: () -> Void
    let onHover: (Bool) -> Void

    static func == (a: Self, b: Self) -> Bool { a.today == b.today && a.selected == b.selected && a.hovered == b.hovered }

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: Radius.small)
                .fill(today ? Theme.selected : hovered ? Theme.hoverRail : .clear)
                .overlay(RoundedRectangle(cornerRadius: Radius.small).strokeBorder(today ? Theme.segRing : selected ? Theme.fg3 : .clear, lineWidth: 1))
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

/// The mini month's numerals in one Canvas. Each numeral is a `Text` symbol (1 to 31 in fg2, fg3 and fg1, today's in 600), laid
/// out once and reused, so a month change redraws one canvas instead of re-resolving 42 texts.
/// `phase` is the month as a month index and is animatable: when the month changes inside an animation (the week band moving into
/// another month), the old and new numerals cross-fade the way the per-day views they replace faded out and in.
private struct MiniMonthNumerals: View, Equatable, Animatable {
    var phase: Double
    let month: Date
    let today: Date
    /// The visible week (its numerals are fg1) and the hovered day (fg1).
    let band: Date?
    let hover: Date?
    let leading: CGFloat
    let math: CalendarMath
    @Environment(\.displayScale) private var scale

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    static func index(_ month: Date, _ math: CalendarMath) -> Int { math.year(month) * 12 + math.month(month) - 1 }

    static func == (a: Self, b: Self) -> Bool {
        a.phase == b.phase && a.month == b.month && a.today == b.today && a.band == b.band && a.hover == b.hover
            && a.leading == b.leading && a.math.calendar == b.math.calendar
    }

    /// Symbol ids of the visible cells of the month `offset` months from `month`, row by row: the day (fg2), plus 100 outside the
    /// month (fg3), 300 in the visible week or under the pointer (fg1), or 200 for today (the rows shown are those `MiniMonth` shows).
    private func cells(_ offset: Int) -> [Int] {
        let m = math.addMonths(month, offset)
        let grid = math.monthGrid(for: m)
        return grid.indices.flatMap { r in
            let banded = band.map { math.isSameDay($0, grid[r][0]) } == true
            return grid[r].map { d in
                let n = math.day(d)
                if math.isSameDay(d, today) { return 200 + n }
                if !math.isSameMonth(d, m) { return hover.map { math.isSameDay($0, d) } == true ? 300 + n : 100 + n }
                return banded || hover.map { math.isSameDay($0, d) } == true ? 300 + n : n
            }
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
                    let x = leading + (CGFloat(i % 7) + 0.5) * cw, y = CGFloat(i / 7) * MiniMonth.pitch + MiniMonth.rowGap + MiniMonth.cell / 2
                    ctx.draw(sym, at: CGPoint(x: px(x), y: px(y)), anchor: .center)
                }
            }
        } symbols: {
            ForEach(1...31, id: \.self) { n in numeral(n, today: false, color: Theme.fg2).tag(n) }
            ForEach(101...131, id: \.self) { code in numeral(code - 100, today: false, color: Theme.fg3).tag(code) }
            ForEach(301...331, id: \.self) { code in numeral(code - 300, today: false, color: Theme.fg).tag(code) }
            numeral(todayNumber, today: true, color: Theme.fg).tag(200 + todayNumber)
        }
        .allowsHitTesting(false)
    }

    private func numeral(_ n: Int, today: Bool, color: Color) -> some View {
        Text(verbatim: String(n)).font((today ? .smallTabSemibold : .smallTab)).tracking(TypeTrack.small).foregroundStyle(color)
            .frame(width: 26, height: MiniMonth.cell)
    }
}

/// ISO week number left of a mini-month row (week numbers on, `.mm .wkn`): 20 pt, 11 fg3 (500 in Dark); opens that week.
private struct MiniWeekNumber: View, Equatable {
    let week: Date
    let number: Int
    let hovered: Bool
    let dark: Bool
    let action: () -> Void
    let onHover: (Bool) -> Void

    static func == (a: Self, b: Self) -> Bool { a.week == b.week && a.number == b.number && a.hovered == b.hovered && a.dark == b.dark }

    var body: some View {
        Button(action: action) {
            Text(verbatim: String(number)).font(.smallLabelTab(dark: dark)).tracking(TypeTrack.small)
                .foregroundStyle(hovered ? Theme.fg : Theme.fg3)
                .frame(width: MiniMonth.weekColumn, height: MiniMonth.cell)
                .background(RoundedRectangle(cornerRadius: Radius.small).fill(hovered ? Theme.hoverRail : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .help("Week \(number)")
    }
}

/// Every calendar, hidden ones included, under its account's group header.
struct CalendarList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.store.accounts) { acc in AccountSection(account: acc) }
        }
        .frame(width: MiniMonth.width, alignment: .leading)
    }
}

/// Mockup-v11 `.grp` (v8 decision D): the account's short name, 12 / 500 fg3; hover turns it fg1 and shows a chevron. A click
/// folds the group: the chevron then stays, turned right, and the count follows the name ("9 · 1 hidden"). The address is the
/// tooltip.
struct AccountSection: View {
    @Environment(AppModel.self) private var model
    let account: CalendarAccount
    @State private var hover = false
    var body: some View {
        let hot = hover || HoverProbe.shared.target == "acct:\(account.id)"
        let closed = model.collapsedGroups.contains(account.id)
        let hidden = account.calendars.filter { model.hiddenCalendars.contains($0.id) }.count
        VStack(alignment: .leading, spacing: 0) {
            Button { model.toggleGroup(account.id) } label: {
                HStack(spacing: Space.xs) {
                    Text(AccountName.display(account.name)).font(.label).tracking(TypeTrack.label).foregroundStyle(hot ? Theme.fg : Theme.fg3)
                        .lineLimit(1).truncationMode(.tail)
                    if closed {
                        Text("\(account.calendars.count)" + (hidden > 0 ? " \u{00B7} \(hidden) hidden" : "")).font(.textTab).tracking(TypeTrack.text)
                            .foregroundStyle(Theme.fg3).lineLimit(1).fixedSize().padding(.leading, 4)
                    }
                    ChromeIcon(name: .down, size: 12, color: Theme.fg3)
                        .rotationEffect(.degrees(closed ? -90 : 0))
                        .frame(width: 16, height: 16)
                        .opacity(hot || closed ? 1 : 0).padding(.leading, 2)
                    Spacer(minLength: 0)
                }
                .padding(.leading, SidebarDim.rowLeading).padding(.trailing, SidebarDim.rowTrailing)
                .frame(height: SidebarDim.groupRow)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }
            .help("\(closed ? "Expand" : "Collapse") \(AccountName.display(account.name)) \u{00B7} \(account.name)")
            .padding(.horizontal, -SidebarDim.rowOutset)
            .padding(.top, SidebarDim.groupTop).padding(.bottom, closed ? 0 : SidebarDim.groupBottom)   // margins collapse after a folded group
            if !closed {
                ForEach(account.calendars) { CalendarRow(cal: $0) }
            }
        }
        .animation(Motion.base, value: hot)
        .animation(Motion.base, value: closed)
    }
}

/// Mockup-v11 `.cal` (v8 decision E): a 12 pt square in the calendar's mark colour, the name (12 / 400 fg1), and an eye at the
/// right on hover. The square and the eye hide the calendar; a hidden one stays in the list with a 35 % square, an fg3 name and
/// an eye-slash that is always shown (click = show). The name does nothing. 26 pt, the hover box 4 pt past the pane padding.
struct CalendarRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let cal: CalendarInfo
    @State private var hover = false
    @State private var hoverEye = false
    var body: some View {
        let dark = scheme == .dark
        let off = model.hiddenCalendars.contains(cal.id)
        let hot = hover || HoverProbe.shared.target == "cal:\(cal.id)"
        let eyeHot = hoverEye || HoverProbe.shared.target == "eye:\(cal.id)"
        let mark = Palettes.cc(cal.colorHex, dark: dark)
        let help = "\(off ? "Show" : "Hide") \(cal.title)"
        HStack(spacing: SidebarDim.squareGap) {
            Button { model.toggleCalendar(cal.id) } label: {
                RoundedRectangle(cornerRadius: Radius.swatch)
                    .fill((off ? mark.mixed(with: InkRGB.of(dark).rail, 0.65) : mark).color)
                    .frame(width: SidebarDim.square, height: SidebarDim.square)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).help(help)
            Text(cal.title).font(.text).tracking(TypeTrack.text).foregroundStyle(off ? Theme.fg3 : Theme.fg).lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(cal.title + (off ? " \u{00B7} hidden" : "") + (cal.icon == .feed ? " \u{00B7} read-only feed" : "") + (cal.isDefault ? " \u{00B7} default" : ""))
            Button { model.toggleCalendar(cal.id) } label: {
                ChromeIcon(name: off ? .eyeOff : .eye, size: 15, color: eyeHot ? Theme.fg : Theme.fg3)
                    .frame(width: Dim.iconButtonSmall, height: Dim.iconButtonSmall)
                    .background(RoundedRectangle(cornerRadius: Radius.small).fill(eyeHot ? Theme.eyeHover : .clear))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hoverEye = $0 }
            .opacity(hot || off ? 1 : 0)
            .help(help)
        }
        .padding(.leading, SidebarDim.rowLeading).padding(.trailing, SidebarDim.rowTrailing)
        .frame(height: SidebarDim.row)
        .background(RoundedRectangle(cornerRadius: Radius.row).fill(hot ? Theme.hoverRail : Color.clear))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .padding(.horizontal, -SidebarDim.rowOutset)
        .animation(Motion.fast, value: hot)
        .animation(Motion.fast, value: eyeHot)
    }
}

/// `.side .foot`: 28 pt, "Settings" 12 fg2 on the content edge, the ⌘ , hint in fg3 at the trailing edge; hover fg1 on the rail
/// hover. No icon.
struct SidebarFoot: View {
    @Environment(AppModel.self) private var model
    @State private var hover = false
    var body: some View {
        let hot = hover || HoverProbe.shared.target == "settings"
        Button { model.overlay = .settings } label: {
            HStack(spacing: Space.m) {
                Text("Settings").font(.text).tracking(TypeTrack.text).foregroundStyle(hot ? Theme.fg : Theme.fg2)
                Spacer(minLength: 0)
                Keycaps(keys: ["\u{2318}", ","])
            }
            .padding(.horizontal, SidebarDim.rowOutset).frame(height: Dim.row)
            .background(RoundedRectangle(cornerRadius: Radius.row).fill(hot ? Theme.hoverRail : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hot)
        .help("Settings  \u{2318},")
    }
}
