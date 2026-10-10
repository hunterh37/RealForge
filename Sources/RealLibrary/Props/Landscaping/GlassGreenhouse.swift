import simd
import Foundation

/// Backyard glass greenhouse, 3.0 m wide, 4.5 m long and 2.9 m tall at the ridge: aluminum frame, glazed walls and gable roof, front door, potting bench, pots.
public struct GlassGreenhouse: RealAsset {
    public static let id = "glass-greenhouse"
    public static let summary = "Backyard glass greenhouse, 3 x 4.5 m: aluminum frame, glazed walls and gable roof, plinth, door, potting bench, pots."
    public static let tags = ["prop", "garden", "landscaping", "outdoor", "glass", "metal"]
    public static let budget = 8700
    public static let author = "hunterh37"

    /// Frame paint, sRGB hex.
    public var frame: UInt32 = 0x2F4A3B
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let f = SK.paint(frame), W: Float = 3.0, L: Float = 4.5, wall: Float = 1.85, ridge: Float = 2.9, b: Float = 0.3
        K.box(&m, V3(0, b / 2, 0), V3(W + 0.1, b, L + 0.1), "brick.common", bevel: 0.01)
        let glass = "glass.pane"
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * W / 2, b + (wall - b) / 2, 0), V3(0.012, wall - b, L), glass, bevel: 0.002)
        }
        for s: Float in [-1, 1] {
            let a = V3(s * W / 2, wall, 0), c = V3(0, ridge, 0)
            let d = c - a, len = simd_length(d), ang = atan2(d.y, abs(d.x)) * s * -1
            K.box(&m, (a + c) / 2, V3(len, 0.012, L), glass, bevel: 0.002, rot: simd_quatf(angle: ang, axis: V3(0, 0, 1)))
        }
        let gable = [V2(-W / 2, b), V2(-W / 2, wall), V2(0, ridge), V2(W / 2, wall), V2(W / 2, b)]
        for z: Float in [-L / 2, L / 2 - 0.04] {
            m.add(Prim.extrude(gable, depth: 0.01, bevel: 0.002, material: MaterialKey(stringLiteral: glass)), Xform(translation: V3(0, 0, z)))
        }
        let bays = 5
        for i in 0...bays {
            let z = -L / 2 + L * Float(i) / Float(bays)
            for s: Float in [-1, 1] { K.box(&m, V3(s * W / 2, b + (wall - b) / 2, z), V3(0.035, wall - b, 0.035), f, bevel: 0.004) }
            for s: Float in [-1, 1] { K.beam(&m, V3(s * W / 2, wall, z), V3(0, ridge, z), 0.035, 0.035, f) }
        }
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * W / 2, wall, 0), V3(0.04, 0.04, L), f, bevel: 0.004)
            K.box(&m, V3(s * W / 2, b + 0.02, 0), V3(0.04, 0.04, L), f, bevel: 0.004)
        }
        K.box(&m, V3(0, ridge, 0), V3(0.05, 0.05, L), f, bevel: 0.004)
        // End-gable door
        K.box(&m, V3(0, b + 0.9, L / 2 + 0.01), V3(0.9, 1.8, 0.03), f, bevel: 0.004)
        K.box(&m, V3(0, b + 0.9, L / 2 + 0.02), V3(0.78, 1.68, 0.01), glass, bevel: 0.002)
        K.box(&m, V3(0.32, b + 0.9, L / 2 + 0.05), V3(0.02, 0.14, 0.03), "metal.brass", bevel: 0.004)
        // Potting bench and pots
        K.box(&m, V3(-1.1, 0.85, -1.2), V3(0.6, 0.05, 1.8), "wood.cedar-weathered", bevel: 0.006)
        for z: Float in [-2.0, -0.4] { for x: Float in [-1.36, -0.84] { K.box(&m, V3(x, 0.42, z), V3(0.05, 0.84, 0.05), "wood.cedar-weathered", bevel: 0.004) } }
        for z: Float in [-1.8, -1.4, -1.0, -0.6] {
            m.add(Prim.lathe([V2(0.07, 0), V2(0.1, 0.16), V2(0.11, 0.16), V2(0, 0.14)].reversed(), segments: 14, material: "ceramic.terracotta"), Xform(translation: V3(-1.1, 0.875, z)))
        }
        return K.finish(&m, ao: 0.25)
    }
}
