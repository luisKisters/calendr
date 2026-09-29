import Foundation

public enum CommandID: String, CaseIterable, Sendable {
    case createEvent, meetWith, showTeammate, recurringLink, oneOffLink, addNotionDatabase
    case goToDate, goToToday, leftAlignToday, nextPeriod, previousPeriod
    case viewDay, viewWeek, viewMonth, toggleSidebar, toggleRightPanel, settings
}

public struct Command: Identifiable, Equatable, Sendable {
    public var id: CommandID
    public var title: String
    public var section: String
    /// Key chips, e.g. ["option", "T"].
    public var chips: [String]
    public var keywords: String
    public init(_ id: CommandID, _ title: String, section: String, chips: [String] = [], keywords: String = "") {
        self.id = id; self.title = title; self.section = section; self.chips = chips; self.keywords = keywords
    }
}

public struct CommandSection: Identifiable, Equatable, Sendable {
    public var id: String { title }
    public var title: String
    public var commands: [Command]
}

public enum CommandRegistry {
    public static let all: [Command] = [
        Command(.createEvent, "Create event\u{2026}", section: "Calendar", chips: ["C"], keywords: "new add"),
        Command(.meetWith, "Meet with\u{2026}", section: "Calendar", chips: ["F"], keywords: "find time schedule"),
        Command(.showTeammate, "Show teammate calendar\u{2026}", section: "Calendar", chips: ["P"], keywords: "people overlay"),
        Command(.recurringLink, "Create recurring scheduling link\u{2026}", section: "Calendar", keywords: "booking"),
        Command(.oneOffLink, "Create one-off scheduling link\u{2026}", section: "Calendar", chips: ["S"], keywords: "booking"),
        Command(.addNotionDatabase, "Add Notion database\u{2026}", section: "Calendar", chips: ["O"]),
        Command(.goToDate, "Go to date\u{2026}", section: "Navigation", chips: ["."], keywords: "jump"),
        Command(.goToToday, "Go to today", section: "Navigation", chips: ["T"], keywords: "now"),
        Command(.leftAlignToday, "Left-align today in view", section: "Navigation", chips: ["option", "T"]),
        Command(.nextPeriod, "Next period", section: "Navigation", chips: ["J"], keywords: "forward"),
        Command(.previousPeriod, "Previous period", section: "Navigation", chips: ["K"], keywords: "back"),
        Command(.viewDay, "Switch to Day view", section: "Navigation", chips: ["D"]),
        Command(.viewWeek, "Switch to Week view", section: "Navigation", chips: ["W"]),
        Command(.viewMonth, "Switch to Month view", section: "Navigation", chips: ["M"]),
        Command(.toggleSidebar, "Toggle sidebar", section: "Navigation", chips: ["`"]),
        Command(.toggleRightPanel, "Toggle right panel", section: "Navigation", chips: ["command", "/"]),
        Command(.settings, "Settings", section: "Navigation", chips: ["command", ","], keywords: "preferences"),
    ]

    public static func sections(matching query: String) -> [CommandSection] {
        let q = query.trimmingCharacters(in: .whitespaces)
        var out: [CommandSection] = []
        if q.isEmpty {
            for c in all { append(c, to: &out) }
            return out
        }
        let scored = all.compactMap { c -> (Command, Int)? in
            guard let s = FuzzyMatcher.score(query: q, in: c.title) ?? FuzzyMatcher.score(query: q, in: c.keywords).map({ $0 - 20 }) else { return nil }
            return (c, s)
        }.sorted { $0.1 > $1.1 }
        for (c, _) in scored { append(c, to: &out) }
        return out
    }

    static func append(_ c: Command, to out: inout [CommandSection]) {
        if let i = out.firstIndex(where: { $0.title == c.section }) { out[i].commands.append(c) }
        else { out.append(CommandSection(title: c.section, commands: [c])) }
    }

    /// Flattened order as displayed, used for keyboard selection.
    public static func flat(_ sections: [CommandSection]) -> [Command] { sections.flatMap(\.commands) }
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

    public static func filter<T>(_ items: [T], query: String, text: (T) -> String) -> [T] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return items }
        return items.compactMap { i in score(query: q, in: text(i)).map { (i, $0) } }
            .sorted { $0.1 > $1.1 }.map(\.0)
    }
}
