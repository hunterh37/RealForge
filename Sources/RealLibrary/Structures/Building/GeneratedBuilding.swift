import simd
import Foundation

/// Procedural building from a `BuildingSpec`: walls with real openings, framed windows and doors,
/// trim runs, roof, floor slabs, interior walls and stairs. Default: three-floor Georgian, 14 x 10 m.
public struct GeneratedBuilding: RealAsset {
    public static let id = "generated-building"
    public static let summary = "Procedural building from a BuildingSpec: walls with openings, framed windows, trim, roof, floors, interior walls and stairs."
    public static let tags = ["structure", "building", "brick", "stone", "urban"]
    public static let budget = 30_000
    public static let preview = PreviewHint(azimuth: 30, elevation: 8, distance: 1.1, fog: 0.001)

    public var spec = BuildingSpec()
    public init() {}
    public init(spec: BuildingSpec) { self.spec = spec }

    public func build(seed: UInt64) -> LODModel {
        var s = spec
        s.seed = spec.seed &+ seed
        return BuildingGenerator.build(s).combined()
    }
}
