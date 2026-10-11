import simd
import Foundation

/// Locking lug nut key: knurled hardened steel body, hex drive, irregular spline socket.
public struct WheelLockKey: RealAsset {
    public static let id = "wheel-lock-key"
    public static let summary = "Locking lug nut key: knurled steel body with an irregular spline pattern in the socket."
    public static let tags = ["prop", "tool", "vehicle", "metal", "handheld"]
    public static let budget = 5000
    public static let author = "realityhd"

    /// Knurled grip radius in meters.
    public var radius: Float = 0.0145
    /// Overall height in meters.
    public var height: Float = 0.045
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let grip: Float = height * 0.62
        // Knurled barrel: dark core with raised ridges.
        m.add(Prim.cylinder(radius: radius - 0.0007, height: grip, bevel: 0.0012, segments: 28, material: "metal.steel"))
        let ridges = 24
        for i in 0..<ridges {
            let a = Float(i) / Float(ridges) * 2 * .pi
            m.add(Prim.roundedBox(V3(0.0017, grip - 0.004, 0.0017), radius: 0.0004, bevelSegments: 1, material: "metal.steel"),
                  Xform(translation: V3(cos(a) * radius, grip / 2, sin(a) * radius), rotation: simd_quatf(angle: -a, axis: V3(0, 1, 0))))
        }
        // Hex drive section above the barrel, 21 mm across flats.
        let afHex: Float = 0.021
        m.add(turned([(0, 0), (afHex * 0.5774, 0), (afHex * 0.5774, height - grip - 0.002), (afHex * 0.5774 - 0.0012, height - grip), (0, height - grip)], segments: 6, material: "metal.chrome", seamTile: 0.05),
              Xform(translation: V3(0, grip, 0)))
        // Socket end (bottom): dark recess with an irregular five-lobe spline set in it.
        m.add(Prim.cylinder(radius: radius - 0.0035, height: 0.0008, bevel: 0.0002, segments: 24, material: "plastic.black"), Xform(translation: V3(0, -0.0004, 0)))
        for i in 0..<5 {
            let a = (Float(i) + rng.float(-0.12...0.12)) / 5 * 2 * .pi
            let rr = rng.float(0.0055...0.0075)
            m.add(Prim.roundedBox(V3(0.0032, 0.0012, 0.0032), radius: 0.0008, bevelSegments: 1, material: "metal.steel"),
                  Xform(translation: V3(cos(a) * rr, 0.0006, sin(a) * rr)))
        }
        // Drive-side cap recess for a keyring hole is omitted; top face is flat steel.
        m.add(Prim.cylinder(radius: 0.0055, height: 0.0006, bevel: 0.0002, segments: 16, material: "metal.steel"), Xform(translation: V3(0, height, 0)))
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(0, -b.min.y, 0)))
        groundAO(&m, height: 0.02, floor: 0.5)
        return LODModel(m)
    }
}
