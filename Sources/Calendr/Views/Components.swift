import SwiftUI
import AppKit

// Shared v2 building blocks: keycaps, buttons, segmented control, toggle, empty-state art, wordmark.

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

struct IconButton: View {
    let name: String
    var size: CGFloat = 15
    var box: CGFloat = 28
    var color: Color = Theme.haze
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            SFIcon(name: name, size: size, color: hover ? Theme.paper : color)
                .frame(width: box, height: box)
                .background(RoundedRectangle(cornerRadius: 8).fill(hover ? Theme.hover : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

/// Mono 10.5 / 600 keycap, `haze` on `ink600`, radius 5, 1pt bottom edge.
struct Keycap: View {
    let text: String
    var onAct = false
    var body: some View {
        let wide = text.count > 1 && text.allSatisfy(\.isLetter)
        Text(text).font(.calMono(10.5, .semibold)).foregroundStyle(onAct ? Color.white : Theme.haze)
            .padding(.horizontal, wide ? 7 : 5).frame(minWidth: 19, minHeight: 19)
            .background(RoundedRectangle(cornerRadius: 5).fill(onAct ? Color.white.opacity(0.18) : Theme.ink600))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(onAct ? Color.clear : Theme.hair, lineWidth: 1))
            .shadow(color: onAct ? .clear : Theme.keyEdge, radius: 0, y: 1)
    }
}

struct Keycaps: View {
    let keys: [String]
    var onAct = false
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, k in
                if k == "or" { Text("or").font(.calMeta).foregroundStyle(Theme.haze) } else { Keycap(text: Self.glyph(k), onAct: onAct) }
            }
        }
    }
    static func glyph(_ k: String) -> String { k == "command" ? "\u{2318}" : k }
}

struct PrimaryButton: View {
    let title: String
    var keys: [String] = []
    var small = false
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: small ? 12 : 13, weight: .medium))
                if !keys.isEmpty { Keycaps(keys: keys, onAct: true) }
            }
            .foregroundStyle(Theme.onAct)
            .padding(.horizontal, small ? 10 : 14).frame(height: small ? 26 : 30)
            .background(RoundedRectangle(cornerRadius: small ? 8 : Radius.control).fill(hover ? Theme.actLift : Theme.act))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

struct SecondaryButton: View {
    let title: String
    var keys: [String] = []
    var small = false
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: small ? 12 : 13, weight: .medium))
                if !keys.isEmpty { Keycaps(keys: keys) }
            }
            .foregroundStyle(Theme.paper)
            .padding(.horizontal, small ? 10 : 14).frame(height: small ? 26 : 30)
            .background(RoundedRectangle(cornerRadius: small ? 8 : Radius.control).fill(hover ? Theme.ink600 : Theme.ink700))
            .overlay(RoundedRectangle(cornerRadius: small ? 8 : Radius.control).strokeBorder(Theme.hairStrong, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

/// Track ink-700, thumb ink-600 sliding 180 ms.
struct Segmented<T: Hashable>: View {
    let options: [(T, String)]
    let selection: T
    var height: CGFloat = 26
    var minWidth: CGFloat = 0
    let onSelect: (T) -> Void
    @State private var widths: [Int: CGFloat] = [:]

    var body: some View {
        let idx = options.firstIndex { $0.0 == selection } ?? 0
        let w = options.indices.map { widths[$0] ?? 0 }
        let x = w.prefix(idx).reduce(0, +)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 7).fill(Theme.ink600)
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.hairStrong, lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                .frame(width: w[idx], height: height)
                .offset(x: x)
                .animation(Motion.base, value: idx)
            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, o in
                    Button { onSelect(o.0) } label: {
                        Text(o.1).font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(i == idx ? Theme.paper : Theme.haze)
                            .padding(.horizontal, 12).frame(minWidth: minWidth, minHeight: height)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { widths[i] = $0 }
                }
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: Radius.control).fill(Theme.ink700))
        .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Theme.hair, lineWidth: 1))
        .fixedSize()
    }
}

/// 30x18 track, ink-600 off / act on, 14 pt knob with spring overshoot.
struct ActToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            ZStack(alignment: .leading) {
                Capsule().fill(configuration.isOn ? Theme.act : Theme.ink600).overlay(Capsule().strokeBorder(Theme.hair, lineWidth: 1))
                Circle().fill(Color.white).frame(width: 14, height: 14).shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
                    .offset(x: configuration.isOn ? 14 : 2)
            }
            .frame(width: 30, height: 18)
            .animation(Motion.base, value: configuration.isOn)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(Theme.hair).frame(height: 1) }
}

// MARK: Brand

/// Small purple ring-and-dot glyph, the app icon's ring turned into a calendar dot.
struct Wordmark: View {
    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle().strokeBorder(Theme.act, lineWidth: 1.8).frame(width: 15, height: 15)
                Circle().fill(Theme.actLift).frame(width: 4.5, height: 4.5)
            }
            .frame(width: 18, height: 18)
            Text("Calendr").font(.system(size: 14, weight: .semibold)).tracking(-0.2).foregroundStyle(Theme.paper)
        }
    }
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
