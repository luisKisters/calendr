import AppKit
import CoreText
import SwiftUI

/// Instrument Sans (SIL OFL, `Resources/Fonts`), registered for this process before anything renders.
///
/// The font is looked up without SwiftPM's `Bundle.module` (it traps when the resource bundle is not next to the executable):
/// 1. the app bundle: `Contents/Resources/Fonts` (copied there by scripts/build-app.sh),
/// 2. next to the executable or the test bundle: `Fonts/` and the SwiftPM resource bundle `*_Calendr.bundle`,
/// 3. the source tree, for builds run from the checkout.
enum Typeface {
    static let fileName = "InstrumentSans.ttf"
    static let family = "Instrument Sans"

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

    private static let weightAxis = 0x77676874    // 'wght', 400 ... 700
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

    /// Instrument Sans at `size` and CSS `weight`; `tabular` turns on tabular figures (every time and date numeral).
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

// MARK: Type tokens (design/mockup-v4 `.ds`: 18 titles · 12.5 text · 11.5 small · events 11.5 / 500)

/// SF Pro (the system font) for text and events; tabular variants use `monospacedDigitSystemFont`. Instrument Sans 600 only for 18 pt titles.
enum SF {
    private struct Key: Hashable { var size: CGFloat; var weight: Int; var tabular: Bool }
    nonisolated(unsafe) private static var cache: [Key: CTFont] = [:]
    private static let lock = NSLock()

    static func nsWeight(_ w: Int) -> NSFont.Weight { w >= 700 ? .bold : w >= 600 ? .semibold : w >= 500 ? .medium : .regular }

    /// SF at `size` and CSS `weight`; `tabular` uses monospaced digits.
    static func ctFont(_ size: CGFloat, weight: Int = 400, tabular: Bool = false) -> CTFont {
        let key = Key(size: size, weight: weight, tabular: tabular)
        lock.lock(); defer { lock.unlock() }
        if let f = cache[key] { return f }
        let f: NSFont = tabular ? .monospacedDigitSystemFont(ofSize: size, weight: nsWeight(weight)) : .systemFont(ofSize: size, weight: nsWeight(weight))
        cache[key] = f
        return f
    }
}

enum TypeSize {
    static let title: CGFloat = 18
    static let text: CGFloat = 12.5
    static let small: CGFloat = 11.5
    static let event: CGFloat = 11.5
    /// Event times, hour labels and the all-day label: the mockup's `--fs-evt` (10.5 at size 's').
    static let eventTime: CGFloat = 10.5
    /// Mini-month week numbers and avatar initials.
    static let tiny: CGFloat = 9.5
}

extension Font {
    private static func sf(_ size: CGFloat, _ weight: Int = 400, tabular: Bool = false) -> Font { Font(SF.ctFont(size, weight: weight, tabular: tabular)) }

    /// Month title, event title, Today, dialog titles: Instrument Sans 18 / 600.
    static let title18 = Font(Typeface.ctFont(TypeSize.title, weight: 600))
    /// The year after the month title: Instrument Sans 18 / 400 tabular, drawn fg3.
    static let title18Light = Font(Typeface.ctFont(TypeSize.title, weight: 400, tabular: true))

    /// Body text: SF 12.5 / 400.
    static let text = sf(TypeSize.text)
    static let textMedium = sf(TypeSize.text, 500)
    static let textSemibold = sf(TypeSize.text, 600)
    static let textTab = sf(TypeSize.text, tabular: true)

    /// Secondary text, labels, hints: SF 11.5 / 400.
    static let small = sf(TypeSize.small)
    static let smallMedium = sf(TypeSize.small, 500)
    static let smallSemibold = sf(TypeSize.small, 600)
    static let smallTab = sf(TypeSize.small, tabular: true)
    static let smallTabMedium = sf(TypeSize.small, 500, tabular: true)
    static let smallTabSemibold = sf(TypeSize.small, 600, tabular: true)

    /// Event titles: SF 11.5 / 500.
    static let event = sf(TypeSize.event, 500)
    static let eventTab = sf(TypeSize.eventTime, tabular: true)

    /// Week numbers and avatar initials: SF 9.5.
    static let tiny = sf(TypeSize.tiny)
    static let tinyTab = sf(TypeSize.tiny, tabular: true)
    static let tinySemibold = sf(TypeSize.tiny, 600)
}
