import SwiftUI
import AppKit

// Shared building blocks (design/mockup-v3/app.css controls): keycaps, buttons, segmented control, switch, empty-state art.

struct SFIcon: View {
    let name: String
    var size: CGFloat = 16
    var color: Color = Theme.haze
    var weight: Font.Weight = .regular
    var body: some View {
        Image(systemName: name).font(.system(size: size, weight: weight)).foregroundStyle(color)
    }
}

/// Hover is a neutral wash, press is a 0.94 scale; both 120 ms.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Motion.fast, value: configuration.isPressed)
    }
}

/// `.btn--icon`: 28 pt (24 small) square, fg2 glyph, hover wash and fg.
struct IconButton: View {
    let name: String
    var size: CGFloat = 13
    var box: CGFloat = 28
    var color: Color = Theme.fg2
    var help: String?
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            SFIcon(name: name, size: size, color: hover ? Theme.fg : color)
                .frame(width: box, height: box)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(hover ? Theme.hover : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
        .help(help ?? "")
    }
}

/// `kbd`: 10.5 / 500 tabular, 18 pt high, fg2 on bg2 with a hair2 edge, radius 4.
struct Keycap: View {
    let text: String
    var onAct = false
    var body: some View {
        Text(text).font(.calMono(10.5, .medium)).foregroundStyle(onAct ? Theme.onAct : Theme.fg2)
            .padding(.horizontal, 4).frame(minWidth: 18, minHeight: 18, maxHeight: 18)
            .background(RoundedRectangle(cornerRadius: 4).fill(onAct ? Theme.onAct.opacity(0.16) : Theme.bg2))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(onAct ? Color.clear : Theme.hair2, lineWidth: 1))
            .fixedSize()
    }
}

struct Keycaps: View {
    let keys: [String]
    var onAct = false
    /// 3 pt between caps; inside a flex row of the mockup the row's gap adds to it.
    var spacing: CGFloat = 3
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, k in
                if k == "or" { Text("or").font(.calMeta).foregroundStyle(Theme.fg3) } else { Keycap(text: Self.glyph(k), onAct: onAct) }
            }
        }
    }
    static func glyph(_ k: String) -> String { k == "command" ? "\u{2318}" : k }
}

/// `.btn`: 28 pt (24 small), radius 7, 12.5 / 500. Plain is fg2 with a hover wash, line adds a hair2 edge and fg text,
/// fill is inverted ink. `quiet` is the line button with fg3 text and a hair edge (Today while today is on screen).
struct TextButton: View {
    enum Kind { case plain, line, fill }
    let title: String
    var kind = Kind.line
    var icon: String?
    var keys: [String] = []
    var small = false
    var quiet = false
    var disabled = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        let h = !disabled && hover
        let fg: Color = disabled || quiet ? Theme.fg3 : kind == .fill ? Theme.onAct : (kind == .line || h ? Theme.fg : Theme.fg2)
        let fill: Color = kind == .fill ? (h ? Theme.actHover : Theme.act) : (h ? Theme.hover : .clear)
        let edge: Color = kind == .fill ? .clear : (disabled || quiet ? Theme.hair : (kind == .line ? Theme.hair2 : .clear))
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { SFIcon(name: icon, size: small ? 11 : 12.5, color: fg) }
                Text(title).font(.ui(small ? 12 : 12.5, kind == .fill ? .semibold : .medium)).foregroundStyle(fg)
                if !keys.isEmpty { Keycaps(keys: keys, onAct: kind == .fill) }
            }
            .padding(.horizontal, small ? 8 : 10).frame(height: small ? 24 : 28)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(edge, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .disabled(disabled)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
        .animation(Motion.base, value: quiet)
    }
}

/// `.btn--fill`.
struct PrimaryButton: View {
    let title: String
    var keys: [String] = []
    var small = false
    let action: () -> Void
    var body: some View { TextButton(title: title, kind: .fill, keys: keys, small: small, action: action) }
}

/// `.btn--line`.
struct SecondaryButton: View {
    let title: String
    var keys: [String] = []
    var small = false
    let action: () -> Void
    var body: some View { TextButton(title: title, kind: .line, keys: keys, small: small, action: action) }
}

/// `.rsvp` segmented control: bg2 track with 2 pt padding, 22 pt options (12 / 500, fg2); the chosen one sits on the thumb.
struct Segmented<T: Hashable>: View {
    let options: [(T, String)]
    let selection: T
    var height: CGFloat = 22
    var minWidth: CGFloat = 0
    let onSelect: (T) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, o in
                let on = o.0 == selection
                Button { onSelect(o.0) } label: {
                    Text(o.1).font(.ui(12, .medium))
                        .foregroundStyle(on ? Theme.fg : Theme.fg2)
                        .padding(.horizontal, 11).frame(minWidth: minWidth, minHeight: height)
                        .background(RoundedRectangle(cornerRadius: Radius.control - 1).fill(on ? Theme.thumb : Color.clear)
                            .shadow(color: .black.opacity(on ? 0.2 : 0), radius: 1, y: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .animation(Motion.base, value: on)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: Radius.control + 1).fill(Theme.bg2))
        .fixedSize()
    }
}

/// `.tg2` switch: 26 x 15 track (bg3 off, act on), 11 pt knob (fg2 off, onAct on).
struct ActToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            ZStack(alignment: .leading) {
                Capsule().fill(configuration.isOn ? Theme.act : Theme.bg3)
                Circle().fill(configuration.isOn ? Theme.onAct : Theme.fg2).frame(width: 11, height: 11)
                    .offset(x: configuration.isOn ? 13 : 2)
            }
            .frame(width: 26, height: 15)
            .animation(Motion.spring, value: configuration.isOn)
            .frame(height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct Hairline: View {
    var color: Color = Theme.hair
    var body: some View { Rectangle().fill(color).frame(height: 1) }
}

extension Theme {
    /// The raised option of a segmented control (`--thumb`).
    static let thumb = Color.dyn("#33333C", "#FFFFFF")
}

// MARK: Empty-state art

/// 7-column hairline grid tile with an act ring; the glyph decides the variant.
struct EmptyArt: View {
    enum Kind { case lock, search, ring }
    let kind: Kind
    var size: CGFloat = 64
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28).fill(Theme.ink700)
            Canvas { ctx, sz in
                var p = Path()
                for i in 1..<7 { let x = sz.width * CGFloat(i) / 7; p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: sz.height)) }
                ctx.stroke(p, with: .color(Theme.hair), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
            RoundedRectangle(cornerRadius: size * 0.28).strokeBorder(Theme.hairStrong, lineWidth: 1)
            switch kind {
            case .lock:
                Circle().stroke(Theme.act, style: StrokeStyle(lineWidth: size * 0.045, dash: [size * 0.04, size * 0.07])).frame(width: size * 0.56, height: size * 0.56)
                SFIcon(name: "lock.fill", size: size * 0.24, color: Theme.actLift)
            case .search:
                Circle().strokeBorder(Theme.act, lineWidth: size * 0.05).frame(width: size * 0.56, height: size * 0.56)
                Rectangle().fill(Theme.act).frame(width: size * 0.36, height: size * 0.05).rotationEffect(.degrees(-45))
            case .ring:
                Circle().strokeBorder(Theme.act, lineWidth: size * 0.05).frame(width: size * 0.5, height: size * 0.5)
                Circle().fill(Theme.actLift).frame(width: size * 0.12, height: size * 0.12)
            }
        }
        .frame(width: size, height: size)
    }
}
