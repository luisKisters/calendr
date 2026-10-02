import SwiftUI
import AppKit
import CalendrKit

@MainActor
enum MainWindow {
    /// Set by the main window's content: reopens it after it was closed.
    static var openAction: (() -> Void)?

    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let w = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain && $0.contentView != nil }) {
            w.makeKeyAndOrderFront(nil)
        } else {
            openAction?()
        }
    }
}

/// Hands the main window's `openWindow` to `MainWindow`, so the menu bar can reopen a closed window.
struct MainWindowOpener: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Color.clear.onAppear { MainWindow.openAction = { openWindow(id: "main") } }
    }
}

/// Control-Command-K (`MenuBarHotKey` from anywhere, `KeyRouter` inside the app) opens the status item's menu.
@MainActor
enum MenuBarControl {
    static func open() -> Bool {
        guard let b = MenuBarController.shared?.item.button else { return false }
        b.performClick(nil)
        return true
    }
}

// MARK: Preview (snapshots and the walkthrough; a real NSMenu cannot be drawn offscreen)

/// The colours and metrics of a native dark macOS menu, as in design/mockup-v3/menubar.html. Not Theme tokens: this imitates the system.
private enum NativeMenu {
    static let font = Font.system(size: 13)
    static let small = Font.system(size: 12)
    static let highlight = Color(hex: "#0A66E0")
    static let surface = Color(red: 38 / 255, green: 37 / 255, blue: 44 / 255).opacity(0.94)
    static let dim = Color.white.opacity(0.48)
    static let dim2 = Color.white.opacity(0.3)
    static let time = Color.white.opacity(0.62)
    static let separator = Color.white.opacity(0.11)
    static let soon = Color(hex: "#FF6B61")
    static let rowHeight: CGFloat = 22
    static let separatorHeight: CGFloat = 11
    static let padding: CGFloat = 5
}

/// One line of the drawn menu.
private enum MenuLine {
    case header(String, countdown: String?, soon: Bool)
    case row(Int)          // index into MenuBarMenuModel.rows
    case separator

    var height: CGFloat { if case .separator = self { NativeMenu.separatorHeight } else { NativeMenu.rowHeight } }

    static func list(_ m: MenuBarMenuModel) -> [MenuLine] {
        var out: [MenuLine] = []
        if let f = m.focus, m.head != nil { out += [.header(m.headLabel, countdown: f.text, soon: f.soon), .row(0)] } else { out.append(.header(m.headLabel, countdown: nil, soon: false)) }
        out.append(.separator)
        var i = m.head == nil ? 0 : 1
        for s in m.sections {
            out.append(.header(s.title, countdown: nil, soon: false))
            for _ in s.rows { out.append(.row(i)); i += 1 }
        }
        return out
    }
}

/// The menu drawn from the same model as the NSMenu: dark translucent surface, 22 pt rows, system font and highlight.
struct MenuBarMenuPreview: View {
    let menu: MenuBarMenuModel
    /// Highlighted row (index into `menu.rows`).
    var highlight: Int?
    var maxHeight: CGFloat = 846

    static let footHeight = NativeMenu.separatorHeight * 2 + NativeMenu.rowHeight * 3

    /// Top of row `i` inside the menu surface.
    static func rowTop(_ i: Int, in m: MenuBarMenuModel) -> CGFloat {
        var y = NativeMenu.padding
        for l in MenuLine.list(m) {
            if case .row(let k) = l, k == i { return y }
            y += l.height
        }
        return y
    }

    var body: some View {
        let lines = MenuLine.list(menu)
        let rows = menu.rows
        let content = lines.reduce(0) { $0 + $1.height }
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(lines.indices, id: \.self) { i in
                    switch lines[i] {
                    case .header(let t, let c, let soon): MenuHeaderLine(text: t, countdown: c, soon: soon)
                    case .row(let k): MenuEventRow(row: rows[k], highlighted: highlight == k)
                    case .separator: MenuSeparator()
                    }
                }
            }
            .frame(height: min(content, maxHeight - 2 * NativeMenu.padding - Self.footHeight), alignment: .top)
            .clipped()
            MenuSeparator()
            MenuCommandRow(title: "Open Calendr", key: "\u{2318}1")
            MenuCommandRow(title: "Settings\u{2026}", key: "\u{2318},")
            MenuSeparator()
            MenuCommandRow(title: "Quit Calendr", key: "\u{2318}Q")
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(NativeMenu.padding)
        .menuSurface()
    }
}

/// An event row's menu, drawn.
struct MenuBarSubmenuPreview: View {
    let items: [MenuBarSubItem]

