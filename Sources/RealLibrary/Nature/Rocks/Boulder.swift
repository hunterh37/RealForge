import simd
import Foundation

/// Granite boulder about 1.6 x 1.0 x 1.3 m: warped, ridged body cut by beveled fracture planes and chips,
/// base sunk 15 percent into the ground with a dark dirt line. 3 LODs.
public struct Boulder: RealAsset {
    public static let id = "boulder"
    public static let summary = "Granite boulder, 1.6 m: warped ridged body, beveled fracture faces and chips, sunk base with dirt line, 3 LODs."
    public static let tags = ["nature", "rock"]
    public static let budget = 15_000

    public var size: V3 = V3(1.6, 1.0, 1.3)
    public var material: MaterialKey = "rock.granite"
    public var facets = 8
    public var chips = 10
    /// Shape noise amount; 0.3 is a typical weathered boulder, 0.1 a fresh angular block.
    public var roughness: Float = 0.3
    /// Cube-sphere subdivisions per LOD.
    public var detail: [Int] = [34, 15, 6]
    public var lodDistances: [Float] = [10, 30]
    public init() {}

    public var shape: RockShape {
        RockShape().with {
            $0.size = size; $0.facets = facets; $0.chips = chips
            $0.lumps = 0.2 * roughness / 0.3; $0.erosion = 0.06 * roughness / 0.3; $0.detail = 0.018
            $0.bevel = max(0.012, 0.025 * min(size.x, size.y, size.z))
        }
    }

    public func build(seed: UInt64) -> LODModel {
        let h = size.y
        let levels = shape.surfaces(seed: seed, material: material, detail: detail).map { s -> Model in
            var s = s
            rockContactAO(&s, height: h)
            return Model(name: Self.id, surfaces: [s])
        }
        return LODModel(levels: levels, switchDistances: Array(lodDistances.prefix(detail.count - 1)))
    }
}
