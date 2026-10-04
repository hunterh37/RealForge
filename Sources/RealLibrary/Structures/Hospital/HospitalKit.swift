import simd
import Foundation

/// Small mesh helpers shared by the Hospital structures.
enum HK {
    /// Flat quad a-b-c-d; the normal is cross(b - a, d - a). UVs come from `uv` (meters by default).
    static func quad(_ s: inout Surface, _ a: V3, _ b: V3, _ c: V3, _ d: V3, uv: (V3) -> V2) {
        let n = simd_normalize(simd_cross(b - a, d - a))
        let i0 = s.add(a, n, uv(a)), i1 = s.add(b, n, uv(b)), i2 = s.add(c, n, uv(c)), i3 = s.add(d, n, uv(d))
        s.quad(i0, i1, i2, i3)
    }

    /// Rectangle centered at `c` spanned by unit `right` and `up` (normal = right x up). UVs are meters, or
    /// 0...1 across the rectangle for labels and screens (`flipV`: v runs down).
    static func rect(_ s: inout Surface, center c: V3, right r: V3, up u: V3, w: Float, h: Float, unit: Bool = false, flipV: Bool = false) {
        let hw = r * (w / 2), hh = u * (h / 2)
        let p = [c - hw - hh, c + hw - hh, c + hw + hh, c - hw + hh]
        let n = simd_normalize(simd_cross(r, u))
        let uv: [V2] = unit ? (flipV ? [V2(0, 1), V2(1, 1), V2(1, 0), V2(0, 0)] : [V2(0, 0), V2(1, 0), V2(1, 1), V2(0, 1)])
                            : [V2(0, 0), V2(w, 0), V2(w, h), V2(0, h)]
        let i = p.indices.map { s.add(p[$0], n, uv[$0]) }
        s.quad(i[0], i[1], i[2], i[3])
    }

    static func rect(_ mat: MaterialKey, center c: V3, right r: V3, up u: V3, w: Float, h: Float, unit: Bool = false, flipV: Bool = false) -> Surface {
        var s = Surface(material: mat)
        rect(&s, center: c, right: r, up: u, w: w, h: h, unit: unit, flipV: flipV)
        return s
    }

    /// Rounded box helper returning a surface already placed.
    static func box(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.002, seg: Int = 2, rot: simd_quatf = .identity) -> Surface {
        Prim.roundedBox(size, radius: min(r, size.min() * 0.49), bevelSegments: seg, material: mat).transformed(Xform(translation: c, rotation: rot))
    }

    /// Cylinder centered on `c` along unit axis `axis`.
    static func cyl(r: Float, len: Float, at c: V3, axis: V3, mat: MaterialKey, seg: Int = 16, bevel: Float = 0.001) -> Surface {
        Prim.cylinder(radius: r, height: len, bevel: min(bevel, r * 0.4, len * 0.4), segments: seg, bevelSegments: 1, material: mat)
            .transformed(Xform(translation: c - axis * (len / 2), rotation: facing(axis)))
    }

    /// Tube through a polyline with constant radius.
    static func pipe(_ pts: [V3], r: Float, sides: Int = 12, mat: MaterialKey) -> Surface {
        Prim.tube(pts, radii: Array(repeating: r, count: pts.count), sides: sides, seamTile: 0.1, material: mat)
    }
}
