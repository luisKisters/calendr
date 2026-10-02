import AppKit
import SwiftUI
import CalendrKit

/// Drives the real window: real key events through `NSApp.sendEvent` (so the same local monitor and text fields see them),
/// pointer gestures through the model entry points the grid gesture forwards to, a frame capture per action, assertions.
@MainActor
final class Driver {
    let model: AppModel
    let win: OffscreenWindow
    /// What the frames are taken from: the app window, or (for the menu bar segment) the menu bar composite.
    var source: OffscreenWindow
    let recorder: VideoRecorder?
    let size: CGSize
    /// Pixels per point of the recorded frames (the video is 2x so Glide can zoom in sharply).
    let scale: CGFloat
    var failures: [String] = []
    var checks = 0
    /// Cursor in window points, top-left origin. It is never drawn into the frames: it goes to `<file>.cursor.json` for Glide.
    var cursor = CGPoint(x: 1000, y: 40)
    /// While true, key and pointer helpers do not pump the run loop, so an animation they start is captured frame by frame by `animate`.
    var live = false
    /// Frames captured by the last `animate` (a check that motion really was sampled).
    private(set) var lastAnimateFrames = 0
    private var lastFrame: CGImage?

    struct Sample { var t: Double; var x: Double; var y: Double }
    struct Click { var t: Double; var x: Double; var y: Double; var double: Bool }
    struct Caption { var start: Double; var end: Double?; var text: String; var keys: [String] }
    private(set) var samples: [Sample] = []
    private(set) var clicks: [Click] = []
    private(set) var captions: [Caption] = []
    struct Zoom { var start: Double; var end: Double?; var x: Double; var y: Double }
    private(set) var zooms: [Zoom] = []

    init(model: AppModel, size: CGSize, recorder: VideoRecorder?) {
        self.model = model
        self.size = size
        self.recorder = recorder
        scale = recorder.map { CGFloat($0.width) / size.width } ?? 2
        win = OffscreenWindow(RootView().environment(model), size: size, dark: true)
        source = win
        KeyRouter.shared.install(model: model)
        win.settle(8)
    }

    // MARK: Timeline

    /// Seconds on the video timeline.
    var videoTime: Double { Double(recorder?.frameCount ?? 0) / Double(recorder?.fps ?? 30) }

    /// Writes `frames` copies of `img`, sampling the cursor on every written frame.
    private func emit(_ img: CGImage, frames: Int) {
        guard let recorder, frames > 0 else { return }
        let fps = Double(recorder.fps), f0 = recorder.frameCount
        for i in 0..<frames {
            samples.append(Sample(t: (Double(f0 + i) / fps * 1000).rounded(), x: Double(cursor.x / size.width), y: Double(cursor.y / size.height)))
        }
        recorder.append(img, hold: frames)
    }

    /// Starts a caption now (the previous one ends here, so captions never overlap).
    func say(_ text: String, keys: [String] = []) {
        endCaption()
        captions.append(Caption(start: videoTime, end: nil, text: text, keys: keys))
    }

    /// Starts a zoom region centred on a window point (Glide zooms in on it until `zoomOut`).
    func zoomIn(on p: CGPoint) {
        zoomOut()
        zooms.append(Zoom(start: videoTime, end: nil, x: Double(p.x / size.width), y: Double(p.y / size.height)))
    }

    func zoomOut() {
        if let i = zooms.indices.last, zooms[i].end == nil { zooms[i].end = videoTime }
    }

    func endCaption() {
        if let i = captions.indices.last, captions[i].end == nil { captions[i].end = max(videoTime, captions[i].start + 0.3) }
    }

