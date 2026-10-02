import Foundation

/// The command menu's commands (design/mockup-v3 `COMMANDS`).
public enum CommandID: String, CaseIterable, Sendable {
    case newEvent, today, goToDate, nextPeriod, previousPeriod
    case viewDay, viewWeek, viewMonth, toggleSidebar, switchAppearance
    case searchEvents, meetWith, undo, deleteSelected, settings, fitWeek, shortcuts
}

public struct Command: Identifiable, Equatable, Sendable {
    public var id: CommandID
    public var title: String
    /// Section in the unfiltered list: Create, Go to, View, Find, Edit, Help.
    public var group: String
    /// Keycaps, one string per cap ("⌘", "Z").
    public var keys: [String]
    /// Opens a mode of the menu or a sheet instead of finishing there: shown with an ellipsis.
    public var more: Bool
    /// Only listed while an event is selected.
    public var needsSelection: Bool
    public init(_ id: CommandID, _ title: String, group: String, keys: [String] = [], more: Bool = false, needsSelection: Bool = false) {
        self.id = id; self.title = title; self.group = group; self.keys = keys; self.more = more; self.needsSelection = needsSelection
    }
}

public enum CommandRegistry {
    public static let all: [Command] = [
        Command(.newEvent, "New event", group: "Create", keys: ["C"]),
        Command(.today, "Go to today", group: "Go to", keys: ["T"]),
        Command(.goToDate, "Go to date", group: "Go to", keys: ["."], more: true),
        Command(.nextPeriod, "Next period", group: "Go to", keys: ["J"]),
        Command(.previousPeriod, "Previous period", group: "Go to", keys: ["K"]),
        Command(.viewDay, "Day view", group: "View", keys: ["D"]),
        Command(.viewWeek, "Week view", group: "View", keys: ["W"]),
        Command(.viewMonth, "Month view", group: "View", keys: ["M"]),
        Command(.toggleSidebar, "Toggle sidebar", group: "View", keys: ["`"]),
        Command(.switchAppearance, "Switch appearance", group: "View"),
        Command(.searchEvents, "Search events", group: "Find", keys: ["/"], more: true),
        Command(.meetWith, "Meet with", group: "Find", keys: ["F"], more: true),
        Command(.undo, "Undo", group: "Edit", keys: ["\u{2318}", "Z"]),
        Command(.deleteSelected, "Delete selected event", group: "Edit", keys: ["\u{232B}"], needsSelection: true),
        Command(.settings, "Settings", group: "Help", keys: ["\u{2318}", ","], more: true),
        Command(.fitWeek, "Fit the week again", group: "View"),
        Command(.shortcuts, "Keyboard shortcuts", group: "Help", keys: ["?"]),
    ]

    /// Commands available now. An empty query keeps the registry order; otherwise best fuzzy match first.
    public static func matching(_ query: String, hasSelection: Bool) -> [Command] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let pool = all.filter { !$0.needsSelection || hasSelection }
        guard !q.isEmpty else { return pool }
        return pool.compactMap { c in FuzzyMatcher.rank(q, in: c.title + " " + c.group).map { (c, $0) } }
            .sorted { $0.1 > $1.1 }.map(\.0)
    }
}

public enum FuzzyMatcher {
    /// Subsequence match. Higher is better; nil means no match. Rewards prefix, word starts and consecutive runs.
    public static func score(query: String, in text: String) -> Int? {
        let q = Array(query.lowercased().filter { !$0.isWhitespace })
        guard !q.isEmpty else { return 0 }
        let t = Array(text.lowercased())
        var qi = 0, score = 0, lastMatch = -2
        for (ti, ch) in t.enumerated() where qi < q.count && ch == q[qi] {
            var s = 1
            if ti == lastMatch + 1 { s += 5 }
            if ti == 0 { s += 10 } else if !t[ti - 1].isLetter && !t[ti - 1].isNumber { s += 6 }
            score += s
            lastMatch = ti
            qi += 1
        }
        guard qi == q.count else { return nil }
        // shorter texts win ties, exact prefix gets a bonus
        score -= t.count / 8
        if text.lowercased().hasPrefix(String(q)) { score += 15 }
        return score
    }

    /// The command menu's ranking (mockup `fuzzy`): a contiguous hit beats any scattered one, earlier and at a word start wins;
    /// otherwise a subsequence scored by runs and word starts. nil means no match.
    public static func rank(_ query: String, in text: String) -> Double? {
        let q = Array(query.lowercased()), t = Array(text.lowercased())
        guard !q.isEmpty else { return 1 }
        if let at = firstIndex(of: q, in: t) {
            return 1000 - Double(at) * 2 - Double(t.count - q.count) * 0.1 + (at == 0 || t[at - 1] == " " ? 50 : 0)
        }
        var i = 0, score = 0.0, last = -1
        for ch in q where ch != " " {
            guard let j = t[i...].firstIndex(of: ch) else { return nil }
            score += (j == last + 1 ? 8 : 0) + (j == 0 || t[j - 1] == " " ? 6 : 0) - Double(j - i) * 0.4
            last = j; i = j + 1
        }
        return score
    }

    static func firstIndex(of q: [Character], in t: [Character]) -> Int? {
        guard q.count <= t.count else { return nil }
        for s in 0...(t.count - q.count) where t[s] == q[0] && Array(t[s..<(s + q.count)]) == q { return s }
        return nil
    }

    public static func filter<T>(_ items: [T], query: String, text: (T) -> String) -> [T] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return items }
        return items.compactMap { i in score(query: q, in: text(i)).map { (i, $0) } }
            .sorted { $0.1 > $1.1 }.map(\.0)
    }
}
