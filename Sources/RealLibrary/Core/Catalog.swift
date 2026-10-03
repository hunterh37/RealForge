import simd
import Foundation

/// Registry of every asset. Tests iterate it; apps build by id. Each kind keeps its own list
/// (`Nature.all`, `Props.all`, `Structures.all`) next to its sources.
public enum Catalog {
    public static let assets: [any RealAsset.Type] = Nature.all + Props.all + Structures.all

    public static func type(_ id: String) -> (any RealAsset.Type)? { assets.first { $0.id == id } }

    public static func build(_ id: String, seed: UInt64 = 1) -> LODModel? { type(id).map { $0.init().build(seed: seed) } }

    public static func ids(tag: String? = nil) -> [String] { assets.filter { tag == nil || $0.tags.contains(tag!) }.map { $0.id } }
}
