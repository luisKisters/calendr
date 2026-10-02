import Foundation

/// v3 view state of the CHROME area (CenterView toolbar, SidebarView, Overlays, Components, KeyRouter, CalendrKit/Commands and Shortcuts). Stored on `AppModel.chromeState`; the area owns this file and grows the struct.
struct ChromeV3State: Equatable {
    /// What the command menu's one field is for. Every mode but `.all` shows a crumb; Backspace on an empty field returns to `.all`.
    enum PaletteMode: Equatable { case all, goTo, search, meet }
    var paletteMode = PaletteMode.all
    var paletteQuery = "" { didSet { if paletteQuery != oldValue { paletteIndex = 0 } } }
    var paletteIndex = 0
    /// The command menu's rows for the inputs they were built from. A reference, so filling it inside a view body is not a
    /// state change (hovering a row re-renders the menu and must not rank every event again).
    let paletteCache = PaletteCache()

    static func == (a: ChromeV3State, b: ChromeV3State) -> Bool {
        a.paletteMode == b.paletteMode && a.paletteQuery == b.paletteQuery && a.paletteIndex == b.paletteIndex
    }
}

final class PaletteCache {
    struct Key: Equatable {
        var mode: ChromeV3State.PaletteMode
        var query: String
        var hasSelection: Bool
        var layoutGeneration: Int
        var searchText: String
        var searchHits: Int
        var teammates: [String]
        var shown: [String]
        var now: Date
    }
    var key: Key?
    var rows: [PaletteRow] = []
    private(set) var builds = 0

    func rows(for key: Key, build: () -> [PaletteRow]) -> [PaletteRow] {
        if key != self.key { rows = build(); self.key = key; builds += 1 }
        return rows
    }
}
