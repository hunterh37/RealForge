import simd
import Foundation

/// Grass clump: 3 crossed alpha cards with bottom-anchored wind weights. Instance by the thousand.
public struct GrassClump: RealAsset {
    public static let id = "grass-clump"
    public static let summary = "Three crossed grass-blade cards, wind-weighted from root to tip."
    public static let tags = ["nature", "grass", "foliage"]
    public static let budget = 64
    public var height: Float = 0.42
    public var width: Float = 0.5
    public var material: MaterialKey = "grass.meadow"
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var s = Surface(material: material)
        let phase = rng.float(0...6.28)
        for k in 0..<3 {
            let a = Float(k) * 60 + rng.float(-10...10)
            var c = Prim.card(width: width * rng.vary(1, 0.15), height: height * rng.vary(1, 0.2), cell: (V2(0, 0), V2(1, 1)), material: material, normal: .up)
            c.extra = [V2(0, phase), V2(0, phase), V2(1, phase), V2(1, phase)]
            c.occlusion = [0.55, 0.55, 1, 1]
            // Up-facing normals light grass like a lawn instead of like flat cards.
            c.normals = [V3(0, 1, 0), V3(0, 1, 0), simd_normalize(V3(0.15, 1, 0)), simd_normalize(V3(-0.15, 1, 0))]
            s.append(c, Xform(rotation: simd_quatf(degrees: a, axis: .up)))
        }
        s.computeTangents()
        let m = Model(name: Self.id, surfaces: [s])
        return LODModel(levels: [m], switchDistances: [])
    }
}
