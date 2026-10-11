import simd
import Foundation

/// Five 21 mm conical-seat lug nuts, three standing and two on their sides.
public struct LugNutSet: RealAsset {
    public static let id = "lug-nut-set"
    public static let summary = "Five 21 mm conical-seat lug nuts with thread bores, scattered close."
    public static let tags = ["prop", "tool", "vehicle", "metal"]
    public static let budget = 7000
    public static let author = "realityhd"

    /// Hex across-flats in meters.
    public var acrossFlats: Float = 0.021
    /// Overall nut height in meters.
    public var nutHeight: Float = 0.034
    public init() {}

    func nut(_ rng: inout SeededRNG, finish: String) -> Model {
        var n = Model(name: "nut")
        let rh = acrossFlats * 0.5774
        let seat: Float = 0.009
        // Conical seat: 60 degree cone widening to the hex.
        n.add(Prim.lathe([V2(0, 0), V2(0.0085, 0), V2(0.0105, 0.0035), V2(rh * 0.96, seat), V2(0, seat)], segments: 24, seamTile: 0.05, material: finish, swapUV: false))
        // Hex body: flat-faced prism with filleted corners and a chamfered closed end.
        let body = Prim.extrude(Shape2D.rounded(Shape2D.polygon(sides: 6, radius: rh), radius: 0.0016), depth: nutHeight - seat, bevel: 0.0018, bevelSegments: 2, material: finish)
        n.add(body, Xform(translation: V3(0, seat + (nutHeight - seat) / 2 - 0.0005, 0), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
        // Brake-dust ring on the seat cone.
        n.add(Prim.torus(major: 0.0098, minor: 0.0012, segments: 20, sides: 5, material: "plastic.black"), Xform(translation: V3(0, 0.0032, 0)))
        // Thread bore visible at the seat end.
        n.add(Prim.cylinder(radius: 0.0072, height: 0.0006, bevel: 0.0002, segments: 18, material: "plastic.black"), Xform(translation: V3(0, -0.0003, 0)))
        n.add(Prim.torus(major: 0.0072, minor: 0.0005, segments: 18, sides: 6, material: "metal.steel"), Xform(translation: V3(0, 0.0004, 0)))
        return n
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Mixed finishes: two bright, two dulled steel, one rusty from sitting in the trunk.
        let finishes = ["metal.chrome", "metal.steel", "metal.chrome", "metal.rust", "metal.steel"]
        // (x, z, lying)
        let slots: [(Float, Float, Bool)] = [(-0.035, -0.032, false), (0.032, -0.04, false), (0.0, 0.0, true), (-0.04, 0.042, false), (0.04, 0.035, true)]
        for (i, s) in slots.enumerated() {
            var r = rng.fork(i)
            let yaw = r.float(0...(2 * .pi))
            var n = Model(name: "centered")
            n.add(nut(&r, finish: finishes[i % finishes.count]), Xform(translation: V3(0, -nutHeight / 2, 0)))
            if s.2 {
                // On its side: axis horizontal, resting on a hex flat, nearly flush with the seat flange.
                let lift: Float = 0.0105
                let q = simd_quatf(angle: yaw, axis: V3(0, 1, 0)) * simd_quatf(degrees: 90, axis: V3(0, 0, 1))
                m.add(n, Xform(translation: V3(s.0, lift, s.1), rotation: q))
            } else {
                m.add(n, Xform(translation: V3(s.0, nutHeight / 2, s.1), rotation: simd_quatf(angle: yaw, axis: V3(0, 1, 0))))
            }
        }
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(0, -b.min.y, 0)))
        groundAO(&m, height: 0.02, floor: 0.5)
        return LODModel(m)
    }
}
