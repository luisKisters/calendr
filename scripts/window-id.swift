// Prints the CGWindowID of the first on-screen window owned by the given process name: swift scripts/window-id.swift Calendr
import CoreGraphics
import Foundation
let name = CommandLine.arguments.dropFirst().first ?? "Calendr"
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list where (w[kCGWindowOwnerName as String] as? String) == name && (w[kCGWindowLayer as String] as? Int) == 0 {
    let b = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    print(w[kCGWindowNumber as String] ?? 0, b["Width"] ?? 0, b["Height"] ?? 0)
    break
}
