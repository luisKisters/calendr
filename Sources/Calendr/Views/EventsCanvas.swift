import SwiftUI
import AppKit
import CoreText
import CalendrKit

/// Draws every timed event of the visible range in one Canvas with CoreGraphics/CoreText. A week has 300+ events; a SwiftUI view per
/// event costs ~0.6 ms of graph work each on navigation and `GraphicsContext.resolve(Text)` ~50 us per string. Here a cached CTLine
/// draws in ~5 us. Hit testing is done by the model (`AppModel.hitTest`), so nothing here needs to be a view.
struct EventsCanvas: View {
    let events: [PlacedEvent]
    let geometry: GridGeometry
    let dark: Bool
    let fmt: Fmt
    let dayView: Bool
    /// The block being created, moved or resized, at its preview position (`AppModel.gridPreviewLayout`); `events` leaves it out.
    let preview: PlacedEvent?
    let creating: Bool
    let rank: (PlacedEvent) -> Int
    let styles: (PlacedEvent) -> EventStyle
    /// Read once: `ProcessInfo.environment` builds a dictionary per call, and this ran on every draw.
    private static let profiling = ProcessInfo.processInfo.environment["CALENDR_PROF"] != nil

    var body: some View {
        let g = geometry
        Canvas(opaque: false, rendersAsynchronously: false) { ctx, size in
            let t0 = CFAbsoluteTimeGetCurrent(); defer { if Self.profiling { print(String(format: "canvas %.1f ms (%d events)", (CFAbsoluteTimeGetCurrent() - t0) * 1000, events.count)) } }
            ctx.withCGContext { cg in
                // Ranks once per event: `rank` reads observable model state, and calling it inside the comparator cost ~1 ms a week.
                let ranks = events.map(rank)
                let order = events.indices.sorted { ranks[$0] != ranks[$1] ? ranks[$0] < ranks[$1] : $0 < $1 }
                for i in order {
                    let p = events[i]
                    EventPainter.draw(cg, event: p.event, start: p.startMinute, end: p.endMinute, rect: g.rect(for: p), style: styles(p), fmt: fmt, dayView: dayView)
                }
                if let p = preview {
                    if creating {
                        var s = EventStyle(palette: Palettes.palette(barHex: "#888888", fillHex: nil, dark: dark), past: false, selected: false, overlapping: false)
                        s.draft = true; s.isDark = dark
                        EventPainter.draw(cg, event: p.event, start: p.startMinute, end: p.endMinute, rect: g.rect(for: p), style: s, fmt: fmt, dayView: dayView)
                    } else {
                        var s = styles(p)
                        s.selected = true; s.over = false; s.past = false
                        cg.saveGState(); cg.setAlpha(0.92)
                        EventPainter.draw(cg, event: p.event, start: p.startMinute, end: p.endMinute, rect: g.rect(for: p), style: s, fmt: fmt, dayView: dayView)
                        cg.restoreGState()
                    }
                }
            }
        }
        .frame(width: CGFloat(g.dayWidth) * CGFloat(g.dayCount), height: CGFloat(g.totalHeight))
        .allowsHitTesting(false)
    }
}

/// Cached CoreText lines. Colors come from the graphics context, so one line serves every appearance and state.
@MainActor
enum TextCache {
    enum Kind: Int {
        case title, titleMedium, time, hour, hourBold, header, headerToday, headerNum, headerNumToday, headerPast, allDayLabel, more, monthTitle, monthNum, monthNumToday, micro, dayNum
    }
    struct Key: Hashable { var text: String; var kind: Int }
    private static var lines: [Key: (CTLine, CGFloat, CGFloat, CGFloat)] = [:]   // line, width, ascent, descent

