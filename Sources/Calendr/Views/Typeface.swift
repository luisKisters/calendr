import AppKit
import CoreText
import SwiftUI

/// Geist (the variable `Geist[wght].ttf`, 100–900, SIL OFL 1.1, `Resources/Fonts` with `Geist-OFL.txt`), registered for this process
/// before anything renders. It is the only face of the UI (v11, locked 2026-11-20); the system menu bar keeps the system font.
///
/// The font is looked up without SwiftPM's `Bundle.module` (it traps when the resource bundle is not next to the executable):
/// 1. the app bundle: `Contents/Resources/Fonts` (copied there by scripts/build-app.sh),
/// 2. next to the executable or the test bundle: `Fonts/` and the SwiftPM resource bundle `*_Calendr.bundle`,
/// 3. the source tree, for builds run from the checkout.
enum Typeface {
    static let fileName = "Geist[wght].ttf"
    static let family = "Geist"

    /// Registers the font once. Safe to call from anywhere and more than once.
    @discardableResult
    static func register() -> Bool { registered }

    private static let registered: Bool = {
        guard let url = locate() else {
            FileHandle.standardError.write(Data("Calendr: \(fileName) not found, falling back to the system font\n".utf8))
            return false
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            // Already registered (e.g. a second test process in the same session) is fine.
            let code = error.map { CFErrorGetCode($0.takeRetainedValue()) } ?? 0
            if code != CTFontManagerError.alreadyRegistered.rawValue { return false }
        }
        if let d = (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first { base = d }
        return true
    }()

    nonisolated(unsafe) private static var base: CTFontDescriptor?

    static func locate() -> URL? {
        let fm = FileManager.default
        var dirs: [URL] = []
        if let r = Bundle.main.resourceURL { dirs.append(r.appendingPathComponent("Fonts")) }
        var roots: [URL] = []
        if let exe = Bundle.main.executableURL?.resolvingSymlinksInPath().deletingLastPathComponent() { roots.append(exe) }
        roots.append(Bundle(for: Marker.self).bundleURL.deletingLastPathComponent())
        for root in roots {
            dirs.append(root.appendingPathComponent("Fonts"))
            let items = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            for b in items where b.pathExtension == "bundle" && b.lastPathComponent.hasSuffix("_Calendr.bundle") {
                if let r = Bundle(url: b)?.resourceURL { dirs.append(r.appendingPathComponent("Fonts")) }
                dirs.append(b.appendingPathComponent("Fonts"))
            }
        }
        // Sources/Calendr/Views/Typeface.swift -> Sources/Calendr/Resources/Fonts
        dirs.append(URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Fonts"))
        return dirs.map { $0.appendingPathComponent(fileName) }.first { fm.fileExists(atPath: $0.path) }
    }

    private final class Marker {}

    // MARK: Fonts

    private static let weightAxis = 0x77676874    // 'wght', 100 ... 900
    private struct Key: Hashable { var size: CGFloat; var weight: Int; var tabular: Bool }
    nonisolated(unsafe) private static var cache: [Key: CTFont] = [:]
    private static let lock = NSLock()

    /// CSS weight (400 regular ... 700 bold) for a SwiftUI weight.
    static func cssWeight(_ w: Font.Weight) -> Int {
        switch w {
        case .ultraLight, .thin, .light, .regular: 400
        case .medium: 500
        case .semibold: 600
        default: 700
        }
    }

    static func cssWeight(_ w: NSFont.Weight) -> Int {
        w.rawValue >= NSFont.Weight.bold.rawValue ? 700 : w.rawValue >= NSFont.Weight.semibold.rawValue ? 600 : w.rawValue >= NSFont.Weight.medium.rawValue ? 500 : 400
    }

    /// Geist at `size` and CSS `weight`; `tabular` turns on tabular figures (`tnum`: every time, date and count).
    static func ctFont(_ size: CGFloat, weight: Int = 400, tabular: Bool = false) -> CTFont {
        let key = Key(size: size, weight: weight, tabular: tabular)
        lock.lock(); defer { lock.unlock() }
        if let f = cache[key] { return f }
        let f = make(key)
        cache[key] = f
        return f
    }

    private static func make(_ k: Key) -> CTFont {
        guard register(), let base else {
            let w: NSFont.Weight = k.weight >= 700 ? .bold : k.weight >= 600 ? .semibold : k.weight >= 500 ? .medium : .regular
            return k.tabular ? NSFont.monospacedDigitSystemFont(ofSize: k.size, weight: w) : NSFont.systemFont(ofSize: k.size, weight: w)
        }
        var attrs: [CFString: Any] = [kCTFontVariationAttribute: [weightAxis: k.weight]]
        if k.tabular {
            attrs[kCTFontFeatureSettingsAttribute] = [[kCTFontOpenTypeFeatureTag: "tnum", kCTFontOpenTypeFeatureValue: 1]]
        }
        let d = CTFontDescriptorCreateCopyWithAttributes(base, attrs as CFDictionary)
        return CTFontCreateWithFontDescriptor(d, k.size, nil)
    }
}

// MARK: Type tokens (v11 design system, the locked "three" scale: 15 / 12 / 11, weights 400 / 500 / 600)

/// Sizes and line heights. Only 15 (month title), 12 (everything you read) and 11 (times, hour labels, mini-month days, small labels).
enum TypeSize {
    /// Month title, 15 / 21.
    static let title: CGFloat = 15
    /// Body, headings, labels, rows: 12 / 18.
    static let text: CGFloat = 12
    /// Secondary: times, hour labels, mini-month days, small labels: 11 / 14.
    static let small: CGFloat = 11
    /// Event titles: 12 / 15.5.
    static let event: CGFloat = 12

    static let titleLine: CGFloat = 21
    static let textLine: CGFloat = 18
    /// The right-column lead title (`heading`, 12 / 20).
    static let headingLine: CGFloat = 20
    static let eventLine: CGFloat = 15.5
    /// Event times and other 11 pt text in lists.
    static let smallLine: CGFloat = 14
}

/// Letter-spacing in points (the mockup's em values at their size): title -.01em, body and event titles -.004em,
/// small text and labels +.004em, hour labels 0.
enum TypeTrack {
    static let title: CGFloat = -0.15
    /// The right-column lead (12 / 600, -.01em).
    static let heading: CGFloat = -0.12
    static let text: CGFloat = -0.048
    static let small: CGFloat = 0.044
    /// Group headers and day-header weekdays (12, +.004em).
    static let label: CGFloat = 0.048
}

extension Font {
    private static func geist(_ size: CGFloat, _ weight: Int = 400, tabular: Bool = false) -> Font { Font(Typeface.ctFont(size, weight: weight, tabular: tabular)) }

    /// Month title and dialog titles: Geist 15 / 600 (track `TypeTrack.title`).
    static let title15 = geist(TypeSize.title, 600)
    /// The year after the month title: Geist 15 / 400 tabular, drawn fg3.
    static let title15Light = geist(TypeSize.title, 400, tabular: true)

    /// Body text (`body`): Geist 12 / 400.
    static let text = geist(TypeSize.text)
    /// `body-strong`: day-header date, mini-month title, all-day chips (12 / 500).
    static let textMedium = geist(TypeSize.text, 500)
    /// `heading`: the right-column lead title and today's date (12 / 600).
    static let textSemibold = geist(TypeSize.text, 600)
    static let textTab = geist(TypeSize.text, tabular: true)
    /// `label`: sidebar group headers (12 / 500, fg3).
    static let label = geist(TypeSize.text, 500)

    /// Secondary text, labels, hints (`small`): Geist 11 / 400.
    static let small = geist(TypeSize.small)
    static let smallMedium = geist(TypeSize.small, 500)
    static let smallSemibold = geist(TypeSize.small, 600)
    static let smallTab = geist(TypeSize.small, tabular: true)
    static let smallTabMedium = geist(TypeSize.small, 500, tabular: true)
    static let smallTabSemibold = geist(TypeSize.small, 600, tabular: true)

    /// Chrome labels that are 500 in Dark and 400 in Paper (mockup theme.css `.desk:not(.light) :is(.lab2, .ad .g .lbl, .mm .wd,
    /// .mm .wkn, .tcol .end, .dh .c) { font-weight: 500 }`): "Later today", "all-day", the mini month's weekday letters and week
    /// numbers, the end time of a right-column card. `smallLabelTab` is the tabular one.
    static func smallLabel(dark: Bool) -> Font { dark ? smallMedium : small }
    static func smallLabelTab(dark: Bool) -> Font { dark ? smallTabMedium : smallTab }

    /// Event titles: Geist 12 / 500.
    static let event = geist(TypeSize.event, 500)
    /// Event times: Geist 11 tabular.
    static let eventTab = geist(TypeSize.small, tabular: true)
}
