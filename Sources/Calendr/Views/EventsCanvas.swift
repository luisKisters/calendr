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
    let now: Date
    let selectedID: String?
    let movingID: String?
    let preview: AppModel.DragPreview?
    let fmt: Fmt
    let styles: (CalendarEvent, Bool, Bool, Bool, Bool) -> EventStyle     // (event, dark, selected, faded, overlapping)
    let ghost: (EventPalette, String, String)?

    var body: some View {
        let g = geometry
        Canvas(opaque: false, rendersAsynchronously: false) { ctx, size in
            let t0 = CFAbsoluteTimeGetCurrent(); defer { if ProcessInfo.processInfo.environment["CALENDR_PROF"] != nil { print(String(format: "canvas %.1f ms (%d events)", (CFAbsoluteTimeGetCurrent() - t0) * 1000, events.count)) } }
            ctx.withCGContext { cg in
                for p in events {
                    let e = p.event
                    let rect = g.rect(for: p)
                    let style = styles(e, dark, e.id == selectedID, e.id == movingID, p.placement.columns > 1)
                    EventPainter.draw(cg, p: p, rect: rect, style: style, fmt: fmt)
                }
                if let pv = preview, let (pal, title, range) = ghost {
                    let y = CGFloat(g.yPos(pv.startMinute))
                    let h = max(11, CGFloat(g.yPos(pv.endMinute)) - y - 3)
                    let rect = CGRect(x: CGFloat(pv.dayIndex) * CGFloat(g.dayWidth) + g.leftInset, y: y, width: CGFloat(g.dayWidth) - g.leftInset - g.rightInset, height: h)
                    EventPainter.drawGhost(cg, rect: rect, palette: pal, ink: EventPainter.Ink.of(dark), title: title, range: range)
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
    enum Kind: Int { case title, time, pill, pillTime, pillPri, mini, dow, header, badge, label11, chipTime, dayNum, hour, micro }
    struct Key: Hashable { var text: String; var kind: Int }
    private static var lines: [Key: (CTLine, CGFloat, CGFloat, CGFloat)] = [:]   // line, width, ascent, descent
    private static var frames: [Key: [(CTLine, CGFloat)]] = [:]

    static func mono(_ size: CGFloat, _ w: NSFont.Weight = .regular) -> NSFont {
        // Tabular figures are part of SF Mono already; the monospaced design is the machine voice.
        NSFont.monospacedSystemFont(ofSize: size, weight: w)
    }

    static func font(_ k: Kind) -> CTFont {
        switch k {
        case .title: return NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        case .time: return mono(10.5)
        case .pill: return NSFont.systemFont(ofSize: 11, weight: .medium)
        case .pillTime: return mono(10)
        case .pillPri: return mono(9.5, .semibold)
        case .mini: return NSFont.systemFont(ofSize: 12)
        case .dow: return NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        case .header: return NSFont.systemFont(ofSize: 14)
        case .badge: return mono(14, .medium)
        case .label11: return NSFont.systemFont(ofSize: 11, weight: .medium)
        case .chipTime: return mono(10)
        case .dayNum: return mono(12, .medium)
        case .hour: return mono(10.5)
        case .micro: return NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        }
    }

    private static var cuts: [Key: CTLine] = [:]
    private static var splits: [String: (priority: String?, text: String)] = [:]
    static func taskParts(_ title: String) -> (priority: String?, text: String) {
        if let c = splits[title] { return c }
        let r = TaskTitle.split(title)
        if splits.count > 6000 { splits.removeAll() }
        splits[title] = r
        return r
    }
    private static var wraps: [Key: [(CTLine, CGFloat, CGFloat)]] = [:]
    /// Cached line breaking for event titles (typesetting per frame was measurable).
    static func wrapped(_ text: String, width: CGFloat, maxLines: Int) -> [(line: CTLine, ascent: CGFloat, descent: CGFloat)] {
        let key = Key(text: text + "\u{2}\(Int(width.rounded(.down)))\u{2}\(maxLines)", kind: Kind.title.rawValue)
        if let c = wraps[key] { return c.map { ($0.0, $0.1, $0.2) } }
        let attr = NSAttributedString(string: text, attributes: [.font: font(.title), NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true])
        let ts = CTTypesetterCreateWithAttributedString(attr)
        var out: [(CTLine, CGFloat, CGFloat)] = []
        var start = 0
        let len = (text as NSString).length
        while start < len && out.count < maxLines {
            let count = CTTypesetterSuggestLineBreak(ts, start, Double(width))
            let line = CTTypesetterCreateLine(ts, CFRange(location: start, length: max(1, count)))
            var asc: CGFloat = 0, desc: CGFloat = 0, lead: CGFloat = 0
            _ = CTLineGetTypographicBounds(line, &asc, &desc, &lead)
            out.append((line, asc, desc))
            start += max(1, count)
        }
        if wraps.count > 4000 { wraps.removeAll() }
        wraps[key] = out
        return out.map { ($0.0, $0.1, $0.2) }
    }
    private static var ranges: [Int: String] = [:]
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
    @MainActor
    static func text(_ cg: CGContext, _ s: String, _ kind: TextCache.Kind, x: CGFloat, top: CGFloat, box: CGFloat = 14, color: CGColor, strike: Bool = false, kern: CGFloat = 0) -> CGFloat {
        let l = TextCache.line(s, kind)
        let baseline = top + (box - (l.ascent + l.descent)) / 2 + l.ascent
        cg.saveGState()
        cg.setFillColor(color)
        cg.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        cg.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(l.line, cg)
        if strike {
            cg.setStrokeColor(color); cg.setLineWidth(1)
            let y = baseline - l.ascent * 0.32
            cg.move(to: CGPoint(x: x, y: y)); cg.addLine(to: CGPoint(x: x + l.width, y: y)); cg.strokePath()
        }
        cg.restoreGState()
        return l.width
    }

    /// Like `text` but ends with an ellipsis when wider than `maxWidth` (returns the drawn width).
    @MainActor
    static func truncated(_ cg: CGContext, _ s: String, _ kind: TextCache.Kind, x: CGFloat, top: CGFloat, box: CGFloat = 14, color: CGColor, maxWidth: CGFloat, strike: Bool = false) -> CGFloat {
        let l = TextCache.line(s, kind)
        if l.width <= maxWidth { return text(cg, s, kind, x: x, top: top, box: box, color: color, strike: strike) }
        guard let cut = TextCache.truncated(s, kind, width: maxWidth) else { return 0 }
        let baseline = top + (box - (l.ascent + l.descent)) / 2 + l.ascent
        cg.saveGState()
        cg.setFillColor(color)
        cg.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        cg.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(cut, cg)
        let cw = CGFloat(CTLineGetTypographicBounds(cut, nil, nil, nil))
        if strike { cg.setStrokeColor(color); cg.setLineWidth(1); let y = baseline - l.ascent * 0.32; cg.move(to: CGPoint(x: x, y: y)); cg.addLine(to: CGPoint(x: x + cw, y: y)); cg.strokePath() }
        cg.restoreGState()
        return cw
    }

    /// Wraps `s` to at most `maxLines` lines of `lineHeight` inside `width`, returns the number of lines drawn.
    @MainActor
    static func wrapped(_ cg: CGContext, _ s: String, x: CGFloat, top: CGFloat, width: CGFloat, maxLines: Int, lineHeight: CGFloat, color: CGColor) -> Int {
        let l = TextCache.line(s, .title)
        if l.width <= width { _ = text(cg, s, .title, x: x, top: top, box: lineHeight, color: color); return 1 }
        let lines = TextCache.wrapped(s, width: width, maxLines: maxLines)
        cg.saveGState()
        cg.setFillColor(color)
        cg.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        for (n, ln) in lines.enumerated() {
            let baseline = top + CGFloat(n) * lineHeight + (lineHeight - (ln.ascent + ln.descent)) / 2 + ln.ascent
            cg.textPosition = CGPoint(x: x, y: baseline)
            CTLineDraw(ln.line, cg)
        }
        cg.restoreGState()
        return max(1, lines.count)
    }

    static func roundedPath(_ r: CGRect, _ radius: CGFloat) -> CGPath {
        CGPath(roundedRect: r, cornerWidth: min(radius, r.height / 2), cornerHeight: min(radius, r.height / 2), transform: nil)
    }

    /// CoreGraphics forms of the ink tokens for the current appearance.
    struct Ink {
        let dark: Bool
        let paper, haze, hazeDim, ink900, ink700, ink600, act, actWash, hairStrong, hair, live, actLift: CGColor
        private init(build dark: Bool) {
            self.dark = dark
            func c(_ d: String, _ l: String) -> CGColor { RGB(hex: dark ? d : l).cg }
            let paperRGB = RGB(hex: dark ? "#EDEBF5" : "#1C1A26").cg
            paper = c("#EDEBF5", "#1C1A26"); haze = c("#9A96AD", "#5F5B74"); hazeDim = c("#6B6880", "#8D89A1")
            ink900 = c("#0F0E14", "#FBFAF7"); ink700 = c("#1E1C28", "#EAE7EF"); ink600 = c("#2A2836", "#DCD8E6")
            act = c("#8B5CF6", "#7C3AED"); actLift = c("#A78BFA", "#6D28D9")
            actWash = act.copy(alpha: dark ? 0.20 : 0.14) ?? act
            hairStrong = paperRGB.copy(alpha: dark ? 0.14 : 0.16) ?? paperRGB
            hair = paperRGB.copy(alpha: dark ? 0.08 : 0.09) ?? paperRGB
            live = c("#FF453A", "#E5342A")
        }
        private static let darkInk = Ink(build: true)
        private static let lightInk = Ink(build: false)
        static func of(_ dark: Bool) -> Ink { dark ? darkInk : lightInk }
    }

    @MainActor
    static func draw(_ cg: CGContext, p: PlacedEvent, rect r: CGRect, style: EventStyle, fmt: Fmt) {
        let e = p.event
        let pal = style.palette
        let ink = Ink.of(style.isDark)
        let title = e.title.isEmpty ? "(No title)" : e.title
        cg.saveGState()
        defer { cg.restoreGState() }
        if style.faded { cg.setAlpha(0.35) } else if style.past { cg.setAlpha(style.isDark ? 0.55 : 0.5) }
        if e.kind == .task { capsule(cg, rect: r, style: style, ink: ink, title: title, time: TextCache.time(fmt, minutes: p.startMinute), done: style.done); return }
        let startS = TextCache.time(fmt, minutes: p.startMinute)
        let shape = roundedPath(r, Radius.event)
        if e.status == .declined { declined(cg, rect: r, style: style, ink: ink, title: title, range: "\(startS)\u{2013}\(TextCache.time(fmt, minutes: p.endMinute))", time: startS); return }

        cg.addPath(shape); cg.setFillColor((style.selected ? pal.hoverFillRGB : pal.fillRGB).cg); cg.fillPath()
        cg.saveGState()
        cg.addPath(shape); cg.clip()
        let barColor = pal.barRGB.cg
        if e.status == .tentative { stripes(cg, CGRect(x: r.minX, y: r.minY, width: 3, height: r.height), color: barColor) }
        else { cg.setFillColor(barColor); cg.fill(CGRect(x: r.minX, y: r.minY, width: 3, height: r.height)) }
        var textX = r.minX + 10
        if let b = style.secondaryBarCG {
            cg.setFillColor(b); cg.fill(CGRect(x: r.minX + 3, y: r.minY, width: 3, height: r.height))
            textX = r.minX + 13
        }
        let textW = r.maxX - 4 - textX
        if r.height >= 40 {
            let lines = wrapped(cg, title, x: textX, top: r.minY + 4, width: max(1, textW), maxLines: 2, lineHeight: 14, color: ink.paper)
            _ = text(cg, TextCache.range(fmt, p.startMinute, p.endMinute), .time, x: textX, top: r.minY + 4 + CGFloat(lines) * 14, box: 13, color: ink.haze)
        } else {
            let top = r.minY + max(0, (r.height - 14) / 2)
            let w = truncated(cg, title, .title, x: textX, top: top, color: ink.paper, maxWidth: textW)
            if textW - w > 44 { _ = text(cg, startS, .time, x: textX + w + 6, top: top, color: ink.haze) }
        }
        cg.restoreGState()
    }

    static func stripes(_ cg: CGContext, _ r: CGRect, color: CGColor) {
        cg.saveGState()
        cg.clip(to: r)
        cg.setStrokeColor(color); cg.setLineWidth(2.8)
        var x = r.minX - r.height
        while x < r.maxX + r.height {
            cg.move(to: CGPoint(x: x, y: r.maxY)); cg.addLine(to: CGPoint(x: x + r.height, y: r.minY))
            x += 4 * 1.4142
        }
        cg.strokePath()
        cg.restoreGState()
    }

    /// Checkbox circle rect inside a capsule (also used for hit testing).
    static func checkboxRect(in r: CGRect) -> CGRect { CGRect(x: r.minX + 3, y: r.midY - 6.5, width: 13, height: 13) }

    static func checkbox(_ cg: CGContext, _ c: CGRect, ink: Ink, done: Bool) {
        if done {
            cg.setFillColor(ink.act); cg.fillEllipse(in: c)
            cg.setStrokeColor(CGColor(gray: 1, alpha: 1)); cg.setLineWidth(1.6); cg.setLineCap(.round); cg.setLineJoin(.round)
            cg.move(to: CGPoint(x: c.minX + 3.4, y: c.midY + 0.2)); cg.addLine(to: CGPoint(x: c.minX + 5.7, y: c.midY + 2.6)); cg.addLine(to: CGPoint(x: c.minX + 9.6, y: c.midY - 2.4))
            cg.strokePath()
        } else {
            cg.setStrokeColor(ink.hazeDim); cg.setLineWidth(1.5); cg.strokeEllipse(in: c.insetBy(dx: 0.75, dy: 0.75))
        }
    }

    /// Task capsule: ink-700 pill with a checkbox, title, optional priority and time.
    @MainActor
    static func capsule(_ cg: CGContext, rect r: CGRect, style: EventStyle, ink: Ink, title: String, time: String, done: Bool) {
        let shape = roundedPath(r, r.height / 2)
        if style.overlapping {
            cg.addPath(roundedPath(r.insetBy(dx: -1, dy: -1), r.height / 2 + 1)); cg.setFillColor(ink.ink900); cg.fillPath()
        }
        cg.addPath(shape); cg.setFillColor(style.selected ? ink.ink600 : ink.ink700); cg.fillPath()
        cg.addPath(roundedPath(r.insetBy(dx: 0.5, dy: 0.5), r.height / 2)); cg.setStrokeColor(ink.hairStrong); cg.setLineWidth(1); cg.strokePath()
        checkbox(cg, checkboxRect(in: r), ink: ink, done: done)
        guard r.width >= 40 else { return }
        let parts = TextCache.taskParts(title)
        var right = r.maxX - 8
        if r.width >= 150 { let w = TextCache.line(time, .pillTime).width; _ = text(cg, time, .pillTime, x: right - w, top: r.minY + (r.height - 12) / 2, box: 12, color: ink.haze); right -= w + 5 }
        if r.width >= 96, let pr = parts.priority { let w = TextCache.line(pr, .pillPri).width; _ = text(cg, pr, .pillPri, x: right - w, top: r.minY + (r.height - 12) / 2, box: 12, color: ink.hazeDim); right -= w + 5 }
        let x = r.minX + 21
        let top = r.minY + (r.height - 13) / 2
        _ = truncated(cg, parts.text, .pill, x: x, top: top, box: 13, color: done ? ink.hazeDim : ink.paper, maxWidth: max(1, right - x), strike: done)
    }

    @MainActor
    static func declined(_ cg: CGContext, rect r: CGRect, style: EventStyle, ink: Ink, title: String, range: String, time: String) {
        let shape = roundedPath(r.insetBy(dx: 0.5, dy: 0.5), Radius.event)
        cg.saveGState()
        cg.addPath(shape); cg.setStrokeColor(style.palette.barRGB.cg.copy(alpha: 0.75) ?? style.palette.barRGB.cg); cg.setLineWidth(1); cg.setLineDash(phase: 0, lengths: [4, 3]); cg.strokePath()
        cg.restoreGState()
        cg.saveGState()
        cg.addPath(roundedPath(r, Radius.event)); cg.clip()
        if r.height >= 40 {
            _ = wrappedStrike(cg, title, x: r.minX + 10, top: r.minY + 4, width: r.width - 14, color: ink.haze)
            _ = text(cg, range, .time, x: r.minX + 10, top: r.minY + 18, box: 13, color: ink.haze, strike: true)
        } else {
            let top = r.minY + max(0, (r.height - 14) / 2)
            let w = truncated(cg, title, .title, x: r.minX + 10, top: top, color: ink.haze, maxWidth: r.width - 14, strike: true)
            if r.width - 14 - w > 44 { _ = text(cg, time, .time, x: r.minX + 10 + w + 6, top: top, color: ink.haze, strike: true) }
        }
        cg.restoreGState()
    }

    @MainActor
    static func wrappedStrike(_ cg: CGContext, _ s: String, x: CGFloat, top: CGFloat, width: CGFloat, color: CGColor) -> Int {
        truncated(cg, s, .title, x: x, top: top, color: color, maxWidth: width, strike: true) > 0 ? 1 : 0
    }

    @MainActor
    static func drawGhost(_ cg: CGContext, rect r: CGRect, palette pal: EventPalette, ink: Ink, title: String, range: String) {
        cg.saveGState()
        defer { cg.restoreGState() }
        let shape = roundedPath(r, Radius.event)
        cg.addPath(shape); cg.setFillColor(ink.actWash); cg.fillPath()
        cg.addPath(roundedPath(r.insetBy(dx: 0.75, dy: 0.75), Radius.event)); cg.setStrokeColor(ink.act); cg.setLineWidth(1.5); cg.strokePath()
        cg.addPath(shape); cg.clip()
        _ = text(cg, title, .title, x: r.minX + 10, top: r.minY + 4, color: ink.paper)
        _ = text(cg, range, .time, x: r.minX + 10, top: r.minY + 18, box: 13, color: ink.haze)
    }
}

extension EventStyle {
    var secondaryBarCG: CGColor? { secondaryBarRGB?.cg }
}
