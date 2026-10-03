import simd
import Foundation

/// Rounded forest rock about 1.3 x 0.8 x 1.1 m under a thick moss cap: the cap is a 2 to 4 cm cushion grown
/// along the normal on upward faces, shaded by `rock.mossy`. 3 LODs.
public struct MossyRock: RealAsset {
    public static let id = "mossy-rock"
    public static let summary = "Rounded forest rock, 1.3 m, under a thick moss cushion on its upper faces, 3 LODs."
    public static let tags = ["nature", "rock"]
    public static let budget = 13_000
    public static let author = "realforge"

    public var size: V3 = V3(1.3, 0.8, 1.1)
    public var material: MaterialKey = "rock.mossy"
    /// Moss cushion thickness in meters.
    public var mossThickness: Float = 0.035
    public var detail: [Int] = [32, 14, 6]
    public var lodDistances: [Float] = [10, 30]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        let shape = RockShape().with {
            $0.size = size; $0.lumps = 0.18; $0.erosion = 0.05; $0.warp = 0.6; $0.facets = 5; $0.chips = 3
            $0.facetDepth = 0.75...0.92; $0.bevel = 0.08; $0.sink = 0.2
        }
        let ns = UInt32(truncatingIfNeeded: seed) &+ 77
        let levels = shape.surfaces(seed: seed, material: material, detail: detail).map { s -> Model in
            var s = s
            for i in s.positions.indices {
                let n = s.normals[i], p = s.positions[i]
                let cover = smoothstep(0.05, 0.55, n.y + 0.25 * Noise.fbm(p * 2.5, octaves: 3, seed: ns))
                let bump = 0.6 + 0.4 * Noise.fbm(p * 14, octaves: 2, seed: ns &+ 1)
                s.positions[i] += n * mossThickness * cover * bump
            }
            s.recomputeNormals(); s.computeTangents()
            rockContactAO(&s, height: size.y)
            return Model(name: Self.id, surfaces: [s])
        }
        return LODModel(levels: levels, switchDistances: lodDistances)
    }
}
