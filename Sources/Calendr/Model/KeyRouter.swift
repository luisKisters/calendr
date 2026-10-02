import AppKit
import CalendrKit

/// One local key monitor for the whole app. It resolves single-key shortcuts only when no text field is focused
/// (`ShortcutResolver`), drives the command menu (arrows, Backspace out of a mode) while it is open, and keeps keys
/// away from the grid while a sheet is up.
@MainActor
final class KeyRouter {
    static let shared = KeyRouter()
    private var monitor: Any?
    private weak var model: AppModel?

    func install(model: AppModel) {
        self.model = model
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let model = self.model else { return event }
            return MainActor.assumeIsolated { self.handle(event, model: model) ? nil : event }
        }
    }

    func textFocused(in window: NSWindow?) -> Bool {
        guard let r = window?.firstResponder else { return false }
        return r is NSText || (r as? NSView)?.isKind(of: NSTextView.self) == true
    }

    func handle(_ event: NSEvent, model: AppModel) -> Bool {
        if event.window is NSPanel { return false }
        let mods = event.modifierFlags
        let input = KeyInput(characters: event.charactersIgnoringModifiers ?? "", keyCode: event.keyCode,
                             command: mods.contains(.command), option: mods.contains(.option),
                             control: mods.contains(.control), shift: mods.contains(.shift))
        let typing = textFocused(in: event.window ?? NSApp.keyWindow)

        if model.overlay == .command, !input.command {
            switch input.keyCode {
            case ShortcutResolver.keyDown: model.movePaletteSelection(1); return true
            case ShortcutResolver.keyUp: model.movePaletteSelection(-1); return true
            case ShortcutResolver.keyDelete: if model.paletteBack() { return true }
            case 48: return true      // Tab stays in the field
            default:
                if input.control && input.characters == "n" { model.movePaletteSelection(1); return true }
                if input.control && input.characters == "p" { model.movePaletteSelection(-1); return true }
            }
        }

        guard let action = ShortcutResolver.resolve(input, textFocused: typing) else {
            // A sheet keeps every other key from the grid underneath. Outside a field a bare character has no other
            // meaning: swallow it rather than let it beep.
            return (isSheet(model.overlay) || Self.isBareCharacter(input)) && !typing
        }
        switch model.overlay {
        case .command?:
            if action == .escape || action == .commandMenu || action == .settings { break }
            return typing ? false : true
        case .shortcuts?:
            if action == .showShortcuts || action == .editTitle { model.overlay = nil; return true }
            if action != .escape && action != .commandMenu && action != .settings { return true }
        case .settings?:
            if action == .settings { model.overlay = nil; return true }
            if action != .escape && action != .commandMenu && action != .showShortcuts { return true }
        case .deleteRecurring?:
            if action != .escape { return true }
        case nil: break
        }
        if action == .escape, typing, model.overlay == nil, let w = event.window ?? NSApp.keyWindow {
            // Esc in a field of the event being created discards it at once; anywhere else the first Esc only leaves
            // the field and the next one peels the layer.
            guard model.draftEventID != nil else { w.makeFirstResponder(nil); return true }
            model.blurTick += 1
            w.makeFirstResponder(nil)
        }
        return model.handle(action)
    }

    /// One printable character without Command, Control or Option (arrows and function keys arrive as private-use characters).
    static func isBareCharacter(_ k: KeyInput) -> Bool {
        guard !k.command, !k.control, !k.option, k.characters.unicodeScalars.count == 1, let u = k.characters.unicodeScalars.first else { return false }
        return u.value >= 0x20 && u.value != 0x7F && !(0xF700...0xF8FF).contains(u.value)
    }

    private func isSheet(_ o: Overlay?) -> Bool {
        switch o { case .shortcuts?, .settings?, .deleteRecurring?: true; default: false }
    }
}
