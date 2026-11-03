import Testing
import Foundation
@testable import CalendrKit

@Suite("Map links")
struct MapLinksTests {
    @Test func appleMaps() {
        #expect(MapLinks.apple("Kitchen, 12 Harbour Street")?.absoluteString == "https://maps.apple.com/?q=Kitchen%2C%2012%20Harbour%20Street")
    }

    @Test func googleMaps() {
        #expect(MapLinks.google("Kitchen, 12 Harbour Street")?.absoluteString
                == "https://www.google.com/maps/search/?api=1&query=Kitchen%2C%2012%20Harbour%20Street")
    }

    @Test func reservedCharactersCannotBreakTheQuery() {
        let u = MapLinks.google("A&B Café #2, 1+1 Road / Hof=3?")!
        #expect(u.absoluteString == "https://www.google.com/maps/search/?api=1&query=A%26B%20Caf%C3%A9%20%232%2C%201%2B1%20Road%20%2F%20Hof%3D3%3F")
        let items = URLComponents(url: u, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.map(\.name) == ["api", "query"] && items.last?.value == "A&B Café #2, 1+1 Road / Hof=3?")
        let a = URLComponents(url: MapLinks.apple("St. Mary's Hall, 8 Church Square")!, resolvingAgainstBaseURL: false)
        #expect(a?.queryItems?.first?.value == "St. Mary's Hall, 8 Church Square")
    }

    @Test func blankHasNoLink() {
        #expect(MapLinks.apple("  ") == nil && MapLinks.google("") == nil)
        #expect(MapLinks.apple("  Market Hall \n")?.absoluteString == "https://maps.apple.com/?q=Market%20Hall")
    }
}
