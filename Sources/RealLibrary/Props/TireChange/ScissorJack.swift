import simd
import Foundation

/// Stamped-steel scissor jack, partly raised: saddle, four paired arms, lead screw with crank eye, base plate.
public struct ScissorJack: RealAsset {
    public static let id = "scissor-jack"
    public static let summary = "Stamped-steel scissor jack, collapsed: saddle, four arms, lead screw with crank eye, base plate."
    public static let tags = ["prop", "tool", "vehicle", "metal", "handheld"]
    public static let budget = 12000
    public static let author = "realityhd"

    /// Diamond half-width (pivot to center) in meters.
    public var halfSpan: Float = 0.125
    /// Closed height at the saddle in meters.
    public var raise: Float = 0.1
    /// Width across the twin arm plates in meters.
    public var width: Float = 0.085
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let d = halfSpan, h = raise
        let base: Float = 0.006, saddleY = base + h
        // Diamond vertices in XY: bottom, top, left and right pivots (lead screw axis).
        let B = V3(0, base + 0.008, 0), T = V3(0, saddleY - 0.008, 0)
        let Lp = V3(-d, (B.y + T.y) / 2, 0), Rp = V3(d, (B.y + T.y) / 2, 0)
        let planes: [Float] = [-width / 2 + 0.008, width / 2 - 0.008]
        func arm(_ a: V3, _ b: V3, z: Float) {
            let dv = b - a
            let len = simd_length(dv)
            let ang = atan2(dv.y, dv.x)
            let mid = (a + b) / 2
            // U-channel arm: web plus two stiffening flanges, rounded ends.
            let q = simd_quatf(angle: ang, axis: V3(0, 0, 1))
            m.add(Prim.roundedBox(V3(len + 0.016, 0.026, 0.0035), radius: 0.0012, bevelSegments: 1, material: "metal.powdercoat:1B1C1E"), Xform(translation: V3(mid.x, mid.y, z), rotation: q))
            for s: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(len, 0.004, 0.012), radius: 0.0012, bevelSegments: 1, material: "metal.powdercoat:1B1C1E"),
                      Xform(translation: V3(mid.x, mid.y, z) + q.act(V3(0, s * 0.013, 0.0055)), rotation: q))
            }
        }
        for z in planes {
            arm(B, Lp, z: z); arm(B, Rp, z: z); arm(T, Lp, z: z); arm(T, Rp, z: z)
        }
        // Pivot pins with domed heads at the four vertices, both sides.
        for v in [B, T, Lp, Rp] {
            for z in planes {
                m.add(Prim.cylinder(radius: 0.0075, height: 0.004, bevel: 0.0012, segments: 14, material: "metal.screw-zinc"),
                      Xform(translation: V3(v.x, v.y, z + (z < 0 ? -0.0058 : 0.0018)), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
        }
        // Base plate with side lips.
        m.add(Prim.roundedBox(V3(0.19, base, width + 0.025), radius: 0.002, bevelSegments: 1, material: "metal.rust"), Xform(translation: V3(0, base / 2, 0)))
        for s: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.19, 0.012, 0.004), radius: 0.0012, bevelSegments: 1, material: "metal.rust"), Xform(translation: V3(0, base + 0.004, s * (width / 2 + 0.0105))))
        }
        // Grease on the screw: dark smear over the middle turns, plus a drip on the base.
        m.add(Prim.tube([V3(-d + 0.03, Lp.y, 0), V3(d - 0.02, Lp.y, 0)], radii: [0.0064, 0.0064], sides: 10, seamTile: 0.04, material: "plastic.black", capEnd: true))
        // Saddle plate with three grip ridges.
        m.add(Prim.roundedBox(V3(0.1, 0.008, width + 0.01), radius: 0.002, bevelSegments: 1, material: "metal.powdercoat:1B1C1E"), Xform(translation: V3(0, saddleY + 0.004 - 0.001, 0)))
        for i in -1...1 {
            m.add(Prim.roundedBox(V3(0.012, 0.004, width), radius: 0.0012, bevelSegments: 1, material: "metal.steel"), Xform(translation: V3(Float(i) * 0.028, saddleY + 0.009, 0)))
        }
        // Lead screw through the side pivots, thread coil, nuts at the ends, crank eye on +X.
        let sy = Lp.y
        let x0 = -d - 0.03, x1 = d + 0.07
        m.add(Prim.tube([V3(x0, sy, 0), V3(x1, sy, 0)], radii: [0.0058, 0.0058], sides: 12, seamTile: 0.04, material: "metal.screw-zinc", capEnd: true))
        var tx = x0 + 0.004
        while tx < x1 - 0.004 {
            m.add(Prim.cylinder(radius: 0.0066, height: 0.0016, bevel: 0.0005, segments: 8, material: "metal.screw-zinc"),
                  Xform(translation: V3(tx, sy, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
            tx += 0.011
        }
        for v in [Lp, Rp] {
            m.add(Prim.roundedBox(V3(0.014, 0.019, 0.019), radius: 0.003, bevelSegments: 1, material: "metal.steel"), Xform(translation: V3(v.x, v.y, 0)))
        }
        m.add(Prim.torus(major: 0.0115, minor: 0.0034, segments: 20, sides: 8, material: "metal.steel"),
              Xform(translation: V3(x1 + 0.006, sy, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 1, 0))))
        m.add(Prim.cylinder(radius: 0.0075, height: 0.01, bevel: 0.002, segments: 14, material: "metal.steel"),
              Xform(translation: V3(x1 - 0.006, sy, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        var out = Model(name: Self.id)
        out.add(m, Xform(rotation: simd_quatf(degrees: rng.float(-3...3), axis: V3(0, 1, 0))))
        let b = out.bounds
        out = out.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&out, height: 0.03, floor: 0.5)
        return LODModel(out)
    }
}