    static func height(_ items: [MenuBarSubItem]) -> CGFloat {
        items.reduce(2 * NativeMenu.padding) { $0 + ($1 == .separator ? NativeMenu.separatorHeight : NativeMenu.rowHeight) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                let it = items[i]
                switch it {
                case .separator: MenuSeparator()
                case .header(let t): MenuHeaderLine(text: t, countdown: nil, soon: false)
                default:
                    HStack(spacing: 8) {
                        ZStack {
                            if case .respond(_, true) = it { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                        }.frame(width: 12).padding(.leading, -1)
                        Text(it.title).font(NativeMenu.font)
                        Spacer(minLength: 18)
                        Text(it.key == "\r" ? "\u{21A9}" : it.key.uppercased()).font(NativeMenu.font).tracking(0.5).foregroundStyle(NativeMenu.dim)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9).frame(height: NativeMenu.rowHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(NativeMenu.padding)
        .menuSurface()
    }
}

private struct MenuHeaderLine: View {
    let text: String
    let countdown: String?
    let soon: Bool
    var body: some View {
        HStack(spacing: 6) {
            Text(text).font(NativeMenu.font).foregroundStyle(NativeMenu.dim)
            if let countdown {
                Text(countdown).font(.system(size: 12, weight: .medium)).monospacedDigit()
                    .foregroundStyle(soon ? NativeMenu.soon : Color.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 9).frame(height: NativeMenu.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MenuSeparator: View {
    var body: some View {
        Rectangle().fill(NativeMenu.separator).frame(height: 1).padding(.horizontal, 9).padding(.vertical, 5)
            .frame(maxWidth: .infinity)
    }
}

private struct MenuEventRow: View {
    let row: MenuBarMenuModel.Row
    let highlighted: Bool
    var body: some View {
        let hl = highlighted
        HStack(spacing: 8) {
            Group {
                if row.tentative && !hl { MenuBarStripes(color: Color(hex: row.colorHex)) } else { Rectangle().fill(hl ? .white : Color(hex: row.colorHex)) }
            }
            .frame(width: 3, height: 14).clipShape(RoundedRectangle(cornerRadius: 1.5))
            Text(row.start).font(NativeMenu.font).monospacedDigit().foregroundStyle(hl ? .white.opacity(0.86) : NativeMenu.time)
                .fixedSize().frame(width: MenuBarColumns.timeWidth, alignment: .leading)
            Text(MenuBarColumns.truncate(row.title)).font(NativeMenu.font).lineLimit(1).fixedSize()
            if let left = row.left {
                Text(left).font(NativeMenu.small).monospacedDigit().foregroundStyle(hl ? .white : NativeMenu.soon)
            }
            Spacer(minLength: 18)
            if let end = row.end {
                Text(end).font(NativeMenu.small).monospacedDigit().foregroundStyle(hl ? .white.opacity(0.86) : NativeMenu.dim)
            }
            ZStack {
                if row.hasSubmenu { Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)) }
            }
            .frame(width: 8).foregroundStyle(hl ? .white.opacity(0.86) : NativeMenu.dim)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9).frame(height: NativeMenu.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 5).fill(hl ? NativeMenu.highlight : .clear))
    }
}

private struct MenuCommandRow: View {
    let title: String
    let key: String
    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(NativeMenu.font).foregroundStyle(.white)
            Spacer(minLength: 18)
            Text(key).font(NativeMenu.font).tracking(0.5).foregroundStyle(NativeMenu.dim)
        }
        .padding(.horizontal, 9).frame(height: NativeMenu.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Tentative bar: 3 pt on, 3 pt off.
private struct MenuBarStripes: View {
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height { ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 3)), with: .color(color)); y += 6 }
        }
    }
}

private extension View {
    func menuSurface() -> some View {
        background(RoundedRectangle(cornerRadius: 10).fill(NativeMenu.surface))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
            .overlay(RoundedRectangle(cornerRadius: 10).inset(by: -1).strokeBorder(Color.black.opacity(0.5), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 25, y: 18)
    }
}

/// The menu bar item as the status item draws it, for the composite.
struct MenuBarItemPreview: View {
    let menu: MenuBarMenuModel
    let display: MenuBarDisplay
    var body: some View {
        HStack(spacing: 6) {
            if let f = menu.focus, display != .icon {
                RoundedRectangle(cornerRadius: 1.5).fill(Color(hex: menu.head?.colorHex ?? "#8A8A8A")).frame(width: 3, height: 13)
                if display == .titleAndCountdown, let t = menu.itemTitle {
                    Text(t)
                    Text("\u{00B7}").opacity(0.5).padding(.horizontal, -2)
                }
                Text(f.text).monospacedDigit().foregroundStyle(f.soon ? NativeMenu.soon : .white)
            } else {
                Circle().strokeBorder(.white, lineWidth: 1.6).frame(width: 15, height: 15)
                    .overlay(alignment: .topTrailing) {
                        Circle().fill(menu.focus?.soon == true ? NativeMenu.soon : .white).frame(width: 5, height: 5).offset(x: 1, y: -1)
                    }
            }
        }
        .font(.system(size: 13, weight: .medium))
    }
}

/// The 1440 x 900 screen of menubar.html: desktop, menu bar, the app window behind, and the open menu under the item.
struct MenuBarScreenPreview: View {
    let menu: MenuBarMenuModel
    let display: MenuBarDisplay
    let clock: String
    var backdrop: NSImage?
    var highlight: Int?
    /// Row (index into `menu.rows`) whose menu is open.
    var submenu: [MenuBarSubItem]?
    var open = true

    private static let size = CGSize(width: 1440, height: 900)
    private static let menuTop: CGFloat = 32

    var body: some View {
        ZStack(alignment: .topLeading) {
            desktop
            if let backdrop {
                Image(nsImage: backdrop).resizable().frame(width: 1150, height: 1150 * 900 / 1440)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                    .saturation(open ? 0.8 : 1).opacity(open ? 0.5 : 1)
                    .shadow(color: .black.opacity(0.6), radius: 40, y: 30)
                    .offset(x: 80, y: 64)
            }
            bar
            if open { menus }
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .clipped()
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    @State private var itemX: CGFloat = 0
    @State private var menuWidth: CGFloat = 0
    @State private var submenuWidth: CGFloat = 0

    /// Under the item, right edges aligned when it would leave the screen; a row menu opens towards the side with room.
    private var menus: some View {
        let x = min(max(itemX, 8), Self.size.width - menuWidth - 8)
        let right = x + menuWidth - 2
        let subX = right + submenuWidth < Self.size.width - 8 ? right : x - submenuWidth + 2
        return ZStack(alignment: .topLeading) {
            MenuBarMenuPreview(menu: menu, highlight: highlight)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { menuWidth = $0 }
                .offset(x: x, y: Self.menuTop)
            if let submenu, let hl = highlight {
                let h = MenuBarSubmenuPreview.height(submenu)
                let top = min(max(Self.menuTop + MenuBarMenuPreview.rowTop(hl, in: menu) - 5, Self.menuTop), Self.size.height - h - 8)
                MenuBarSubmenuPreview(items: submenu)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { submenuWidth = $0 }
                    .offset(x: subX, y: top)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    /// menubar.html `.screen` background. CSS paints the first layer on top, so the blobs are stacked in reverse.
    private var desktop: some View {
        let line = Self.cssLinear(degrees: 160)
        return ZStack {
            LinearGradient(stops: [.init(color: Color(hex: "#13111C"), location: 0), .init(color: Color(hex: "#1D1A2B"), location: 0.5), .init(color: Color(hex: "#0D0C13"), location: 1)],
                           startPoint: line.start, endPoint: line.end)
            Self.blob("#5B2C48", at: CGPoint(x: 0.6, y: 1.1), radii: CGSize(width: 1.1, height: 0.9), fade: 0.6)
            Self.blob("#16405C", at: CGPoint(x: 0.92, y: 0.08), radii: CGSize(width: 0.8, height: 0.7), fade: 0.58)
            Self.blob("#3B2A6B", at: CGPoint(x: 0.12, y: 0), radii: CGSize(width: 0.9, height: 0.8), fade: 0.6)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    /// CSS `linear-gradient(<angle>deg, ...)`: the gradient line runs through the centre and is long enough that the corners get the end colours.
    static func cssLinear(degrees: Double) -> (start: UnitPoint, end: UnitPoint) {
        let a = degrees * .pi / 180, dx = sin(a), dy = -cos(a)
        let half = (abs(size.width * dx) + abs(size.height * dy)) / 2
        let ux = dx * half / size.width, uy = dy * half / size.height
        return (UnitPoint(x: 0.5 - ux, y: 0.5 - uy), UnitPoint(x: 0.5 + ux, y: 0.5 + uy))
    }

    /// CSS `radial-gradient(rx ry at x y, color 0%, transparent fade)`.
    private static func blob(_ hex: String, at c: CGPoint, radii r: CGSize, fade: CGFloat) -> some View {
        let rx = r.width * size.width, ry = r.height * size.height
        return Rectangle()
            .fill(RadialGradient(stops: [.init(color: Color(hex: hex), location: 0), .init(color: Color(hex: hex).opacity(0), location: fade)],
                                 center: .center, startRadius: 0, endRadius: rx))
            .frame(width: 2 * rx, height: 2 * rx)
            .scaleEffect(x: 1, y: ry / rx)
            .position(x: c.x * size.width, y: c.y * size.height)
    }

    private var bar: some View {
        HStack(spacing: 2) {
            Image(systemName: "apple.logo").font(.system(size: 15)).padding(.horizontal, 9)
            Text("Calendr").fontWeight(.bold).padding(.horizontal, 9)
            ForEach(["File", "Edit", "View", "Window", "Help"], id: \.self) { Text($0).padding(.horizontal, 9) }
            Spacer(minLength: 0)
            MenuBarItemPreview(menu: menu, display: display)
                .padding(.horizontal, 9).frame(height: 22)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(open ? 0.2 : 0)))
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minX } action: { itemX = $0 }
            ForEach(["wifi", "battery.100percent", "switch.2"], id: \.self) {
                Image(systemName: $0).font(.system(size: 14)).opacity(0.92).padding(.horizontal, 7)
            }
            Text(clock).monospacedDigit().padding(.horizontal, 9)
        }
        .font(.system(size: 13))
        .padding(.leading, 16).padding(.trailing, 10)
        .frame(width: Self.size.width, height: 30)
        .background(Color(red: 20 / 255, green: 18 / 255, blue: 28 / 255).opacity(0.42))
    }
}
