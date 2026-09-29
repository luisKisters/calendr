import AppKit
import SwiftUI
import CalendrKit

/// Drives the real window: real key events through `NSApp.sendEvent` (so the same local monitor and text fields see them),
/// pointer gestures through the model entry points the grid gesture forwards to, a frame capture per action, assertions.
@MainActor
final class Driver {
    let model: AppModel
    let win: OffscreenWindow
    let recorder: VideoRecorder?
    let size: CGSize
    var failures: [String] = []
    var checks = 0
    var caption: String?
    var keyBadge: String?
    var cursor: CGPoint?
    var pressed = false
    var popover: CGImage?
    var menuBarLabel: String?
    /// While true, key and pointer helpers do not pump the run loop, so an animation they start is captured frame by frame by `animate`.
    var live = false
    /// Frames captured by the last `animate` (a check that motion really was sampled).
    private(set) var lastAnimateFrames = 0
    private var eventNumber = 1
    private var lastFrame: CGImage?

    init(model: AppModel, size: CGSize, recorder: VideoRecorder?) {
        self.model = model
        self.size = size
        self.recorder = recorder
        win = OffscreenWindow(RootView().environment(model), size: size, dark: true)
        KeyRouter.shared.install(model: model)
        win.settle(8)
    }

    // MARK: Frames

    func settle(_ turns: Int = 5) { win.settle(turns) }

    /// Captures the window (with overlays) and writes it `hold` seconds long.
    func frame(hold: Double = 0, scale: CGFloat = 2) {
        guard let recorder else { return }
        settle(2)
        guard let raw = win.image(scale: scale) else { return }
        let o = FrameComposer.Overlay(caption: caption, keys: keyBadge, cursor: cursor, pressed: pressed, popover: popover, menuBarLabel: menuBarLabel)
        if let img = FrameComposer.compose(window: raw, size: size, overlay: o) {
            lastFrame = img
            recorder.append(img, hold: max(1, Int((hold * Double(recorder.fps)).rounded())))
        }
    }

    /// Runs `body` (a key press, a click, a model call) and records `seconds` of real time while SwiftUI animates. Frames are captured
    /// back to back and placed on the 30 fps timeline by their wall-clock timestamps, so the video plays the motion at true speed.
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
        var frames: [(img: CGImage, t: Double)] = []
        defer { lastAnimateFrames = frames.count }
        repeat {
            RunLoop.main.run(until: Date().addingTimeInterval(0.001))
            win.host.layoutSubtreeIfNeeded()
            let t = Date().timeIntervalSince(t0)
            guard let raw = win.image(scale: 1) else { continue }
            let o = FrameComposer.Overlay(caption: caption, keys: keyBadge, cursor: cursor, pressed: pressed, popover: popover, menuBarLabel: menuBarLabel)
            if let img = FrameComposer.compose(window: raw, size: size, overlay: o) { frames.append((img, t)) }
        } while Date().timeIntervalSince(t0) < seconds
        let fps = Double(recorder.fps)
        for (i, f) in frames.enumerated() {
            let start = Int((f.t * fps).rounded())
            let end = i + 1 < frames.count ? Int((frames[i + 1].t * fps).rounded()) : max(start + 1, Int((seconds * fps).rounded()))
            recorder.append(f.img, hold: max(1, end - start))
            lastFrame = f.img
        }
        settle(2)
    }

    func hold(_ seconds: Double) {
        guard let recorder, let f = lastFrame else { return }
        recorder.append(f, hold: Int((seconds * Double(recorder.fps)).rounded()))
    }

    // MARK: Assertions

    func check(_ cond: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !cond() { failures.append(message); print("  FAIL: \(message)") }
    }

    func section(_ title: String) { caption = title; keyBadge = nil; print("== \(title)") }

    // MARK: Keys

    struct Key {
        var chars: String
        var code: UInt16 = 0
        var mods: NSEvent.ModifierFlags = []
        var label: String?
    }

    func press(_ k: Key, badge: Bool = true) {
        if badge { keyBadge = k.label ?? k.chars.uppercased() }
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
            if frames && (c == " " || text.count < 12) { frame() }
        }
        keyBadge = nil
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

    func click(grid: CGPoint, clickCount: Int = 1) {
        let p = windowPoint(fromGrid: grid)
        moveCursor(to: p, steps: 6)
        pressed = true
        model.gridMouseDown(grid, clickCount: clickCount)
        settle(2); frame()
        model.gridMouseUp(grid)
        pressed = false
        settle(3); frame()
    }

    /// A click whose consequences animate (selection ring, inspector sliding in): recorded in real time.
    func clickAnimated(grid: CGPoint, clickCount: Int = 1, seconds: Double = 0.55) {
        let p = windowPoint(fromGrid: grid)
        moveCursor(to: p, steps: 6)
        pressed = true
        model.gridMouseDown(grid, clickCount: clickCount)
        settle(2); frame()
        pressed = false
        play(seconds) { model.gridMouseUp(grid) }
    }

    func moveCursor(to p: CGPoint, steps: Int) {
        let from = cursor ?? CGPoint(x: p.x + 80, y: p.y + 60)
        for i in 1...max(1, steps) {
            let t = Double(i) / Double(max(1, steps))
            cursor = CGPoint(x: from.x + (p.x - from.x) * t, y: from.y + (p.y - from.y) * t)
            frame()
        }
    }

    /// Press, drag along a straight line of `steps` dragged events (a frame for each), release.
    func drag(from a: CGPoint, to b: CGPoint, steps: Int = 14) {
        moveCursor(to: windowPoint(fromGrid: a), steps: 8)
        pressed = true
        model.gridMouseDown(a)
        settle(2); frame()
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            cursor = windowPoint(fromGrid: p)
            model.gridMouseDragged(p)
            settle(2); frame()
        }
        pressed = false
        play(0.3) { model.gridMouseUp(b) }      // the drop settles in 120 ms
    }
}
