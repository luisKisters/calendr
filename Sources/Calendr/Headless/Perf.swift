import AppKit
import SwiftUI
import CalendrKit
import Darwin

@MainActor
enum Perf {
    static func processStart() -> Date {
        var kp = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        sysctl(&mib, 4, &kp, &size, nil, 0)
        let tv = kp.kp_proc.p_un.__p_starttime
        return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000)
    }

    static func percentile(_ v: [Double], _ p: Double) -> Double {
        let s = v.sorted()
        return s[min(s.count - 1, Int(Double(s.count) * p))]
    }

    static func run(_ o: LaunchOptions) -> Int32 {
        Motion.forcedInstant = true      // layout + render cost is measured with animations off; animated cost is reported separately
        let t0 = processStart()
        print(String(format: "  (perf started %.0f ms after process start)", Date().timeIntervalSince(t0) * 1000))
        // Cold launch: normal demo data, model + window + first frame, measured from process start.
        let coldModel = HeadlessRunner.makeModel(o)
        let tModel = Date()
        print(String(format: "  (model built after %.0f ms)", tModel.timeIntervalSince(t0) * 1000))
        let coldWindow = OffscreenWindow(RootView().environment(coldModel), size: o.size, dark: true, settle: false)
        RunLoop.main.run(until: Date())
        coldWindow.host.layoutSubtreeIfNeeded()
        coldWindow.host.display()
        let cold = Date().timeIntervalSince(t0) * 1000
        print(String(format: "cold launch (demo data, offscreen window, process start to first drawn frame): %.0f ms (model ready at %.0f ms)", cold, tModel.timeIntervalSince(t0) * 1000))
        coldWindow.close()

        // Navigation: ~300+ events per week (dense demo store, 120 weeks).
        let model = HeadlessRunner.makeModel(o, dense: true)
        let w = OffscreenWindow(RootView().environment(model), size: o.size, dark: true)
        w.settle(6)
        _ = w.image(scale: 1)

        // Events per visible week
        var perWeek: [Int] = []
        var times: [Double] = []
        var modelTimes: [Double] = []
        var updateTimes: [Double] = [], layoutTimes: [Double] = [], drawTimes: [Double] = []
        func nav(_ forward: Bool) {
            let a = CFAbsoluteTimeGetCurrent()
            if forward { model.next() } else { model.previous() }
            let b = CFAbsoluteTimeGetCurrent()
            // Let SwiftUI apply the observation change, then layout + draw synchronously.
            RunLoop.main.run(until: Date())
            let b2 = CFAbsoluteTimeGetCurrent()
            w.host.layoutSubtreeIfNeeded()
            let b3 = CFAbsoluteTimeGetCurrent()
            w.host.displayIfNeeded()
            if ProcessInfo.processInfo.environment["CALENDR_PERF_DIRTY"] == nil { w.host.display() }
            let c = CFAbsoluteTimeGetCurrent()
            updateTimes.append((b2 - b) * 1000); layoutTimes.append((b3 - b2) * 1000); drawTimes.append((c - b3) * 1000)
            modelTimes.append((b - a) * 1000)
            times.append((c - a) * 1000)
            perWeek.append(model.layout.timedCount + model.layout.allDayEvents.count)
        }
        for _ in 0..<3 { nav(true) }
        for _ in 0..<3 { nav(false) }
        times.removeAll(); modelTimes.removeAll(); perWeek.removeAll(); updateTimes.removeAll(); layoutTimes.removeAll(); drawTimes.removeAll()
        let rounds = Int(ProcessInfo.processInfo.environment["CALENDR_PERF_ROUNDS"] ?? "") ?? 1
        for _ in 0..<rounds { for _ in 0..<50 { nav(true) }; for _ in 0..<50 { nav(false) } }
        if ProcessInfo.processInfo.environment["CALENDR_PERF_TRACE"] != nil { print(times.prefix(24).map { String(format: "%.1f/%.1f", $0, modelTimes[times.firstIndex(of: $0)!]) }.joined(separator: " ")) }
        print(String(format: "events per week visible: min %d, median %d, max %d", perWeek.min() ?? 0, Int(percentile(perWeek.map(Double.init), 0.5)), perWeek.max() ?? 0))
        print(String(format: "week navigation x100 (50 forward, 50 back), layout+render: p50 %.1f ms, p95 %.1f ms, max %.1f ms", percentile(times, 0.5), percentile(times, 0.95), times.max() ?? 0))
        print(String(format: "  of which model reload (fetch + layout): p50 %.2f ms, p95 %.2f ms", percentile(modelTimes, 0.5), percentile(modelTimes, 0.95)))

        print(String(format: "  breakdown p50: runloop/update %.1f ms, layout %.1f ms, draw %.1f ms", percentile(updateTimes, 0.5), percentile(layoutTimes, 0.5), percentile(drawTimes, 0.5)))
        let weekTimes = times
        // Same navigation with animations on (the slide starts at each step; cost of the work done per step, not of the 180 ms itself).
        Motion.forcedInstant = false
        var animated: [Double] = []
        for _ in 0..<3 { nav(true) }
        times.removeAll()
        for _ in 0..<20 { nav(true) }
        for _ in 0..<20 { nav(false) }
        animated = times
        Motion.forcedInstant = true
        for _ in 0..<20 { nav(true) }; for _ in 0..<20 { nav(false) }
        print(String(format: "week navigation with animations on (x40): p50 %.1f ms, p95 %.1f ms", percentile(animated, 0.5), percentile(animated, 0.95)))
        times = weekTimes
        // Month view too.
        model.setMode(.month)
        w.settle(4)
        var mt: [Double] = [], mModel: [Double] = [], mUpdate: [Double] = [], mDraw: [Double] = []
        for _ in 0..<3 { model.next(); RunLoop.main.run(until: Date()); w.host.layoutSubtreeIfNeeded(); w.host.display() }   // warm-up like the week loop
        for i in 0..<40 {
            let a = CFAbsoluteTimeGetCurrent()
            if i < 20 { model.next() } else { model.previous() }
            let b = CFAbsoluteTimeGetCurrent()
            RunLoop.main.run(until: Date())
            let c = CFAbsoluteTimeGetCurrent()
            w.host.layoutSubtreeIfNeeded(); w.host.display()
            let d = CFAbsoluteTimeGetCurrent()
            mt.append((d - a) * 1000); mModel.append((b - a) * 1000); mUpdate.append((c - b) * 1000); mDraw.append((d - c) * 1000)
        }
        print(String(format: "month navigation x40: p50 %.1f ms, p95 %.1f ms", percentile(mt, 0.5), percentile(mt, 0.95)))
        print(String(format: "  month breakdown p50: model %.1f ms, runloop/update %.1f ms, layout+draw %.1f ms", percentile(mModel, 0.5), percentile(mUpdate, 0.5), percentile(mDraw, 0.5)))
        let ok = percentile(times, 0.95) < 16.7 && percentile(mt, 0.95) < 16.7 && cold < 500
        print(ok ? "PERF OK (budget: p95 < 16.7 ms per navigation, cold < 500 ms)" : "PERF OVER BUDGET (p95 < 16.7 ms per navigation, cold < 500 ms)")
        if ProcessInfo.processInfo.environment["CALENDR_PERF_STRICT"] != nil && !ok { return 1 }
        return 0
    }
}
