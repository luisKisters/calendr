import AppKit
import SwiftUI
import Observation
import HorionKit

extension AppModel {
    /// The menu bar item and menu for the current clock: today and the next two days, hidden calendars left out.
    var menuBarMenu: MenuBarMenuModel {
        let today = math.startOfDay(now)
        let evs = store.events(in: DateInterval(start: math.addDays(today, -1), end: math.addDays(today, 3)))
            .filter { !hiddenCalendars.contains($0.calendarID) }
        return MenuBarMenu.build(events: evs, now: now, fmt: fmt, canRespondTo: { [store] in store.canRespond(calendarID: $0.calendarID) },
                                 guestAddresses: { menuBarGuestAddresses($0) }) { calendarColorHex(of: $0) }
    }

    /// EventKit cannot set the user's own attendee status; the demo store can.
    var canChangeResponse: Bool { store.canRespond }

    /// The other guests' addresses: their own, or a teammate's of that name.
    func menuBarGuestAddresses(_ e: CalendarEvent) -> [String] {
        e.attendees.filter { !$0.isMe }.compactMap { a in
            a.email.isEmpty ? MenuBarMenu.guestAddress(a.label) ?? store.teammates.first { $0.name == a.label }?.email : a.email
        }
    }

    func menuBarSubmenu(for e: CalendarEvent) -> [MenuBarSubItem] {
        // per calendar: with Google connected, EventKit events still cannot take a reply
        MenuBarMenu.submenu(for: e, canRespond: store.canRespond(calendarID: e.calendarID), guestAddresses: menuBarGuestAddresses(e))
    }

    /// The editor's reply path (`setReply`): the same guards, and a held change stays held.
    func setResponse(_ status: ResponseStatus, for e: CalendarEvent) {
        setReply(status, eventID: e.id)
    }
}

