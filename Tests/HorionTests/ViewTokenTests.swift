import Testing
import Foundation

/// Keeps views on the design system (design/design-system/): colours come from `InkRGB` / `Theme`, fonts from the named
/// Geist fonts and `TypeSize`. Fails on hex literals, `Color(red:)` / `Color(white:)`, named SwiftUI or AppKit colours, system text
/// fonts and literal font sizes in `Sources/Horion/Views`. SF Symbols (`Image(systemName:)` on the same line) keep the system font.
/// Calendar colours are data (`Color(hex: model.…)`) and are allowed. Need a new value? Add it to Theme.swift and foundations.md.
@Suite("View tokens")
struct ViewTokenTests {
    /// Files that own a palette or font on purpose.
    static let exempt: Set<String> = [
        "Theme.swift",              // the colour table
        "Typeface.swift",           // the type tokens and the font fallback
        "MenuBarViews.swift",       // imitates the native macOS menu (system colours and font)
        "MenuBarStatusItem.swift",  // draws into the system menu bar with AppKit
    ]

    static let rules: [(name: String, pattern: String)] = [
        ("hex literal", ##""#[0-9A-Fa-f]{3,8}""##),
        ("Color(red:/white:)", #"Color\((red|white):"#),
        ("named colour", #"(Color|NSColor)\.(white|black|gray|grey|red|blue|green|orange|yellow|purple|pink|primary|secondary)\b"#),
        ("named colour shorthand", #"\.(fill|foregroundStyle|foregroundColor|background|stroke|strokeBorder|tint)\(\.(white|black|gray|red|blue|green|orange|yellow|purple|pink|primary|secondary)\b"#),
        ("system text font", #"(\.font\(\.system\(|Font\.system\(|NSFont\.systemFont)"#),
        ("literal font size", #"(ctFont|geist)\([0-9]"#),
    ]

    static var viewsDir: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Horion/Views")
    }

    @Test func viewsUseTokensOnly() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.viewsDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" && !Self.exempt.contains($0.lastPathComponent) }
        #expect(!files.isEmpty, "no view sources at \(Self.viewsDir.path)")
        var hits: [String] = []
        for file in files {
            for (i, line) in try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n").enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                if code.hasPrefix("//") { continue }
                for rule in Self.rules where line.range(of: rule.pattern, options: .regularExpression) != nil {
                    if rule.name == "system text font", line.contains("systemName:") { continue }
                    hits.append("\(file.lastPathComponent):\(i + 1) \(rule.name): \(code)")
                }
            }
        }
        #expect(hits.isEmpty, "Use the design-system tokens (Theme.swift, Typeface.swift):\n\(hits.joined(separator: "\n"))")
    }

    static func matches(_ s: String) -> Bool {
        rules.contains { s.range(of: $0.pattern, options: String.CompareOptions.regularExpression) != nil }
    }

    /// The rules catch what they should.
    @Test func rulesMatchViolations() {
        let bad = [##"x.fill(Color(hex: "#33333C"))"##, "Color(red: 1, green: 0, blue: 0)", "Color.white.opacity(0.3)", ".foregroundStyle(.secondary)",
                   "Text(\"a\").font(.system(size: 12))", "Typeface.ctFont(13, weight: 500)"]
        for s in bad { #expect(Self.matches(s), "\(s)") }
        let good = ["Color(hex: model.colorHex(of: e))", "Theme.fg3", "Image(systemName: \"x\").font(.system(size: 10))", ".font(.text)"]
        for s in good where !s.contains("systemName:") { #expect(!Self.matches(s), "\(s)") }
    }
}
