import SwiftUI
import CalendrKit

/// Diagonal stripes (135 degrees): teammate overlay fills.
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
    var past: Bool
    var selected: Bool
    /// Laid over an earlier event (`.is-over`): cut out of it with a window-coloured outline.
    var over: Bool
    var hovered = false
    /// The event being created: dashed ring over `actWash`, no bar.
    var draft = false
    var isDark = true

    init(palette: EventPalette, past: Bool, selected: Bool, overlapping: Bool) {
        self.palette = palette; self.past = past; self.selected = selected; self.over = overlapping
    }
}

/// Teammate busy block (`.mate`): striped in the teammate's colour on the right of the column.
struct TeammateCell: View, Equatable {
    let size: CGSize
    let hue: Color
    var body: some View {
        ZStack {
            Theme.bg.opacity(0.6)
            Stripes(color: hue.opacity(0.24), on: 2, off: 4)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.event))
        .overlay(RoundedRectangle(cornerRadius: Radius.event).strokeBorder(hue, lineWidth: 1))
    }
}
