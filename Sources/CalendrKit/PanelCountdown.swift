import Foundation

/// Minutes left until a moment, as every countdown in the app shows them (panel "in 12 min", "8 min left"; menu bar "in 12m").
public enum Countdown {
    /// Rounded up, so a countdown reads "1 min" until the moment arrives and never "0 min" while time is left. Never negative.
    public static func minutes(from now: Date, to date: Date) -> Int {
        max(0, Int((date.timeIntervalSince(now) / 60).rounded(.up)))
    }
}
