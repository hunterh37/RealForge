import simd
import Foundation

/// Regulation soccer goal, 7.32 m wide and 2.44 m tall, 1.8 m deep: white round posts, rear supports, side and back net.
public struct SoccerGoal: RealAsset {
    public static let id = "soccer-goal"
    public static let summary = "Regulation soccer goal, 7.32 x 2.44 m: white aluminum frame, rear support arms, mesh side, top and back net."
    public static let tags = ["prop", "sports", "park", "outdoor", "metal"]
    public static let budget = 800
    public static let author = "hunterh37"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let w: Float = 7.32, h: Float = 2.44, d: Float = 1.8, white = SK.paint(0xF2F2F2), net = "fence.chainlink-veil-light"
        for s: Float in [-1, 1] {
            K.rod(&m, [V3(s * w / 2, 0, 0), V3(s * w / 2, h, 0)], r: 0.06, white, sides: 14)
            K.rod(&m, [V3(s * w / 2, h, 0), V3(s * w / 2, 1.0, -d)], r: 0.04, white, sides: 10)
            K.rod(&m, [V3(s * w / 2, 1.0, -d), V3(s * w / 2, 0.02, -d)], r: 0.035, white, sides: 10)
            K.rod(&m, [V3(s * w / 2, 0.03, 0), V3(s * w / 2, 0.03, -d)], r: 0.03, white, sides: 10)
            SK.side(&m, [V2(0, 0.03), V2(-d, 0.03), V2(-d, 1.0), V2(0, h)], width: 0.012, x: s * w / 2, mat: net, bevel: 0.002)
        }
        K.rod(&m, [V3(-w / 2, h, 0), V3(w / 2, h, 0)], r: 0.06, white, sides: 14)
        K.rod(&m, [V3(-w / 2, 0.02, -d), V3(w / 2, 0.02, -d)], r: 0.03, white, sides: 10)
        K.rod(&m, [V3(-w / 2, 1.0, -d), V3(w / 2, 1.0, -d)], r: 0.035, white, sides: 10)
        SK.sloped(&m, from: V2(0, h), to: V2(-d, 1.0), width: w, thick: 0.012, mat: net)
        K.box(&m, V3(0, 0.51, -d), V3(w, 0.98, 0.012), net, bevel: 0.002)
        return K.finish(&m, ao: 0.1)
    }
}
