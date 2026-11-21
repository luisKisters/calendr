import SwiftUI
import HorionKit

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

/// The colours of one block in one reply state (v11 recipe, design/design-system/foundations.md "Event recipe"; mockup app.css
/// `.ev.past`, `.ev.st-none`, `.ev.st-no`, designer.css `.d-maybe-0`). Normal: fill, bar, title, time. Past: fill → bg, past bar,
/// fitted past title and time. Not answered: bg fill and a 1 pt `edge` outline. Maybe: 135 degree hatch in the hover fill (not past).
/// Declined: fill → bg, the past bar, a fitted grey title, struck. No alpha on any text or bar.
struct BlockColors: Equatable {
    var fill: RGB
    /// The hatch bands of a maybe block (drawn over `fill`).
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
            return BlockColors(fill: past ? pastFillRGB : fillRGB, stripe: past ? nil : hoverFillRGB, bar: bar, barAlpha: 1, title: title, time: time, outline: nil, strike: false)
        case .notAnswered:
            // `.ev.st-none`: bg fill, fg1 / fg2 text, no bar (the painter skips it when there is an outline), a 1 pt hue outline.
            return BlockColors(fill: bgRGB, stripe: nil, bar: bar, barAlpha: 1, title: fgRGB, time: fg2RGB, outline: edgeRGB, strike: false)
        case .declined:
            return BlockColors(fill: declFillRGB, stripe: nil, bar: pastBarRGB, barAlpha: 1, title: declTitleRGB, time: declTitleRGB, outline: nil, strike: true)
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
    /// Changes the editor holds that are not sent yet: a small dot in the top-right corner (the editor's "not sent" dot).
    var unsent = false

    init(palette: EventPalette, past: Bool, selected: Bool, overlapping: Bool) {
        self.palette = palette; self.past = past; self.selected = selected; self.over = overlapping
    }

    var colors: BlockColors {
        var c = palette.colors(reply: reply, past: past)
        if selected && !draft {
            // `.ev.sel`: the selected fill with its fitted title and time (rings: 1.5 pt bg, then the bar colour).
            c.fill = palette.selFillRGB; c.title = palette.selTitleRGB; c.time = palette.selTimeRGB; c.outline = nil
        } else if hovered && !past && reply != .notAnswered {
            // `.ev:not(.past):not(.sel):not(.st-none):hover`: the hover fill, no hatch.
            c.fill = palette.hoverFillRGB; c.stripe = nil
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
