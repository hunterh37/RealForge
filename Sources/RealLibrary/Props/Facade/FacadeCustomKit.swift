import simd
import Foundation

/// Helpers for the facade customization props (second facade batch). Same frame as `FA`: wall plane at
/// z = 0, piece projecting toward +Z.
enum FC {
    /// Low-poly bead for repeated ornament (finials, rivets, fruit, bulbs).
    static func bead(_ m: inout Model, r: Float, at c: V3, _ mat: MaterialKey, sub: Int = 3) {
        m.add(Prim.superellipsoid(V3(repeating: r * 2), exponent: 2, subdivisions: sub, material: mat), Xform(translation: c))
    }
    /// Centers bounds on X and Z and seats the lowest point on y = 0.
    static func place(_ m: Model) -> Model {
        let bb = m.bounds
        return m.transformed(Xform(translation: V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)))
    }
}
