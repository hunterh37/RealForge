import simd
import Foundation

/// Garden stepping stone about 0.6 x 0.5 m with a flat, slightly domed tread 8 to 12 cm above the ground
/// and broken, beveled edges. 2 LODs.
public struct SteppingStone: RealAsset {
    public static let id = "stepping-stone"
    public static let summary = "Garden stepping stone, 0.6 m: flat tread about 10 cm above ground, broken beveled edges, 2 LODs."
    public static let tags = ["nature", "rock", "garden"]
    public static let budget = 4_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 35)

    public var size: V3 = V3(0.62, 0.26, 0.5)
    public var material: MaterialKey = "rock.granite-bare"
    public var detail: [Int] = [18, 8]
    public var lodDistances: [Float] = [12]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        let shape = RockShape().with {
            $0.size = size; $0.lumps = 0.08; $0.erosion = 0.03; $0.detail = 0.01; $0.facets = 6; $0.chips = 6
            $0.facetDepth = 0.8...0.95; $0.bevel = 0.012; $0.squareness = 2.4; $0.flatTop = 0.92; $0.verticalFacets = true; $0.sink = 0.45
        }
        let levels = shape.surfaces(seed: seed, material: material, detail: detail).map { s -> Model in
            var s = s
            rockContactAO(&s, height: 0.12)
            return Model(name: Self.id, surfaces: [s])
        }
        return LODModel(levels: levels, switchDistances: lodDistances)
    }
}
