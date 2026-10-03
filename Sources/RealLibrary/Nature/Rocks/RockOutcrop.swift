import simd
import Foundation

/// Granite outcrop about 4.5 x 2.2 x 3.5 m: a large jointed main block, two to four leaning slabs against it
/// and broken pieces at the foot, one mesh. 3 LODs.
public struct RockOutcrop: RealAsset {
    public static let id = "rock-outcrop"
    public static let summary = "Granite outcrop, 4.5 m: large jointed block, leaning slabs and broken pieces at the foot, 3 LODs."
    public static let tags = ["nature", "rock"]
    public static let budget = 48_000
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 30, elevation: 18)

    /// Main block extents in meters.
    public var size: V3 = V3(3.2, 2.2, 2.4)
    public var material: MaterialKey = "rock.granite"
    public var slabs: ClosedRange<Int> = 2...4
    public var pieces: ClosedRange<Int> = 4...7
    public var lodDistances: [Float] = [20, 50]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let base = RockShape().with {
            $0.lumps = 0.12; $0.erosion = 0.08; $0.squareness = 2.6; $0.facetDepth = 0.7...0.92
            $0.bevel = 0.05; $0.sink = 0.12
        }
        var parts = [RockPart(shape: base.with { $0.size = size; $0.facets = 9; $0.chips = 14 }, seed: seed,
                              xform: Xform(translation: V3(0, 0, 0)), material: material)]
        let ns = rng.int(slabs)
        for k in 0..<ns {
            let a = Float(k) / Float(ns) * 2 * .pi + rng.float(-0.5...0.5)
            let sz = V3(size.x * rng.float(0.45...0.7), size.y * rng.float(0.5...0.8), size.z * rng.float(0.3...0.45))
            let r = V2(size.x, size.z) * 0.42
            let pos = V3(cos(a) * r.x, 0, sin(a) * r.y)
            let yaw = simd_quatf(angle: -a + .pi / 2, axis: V3(0, 1, 0))
            let tilt = simd_quatf(degrees: rng.float(8...22), axis: V3(1, 0, 0))
            parts.append(RockPart(shape: base.with { $0.size = sz; $0.facets = 6; $0.chips = 8; $0.squareness = 3 },
                                  seed: seed &+ UInt64(10 + k), xform: Xform(translation: pos, rotation: yaw * tilt), material: material))
        }
        let np = rng.int(pieces)
        for k in 0..<np {
            let a = rng.float(0...(2 * .pi)), d = rng.float(0.55...0.8)
            let s = rng.float(0.25...0.6)
            let pos = V3(cos(a) * size.x * d, 0, sin(a) * size.z * d)
            parts.append(RockPart(shape: base.with { $0.size = V3(s * 1.3, s * 0.8, s); $0.facets = 6; $0.chips = 4; $0.squareness = 2.2; $0.sink = 0.2 },
                                  seed: seed &+ UInt64(40 + k), xform: Xform(translation: pos), material: material))
        }
        let levels = rockCluster(name: Self.id, parts: parts, lods: 3) { i, lod in
            if i == 0 { return [36, 16, 7][lod] }
            if i <= ns { return [22, 10, 4][lod] }
            return lod == 2 ? nil : [10, 5, 0][lod]
        }
        return LODModel(levels: levels, switchDistances: lodDistances)
    }
}
