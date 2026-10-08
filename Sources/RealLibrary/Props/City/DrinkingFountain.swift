import simd
import Foundation

/// Park pedestal drinking fountain: a powder-coated steel column on a cast base plate, a stainless
/// bowl with a chrome bubbler and guard, a front push button and a grated drain. Scuffed paint at
/// shoe height and a mineral stain under the bubbler.
public struct DrinkingFountain: RealAsset {
    public static let id = "drinking-fountain"
    public static let summary = "Pedestal drinking fountain: powder-coated steel column with a stainless bowl, bubbler and push button."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal", "water"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20, distance: 1.1)

    /// Bowl rim height (m).
    public var height: Float = 0.92
    /// Bowl radius (m).
    public var bowlRadius: Float = 0.22
    /// Column paint.
    public var paint: MaterialKey = "metal.powdercoat:2E4A36"
    public var stainless: MaterialKey = "metal.stainless"
    public var chrome: MaterialKey = "metal.chrome"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let h = height, R = bowlRadius
        // Base plate with bolts.
        m.add(Prim.roundedBox(V3(0.36, 0.015, 0.36), radius: 0.006, bevelSegments: 2, material: paint), Xform(translation: V3(0, 0.0075, 0)))
        for k in 0..<4 { let a = Float(k) * .pi / 2 + .pi / 4
            hexBolt(&m, at: V3(cos(a) * 0.21, 0.015, sin(a) * 0.21), normal: .up, size: 0.016, material: "metal.steel") }
        // Column: fluted lathe, tapering out into the bowl skirt.
        m.add(turned([(0.0, 0.015), (0.11, 0.015), (0.11, 0.05), (0.095, 0.08), (0.085, 0.15), (0.075, h - 0.22), (0.09, h - 0.15), (0.15, h - 0.1),
                      (R - 0.01, h - 0.06), (R, h - 0.05), (0, h - 0.05)], segments: 28, material: paint))
        // Stainless bowl: rolled rim, shallow dish, drain.
        m.add(Prim.lathe([V2(R - 0.004, h - 0.052), V2(R + 0.006, h - 0.04), V2(R + 0.008, h), V2(R, h + 0.008), V2(R - 0.012, h), V2(R - 0.03, h - 0.03),
                          V2(0.05, h - 0.05), V2(0.0, h - 0.052)], segments: 40, seamTile: 0.2, material: stainless))
        m.add(Prim.cylinder(radius: 0.022, height: 0.003, bevel: 0.001, segments: 14, material: "metal.steel:2A2A2A"), Xform(translation: V3(0, h - 0.052, 0)))
        // Bubbler with a guard hoop, offset back.
        let bz: Float = -0.06
        m.add(turned([(0.0, h - 0.05), (0.018, h - 0.05), (0.016, h + 0.02), (0.012, h + 0.05), (0.008, h + 0.06), (0, h + 0.06)], segments: 16, material: chrome), Xform(translation: V3(0, 0, bz)))
        m.add(Prim.torus(major: 0.03, minor: 0.004, segments: 20, sides: 6, arc: .pi, material: chrome),
              Xform(translation: V3(0, h + 0.03, bz), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Mineral stain on the bowl under the bubbler.
        m.add(Prim.cylinder(radius: 0.035, height: 0.001, bevel: 0.0004, segments: 14, material: "concrete.smooth:C8C2B4"), Xform(translation: V3(0, h - 0.045, bz + 0.03)))
        // Push button on the front of the skirt.
        let px = Xform(translation: V3(0, h - 0.11, 0.13), rotation: simd_quatf(degrees: 60, axis: V3(1, 0, 0)))
        m.add(Prim.cylinder(radius: 0.026, height: 0.012, bevel: 0.003, segments: 18, material: stainless), px)
        m.add(Prim.cylinder(radius: 0.019, height: 0.02, bevel: 0.004, segments: 18, material: chrome), px)
        // Scuffs at shoe height: bare steel nicks.
        for _ in 0..<6 {
            let a = rng.float(0...6.28), y = rng.float(0.06...0.2)
            m.add(cuboid(V3(rng.float(0.006...0.02), rng.float(0.003...0.008), 0.0008), material: "metal.steel"),
                  Xform(translation: V3(sin(a) * 0.0905, y, cos(a) * 0.0905), rotation: simd_quatf(angle: a, axis: .up)))
        }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
