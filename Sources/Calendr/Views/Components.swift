import SwiftUI
import AppKit

// Shared building blocks (design/mockup-v4 `.ds` controls): key hints, buttons, the one segmented control, empty-state art.

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

/// `.ibtn`: 26 pt square with a 16 pt icon (panel, header), or 22 with a 14 pt icon (`small`: sidebar, rows); radius 6, fg2 glyph,
/// hover wash and fg. An SF Symbol at point size p is about 1.33 p tall, so the icon box of g points uses a symbol of 0.75 g.
struct IconButton: View {
    let name: String
    var small = false
    var color: Color = Theme.fg2
    var help: String?
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        let glyph = small ? Dim.iconGlyphSmall : Dim.iconGlyph, box = small ? Dim.iconButtonSmall : Dim.iconButton
        Button(action: action) {
            SFIcon(name: name, size: glyph * 0.75, color: hover ? Theme.fg : color)
                .frame(width: glyph, height: glyph)
                .frame(width: box, height: box)
                .background(RoundedRectangle(cornerRadius: Radius.row).fill(hover ? Theme.hover : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
        .help(help ?? "")
    }
}

/// A shortcut hint (round 3): grey small tabular text, no box.
struct Keycap: View {
    let text: String
    var onAct = false
    var body: some View {
        Text(text).font(.smallTab).foregroundStyle(onAct ? Theme.onAct.opacity(0.6) : Theme.fg3).fixedSize()
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
                if k == "or" { Text("or").font(.small).foregroundStyle(Theme.fg3) } else { Keycap(text: Self.glyph(k), onAct: onAct) }
            }
        }
    }
    static func glyph(_ k: String) -> String { k == "command" ? "\u{2318}" : k }
}

/// `.btn`: 32 pt (28 small), radius 8, 12.5 / 500. Plain is fg2 with a hover wash, line adds a hair2 edge and fg text,
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
                Text(title).font(kind == .fill ? .textSemibold : .textMedium).foregroundStyle(fg)
                if !keys.isEmpty { Keycaps(keys: keys, onAct: kind == .fill) }
            }
            .padding(.horizontal, small ? 10 : 12).frame(height: small ? Dim.row : Dim.field)
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

/// The one segmented control (Day / Week / Month, Going?, every settings choice): a hair2 frame inset 1 pt, padding 2, radius 8.
/// Segments are 22 pt high, radius 6, 10 pt side padding. The selected one sits on the thumb in fg 600; the others are fg2 400
/// with a hover fill.
struct Segmented<T: Hashable>: View {
    let options: [(T, String)]
    let selection: T
    var minWidth: CGFloat = 0
    var enabled = true
    /// Optional tooltip per option (same order as `options`).
    var helps: [String] = []
    let onSelect: (T) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, o in
                SegmentButton(title: o.1, on: o.0 == selection, minWidth: minWidth, enabled: enabled) { onSelect(o.0) }
                    .help(i < helps.count ? helps[i] : "")
            }
        }
        .segmentedFrame()
        .animation(Motion.fast, value: selection)
    }
}

private extension View {
    /// The frame of `Segmented`: padding 2, 1 pt hair2 edge inside, radius 8.
    func segmentedFrame() -> some View {
        padding(2)
            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Theme.hair2, lineWidth: 1))
            .fixedSize()
    }
}

/// Hover forced by the walkthrough driver: synthesized pointer events cannot reach SwiftUI's hover tracking offscreen, so the
/// v4 tours name the control the cursor rests on. Nil in the app.
@MainActor @Observable
final class HoverProbe {
    static let shared = HoverProbe()
    var target: String?
}

struct SegmentButton: View {
    let title: String
    let on: Bool
    var minWidth: CGFloat = 0
    var enabled = true
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        let h = (hover || HoverProbe.shared.target == title) && enabled && !on
        Button { if enabled { action() } } label: {
            Text(title).font(on ? .smallSemibold : .small)
                .foregroundStyle(on || h ? Theme.fg : Theme.fg2)
                .padding(.horizontal, 10).frame(minWidth: minWidth, minHeight: Dim.segment, maxHeight: Dim.segment)
                .background(RoundedRectangle(cornerRadius: Radius.row).fill(on ? Theme.thumb : h ? Theme.hover : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

struct Hairline: View {
    var color: Color = Theme.hair
    var body: some View { Rectangle().fill(color).frame(height: 1) }
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
