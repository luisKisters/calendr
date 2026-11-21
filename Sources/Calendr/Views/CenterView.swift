import SwiftUI
import CalendrKit

/// Chrome metrics (mockup-v11 `.hdr`: 48 pt, padding 0 12 0 20, gap 10).
enum ChromeDim {
    static let headerHeight: CGFloat = Dim.toolbarHeight
    static let sidebarWidth: CGFloat = 236
    static let headerLeading: CGFloat = 20
    static let headerTrailing: CGFloat = 12
    /// Header leading inset with the sidebar hidden: the traffic lights (20 + 52) and their 4 pt margin plus the gap.
    static let headerInsetNoSidebar: CGFloat = 86
}

struct CenterView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView().frame(height: ChromeDim.headerHeight)
            if model.authState != .authorized {
                AccessEmptyState()
            } else if model.viewMode == .month {
                MonthView()
            } else {
                DayHeaderView().frame(height: Dim.dayHeaderHeight)
                AllDayView()
                TimeGridView()
            }
        }
        .background(Theme.bg)
        .overlay(alignment: .bottom) { ToastHost(yieldsToSheet: true) }
    }
}

/// Mockup-v11 `.hdr`: the title left (Geist 15 / 600, the year 400 fg3), then on the right the view switch, ‹ Today › and the
/// right-column toggle: "November 2026  [with Maya ×]  ...  [Day Week Month]  ‹ Today ›  ▯". No week label (its number is the
/// title's tooltip). v4: no search button; search is the right column's field (`/`, Command-F).
struct ToolbarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let unit = model.viewMode.baseMode.title.lowercased()
        let right = model.rightColumnVisible
        HStack(spacing: 10) {
            if !model.sidebarVisible {
                ChromeIconButton(icon: .side, probe: "showSidebar", help: "Show sidebar  `") { model.toggleSidebar() }
            }
            HeaderTitle()
            ForEach(model.shownTeammates) { MateChip(mate: $0).fixedSize() }
            Spacer(minLength: 0)
            ViewTabs()
            // `.nav`: gap 4.
            HStack(spacing: 4) {
                ChromeIconButton(icon: .left, probe: "prev", help: "Previous \(unit)  K") { model.previous() }
                TodayButton()
                ChromeIconButton(icon: .right, probe: "next", help: "Next \(unit)  J") { model.next() }
            }
            ChromeIconButton(icon: .sideRight, on: !right, probe: "togRight",
                             help: "\(right ? "Hide" : "Show") right column  \u{2325}\u{2318}I") { model.toggleRightColumn() }
        }
        .padding(.leading, model.sidebarVisible ? ChromeDim.headerLeading : ChromeDim.headerInsetNoSidebar).padding(.trailing, ChromeDim.headerTrailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// `.btn-line` "Today": 26 pt, padding 0 12, radius 8, 12 / 400 fg1 on `raised` (Paper adds a warm 1 pt edge); hover mixes fg1 6 %
/// into the fill. It looks the same whether or not today is on screen, as in the mockup.
struct TodayButton: View {
    @Environment(AppModel.self) private var model
    @State private var hover = false
    var body: some View {
        let hot = hover || HoverProbe.shared.target == "today"
        Button { model.goToToday() } label: {
            Text("Today").font(.text).tracking(TypeTrack.text).foregroundStyle(Theme.fg)
                .padding(.horizontal, Space.m).frame(height: Dim.iconButton)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(hot ? Theme.buttonHover : Theme.bg2))
                .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Theme.buttonEdge, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hot)
        .help("Go to today  T")
    }
}

/// `.hdr h2`: 15 / 600 fg1 with the year in 400 fg3, line 24. In week and day view its tooltip is the ISO week.
struct HeaderTitle: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let t = model.chromeTitle
        (Text(t.main).font(.title15).tracking(TypeTrack.title).foregroundColor(Theme.fg)
         + Text(" " + t.year).font(.title15Light).tracking(TypeTrack.title).foregroundColor(Theme.fg3))
            .lineLimit(1).fixedSize()
            .frame(height: 24)
            // The mockup's 21 pt line box sits at y 13.5 and Chrome snaps it to 14: half a point below SwiftUI's centring.
            .offset(y: 0.5)
            .help(model.viewMode != .month && model.authState == .authorized ? model.weekLabel : "")
            .id(model.headerTitleKey)
            .transition(.opacity)
            .animation(Motion.base, value: model.headerTitleKey)
    }
}

extension AppModel {
    var headerTitleKey: String { chromeTitle.main + chromeTitle.year }
}

/// The overlaid teammate: striped swatch in their colour, "with Maya Sterling", × removes the overlay.
struct MateChip: View {
    @Environment(AppModel.self) private var model
    let mate: Teammate
    @State private var hover = false
    var body: some View {
        let c = Theme.calendarMark(model.mateColorHex(mate))
        Button { model.toggleMate(mate) } label: {
            HStack(spacing: 6) {
                ZStack {
                    Canvas { ctx, size in
                        var p = Path()
                        var x: CGFloat = -size.height
                        while x < size.width { p.move(to: CGPoint(x: x, y: size.height)); p.addLine(to: CGPoint(x: x + size.height, y: 0)); x += 4 }
                        ctx.stroke(p, with: .color(c.opacity(0.45)), lineWidth: 1.4)
                    }
                    RoundedRectangle(cornerRadius: Radius.swatch).strokeBorder(c, lineWidth: 1)
                }
                .frame(width: 10, height: 10).clipShape(RoundedRectangle(cornerRadius: Radius.swatch))
                Text("with \(mate.name)").font(.text).foregroundStyle(Theme.fg).lineLimit(1)
                SFIcon(name: "xmark", size: 9, color: Theme.fg3, weight: .medium)
            }
            .padding(.leading, 8).padding(.trailing, 6).frame(height: 24)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(hover ? Theme.hover : .clear))
            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Theme.hair2, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: Radius.control))
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
        .help("Hide \(mate.name)\u{2019}s calendar")
    }
}

/// Day / Week / Month: the one `Segmented`.
struct ViewTabs: View {
    @Environment(AppModel.self) private var model
    static let modes: [(ViewMode, String, String)] = [(.day, "Day", "D"), (.week, "Week", "W"), (.month, "Month", "M")]
    var body: some View {
        Segmented(options: Self.modes.map { ($0.0, $0.1) }, selection: model.viewMode.baseMode,
                  helps: Self.modes.map { "\($0.1) view  \($0.2)" }) { model.setMode($0) }
    }
}

extension ViewMode {
    /// Custom N-day ranges map onto Week in the view switch.
    var baseMode: ViewMode { if case .custom = self { return .week }; return self }
}
