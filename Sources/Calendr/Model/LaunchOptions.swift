import Foundation
import CalendrKit

struct LaunchOptions {
    var demo = false
    var now: Date?
    var snapshot: String?
    var out: String?
    var walkthrough = false
    /// `--walkthrough <tour>`: nil (or "e2e") is the end-to-end tour scripts/verify.sh runs; "v4-a" ... are the v4 feature tours.
    var tour: String?
    /// The demo data: the design/mockup-v4 week with its clock (Sun 4 Oct 2026 15:10) and 46 pt hours. `--fixture v4` is accepted as an alias of `--demo`.
    var fixture = DemoFixture.v4
    var record: String?
    var perf = false
    var size = CGSize(width: 1440, height: 900)
    var freezeClock = false
    var scale: CGFloat = 2
    /// Real app: print process-start-to-first-window-content time and quit (used by scripts/verify.sh).
    var printLaunch = false

    var isHeadless: Bool { snapshot != nil || walkthrough || perf }
    /// The PR E tours and Google snapshots: a `CompositeStore` over the demo store, ready for the demo Google account.
    var googleDemo: Bool { tour?.hasPrefix("v4-e") == true || (snapshot.map(SnapshotServices.googleStates.contains) ?? false) }

    static func parse(_ args: [String]) -> LaunchOptions {
        var o = LaunchOptions()
        var i = 1
        func value() -> String? { i += 1; return i < args.count ? args[i] : nil }
        while i < args.count {
            switch args[i] {
            case "--demo": o.demo = true
            case "--now": o.now = value().flatMap(parseNow)
            case "--snapshot": o.snapshot = value(); o.demo = true; o.freezeClock = true
            case "--out": o.out = value()
            case "--walkthrough":
                o.walkthrough = true; o.demo = true; o.freezeClock = true
                if i + 1 < args.count, !args[i + 1].hasPrefix("-") { o.tour = value() }
            case "--fixture": o.demo = true; o.fixture = value().flatMap(DemoFixture.init(rawValue:)) ?? .v4
            case "--record": o.record = value()
            case "--perf": o.perf = true; o.demo = true; o.freezeClock = true; o.fixture = .v3
            case "--freeze-clock": o.freezeClock = true
            case "--print-launch": o.printLaunch = true
            case "--scale": o.scale = value().flatMap { Double($0) }.map { CGFloat($0) } ?? 2
            case "--size":
                if let v = value()?.split(separator: "x").compactMap({ Double($0) }), v.count == 2 { o.size = CGSize(width: v[0], height: v[1]) }
            default: break
            }
            i += 1
        }
        if o.demo && o.now == nil { o.now = o.fixture == .v4 ? DemoDataV4.now : DemoData.defaultNow }
        return o
    }

    /// "2026-09-29T11:48" interpreted in Europe/Berlin (the demo zone); also accepts full ISO 8601 with offset.
    static func parseNow(_ s: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        let parts = s.split(whereSeparator: { "-T: ".contains($0) }).compactMap { Int($0) }
        guard parts.count >= 3 else { return nil }
        return DemoData.math.date(year: parts[0], month: parts[1], day: parts[2], hour: parts.count > 3 ? parts[3] : 0, minute: parts.count > 4 ? parts[4] : 0)
    }
}

extension DemoData {
    static var defaultNow: Date { math.date(year: 2026, month: 9, day: 29, hour: 11, minute: 48) }
}
