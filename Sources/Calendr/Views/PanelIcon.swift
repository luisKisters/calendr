import SwiftUI

/// The mockup's 16-unit stroke icons (app-views.js `I`), drawn from the same path data: 1.4 stroke, round caps and joins.
struct PanelIcon: View {
    enum Name {
        case clock, repeats, pin, users, video, help, calendar, notes, trash, x, plus, lock, down, arrow
    }
    let name: Name
    var size: CGFloat?
    var color: Color = Theme.fg3

    var body: some View {
        Canvas { ctx, sz in
            let k = sz.width / 16
            ctx.stroke(Self.path(name).applying(CGAffineTransform(scaleX: k, y: k)), with: .color(color),
                       style: StrokeStyle(lineWidth: 1.4 * k, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size ?? Self.design(name), height: size ?? Self.design(name))
    }

    /// The size the icon is drawn at in the mockup.
    static func design(_ n: Name) -> CGFloat {
        switch n {
        case .x, .plus, .lock, .down, .arrow: 12
        default: 14
        }
    }

    nonisolated(unsafe) private static var cache: [Name: Path] = [:]
    static func path(_ n: Name) -> Path {
        if let p = cache[n] { return p }
        var p = Path()
        switch n {
        case .clock: circle(&p, 8, 8, 5.8); svg(&p, "M8 4.8V8l2.2 1.4")
        case .repeats: svg(&p, "M2.6 7.4a5.4 5.4 0 0 1 9.6-2.6M13.4 8.6a5.4 5.4 0 0 1-9.6 2.6M12.4 2v3h-3M3.6 14v-3h3")
        case .pin: svg(&p, "M8 14s4.4-3.9 4.4-7.4a4.4 4.4 0 0 0-8.8 0C3.6 10.1 8 14 8 14z"); circle(&p, 8, 6.6, 1.5)
        case .users: circle(&p, 6, 5.6, 2.4); svg(&p, "M1.8 13c.3-2.3 2-3.6 4.2-3.6s3.9 1.3 4.2 3.6M10.6 3.4a2.4 2.4 0 0 1 0 4.4M12.2 9.8c1.2.5 1.9 1.6 2.1 3.2")
        case .video: p.addRoundedRect(in: CGRect(x: 1.6, y: 4, width: 9, height: 8), cornerSize: CGSize(width: 1.8, height: 1.8)); svg(&p, "m10.6 7 3.8-2v6l-3.8-2")
        case .help: circle(&p, 8, 8, 6); svg(&p, "M6.2 6.2a1.9 1.9 0 0 1 3.7.5c0 1.3-1.9 1.6-1.9 2.9M8 11.6h.01")
        case .calendar: p.addRoundedRect(in: CGRect(x: 2, y: 3, width: 12, height: 11), cornerSize: CGSize(width: 2.2, height: 2.2)); svg(&p, "M2 6.6h12M5.2 1.8v2.4M10.8 1.8v2.4")
        case .notes: svg(&p, "M2.6 4h10.8M2.6 8h10.8M2.6 12h6.4")
        case .trash: svg(&p, "M2.8 4.4h10.4M6.4 4.4V3a.8.8 0 0 1 .8-.8h1.6a.8.8 0 0 1 .8.8v1.4M4.2 4.4l.6 8a1.2 1.2 0 0 0 1.2 1.1h4a1.2 1.2 0 0 0 1.2-1.1l.6-8")
        case .x: svg(&p, "m4 4 8 8M12 4l-8 8")
        case .plus: svg(&p, "M8 3.2v9.6M3.2 8h9.6")
        case .lock: p.addRoundedRect(in: CGRect(x: 3.4, y: 7, width: 9.2, height: 6.6), cornerSize: CGSize(width: 1.6, height: 1.6)); svg(&p, "M5.4 7V5.2a2.6 2.6 0 0 1 5.2 0V7")
        case .down: svg(&p, "M4 6.2 8 10l4-3.8")
        case .arrow: svg(&p, "M3 8h10M9.4 4.4 13 8l-3.6 3.6")
        }
        cache[n] = p
        return p
    }

    private static func circle(_ p: inout Path, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
        p.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }

    /// SVG path data: M L H V C S A Z, absolute and relative.
    static func svg(_ p: inout Path, _ d: String) {
        var nums: [CGFloat] = [], cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero, lastCtrl: CGPoint?
        var tokens: [Any] = []
        var buf = ""
        func flush() { if let v = Double(buf) { tokens.append(CGFloat(v)) }; buf = "" }
        for ch in d {
            if ch.isLetter && ch != "e" { flush(); tokens.append(ch) }
            else if ch == " " || ch == "," { flush() }
            else if ch == "-" && !buf.isEmpty && buf.last != "e" { flush(); buf = "-" }
            else if ch == "." && buf.contains(".") { flush(); buf = "." }
            else { buf.append(ch) }
        }
        flush()
        func run() {
            let rel = cmd.isLowercase
            let o = rel ? cur : .zero
            func pt(_ i: Int) -> CGPoint { CGPoint(x: o.x + nums[i], y: o.y + nums[i + 1]) }
            switch cmd.uppercased().first! {
            case "M":
                guard nums.count >= 2 else { return }
                cur = pt(0); start = cur; p.move(to: cur); nums.removeFirst(2); cmd = rel ? "l" : "L"; lastCtrl = nil
            case "L":
                guard nums.count >= 2 else { return }
                cur = pt(0); p.addLine(to: cur); nums.removeFirst(2); lastCtrl = nil
            case "H":
                guard nums.count >= 1 else { return }
                cur = CGPoint(x: (rel ? cur.x : 0) + nums[0], y: cur.y); p.addLine(to: cur); nums.removeFirst(); lastCtrl = nil
            case "V":
                guard nums.count >= 1 else { return }
                cur = CGPoint(x: cur.x, y: (rel ? cur.y : 0) + nums[0]); p.addLine(to: cur); nums.removeFirst(); lastCtrl = nil
            case "C":
                guard nums.count >= 6 else { return }
                let c1 = pt(0), c2 = pt(2), e = pt(4)
                p.addCurve(to: e, control1: c1, control2: c2); cur = e; lastCtrl = c2; nums.removeFirst(6)
            case "S":
                guard nums.count >= 4 else { return }
                let c1 = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = pt(0), e = pt(2)
                p.addCurve(to: e, control1: c1, control2: c2); cur = e; lastCtrl = c2; nums.removeFirst(4)
            case "A":
                guard nums.count >= 7 else { return }
                let e = CGPoint(x: o.x + nums[5], y: o.y + nums[6])
                arc(&p, from: cur, to: e, r: nums[0], large: nums[3] != 0, sweep: nums[4] != 0)
                cur = e; lastCtrl = nil; nums.removeFirst(7)
            default: nums.removeAll()
            }
        }
        for t in tokens {
            if let c = t as? Character {
                while !nums.isEmpty { let n = nums.count; run(); if nums.count == n { break } }
                cmd = c
                if c == "z" || c == "Z" { p.closeSubpath(); cur = start; lastCtrl = nil }
            } else if let v = t as? CGFloat {
                nums.append(v)
            }
        }
        while !nums.isEmpty { let n = nums.count; run(); if nums.count == n { break } }
    }

    /// Circular SVG arc (rx == ry, no rotation) from endpoint form.
    private static func arc(_ p: inout Path, from a: CGPoint, to b: CGPoint, r: CGFloat, large: Bool, sweep: Bool) {
        let dx = (b.x - a.x) / 2, dy = (b.y - a.y) / 2
        let d2 = dx * dx + dy * dy
        guard d2 > 0 else { return }
        let rr = max(r, sqrt(d2))
        let h = sqrt(max(0, rr * rr - d2)) * (large == sweep ? -1 : 1)
        let len = sqrt(d2)
        let c = CGPoint(x: (a.x + b.x) / 2 - h * dy / len, y: (a.y + b.y) / 2 + h * dx / len)
        let a0 = atan2(a.y - c.y, a.x - c.x), a1 = atan2(b.y - c.y, b.x - c.x)
        // y points down, so SVG's positive sweep is clockwise on screen, which is Path's `clockwise: false`.
        p.addArc(center: c, radius: rr, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: !sweep)
    }
}
