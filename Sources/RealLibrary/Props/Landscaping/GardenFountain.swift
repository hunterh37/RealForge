import simd
import Foundation

/// Three-tier cast-stone garden fountain, 1.3 m tall: 1.0 m ground basin with a rolled rim, fluted
/// pedestal, 0.62 m middle bowl and 0.36 m top bowl on turned columns, pineapple finial. Water stands in
/// each bowl and dribbles over the upper rims in thin streams; algae and mineral streaks darken the stone
/// below each lip.
public struct GardenFountain: RealAsset {
    public static let id = "garden-fountain"
    public static let summary = "Three-tier cast-stone garden fountain, 1.3 m: 1 m basin, fluted pedestal, two bowls on turned columns, finial, standing water and spill streams."
    public static let tags = ["prop", "garden", "outdoor", "landscaping", "stone", "water", "decor"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 12, distance: 1.05, studio: true)

    /// Ground basin outside diameter (m).
    public var basinDiameter: Float = 1.0
    /// Overall height scale (1 = 1.3 m).
    public var scale: Float = 1.0
    /// Stone material.
    public var stone: MaterialKey = "stone.cast-grey"
    /// Standing water material.
    public var water: MaterialKey = "water.pond"
    /// Spilling water material.
    public var spill: MaterialKey = "water.stream"
    /// Algae at the waterline.
    public var algae: MaterialKey = "moss.cushion:3A4A22"
    /// Show the water.
    public var showWater = true
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        let seg = 56, segL = 24
        func lathe(_ p: [(Float, Float)], liteToo: Bool = true) {
            m.add(turned(p, segments: seg, material: stone, seamTile: 0.5))
            if liteToo { lite.add(turned(p, segments: segL, material: stone, seamTile: 0.5)) }
        }
        func waterDisc(_ r: Float, _ y: Float) {
            guard showWater else { return }
            let s = Prim.lathe([V2(r, y), V2(0, y)], segments: seg, seamTile: 0.5, material: water)
            m.add(s); lite.add(Prim.lathe([V2(r, y), V2(0, y)], segments: segL, seamTile: 0.5, material: water))
        }
        func streams(rTop: Float, yTop: Float, yBot: Float, count: Int, _ r: inout SeededRNG) {
            guard showWater else { return }
            // Water spilling over the lip at scallop low points: thin falling ribbons, thicker at the lip.
            for i in 0..<count {
                let a = (Float(i) + r.float(-0.2...0.2)) / Float(count) * 2 * .pi
                let dir = V3(cos(a), 0, sin(a))
                let out = r.float(0.012...0.03)
                let pts = (0...6).map { k -> V3 in
                    let t = Float(k) / 6
                    return dir * (rTop + out * sqrt(t) * 1.4) + V3(0, yTop - (yTop - yBot) * t, 0)
                }
                let w = r.float(0.004...0.008)
                m.add(Prim.tube(pts, radii: pts.indices.map { k in w * (1 - Float(k) / 6 * 0.5) }, sides: 6, seamTile: 0.1, material: spill))
                // Ring of ripples where it lands.
                m.add(Prim.torus(major: w * 2.2, minor: 0.0018, segments: 10, sides: 4, material: spill), Xform(translation: pts[6] + V3(0, 0.001, 0)))
            }
        }
        let R = basinDiameter / 2, k = scale
        // Ground basin: rolled rim, inner wall, floor.
        let bh: Float = 0.32 * k
        lathe([(0, 0.0), (R - 0.03, 0.0), (R - 0.01, 0.01), (R, 0.04), (R - 0.015, bh - 0.06), (R + 0.01, bh - 0.04), (R + 0.02, bh - 0.015),
               (R + 0.005, bh), (R - 0.03, bh + 0.005), (R - 0.055, bh - 0.02), (R - 0.07, 0.09), (R - 0.09, 0.07), (0, 0.07)])
        waterDisc(R - 0.058, bh - 0.04)
        // Algae band at the basin waterline and a mineral stain band under the middle bowl's lip.
        m.add(Prim.lathe([V2(R - 0.0585, bh - 0.055), V2(R - 0.0575, bh - 0.03)], segments: seg, seamTile: 0.3, material: algae))
        // Fluted pedestal: lathe core plus vertical flutes as thin raised ribs.
        let pTop: Float = 0.62 * k
        lathe([(0, 0.069), (0.17, 0.069), (0.17, 0.11), (0.14, 0.13), (0.11, 0.17), (0.095, 0.25), (0.09, pTop - 0.08), (0.11, pTop - 0.05), (0.14, pTop - 0.02), (0.14, pTop), (0, pTop)])
        for i in 0..<12 {
            let a = Float(i) / 12 * 2 * .pi
            let rib = Prim.roundedBox(V3(0.018, pTop - 0.33, 0.012), radius: 0.005, bevelSegments: 1, material: stone)
            m.add(rib, Xform(translation: V3(cos(a) * 0.093, 0.25 + (pTop - 0.33) / 2 + 0.02, sin(a) * 0.093), rotation: simd_quatf(angle: -a, axis: .up)))
        }
        // Middle bowl: shallow bowl with a scalloped look via a thick rim torus.
        let r2: Float = 0.31 * k, y2 = pTop
        lathe([(0, y2), (0.13, y2), (0.2, y2 + 0.04), (r2 - 0.03, y2 + 0.1), (r2, y2 + 0.13), (r2 + 0.005, y2 + 0.15), (r2 - 0.012, y2 + 0.16),
               (r2 - 0.03, y2 + 0.14), (0.18, y2 + 0.09), (0, y2 + 0.08)])
        waterDisc(r2 - 0.025, y2 + 0.145)
        // Upper column and bowl.
        let c2: Float = y2 + 0.08, c2Top: Float = c2 + 0.34 * k
        lathe([(0, c2), (0.08, c2), (0.08, c2 + 0.03), (0.055, c2 + 0.06), (0.05, c2 + 0.15), (0.065, c2 + 0.2), (0.05, c2 + 0.25), (0.06, c2Top - 0.03), (0.08, c2Top), (0, c2Top)])
        let r3: Float = 0.18 * k, y3 = c2Top
        lathe([(0, y3), (0.07, y3), (0.12, y3 + 0.03), (r3 - 0.015, y3 + 0.07), (r3, y3 + 0.09), (r3 + 0.004, y3 + 0.105), (r3 - 0.01, y3 + 0.112),
               (r3 - 0.022, y3 + 0.095), (0.1, y3 + 0.06), (0, y3 + 0.055)])
        waterDisc(r3 - 0.018, y3 + 0.1)
        // Finial: pineapple-ish turned spout.
        let f0 = y3 + 0.055
        lathe([(0, f0), (0.035, f0), (0.03, f0 + 0.03), (0.02, f0 + 0.05), (0.035, f0 + 0.08), (0.04, f0 + 0.11), (0.03, f0 + 0.14), (0.012, f0 + 0.165), (0.006, f0 + 0.18), (0, f0 + 0.18)])
        // Spill curtains from the two bowls.
        streams(rTop: r3 + 0.004, yTop: y3 + 0.104, yBot: y2 + 0.146, count: 8, &rng)
        streams(rTop: r2 + 0.006, yTop: y2 + 0.15, yBot: bh - 0.04, count: 12, &rng)
        let bb = m.bounds
        let shift = V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)
        m = m.transformed(Xform(translation: shift)); lite = lite.transformed(Xform(translation: shift))
        groundAO(&m, height: 0.2, floor: 0.55); groundAO(&lite, height: 0.2, floor: 0.55)
        return LODModel(levels: [m, lite], switchDistances: [12])
    }
}
