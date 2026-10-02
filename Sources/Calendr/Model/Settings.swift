import Foundation

enum AppearanceSetting: String, Codable, CaseIterable, Identifiable {
    case dark = "Dark", light = "Light"
    var id: String { rawValue }

    /// Older builds also saved "System"; anything other than Light opens in Ink.
    init(from decoder: Decoder) throws {
        self = try AppearanceSetting(rawValue: decoder.singleValueContainer().decode(String.self)) ?? .dark
    }
}

/// What the menu bar item shows.
enum MenuBarDisplay: String, Codable, CaseIterable, Identifiable {
    case titleAndCountdown, countdown, icon
    var id: String { rawValue }
}

struct AppSettings: Codable, Equatable {
    var appearance: AppearanceSetting = .dark
    /// New events last this long: 30, 45 or 60 minutes.
    var defaultDurationMinutes = 60
    var showDeclined = true
    var defaultCalendarID: String?
    /// Overrides the system setting: every animation becomes instant.
    var reduceMotion = false
    var showWeekNumbers = false
    var menuBarDisplay: MenuBarDisplay = .titleAndCountdown
    /// Points per hour set by zooming the hour gutter; nil fits the period's events into the grid.
    var hourHeight: Double?

    static let durationChoices = [30, 45, 60]

    init() {}

    /// Missing keys decode to their defaults, so settings saved by an older build keep loading.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        appearance = try c.decodeIfPresent(AppearanceSetting.self, forKey: .appearance) ?? d.appearance
        defaultDurationMinutes = try c.decodeIfPresent(Int.self, forKey: .defaultDurationMinutes) ?? d.defaultDurationMinutes
        showDeclined = try c.decodeIfPresent(Bool.self, forKey: .showDeclined) ?? d.showDeclined
        defaultCalendarID = try c.decodeIfPresent(String.self, forKey: .defaultCalendarID)
        reduceMotion = try c.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? d.reduceMotion
        showWeekNumbers = try c.decodeIfPresent(Bool.self, forKey: .showWeekNumbers) ?? d.showWeekNumbers
        menuBarDisplay = (try? c.decodeIfPresent(MenuBarDisplay.self, forKey: .menuBarDisplay)) ?? d.menuBarDisplay
        hourHeight = try c.decodeIfPresent(Double.self, forKey: .hourHeight)
    }

    static let key = "calendr.settings.v2"
    static func load() -> AppSettings {
        guard let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(AppSettings.self, from: d) else { return AppSettings() }
        return s
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: Self.key) }
    }
}
