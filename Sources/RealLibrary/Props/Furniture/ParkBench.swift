import simd
import Foundation

public struct ParkBench: RealAsset {
    public static let id = "park-bench"
    public static let summary = "Cast-iron frame park bench with oak seat and back slats."
    public static let tags = ["prop", "urban", "furniture", "wood", "metal"]
    public static let budget = 12_000
    public var length: Float = 1.6
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let iron: MaterialKey = "metal.iron"
        // Side frames: leg + seat support + back post + armrest, as tubes.
        for sx: Float in [-1, 1] {
            let x = sx * (length / 2 - 0.12)
            let front: [V3] = [V3(x, 0, 0.24), V3(x, 0.2, 0.22), V3(x, 0.42, 0.2), V3(x, 0.6, 0.22), V3(x, 0.64, 0.12), V3(x, 0.62, -0.05)]
            let rear: [V3] = [V3(x, 0, -0.26), V3(x, 0.2, -0.22), V3(x, 0.42, -0.2), V3(x, 0.6, -0.27), V3(x, 0.85, -0.34)]
            let seatRail: [V3] = [V3(x, 0.42, 0.24), V3(x, 0.43, 0), V3(x, 0.41, -0.22)]
            for path in [front, rear, seatRail] {
                let smooth = catmull(path, per: 6)
                m.add(Prim.tube(smooth, radii: smooth.map { _ in 0.022 }, sides: 10, seamTile: 0.2, material: iron))
            }
            // Feet pads.
            for z: Float in [0.24, -0.26] { m.add(Prim.roundedBox(V3(0.07, 0.02, 0.09), radius: 0.006, material: iron), Xform(translation: V3(x, 0.01, z))) }
        }
        // Seat slats.
        for i in 0..<5 {
            let z = 0.22 - Float(i) * 0.105
            m.add(plank(length, 0.085, 0.032, bevel: 0.006, material: "wood.oak"), Xform(translation: V3(0, 0.445 + Float(i) * 0.002, z)).jittered(&rng, deg: 0.3))
        }
        // Back slats, reclined ~15 degrees.
        for i in 0..<3 {
            let t = Float(i)
            let (b, x) = board(from: V3(-length / 2, 0.56 + t * 0.1, -0.235 - t * 0.026), to: V3(length / 2, 0.56 + t * 0.1, -0.235 - t * 0.026),
                               width: 0.085, thick: 0.028, up: simd_normalize(V3(0, 0.26, 0.97)), bevel: 0.006, material: "wood.oak")
            m.add(b, x.jittered(&rng, deg: 0.3))
        }
        groundAO(&m, height: 0.3, floor: 0.6)
        return LODModel(m)
    }
}
