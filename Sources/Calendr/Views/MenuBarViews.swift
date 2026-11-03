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

/// The colours and metrics of a native dark macOS menu. Not Theme tokens: this imitates the system.
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
    case join(Int)         // a row with the Join button (`MenuBarMenuModel.joinIndices`)
    case separator

    var height: CGFloat {
        switch self {
        case .separator: NativeMenu.separatorHeight
        case .join: MenuJoinRow.height
        default: NativeMenu.rowHeight
        }
    }

    static func list(_ m: MenuBarMenuModel) -> [MenuLine] {
        var out: [MenuLine] = []
        func line(_ i: Int) -> MenuLine { m.joinIndices.contains(i) ? .join(i) : .row(i) }
        if let f = m.focus, m.head != nil { out += [.header(m.headLabel, countdown: f.text, soon: f.soon), line(0)] } else { out.append(.header(m.headLabel, countdown: nil, soon: false)) }
        out.append(.separator)
        var i = m.head == nil ? 0 : 1
        for s in m.sections {
            out.append(.header(s.title, countdown: nil, soon: false))
            for _ in s.rows { out.append(line(i)); i += 1 }
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
    /// The pointer is on the Join button of the Join row.
    var joinHover = false

    static let footHeight = NativeMenu.separatorHeight * 2 + NativeMenu.rowHeight * 3

    /// Top of row `i` inside the menu surface.
    static func rowTop(_ i: Int, in m: MenuBarMenuModel) -> CGFloat {
        var y = NativeMenu.padding
        for l in MenuLine.list(m) {
            if case .row(let k) = l, k == i { return y }
            if case .join(let k) = l, k == i { return y }
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
                    case .join(let k):
                        MenuJoinRow(row: rows[k], detail: MenuJoinRow.detail(rows[k], focus: k == 0 && menu.head != nil ? menu.focus : nil),
                                    highlighted: highlight == k, joinHover: joinHover)
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
    /// Index into `items` of the hovered entry.
    var highlight: Int? = nil

    /// Top of item `i` inside the submenu surface.
    static func itemTop(_ i: Int, in items: [MenuBarSubItem]) -> CGFloat {
        items.prefix(i).reduce(NativeMenu.padding) { $0 + ($1 == .separator ? NativeMenu.separatorHeight : NativeMenu.rowHeight) }
    }

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
                    .background(RoundedRectangle(cornerRadius: Radius.row).fill(highlight == i ? NativeMenu.highlight : .clear))
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
            .frame(width: 3, height: 14).clipShape(RoundedRectangle(cornerRadius: Radius.bar))
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
        .background(RoundedRectangle(cornerRadius: Radius.row).fill(hl ? NativeMenu.highlight : .clear))
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
        background(RoundedRectangle(cornerRadius: Radius.surface).fill(NativeMenu.surface))
            .overlay(RoundedRectangle(cornerRadius: Radius.surface).strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
            .overlay(RoundedRectangle(cornerRadius: Radius.surface).inset(by: -1).strokeBorder(Color.black.opacity(0.5), lineWidth: 1))
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
                RoundedRectangle(cornerRadius: Radius.bar).fill(Color(hex: menu.head?.colorHex ?? "#8A8A8A")).frame(width: 3, height: 13)
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
    /// Hovered entry of the open row menu.
    var subHighlight: Int? = nil
    /// The pointer is on the Join button of the Join row.
    var joinHover = false

    /// Screen point of the middle of submenu item `i` (the row menu opens to the left of the menu here, 1440 pt wide screen).
    static func submenuItemTop(_ i: Int, items: [MenuBarSubItem], row: Int, in menu: MenuBarMenuModel) -> CGFloat {
        let h = MenuBarSubmenuPreview.height(items)
        let top = min(max(menuTop + MenuBarMenuPreview.rowTop(row, in: menu) - 5, menuTop), size.height - h - 8)
        return top + MenuBarSubmenuPreview.itemTop(i, in: items) + NativeMenu.rowHeight / 2
    }

    private static let size = CGSize(width: 1440, height: 900)
    private static let menuTop: CGFloat = 32

    var body: some View {
        ZStack(alignment: .topLeading) {
            desktop
            if let backdrop {
                Image(nsImage: backdrop).resizable().frame(width: 1150, height: 1150 * 900 / 1440)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.surface))
                    .overlay(RoundedRectangle(cornerRadius: Radius.surface).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
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
            MenuBarMenuPreview(menu: menu, highlight: highlight, joinHover: joinHover)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { menuWidth = $0 }
                .offset(x: x, y: Self.menuTop)
            if let submenu, let hl = highlight {
                let h = MenuBarSubmenuPreview.height(submenu)
                let top = min(max(Self.menuTop + MenuBarMenuPreview.rowTop(hl, in: menu) - 5, Self.menuTop), Self.size.height - h - 8)
                MenuBarSubmenuPreview(items: submenu, highlight: subHighlight)
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
                .background(RoundedRectangle(cornerRadius: Radius.row).fill(Color.white.opacity(open ? 0.2 : 0)))
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

// MARK: The Join row (v4 Phase 9)

/// The menu's Join row (design/mockup-v4 `.mbr` with `.mbjoin`): start time, the calendar bar, the title over its times or
/// countdown, and Join (28 pt, radius 8, the act colour of the dark menu: white) with the call logo. In the real menu it is the
/// view of one `NSMenuItem` (Q5: the native menu stays); highlighted like the native rows while the pointer is on it.
struct MenuJoinRow: View {
    static let height: CGFloat = 40
    static let minWidth: CGFloat = 300
    let row: MenuBarMenuModel.Row
    /// "19:00–20:00", or the countdown of the head row ("in 20 min", "35 min left").
    let detail: String
    var highlighted = false
    var joinHover = false
    /// In the real menu the row tracks the pointer itself and runs the actions.
    var interactive = false
    var open: () -> Void = {}
    var join: () -> Void = {}
    @State private var hover = false
    @State private var hoverJoin = false

    static func detail(_ r: MenuBarMenuModel.Row, focus: MenuBarMenuModel.Focus?) -> String {
        if let focus { return focus.text }
        return r.end.map { "\(r.start)\u{2013}\($0)" } ?? r.start
    }

    var body: some View {
        let hl = highlighted || (interactive && hover && !hoverJoin)
        let onJoin = joinHover || hoverJoin
        HStack(spacing: 8) {
            Group {
                if row.tentative && !hl { MenuBarStripes(color: Color(hex: row.colorHex)) } else { Rectangle().fill(hl ? .white : Color(hex: row.colorHex)) }
            }
            .frame(width: 3, height: 26).clipShape(RoundedRectangle(cornerRadius: Radius.bar))
            Text(row.start).font(NativeMenu.font).monospacedDigit().foregroundStyle(hl ? .white.opacity(0.86) : NativeMenu.time)
                .fixedSize().frame(width: MenuBarColumns.timeWidth, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(MenuBarColumns.truncate(row.title)).font(NativeMenu.font).lineLimit(1)
                Text(detail).font(NativeMenu.small).monospacedDigit().foregroundStyle(hl ? .white.opacity(0.86) : NativeMenu.dim).lineLimit(1)
            }
            .fixedSize()
            Spacer(minLength: 18)
            if let call = row.call {
                Button(action: join) {
                    HStack(spacing: 6) {
                        CallLogo(kind: call.kind, size: 13, glyphColor: .black)
                        Text("Join").font(.system(size: 12, weight: .semibold)).foregroundStyle(.black)
                    }
                    .padding(.horizontal, 10).frame(height: Dim.row)
                    .background(RoundedRectangle(cornerRadius: Radius.control).fill(Color.white.opacity(onJoin ? 1 : 0.92)))
                    .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Color.white.opacity(onJoin ? 0.9 : 0), lineWidth: 1.5).padding(-2.5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hoverJoin = $0 }
                .help("Join \(call.name)")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9).frame(height: Self.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.row).fill(hl ? NativeMenu.highlight : .clear))
        .padding(.horizontal, interactive ? NativeMenu.padding : 0)
        .contentShape(Rectangle())
        .onTapGesture { open() }
        .onHover { hover = $0 }
    }
}

// MARK: Call logos (design/mockup-v4 `meetLogo`, `zoomLogo`): brand art, so its colours stay here, not in Theme.

/// The call's logo: Google Meet, Zoom, or a video glyph for any other host. `size` is the width; Meet is 22 x 18 in its box.
struct CallLogo: View {
    let kind: CallLink.Kind
    var size: CGFloat = 16
    var glyphColor: Color = .primary

    static let meet: [(String, String)] = [
        ("#00832d", "M12.4 9 14.5 11.4 17.4 13.2 17.9 9 17.4 4.9 14.6 6.5z"),
        ("#0066da", "M0 12.8v3.6C0 17.3.7 18 1.6 18h3.6l.7-2.6-.7-2.6-2.5-.7z"),
        ("#e94235", "M5.2 0 0 5.2l2.6.7 2.6-.7.8-2.4z"),
        ("#2684fc", "M5.2 5.2H0v7.6h5.2z"),
        ("#00ac47", "M20.9 2.2 17.4 4.9v8.3l3.5 2.7c.5.4 1.3 0 1.3-.7V2.9c0-.7-.8-1.1-1.3-.7zM12.4 9v3.8H5.2V18h10.6c.9 0 1.6-.7 1.6-1.6v-3.2z"),
        ("#ffba00", "M15.8 0H5.2v5.2h7.2V9l5-4.1V1.6C17.4.7 16.7 0 15.8 0z"),
    ]
    static let zoomBlue = "#2D8CFF"
    static let zoomCamera = "M3.5 5.5h5.2c.7 0 1.3.6 1.3 1.3v3.7H4.8c-.7 0-1.3-.6-1.3-1.3zM10.5 7.2l2-1.5v4.6l-2-1.5z"

    var body: some View {
        switch kind {
        case .meet:
            Canvas { ctx, sz in
                let k = sz.width / 22
                for (hex, d) in Self.meet { ctx.fill(SVGPath.parse(d).applying(CGAffineTransform(scaleX: k, y: k)), with: .color(Color(hex: hex))) }
            }
            .frame(width: size, height: size * 18 / 22)
        case .zoom:
            Canvas { ctx, sz in
                let k = sz.width / 16
                ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: sz), cornerRadius: Radius.check * k), with: .color(Color(hex: Self.zoomBlue)))
                ctx.fill(SVGPath.parse(Self.zoomCamera).applying(CGAffineTransform(scaleX: k, y: k)), with: .color(.white))
            }
            .frame(width: size, height: size)
        case .teams, .other:
            Image(systemName: "video.fill").font(.system(size: size * 0.7)).foregroundStyle(glyphColor).frame(width: size, height: size)
        }
    }
}

/// Just enough SVG path syntax for the logos: M L H V C Z, absolute and relative, with implicit repeats.
enum SVGPath {
    static func parse(_ d: String) -> Path {
        var tokens: [String] = []
        var num = ""
        func flush() { if !num.isEmpty { tokens.append(num); num = "" } }
        for ch in d {
            if ch.isLetter { flush(); tokens.append(String(ch)) }
            else if ch == "-" { flush(); num = "-" }
            else if ch == "." { if num.contains(".") { flush() }; num.append(ch) }
            else if ch.isNumber { num.append(ch) }
            else { flush() }
        }
        flush()
        var p = Path()
        var i = 0, cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero
        func n() -> CGFloat { defer { i += 1 }; return CGFloat(Double(tokens[i]) ?? 0) }
        while i < tokens.count {
            if let c = tokens[i].first, c.isLetter { cmd = c; i += 1; if c == "z" || c == "Z" { p.closeSubpath(); cur = start; continue } }
            guard i < tokens.count else { break }
            let rel = cmd.isLowercase
            let o = rel ? cur : .zero
            switch cmd.uppercased() {
            case "M":
                let x = n(), y = n(); cur = CGPoint(x: o.x + x, y: o.y + y); start = cur; p.move(to: cur)
                cmd = rel ? "l" : "L"
            case "L": let x = n(), y = n(); cur = CGPoint(x: o.x + x, y: o.y + y); p.addLine(to: cur)
            case "H": let x = n(); cur.x = (rel ? cur.x : 0) + x; p.addLine(to: cur)
            case "V": let y = n(); cur.y = (rel ? cur.y : 0) + y; p.addLine(to: cur)
            case "C":
                let a = CGPoint(x: o.x + n(), y: o.y + n()), b = CGPoint(x: o.x + n(), y: o.y + n()), e = CGPoint(x: o.x + n(), y: o.y + n())
                p.addCurve(to: e, control1: a, control2: b); cur = e
            default: i += 1
            }
        }
        return p
    }
}

// MARK: Map logos (design/mockup-v4 `appleMaps`, `gMaps`): brand art for the location menu, so its colours stay here, like the call logos.

struct MapLogo: View {
    enum Kind { case apple, google }
    let kind: Kind
    var size: CGFloat = 16

    static let apple: [(String, String)] = [
        ("#93d36f", "M0 10 16 4.4v5L0 15z"), ("#f6c443", "M5.2 0h3L4.4 16h-3z"),
        ("#ff4b3e", "M8.6 3.6a2.6 2.6 0 0 1 2.6 2.6c0 1.9-2.6 4.6-2.6 4.6S6 8.1 6 6.2a2.6 2.6 0 0 1 2.6-2.6z"),
    ]
    static let appleBase = "#f4f4f1"
    static let google: [(String, String)] = [
        ("#34a853", "M8 .8A5.2 5.2 0 0 0 2.8 6c0 3.7 5.2 9.2 5.2 9.2s5.2-5.5 5.2-9.2A5.2 5.2 0 0 0 8 .8z"),
        ("#fbbc04", "M4.3 2.3 8 6 3.3 8.4A5 5 0 0 1 2.8 6c0-1.4.6-2.7 1.5-3.7z"),
        ("#ea4335", "M4.3 2.3A5.2 5.2 0 0 1 11.7 2.3L8 6z"),
        ("#4285f4", "M11.7 2.3A5.2 5.2 0 0 1 13.2 6c0 1-.3 2-.8 3L8 6z"),
    ]

    var body: some View {
        Canvas { ctx, sz in
            let k = sz.width / 16, t = CGAffineTransform(scaleX: k, y: k)
            func fill(_ d: String, _ hex: String) { var p = Path(); PanelIcon.svg(&p, d); ctx.fill(p.applying(t), with: .color(Color(hex: hex))) }
            switch kind {
            case .apple:
                ctx.clip(to: Path(roundedRect: CGRect(origin: .zero, size: sz), cornerRadius: Radius.check * k))
                ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(Color(hex: Self.appleBase)))
                for (hex, d) in Self.apple { fill(d, hex) }
                ctx.fill(Path(ellipseIn: CGRect(x: 7.6 * k, y: 5.2 * k, width: 2 * k, height: 2 * k)), with: .color(.white))
            case .google:
                for (hex, d) in Self.google { fill(d, hex) }
                ctx.fill(Path(ellipseIn: CGRect(x: 6.1 * k, y: 4.1 * k, width: 3.8 * k, height: 3.8 * k)), with: .color(.white))
            }
        }
        .frame(width: size, height: size)
    }
}
