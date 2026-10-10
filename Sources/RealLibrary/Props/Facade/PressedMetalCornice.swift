import simd
import Foundation

/// Pressed-metal cornice: a stepped crown (bed, corona with drip, ogee fascia) swept 2.4 m along the
/// wall, with modillion blocks under the corona, a panel seam at mid span and mitred end returns.
/// Painted sheet steel, slightly buckled along the corona.
public struct PressedMetalCornice: RealAsset {
    public static let id = "pressed-metal-cornice"
    public static let summary = "Pressed-metal cornice, 2.4 m run: stepped crown profile, modillion blocks and end returns."
    public static let tags = ["prop", "architecture", "facade", "trim", "metal"]
    public static let budget = 9_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: -10, distance: 2.4)

    public var length: Float = 2.4
    public var height: Float = 0.6
    public var projection: Float = 0.5
    public var paint: MaterialKey = "metal.painted:D9D2C0"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, H = height, P = projection
        let prof: [V2] = [V2(0, 0), V2(0.1 * P, 0), V2(0.12 * P, 0.1 * H), V2(0.55 * P, 0.28 * H), V2(0.58 * P, 0.36 * H), V2(0.94 * P, 0.4 * H),
                          V2(P, 0.43 * H), V2(P, 0.5 * H), V2(0.96 * P, 0.56 * H), V2(0.98 * P, 0.7 * H), V2(0.9 * P, 0.78 * H),
                          V2(0.7 * P, 0.86 * H), V2(0.5 * P, 0.94 * H), V2(0.5 * P, H), V2(0, H)]
        FA.run(&m, prof, length: L, paint, bevel: 0.002)
        let n = Int(L / 0.2)
        for i in 0..<n {
            let x = -(Float(n - 1) * 0.2) / 2 + Float(i) * 0.2
            FA.box(&m, V3(0.06, 0.14 * H + 0.07, 0.3 * P), V3(x, 0.17 * H + 0.04, 0.16 * P), paint, r: 0.003)
            FA.box(&m, V3(0.07, 0.01, 0.3 * P + 0.01), V3(x, 0.17 * H + 0.04 - 0.07 * 0.9, 0.16 * P), paint, r: 0.002)
        }
        // Seam strap and buckle.
        FA.box(&m, V3(0.05, H * 0.5, 0.006), V3(rng.float(-0.1...0.1), H * 0.74, P * 0.6), "metal.painted:C3BBA8", r: 0.001, rot: FA.q(-30, FA.X))
        // End returns.
        for e: Float in [-1, 1] {
            m.add(Prim.extrude(prof, depth: 0.004, bevel: 0.001, bevelSegments: 1, material: paint), Xform(translation: V3(e * (L / 2 + 0.002), 0, 0), rotation: FA.q(-90, FA.Y)))
        }
        groundAO(&m, height: 0.1, floor: 0.85)
        return LODModel(FA.centerZ(m))
    }
}
