import simd
import Foundation

/// Slate flagstone about 0.9 x 0.6 m and 6 cm proud of the ground: split flat top, irregular broken outline.
public struct Flagstone: RealAsset {
    public static let id = "flagstone"
    public static let summary = "Slate flagstone, 0.9 x 0.6 m: split flat top 6 cm above ground, irregular broken outline."
    public static let tags = ["nature", "rock", "garden"]
    public static let budget = 3_200
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 30, elevation: 40)

    public var size: V3 = V3(0.9, 0.14, 0.6)
    public var material: MaterialKey = "rock.slate"
    public var detail: [Int] = [15, 7]
    public var lodDistances: [Float] = [12]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        let shape = RockShape().with {
            $0.size = size; $0.lumps = 0.1; $0.erosion = 0.02; $0.detail = 0.008; $0.facets = 9; $0.chips = 6
            $0.facetDepth = 0.9...1.0; $0.bevel = 0.006; $0.squareness = 2.5; $0.flatTop = 1; $0.verticalFacets = true; $0.sink = 0.5
        }
        let levels = shape.surfaces(seed: seed, material: material, detail: detail).map { s -> Model in
            var s = s
            rockContactAO(&s, height: 0.06)
            return Model(name: Self.id, surfaces: [s])
        }
        return LODModel(levels: levels, switchDistances: lodDistances)
    }
}
