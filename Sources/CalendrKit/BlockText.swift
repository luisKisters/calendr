import Foundation

/// How the text of one timed event block is laid out (design/mockup-v4/index.html `grid()` :1270-1278 and the `.ev` rules :181-200).
/// Pure numbers in, a plan out; the painter only follows it. The title always starts at the top of the block.
public struct BlockTextPlan: Equatable, Sendable {
    public enum Lines: Equatable, Sendable {
        /// Title and time on one row (`.ev.one`): blocks under 30 pt.
        case one
        /// Title lines, then the time below them.
        case stacked
    }
    public enum Time: Equatable, Sendable {
        /// "14:00–16:00"
        case range
        /// "14:00"
        case start
        case none
    }
    public var lines: Lines
    /// 1 or 2 title lines (a one-line block has 1).
    public var maxTitleLines: Int
    public var time: Time
    /// The one row sits in the middle of the block (`.ev.one.xs`, under 22 pt).
    public var centered: Bool
    /// 2 pt instead of 4 pt above the title and no gap above the time (`.ev.cmp`, under 40 pt).
    public var compact: Bool
    /// Narrow (`.ev.narrow`): the title stays on one line with an ellipsis and never splits inside a word.
    public var narrow: Bool
    /// Long words may break at syllables (`hyphens: auto`): only a two-line title of a block that is not narrow.
    public var hyphenate: Bool { lines == .stacked && maxTitleLines > 1 && !narrow }

    public init(lines: Lines, maxTitleLines: Int, time: Time, centered: Bool, compact: Bool, narrow: Bool) {
        self.lines = lines; self.maxTitleLines = maxTitleLines; self.time = time; self.centered = centered; self.compact = compact; self.narrow = narrow
    }
}

public enum BlockText {
    /// Under this height (pt) a block is one row.
    public static let oneRow = 30.0
    /// Under this height the one row is centred.
    public static let centredRow = 22.0
    /// Under this height the title keeps to one line.
    public static let oneTitleLine = 52.0
    /// Under this height the padding is compact.
    public static let compactBelow = 40.0
    /// Narrower than this (pt) the title is one line with an ellipsis.
    public static let narrowBelow = 56.0
    /// The time shows as a range only when the block width minus its padding (17 pt) leaves this much.
    public static let rangeWidth = 62.0
    public static let horizontalPadding = 17.0

    /// `height` and `width` are the drawn block in points; `isShort` is an event of 15 minutes or less.
    public static func plan(height: Double, width: Double, isShort: Bool) -> BlockTextPlan {
        let one = height < oneRow
        let narrow = width < narrowBelow
        var time: BlockTextPlan.Time = isShort || one || width - horizontalPadding < rangeWidth ? .start : .range
        // A narrow one-line block keeps its title; its position already says the time.
        if one && narrow { time = .none }
        return BlockTextPlan(lines: one ? .one : .stacked,
                             maxTitleLines: one || narrow || height < oneTitleLine ? 1 : 2,
                             time: time,
                             centered: one && height < centredRow,
                             compact: !one && height < compactBelow,
                             narrow: narrow)
    }
}
