import Foundation

public struct KeyInput: Equatable, Sendable {
    /// `charactersIgnoringModifiers` (shift is kept, so "?" arrives as "?").
    public var characters: String
    public var keyCode: UInt16
    public var command: Bool, option: Bool, control: Bool, shift: Bool
    public init(characters: String, keyCode: UInt16 = 0, command: Bool = false, option: Bool = false, control: Bool = false, shift: Bool = false) {
        self.characters = characters; self.keyCode = keyCode; self.command = command; self.option = option; self.control = control; self.shift = shift
    }
}

public enum ShortcutAction: Equatable, Sendable {
    case commandMenu, today, nextPeriod, previousPeriod
    case createEvent, meetWith, goToDate, searchEvents, showShortcuts
    case viewDay, viewWeek, viewMonth
    case toggleSidebar, settings, menuBarCalendar, mainWindow
    case undo, refresh, deleteSelection, escape
    /// An arrow key: walks the selection with one, pages the period (left, right) without.
    case arrow(dx: Int, dy: Int)
    /// Option-arrow: moves the selected event by a day (dx) or 15 minutes (dy).
    case nudge(dx: Int, dy: Int)
    case selectNext, selectPrevious, editTitle
}

public enum ShortcutResolver {
    public static let keyEscape: UInt16 = 53
    public static let keyDelete: UInt16 = 51
    public static let keyForwardDelete: UInt16 = 117
    public static let keyLeft: UInt16 = 123
    public static let keyRight: UInt16 = 124
    public static let keyDown: UInt16 = 125
    public static let keyUp: UInt16 = 126
    public static let keyReturn: UInt16 = 36
    public static let keyEnter: UInt16 = 76
    public static let keyTab: UInt16 = 48

    static func arrow(_ code: UInt16) -> (dx: Int, dy: Int)? {
        switch code {
        case keyLeft: (-1, 0)
        case keyRight: (1, 0)
        case keyUp: (0, -1)
        case keyDown: (0, 1)
        default: nil
        }
    }

    /// Maps a key press to an action. Command-modified shortcuts always fire; bare keys never fire while a text field is focused.
    public static func resolve(_ k: KeyInput, textFocused: Bool) -> ShortcutAction? {
        let c = k.characters.lowercased()
        if k.command {
            if k.control && !k.option { return c == "k" ? .menuBarCalendar : nil }
            if k.option { return nil }
            switch c {
            case "k": return .commandMenu
            case ",": return .settings
            case "1": return .mainWindow
            case "\\": return .toggleSidebar
            case "z": return k.shift ? nil : (textFocused ? nil : .undo)
            case "r": return .refresh
            case "f": return .searchEvents
            default: return nil
            }
        }
        if k.keyCode == keyEscape { return .escape }
        if textFocused || k.control { return nil }
        if k.option { return arrow(k.keyCode).map { .nudge(dx: $0.dx, dy: $0.dy) } }
        if let a = arrow(k.keyCode) { return .arrow(dx: a.dx, dy: a.dy) }
        switch k.keyCode {
        case keyDelete, keyForwardDelete: return .deleteSelection
        case keyTab: return k.shift ? .selectPrevious : .selectNext
        case keyReturn, keyEnter: return .editTitle
        default: break
        }
        switch c {
        case "t": return .today
        case "j": return .nextPeriod
        case "k": return .previousPeriod
        case "c": return .createEvent
        case "d": return .viewDay
        case "w": return .viewWeek
        case "m": return .viewMonth
        case "f": return .meetWith
        case ".": return .goToDate
        case "?": return .showShortcuts
        case "/": return k.shift ? .showShortcuts : .searchEvents
        case "`": return .toggleSidebar
        default: return nil
        }
    }
}
