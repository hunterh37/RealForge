import simd
import Foundation

/// Hibiscus shrub, 1.3 m. Plant habit in `plan`, bloom shape and colors in `flower` (hex colors, petal count and rows,
/// petal size, cup and curl, center disc); both are plain values to override.
public struct HibiscusShrub: RealAsset {
    public static let id = "hibiscus-shrub"
    public static let summary = "Hibiscus shrub, 1.3 m: 8-12 branches with glossy toothed leaves and red five-petal blooms with yellow stamen columns."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 12000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var plan = FlowerPlan().with { $0.stems = 8...12; $0.height = 1.1...1.5; $0.spread = 0.3; $0.stemRadius = 0.01; $0.stemColor = "6B5A44"; $0.leafColor = "2F6B2C"; $0.stemLeaves = 14...20; $0.basal = 0...0; $0.leafLength = 0.08...0.12; $0.leafBelly = 0.7; $0.leafWidth = 0.05; $0.leafTip = 0.1; $0.facing = 0.6 }
    public var flower = FlowerStyle().with { $0.color = "E8242C"; $0.center = "F2D030"; $0.petals = 5; $0.length = 0.09; $0.width = 0.075; $0.tipWidth = 0.8; $0.lean = 1.1; $0.curl = 0.3; $0.fold = -0.15; $0.centerRadius = 0.008; $0.centerDome = 4 }
    public init() {}

    public func build(seed: UInt64) -> LODModel { FlowerKit.lod(Self.id, plan, flower, seed: seed) }
}
