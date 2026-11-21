import Foundation

/// How the text of one timed event block is laid out: the v11 rule (design/mockup-v11 app.js `evBlock`, rd.css round g
/// "type roles, event padding, clipping"; locked look R · R10). Pure numbers in, a plan out; the painter only follows it.
///
/// - Title and time sit on two lines only when the padding and both line boxes fit (`minTwo`, 34.5 pt) in the part of the block
///   that shows (up to the first later block drawn over it, mockup-v14) and the event is 45 minutes or longer. Otherwise the block
///   is one line (`.ev.one`): the time goes inline after the title, and only when the block is 120 pt wide or more (`notime`).
/// - A narrow block (44 to 66 pt, side by side in a crowded spot) that has room wraps its title over up to 3 lines and shows its
///   start time below (mockup-v14 "titles wrap"; "the time could still be shown"). Under 44 pt, or one line, it clips its title.
/// - A one-line block that has room for the padding above and below its line (21.5 pt) keeps the 3 pt top padding
///   (`tall1`); a shorter one centres its line, and the line box shrinks to the block, so no glyph is ever clipped.
/// - The title of a two-line block clamps to the lines that fit: `floor((h - 3 - 15 - 2) / 15.5)`, 1 or 2 (3 when narrow).
public struct BlockTextPlan: Equatable, Sendable {
    public enum Lines: Equatable, Sendable {
        /// Title and time on one line (`.ev.one`).
        case one
        /// Title lines, then the time below them.
        case stacked
    }
    public enum Time: Equatable, Sendable {
        /// "14:00–16:00"
        case range
        /// "14:00"
        case start
        /// "→ 16:00": the part of an event that began on an earlier day (`cont-top`).
        case until
        case none
    }
    public var lines: Lines
    /// 1 to 3 title lines (a one-line block has 1).
    public var maxTitleLines: Int
    public var time: Time
    /// A one-line block too short for its padding: the line is centred and its box is `min(lineHeight, height)`.
    public var centered: Bool
    /// A one-line block under 66 pt (`.ev.narrow` / `.ev.squeezed`): one title line cut at the edge, no time.
    public var narrow: Bool
    /// Thin (`.ev.thin`, under 30 pt): 2 pt after the bar instead of 6, and the title at the small size.
    public var thin: Bool
    /// Long words may break at syllables (`hyphens: auto`): only a two-line title of a block that is not narrow.
    public var hyphenate: Bool { lines == .stacked && maxTitleLines > 1 }

    public init(lines: Lines, maxTitleLines: Int, time: Time, centered: Bool, narrow: Bool, thin: Bool = false) {
        self.lines = lines; self.maxTitleLines = maxTitleLines; self.time = time; self.centered = centered; self.narrow = narrow; self.thin = thin
    }
}

public enum BlockText {
    // The locked numbers (readability.js `look()`: ft 12, fm 11, py 3; app.js GEO0 `one` 45).
    /// Top padding.
    public static let padTop = 3.0
    /// Padding after the bar and on the right.
    public static let padX = 6.0
    /// Event title line box (12 + 3.5).
    public static let titleLine = 15.5
    /// Event time line box (11 + 3).
    public static let timeLine = 14.0
    /// The time sits 1 pt below the title.
    public static let timeGap = 1.0
    /// Two lines need padding + both line boxes + 2 pt (`minTwo`).
    public static let minTwo = padTop + titleLine + timeLine + 2      // 34.5
    /// Events shorter than this (minutes) are one line (`G().one`).
    public static let oneLineMinutes = 45
    /// A one-line block at least this tall keeps its top padding (`tall1`: line + 2 × padding).
    public static let tallOne = titleLine + 2 * padTop              // 21.5
    /// One-line blocks narrower than this hide the time (`notime`).
    public static let inlineTimeWidth = 120.0
    /// Narrower than this the time is the start only.
    public static let rangeWidth = 84.0
    public static let thinBelow = 30.0
    /// Narrower than this a block is squeezed: one clipped title line and no time when it is one line, else up to `narrowLines`.
    public static let squeezedBelow = 66.0
    /// Title lines of a narrow two-line block (mockup-v14 "Title lines in a narrow event: 3").
    public static let narrowLines = 3
    /// Narrower than this a block keeps one clipped title line even when tall: a wrapped title would be one letter a line.
    public static let wrapFrom = 44.0

    /// - Parameters:
    ///   - height, width: the drawn block in points.
    ///   - minutes: its drawn span (a short item spans 22 minutes).
    ///   - isShort: an event of 15 minutes or less (shows only its start).
    ///   - visibleHeight: the part that shows, when a later block is drawn over it (`Placement.visibleMinutes` in points).
    ///   - continuesFromPrevious: the event began on an earlier day.
    public static func plan(height: Double, width: Double, minutes: Int, isShort: Bool = false, visibleHeight: Double? = nil,
                            continuesFromPrevious: Bool = false) -> BlockTextPlan {
        let h = min(height, visibleHeight ?? height)
        let one = minutes < oneLineMinutes || h < max(26, minTwo) || width < wrapFrom
        let squeezed = width < squeezedBelow              // narrow (< 46) is inside squeezed (< 66): same rule
        let most = squeezed ? narrowLines : 2
        let lines = one ? 1 : max(1, min(most, Int(((h - padTop - (timeLine + timeGap) - 2) / titleLine).rounded(.down))))
        var time: BlockTextPlan.Time = continuesFromPrevious ? .until : (one || width < rangeWidth || isShort) ? .start : .range
        if one && (squeezed || width < inlineTimeWidth) { time = .none }
        return BlockTextPlan(lines: one ? .one : .stacked, maxTitleLines: lines, time: time, centered: one && height < tallOne,
                             narrow: one && squeezed, thin: width < thinBelow)
    }

    /// The line box of a one-line block: the title line, or the block when it is shorter (rd.css `min(var(--lh-ev), var(--evh))`).
    public static func oneLineBox(height: Double) -> Double { min(titleLine, height) }
}
