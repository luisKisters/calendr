import SwiftUI

/// The mockup's stroke icons used by the command menu and the header (app-views.js `I`), drawn from the same path data
/// as `PanelIcon`: 16-unit box, 1.4 stroke, round caps and joins.
struct ChromeIcon: View {
    enum Name: Hashable {
        case plus, cal, left, right, side, moon, search, users, ret, trash, gear, clock, keys
    }
    let name: Name
    var size: CGFloat?
    var color: Color = Theme.fg3

    var body: some View {
        let s = size ?? Self.design(name)
        Canvas { ctx, sz in
            let k = sz.width / 16
            ctx.stroke(Self.path(name).applying(CGAffineTransform(scaleX: k, y: k)), with: .color(color),
                       style: StrokeStyle(lineWidth: 1.4 * k, lineCap: .round, lineJoin: .round))
        }
        .frame(width: s, height: s)
    }

    /// The size the icon is drawn at in the mockup.
    static func design(_ n: Name) -> CGFloat {
        switch n { case .plus, .ret: 12; default: 14 }
    }

    nonisolated(unsafe) private static var cache: [Name: Path] = [:]
    static func path(_ n: Name) -> Path {
        if let p = cache[n] { return p }
        var p = Path()
        switch n {
        case .plus: p = PanelIcon.path(.plus)
        case .cal: p = PanelIcon.path(.calendar)
        case .users: p = PanelIcon.path(.users)
        case .trash: p = PanelIcon.path(.trash)
        case .clock: p = PanelIcon.path(.clock)
        case .left: PanelIcon.svg(&p, "M10 3.5 5.5 8l4.5 4.5")
        case .right: PanelIcon.svg(&p, "M6 3.5 10.5 8 6 12.5")
        case .side:
            p.addRoundedRect(in: CGRect(x: 1.8, y: 2.8, width: 12.4, height: 10.4), cornerSize: CGSize(width: 2.2, height: 2.2))
            PanelIcon.svg(&p, "M6 2.8v10.4")
        case .moon: PanelIcon.svg(&p, "M13.2 9.6A5.6 5.6 0 0 1 6.4 2.8a5.6 5.6 0 1 0 6.8 6.8z")
        case .search:
            p.addEllipse(in: CGRect(x: 7 - 4.4, y: 7 - 4.4, width: 8.8, height: 8.8))
            PanelIcon.svg(&p, "m10.4 10.4 3.2 3.2")
        case .ret: PanelIcon.svg(&p, "M13 3v4a2 2 0 0 1-2 2H3.4M6 6.2 3.2 9 6 11.8")
        case .gear:
            p.addEllipse(in: CGRect(x: 8 - 2.1, y: 8 - 2.1, width: 4.2, height: 4.2))
            PanelIcon.svg(&p, "M8 1.8v1.6M8 12.6v1.6M1.8 8h1.6M12.6 8h1.6M3.6 3.6l1.15 1.15M11.25 11.25l1.15 1.15M12.4 3.6l-1.15 1.15M4.75 11.25 3.6 12.4")
        case .keys:
            p.addRoundedRect(in: CGRect(x: 1.6, y: 4, width: 12.8, height: 8), cornerSize: CGSize(width: 2, height: 2))
            PanelIcon.svg(&p, "M4.4 6.8h.01M7 6.8h.01M9.6 6.8h.01M11.8 6.8h.01M5 9.4h6")
        }
        cache[n] = p
        return p
    }
}
