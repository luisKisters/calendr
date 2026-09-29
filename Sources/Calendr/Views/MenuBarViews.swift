import SwiftUI
import AppKit
import CalendrKit

@MainActor
enum MainWindow {
    static var openAction: (() -> Void)?

    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let w = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain && $0.contentView != nil && $0.isVisible == false || ($0.canBecomeMain && !($0 is NSPanel)) }) {
            w.makeKeyAndOrderFront(nil)
        } else {
            openAction?()
        }
    }
}

/// Menu bar item: template glyph, next event title, and the imminence in mono (`live` red inside 15 minutes).
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let s = model.upcoming
        HStack(spacing: 6) {
            if let img = Self.glyph { Image(nsImage: img) } else { Image(systemName: "circle.dotted") }
            if let n = s.next {
                Text(n.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(s.label.replacingOccurrences(of: "in ", with: "")).font(.calMono(11.5, .semibold))
            } else {
                Text("Calendr").font(.system(size: 13, weight: .medium))
            }
        }
        .padding(.horizontal, 4)
    }

    /// Template image from the bundle (design/icon/MenuBarTemplate.png); black on clear so the system tints it.
    static let glyph: NSImage? = {
        guard let url = Bundle.main.url(forResource: "MenuBarTemplate", withExtension: "png"), let img = NSImage(contentsOf: url) else { return nil }
        img.size = NSSize(width: 18, height: 18)
        img.isTemplate = true
        return img
    }()
}

struct MenuBarPopover: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let s = model.upcoming
        // A MenuBarExtra window sizes itself from ideal sizes, and a ScrollView has none: give it its content height, capped to the screen.
        let rows = s.sections.reduce(0) { $0 + 1 + $1.events.count }
        let maxScroll = (NSScreen.main?.visibleFrame.height ?? 900) - 130
        let cardHeight: CGFloat = s.next != nil ? 132 : 200
        let scrollHeight = min(CGFloat(rows) * 28 + cardHeight + 14 + CGFloat(s.sections.count) * 16, maxScroll)
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if let n = s.next {
                        NextCard(event: n, until: s.untilNext) { openWindowFor(n) }
                    } else {
                        MenuBarEmpty()
                    }
                    ForEach(s.sections) { sec in
                        MicroLabel(text: sec.title == "Today" ? "Later today" : sec.title).padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 4)
                        ForEach(sec.events) { PopEventRow(e: $0) }
                    }
                }
                .padding(.top, 6).padding(.bottom, 4)
            }
            .frame(height: scrollHeight)
            Hairline()
            VStack(spacing: 0) {
                PopFooter(title: "Open Calendr", keys: ["\u{2318}", "1"]) { show() }
                PopFooter(title: "Settings\u{2026}", keys: ["\u{2318}", ","]) { show(); model.handle(.settings) }
            }.padding(.vertical, 6)
        }
        .frame(width: 392)
        .background(Theme.ink800)
        .onAppear { MainWindow.openAction = { openWindow(id: "main") } }
    }

    private func openWindowFor(_ e: CalendarEvent) {
        MainWindow.openAction = { openWindow(id: "main") }
        model.open(event: e)
        MainWindow.show()
    }

    private func show() {
        MainWindow.openAction = { openWindow(id: "main") }
        MainWindow.show()
    }
}

