import simd
import Foundation

/// Rain chain: a copper cup-link chain 2.4 m long hanging from a gutter outlet bracket, 21 cups with
/// drip holes on a linked wire spine, ending in a pebble-filled basin. Hangs from y = 2.4 to the basin.
public struct RainChain: RealAsset {
    public static let id = "rain-chain"
    public static let summary = "Copper rain chain, 2.4 m: 21 cup links on a wire spine from an outlet bracket into a pebble basin."
    public static let tags = ["prop", "architecture", "facade", "metal", "garden"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 8, distance: 4.0)

    public var cups: Int = 21
    public var copper: MaterialKey = "metal.copper"
    public var aged: MaterialKey = "metal.copper-patina"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let n = cups, top: Float = 2.4, pitch: Float = 0.105, z: Float = 0.12
        // Outlet bracket on the gutter.
        FA.box(&m, V3(0.1, 0.04, 0.12), V3(0, top + 0.02, 0.06), aged, r: 0.004)
        m.add(Prim.torus(major: 0.026, minor: 0.005, segments: 14, sides: 6, material: aged), Xform(translation: V3(0, top, z)))
        FA.rod(&m, V3(0, top, z), V3(0, 0.12, z + rng.float(0...0.0)), r: 0.0025, "metal.steel", sides: 6)
        for i in 0..<n {
            let y = top - 0.06 - Float(i) * pitch
            let mat = i % 5 == 0 ? aged : copper
            // Cup: flared lathe with a rolled lip and a drip hole shown as a dark ring on the base.
            m.add(Prim.lathe([V2(0.0, 0.0), V2(0.012, 0.0), V2(0.02, 0.016), V2(0.034, 0.05), V2(0.037, 0.058), V2(0.034, 0.06), V2(0.029, 0.052), V2(0.016, 0.02), V2(0.0, 0.01)],
                             segments: 10, material: mat), Xform(translation: V3(0, y - 0.03, z), rotation: FA.q(rng.float(-2...2), FA.X)))
            FA.cylZ(&m, r: 0.003, h: 0.004, at: V3(0, y - 0.02, z), "metal.rust", bevel: 0.0005, segments: 6)
            m.add(Prim.torus(major: 0.008, minor: 0.0018, segments: 8, sides: 4, material: "metal.steel"), Xform(translation: V3(0, y + 0.036, z), rotation: FA.q(90, FA.X)))
        }
        // Basin with river pebbles.
        m.add(Prim.lathe([V2(0.0, 0.0), V2(0.18, 0.0), V2(0.26, 0.05), V2(0.27, 0.1), V2(0.25, 0.1), V2(0.24, 0.06), V2(0.0, 0.03)], segments: 28, material: "ceramic.stoneware"),
              Xform(translation: V3(0, 0, z)))
        for _ in 0..<26 {
            let p = rng.inDisc(radius: 0.2)
            m.add(Prim.superellipsoid(V3(0.05, 0.03, 0.04) * rng.float(0.8...1.3), exponent: 2, subdivisions: 3, material: "stone.sandstone"),
                  Xform(translation: V3(p.x, 0.05 + rng.float(0...0.015), z + p.y), rotation: FA.q(rng.float(0...180), FA.Y)))
        }
        groundAO(&m, height: 0.12, floor: 0.85)
        return LODModel(FC.place(m))
    }
}
