import simd
import Foundation

/// Low-profile full-size keyboard and mouse as they sit on a desk: 430 x 125 mm wedge case (9 mm front,
/// 19 mm back) with 104 ANSI keys in their real rows (function row in groups of four, navigation cluster,
/// inverted-T arrows, numeric pad with tall plus and enter), each row tipped a little more toward the
/// typist; a right-hand mouse with split buttons, rubber scroll wheel and a flat skirt sits to the right.
public struct KeyboardMouse: RealAsset {
    public static let id = "keyboard-mouse"
    public static let summary = "Low-profile full-size keyboard with 104 ANSI keys in real rows on a wedge case, plus a right-hand mouse with scroll wheel."
    public static let tags = ["prop", "office", "electronics", "plastic"]
    public static let budget = 9_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 18, elevation: 38, distance: 0.75, studio: true)

    public var caseMaterial: MaterialKey = "metal.anodized"
    public var keyMaterial: MaterialKey = "plastic.matte:2A2B2D"
    public var mouseMaterial: MaterialKey = "plastic.matte:2E2F32"
    /// Key pitch (m), 19.05 mm on standard boards, 18.5 on compact low-profile ones.
    public var pitch: Float = 0.0186
    public var mouse = true
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var levels: [Model] = []
        for l in 0..<2 {
            var rng = SeededRNG(seed: seed)
            var m = Model(name: Self.id)
            let p = pitch, W: Float = 22.5 * p + 0.014, D: Float = 6.25 * p + 0.012
            let hf: Float = 0.009, hb: Float = 0.019
            // Case: wedge section extruded along X.
            let section = Shape2D.rounded([V2(D / 2, 0), V2(D / 2, hf), V2(-D / 2, hb), V2(-D / 2, 0)], radius: 0.0035, segments: l == 0 ? 3 : 1)
            m.add(Prim.extrude(section, depth: W, bevel: l == 0 ? 0.0025 : 0.0015, bevelSegments: l == 0 ? 2 : 1, material: caseMaterial),
                  Xform(rotation: simd_quatf(degrees: -90, axis: .up)))
            let slope = atan((hb - hf) / D)
            func deckY(_ z: Float) -> Float { hf + (D / 2 - z) / D * (hb - hf) - 0.0006 }
            // Dark deck plate the keys rise from.
            let deckQ = simd_quatf(angle: slope, axis: V3(1, 0, 0)) * simd_quatf(degrees: -90, axis: V3(1, 0, 0))
            m.add(Prim.extrude(Shape2D.roundedRect(22.5 * p + 0.003, 6.25 * p + 0.003, radius: 0.002, segments: 1), depth: 0.0008, bevel: 0, material: "plastic.black"),
                  Xform(translation: V3(0, deckY(0) + 0.0002, 0), rotation: deckQ))
            // Rubber feet.
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                m.add(Prim.cylinder(radius: 0.006, height: 0.0012, bevel: 0.0004, segments: 10, bevelSegments: 1, material: "rubber"),
                      Xform(translation: V3(sx * (W / 2 - 0.03), -0.0008, sz * (D / 2 - 0.018))))
            }}
            // Keys: (x in units, row, width units, height units).
            var keys: [(Float, Int, Float, Float)] = []
            func run(_ x0: Float, _ row: Int, _ widths: [Float]) { var x = x0; for w in widths { keys.append((x, row, w, 1)); x += w } }
            run(0, 0, [1]); run(2, 0, [1, 1, 1, 1]); run(6.5, 0, [1, 1, 1, 1]); run(11, 0, [1, 1, 1, 1]); run(15.25, 0, [1, 1, 1])
            run(0, 1, Array(repeating: 1, count: 13) + [2]); run(15.25, 1, [1, 1, 1]); run(18.5, 1, [1, 1, 1, 1])
            run(0, 2, [1.5] + Array(repeating: 1, count: 12) + [1.5]); run(15.25, 2, [1, 1, 1]); run(18.5, 2, [1, 1, 1]); keys.append((21.5, 2, 1, 2))
            run(0, 3, [1.75] + Array(repeating: 1, count: 11) + [2.25]); run(18.5, 3, [1, 1, 1])
            run(0, 4, [2.25] + Array(repeating: 1, count: 10) + [2.75]); run(16.25, 4, [1]); run(18.5, 4, [1, 1, 1]); keys.append((21.5, 4, 1, 2))
            run(0, 5, [1.25, 1.25, 1.25, 6.25, 1.25, 1.25, 1.25, 1.25]); run(15.25, 5, [1, 1, 1]); run(18.5, 5, [2, 1])
            let rowTilt: [Float] = [-4, -3, -1.5, 0, 2, 3.5]      // sculpted rows (degrees about X, + tips toward the typist)
            let gap: Float = 0.0032, capH: Float = 0.0032
            var caps = Surface(material: keyMaterial)
            let x0 = -22.5 * p / 2, z0 = -6.25 * p / 2
            for (ux, row, uw, uh) in keys {
                let rowZ = z0 + (row == 0 ? 0 : 0.25 * p + Float(row) * p)
                let cx = x0 + (ux + uw / 2) * p, cz = rowZ + uh * p / 2
                let w = uw * p - gap, h = uh * p - gap
                let rot = simd_quatf(angle: slope + radians(rowTilt[row] * (uh > 1 ? 0.5 : 1)), axis: V3(1, 0, 0)) * simd_quatf(degrees: -90, axis: V3(1, 0, 0))
                if l == 0 {
                    // Caps narrow slightly toward the top (two stacked extrusions read as a draft).
                    let cap = Prim.extrude(Shape2D.roundedRect(w, h, radius: 0.0022, segments: 1), depth: capH, bevel: 0.0009, bevelSegments: 1, material: keyMaterial)
                    caps.append(cap, Xform(translation: V3(cx, deckY(cz) + capH / 2, cz), rotation: rot).jittered(&rng, deg: 0.15, offset: 0.00004))
                }
            }
            if l == 0 { m.add(caps) } else {
                m.add(Prim.extrude(Shape2D.roundedRect(22.5 * p - 0.002, 6.25 * p - 0.002, radius: 0.002, segments: 1), depth: capH, bevel: 0.0008,
                                   bevelSegments: 1, material: keyMaterial), Xform(translation: V3(0, deckY(0) + capH / 2, 0), rotation: deckQ))
            }
            // Status LED strip above the numeric pad.
            if l == 0 {
                for k in 0..<3 {
                    m.add(Prim.roundedBox(V3(0.003, 0.0006, 0.0018), radius: 0.0002, bevelSegments: 1, material: "plastic.white"),
                          Xform(translation: V3(x0 + (19 + Float(k)) * p, deckY(z0 + 0.4 * p) + 0.0008, z0 + 0.4 * p), rotation: simd_quatf(angle: slope, axis: V3(1, 0, 0))))
                }
            }
            if mouse {
                // Mouse: squashed superellipsoid shell, high at the palm, flat skirt, split buttons, wheel.
                var shell = Prim.superellipsoid(V3(0.063, 0.074, 0.116), exponent: 2.4, subdivisions: l == 0 ? 8 : 3, material: mouseMaterial)
                shell.deform { q in
                    let t = q.z / 0.116 + 0.5                          // 0 front (buttons) ... 1 palm
                    var y = q.y < 0 ? q.y * 0.08 : q.y * (0.62 + 0.38 * sin(.pi * min(1, t * 1.05 + 0.05)))
                    y += 0.003
                    let x = q.x * (0.86 + 0.14 * t) + (q.y > 0 ? -0.004 * q.y / 0.037 : 0)
                    return V3(x, max(0, y), q.z)
                }
                let mx = W / 2 + 0.07, mz: Float = 0.01
                let mq = simd_quatf(degrees: -6, axis: .up)
                m.add(shell, Xform(translation: V3(mx, 0, mz), rotation: mq))
                if l == 0 {
                    // Button split and scroll wheel in the front third.
                    m.add(Prim.roundedBox(V3(0.0012, 0.004, 0.04), radius: 0.0004, bevelSegments: 1, material: "plastic.black"),
                          Xform(translation: V3(mx, 0.0312, mz - 0.036), rotation: mq * simd_quatf(degrees: -10, axis: V3(1, 0, 0))))
                    m.add(Prim.cylinder(radius: 0.0105, height: 0.007, bevel: 0.0015, segments: 18, bevelSegments: 1, material: "rubber"),
                          Xform(translation: V3(mx - 0.0035, 0.0245, mz - 0.034), rotation: mq * simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
                }
            }
            let bb = m.bounds
            m = m.transformed(Xform(translation: V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)))
            groundAO(&m, height: 0.01, floor: 0.6)
            levels.append(m)
        }
        return LODModel(levels: levels, switchDistances: [4])
    }
}
