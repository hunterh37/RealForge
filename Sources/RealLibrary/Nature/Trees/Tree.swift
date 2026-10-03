import simd
import Foundation

/// Generic tree asset over a species. LOD0 hero (~20-35k tris), LOD1 (~6-10k), LOD2 (~1.5-3k).
public struct Tree: RealAsset {
    public static let id = "tree"
    public static let summary = "Recursive-branching tree with bark, alpha-card foliage, crown normals, wind weights, 3 LODs."
    public static let tags = ["nature", "tree"]
    public static let budget = 45_000

    public var species: TreeSpecies = .oak
    public var lodDistances: [Float] = [14, 40]
    public init() {}
    public init(_ species: TreeSpecies) { self.species = species }

    public func build(seed: UInt64) -> LODModel {
        let g = TreeGenerator(species: species, seed: seed)
        return LODModel(levels: [g.model(.lod0), g.model(.lod1), g.model(.lod2)], switchDistances: lodDistances)
    }
}
