import Foundation
import HorionKit

// MARK: The right column's search (v4 Phase 6)

extension AppModel {
    /// `/`, Command-F and the command menu's Search events: the right column's field takes the keyboard.
    func focusColumnSearch() {
        if overlay == .command { overlay = nil }
        rightColumnVisible = true
        chromeState.searchFocused = true
        chromeState.searchFocusTick += 1
    }

    /// The field's text. Events are searched through `searchText` (the same corpus as the command menu).
    func setColumnQuery(_ q: String) {
        chromeState.columnQuery = q
        searchText = q.trimmingCharacters(in: .whitespaces)
    }

    /// While the field has text, its results replace Today.
    var columnSearching: Bool { !chromeState.columnQuery.trimmingCharacters(in: .whitespaces).isEmpty }

    /// The results grouped by day (empty while the query is empty).
    var columnResults: [SearchGroup] { columnSearching ? searchGroups : [] }

    /// Return in the field: opens the first result and gives the keyboard back to the calendar. The query stays.
    func openFirstColumnResult() {
        guard let e = columnResults.first?.events.first else { return }
        openColumnResult(e)
    }

    func openColumnResult(_ e: CalendarEvent) {
        chromeState.searchFocused = false
        openSearchResult(e)
    }

    func clearColumnSearch() { setColumnQuery("") }
}
