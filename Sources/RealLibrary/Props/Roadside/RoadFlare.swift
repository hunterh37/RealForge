import simd
import Foundation

/// Incendiary road flare standing on its wire stand: red wrapped body, white label band, striker cap, burning tip.
public struct RoadFlare: RealAsset {
    public static let id = "road-flare"
    public static let summary = "Standing 30 cm incendiary road flare on a wire stand: red paper-wrapped body, striker cap, burning tip with bright red flame."
    public static let tags = ["prop", "road", "light", "outdoor", "handheld"]
    public static let budget = 4500
    public static let author = "realityhd"

    /// Body length in meters.
    public var length: Float = 0.30
    /// Body radius in meters (32 mm flare).
    public var radius: Float = 0.016
    /// Wrapper color.
    public var bodyMaterial = "plastic.orange:B3141A"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let r = radius, y0: Float = 0.045, y1 = y0 + length
        // Wire stand: folded legs with a cradle ring.
        let leg: Float = 0.085
        for k in 0..<3 {
            let a = Float(k) * 2 * .pi / 3 + 0.5
            let foot = V3(cos(a) * leg, 0.002, sin(a) * leg)
            m.add(Prim.tube([foot, V3(cos(a) * 0.02, y0 - 0.012, sin(a) * 0.02), V3(cos(a) * r * 1.05, y0 + 0.012, sin(a) * r * 1.05)],
                            radii: [0.0016, 0.0016, 0.0016], sides: 6, seamTile: 0.05, material: "metal.steel", capEnd: true))
        }
        m.add(Prim.torus(major: r * 1.07, minor: 0.0017, segments: 24, sides: 6, material: "metal.steel"), Xform(translation: V3(0, y0 + 0.012, 0)))
        m.add(Prim.torus(major: r * 1.07, minor: 0.0017, segments: 24, sides: 6, material: "metal.steel"), Xform(translation: V3(0, y0 + 0.07, 0)))
        // Body: spike end cap, wrapped tube, white label band, black striker cap at the top.
        m.add(turned([(0, y0 - 0.004), (r * 0.7, y0 - 0.004), (r * 0.98, y0 + 0.01), (r, y0 + 0.02), (r, y1 - 0.06)], segments: 28, material: bodyMaterial, seamTile: 0.1))
        m.add(turned([(r * 1.002, y0 + 0.095), (r * 1.002, y0 + 0.165)], segments: 28, material: "plastic.white", seamTile: 0.1))
        // Label bars (type warning stripes) on the white band.
        for k in 0..<3 {
            m.add(Prim.roundedBox(V3(0.004, 0.012, 0.0016), radius: 0.0004, bevelSegments: 1, material: "plastic.black"),
                  Xform(translation: V3(Float(k - 1) * 0.009, y0 + 0.13, r * 1.004)))
        }
        m.add(turned([(r, y1 - 0.06), (r * 1.06, y1 - 0.058), (r * 1.06, y1 - 0.012), (r * 0.9, y1 - 0.005), (r * 0.75, y1)], segments: 28, material: "plastic.black", seamTile: 0.1))
        // Burning tip: glowing core, flame cone, scorched paper crown.
        m.add(turned([(r * 0.74, y1), (r * 0.66, y1 + 0.006), (r * 0.5, y1 + 0.012), (0, y1 + 0.014)], segments: 20, material: "emissive.signal-red"))
        for k in 0..<5 {
            let a = Float(k) * 2 * .pi / 5 + rng.float(0...1)
            let h = 0.045 + rng.float(0...0.03)
            let base = V3(cos(a) * r * 0.35, y1 + 0.008, sin(a) * r * 0.35)
            let tip = V3(cos(a) * 0.004, y1 + 0.008 + h, sin(a) * 0.004)
            m.add(Prim.tube([base, (base + tip) * 0.5 + V3(rng.float(-0.004...0.004), 0, rng.float(-0.004...0.004)), tip], radii: [0.0085, 0.006, 0.0008], sides: 8, seamTile: 0.1, material: "emissive.signal-red", capEnd: true))
        }
        // Ash crust at the burning face, soot ring under the cap, and flying sparks.
        m.add(Prim.superellipsoid(V3(r * 1.3, 0.012, r * 1.3), exponent: 3, subdivisions: 6, material: "wood.ash"), Xform(translation: V3(0, y1 + 0.004, 0)))
        m.add(turned([(r * 1.002, y1 - 0.075), (r * 1.002, y1 - 0.062)], segments: 28, material: "plastic.black", seamTile: 0.1))
        for k in 0..<7 {
            let a = rng.float(0...(2 * .pi)), d = rng.float(0.01...0.05)
            m.add(Prim.superellipsoid(V3(0.0025, 0.0025, 0.0025), exponent: 2, subdivisions: 2, material: "emissive.signal-orange"),
                  Xform(translation: V3(cos(a) * d, y1 + 0.03 + rng.float(0...0.1), sin(a) * d)))
        }
        groundAO(&m, height: 0.06, floor: 0.6)
        return LODModel(m)
    }
}
