import AppKit
import CalendrKit

/// One local key monitor for the whole app. It resolves single-key shortcuts only when no text field is focused
/// (`ShortcutResolver`), and drives the palettes (arrows/return) while they are open.
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
        // Palette navigation.
        if let o = model.overlay, !input.command {
            switch (o, input.keyCode) {
            case (.command, 125): model.commandIndex = min(CommandRegistry.flat(model.commandSections).count - 1, model.commandIndex + 1); return true
            case (.command, 126): model.commandIndex = max(0, model.commandIndex - 1); return true
            case (.teammate, 125): model.teammateIndex = min(model.filteredTeammates(model.teammateQuery).count - 1, model.teammateIndex + 1); return true
            case (.teammate, 126): model.teammateIndex = max(0, model.teammateIndex - 1); return true
            default: break
            }
        }
        if model.overlay == nil, !model.meetQuery.isEmpty, !input.command {
            let n = model.filteredTeammates(model.meetQuery).count
            if input.keyCode == 125 { model.meetIndex = min(max(0, n - 1), model.meetIndex + 1); return true }
            if input.keyCode == 126 { model.meetIndex = max(0, model.meetIndex - 1); return true }
        }
        let typing = textFocused(in: event.window ?? NSApp.keyWindow)
        guard let action = ShortcutResolver.resolve(input, textFocused: typing) else { return false }
        // While a modal is open, only the modal-level actions apply.
        if model.overlay != nil {
            switch action {
            case .escape, .commandMenu, .settings, .showShortcuts: break
            default: if !typing { return true } else { return false }
            }
        }
        if action == .escape, typing, let w = event.window ?? NSApp.keyWindow {
            // Esc while typing: leave the field first, then unwind one layer.
            if model.overlay == nil && (model.selectedEventID != nil || !model.searchText.isEmpty || !model.meetQuery.isEmpty) {
                model.blurTick += 1
                w.makeFirstResponder(nil)
                if !model.meetQuery.isEmpty { model.meetQuery = "" }
                return true
            }
        }
        return model.handle(action)
    }
}
