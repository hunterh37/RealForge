import simd
import Foundation

/// Juliet balcony: wrought iron rail bowed 200 mm off the wall, round balusters between a top and
/// bottom rail, four scroll rings, two wall-anchored end posts with ball finials and wall plates.
public struct JulietBalcony: RealAsset {
    public static let id = "juliet-balcony"
    public static let summary = "Juliet balcony rail, 1.5 m: wrought iron frame, round balusters, scroll panels, wall anchors."
    public static let tags = ["prop", "architecture", "facade", "trim", "metal", "urban"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 10, distance: 1.6)

    public var width: Float = 1.5
    public var height: Float = 1.1
    public var bow: Float = 0.2
    public var balusterPitch: Float = 0.11
    public var iron: MaterialKey = "metal.wrought-iron"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, H = height, B = bow, hw = W / 2
        func rail(_ y: Float, r: Float) {
            FA.path(&m, [V3(-hw, y, 0.02), V3(-hw + 0.06, y, B * 0.7), V3(-hw + 0.14, y, B), V3(hw - 0.14, y, B), V3(hw - 0.06, y, B * 0.7), V3(hw, y, 0.02)], r: r, iron, sides: 10)
        }
        rail(H - 0.02, r: 0.017)
        rail(0.08, r: 0.012)
        rail(H * 0.56, r: 0.007)
        for e: Float in [-1, 1] {
            FA.rod(&m, V3(e * hw, 0.0, 0.02), V3(e * hw, H, 0.02), r: 0.016, iron)
            FA.ball(&m, r: 0.026, at: V3(e * hw, H + 0.02, 0.02), iron)
            FA.box(&m, V3(0.09, 0.2, 0.012), V3(e * hw, 0.3, 0.006), iron, r: 0.002)
            FA.box(&m, V3(0.09, 0.2, 0.012), V3(e * hw, H - 0.2, 0.006), iron, r: 0.002)
            hexBolt(&m, at: V3(e * hw, 0.3, 0.013), normal: FA.Z, size: 0.016, material: "metal.rust")
        }
        let n = Int((W - 0.3) / balusterPitch)
        for i in 0...n {
            let x = -(Float(n) * balusterPitch) / 2 + Float(i) * balusterPitch
            FA.rod(&m, V3(x, 0.08, B), V3(x, H - 0.02, B), r: 0.0075, iron, sides: 8)
        }
        for i in 0..<4 {
            let x = -0.3 * 1.5 + Float(i) * 0.3 + rng.float(-0.003...0.003)
            m.add(Prim.torus(major: 0.06, minor: 0.006, segments: 20, sides: 6, material: iron),
                  Xform(translation: V3(x, H * 0.3, B + 0.004), rotation: FA.q(90, FA.X)))
        }
        groundAO(&m, height: 0.12, floor: 0.75)
        return LODModel(FA.centerZ(m))
    }
}
