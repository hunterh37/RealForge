import simd
import Foundation

/// Geometry helpers shared by the Bedside pack: flat label/screen quads and printed or LCD
/// seven-segment numerals built as quads (no texture program needed).
enum BedsideKit {
    /// Flat quad centered at `c`, `w` along `u`, `h` along `v`; faces `cross(u, v)`. UVs 0...1 across
    /// the quad (`vDown` puts v = 0 at the top edge, as label and screen programs expect).
    static func panel(center c: V3, u: V3, v: V3, w: Float, h: Float, material: MaterialKey, vDown: Bool = false) -> Surface {
        var s = Surface(material: material)
        let uu = simd_normalize(u), vv = simd_normalize(v), n = simd_normalize(simd_cross(uu, vv))
        let eu = uu * w / 2, ev = vv * h / 2
        let v0: Float = vDown ? 1 : 0, v1: Float = vDown ? 0 : 1
        let a = s.add(c - eu - ev, n, V2(0, v0)), b = s.add(c + eu - ev, n, V2(1, v0))
        let d = s.add(c + eu + ev, n, V2(1, v1)), e = s.add(c - eu + ev, n, V2(0, v1))
        s.quad(a, b, d, e)
        s.computeTangents()
        return s
    }

    /// Adds a quad from local 2D corners (x along u, y along v, origin o) to `s`.
    static func quad2(_ s: inout Surface, _ o: V3, _ u: V3, _ v: V3, _ p0: V2, _ p1: V2, _ p2: V2, _ p3: V2) {
        let n = simd_normalize(simd_cross(u, v))
        let a = s.add(o + u * p0.x + v * p0.y, n, p0), b = s.add(o + u * p1.x + v * p1.y, n, p1)
        let c = s.add(o + u * p2.x + v * p2.y, n, p2), d = s.add(o + u * p3.x + v * p3.y, n, p3)
        s.quad(a, b, c, d)
    }

    /// Axis-aligned bar in the (u, v) plane from (x0, y0) to (x1, y1).
    static func bar(_ s: inout Surface, _ o: V3, _ u: V3, _ v: V3, _ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float, shear: Float = 0) {
        quad2(&s, o, u, v, V2(x0 + shear * y0, y0), V2(x1 + shear * y0, y0), V2(x1 + shear * y1, y1), V2(x0 + shear * y1, y1))
    }

    /// Segment masks a b c d e f g (bit 0 = a, top; clockwise; g = middle).
    static let glyphs: [Character: UInt8] = [
        "0": 0b0111111, "1": 0b0000110, "2": 0b1011011, "3": 0b1001111, "4": 0b1100110, "5": 0b1101101,
        "6": 0b1111101, "7": 0b0000111, "8": 0b1111111, "9": 0b1101111, "-": 0b1000000, "E": 0b1111001,
        "L": 0b0111000, "o": 0b1011100, "H": 0b1110110, "P": 0b1110011, "C": 0b0111001, "r": 0b1010000,
    ]

    /// Width of `text` in meters at glyph height `h` (advance 0.72 h per glyph, 0.3 h for "." and " ").
    static func textWidth(_ text: String, height h: Float) -> Float {
        text.reduce(Float(0)) { $0 + (($1 == "." || $1 == ":") ? 0.3 * h : 0.72 * h) } - 0.17 * h
    }

    /// Seven-segment numerals as quads in the plane through `origin` spanned by `u` (right) and `v` (up),
    /// facing `cross(u, v)`. `origin` is the bottom-left of the first glyph. `stroke` is the segment width
    /// as a fraction of `h`. `centered` shifts so the string is centered on `origin` horizontally.
    static func segments(_ text: String, origin: V3, u: V3, v: V3, height h: Float, stroke: Float = 0.13,
                         shear: Float = 0.1, centered: Bool = false, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let uu = simd_normalize(u), vv = simd_normalize(v)
        let w = 0.55 * h, t = stroke * h, g = t * 0.35
        var x: Float = centered ? -textWidth(text, height: h) / 2 : 0
        for ch in text {
            if ch == "." { bar(&s, origin, uu, vv, x, 0, x + t, t, shear: shear); x += 0.3 * h; continue }
            if ch == ":" { bar(&s, origin, uu, vv, x, h * 0.2, x + t, h * 0.2 + t, shear: shear); bar(&s, origin, uu, vv, x, h * 0.65, x + t, h * 0.65 + t, shear: shear); x += 0.3 * h; continue }
            let m = glyphs[ch] ?? 0
            let ym = h / 2
            if m & 1 != 0 { bar(&s, origin, uu, vv, x + g + t * 0.5, h - t, x + w - g - t * 0.5, h, shear: shear) }          // a
            if m & 2 != 0 { bar(&s, origin, uu, vv, x + w - t, ym + g, x + w, h - g, shear: shear) }                         // b
            if m & 4 != 0 { bar(&s, origin, uu, vv, x + w - t, g, x + w, ym - g, shear: shear) }                             // c
            if m & 8 != 0 { bar(&s, origin, uu, vv, x + g + t * 0.5, 0, x + w - g - t * 0.5, t, shear: shear) }             // d
            if m & 16 != 0 { bar(&s, origin, uu, vv, x, g, x + t, ym - g, shear: shear) }                                    // e
            if m & 32 != 0 { bar(&s, origin, uu, vv, x, ym + g, x + t, h - g, shear: shear) }                                // f
            if m & 64 != 0 { bar(&s, origin, uu, vv, x + g + t * 0.5, ym - t / 2, x + w - g - t * 0.5, ym + t / 2, shear: shear) } // g
            x += 0.72 * h
        }
        s.computeTangents()
        return s
    }

    /// Greeked one-line caption: short bars of word lengths `words` (in glyph widths), height `h`.
    static func caption(_ words: [Int], origin: V3, u: V3, v: V3, height h: Float, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let uu = simd_normalize(u), vv = simd_normalize(v)
        var x: Float = 0
        for n in words {
            let len = Float(n) * h * 0.62
            bar(&s, origin, uu, vv, x, 0, x + len, h * 0.72)
            x += len + h * 0.5
        }
        s.computeTangents()
        return s
    }
}
