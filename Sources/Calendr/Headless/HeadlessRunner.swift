import AppKit
import SwiftUI
import CalendrKit

@MainActor
enum HeadlessRunner {
    static var keep: [AnyObject] = []

    static func start(_ o: LaunchOptions) {
        setvbuf(stdout, nil, _IOLBF, 0)
        UserDefaults.standard.set(0, forKey: "AppleFontSmoothing")
        let app = NSApplication.shared
        app.setActivationPolicy(o.walkthrough ? .regular : .accessory)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                var code: Int32 = 0
                if let s = o.snapshot { code = runSnapshot(s, o) }
                else if o.perf { code = Perf.run(o) }
                else if o.walkthrough { code = Walkthrough.run(o) }
                fflush(stdout)
                exit(code)
            }
        }
        app.run()
    }

    static func makeModel(_ o: LaunchOptions, dense: Bool = false) -> AppModel {
        AppModel(store: DemoStore(dense: dense), options: o, persist: false)
    }

    static func runSnapshot(_ state: String, _ o: LaunchOptions) -> Int32 {
        Motion.forcedInstant = true
        let model = state == "empty-access" ? AppModel(store: DemoStore(authorization: .notDetermined), options: o, persist: false) : makeModel(o)
        guard let out = o.out else { print("--snapshot needs --out"); return 2 }
        KeyRouter.shared.install(model: model)
        if let code = SnapshotMenuBar.run(state, model, o, out: out) { return code }
        let w = OffscreenWindow(RootView().environment(model), size: o.size, dark: true)
        keep.append(w)
        w.settle(6)
        model.gridGeometry = model.gridGeometry
        guard SnapshotStates.apply(state, to: model) else { print("unknown state \(state)"); return 2 }
        if state == "light-week" || state == "month-light" { w.setDark(false) }
        w.settle(8)
        let ok = w.writePNG(to: out, scale: o.scale)
        print(ok ? "wrote \(out)" : "failed \(out)")
        return ok ? 0 : 1
    }
}

