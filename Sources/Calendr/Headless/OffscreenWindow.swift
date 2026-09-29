import AppKit
import SwiftUI

/// A real (titled, full-size-content) window parked off screen. Everything the headless modes draw goes through
/// `cacheDisplay` on its frame view, so no screen recording permission is needed.
final class OffscreenNSWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    // The process cannot be activated without a login session; behave as the key window anyway so clicks and focus reach SwiftUI.
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class OffscreenWindow {
    let window: OffscreenNSWindow
    let host: FirstMouseHostingView<AnyView>
    private(set) var size: CGSize
    var drawTrafficLights = true

    init<V: View>(_ root: V, size: CGSize, dark: Bool = true, chrome: Bool = true, settle waits: Bool = true) {
        self.size = size
        drawTrafficLights = chrome
        let mask: NSWindow.StyleMask = chrome ? [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView] : [.borderless]
        window = OffscreenNSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: mask, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host = FirstMouseHostingView(rootView: AnyView(root))
        host.frame = NSRect(origin: .zero, size: size)
        window.contentView = host
        if chrome { WindowChrome.apply(to: window); window.minSize = NSSize(width: 100, height: 100) }
        window.setContentSize(size)
        window.setFrameOrigin(ProcessInfo.processInfo.environment["CALENDR_ONSCREEN"] != nil ? NSPoint(x: 40, y: 40) : NSPoint(x: -12000, y: -12000))
        if chrome { NSApp.activate(ignoringOtherApps: true) }
        window.makeKeyAndOrderFront(nil)
        if waits { settle() }
    }

    /// Lets SwiftUI process pending state changes (a few short run-loop turns).
    func settle(_ turns: Int = 4) {
        for _ in 0..<turns {
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
            host.layoutSubtreeIfNeeded()
        }
    }

    func resize(_ s: CGSize) {
        window.setContentSize(s)
        host.frame = NSRect(origin: .zero, size: s)
        settle()
    }

    func setDark(_ dark: Bool) { window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua) }

    /// Renders the whole window including the title bar controls.
    func image(scale: CGFloat = 2) -> CGImage? {
        host.layoutSubtreeIfNeeded()
        let target: NSView = window.contentView?.superview ?? host
        let bounds = target.bounds
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(bounds.width * scale), pixelsHigh: Int(bounds.height * scale),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = bounds.size
        target.cacheDisplay(in: bounds, to: rep)
        if drawTrafficLights, let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            // The window is never active offscreen, so AppKit draws the inactive gray dots. Paint the active ones.
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = ctx
            for (x, hex) in [(17.0, 0xec6765), (40.0, 0xf2ca44), (63.0, 0x65c466)] {
                NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1).setFill()
                NSBezierPath(ovalIn: NSRect(x: x - 7, y: bounds.height - 18 - 7, width: 14, height: 14)).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        return rep.cgImage
    }

    func writePNG(to path: String, scale: CGFloat = 2) -> Bool {
        guard let img = image(scale: scale) else { return false }
        let rep = NSBitmapImageRep(cgImage: img)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? data.write(to: url)) != nil
    }

    func close() { window.orderOut(nil) }
}
