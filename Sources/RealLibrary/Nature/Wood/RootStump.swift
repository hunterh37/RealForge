import simd
import Foundation

/// Old stump on eroded ground, 70 cm across and 30 cm tall: wide flare and eight surface roots that arch
/// out of the soil up to 1 m from the trunk before diving back in; mossy bark and a grey, checked top.
public struct RootStump: RealAsset {
    public static let id = "root-stump"
    public static let summary = "Old stump with exposed roots, 70 cm across: wide flare, eight arching surface roots, mossy bark, grey checked top."
    public static let tags = ["nature", "wood"]
    public static let budget = 6_000
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 30, elevation: 30, distance: 1.0)

    public var diameter: Float = 0.7
    public var height: Float = 0.3
    public var roots = 8
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LogStump().with {
            $0.diameter = diameter; $0.height = height; $0.roots = roots
            $0.flare = 0.75; $0.rootReach = 2.2; $0.rootArch = 0.07; $0.tilt = 6
        }.build(seed: seed)
    }
}