/// The next event as a card: calendar bar, imminence badge in `live`, Open (primary) and Start transcription.
struct NextCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let event: CalendarEvent
    let until: String
    let open: () -> Void
    var body: some View {
        let pal = Palettes.palette(barHex: model.calendarColorHex(of: event), fillHex: nil, dark: scheme == .dark)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                MicroLabel(text: "Up next")
                Spacer()
                if until != "" && until != "now" {
                    Text("in \(until.replacingOccurrences(of: "min", with: " min"))").font(.calMono(11, .semibold)).foregroundStyle(Theme.live)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.live.opacity(0.14)))
                } else if until == "now" {
                    Text("now").font(.calMono(11, .semibold)).foregroundStyle(Theme.live)
                }
            }
            Text(event.title).font(.system(size: 15, weight: .semibold)).tracking(-0.2).foregroundStyle(Theme.paper).lineLimit(1).padding(.top, 6).padding(.bottom, 2)
            Text(model.fmt.timeRange(event.start, event.end)).font(.calMono(11.5)).foregroundStyle(Theme.haze)
            HStack(spacing: 6) {
                PrimaryButton(title: "Open", small: true, action: open)
                SecondaryButton(title: "Start transcription", small: true) { model.showToast("Transcription is not available in Calendr") }
            }.padding(.top, 10)
        }
        .padding(.leading, 16).padding(.trailing, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(Theme.ink700))
        .overlay(alignment: .leading) { Rectangle().fill(pal.bar).frame(width: 3) }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Theme.hair, lineWidth: 1))
        .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 6)
    }
}

/// No events left: one line of explanation and the primary action.
struct MenuBarEmpty: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let after = model.upcoming.sections.first?.events.first
        VStack(spacing: 6) {
            EmptyArt(kind: .ring, size: 56).padding(.bottom, 8)
            Text("Nothing else today").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
            if let e = after {
                Text("Your next event is \(e.title) \(model.upcoming.sections[0].title.lowercased()) at \(model.fmt.time(e.start)).")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.haze).multilineTextAlignment(.center).lineSpacing(3).frame(maxWidth: 260)
            } else {
                Text("Nothing is scheduled for the next seven days.").font(.system(size: 12.5)).foregroundStyle(Theme.haze).multilineTextAlignment(.center)
            }
            PrimaryButton(title: "Create event", keys: ["C"]) { model.handle(.createEvent) }.padding(.top, 12)
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 24).padding(.top, 32).padding(.bottom, 26)
    }
}

struct PopEventRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var scheme
    let e: CalendarEvent
    @State private var hover = false
    var body: some View {
        let pal = Palettes.palette(barHex: model.calendarColorHex(of: e), fillHex: nil, dark: scheme == .dark)
        let past = e.end <= model.now
        Button {
            MainWindow.openAction = { openWindow(id: "main") }
            model.open(event: e)
            MainWindow.show()
        } label: {
            HStack(spacing: 0) {
                Text(model.fmt.time(e.start)).font(.calMono(12)).foregroundStyle(Theme.haze).frame(width: 48, alignment: .leading)
                Group {
                    if e.kind == .task { Circle().strokeBorder(Theme.hazeDim, lineWidth: 1.5).frame(width: 10, height: 10) }
                    else if e.status == .tentative { Stripes(color: pal.bar).frame(width: 3, height: 14).clipShape(RoundedRectangle(cornerRadius: 2)) }
                    else { RoundedRectangle(cornerRadius: 2).fill(pal.bar).frame(width: 3, height: 14) }
                }.padding(.trailing, 10)
                Text(e.kind == .task ? TaskTitle.split(e.title).text : e.title).font(.system(size: 13)).foregroundStyle(Theme.paper).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20).frame(height: 28)
            .background(hover ? Theme.hover : Color.clear)
            .opacity(past ? 0.5 : 1)
            .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

struct PopFooter: View {
    let title: String
    let keys: [String]
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 13)).foregroundStyle(Theme.paper)
                Spacer()
                Keycaps(keys: keys)
            }
            .padding(.horizontal, 20).frame(height: 28)
            .background(hover ? Theme.hover : Color.clear)
            .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

/// SwiftUI has no API to open a MenuBarExtra window, so control-cmd-K clicks its status item button.
@MainActor
enum MenuBarControl {
    static func open() -> Bool {
        for w in NSApp.windows where String(describing: type(of: w)).contains("StatusBar") {
            if let b = findButton(in: w.contentView) { b.performClick(nil); return true }
        }
        return false
    }
    private static func findButton(in v: NSView?) -> NSButton? {
        guard let v else { return nil }
        if let b = v as? NSButton { return b }
        for s in v.subviews { if let b = findButton(in: s) { return b } }
        return nil
    }
}
