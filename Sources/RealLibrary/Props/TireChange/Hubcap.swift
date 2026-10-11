import simd
import Foundation

/// Plastic wheel cover, face up: dished disc, ten spoke ribs, chrome ring, center emblem.
public struct Hubcap: RealAsset {
    public static let id = "hubcap"
    public static let summary = "Plastic wheel cover: dished disc with ribs, chrome ring and retaining clips, resting face up."
    public static let tags = ["prop", "vehicle", "metal", "plastic"]
    public static let budget = 8000
    public static let author = "realityhd"

    /// Outer radius in meters (16 inch cover).
    public var radius: Float = 0.2
    /// Number of spoke ribs.
    public var ribCount = 10
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = radius
        let cover = "metal.satin-aluminum"
        // Dished body: rolled lip, slope, raised center.
        let prof: [V2] = [V2(R, 0), V2(R, 0.012), V2(R - 0.008, 0.017), V2(R - 0.025, 0.021), V2(R - 0.06, 0.03), V2(0.09, 0.046), V2(0.07, 0.056), V2(0.045, 0.06), V2(0, 0.062)]
        m.add(Prim.lathe(prof, segments: 80, seamTile: 0.3, material: cover, swapUV: false))
        // Underside thickness: inner dish so the edge reads as a shell.
        m.add(Prim.lathe([V2(0, 0.0), V2(R - 0.004, 0.0), V2(R - 0.004, 0.003), V2(0, 0.003)], segments: 80, seamTile: 0.3, material: "plastic.black", swapUV: false))
        // Chrome ring bead near the lip.
        m.add(Prim.torus(major: R - 0.012, minor: 0.0038, segments: 80, sides: 8, material: "metal.chrome"), Xform(translation: V3(0, 0.0185, 0)))
        // Spoke ribs following the slope (slope angle from the profile).
        let a0 = V2(R - 0.06, 0.03), a1 = V2(0.09, 0.046)
        let slope = atan2(a1.y - a0.y, a0.x - a1.x)
        let ribLen = simd_length(V2(a0.x - a1.x, a1.y - a0.y)) + 0.01
        let rmid = (a0.x + a1.x) / 2
        for i in 0..<ribCount where i != 3 {
            let a = Float(i) / Float(ribCount) * 2 * .pi
            let q = simd_quatf(angle: -a, axis: V3(0, 1, 0)) * simd_quatf(angle: slope, axis: V3(0, 0, 1)) * simd_quatf(degrees: 90, axis: V3(0, 1, 0))
            _ = q
            // Orient rib: long axis points outward along radial, tilted by slope.
            let radial = V3(cos(a), 0, sin(a))
            let yaw = simd_quatf(angle: -a, axis: V3(0, 1, 0))
            let tilt = simd_quatf(angle: -slope, axis: V3(0, 0, 1))
            m.add(Prim.roundedBox(V3(ribLen, 0.006, 0.013), radius: 0.0022, bevelSegments: 1, material: "metal.chrome"),
                  Xform(translation: radial * rmid + V3(0, (a0.y + a1.y) / 2 + 0.003, 0), rotation: yaw * tilt))
        }
        // Retaining clips visible under the rim: eight spring tabs bent down.
        for i in 0..<8 {
            let a = (Float(i) + 0.5) / 8 * 2 * .pi
            m.add(Prim.roundedBox(V3(0.004, 0.012, 0.018), radius: 0.001, bevelSegments: 1, material: "metal.steel"),
                  Xform(translation: V3(cos(a) * (R - 0.012), 0.006, sin(a) * (R - 0.012)), rotation: simd_quatf(angle: -a, axis: V3(0, 1, 0))))
        }
        // Brake dust: dark smears fanning across the slope near the lip, plus a scuffed arc on the ring.
        for i in 0..<5 {
            let a = rng.float(0...(2 * .pi))
            let rrr = rng.float(0.14...0.17)
            m.add(Prim.roundedBox(V3(0.045, 0.0008, 0.016), radius: 0.0003, bevelSegments: 1, material: "plastic.black"),
                  Xform(translation: V3(cos(a) * rrr, 0.0313 - (rrr - 0.14) * 0.3, sin(a) * rrr), rotation: simd_quatf(angle: -a, axis: V3(0, 1, 0)) * simd_quatf(angle: -0.3, axis: V3(0, 0, 1))))
        }
        // Center emblem: chrome ring with dark enamel disc.
        m.add(Prim.cylinder(radius: 0.034, height: 0.004, bevel: 0.0014, segments: 32, material: "metal.chrome"), Xform(translation: V3(0, 0.059, 0)))
        m.add(Prim.cylinder(radius: 0.026, height: 0.0014, bevel: 0.0004, segments: 32, material: "plastic.black"), Xform(translation: V3(0, 0.0626, 0)))
        // Story detail: dusty brake-side scuff patch on the lip.
        let sa = rng.float(0...(2 * .pi))
        m.add(Prim.roundedBox(V3(0.05, 0.002, 0.012), radius: 0.0008, bevelSegments: 1, material: "plastic.black"),
              Xform(translation: V3(cos(sa) * (R - 0.004), 0.0145, sin(sa) * (R - 0.004)), rotation: simd_quatf(angle: -sa + .pi / 2, axis: V3(0, 1, 0)) * simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(0, -b.min.y, 0)))
        groundAO(&m, height: 0.02, floor: 0.5)
        return LODModel(m)
    }
}
