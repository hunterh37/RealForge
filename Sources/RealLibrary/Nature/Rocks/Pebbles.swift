import simd
import Foundation

/// Scatter of small stones (single mesh, one draw).
public struct Pebbles: RealAsset {
    public static let id = "pebbles"
    public static let summary = "Cluster of 8-20 small rounded stones in one mesh."
    public static let tags = ["nature", "rock"]
    public static let budget = 10_000
    public var radius: Float = 0.6
    public var count = 14
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        for i in 0..<count {
            let p = rng.inDisc(radius: radius), sz = rng.float(0.04...0.14)
            let b = Boulder().with { $0.size = V3(sz * 1.4, sz * 0.8, sz * 1.1); $0.facets = 2; $0.roughness = 0.12; $0.detail = [5] }
            let one = b.build(seed: seed &+ UInt64(i)).levels[0]
            m.add(one, Xform(translation: V3(p.x, 0, p.y), rotation: simd_quatf(degrees: rng.float(0...360), axis: .up)))
        }
        return LODModel(m)
    }
}
