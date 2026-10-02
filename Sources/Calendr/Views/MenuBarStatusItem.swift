import AppKit
import SwiftUI
import Observation
import CalendrKit

extension AppModel {
    /// The menu bar item and menu for the current clock: today and the next two days, hidden calendars left out.
    var menuBarMenu: MenuBarMenuModel {
        let today = math.startOfDay(now)
        let evs = store.events(in: DateInterval(start: math.addDays(today, -1), end: math.addDays(today, 3)))
            .filter { !hiddenCalendars.contains($0.calendarID) }
        return MenuBarMenu.build(events: evs, now: now, fmt: fmt, canRespond: canChangeResponse,
                                 guestAddresses: { menuBarGuestAddresses($0) }) { calendarColorHex(of: $0) }
    }

    /// EventKit cannot set the user's own attendee status; the demo store can.
    var canChangeResponse: Bool { store is DemoStore }

    /// The guests' addresses: written in the participant, or a teammate's of that name.
    func menuBarGuestAddresses(_ e: CalendarEvent) -> [String] {
        e.participants.compactMap { p in MenuBarMenu.guestAddress(p) ?? store.teammates.first { $0.name == p }?.email }
    }

    func menuBarSubmenu(for e: CalendarEvent) -> [MenuBarSubItem] {
        MenuBarMenu.submenu(for: e, canRespond: canChangeResponse, guestAddresses: menuBarGuestAddresses(e))
    }

    func setResponse(_ status: ResponseStatus, for e: CalendarEvent) {
        guard canChangeResponse else { return }
        var cur = event(id: e.id) ?? e
        cur.status = status
        _ = try? store.update(cur, span: .this)
    }
}