    func writeTelemetry(to base: String) {
        endCaption(); zoomOut()
        let zs = zooms.compactMap { z -> [String: Any]? in
            guard let e = z.end, e > z.start else { return nil }
            return ["start": (z.start * 100).rounded() / 100, "end": (e * 100).rounded() / 100, "x": (z.x * 1000).rounded() / 1000, "y": (z.y * 1000).rounded() / 1000]
        }
        if let data = try? JSONSerialization.data(withJSONObject: zs, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: URL(fileURLWithPath: base + ".zoom.json")) }
        func n(_ v: Double) -> String { String(format: "%.5f", min(1, max(0, v))) }
        let sj = samples.map { "{\"t\":\(Int($0.t)),\"x\":\(n($0.x)),\"y\":\(n($0.y))}" }.joined(separator: ",")
        let cj = clicks.map { "{\"t\":\(Int($0.t)),\"x\":\(n($0.x)),\"y\":\(n($0.y)),\"button\":1,\"double\":\($0.double)}" }.joined(separator: ",")
        try? "{\"version\":1,\"samples\":[\(sj)],\"clicks\":[\(cj)]}".write(toFile: base + ".cursor.json", atomically: true, encoding: .utf8)
        let caps = captions.compactMap { c -> [String: Any]? in
            guard let e = c.end, e > c.start else { return nil }
            return ["start": (c.start * 1000).rounded() / 1000, "end": (e * 1000).rounded() / 1000, "text": c.text, "keys": c.keys]
        }
        if let data = try? JSONSerialization.data(withJSONObject: caps, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: URL(fileURLWithPath: base + ".captions.json")) }
    }

    // MARK: Frames

    func settle(_ turns: Int = 5) { source.settle(turns) }

    /// Captures the window (with overlays) and writes it `hold` seconds long (at least one frame).
    func frame(hold: Double = 0) {
        guard let recorder else { return }
        settle(2)
        guard let img = source.image(scale: scale) else { return }
        lastFrame = img
        emit(img, frames: max(1, Int((hold * Double(recorder.fps)).rounded())))
    }

    /// Runs `body` (a key press, a click, a model call) and records `seconds` of SwiftUI animation. Capturing a 2x frame takes longer than a
    /// 60 fps frame, so the Motion tokens are stretched by `Motion.timeScale` while recording and each capture is placed on the timeline at
    /// its wall-clock time divided by that factor: the video plays the motion at true speed with a frame for every 60 fps tick.
    func play(_ seconds: Double, _ body: () -> Void) {
        live = true
        body()
        live = false
        animate(seconds)
    }

    func animate(_ seconds: Double) {
        let t0 = Date()
        guard let recorder else {
            while Date().timeIntervalSince(t0) < seconds { RunLoop.main.run(until: Date().addingTimeInterval(0.005)) }
            return
        }
        let k = Motion.timeScale
        var frames: [(img: CGImage, t: Double)] = [], unchanged = 0
        defer { lastAnimateFrames = frames.count }
        repeat {
            RunLoop.main.run(until: Date().addingTimeInterval(0.001))
            source.host.layoutSubtreeIfNeeded()
            let t = Date().timeIntervalSince(t0) / k
            guard let img = source.image(scale: scale) else { continue }
            // Once the picture has stopped changing the animation is over: hold it for the rest of `seconds` instead of re-capturing.
            if let prev = frames.last?.img, Self.same(prev, img) { unchanged += 1 } else { unchanged = 0 }
            frames.append((img, t))
        } while Date().timeIntervalSince(t0) / k < seconds && unchanged < 4
        // The last frame sampled can be mid-animation: a spring stretched by `k` is still settling when `seconds` is up, and `hold()` repeats
        // whatever is captured here. Let it finish (until two captures match, at most another stretched `seconds`) and take that frame.
        var settled = frames.last?.img
        let cap = Date().addingTimeInterval(seconds * k)
        repeat {
            settle(4)
            guard let img = source.image(scale: scale) else { break }
            if let prev = settled, Self.same(prev, img) { break }
            settled = img
        } while unchanged < 4 && Date() < cap
        if let settled { frames.append((settled, seconds)) }
        let fps = Double(recorder.fps)
        var written = 0
        for (i, f) in frames.enumerated() {
            // Captures closer together than a frame collapse onto one tick; the later one wins.
            let end = i + 1 < frames.count ? Int((frames[i + 1].t * fps).rounded()) : max(written + 1, Int((seconds * fps).rounded()))
            if end > written { emit(f.img, frames: end - written); written = end }
            lastFrame = f.img
        }
        settle(2)
    }

    /// A 2x capture of a changing window takes up to ~400 ms (the material behind sheets is the slowest), far longer than a 60 fps tick.
    /// Recording stretches the Motion tokens by this factor so every tick of an animation gets its own capture.
    static let recordingTimeScale = 24.0

    static func same(_ a: CGImage, _ b: CGImage) -> Bool {
        guard let x = a.dataProvider?.data, let y = b.dataProvider?.data else { return false }
        return (x as Data) == (y as Data)
    }

    /// A gesture that is stepped by the driver (a drag, a gutter zoom, a scroll): `step` gets the eased progress for every video frame of
    /// `duration`, and each frame is captured after it.
    func gesture(_ duration: Double, _ step: (Double) -> Void) {
        let n = max(2, Int((duration * Double(recorder?.fps ?? 60)).rounded()))
        for i in 1...n {
            let t = Double(i) / Double(n)
            step(t * t * (3 - 2 * t))
            settle(1); frame()
        }
    }

    /// Re-captures the source for the frame the cursor is moving over (the menu bar highlight changed under it).
    func refreshFrame() {
        settle(1)
        if let img = source.image(scale: scale) { lastFrame = img }
    }

    func hold(_ seconds: Double) {
        guard let recorder else { return }
        if lastFrame == nil { frame() }
        if let f = lastFrame { emit(f, frames: Int((seconds * Double(recorder.fps)).rounded())) }
    }

    // MARK: Assertions

    func check(_ cond: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !cond() { failures.append(message); print("  FAIL: \(message)") }
    }

    func section(_ title: String) { print("== \(title)") }

    // MARK: Keys

    struct Key {
        var chars: String
        var code: UInt16 = 0
        var mods: NSEvent.ModifierFlags = []
        var label: String?
    }

    func press(_ k: Key, badge: Bool = true) {
        let t = ProcessInfo.processInfo.systemUptime
        let base = k.chars.lowercased()
        if let down = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: k.mods, timestamp: t, windowNumber: win.window.windowNumber,
                                       context: nil, characters: k.mods.contains(.shift) ? k.chars : base, charactersIgnoringModifiers: k.chars, isARepeat: false, keyCode: k.code) {
            NSApp.sendEvent(down)
        }
        if let up = NSEvent.keyEvent(with: .keyUp, location: .zero, modifierFlags: k.mods, timestamp: t + 0.01, windowNumber: win.window.windowNumber,
                                     context: nil, characters: base, charactersIgnoringModifiers: k.chars, isARepeat: false, keyCode: k.code) {
            NSApp.sendEvent(up)
        }
        if !live { settle(3) }
    }

    static let codes: [Character: UInt16] = ["a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
                                             "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
                                             "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
                                             "n": 45, "m": 46, ".": 47, " ": 49, "`": 50]

    /// Presses a printable key ("t", ".", "?" ...). Shift is inferred for "?".
    func key(_ c: Character, cmd: Bool = false, opt: Bool = false, ctrl: Bool = false, label: String? = nil) {
        var mods: NSEvent.ModifierFlags = []
        if cmd { mods.insert(.command) }
        if opt { mods.insert(.option) }
        if ctrl { mods.insert(.control) }
        var ch = c
        var code = Self.codes[Character(c.lowercased())] ?? 0
        if c == "?" { mods.insert(.shift); code = 44; ch = "?" }
        var l = label
        if l == nil {
            var s = ""
            if ctrl { s += "\u{2303} " }; if opt { s += "\u{2325} " }; if cmd { s += "\u{2318} " }
            s += c == "?" ? "?" : String(c).uppercased()
            l = s
        }
        press(Key(chars: String(ch), code: code, mods: mods, label: l))
    }

    func special(_ name: String) {
        switch name {
        case "return": press(Key(chars: "\r", code: 36, label: "\u{21A9}"))
        case "esc": press(Key(chars: "\u{1b}", code: 53, label: "esc"))
        case "delete": press(Key(chars: "\u{8}", code: 51, label: "\u{232B}"))
        case "left": press(Key(chars: "\u{F702}", code: 123, label: "\u{2190}"))
        case "right": press(Key(chars: "\u{F703}", code: 124, label: "\u{2192}"))
        case "down": press(Key(chars: "\u{F701}", code: 125, label: "\u{2193}"))
        case "up": press(Key(chars: "\u{F700}", code: 126, label: "\u{2191}"))
        default: break
        }
    }

    /// Types into whatever text field is focused, one real key event per character, capturing frames along the way.
    func type(_ text: String, frames: Bool = true) {
        for c in text {
            var mods: NSEvent.ModifierFlags = []
            if c.isUppercase { mods.insert(.shift) }
            let code = Self.codes[Character(c.lowercased())] ?? 0
            press(Key(chars: String(c), code: code, mods: mods, label: nil), badge: false)
            if frames { frame(hold: 1.0 / 16) }
        }
        frame()
    }

    // MARK: Mouse
    //
    // Synthesized mouse events cannot reach SwiftUI in an unattended session (the process can never become the active app,
    // e.g. while the screen is locked), so pointer gestures call the exact three functions the grid's DragGesture forwards to
    // (`gridMouseDown/Dragged/Up`) with points computed by the same geometry. Everything below the gesture layer is the real code path.

    func windowPoint(fromGrid g: CGPoint) -> CGPoint {
        let v = model.gridViewport
        return CGPoint(x: v.minX + Theme.gutterWidth + g.x, y: v.minY + g.y - model.gridScrollY)
    }

    /// Grid-space point for a day column and minute of day.
    func gridPoint(day: Int, minute: Double, xFraction: Double = 0.5) -> CGPoint {
        let g = model.gridGeometry
        return CGPoint(x: (Double(day) + xFraction) * g.dayWidth, y: g.yPos(Int(minute)) + (minute - Double(Int(minute))) * g.hourHeight / 60)
    }

    /// Eases the cursor to `p` over `duration` seconds (smoothstep), one written frame per step, like a hand moving to its target.
    func moveCursor(to p: CGPoint, duration: Double = 0.32, onStep: ((CGPoint) -> Void)? = nil) {
        guard let recorder else { cursor = p; return }
        if lastFrame == nil { frame() }
        let from = cursor
        let steps = max(1, Int((duration * Double(recorder.fps)).rounded()))
        for i in 1...steps {
            let t = Double(i) / Double(steps), e = t * t * (3 - 2 * t)
            cursor = CGPoint(x: from.x + (p.x - from.x) * e, y: from.y + (p.y - from.y) * e)
            onStep?(cursor)
            if let f = lastFrame { emit(f, frames: 1) }
        }
    }

    /// Records a click for Glide at the cursor, at the current video time.
    func recordClick(double: Bool = false) {
        clicks.append(Click(t: (videoTime * 1000).rounded(), x: Double(cursor.x / size.width), y: Double(cursor.y / size.height), double: double))
    }

    /// Moves to a window point and clicks it; `action` is what the click does (the model call the button's action makes).
    func click(at p: CGPoint, double: Bool = false, then action: () -> Void) {
        moveCursor(to: p)
        recordClick(double: double)
        play(0.3, action)
    }

    /// A click on the grid whose consequences animate (selection ring, the panel swapping): recorded in real time.
    func clickGrid(_ g: CGPoint, clickCount: Int = 1, seconds: Double = 0.55) {
        moveCursor(to: windowPoint(fromGrid: g))
        recordClick(double: clickCount > 1)
        model.gridMouseDown(g, clickCount: clickCount)
        settle(2); frame()
        play(seconds) { model.gridMouseUp(g) }
    }

    /// Press, drag along a straight line over `duration` seconds (a frame for each video tick), release.
    func drag(from a: CGPoint, to b: CGPoint, duration: Double = 0.5) {
        moveCursor(to: windowPoint(fromGrid: a))
        recordClick()
        model.gridMouseDown(a)
        settle(2); frame()
        gesture(duration) { e in
            let p = CGPoint(x: a.x + (b.x - a.x) * e, y: a.y + (b.y - a.y) * e)
            cursor = windowPoint(fromGrid: p)
            model.gridMouseDragged(p)
        }
        play(0.3) { model.gridMouseUp(b) }      // the drop settles in 120 ms
    }
}
