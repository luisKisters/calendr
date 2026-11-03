import AppKit
import CalendrKit

/// Named UI states (all on the v4 fixture). `design/states.json` lists them with the design/mockup-v4 scene each one is compared against.
@MainActor
enum SnapshotStates {
    static let all = SnapshotV4.states + SnapshotChrome.v4States + SnapshotPanel.v4States + SnapshotServices.states

    static func find(_ m: AppModel, _ title: String, day: Int) -> CalendarEvent? {
        m.layout.timed[day].first { $0.event.title == title }?.event
    }

    /// Puts the model into the named state through the area hooks (`SnapshotV4`, `SnapshotChrome`, `SnapshotPanel`, `SnapshotServices`;
    /// the menu bar screen is drawn by `SnapshotMenuBar.run`). Returns false for unknown names.
    static func apply(_ name: String, to m: AppModel) -> Bool {
        SnapshotV4.apply(name, m) || SnapshotChrome.apply(name, m) || SnapshotPanel.apply(name, m) || SnapshotServices.apply(name, m)
    }
}
