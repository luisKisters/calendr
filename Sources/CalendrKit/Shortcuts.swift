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
    case commandMenu, today, leftAlignToday, nextPeriod, previousPeriod
    case createEvent, meetWith, showTeammate, goToDate, showShortcuts, schedulingLink, addNotionDatabase
    case viewDay, viewWeek, viewMonth
    case toggleSidebar, toggleRightPanel, settings, menuBarCalendar, mainWindow
    case focusSearch, undo, refresh, deleteSelection, escape
}

public enum ShortcutResolver {
    public static let keyEscape: UInt16 = 53
    public static let keyDelete: UInt16 = 51
    public static let keyForwardDelete: UInt16 = 117
    public static let keyLeft: UInt16 = 123
    public static let keyRight: UInt16 = 124

    /// Maps a key press to an action. Command-modified shortcuts always fire; bare keys never fire while a text field is focused.
    public static func resolve(_ k: KeyInput, textFocused: Bool) -> ShortcutAction? {
        let c = k.characters.lowercased()
        if k.command {
            if k.control && !k.option { return c == "k" ? .menuBarCalendar : nil }
            if k.option { return nil }
            switch c {
            case "k": return .commandMenu
            case "/": return .toggleRightPanel
            case ",": return .settings
            case "1": return .mainWindow
            case "z": return k.shift ? nil : (textFocused ? nil : .undo)
            case "r": return .refresh
            case "f": return .focusSearch
            default: return nil
            }
        }
        if k.keyCode == keyEscape { return .escape }
        if textFocused { return nil }
        if k.control { return nil }
        if k.option { return c == "t" ? .leftAlignToday : nil }
        switch k.keyCode {
        case keyDelete, keyForwardDelete: return .deleteSelection
        case keyLeft: return .previousPeriod
        case keyRight: return .nextPeriod
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
        case "p": return .showTeammate
        case "f": return .meetWith
        case ".": return .goToDate
        case "?": return .showShortcuts
        case "/": return k.shift ? .showShortcuts : .focusSearch
        case "`": return .toggleSidebar
        case "s": return .schedulingLink
        case "o": return .addNotionDatabase
        default: return nil
        }
    }
}
