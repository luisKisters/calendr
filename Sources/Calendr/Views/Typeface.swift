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

extension Font {
    /// The UI face: Instrument Sans. Use this instead of `.system(size:)` for text (SF Symbols keep the system font).
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font(Typeface.ctFont(size, weight: Typeface.cssWeight(weight)))
    }
    /// Times, durations, dates and keycaps: Instrument Sans with tabular figures (the v2 mono-is-machine rule is retired).
    static func calMono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font(Typeface.ctFont(size, weight: Typeface.cssWeight(weight), tabular: true))
    }
    static let calTitle = Font.ui(22, .semibold)
    static let calLead = Font.ui(16, .semibold)
    static let calBody = Font.ui(13)
    static let calMeta = Font.ui(11.5)
    static let calMicro = Font.ui(10.5, .semibold)
}