/// The real menu bar item: an NSStatusItem whose NSMenu is rebuilt from `MenuBarMenuModel` each time it opens.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    static var shared: MenuBarController?

    let model: AppModel
    let item: NSStatusItem
    let menu = NSMenu()

    init(model: AppModel) {
        self.model = model
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        item.button?.toolTip = "Calendr  \u{2303}\u{2318}K"
        observe()
    }

    /// Re-renders the item whenever the clock (on the minute), the setting, hidden calendars or the store change.
    private func observe() {
        withObservationTracking {
            updateItem()
        } onChange: { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.observe() } }
        }
    }

    func updateItem() {
        guard let button = item.button else { return }
        _ = model.storeVersion
        let m = model.menuBarMenu
        guard let f = m.focus, model.settings.menuBarDisplay != .icon else {
            button.image = MenuBarArt.glyph(soon: m.focus?.soon ?? false)
            button.imagePosition = .imageOnly
            button.attributedTitle = NSAttributedString()
            return
        }
        button.image = MenuBarArt.bar(color: NSColor(Color(hex: model.calendarColorHex(of: f.event))), height: 13, tentative: false)
        button.imagePosition = .imageLeading
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let s = NSMutableAttributedString()
        if model.settings.menuBarDisplay == .titleAndCountdown, let t = m.itemTitle {
            s.append(NSAttributedString(string: " " + t, attributes: [.font: font, .foregroundColor: NSColor.labelColor]))
            s.append(NSAttributedString(string: " \u{00B7} ", attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]))
        } else {
            s.append(NSAttributedString(string: " ", attributes: [.font: font]))
        }
        s.append(NSAttributedString(string: f.text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: f.soon ? MenuBarArt.soon : NSColor.labelColor,
        ]))
        button.attributedTitle = s
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) { rebuild(menu) }

    /// Rows set their own colours, which the system keeps on the highlight: swap in the white version while a row is highlighted.
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        for it in menu.items { (it.representedObject as? MenuBarRowItem)?.apply(to: it, highlighted: it === item) }
    }

    func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()
        let m = model.menuBarMenu
        let cols = MenuBarColumns(rows: m.rows)
        if let f = m.focus, let head = m.head {
            menu.addItem(header(m.headLabel, countdown: f.text, soon: f.soon))
            menu.addItem(row(head, cols))
        } else {
            menu.addItem(header(m.headLabel))
        }
        menu.addItem(.separator())
        for s in m.sections {
            menu.addItem(header(s.title))
            for r in s.rows { menu.addItem(row(r, cols)) }
        }
        menu.addItem(.separator())
        menu.addItem(command("Open Calendr", key: "1", #selector(openCalendr)))
        menu.addItem(command("Settings\u{2026}", key: ",", #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(command("Quit Calendr", key: "q", #selector(quit)))
    }

    private func header(_ text: String, countdown: String? = nil, soon: Bool = false) -> NSMenuItem {
        let it = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        it.isEnabled = false
        let font = NSFont.menuFont(ofSize: 0)
        let s = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor])
        if let countdown {
            s.append(NSAttributedString(string: "  " + countdown, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: font.pointSize, weight: .regular),
                .foregroundColor: soon ? MenuBarArt.soon : NSColor.secondaryLabelColor,
            ]))
        }
        it.attributedTitle = s
        return it
    }

    private func row(_ r: MenuBarMenuModel.Row, _ cols: MenuBarColumns) -> NSMenuItem {
        let it = NSMenuItem(title: r.title, action: #selector(openEvent(_:)), keyEquivalent: "")
        it.target = self
        let state = MenuBarRowItem(row: r, columns: cols)
        it.representedObject = state
        state.apply(to: it, highlighted: false)
        if r.hasSubmenu {
            let sub = NSMenu()
            sub.autoenablesItems = false
            for s in model.menuBarSubmenu(for: r.event) { sub.addItem(subItem(s, r.event)) }
            it.submenu = sub
        }
        return it
    }

    private func subItem(_ s: MenuBarSubItem, _ e: CalendarEvent) -> NSMenuItem {
        switch s {
        case .separator: return .separator()
        case .header(let t): return header(t)
        default:
            let it = NSMenuItem(title: s.title, action: #selector(runSub(_:)), keyEquivalent: s.key)
            it.keyEquivalentModifierMask = []
            it.target = self
            it.representedObject = MenuBarAction(item: s, event: e)
            if case .respond(_, let checked) = s { it.state = checked ? .on : .off }
            return it
        }
    }

    private func command(_ title: String, key: String, _ action: Selector) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
        it.target = self
        return it
    }

    // MARK: Actions

    @objc private func openEvent(_ sender: NSMenuItem) {
        guard let r = sender.representedObject as? MenuBarRowItem else { return }
        show(r.row.event)
    }

    @objc private func runSub(_ sender: NSMenuItem) {
        guard let a = sender.representedObject as? MenuBarAction else { return }
        switch a.item {
        case .join(let url), .email(_, let url): NSWorkspace.shared.open(url)
        case .respond(let status, _): model.setResponse(status, for: a.event)
        case .show: show(a.event)
        case .header, .separator: break
        }
    }

    private func show(_ e: CalendarEvent) {
        MainWindow.show()
        model.open(event: e)
    }

    @objc private func openCalendr() { MainWindow.show() }
    @objc private func openSettings() { MainWindow.show(); model.handle(.settings) }
    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: Debug

    /// `--dump-menubar`: the item and the menu as text, one line per entry (submenus indented).
    func dump() -> String {
        rebuild(menu)
        var lines = ["item: \(item.button?.attributedTitle.string.trimmingCharacters(in: .whitespaces) ?? "")\(item.button?.imagePosition == .imageOnly ? "[glyph]" : "")"]
        func walk(_ m: NSMenu, _ depth: Int) {
            for it in m.items {
                let pad = String(repeating: "    ", count: depth)
                if it.isSeparatorItem { lines.append(pad + "----"); continue }
                var line = pad + (it.attributedTitle?.string ?? it.title).replacingOccurrences(of: "\t", with: " | ")
                if !it.isEnabled { line += "  (disabled)" }
                if it.state == .on { line += "  [checked]" }
                if !it.keyEquivalent.isEmpty {
                    let k = it.keyEquivalent == "\r" ? "\u{21A9}" : it.keyEquivalent.uppercased()
                    line += "  [\(it.keyEquivalentModifierMask.contains(.command) ? "\u{2318}" : "")\(k)]"
                }
                lines.append(line)
                if let sub = it.submenu { walk(sub, depth + 1) }
            }
        }
        walk(menu, 0)
        return lines.joined(separator: "\n")
    }
}

/// An event row's two looks: its own colours, and all white on the highlight.
final class MenuBarRowItem: NSObject {
    let row: MenuBarMenuModel.Row
    private let plain: NSAttributedString
    private let lit: NSAttributedString

    init(row: MenuBarMenuModel.Row, columns: MenuBarColumns) {
        self.row = row
        plain = columns.title(for: row, highlighted: false)
        lit = columns.title(for: row, highlighted: true)
    }

    func apply(to it: NSMenuItem, highlighted: Bool) {
        it.attributedTitle = highlighted ? lit : plain
        it.image = highlighted ? MenuBarArt.bar(color: .selectedMenuItemTextColor, height: 14, tentative: false)
                               : MenuBarArt.bar(color: NSColor(Color(hex: row.colorHex)), height: 14, tentative: row.tentative)
    }
}

/// A row menu entry and the event it acts on.
final class MenuBarAction: NSObject {
    let item: MenuBarSubItem
    let event: CalendarEvent
    init(item: MenuBarSubItem, event: CalendarEvent) { self.item = item; self.event = event }
}

/// Tab stops for the menu rows: start times in one tabular column, titles on one rail, end times right-aligned.
struct MenuBarColumns {
    static let font = NSFont.menuFont(ofSize: 0)
    static let timeFont = NSFont.monospacedDigitSystemFont(ofSize: font.pointSize, weight: .regular)
    static let smallFont = NSFont.monospacedDigitSystemFont(ofSize: font.pointSize - 1, weight: .regular)
    static let maxTitle: CGFloat = 330

