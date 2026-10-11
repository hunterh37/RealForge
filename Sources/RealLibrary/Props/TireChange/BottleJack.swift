import simd
import Foundation

/// 2-ton hydraulic bottle jack, retracted, with the extension screw wound out a few turns.
public struct BottleJack: RealAsset {
    public static let id = "bottle-jack"
    public static let summary = "2-ton hydraulic bottle jack: red body, threaded extension screw, saddle, base, pump socket and release screw."
    public static let tags = ["prop", "tool", "vehicle", "metal", "handheld"]
    public static let budget = 8000
    public static let author = "realityhd"

    /// Body radius in meters.
    public var bodyRadius: Float = 0.038
    /// Body paint, sRGB hex.
    public var paint: UInt32 = 0xC8201E
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = bodyRadius
        let paintKey = "metal.painted:" + String(paint, radix: 16, uppercase: true)
        // Base: stepped rectangular foot, 0.115 x 0.1.
        m.add(Prim.roundedBox(V3(0.115, 0.014, 0.1), radius: 0.003, bevelSegments: 2, material: paintKey), Xform(translation: V3(0, 0.007, 0)))
        m.add(Prim.cylinder(radius: R + 0.006, height: 0.01, bevel: 0.003, segments: 28, material: "metal.steel"), Xform(translation: V3(0, 0.014, 0)))
        // Body cylinder, slightly tapered shoulder at the top.
        m.add(turned([(0, 0), (R, 0), (R, 0.104), (R - 0.004, 0.112), (0, 0.112)], segments: 32, material: paintKey, seamTile: 0.1), Xform(translation: V3(0, 0.022, 0)))
        // Gland collar and chrome ram.
        m.add(Prim.cylinder(radius: R - 0.006, height: 0.012, bevel: 0.003, segments: 28, material: "metal.steel"), Xform(translation: V3(0, 0.133, 0)))
        m.add(Prim.cylinder(radius: 0.0215, height: 0.036, bevel: 0.0015, segments: 24, material: "metal.chrome"), Xform(translation: V3(0, 0.143, 0)))
        // Extension screw: zinc core with thread, locking ring.
        let ey: Float = 0.178
        m.add(Prim.cylinder(radius: 0.0125, height: 0.03, bevel: 0.001, segments: 18, material: "metal.screw-zinc"), Xform(translation: V3(0, ey, 0)))
        m.add(Prim.helix(radius: 0.0132, pitch: 0.0032, turns: 9, wire: 0.001, material: "metal.screw-zinc"), Xform(translation: V3(0, ey, 0)))
        m.add(Prim.cylinder(radius: 0.017, height: 0.006, bevel: 0.0015, segments: 6, material: "metal.steel"), Xform(translation: V3(0, ey - 0.002, 0)))
        // Saddle: round steel head with ribbed top.
        m.add(Prim.cylinder(radius: 0.0295, height: 0.012, bevel: 0.003, segments: 28, material: "metal.steel"), Xform(translation: V3(0, ey + 0.026, 0)))
        for i in -2...2 {
            m.add(Prim.roundedBox(V3(0.052 - abs(Float(i)) * 0.007, 0.0035, 0.004), radius: 0.001, bevelSegments: 1, material: "metal.steel"), Xform(translation: V3(0, ey + 0.0385, Float(i) * 0.009)))
        }
        // Pump socket sleeve on the side, angled out and up, and release screw below it.
        let sy: Float = 0.062
        m.add(Prim.tube([V3(R - 0.004, sy, 0), V3(R + 0.016, sy + 0.01, 0)], radii: [0.0105, 0.0105], sides: 14, seamTile: 0.1, material: "metal.steel", capEnd: true))
        m.add(Prim.cylinder(radius: 0.0072, height: 0.004, bevel: 0.0012, segments: 14, material: "plastic.black"),
              Xform(translation: V3(R + 0.0166, sy + 0.0103, 0), rotation: simd_quatf(angle: -atan2(0.01, 0.02) - .pi / 2, axis: V3(0, 0, 1))))
        m.add(Prim.cylinder(radius: 0.0075, height: 0.012, bevel: 0.002, segments: 6, material: "metal.steel"),
              Xform(translation: V3(R - 0.003, 0.036, 0.0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        // Stamped capacity plate.
        m.add(Prim.roundedBox(V3(0.001, 0.028, 0.042), radius: 0.0004, bevelSegments: 1, material: "metal.chrome"),
              Xform(translation: V3(0, 0.092, -(R + 0.0008)), rotation: simd_quatf(degrees: 90, axis: V3(0, 1, 0))))
        var out = Model(name: Self.id)
        out.add(m, Xform(rotation: simd_quatf(degrees: rng.float(0...360), axis: V3(0, 1, 0))))
        groundAO(&out, height: 0.03, floor: 0.5)
        return LODModel(out)
    }
}
