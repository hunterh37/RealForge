import simd
import Foundation

/// Cut-stone lintel: four limestone voussoir blocks with 4 mm joints and a keystone that drops below
/// and rises above the lintel. Block heights vary a few millimetres; the sooting is in the material.
public struct KeystoneLintel: RealAsset {
    public static let id = "keystone-lintel"
    public static let summary = "Cut-stone window lintel, 1.4 m, with projecting keystone and flanking skewbacks."
    public static let tags = ["prop", "architecture", "facade", "trim", "stone"]
    public static let budget = 6_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 10, distance: 1.4)

    public var width: Float = 1.4
    public var blockHeight: Float = 0.22
    public var depth: Float = 0.14
    public var keystoneWidth: Float = 0.2
    public var stone: MaterialKey = "stone.limestone"
    public var keystoneStone: MaterialKey = "stone.limestone-sooted"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, H = blockHeight, D = depth, k = keystoneWidth, joint: Float = 0.004
        let yb: Float = 0.1
        let side = (W - k) / 2
        for e: Float in [-1, 1] {
            let outer = side * 0.45, inner = side - outer
            for (i, w) in [outer, inner].enumerated() {
                let x0 = i == 0 ? W / 2 - outer / 2 : W / 2 - outer - inner / 2
                let h = H + rng.float(-0.003...0.003)
                FA.box(&m, V3(w - joint, h, D), V3(e * x0, yb + H / 2, D / 2), stone, r: 0.004)
            }
        }
        let ks = [V2(-k / 2 - 0.008, 0), V2(k / 2 + 0.008, 0), V2(k / 2 + 0.03, H + 0.12), V2(-k / 2 - 0.03, H + 0.12)]
        m.add(Prim.extrude(Shape2D.rounded(ks, radius: 0.004), depth: D + 0.025, bevel: 0.004, bevelSegments: 1, material: keystoneStone),
              Xform(translation: V3(0, 0, (D + 0.025) / 2)))
        groundAO(&m, height: 0.1, floor: 0.8)
        return LODModel(FA.centerZ(m))
    }
}
