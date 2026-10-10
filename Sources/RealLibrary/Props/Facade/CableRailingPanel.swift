import simd
import Foundation

/// Cable railing: a 1.8 m stainless panel with 60 mm square posts, nine 4 mm cables under 40 mm
/// tension, swage terminals, a timber top cap, intermediate bracing blocks and a base shoe.
public struct CableRailingPanel: RealAsset {
    public static let id = "cable-railing-panel"
    public static let summary = "Cable railing, 1.8 m: stainless posts, nine tensioned cables, swage ends, oak cap."
    public static let tags = ["prop", "architecture", "facade", "metal", "wood"]
    public static let budget = 10_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 10, distance: 3.2)

    public var width: Float = 1.8
    public var height: Float = 1.05
    public var cableCount: Int = 9
    public var steel: MaterialKey = "metal.stainless"
    public var cap: MaterialKey = "wood.oak"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = height, post: Float = 0.05
        for e: Float in [-1, 1] {
            FA.box(&m, V3(post, H - 0.05, post), V3(e * (W / 2 - post / 2), (H - 0.05) / 2, 0.03), steel, r: 0.004)
            FA.box(&m, V3(0.1, 0.01, 0.1), V3(e * (W / 2 - post / 2), 0.005, 0.03), steel, r: 0.002)
            for k in 0..<4 { hexBolt(&m, at: V3(e * (W / 2 - post / 2) + (k % 2 == 0 ? 0.035 : -0.035), 0.012, 0.03 + (k < 2 ? 0.035 : -0.035)), normal: FA.Y, size: 0.012, material: steel) }
        }
        FA.box(&m, V3(W, 0.05, 0.075), V3(0, H - 0.025, 0.03), cap, r: 0.008)
        FA.box(&m, V3(W - 2 * post, 0.025, 0.05), V3(0, 0.0125, 0.03), steel, r: 0.002)
        let n = cableCount, y0: Float = 0.12, y1 = H - 0.1
        for i in 0..<n {
            let y = y0 + Float(i) * (y1 - y0) / Float(n - 1)
            let sag = 0.0 as Float
            FA.rod(&m, V3(-W / 2 + post, y, 0.03 + sag), V3(W / 2 - post, y, 0.03 + sag), r: 0.002, steel, sides: 6)
            for e: Float in [-1, 1] {
                FA.cylX(&m, r: 0.008, h: 0.03, at: V3(e * (W / 2 - post - 0.015), y, 0.03), steel, segments: 10)
                FA.cylX(&m, r: 0.011, h: 0.012, at: V3(e * (W / 2 - post - 0.002), y, 0.03), steel, segments: 6)
            }
        }
        // Intermediate cable guides in a column at mid-span.
        FA.box(&m, V3(0.012, y1 - y0 + 0.02, 0.012), V3(0, (y0 + y1) / 2, 0.03), steel, r: 0.002)
        groundAO(&m, height: 0.1, floor: 0.88)
        return LODModel(FA.centerZ(m))
    }
}
