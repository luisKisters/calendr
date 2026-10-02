import AppKit
import Carbon.HIToolbox

/// The system-wide Control-Command-K that opens the menu bar item's menu from any app.
/// A Carbon hot key needs no Accessibility permission. Registered by the app delegate only, so headless runs never get it.
@MainActor
enum MenuBarHotKey {
    private static var hotKey: EventHotKeyRef?
    private static var handler: EventHandlerRef?

    static func register() {
        guard hotKey == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { _ = MenuBarControl.open() } }
            return noErr
        }, 1, &spec, nil, &handler)
        let id = EventHotKeyID(signature: OSType(0x434C_4452), id: 1)   // "CLDR"
        RegisterEventHotKey(UInt32(kVK_ANSI_K), UInt32(cmdKey | controlKey), id, GetApplicationEventTarget(), 0, &hotKey)
    }

    static func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
    }
}