/// The real menu bar item: an NSStatusItem whose NSMenu is rebuilt from `MenuBarMenuModel` each time it opens.
/// Event rows are custom views (`MenuBarRowView`): no submenu arrow, a small icon says what a row's menu has.
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
        item.button?.toolTip = "Horion  \u{2303}\u{2318}K"
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
        button.image = MenuBarArt.bar(color: MenuBarArt.calendar(model.calendarColorHex(of: f.event)), second: nil, height: 13, tentative: false)
        button.imagePosition = .imageLeading
        button.attributedTitle = Self.itemTitle(title: model.settings.menuBarDisplay == .titleAndCountdown ? m.itemTitle : nil, countdown: f.text)
    }

    /// "Title · 2 h 3 min left": the dot at 45 %, the time at 72 %, so the title reads first. Nothing is red.
    static func itemTitle(title: String?, countdown: String) -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let s = NSMutableAttributedString(string: " ", attributes: [.font: font])
        if let title {
            s.append(NSAttributedString(string: title, attributes: [.font: font, .foregroundColor: NSColor.labelColor]))
            s.append(NSAttributedString(string: "  \u{00B7}  ", attributes: [.font: font, .foregroundColor: NSColor.labelColor.withAlphaComponent(0.45)]))
        }
        s.append(NSAttributedString(string: countdown, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor.withAlphaComponent(title == nil ? 1 : 0.72),
        ]))
        return s
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) { if menu === self.menu { rebuild(menu) } }

    /// The menus open right now, the root first. Keys go to the deepest one with a highlight.
    private var open: [NSMenu] = []
    private var keys: Any?

    func menuWillOpen(_ menu: NSMenu) {
        open.removeAll { $0 === menu }
        open.append(menu)
        guard menu === self.menu, keys == nil else { return }
        keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            MainActor.assumeIsolated { self?.key(e) ?? false } ? nil : e
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        open.removeAll { $0 === menu }
        guard menu === self.menu else { return }
        open.removeAll()
        if let keys { NSEvent.removeMonitor(keys) }
        keys = nil
    }

    /// With nothing highlighted, Down starts at the first event and Up at the last one (not at Quit).
    /// Return or Enter on an event row opens it in Horion, even when the row has a menu.
    /// Returns true when the key was handled here.
    private func key(_ e: NSEvent) -> Bool {
        guard e.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty else { return false }
        let lit = open.reversed().lazy.compactMap(\.highlightedItem).first
        switch e.keyCode {
        case 36, 76:
            guard let it = lit, it.view is MenuBarRowView, let ev = it.representedObject as? CalendarEvent else { return false }
            menu.cancelTracking()
            show(ev)
            return true
        case 125, 126:
            guard lit == nil, open.count == 1 else { return false }
            let rows = menu.items.filter { $0.isEnabled && $0.view is MenuBarRowView }
            guard let target = e.keyCode == 125 ? rows.first : rows.last else { return false }
            let sel = Selector(("highlightItem:"))
            guard menu.responds(to: sel) else { return false }
            menu.perform(sel, with: target)
            for it in menu.items { it.view?.needsDisplay = true }
            return true
        default:
            return false
        }
    }

    /// Row views draw their own highlight: redraw the rows of the menu whose highlight moved.
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        for it in menu.items { it.view?.needsDisplay = true }
    }

    /// Half the height of the screen the menu opens on.
    private var maxHeight: CGFloat {
        ((item.button?.window?.screen ?? NSScreen.main)?.visibleFrame.height ?? 900) * 0.5
    }

    func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()
        let m = model.menuBarMenu
        let lines = MenuBarMenu.lines(m, maxHeight: maxHeight)
        let width = MenuBarRowView.width(for: lines)
        for (i, l) in lines.enumerated() {
            switch l {
            case .header(let t): menu.addItem(header(t, countdown: i == 0 ? m.focus?.text : nil))
            case .row(let r): menu.addItem(row(r, width: width))
            case .fold(let t, let d, let sections): menu.addItem(fold(t, detail: d, sections: sections, width: width))
            case .separator: menu.addItem(.separator())
            }
        }
        menu.addItem(.separator())
        menu.addItem(command("Open Horion", key: "", #selector(openHorion)))
        menu.addItem(command("Settings\u{2026}", key: ",", #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(command("Quit Horion", key: "q", #selector(quit)))
    }

    private func header(_ text: String, countdown: String? = nil) -> NSMenuItem {
        let it = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        it.isEnabled = false
        let font = NSFont.menuFont(ofSize: 0)
        let s = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor])
        if let countdown {
            s.append(NSAttributedString(string: "  " + countdown, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: font.pointSize, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]))
        }
        it.attributedTitle = s
        return it
    }

    private func row(_ r: MenuBarMenuModel.Row, width: CGFloat) -> NSMenuItem {
        let it = NSMenuItem(title: "\(r.start)\t\(r.title)", action: #selector(openEvent(_:)), keyEquivalent: "")
        it.target = self
        it.representedObject = r.event
        let v = MenuBarRowView(content: .event(r), width: width)
        v.onClick = { [weak self] in self?.menu.cancelTracking(); self?.show(r.event) }
        v.onJoin = { [weak self] in self?.menu.cancelTracking(); self?.model.joinCall(r.event) }
        if r.join, let call = r.call { it.toolTip = "Join \(call.name)" }
        it.view = v
        let sub = NSMenu()
        sub.autoenablesItems = false
        sub.delegate = self
        for s in model.menuBarSubmenu(for: r.event) { sub.addItem(subItem(s, r.event)) }
        it.submenu = sub
        return it
    }

    /// The day after, or the rows that did not fit: one row, its list in a submenu.
    private func fold(_ title: String, detail: String?, sections: [MenuBarMenuModel.Section], width: CGFloat) -> NSMenuItem {
        let it = NSMenuItem(title: title + (detail.map { "\t" + $0 } ?? ""), action: nil, keyEquivalent: "")
        it.view = MenuBarRowView(content: .fold(title: title, detail: detail), width: width)
        let sub = NSMenu()
        sub.autoenablesItems = false
        sub.delegate = self
        let w = MenuBarRowView.width(for: sections.flatMap { $0.rows.map(MenuBarLine.row) })
        for s in sections {
            sub.addItem(header(s.title))
            for r in s.rows { sub.addItem(row(r, width: w)) }
        }
        if sections.count == 1, let day = sections[0].rows.first?.event.start {
            sub.addItem(.separator())
            let show = command("Show the day in Horion", key: "", #selector(showDay(_:)))
            show.representedObject = day
            sub.addItem(show)
        }
        it.submenu = sub
        return it
    }

    private func subItem(_ s: MenuBarSubItem, _ e: CalendarEvent) -> NSMenuItem {
        switch s {
        case .separator: return .separator()
        case .header(let t): return header(t)
        default:
            let it = NSMenuItem(title: s.title, action: #selector(runSub(_:)), keyEquivalent: "")
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
        guard let e = sender.representedObject as? CalendarEvent else { return }
        show(e)
    }

    @objc private func runSub(_ sender: NSMenuItem) {
        guard let a = sender.representedObject as? MenuBarAction else { return }
        switch a.item {
        case .join(let url), .email(_, let url): NSWorkspace.shared.open(url)
        case .respond(let status, _): model.setResponse(status, for: a.event)
        case .copy:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(MenuBarMenu.details(model.event(id: a.event.id) ?? a.event, fmt: model.fmt), forType: .string)
        case .show: show(a.event)
        case .header, .separator: break
        }
    }

    @objc private func showDay(_ sender: NSMenuItem) {
        guard let d = sender.representedObject as? Date else { return }
        MainWindow.show()
        model.goTo(day: d)
    }

    private func show(_ e: CalendarEvent) {
        MainWindow.show()
        model.open(event: e)
    }

    @objc private func openHorion() { MainWindow.show() }
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
                var line = pad + (it.view == nil ? (it.attributedTitle?.string ?? it.title) : it.title).replacingOccurrences(of: "\t", with: " | ")
                if let v = it.view as? MenuBarRowView, let hint = v.hintName { line += "  [\(hint)]" }
                if !it.isEnabled { line += "  (disabled)" }
                if it.state == .on { line += "  [checked]" }
                if !it.keyEquivalent.isEmpty { line += "  [\u{2318}\(it.keyEquivalent.uppercased())]" }
                lines.append(line)
                if let sub = it.submenu { walk(sub, depth + 1) }
            }
        }
        walk(menu, 0)
        return lines.joined(separator: "\n")
    }
}

