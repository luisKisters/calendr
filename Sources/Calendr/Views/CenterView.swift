import SwiftUI
import CalendrKit

/// Chrome metrics from design/mockup-v3/app.css (`.head`, `--side-w`).
enum ChromeDim {
    static let headerHeight: CGFloat = 60
    static let sidebarWidth: CGFloat = 236
    /// Header leading inset with the sidebar hidden: clears the traffic lights.
    static let headerInsetNoSidebar: CGFloat = 92
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
        .overlay(alignment: .bottom) { ToastHost() }
    }
}

/// Title left, controls right: "Sep – Oct 2026  W40  [with Maya ×]  ...  Day Week Month  ‹ Today ›  [Search ⌘K]".
struct ToolbarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            if !model.sidebarVisible {
                IconButton(name: "sidebar.left", size: 14, help: "Show sidebar  `") { model.toggleSidebar() }.padding(.trailing, 2)
            }
            HeaderTitle()
            ForEach(model.shownTeammates) { MateChip(mate: $0).fixedSize() }
            Spacer(minLength: 0)
            ViewTabs()
            HStack(spacing: 2) {
                IconButton(name: "chevron.left", size: 12, help: "Previous \(model.viewMode.title.lowercased())  K") { model.previous() }
                TodayButton()
                IconButton(name: "chevron.right", size: 12, help: "Next \(model.viewMode.title.lowercased())  J") { model.next() }
            }
            SearchButton()
        }
        .padding(.leading, model.sidebarVisible ? 20 : ChromeDim.headerInsetNoSidebar).padding(.trailing, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// "Today", quiet while today is on screen. Its own view so the toolbar body does not depend on the visible period.
struct TodayButton: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        TextButton(title: "Today", quiet: model.chromeShowsToday) { model.goToToday() }.help("Go to today  T")
    }
}

struct HeaderTitle: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let t = model.chromeTitle
        HStack(spacing: 10) {
            (Text(t.main).font(.ui(22, .semibold)).tracking(-0.48).foregroundColor(Theme.fg)
             + Text(" " + t.year).font(.calMono(22)).foregroundColor(Theme.fg3))
                .lineLimit(1).fixedSize()
            if model.viewMode != .month && model.authState == .authorized {
                Text(model.weekLabel).font(.calMono(11)).foregroundStyle(Theme.fg3).padding(.top, 5).fixedSize()
            }
        }
        .id(model.headerTitleKey)
        .transition(.opacity)
        .animation(Motion.base, value: model.headerTitleKey)
    }
}

extension AppModel {
    var headerTitleKey: String { chromeTitle.main + chromeTitle.year + weekLabel }
}

/// The overlaid teammate: striped swatch in their colour, "with Maya Sterling", × removes the overlay.
struct MateChip: View {
    @Environment(AppModel.self) private var model
    let mate: Teammate
    @State private var hover = false
    var body: some View {
        let c = Color(hex: model.mateColorHex(mate))
        Button { model.toggleMate(mate) } label: {
            HStack(spacing: 6) {
                ZStack {
                    Canvas { ctx, size in
                        var p = Path()
                        var x: CGFloat = -size.height
                        while x < size.width { p.move(to: CGPoint(x: x, y: size.height)); p.addLine(to: CGPoint(x: x + size.height, y: 0)); x += 4 }
                        ctx.stroke(p, with: .color(c.opacity(0.45)), lineWidth: 1.4)
                    }
                    RoundedRectangle(cornerRadius: 3).strokeBorder(c, lineWidth: 1)
                }
                .frame(width: 10, height: 10).clipShape(RoundedRectangle(cornerRadius: 3))
                Text("with \(mate.name)").font(.ui(12)).foregroundStyle(Theme.fg).lineLimit(1)
                SFIcon(name: "xmark", size: 9, color: Theme.fg3, weight: .medium)
            }
            .padding(.leading, 8).padding(.trailing, 6).frame(height: 24)
            .background(Capsule().fill(hover ? Theme.hover : .clear))
            .overlay(Capsule().strokeBorder(Theme.hair2, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
        .help("Hide \(mate.name)\u{2019}s calendar")
    }
}

/// Day Week Month as text tabs: no container, the active one fg 600 over a 1.5 pt rule.
struct ViewTabs: View {
    @Environment(AppModel.self) private var model
    @Namespace private var rule
    var body: some View {
        HStack(spacing: 16) {
            ForEach([(ViewMode.day, "Day", "D"), (ViewMode.week, "Week", "W"), (ViewMode.month, "Month", "M")], id: \.1) { mode, title, key in
                ViewTab(title: title, on: model.viewMode.baseMode == mode, rule: rule) { model.setMode(mode) }
                    .help("\(title) view  \(key)")
            }
        }
        .padding(.horizontal, 6)
        .animation(Motion.base, value: model.viewMode.baseMode)
    }
}

struct ViewTab: View {
    let title: String
    let on: Bool
    let rule: Namespace.ID
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Text(title).font(.ui(12.5, on ? .semibold : .medium))
                .foregroundStyle(on || hover ? Theme.fg : Theme.fg3)
                .frame(height: 26)
                .overlay(alignment: .bottom) {
                    if on { RoundedRectangle(cornerRadius: 1).fill(Theme.act).frame(height: 1.5).offset(y: 1).matchedGeometryEffect(id: "rule", in: rule) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.base, value: hover)
    }
}

/// Line button that opens the command menu: glyph, "Search", ⌘K.
struct SearchButton: View {
    @Environment(AppModel.self) private var model
    @State private var hover = false
    var body: some View {
        Button { model.openPalette(.all) } label: {
            HStack(spacing: 7) {
                ChromeIcon(name: .search, color: Theme.fg2)
                Text("Search").font(.ui(12.5)).foregroundStyle(Theme.fg2).padding(.trailing, 8)
                Keycap(text: "\u{2318}K")
            }
            .padding(.leading, 9).padding(.trailing, 6).frame(height: 28)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(hover ? Theme.hover : .clear))
            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Theme.hair2, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
        .help("Search, go to a date, run a command  \u{2318}K")
    }
}

extension ViewMode {
    /// Custom N-day ranges map onto Week in the view switch.
    var baseMode: ViewMode { if case .custom = self { return .week }; return self }
}