    static func font(_ k: Kind) -> CTFont {
        func f(_ size: CGFloat, _ w: Int, _ tab: Bool = false) -> CTFont { Typeface.ctFont(size, weight: w, tabular: tab) }
        switch k {
        case .title: return f(11.5, 600)
        case .titleMedium: return f(11.5, 500)
        case .time: return f(10.5, 400, true)
        case .hour: return f(10.5, 400, true)
        case .hourBold: return f(10.5, 600, true)
        case .header: return f(12.5, 400)
        case .headerToday: return f(12.5, 600)
        case .headerNum: return f(12.5, 600, true)
        case .headerNumToday: return f(12.5, 650, true)
        case .headerPast: return f(12.5, 450, true)
        case .allDayLabel: return f(9.5, 400)
        case .more: return f(11, 400, true)
        case .monthTitle: return f(11.5, 400)
        case .monthNum: return f(12, 500, true)
        case .monthNumToday: return f(12, 650, true)
        case .micro: return f(10.5, 600)
        case .dayNum: return f(12, 500, true)
        }
    }

    private static var cuts: [Key: CTLine] = [:]
    private static var wraps: [Key: [(CTLine, CGFloat, CGFloat)]] = [:]
    /// Cached word wrapping for event titles (typesetting per frame was measurable), as CSS line-clamp does it: a word wider than
    /// the line gets a line of its own and an ellipsis, and the last line ends with an ellipsis when text is left over.
    static func wrapped(_ text: String, _ kind: Kind, width: CGFloat, maxLines: Int) -> [(line: CTLine, ascent: CGFloat, descent: CGFloat)] {
        let key = Key(text: text + "\u{2}\(Int(width.rounded(.down)))\u{2}\(maxLines)", kind: kind.rawValue)
        if let c = wraps[key] { return c.map { ($0.0, $0.1, $0.2) } }
        var words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var texts: [String] = []
        while !words.isEmpty && texts.count < maxLines {
            if texts.count == maxLines - 1 { texts.append(words.joined(separator: " ")); break }
            var cur = words.removeFirst()
            while let w = words.first, line(cur + " " + w, kind).width <= width { cur += " " + w; words.removeFirst() }
            texts.append(cur)
        }
        let out: [(CTLine, CGFloat, CGFloat)] = texts.map { t in
            let l = line(t, kind)
            return (l.width <= width ? l.line : truncated(t, kind, width: width) ?? l.line, l.ascent, l.descent)
        }
        if wraps.count > 4000 { wraps.removeAll() }
        wraps[key] = out
        return out.map { ($0.0, $0.1, $0.2) }
    }
    private static var ranges: [Int: String] = [:]
    /// "10:10 – 11:50"
    static func range(_ fmt: Fmt, _ a: Int, _ b: Int) -> String {
        let k = (a * 1441 + b) * 2 + (fmt.use24h ? 1 : 0)
        if let t = ranges[k] { return t }
        let t = "\(fmt.time(minutes: a)) \u{2013} \(fmt.time(minutes: b))"; ranges[k] = t; return t
    }
    private static var times: [Int: String] = [:]
    static func time(_ fmt: Fmt, minutes: Int) -> String {
        let k = minutes * 2 + (fmt.use24h ? 1 : 0)
        if let t = times[k] { return t }
        let t = fmt.time(minutes: minutes); times[k] = t; return t
    }
    /// Truncated lines are cached per (text, kind, whole-point width): creating them per frame was the biggest grid cost.
    static func truncated(_ text: String, _ kind: Kind, width: CGFloat) -> CTLine? {
        let key = Key(text: text + "\u{1}\(Int(width.rounded(.down)))", kind: kind.rawValue)
        if let c = cuts[key] { return c }
        let l = line(text, kind).line
        let token = line("\u{2026}", kind).line
        guard let cut = CTLineCreateTruncatedLine(l, Double(max(1, width.rounded(.down))), .end, token) else { return nil }
        if cuts.count > 6000 { cuts.removeAll() }
        cuts[key] = cut
        return cut
    }

    static func line(_ text: String, _ kind: Kind) -> (line: CTLine, width: CGFloat, ascent: CGFloat, descent: CGFloat) {
        let key = Key(text: text, kind: kind.rawValue)
        if let hit = lines[key] { return (hit.0, hit.1, hit.2, hit.3) }
        var attrs: [NSAttributedString.Key: Any] = [.font: font(kind), NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true]
        if kind == .micro { attrs[.kern] = 0.63 }
        if kind == .allDayLabel { attrs[.kern] = 0.19 }
        let l = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        var asc: CGFloat = 0, desc: CGFloat = 0, lead: CGFloat = 0
        let w = CGFloat(CTLineGetTypographicBounds(l, &asc, &desc, &lead))
        if lines.count > 6000 { lines.removeAll() }
        lines[key] = (l, w, asc, desc)
        return (l, w, asc, desc)
    }
}