/// A row menu entry and the event it acts on.
final class MenuBarAction: NSObject {
    let item: MenuBarSubItem
    let event: CalendarEvent
    init(item: MenuBarSubItem, event: CalendarEvent) { self.item = item; self.event = event }
}

/// An event row or a fold row of the menu, drawn like a native item: calendar bar, start time, title cut at 220 pt,
/// and a grey camera or people icon when the row has a menu. A fold row shows its count and an arrow.
final class MenuBarRowView: NSView {
    enum Content { case event(MenuBarMenuModel.Row), fold(title: String, detail: String?) }

    static let font = NSFont.menuFont(ofSize: 0)
    static let timeFont = NSFont.monospacedDigitSystemFont(ofSize: font.pointSize, weight: .regular)
    static let smallFont = NSFont.monospacedDigitSystemFont(ofSize: font.pointSize - 1, weight: .regular)
    /// Titles longer than this end in an ellipsis (design/menubar-v2: "Where long titles are cut").
    static let maxTitle: CGFloat = 220
    /// The menu's highlight inset and the text start, matching the native items around the rows.
    static let inset: CGFloat = 5, barX: CGFloat = 14, timeX: CGFloat = 25, trailing: CGFloat = 14
    static let timeWidth = max(width("all-day", timeFont), width("00:00", timeFont))
    static var titleX: CGFloat { timeX + timeWidth + 8 }

