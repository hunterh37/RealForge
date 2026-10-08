import simd
import Foundation

/// Pavement café set: a 60 cm round aluminum bistro table on a cast four-foot base and two
/// stacking chairs with tube frames, slatted seats and backs and rubber feet, pulled out at slightly
/// different angles.
public struct CafeTableSet: RealAsset {
    public static let id = "cafe-table-set"
    public static let summary = "Bistro café set: round aluminium table and two stacking chairs."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal", "furniture"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 18, distance: 1.1)

    /// Table top diameter and height (m).
    public var tableDiameter: Float = 0.6
    public var tableHeight: Float = 0.74
    /// Chair frame and slat materials.
    public var frame: MaterialKey = "metal.aluminum-brushed"
    public var slats: MaterialKey = "metal.powdercoat:3A4A3E"
    public var top: MaterialKey = "metal.aluminum-brushed"
    public init() {}

    func chair(_ m: inout Model, at p: V3, yaw: Float) {
        let x = Xform(translation: p, rotation: simd_quatf(angle: yaw, axis: .up))
        let sw: Float = 0.42, sd: Float = 0.42, sh: Float = 0.45, bh: Float = 0.84, r: Float = 0.011
        // Legs: front pair straight, rear pair rising into the back posts with a slight rake.
        for s: Float in [-1, 1] {
            let f0 = V3(s * sw / 2, 0.02, sd / 2), f1 = V3(s * sw / 2, sh, sd / 2 - 0.02)
            m.add(Prim.tube([f0, f1], radii: [r, r], sides: 8, seamTile: 0.05, material: frame), x)
            let b = [V3(s * (sw / 2), 0.02, -sd / 2 - 0.03), V3(s * sw / 2, sh, -sd / 2 + 0.02), V3(s * (sw / 2 - 0.01), bh, -sd / 2 - 0.05)]
            m.add(Prim.tube(catmull(b, per: 4), radii: Array(repeating: r, count: 9), sides: 8, seamTile: 0.05, material: frame), x)
            for f in [f0, b[0]] {
                m.add(Prim.cylinder(radius: r + 0.002, height: 0.02, bevel: 0.003, segments: 8, material: "rubber"), x.child(Xform(translation: f - V3(0, 0.02, 0))))
            }
        }
        // Seat frame and slats.
        m.add(Prim.tube([V3(-sw / 2, sh, sd / 2 - 0.02), V3(sw / 2, sh, sd / 2 - 0.02)], radii: [r, r], sides: 8, seamTile: 0.05, material: frame), x)
        m.add(Prim.tube([V3(-sw / 2, sh, -sd / 2 + 0.02), V3(sw / 2, sh, -sd / 2 + 0.02)], radii: [r, r], sides: 8, seamTile: 0.05, material: frame), x)
        for k in 0..<6 {
            let z = -sd / 2 + 0.05 + Float(k) * (sd - 0.1) / 5
            m.add(Prim.roundedBox(V3(sw + 0.01, 0.012, 0.05), radius: 0.004, bevelSegments: 1, material: slats), x.child(Xform(translation: V3(0, sh + 0.016, z))))
        }
        // Back slats, raked.
        for k in 0..<3 {
            let y = sh + 0.17 + Float(k) * 0.075, z = -sd / 2 + 0.02 - (y - sh) / (bh - sh) * 0.07
            m.add(Prim.roundedBox(V3(sw - 0.01, 0.05, 0.012), radius: 0.004, bevelSegments: 1, material: slats),
                  x.child(Xform(translation: V3(0, y, z), rotation: simd_quatf(degrees: -10, axis: V3(1, 0, 0)))))
        }
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = tableDiameter / 2, H = tableHeight
        // Table: cross base with four feet, column, rolled-edge top.
        for k in 0..<4 {
            let a = Float(k) * .pi / 2 + .pi / 4
            m.add(Prim.roundedBox(V3(0.24, 0.025, 0.05), radius: 0.008, bevelSegments: 2, material: "metal.diecast"),
                  Xform(translation: V3(cos(a), 0, -sin(a)) * 0.12 + V3(0, 0.03, 0), rotation: simd_quatf(angle: a, axis: .up)))
            m.add(Prim.cylinder(radius: 0.02, height: 0.018, bevel: 0.004, segments: 10, material: "rubber"), Xform(translation: V3(cos(a), 0, -sin(a)) * 0.22))
        }
        m.add(turned([(0, 0.02), (0.06, 0.02), (0.05, 0.06), (0.025, 0.09), (0.022, H - 0.06), (0.05, H - 0.03), (0.06, H - 0.02), (0, H - 0.02)], segments: 18, material: frame))
        m.add(turned([(0, H - 0.02), (R - 0.01, H - 0.02), (R, H - 0.012), (R + 0.004, H - 0.002), (R - 0.002, H + 0.002), (0, H + 0.002)], segments: 48, material: top))
        // Story detail: a coffee ring and a folded receipt on the top.
        m.add(Prim.torus(major: 0.035, minor: 0.002, segments: 20, sides: 3, minorY: 0.0003, material: "food.chocolate-melted"), Xform(translation: V3(0.1, H + 0.0025, -0.06)))
        m.add(cuboid(V3(0.06, 0.0008, 0.09), material: "paper.sheet"), Xform(translation: V3(-0.09, H + 0.003, 0.08), rotation: simd_quatf(angle: 0.4, axis: .up)))
        // Two chairs facing the table from either side.
        chair(&m, at: V3(-0.55, 0, rng.float(-0.06...0.06)), yaw: .pi / 2 + rng.float(-0.25...0.25))
        chair(&m, at: V3(0.55, 0, rng.float(-0.06...0.06)), yaw: -.pi / 2 + rng.float(-0.25...0.25))
        groundAO(&m, height: 0.15, floor: 0.6)
        let b = m.bounds, c = (b.min + b.max) / 2
        var out = Model(name: Self.id); out.add(m, Xform(translation: V3(-c.x, 0, -c.z)))
        return LODModel(out)
    }
}
