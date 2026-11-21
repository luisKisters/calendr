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
    /// "+N" groups per day, and the buttons drawn inverted (hovered or open).
    var groups: [[OverflowGroup]] = []
    var hotMore: [GridMoreRef] = []
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
                var top: [Int] = []
                for i in order where !events[i].placement.hidden {
                    if ranks[i] >= 100_000 { top.append(i); continue }     // the selected block and the draft go above the "+N" buttons
                    let p = events[i]
                    EventPainter.draw(cg, event: p.event, start: p.startMinute, end: p.endMinute, rect: g.rect(for: p), style: styles(p), fmt: fmt, dayView: dayView)
                }
                let ink = EventPainter.Ink.of(dark)
                for (d, day) in groups.enumerated() {
                    for (k, grp) in day.enumerated() {
                        EventPainter.more(cg, grp, rect: g.moreRect(day: d, group: grp), hot: hotMore.contains(GridMoreRef(day: d, group: k)), ink: ink)
                    }
                }
                for i in top {
                    let p = events[i]
                    EventPainter.draw(cg, event: p.event, start: p.startMinute, end: p.endMinute, rect: g.rect(for: p), style: styles(p), fmt: fmt, dayView: dayView)
                }
                if let p = preview {
                    if creating {
                        var s = EventStyle(palette: Palettes.palette(barHex: InkRGB.neutralHex, fillHex: nil, dark: dark), past: false, selected: false, overlapping: false)
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
        case title, titleMedium, time, hour, hourBold, header, headerToday, headerNum, headerNumToday, headerPast, allDayLabel, more, monthTitle, monthNum, monthNumToday, micro, dayNum, moreChip
    }
    struct Key: Hashable { var text: String; var kind: Int }
    private static var lines: [Key: (CTLine, CGFloat, CGFloat, CGFloat)] = [:]   // line, width, ascent, descent

    static func font(_ k: Kind) -> CTFont {
        // SF Pro throughout (v4); sizes are the type tokens.
        func f(_ size: CGFloat, _ w: Int, _ tab: Bool = false) -> CTFont { SF.ctFont(size, weight: w, tabular: tab) }
        switch k {
        case .title: return f(TypeSize.event, 500)
        case .titleMedium: return f(TypeSize.event, 500)
        case .time: return f(TypeSize.small, 400, true)
        case .hour: return f(TypeSize.small, 400, true)
        case .hourBold: return f(TypeSize.small, 600, true)
        case .header: return f(TypeSize.small, 400)
        case .headerToday: return f(TypeSize.small, 600)
        case .headerNum: return f(TypeSize.small, 600, true)
        case .headerNumToday: return f(TypeSize.small, 600, true)
        case .headerPast: return f(TypeSize.small, 400, true)
        case .allDayLabel: return f(TypeSize.small, 400)
        case .more: return f(TypeSize.small, 400, true)
        case .monthTitle: return f(TypeSize.small, 400)
        case .monthNum: return f(TypeSize.small, 500, true)
        case .monthNumToday: return f(TypeSize.small, 600, true)
        case .micro: return f(TypeSize.small, 600)
        case .dayNum: return f(TypeSize.small, 500, true)
        case .moreChip: return f(TypeSize.small, 600, true)
        }
    }

    private static var cuts: [Key: CTLine] = [:]
    private static var wraps: [Key: [(CTLine, CGFloat, CGFloat)]] = [:]
    /// Cached word wrapping for event titles (typesetting per frame was measurable), as CSS line-clamp does it: a word wider than
    /// the line gets a line of its own and an ellipsis, and the last line ends with an ellipsis when text is left over. With
    /// `hyphenate` (`hyphens: auto`, the mockup's `lang="en"`) a word that does not fit breaks at a syllable with a hyphen.
    /// Everything is cached per (text, width, lines), so hyphenation costs nothing after the first frame.
    static func wrapped(_ text: String, _ kind: Kind, width: CGFloat, maxLines: Int, hyphenate: Bool = false) -> [(line: CTLine, ascent: CGFloat, descent: CGFloat)] {
        let key = Key(text: text + "\u{2}\(Int(width.rounded(.down)))\u{2}\(maxLines)\(hyphenate ? "h" : "")", kind: kind.rawValue)
        if let c = wraps[key] { return c.map { ($0.0, $0.1, $0.2) } }
        let texts = wrapTexts(text, kind, width: width, maxLines: maxLines, hyphenate: hyphenate)
        let out: [(CTLine, CGFloat, CGFloat)] = texts.map { t in
            let l = line(t, kind)
            return (l.width <= width ? l.line : truncated(t, kind, width: width) ?? l.line, l.ascent, l.descent)
        }
        if wraps.count > 4000 { wraps.removeAll() }
        wraps[key] = out
        return out.map { ($0.0, $0.1, $0.2) }
    }

    /// The text of each line (the last one may still be too wide: it is truncated with an ellipsis).
    static func wrapTexts(_ text: String, _ kind: Kind, width: CGFloat, maxLines: Int, hyphenate: Bool) -> [String] {
        var words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var texts: [String] = []
        var cur = ""
        func fits(_ t: String) -> Bool { line(t, kind).width <= width }
        while let w = words.first, texts.count < maxLines {
            let candidate = cur.isEmpty ? w : cur + " " + w
            if fits(candidate) { cur = candidate; words.removeFirst(); continue }
            if texts.count == maxLines - 1 { break }           // the last line: the rest is cut with an ellipsis below
            if hyphenate, let (head, tail) = hyphenSplit(w, fitting: { fits(cur.isEmpty ? $0 : cur + " " + $0) }) {
                texts.append(cur.isEmpty ? head : cur + " " + head)
                words[0] = tail; cur = ""
                continue
            }
            if cur.isEmpty { cur = w; words.removeFirst() }      // a word wider than the line: a line of its own
            texts.append(cur); cur = ""
        }
        if !words.isEmpty { cur = cur.isEmpty ? words.joined(separator: " ") : cur + " " + words.joined(separator: " ") }
        if !cur.isEmpty && texts.count < maxLines { texts.append(cur) }
        return texts
    }

    private static let hyphenLocale = Locale(identifier: "en_US") as CFLocale
    /// The longest syllable prefix of `word` that, with a hyphen, passes `fits`; the head ends with "-".
    static func hyphenSplit(_ word: String, fitting fits: (String) -> Bool) -> (String, String)? {
        let ns = word as NSString
        let cf = word as CFString
        var before = ns.length
        while before > 2 {
            let loc = CFStringGetHyphenationLocationBeforeIndex(cf, before, CFRange(location: 0, length: ns.length), 0, hyphenLocale, nil)
            guard loc != kCFNotFound, loc >= 2, loc < ns.length - 1 else { return nil }
            let head = ns.substring(to: loc) + "-"
            if fits(head) { return (head, ns.substring(from: loc)) }
            before = loc
        }
        return nil
    }
    private static var ranges: [Int: String] = [:]
    /// "10:10–11:50" (mockup `grid()`: no spaces around the dash).
    static func range(_ fmt: Fmt, _ a: Int, _ b: Int) -> String {
        let k = (a * 1441 + b) * 2 + (fmt.use24h ? 1 : 0)
        if let t = ranges[k] { return t }
        let t = "\(fmt.time(minutes: a))\u{2013}\(fmt.time(minutes: b))"; ranges[k] = t; return t
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
    /// `clipped`: when not even an ellipsis fits, draw the whole line and let the caller's clip cut it (CSS `overflow: hidden`).
    static func truncated(_ cg: CGContext, _ s: String, _ kind: TextCache.Kind, x: CGFloat, top: CGFloat, box: CGFloat = 14, color: CGColor, maxWidth: CGFloat, strike: Bool = false, clipped: Bool = false) -> CGFloat {
        let l = TextCache.line(s, kind)
        if l.width <= maxWidth { return text(cg, s, kind, x: x, top: top, box: box, color: color, strike: strike) }
        let token = TextCache.line("\u{2026}", kind).width
        guard maxWidth > max(4, token), let cut = TextCache.truncated(s, kind, width: maxWidth) else {
            return clipped ? text(cg, s, kind, x: x, top: top, box: box, color: color, strike: strike) : 0
        }
        let cw = CGFloat(CTLineGetTypographicBounds(cut, nil, nil, nil))
        draw(cg, cut, width: cw, ascent: l.ascent, descent: l.descent, x: x, top: top, box: box, color: color, strike: strike)
        return cw
    }

    /// Wraps `s` to at most `maxLines` lines of `lineHeight` inside `width`; returns the number of lines drawn.
    @MainActor
    static func wrapped(_ cg: CGContext, _ s: String, _ kind: TextCache.Kind, x: CGFloat, top: CGFloat, width: CGFloat, maxLines: Int, lineHeight: CGFloat, color: CGColor, strike: Bool = false, hyphenate: Bool = false) -> Int {
        let l = TextCache.line(s, kind)
        if l.width <= width || maxLines == 1 { truncated(cg, s, kind, x: x, top: top, box: lineHeight, color: color, maxWidth: width, strike: strike, clipped: true); return 1 }
        let lines = TextCache.wrapped(s, kind, width: width, maxLines: maxLines, hyphenate: hyphenate)
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

    /// CoreGraphics forms of the ink tokens for the current appearance (from `InkRGB`, like `Theme`).
    struct Ink {
        let dark: Bool
        let bg, bg1, bg2, bg3, fg, fg2, fg3, act, onAct, actWash, ring, hair, hair2, hover, live, pastTitle, liftShadow: CGColor
        // v2 names still used by the sidebar.
        var paper: CGColor { fg }
        var haze: CGColor { fg2 }
        var hazeDim: CGColor { fg3 }
        private init(build dark: Bool) {
            self.dark = dark
            let t = InkRGB.of(dark)
            fg = t.fg.cg; fg2 = t.fg2.cg; fg3 = t.fg3.cg
            bg = t.bg.cg; bg1 = t.bg1.cg; bg2 = t.bg2.cg; bg3 = t.bg3.cg
            act = fg; onAct = bg
            actWash = fg.copy(alpha: 0.09) ?? fg
            ring = fg.copy(alpha: 0.82) ?? fg
            hair2 = fg.copy(alpha: t.hair2Alpha) ?? fg
            hair = fg.copy(alpha: t.hairAlpha) ?? fg
            hover = fg.copy(alpha: t.hoverAlpha) ?? fg
            live = t.live.cg
            // `.is-past .ev__t`: fg2 78 percent over the window colour.
            pastTitle = t.fg2.mixed(with: t.bg, 0.22).cg
            liftShadow = dark ? InkRGB.black.cg.copy(alpha: 0.45)! : InkRGB.paperShadow.cg.copy(alpha: 0.16)!
        }
        private static let darkInk = Ink(build: true)
        private static let lightInk = Ink(build: false)
        static func of(_ dark: Bool) -> Ink { dark ? darkInk : lightInk }
    }

    /// The 135 degree stripes of a maybe block (`repeating-linear-gradient(135deg, fill 0 6px, stripe 6px 12px)`): the band at
    /// distance d = (x + y) / sqrt 2 from the top-left corner is `fill` when d mod 12 < 6. One path per block, drawn under its clip.
    static func stripes(_ cg: CGContext, _ r: CGRect, color: CGColor) {
        let step = 12 * 2.0.squareRoot(), band = 6 * 2.0.squareRoot(), h = r.height
        let p = CGMutablePath()
        var a = 0.0
        while a < r.width + h {
            let b = a + band
            p.move(to: CGPoint(x: r.minX + a, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + b, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX + b - h, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX + a - h, y: r.maxY)); p.closeSubpath()
            a += step
        }
        cg.addPath(p); cg.setFillColor(color); cg.fillPath()
    }

    /// The rings outside a block: cut (1.5 pt of window colour) and selected (that plus 1.5 pt of fg, `0 0 0 1.5px bg, 0 0 0 3px fg`).
    static func rings(_ cg: CGContext, _ path: (CGFloat) -> CGPath, selected: Bool, cut: Bool, ink: Ink) {
        if selected {
            cg.addPath(path(-2.25)); cg.setStrokeColor(ink.fg); cg.setLineWidth(1.5); cg.strokePath()
        }
        if selected || cut {
            cg.addPath(path(-0.75)); cg.setStrokeColor(ink.bg); cg.setLineWidth(1.5); cg.strokePath()
        }
    }

    /// The "+N" button (`.evmore`): bg3 with fg text, a 1.5 pt bg ring; inverted (fg with bg text) when hovered or open.
    @MainActor
    static func more(_ cg: CGContext, _ grp: OverflowGroup, rect r: CGRect, hot: Bool, ink: Ink) {
        let shape = roundedPath(r, r.height / 2)
        cg.addPath(roundedPath(r.insetBy(dx: -0.75, dy: -0.75), r.height / 2 + 0.75)); cg.setStrokeColor(ink.bg); cg.setLineWidth(1.5); cg.strokePath()
        cg.addPath(shape); cg.setFillColor(hot ? ink.fg : ink.bg3); cg.fillPath()
        let s = GridGeometry.moreLabel(grp)
        let w = TextCache.line(s, .moreChip).width
        text(cg, s, .moreChip, x: r.midX - w / 2, top: r.minY, box: r.height, color: hot ? ink.bg : ink.fg)
    }

    /// Line height of event text: 11.5 pt at `line-height: 1.25`.
    static let lineHeight: CGFloat = 14.4

    /// One event block (mockup-v4 `.ev`): fill in its reply state, bar, title and time as `BlockText.plan` lays them out.
    @MainActor
    static func draw(_ cg: CGContext, event e: CalendarEvent, start: Int, end: Int, rect r: CGRect, style: EventStyle, fmt: Fmt, dayView: Bool) {
        let ink = Ink.of(style.isDark)
        let shape = roundedPath(r, Radius.event)
        let c = style.colors
        cg.saveGState()
        defer { cg.restoreGState() }

        // Rings, fill, stripes, outline.
        rings(cg, { roundedPath(r.insetBy(dx: $0, dy: $0), Radius.event - $0) }, selected: style.selected && !style.draft, cut: style.over, ink: ink)
        if style.draft {
            cg.addPath(shape); cg.setFillColor(ink.actWash); cg.fillPath()
            cg.saveGState()
            cg.addPath(roundedPath(r.insetBy(dx: 0.75, dy: 0.75), Radius.event - 0.75))
            cg.setStrokeColor(ink.ring); cg.setLineWidth(1.5); cg.setLineDash(phase: 0, lengths: [4.5, 3]); cg.strokePath()
            cg.restoreGState()
        } else {
            cg.addPath(shape); cg.setFillColor((c.stripe ?? c.fill).cg); cg.fillPath()
        }
        cg.addPath(shape); cg.clip()
        if !style.draft {
            if c.stripe != nil { stripes(cg, r, color: c.fill.cg) }
            if let o = c.outline {
                cg.addPath(roundedPath(r.insetBy(dx: 0.5, dy: 0.5), Radius.event - 0.5)); cg.setStrokeColor(o.cg); cg.setLineWidth(1); cg.strokePath()
            }
            // Bar: 3 pt, inset 3 pt from top, bottom and left.
            let bar = CGRect(x: r.minX + 3, y: r.minY + 3, width: 3, height: max(0, r.height - 6))
            cg.addPath(roundedPath(bar, Radius.bar)); cg.setFillColor(c.bar.cg.copy(alpha: c.barAlpha) ?? c.bar.cg); cg.fillPath()
        }

        // Text.
        let title = e.title.isEmpty ? (style.draft || e.id.isEmpty ? "New event" : "(No title)") : e.title
        let titleColor = style.draft ? ink.fg : c.title.cg, timeColor = style.draft ? ink.fg2 : c.time.cg
        let strike = c.strike && !style.draft
        let plan = BlockText.plan(height: Double(r.height), width: Double(r.width), isShort: style.isShort)
        let x = r.minX + 10
        let lh = lineHeight
        let timeText: String? = switch plan.time {
        case .range: TextCache.range(fmt, start, end)
        case .start: TextCache.time(fmt, minutes: start)
        case .none: nil
        }
        if plan.lines == .one {
            let right = r.maxX - 5
            let top = plan.centered ? r.minY + (r.height - lh) / 2 : r.minY + 3
            let tw = timeText.map { TextCache.line($0, .time).width } ?? 0
            let titleMax = max(1, right - x - (tw > 0 ? tw + 4 : 0))
            let drawn = truncated(cg, title, .title, x: x, top: top, box: lh, color: titleColor, maxWidth: titleMax, strike: strike, clipped: true)
            if let t = timeText { text(cg, t, .time, x: x + drawn + 4, top: top, box: lh, color: timeColor, strike: strike) }
        } else {
            let w = max(1, r.maxX - 7 - x)
            let top = r.minY + (plan.compact ? 2 : 4)
            let lines = wrapped(cg, title, .title, x: x, top: top, width: w, maxLines: plan.maxTitleLines, lineHeight: lh, color: titleColor,
                                strike: strike, hyphenate: plan.hyphenate)
            let y = top + CGFloat(lines) * lh + (plan.compact ? 0 : 1)
            if let t = timeText {
                if plan.narrow { text(cg, t, .time, x: x, top: y, box: lh, color: timeColor, strike: strike) }
                else { truncated(cg, t, .time, x: x, top: y, box: lh, color: timeColor, maxWidth: w, strike: strike) }
            }
        }
    }
}
