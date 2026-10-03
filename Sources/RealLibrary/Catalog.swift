import simd
import Foundation

/// Registry of every asset. Tests iterate it; apps build by id.
public enum Catalog {
    public static let assets: [any RealAsset.Type] = [
        OakTree.self, BirchTree.self, SpruceTree.self, Shrub.self, Tree.self,
        Boulder.self, Pebbles.self, GroundPatch.self, GrassClump.self,
    ] + Props.all

    public static func type(_ id: String) -> (any RealAsset.Type)? { assets.first { $0.id == id } }

    public static func build(_ id: String, seed: UInt64 = 1) -> LODModel? { type(id).map { $0.init().build(seed: seed) } }

    public static func ids(tag: String? = nil) -> [String] { assets.filter { tag == nil || $0.tags.contains(tag!) }.map { $0.id } }
}
