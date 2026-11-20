import Foundation

/// Overlap layout v11: the locked cascade (design/mockup-v11 app.js `clustersOf` / `cascade`, decided 2026-11-05, kept in v11).
/// Pure: minutes in, fractions of the day column and points of indent out. Nothing is ever folded into "+N".
///
/// Google-like: in each cluster of overlapping blocks (by start, the longer first), a block indents one step (12 pt) from the deepest
/// block still running at its start and keeps nearly the full width; the later one is drawn on top. A block that starts within one
/// title line (22 minutes) of one below it moves to the right half of that block, and that one ends at its edge, so no title is covered.
/// Short items (15 minutes or less) take part as 22-minute blocks (the app has no separate task markers: tasks are plain events).
public enum OverlapV11 {
    /// Points of indent per cascade level (mockup `G().indent`, capped there at 36 percent of the column over the cluster's depth).
    public static let indentStep = 12.0
    /// Minutes one title line covers at 44 pt per hour (`TITLE_MIN`).
    public static let titleMinutes = 22

    /// `placements` are in drawing order (each later one on top); `cut` is set on every block but the first of its cluster
    /// (`.ev.stk`: the 1 pt window-coloured ring).
    public static func layout(_ input: [V5Item]) -> [V5Placement] {
        struct W { var id: String; var order: Int; var s: Int; var en: Int; var lvl = 0; var left = 0.0; var width = 1.0; var px = 0.0; var stk = false; var near: [Int] = [] }
        var w: [W] = input.enumerated().map { i, it in
            W(id: it.id, order: i, s: it.startMinute,
              en: it.isShort ? it.startMinute + OverlapV5.shortSpan : max(it.endMinute, it.startMinute + 15))
        }
        w.sort { a, b in
            if a.s != b.s { return a.s < b.s }
            if a.en - a.s != b.en - b.s { return a.en - a.s > b.en - b.s }
            return a.order < b.order
        }
        // Clusters: a block that starts at or after the end of everything before it starts a new one.
        var clusters: [[Int]] = []
        var end = -1
        for i in w.indices {
            if w[i].s >= end, !(clusters.last?.isEmpty ?? true) { clusters.append([]); end = -1 }
            if clusters.isEmpty { clusters.append([]) }
            clusters[clusters.count - 1].append(i)
            end = max(end, w[i].en)
        }
        for c in clusters {
            for (k, i) in c.enumerated() {
                let under = c[..<k].filter { w[$0].en > w[i].s }
                w[i].lvl = under.isEmpty ? 0 : 1 + (under.map { w[$0].lvl }.max() ?? 0)
                w[i].near = under.filter { w[i].s - w[$0].s < titleMinutes }
                w[i].stk = k > 0
                w[i].px = Double(w[i].lvl) * indentStep
            }
            for i in c where !w[i].near.isEmpty {
                // The right half of the block it starts with; the cascade indent no longer applies.
                let x = w[i].near.map { w[$0].left + (1 - w[$0].left) / 2 }.max() ?? 0
                w[i].left = max(w[i].left, x); w[i].width = 1 - w[i].left; w[i].px = 0
                for o in w[i].near { w[o].width = min(w[o].width, w[i].left - w[o].left) }
            }
        }
        return clusters.flatMap { $0 }.map { i in
            V5Placement(id: w[i].id, left: w[i].left, width: w[i].width, indent: w[i].px, level: 0, cut: w[i].stk, startMinute: w[i].s, endMinute: w[i].en)
        }
    }
}
