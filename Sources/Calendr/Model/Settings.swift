import Foundation

enum AppearanceSetting: String, Codable, CaseIterable, Identifiable {
    case dark = "Dark", light = "Light", system = "System"
    var id: String { rawValue }
}

struct AppSettings: Codable, Equatable {
    var appearance: AppearanceSetting = .dark
    var weekStartsOnMonday = true
    var defaultDurationMinutes = 60
    var showDeclined = true
    var use24h = true
    var firstVisibleHour = 7
    var defaultCalendarID: String?
    /// Overrides the system setting: every animation becomes instant.
    var reduceMotion = false

    static let key = "calendr.settings.v2"
    static func load() -> AppSettings {
        guard let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(AppSettings.self, from: d) else { return AppSettings() }
        return s
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: Self.key) }
    }
}

/// Task completion is a local marker: EventKit has no task kind, and reminders are out of scope.
enum TaskStore {
    static let key = "calendr.completedTasks.v1"
    static func load() -> Set<String> { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
    static func save(_ s: Set<String>) { UserDefaults.standard.set(Array(s), forKey: key) }
}
