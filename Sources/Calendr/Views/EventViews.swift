import SwiftUI
import CalendrKit

/// Diagonal stripes (135 degrees). Used for tentative bars and teammate overlay fills.
struct Stripes: View {
    var color: Color
    var on: CGFloat = 2
    var off: CGFloat = 2
    var body: some View {
        Canvas { ctx, size in
            let period = on + off
            var x = -size.height
            var path = Path()
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += period * 1.4142
            }
            ctx.stroke(path, with: .color(color), lineWidth: on * 1.4142)
        }
    }
}

struct EventStyle: Equatable {
    var palette: EventPalette
    var secondaryBarRGB: RGB?
    var secondaryBar: Color? { secondaryBarRGB?.color }
    var past: Bool
    var selected: Bool
    var faded: Bool
    var overlapping: Bool
    var isDark = true
    var done = false
}

struct TeammateCell: View, Equatable {
    let title: String
    let time: String
    let rect: CGRect
    let hue: Color
    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.ink900
            Stripes(color: hue.opacity(0.14), on: 4, off: 4)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.paper).lineLimit(1)
                if rect.height > 30 { Text(time).font(.calMono(10)).foregroundStyle(Theme.haze).lineLimit(1) }
            }.padding(.top, 3).padding(.leading, 9).padding(.trailing, 5)
        }
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: Radius.event))
        .overlay(RoundedRectangle(cornerRadius: Radius.event).strokeBorder(hue, lineWidth: 1))
        .placed(rect)
    }
}

/// All-day chip / task capsule in the all-day lanes.
struct AllDayChip: View {
    let title: String
    let width: CGFloat
    let style: EventStyle
    let isTask: Bool
    var done = false
    let height: CGFloat
    var onCheck: () -> Void = {}

    var body: some View {
        let pal = style.palette
        Group {
            if isTask {
                let parts = TaskTitle.split(title)
                HStack(spacing: 5) {
                    Button(action: onCheck) {
                        ZStack {
                            Circle().strokeBorder(done ? Theme.act : Theme.hazeDim, lineWidth: 1.5).background(Circle().fill(done ? Theme.act : Color.clear))
                            if done { Image(systemName: "checkmark").font(.system(size: 7, weight: .heavy)).foregroundStyle(.white) }
                        }.frame(width: 12, height: 12).contentShape(Circle().inset(by: -4))
                    }.buttonStyle(.plain)
                    Text(parts.text).font(.system(size: 11, weight: .medium)).foregroundStyle(done ? Theme.hazeDim : Theme.paper).strikethrough(done).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 4).padding(.trailing, 8)
                .frame(width: width, height: height, alignment: .leading)
                .background(Capsule().fill(Theme.ink700))
                .overlay(Capsule().strokeBorder(Theme.hairStrong, lineWidth: 1))
            } else {
                ZStack(alignment: .leading) {
                    Text(title).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Theme.paper).lineLimit(1)
                        .padding(.leading, style.secondaryBar != nil ? 13 : 10).padding(.trailing, 6)
                    HStack(spacing: 0) {
                        Rectangle().fill(pal.bar).frame(width: 3)
                        if let b = style.secondaryBar { Rectangle().fill(b).frame(width: 3) }
                        Spacer(minLength: 0)
                    }
                }
                .frame(width: width, height: height, alignment: .leading)
                .background(style.selected ? pal.hoverFillRGB.color : pal.fill)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .opacity(style.past ? (style.isDark ? 0.55 : 0.5) : 1)
        .overlay { if style.selected { RoundedRectangle(cornerRadius: isTask ? height / 2 : 6).strokeBorder(Theme.act, lineWidth: 1.5).padding(-0.75) } }
        .liftShadowIf(style.selected)
        .animation(Motion.base, value: style.selected)
    }
}

extension View {
    @ViewBuilder func liftShadowIf(_ on: Bool) -> some View { if on { self.liftShadow() } else { self } }
}