    let content: Content
    var onClick: (() -> Void)?
    /// The Join pill on a row of today with a call (design/mockup-v4 "Call logo and Join"); clicking it joins.
    var onJoin: (() -> Void)?
    private let logo: NSImage?
    private var pill: NSRect = .zero

    static let pillFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    static let pillHeight: CGFloat = 18, logoSize: CGFloat = 13
    static var pillWidth: CGFloat { 7 + logoSize + 4 + width("Join", pillFont) + 8 }

    init(content: Content, width: CGFloat) {
        self.content = content
        if case .event(let r) = content, r.join, let call = r.call {
            let render = ImageRenderer(content: CallLogo(kind: call.kind, size: Self.logoSize, glyphColor: .black))
            render.scale = NSScreen.main?.backingScaleFactor ?? 2
            logo = render.nsImage
        } else { logo = nil }
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: MenuBarMenu.rowHeight))
        autoresizingMask = [.width]
        setAccessibilityElement(true)
        setAccessibilityRole(.menuItem)
        switch content {
        case .event(let r): setAccessibilityLabel("\(r.start), \(r.title)")
        case .fold(let t, let d): setAccessibilityLabel([t, d].compactMap { $0 }.joined(separator: ", "))
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    static func width(_ s: String, _ f: NSFont) -> CGFloat { ceil((s as NSString).size(withAttributes: [.font: f]).width) }

    /// One width for every row of a menu: the widest title (cut at `maxTitle`) plus its icon.
    static func width(for lines: [MenuBarLine]) -> CGFloat {
        let widest = lines.map { l -> CGFloat in
            switch l {
            case .row(let r): return min(width(r.title, font), maxTitle) + (r.join && r.call != nil ? 12 + pillWidth : r.hint == nil ? 0 : 6 + 15)
            case .fold(let t, let d, _): return width(t, font) - (timeWidth + 8) + (d.map { 24 + width($0, smallFont) } ?? 0) + 20
            default: return 0
            }
        }.max() ?? 0
        return ceil(titleX + max(widest, 120) + trailing)
    }

    var hintName: String? {
        guard case .event(let r) = content else { return nil }
        if r.join, r.call != nil { return "join" }
        return r.hint.map { $0 == .call ? "call" : "guests" }
    }

    override var isFlipped: Bool { true }
    override func mouseUp(with event: NSEvent) {
        guard case .event = content else { return }
        if logo != nil, pill.insetBy(dx: -3, dy: -2).contains(convert(event.locationInWindow, from: nil)) { onJoin?() } else { onClick?() }
    }

    override func draw(_ dirty: NSRect) {
        let hl = enclosingMenuItem?.isHighlighted == true
        if hl {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: Self.inset, dy: 0), xRadius: 5, yRadius: 5).fill()
        }
        let on = NSColor.selectedMenuItemTextColor
        let fg = hl ? on : NSColor.labelColor, dim = hl ? on.withAlphaComponent(0.86) : NSColor.secondaryLabelColor
        let mid = bounds.midY
        func text(_ s: String, _ f: NSFont, _ c: NSColor, x: CGFloat, maxWidth: CGFloat = .greatestFiniteMagnitude) -> CGFloat {
            let p = NSMutableParagraphStyle(); p.lineBreakMode = .byTruncatingTail
            let a = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c, .paragraphStyle: p])
            let w = min(ceil(a.size().width), maxWidth), h = ceil(a.size().height)
            a.draw(with: NSRect(x: x, y: mid - h / 2, width: w, height: h), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
            return w
        }
        switch content {
        case .event(let r):
            let bar = NSRect(x: Self.barX, y: mid - 7, width: 3, height: 14)
            if hl { MenuBarArt.drawBar(in: bar, color: on, second: nil, tentative: false) }
            else { MenuBarArt.drawBar(in: bar, color: MenuBarArt.calendar(r.colorHex), second: r.secondColorHex.map(MenuBarArt.calendar), tentative: r.tentative) }
            _ = text(r.start, Self.timeFont, dim, x: Self.timeX)
            let joins = logo != nil
            let room = bounds.width - Self.titleX - Self.trailing - (joins ? 12 + Self.pillWidth : r.hint == nil ? 0 : 21)
            let w = text(r.title, Self.font, fg, x: Self.titleX, maxWidth: min(Self.maxTitle, room))
            if let logo {
                pill = NSRect(x: bounds.width - Self.trailing - Self.pillWidth + 4, y: mid - Self.pillHeight / 2, width: Self.pillWidth, height: Self.pillHeight)
                NSColor.white.withAlphaComponent(hl ? 1 : 0.92).setFill()
                NSBezierPath(roundedRect: pill, xRadius: Radius.small, yRadius: Radius.small).fill()
                logo.draw(in: NSRect(x: pill.minX + 7, y: mid - logo.size.height / 2, width: logo.size.width, height: logo.size.height))
                let a = NSAttributedString(string: "Join", attributes: [.font: Self.pillFont, .foregroundColor: NSColor.black])
                let h = ceil(a.size().height)
                a.draw(at: NSPoint(x: pill.minX + 7 + Self.logoSize + 4, y: mid - h / 2))
            } else if let hint = r.hint, let img = NSImage(systemSymbolName: hint == .call ? "video" : "person.2", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 10, weight: .regular)) {
                let tinted = img.tinted(dim)
                tinted.draw(in: NSRect(x: Self.titleX + w + 6, y: mid - tinted.size.height / 2, width: tinted.size.width, height: tinted.size.height))
            }
        case .fold(let title, let detail):
            _ = text(title, Self.font, detail == nil ? dim : fg, x: Self.timeX)
            var x = bounds.width - Self.trailing
            if let chev = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 10, weight: .semibold))?.tinted(dim) {
                x -= chev.size.width
                chev.draw(in: NSRect(x: x, y: mid - chev.size.height / 2, width: chev.size.width, height: chev.size.height))
            }
            if let detail {
                let w = Self.width(detail, Self.smallFont)
                _ = text(detail, Self.smallFont, dim, x: x - 8 - w)
            }
        }
    }
}

