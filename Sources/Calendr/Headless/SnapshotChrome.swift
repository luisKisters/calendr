import AppKit
import CalendrKit

/// Snapshot states of the CHROME area. `SnapshotStates.apply` falls through to this for names it does not know.
@MainActor
enum SnapshotChrome {
    /// Puts the model into the named state. Returns false for names this area does not define.
    static func apply(_ state: String, _ m: AppModel) -> Bool {
        switch state {
        case "command-menu": m.openPalette(.all)
        case "command-typed": m.openPalette(.all); m.setPaletteQuery("stat")
        case "go-to-date": m.openPalette(.goTo); m.setPaletteQuery("next fri")
        case "search-results": m.openPalette(.search); m.setPaletteQuery("calculus")
        case "search-empty": m.openPalette(.search); m.setPaletteQuery("Quokka")
        case "teammate-picker": m.openPalette(.meet)
        case "meet-with": m.openPalette(.meet); m.setPaletteQuery("ma")
        case "teammate-overlay":
            if let t = m.store.teammates.first(where: { $0.name == "Maya Sterling" }) { m.toggleMate(t) }
        case "toast":
            // The mockup's toast scene: the undo pill after moving Piano lesson to Thu 13:00.
            if let e = m.layout.timed[3].first(where: { $0.event.title == "Piano lesson" })?.event {
                m.showToast(m.undoToastText(old: e, new: e), undo: true)
            }
        case "settings-hand-height": m.settings.hourHeight = 72; m.overlay = .settings
        case "light-command-menu": m.settings.appearance = .light; m.openPalette(.all)
        case "light-settings": m.settings.appearance = .light; m.overlay = .settings
        default: return false
        }
        return true
    }
}
