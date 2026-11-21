import Foundation

/// The colour math of the v11 mockup (`tokens.js` `THEME.util`: `mx`, `relL`, `wcag`, `apca`, `oklch`, `fromOklch`, `fit`, and
/// `readability.js` `deOK`), ported one to one so the app computes the same 8-bit colours as the mockup. Every colour is an
/// 8-bit sRGB triple, as the mockup's hex strings are: mixes and OKLCH conversions round to whole channel values.
struct C8: Hashable {
    var r: Int, g: Int, b: Int
    init(_ r: Int, _ g: Int, _ b: Int) { self.r = r; self.g = g; self.b = b }
    init(hex: String) {
        let v = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(Int((v >> 16) & 255), Int((v >> 8) & 255), Int(v & 255))
    }
    static let white = C8(255, 255, 255)
    static let black = C8(0, 0, 0)
    var hex: String { String(format: "#%02X%02X%02X", r, g, b) }
    var rgb: RGB { RGB(Double(r) / 255, Double(g) / 255, Double(b) / 255) }
    fileprivate var ch: [Double] { [Double(r), Double(g), Double(b)] }

    /// `mx(a, b, t)`: this colour moved toward `o` by `t`, each channel rounded.
    func mix(_ o: C8, _ t: Double) -> C8 {
        let x = ch, y = o.ch
        let v = (0..<3).map { Int((x[$0] + (y[$0] - x[$0]) * t).rounded()) }
        return C8(v[0], v[1], v[2])
    }
}

enum ColorMath {
    private static func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    private static func toS(_ v0: Double) -> Double { let v = max(0, min(1, v0)); return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055 }

    /// WCAG relative luminance.
    static func relL(_ c: C8) -> Double {
        let w = [0.2126, 0.7152, 0.0722]
        return zip(c.ch, w).reduce(0) { $0 + lin($1.0 / 255) * $1.1 }
    }
    /// WCAG 2 contrast ratio.
    static func wcag(_ a: C8, _ b: C8) -> Double {
        let x = relL(a), y = relL(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
    /// APCA Lc (SAPC 0.0.98G as in the mockup) of text `txt` on `bg`; negative for light text on dark.
    static func apca(_ txt: C8, _ bg: C8) -> Double {
        func Y(_ c: C8) -> Double { let v = c.ch.map { pow($0 / 255, 2.4) }; return 0.2126729 * v[0] + 0.7151522 * v[1] + 0.072175 * v[2] }
        func cl(_ y: Double) -> Double { y > 0.022 ? y : y + pow(0.022 - y, 1.414) }
        let t = cl(Y(txt)), b = cl(Y(bg))
        if abs(b - t) < 0.0005 { return 0 }
        if b > t { let s = (pow(b, 0.56) - pow(t, 0.57)) * 1.14; return s < 0.1 ? 0 : (s - 0.027) * 100 }
        let s = (pow(b, 0.65) - pow(t, 0.62)) * 1.14; return s > -0.1 ? 0 : (s + 0.027) * 100
    }
    /// A floor: [min WCAG ratio, min |Lc|].
    typealias Floor = (ratio: Double, lc: Double)
    /// `ok`: passes the floor with the mockup's small margin (+.05 ratio, +.6 Lc).
    static func ok(_ fg: C8, _ bg: C8, _ f: Floor) -> Bool { wcag(fg, bg) >= f.ratio + 0.05 && abs(apca(fg, bg)) >= f.lc + 0.6 }
    /// `fit(fg, bgs, to, floor)`: moves `fg` toward `to` in 1 % steps until it passes `floor` on every background.
    static func fit(_ fg: C8, _ bgs: [C8], _ to: C8, _ f: Floor) -> C8 {
        var t = 0.0, c = fg
        while t < 1 && !bgs.allSatisfy({ ok(c, $0, f) }) { t += 0.01; c = fg.mix(to, t) }
        return c
    }

    /// OKLCH of a colour: L, C, H (radians, -π ... π as atan2 gives it).
    static func oklch(_ c: C8) -> (L: Double, C: Double, H: Double) {
        let v = c.ch.map { lin($0 / 255) }, r = v[0], g = v[1], b = v[2]
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let q = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        let L = 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * q
        let A = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * q
        let B = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * q
        return (L, (A * A + B * B).squareRoot(), atan2(B, A))
    }
    private static func linear(_ L: Double, _ C: Double, _ H: Double) -> [Double] {
        let A = C * cos(H), B = C * sin(H)
        let l = pow(L + 0.3963377774 * A + 0.2158037573 * B, 3), m = pow(L - 0.1055613458 * A - 0.0638541728 * B, 3), q = pow(L - 0.0894841775 * A - 1.291485548 * B, 3)
        return [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * q, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * q, -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * q]
    }
    /// `fromOklch`: the sRGB colour of an OKLCH value; out of gamut, only the chroma is reduced (in .002 steps).
    static func fromOklch(_ L: Double, _ C: Double, _ H: Double) -> C8 {
        var c = C, v = linear(L, c, H)
        while c > 0 && v.contains(where: { $0 < -1e-4 || $0 > 1 + 1e-4 }) { c -= 0.002; v = linear(L, c, H) }
        let o = v.map { Int((toS($0) * 255).rounded()) }
        return C8(o[0], o[1], o[2])
    }
    /// Hue in degrees, 0 ..< 360.
    static func deg(_ H: Double) -> Double { (H * 180 / .pi + 360).truncatingRemainder(dividingBy: 360) }
    /// ΔE_OK × 100 (OKLab distance).
    static func deltaE(_ a: C8, _ b: C8) -> Double {
        func lab(_ c: C8) -> [Double] { let o = oklch(c); return [o.L, o.C * cos(o.H), o.C * sin(o.H)] }
        let x = lab(a), y = lab(b)
        let d0 = x[0] - y[0], d1 = x[1] - y[1], d2 = x[2] - y[2]
        return (d0 * d0 + d1 * d1 + d2 * d2).squareRoot() * 100
    }
}
