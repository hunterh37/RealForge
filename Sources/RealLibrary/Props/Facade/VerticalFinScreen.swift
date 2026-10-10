import simd
import Foundation

/// Vertical fin screen: cedar fins, 40 mm wide and 300 mm deep at 120 mm pitch, between a top and a
/// bottom anodized rail, standing off the wall on steel pins.
public struct VerticalFinScreen: RealAsset {
    public static let id = "vertical-fin-screen"
    public static let summary = "Vertical timber fin screen, 1.8 m: 40 mm cedar fins at 120 mm pitch between steel top and bottom rails."
    public static let tags = ["prop", "architecture", "facade", "wood", "metal"]
    public static let budget = 9_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 38, elevation: 10, distance: 2.8)

    public var width: Float = 1.8
    public var height: Float = 2.4
    public var finWidth: Float = 0.04
    public var finDepth: Float = 0.3
    public var pitch: Float = 0.12
    public var fin: MaterialKey = "wood.cedar-weathered"
    public var rail: MaterialKey = "metal.anodized-black"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, H = height, rh: Float = 0.05
        let n = Int((W - 0.1) / pitch) + 1
        let x0 = -Float(n - 1) * pitch / 2
        for i in 0..<n {
            let x = x0 + Float(i) * pitch + rng.float(-0.002...0.002)
            m.add(Prim.roundedBox(V3(finDepth, H - 2 * rh, finWidth), radius: 0.003, bevelSegments: 1, material: fin),
                  Xform(translation: V3(x, H / 2, 0.06 + finDepth / 2), rotation: FA.q(90, FA.Y)))
        }
        for y in [rh / 2, H - rh / 2] {
            FA.box(&m, V3(W, rh, 0.06), V3(0, y, 0.1), rail, r: 0.004)
            FA.box(&m, V3(W, rh, 0.06), V3(0, y, 0.26), rail, r: 0.004)
        }
        for x in [-W / 2 + 0.1, 0, W / 2 - 0.1] {
            for y in [rh / 2, H - rh / 2] { FA.rod(&m, V3(x, y, 0), V3(x, y, 0.1), r: 0.008, "metal.steel", sides: 8) }
        }
        groundAO(&m, height: 0.15, floor: 0.7)
        return LODModel(FA.centerZ(m))
    }
}