private extension NSImage {
    func tinted(_ c: NSColor) -> NSImage {
        let img = NSImage(size: size, flipped: false) { r in
            self.draw(in: r)
            c.set()
            r.fill(using: .sourceAtop)
            return true
        }
        return img
    }
}

/// Images for the item and the rows: the calendar colour bar (striped when tentative) and the ring glyph.
enum MenuBarArt {
    /// The ring glyph's red dot when an event is close (menubar.html #FF6B61). Text is never red.
    static let soon = NSColor(srgbRed: 1, green: 0x6B / 255, blue: 0x61 / 255, alpha: 1)

    /// A calendar's bar colour in the event recipe, resolved for the appearance the menu bar or its menu draws in.
    static func calendar(_ hex: String) -> NSColor {
        NSColor(name: nil) { ap in NSColor(Palettes.barColor(hex, dark: ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua).color) }
    }

    static func bar(color: NSColor, second: NSColor?, height: CGFloat, tentative: Bool) -> NSImage {
        NSImage(size: NSSize(width: 3, height: height), flipped: true) { r in drawBar(in: r, color: color, second: second, tentative: tentative); return true }
    }

    /// The calendar bar: striped when tentative; top and bottom halves in two colours when the event is in two calendars.
    static func drawBar(in r: NSRect, color: NSColor, second: NSColor?, tentative: Bool) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: r, xRadius: Radius.bar, yRadius: Radius.bar).addClip()
        color.setFill()
        if tentative {
            var y = r.minY
            while y < r.maxY { NSRect(x: r.minX, y: y, width: r.width, height: 3).fill(); y += 6 }
        } else {
            r.fill()
            if let second {
                second.setFill()
                NSRect(x: r.minX, y: r.midY, width: r.width, height: r.height / 2).fill()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
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