enum EventPainter {
    /// Draws `line` with its line box top at `top` (CSS-style half leading inside `box` height).
    @MainActor @discardableResult
    static func text(_ cg: CGContext, _ s: String, _ kind: TextCache.Kind, x: CGFloat, top: CGFloat, box: CGFloat = 14, color: CGColor, strike: Bool = false, kern: CGFloat = 0) -> CGFloat {
        let l = TextCache.line(s, kind)
        draw(cg, l.line, width: l.width, ascent: l.ascent, descent: l.descent, x: x, top: top, box: box, color: color, strike: strike)
        return l.width
    }

    @MainActor
    private static func draw(_ cg: CGContext, _ line: CTLine, width: CGFloat, ascent: CGFloat, descent: CGFloat, x: CGFloat, top: CGFloat, box: CGFloat, color: CGColor, strike: Bool) {
        let baseline = top + (box - (ascent + descent)) / 2 + ascent
        cg.saveGState()
        cg.setFillColor(color)
        cg.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        cg.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(line, cg)
        if strike {
            cg.setStrokeColor(color); cg.setLineWidth(1)
            let y = baseline - ascent * 0.3
            cg.move(to: CGPoint(x: x, y: y)); cg.addLine(to: CGPoint(x: x + width, y: y)); cg.strokePath()
        }
        cg.restoreGState()
    }

    /// Like `text` but ends with an ellipsis when wider than `maxWidth` (returns the drawn width).
    @MainActor @discardableResult
    static func truncated(_ cg: CGContext, _ s: String, _ kind: TextCache.Kind, x: CGFloat, top: CGFloat, box: CGFloat = 14, color: CGColor, maxWidth: CGFloat, strike: Bool = false) -> CGFloat {
        let l = TextCache.line(s, kind)
        if l.width <= maxWidth { return text(cg, s, kind, x: x, top: top, box: box, color: color, strike: strike) }
        guard maxWidth > 4, let cut = TextCache.truncated(s, kind, width: maxWidth) else { return 0 }
        let cw = CGFloat(CTLineGetTypographicBounds(cut, nil, nil, nil))
        draw(cg, cut, width: cw, ascent: l.ascent, descent: l.descent, x: x, top: top, box: box, color: color, strike: strike)
        return cw
    }

    /// Wraps `s` to at most `maxLines` lines of `lineHeight` inside `width`; returns the number of lines drawn.
    @MainActor
    static func wrapped(_ cg: CGContext, _ s: String, _ kind: TextCache.Kind, x: CGFloat, top: CGFloat, width: CGFloat, maxLines: Int, lineHeight: CGFloat, color: CGColor, strike: Bool = false) -> Int {
        let l = TextCache.line(s, kind)
        if l.width <= width || maxLines == 1 { truncated(cg, s, kind, x: x, top: top, box: lineHeight, color: color, maxWidth: width, strike: strike); return 1 }
        let lines = TextCache.wrapped(s, kind, width: width, maxLines: maxLines)
        for (n, ln) in lines.enumerated() {
            let w = CGFloat(CTLineGetTypographicBounds(ln.line, nil, nil, nil))
            draw(cg, ln.line, width: w, ascent: ln.ascent, descent: ln.descent, x: x, top: top + CGFloat(n) * lineHeight, box: lineHeight, color: color, strike: strike)
        }
        return max(1, lines.count)
    }

    static func roundedPath(_ r: CGRect, _ radius: CGFloat) -> CGPath {
        let rad = max(0, min(radius, r.height / 2, r.width / 2))
        return CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
    }

