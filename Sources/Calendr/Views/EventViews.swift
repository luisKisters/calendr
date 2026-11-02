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

/// My reply as the grid draws it (mockup `myResp`, status style "quiet"): the organizer and an event without guests count as accepted.
enum EventReply: Equatable {
    case accepted, maybe, notAnswered, declined
    init(_ e: CalendarEvent) {
        switch e.myReply {
        case .confirmed: self = .accepted
        case .tentative: self = .maybe
        case .declined: self = .declined
        case .needsAction: self = .notAnswered
        }
    }
    /// The word the "+N" stack shows after the title.
    var label: String? {
        switch self {
        case .accepted: nil
        case .maybe: "maybe"
        case .notAnswered: "no reply"
        case .declined: "declined"
        }
    }
}

/// The colours of one block in one reply state (mockup :181-204, :458-473 `.rs-quiet`, :612-613 `.ds`).
/// Normal: fill, bar, fg, fg2. Past: past fill and bar, fg2, fg3. Not answered: window fill and a 1 pt `dash` outline, title fg.
/// Maybe: 135 degree stripes, 6 pt of fill and 6 pt of fill 55 percent over the window colour. Declined: fill 38 percent over the
/// window colour, the bar at .45, fg3 struck text.
struct BlockColors: Equatable {
    var fill: RGB
    /// The second band of the maybe stripes.
    var stripe: RGB?
    var bar: RGB
    var barAlpha: Double
    var title: RGB
    var time: RGB
    /// 1 pt inside the edge.
    var outline: RGB?
    var strike: Bool
}

extension EventPalette {
    func colors(reply: EventReply, past: Bool) -> BlockColors {
        let bar = past ? pastBarRGB : barRGB
        let title = past ? pastTitleRGB : titleRGB, time = past ? pastTimeRGB : timeRGB
        switch reply {
        case .accepted:
            return BlockColors(fill: past ? pastFillRGB : fillRGB, stripe: nil, bar: bar, barAlpha: 1, title: title, time: time, outline: nil, strike: false)
        case .maybe:
            // `.rs-quiet .ev.st-maybe` outranks `.ev.past`: the stripes always use the normal fill.
            return BlockColors(fill: fillRGB, stripe: bgRGB.mixed(with: fillRGB, 0.55), bar: bar, barAlpha: 1, title: title, time: time, outline: nil, strike: false)
        case .notAnswered:
            return BlockColors(fill: bgRGB, stripe: nil, bar: bar, barAlpha: 1, title: titleRGB, time: time, outline: dashRGB, strike: false)
        case .declined:
            return BlockColors(fill: bgRGB.mixed(with: fillRGB, 0.38), stripe: nil, bar: bar, barAlpha: 0.45, title: fg3RGB, time: fg3RGB, outline: nil, strike: true)
        }
    }
}

struct EventStyle: Equatable {
    var palette: EventPalette
    var past: Bool
    var selected: Bool
    /// Cut (`.ev.cut`): laid against or over another block, with a 1.5 pt window-coloured ring.
    var over: Bool
    var hovered = false
    /// The event being created: dashed ring over `actWash`, no bar.
    var draft = false
    var isDark = true
    var reply: EventReply = .accepted
    /// 15 minutes or less: shows only its start time.
    var isShort = false

    init(palette: EventPalette, past: Bool, selected: Bool, overlapping: Bool) {
        self.palette = palette; self.past = past; self.selected = selected; self.over = overlapping
    }

    var colors: BlockColors {
        var c = palette.colors(reply: reply, past: past)
        if hovered {
            c.fill = Palettes.brighter(c.fill); c.stripe = c.stripe.map { Palettes.brighter($0) }
            c.bar = Palettes.brighter(c.bar); c.outline = c.outline.map { Palettes.brighter($0) }
        }
        return c
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
