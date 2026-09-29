// Usage: swift render-svg.swift in.svg out.png size
// Renders an SVG (via WebKit, transparent background) to a PNG.
import AppKit
import WebKit

let args = CommandLine.arguments
guard args.count == 4, let size = Int(args[3]) else { print("usage: render-svg in.svg out.png size"); exit(2) }
let svg = try! String(contentsOfFile: args[1], encoding: .utf8)
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let web = WKWebView(frame: NSRect(x: 0, y: 0, width: size, height: size), configuration: WKWebViewConfiguration())
web.setValue(false, forKey: "drawsBackground")
let html = "<html><body style='margin:0;background:transparent'><div style='width:\(size)px;height:\(size)px'>" +
    svg.replacingOccurrences(of: "width=\"1024\" height=\"1024\"", with: "width=\"\(size)\" height=\"\(size)\"") +
    "</div></body></html>"

final class Nav: NSObject, WKNavigationDelegate {
    let size: Int
    let out: String
    init(size: Int, out: String) { self.size = size; self.out = out }
    func webView(_ w: WKWebView, didFinish _: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let c = WKSnapshotConfiguration()
            c.rect = NSRect(x: 0, y: 0, width: self.size, height: self.size)
            c.snapshotWidth = NSNumber(value: self.size)
            w.takeSnapshot(with: c) { img, err in
                guard let img, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    print("snapshot failed: \(String(describing: err))"); exit(1)
                }
                try! png.write(to: URL(fileURLWithPath: self.out))
                exit(0)
            }
        }
    }
}
let nav = Nav(size: size, out: args[2])
web.navigationDelegate = nav
let win = NSWindow(contentRect: web.frame, styleMask: .borderless, backing: .buffered, defer: false)
win.isOpaque = false
win.backgroundColor = .clear
win.contentView = web
web.loadHTMLString(html, baseURL: nil)
app.run()
