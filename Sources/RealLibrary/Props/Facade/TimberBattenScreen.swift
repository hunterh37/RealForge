import simd
import Foundation

/// Charred timber batten screen: 1.5 x 2.4 m of vertical shou-sugi-ban battens at irregular pitch and
/// alternating depth, held by three steel rails on offset brackets. Wall plane at z = 0.
public struct TimberBattenScreen: RealAsset {
    public static let id = "timber-batten-screen"
    public static let summary = "Timber batten screen, 1.5 x 2.4 m: charred vertical battens at irregular pitch and depth on steel rails."
    public static let tags = ["prop", "architecture", "facade", "wood"]
    public static let budget = 4000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 10, distance: 3.4)

    public var width: Float = 1.5
    public var height: Float = 2.4
    public var batten: MaterialKey = "wood.charred"
    public var rail: MaterialKey = "metal.galvanized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, H = height
        let railZ: [Float] = [0.04, 0.04, 0.04]
        let railY: [Float] = [0.2, H / 2, H - 0.2]
        for (i, y) in railY.enumerated() {
            FA.box(&m, V3(W, 0.04, 0.025), V3(0, y, railZ[i]), rail, r: 0.003)
            for x in [-W / 2 + 0.15, 0, W / 2 - 0.15] { FA.box(&m, V3(0.03, 0.03, railZ[i]), V3(x, y, railZ[i] / 2), rail, r: 0.002) }
        }
        var x = -W / 2 + 0.03
        var k = 0
        while x < W / 2 - 0.03 {
            let w: Float = rng.chance(0.3) ? 0.09 : 0.05
            let depth: Float = k % 3 == 0 ? 0.1 : (k % 3 == 1 ? 0.07 : 0.045)
            let len = H - rng.float(0...0.04)
            FA.box(&m, V3(w, len, depth), V3(x + w / 2, len / 2 + rng.float(0...0.02), 0.052 + depth / 2), batten, r: 0.004)
            x += w + rng.float(0.012...0.045)
            k += 1
        }
        groundAO(&m, height: 0.15, floor: 0.8)
        return LODModel(FC.place(m))
    }
}
