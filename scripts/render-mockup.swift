// Usage: swift scripts/render-mockup.swift [name ...]
// Renders the mockup scene of every design/states.json entry that has a `mockup` (or only the named entries) into
// <mockupDir>/shots/<shot>.png at 1440x900: the 1440x928 `.desk` of <mockupDir>/index.html minus its fake 28 pt menu bar.
// Each scene loads `index.html#<mockup>` in a fresh non-persistent web view, so the mockup starts from its LOCKED picks
// (`&key=value` in `mockup` adds extra picks). The page reads the font from ../../Sources, so file access is granted to the repo root.
// An optional `js` step runs after the fonts are ready (for example to open a popover: `document.querySelector('[data-pop=evmore]').click()`).
import AppKit
import WebKit

setvbuf(stdout, nil, _IONBF, 0)

// `swift scripts/render-mockup.swift` passes a relative #filePath: resolve it against the working directory.
let root = URL(fileURLWithPath: #filePath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
    .absoluteURL.standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent()
let statesURL = root.appendingPathComponent("design/states.json")
guard let data = try? Data(contentsOf: statesURL),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let states = json["states"] as? [String: [String: Any]],
      let mockupDir = json["mockupDir"] as? String else { print("design/states.json needs mockupDir and states"); exit(2) }

struct Job { var shot: String; var hash: String; var js: String? }
let only = Set(CommandLine.arguments.dropFirst())
var seen = Set<String>()
var jobs: [Job] = []
for name in states.keys.sorted() {
    guard let s = states[name], let m = s["mockup"] as? String else { continue }
    if !only.isEmpty && !only.contains(name) { continue }
    let shot = (s["shot"] as? String) ?? m.replacingOccurrences(of: "&", with: "-").replacingOccurrences(of: "=", with: "-")
    if seen.insert(shot).inserted { jobs.append(Job(shot: shot, hash: m, js: s["js"] as? String)) }
}
if jobs.isEmpty { print("no mockup scenes to render"); exit(0) }

let page = root.appendingPathComponent(mockupDir).appendingPathComponent("index.html")
let shots = root.appendingPathComponent(mockupDir).appendingPathComponent("shots")
try? FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true)

let W = 1440.0, H = 928.0, bar = 28.0
/// Shows the desk alone, unscaled, at the top left (the picker rail and the fit-to-stage transform go away).
let isolate = """
(() => {
  const st = document.createElement('style');
  st.textContent = '#picker{display:none!important}#frame{left:0!important;top:0!important;transform:none!important;border-radius:0!important;box-shadow:none!important}#tt{display:none!important}*{transition:none!important;animation:none!important;caret-color:transparent!important}';
  document.head.appendChild(st);
  window.fit = () => {};
})();
"""

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

@MainActor
final class Renderer: NSObject, WKNavigationDelegate {
    var jobs: [Job]
    var web: WKWebView!
    var win: NSWindow!
    var failed = 0
    init(jobs: [Job]) { self.jobs = jobs }

    func next() {
        guard let job = jobs.first else { exit(failed == 0 ? 0 : 1) }
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()       // empty localStorage: the LOCKED picks apply
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: W, height: H), configuration: cfg)
        web.navigationDelegate = self
        win = NSWindow(contentRect: web.frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.isReleasedWhenClosed = false          // the renderer owns it; close() must not free it
        win.contentView = web
        var c = URLComponents(url: page, resolvingAgainstBaseURL: false)!
        c.fragment = job.hash
        web.loadFileURL(c.url!, allowingReadAccessTo: root)
    }

    nonisolated func webView(_ w: WKWebView, didFinish _: WKNavigation!) {
        MainActor.assumeIsolated { self.loaded() }
    }
    nonisolated func webView(_ w: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        MainActor.assumeIsolated { print("load failed: \(error)"); self.failed += 1; self.done() }
    }

    func loaded() {
        let job = jobs[0]
        let script = isolate + "\nawait document.fonts.ready;\n" + (job.js.map { "\($0);\n" } ?? "") +
            "await new Promise(r => setTimeout(r, 100));   // no requestAnimationFrame: the window is never on screen\nreturn document.querySelector('.desk') ? 'ok' : 'no desk';"
        web.callAsyncJavaScript(script, arguments: [:], in: nil, in: .page) { result in
            MainActor.assumeIsolated {
                if case .failure(let e) = result { print("\(job.shot): js failed: \(e)"); self.failed += 1; self.done(); return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.snap() }
            }
        }
    }

    func snap() {
        let job = jobs[0]
        let c = WKSnapshotConfiguration()
        c.rect = NSRect(x: 0, y: bar, width: W, height: H - bar)
        c.snapshotWidth = NSNumber(value: W)
        web.takeSnapshot(with: c) { img, err in
            MainActor.assumeIsolated {
                guard let img, let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    print("\(job.shot): snapshot failed: \(String(describing: err))"); self.failed += 1; self.done(); return
                }
                // Exactly 1440x900 pixels, whatever the backing scale of the offscreen view.
                let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H - bar), bitsPerSample: 8, samplesPerPixel: 4,
                                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                NSGraphicsContext.current?.cgContext.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H - bar))
                NSGraphicsContext.restoreGraphicsState()
                let out = shots.appendingPathComponent("\(job.shot).png")
                do {
                    try rep.representation(using: .png, properties: [:])!.write(to: out)
                    print("wrote \(out.path.replacingOccurrences(of: root.path + "/", with: ""))")
                } catch { print("\(job.shot): \(error)"); self.failed += 1 }
                self.done()
            }
        }
    }

    func done() {
        jobs.removeFirst()
        win?.close()
        next()
    }
}

MainActor.assumeIsolated {
    let r = Renderer(jobs: jobs)
    objc_setAssociatedObject(app, "renderer", r, .OBJC_ASSOCIATION_RETAIN)
    DispatchQueue.main.async { MainActor.assumeIsolated { r.next() } }
}
app.run()