    let titleX: CGFloat
    let endX: CGFloat

    /// The start-time column fits "all-day" and "00:00"; the preview uses the same width.
    static let timeWidth = max(width("all-day", timeFont), width("00:00", timeFont))

    static func width(_ s: String, _ f: NSFont) -> CGFloat { ceil((s as NSString).size(withAttributes: [.font: f]).width) }

    init(rows: [MenuBarMenuModel.Row]) {
        let w = Self.width
        titleX = Self.timeWidth + 8
        let widest = rows.map { r in
            min(w(r.title, Self.font), Self.maxTitle) + (r.left.map { 8 + w($0, Self.smallFont) } ?? 0)
        }.max() ?? 0
        endX = titleX + widest + 18 + w("00:00", Self.smallFont)
    }

    /// The row's text. Highlighted, everything is the selected-item colour, the times slightly dimmed (as the preview draws it).
    func title(for r: MenuBarMenuModel.Row, highlighted hl: Bool) -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.tabStops = [NSTextTab(textAlignment: .left, location: titleX), NSTextTab(textAlignment: .right, location: endX)]
        p.lineBreakMode = .byClipping
        let on = NSColor.selectedMenuItemTextColor, dim = on.withAlphaComponent(0.86)
        let s = NSMutableAttributedString(string: r.start, attributes: [.font: Self.timeFont, .foregroundColor: hl ? dim : NSColor.secondaryLabelColor, .paragraphStyle: p])
        s.append(NSAttributedString(string: "\t" + Self.truncate(r.title), attributes: [.font: Self.font, .foregroundColor: hl ? on : NSColor.labelColor, .paragraphStyle: p]))
        if let left = r.left {
            s.append(NSAttributedString(string: "  " + left, attributes: [.font: Self.smallFont, .foregroundColor: hl ? on : MenuBarArt.soon, .paragraphStyle: p]))
        }
        if let end = r.end {
            s.append(NSAttributedString(string: "\t" + end, attributes: [.font: Self.smallFont, .foregroundColor: hl ? dim : NSColor.tertiaryLabelColor, .paragraphStyle: p]))
        }
        return s
    }

    static func truncate(_ t: String) -> String {
        func w(_ s: String) -> CGFloat { (s as NSString).size(withAttributes: [.font: font]).width }
        guard w(t) > maxTitle else { return t }
        var cut = t
        while !cut.isEmpty && w(cut + "\u{2026}") > maxTitle { cut.removeLast() }
        return cut.trimmingCharacters(in: .whitespaces) + "\u{2026}"
    }
}

/// Images for the item and the rows: the calendar colour bar (striped when tentative) and the ring glyph.
enum MenuBarArt {
    /// Red text and dot on the dark menu bar and menu (menubar.html #FF6B61), lighter than Theme.live so it reads there.
    static let soon = NSColor(srgbRed: 1, green: 0x6B / 255, blue: 0x61 / 255, alpha: 1)

    static func bar(color: NSColor, height: CGFloat, tentative: Bool) -> NSImage {
        NSImage(size: NSSize(width: 3, height: height), flipped: true) { r in
            let path = NSBezierPath(roundedRect: r, xRadius: 1.5, yRadius: 1.5)
            if tentative {
                path.addClip()
                color.setFill()
                var y: CGFloat = 0
                while y < r.height { NSRect(x: 0, y: y, width: 3, height: 3).fill(); y += 6 }
            } else {
                color.setFill()
                path.fill()
            }
            return true
        }
    }

    /// The app's ring with its dot (design/icon/menubar.svg). A template image, unless the dot is red.
    static func glyph(soon: Bool) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let k: CGFloat = 18 / 1024
            let ink = soon ? NSColor.labelColor : NSColor.black
            NSGraphicsContext.saveGraphicsState()
            let clip = NSBezierPath(rect: NSRect(x: 0, y: 0, width: 18, height: 18))
            clip.appendOval(in: NSRect(x: (753 - 190) * k, y: (271 - 190) * k, width: 380 * k, height: 380 * k))
            clip.windingRule = .evenOdd
            clip.addClip()
            let ring = NSBezierPath(ovalIn: NSRect(x: (512 - 360) * k, y: (512 - 360) * k, width: 720 * k, height: 720 * k))
            ring.lineWidth = 112 * k
            ink.setStroke()
            ring.stroke()
            NSGraphicsContext.restoreGraphicsState()
            (soon ? Self.soon : ink).setFill()
            NSBezierPath(ovalIn: NSRect(x: (753 - 125) * k, y: (271 - 125) * k, width: 250 * k, height: 250 * k)).fill()
            return true
        }
        img.isTemplate = !soon
        return img
    }
}
