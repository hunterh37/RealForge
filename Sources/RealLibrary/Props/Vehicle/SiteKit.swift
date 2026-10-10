import simd
import Foundation

/// Helpers shared by the site-context props (road vehicles, rooftop gear, plaza structures).
enum SK {
    /// Tinted painted-metal key for a sRGB hex color.
    static func paint(_ hex: UInt32) -> String { "metal.painted:" + String(format: "%06X", hex) }

    /// Side-profile prism: outline in (z, y), extruded `width` along X centered on `x`.
    static func side(_ m: inout Model, _ outline: [V2], width: Float, x: Float = 0, mat: String, bevel: Float = 0.01) {
        m.add(VK.side(outline, width: width, x: x, bevel: bevel, seg: 1, mat: MaterialKey(stringLiteral: mat)))
    }

    /// Thin slab between two (z, y) points, `width` along X, tilted to follow the line.
    static func sloped(_ m: inout Model, from a: V2, to b: V2, width: Float, x: Float = 0, thick: Float = 0.03, mat: String) {
        let d = b - a, len = simd_length(d)
        let rot = simd_quatf(angle: atan2(d.x, d.y), axis: V3(1, 0, 0))
        K.box(&m, V3(x, (a.y + b.y) / 2, (a.x + b.x) / 2), V3(width, len, thick), mat, bevel: 0.004, rot: rot)
    }

    /// Wheel with axle along X centered at `x`: tire, alloy hub, brake disc.
    static func wheel(_ m: inout Model, x: Float, z: Float, r: Float, w: Float) {
        let q = simd_quatf(degrees: 90, axis: V3(0, 0, 1))
        m.add(Prim.cylinder(radius: r, height: w, bevel: 0.03, segments: 24, material: "rubber.tire"), Xform(translation: V3(x + w / 2, r, z), rotation: q))
        m.add(Prim.cylinder(radius: r * 0.58, height: w + 0.02, bevel: 0.008, segments: 20, material: "metal.aluminum-brushed"),
              Xform(translation: V3(x + (w + 0.02) / 2, r, z), rotation: q))
        m.add(Prim.cylinder(radius: r * 0.18, height: w + 0.04, bevel: 0.004, segments: 10, material: "metal.steel"),
              Xform(translation: V3(x + (w + 0.04) / 2, r, z), rotation: q))
    }
}