    /// A rounded rect whose left and/or right corners are square (all-day chips that continue past the visible range).
    static func chipPath(_ r: CGRect, _ radius: CGFloat, squareLeft: Bool, squareRight: Bool) -> CGPath {
        let rad = max(0, min(radius, r.height / 2))
        let p = CGMutablePath()
        let l = squareLeft ? 0 : rad, rr = squareRight ? 0 : rad
        p.move(to: CGPoint(x: r.minX + l, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - rr, y: r.minY))
        if rr > 0 { p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.maxY), radius: rr) } else { p.addLine(to: CGPoint(x: r.maxX, y: r.minY)) }
        if rr > 0 { p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY), radius: rr) } else { p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)) }
        if l > 0 { p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: l) } else { p.addLine(to: CGPoint(x: r.minX, y: r.maxY)) }
        if l > 0 { p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY), radius: l) } else { p.addLine(to: CGPoint(x: r.minX, y: r.minY)) }
        p.closeSubpath()
        return p
    }

    /// CoreGraphics forms of the ink tokens for the current appearance (values as in `Theme`).
    struct Ink {
        let dark: Bool
        let bg, bg1, bg2, bg3, fg, fg2, fg3, act, onAct, actWash, ring, hair, hair2, hover, live, pastTitle, liftShadow: CGColor
        // v2 names still used by the sidebar.
        var paper: CGColor { fg }
        var haze: CGColor { fg2 }
        var hazeDim: CGColor { fg3 }
        private init(build dark: Bool) {
            self.dark = dark
            func c(_ d: String, _ l: String) -> CGColor { RGB(hex: dark ? d : l).cg }
            fg = c("#EDECF1", "#1B1A20"); fg2 = c("#A19FAC", "#5C5A65"); fg3 = c("#6D6B78", "#918E99")
            bg = c("#0E0E11", "#FBFAF6"); bg1 = c("#15151A", "#F5F3ED"); bg2 = c("#1E1E24", "#ECE9E1"); bg3 = c("#2B2B33", "#DFDBD1")
            act = fg; onAct = bg
            actWash = fg.copy(alpha: 0.09) ?? fg
            ring = fg.copy(alpha: 0.82) ?? fg
            hair2 = fg.copy(alpha: dark ? 0.13 : 0.15) ?? fg
            hair = fg.copy(alpha: dark ? 0.065 : 0.075) ?? fg
            hover = fg.copy(alpha: dark ? 0.055 : 0.05) ?? fg
            live = c("#FF453A", "#E5342A")
            // `.is-past .ev__t`: fg2 78 percent over the window colour.
            pastTitle = RGB(hex: dark ? "#A19FAC" : "#5C5A65").mixed(with: RGB(hex: dark ? "#0E0E11" : "#FBFAF6"), 0.22).cg
            liftShadow = dark ? CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.45) : CGColor(srgbRed: 40 / 255, green: 34 / 255, blue: 20 / 255, alpha: 0.16)
        }
        private static let darkInk = Ink(build: true)
        private static let lightInk = Ink(build: false)
        static func of(_ dark: Bool) -> Ink { dark ? darkInk : lightInk }
    }

    /// One event block (app.css `.ev`): tint and bar. Sizes by height: under 30 pt one line (title, start time), under 50 pt title
    /// and range, taller a two-line title then the range.
    @MainActor
    static func draw(_ cg: CGContext, event e: CalendarEvent, start: Int, end: Int, rect r: CGRect, style: EventStyle, fmt: Fmt, dayView: Bool) {
        let pal = style.palette
        let ink = Ink.of(style.isDark)
        let shape = roundedPath(r, Radius.event)
        let declined = e.status == .declined && !style.draft
        cg.saveGState()
        defer { cg.restoreGState() }

        // Fill, outline and shadow.
        if style.draft {
            cg.addPath(shape); cg.setFillColor(ink.actWash); cg.fillPath()
            cg.saveGState()
            cg.addPath(roundedPath(r.insetBy(dx: 0.75, dy: 0.75), Radius.event - 0.75))
            cg.setStrokeColor(ink.ring); cg.setLineWidth(1.5); cg.setLineDash(phase: 0, lengths: [4.5, 3]); cg.strokePath()
            cg.restoreGState()
        } else if declined {
            cg.addPath(shape); cg.setFillColor(ink.bg); cg.fillPath()
            cg.addPath(roundedPath(r.insetBy(dx: 0.5, dy: 0.5), Radius.event - 0.5))
            cg.setStrokeColor(pal.barRGB.cg.copy(alpha: 0.4) ?? pal.barRGB.cg); cg.setLineWidth(1); cg.strokePath()
        } else {
            if style.over && !style.selected {
                cg.addPath(roundedPath(r.insetBy(dx: -0.75, dy: -0.75), Radius.event + 0.75)); cg.setStrokeColor(ink.bg); cg.setLineWidth(1.5); cg.strokePath()
            }
            let fill = style.past && !style.selected ? pal.pastFillRGB : (style.selected || style.hovered ? pal.hoverFillRGB : pal.fillRGB)
            if style.selected {
                cg.saveGState()
                cg.setShadow(offset: CGSize(width: 0, height: 8), blur: 22, color: ink.liftShadow)
                cg.addPath(shape); cg.setFillColor(fill.cg); cg.fillPath()
                cg.restoreGState()
            }
            cg.addPath(shape); cg.setFillColor(fill.cg); cg.fillPath()
        }
        if style.selected && !style.draft {
            cg.addPath(roundedPath(r.insetBy(dx: -0.75, dy: -0.75), Radius.event + 0.75)); cg.setStrokeColor(ink.ring); cg.setLineWidth(1.5); cg.strokePath()
        }

        cg.addPath(shape); cg.clip()
        // Bar: 3 pt, inset 3 pt from top, bottom and left.
        if !style.draft && !declined {
            let bar = CGRect(x: r.minX + 3, y: r.minY + 3, width: 3, height: max(0, r.height - 6))
            let color = style.past && !style.selected ? (pal.barRGB.cg.copy(alpha: 0.5) ?? pal.barRGB.cg) : pal.barRGB.cg
            cg.saveGState()
            cg.addPath(roundedPath(bar, 1.5)); cg.clip()
            cg.setFillColor(color)
            if e.status == .tentative {
                var y = bar.minY
                while y < bar.maxY { cg.fill(CGRect(x: bar.minX, y: y, width: 3, height: min(3, bar.maxY - y))); y += 6 }
            } else { cg.fill(bar) }
            cg.restoreGState()
        }

        // Text.
        let title = e.title.isEmpty ? (style.draft || e.id.isEmpty ? "New event" : "(No title)") : e.title
        let titleColor: CGColor, timeColor: CGColor
        if style.draft { titleColor = ink.fg; timeColor = ink.fg2 }
        else if declined { titleColor = ink.fg3; timeColor = ink.fg3 }
        else if style.selected { titleColor = ink.fg; timeColor = pal.timeRGB.cg }
        else if style.past { titleColor = ink.pastTitle; timeColor = ink.fg3.copy(alpha: 0.8) ?? ink.fg3 }
        else { titleColor = pal.titleRGB.cg; timeColor = pal.timeRGB.cg }
        let titleKind: TextCache.Kind = declined ? .titleMedium : .title
        let x = r.minX + (style.draft ? 8 : 11)
        let w = max(1, r.maxX - 6 - x)
        if r.height < 30 {
            let startS = TextCache.time(fmt, minutes: start)
            let tw = r.width > 118 ? TextCache.line(startS, .time).width : 0
            let top = r.minY + (r.height - 15) / 2
            let drawn = truncated(cg, title, titleKind, x: x, top: top, box: 15, color: titleColor, maxWidth: tw > 0 ? max(1, w - tw - 6) : w, strike: declined)
            if tw > 0 { text(cg, startS, .time, x: x + drawn + 6, top: r.minY + (r.height - 14) / 2, box: 14, color: timeColor) }
        } else {
            let lines = wrapped(cg, title, titleKind, x: x, top: r.minY + 4, width: w, maxLines: r.height < 50 ? 1 : 2, lineHeight: 15, color: titleColor, strike: declined)
            var y = r.minY + 4 + CGFloat(lines) * 15
            truncated(cg, TextCache.range(fmt, start, end), .time, x: x, top: y, box: 14, color: timeColor, maxWidth: w)
            y += 14
            if dayView && r.height > 66 && !e.location.isEmpty && !declined {
                truncated(cg, e.location.components(separatedBy: "\n")[0], .time, x: x, top: y, box: 14, color: timeColor, maxWidth: w)
            }
        }
    }
}
