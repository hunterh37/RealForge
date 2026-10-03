import simd
import Foundation

/// Portable site cement mixer, about 140 L drum: 1.4 m tall, 1.3 m long. Painted steel drum (0.66 m belly,
/// conical mouth tilted 35 degrees) with a ring gear and concrete crust, yoke and handwheel, motor housing,
/// tube frame on two wheels and two feet with a tow bar.
public struct CementMixer: RealAsset {
    public static let id = "cement-mixer"
    public static let summary = "Portable cement mixer: tilted painted drum with ring gear and concrete crust, yoke, handwheel, motor, wheeled frame."
    public static let tags = ["prop", "construction", "metal", "tool"]
    public static let budget = 12_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 40, elevation: 16)

    public var color: UInt32 = 0xC9581A
    /// Drum tilt from vertical, degrees (0 upright, 90 tipping).
    public var tilt: Float = 35
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let paint = String(format: "metal.painted:%06X", color), dark = "metal.painted:2A2C30"
        let pivot = V3(-0.05, 0.86, 0)
        // Drum (local Y = drum axis, origin at the pivot).
        var drum = Model(name: "drum")
        let outer: [(Float, Float)] = [(0, -0.36), (0.12, -0.36), (0.24, -0.34), (0.3, -0.29), (0.33, -0.2), (0.33, -0.04),
                                       (0.3, 0.06), (0.24, 0.2), (0.19, 0.3), (0.17, 0.36), (0.176, 0.375), (0.168, 0.385)]
        drum.add(turned(outer, segments: 40, material: paint, seamTile: 0.5))
        // Inside of the mouth and the crusted interior.
        drum.add(turned([(0.158, 0.38), (0.15, 0.3), (0.2, 0.2), (0.26, 0.05), (0.27, -0.1), (0.0, -0.12)],
                        segments: 32, material: "concrete.rough", seamTile: 0.5))
        // Ring gear around the belly: teeth by pushing every other column out.
        var gear = turned([(0.335, -0.17), (0.37, -0.165), (0.37, -0.125), (0.335, -0.12)], segments: 120, material: "metal.rust", seamTile: 0.5)
        gear.positions = gear.positions.enumerated().map { i, p in
            let col = i % 121, r = simd_length(V2(p.x, p.z))
            guard r > 0.35, col % 2 == 1 else { return p }
            return p * V3(1.04, 1, 1.04)
        }
        gear.recomputeNormals(); gear.computeTangents()
        drum.add(gear)
        // Mixing blade tips visible inside the mouth.
        for k in 0..<3 {
            let a = Float(k) / 3 * 2 * .pi
            drum.add(Prim.roundedBox(V3(0.16, 0.02, 0.06), radius: 0.004, bevelSegments: 1, material: "metal.rust"),
                     Xform(translation: V3(cos(a) * 0.17, 0.12, sin(a) * 0.17), rotation: simd_quatf(degrees: -Float(k) * 120, axis: .up) * simd_quatf(degrees: 30, axis: V3(0, 0, 1))))
        }
        // Concrete crust around the lip.
        let ns = UInt32(truncatingIfNeeded: seed)
        let lip = (0..<48).map { k -> V3 in let a = Float(k) / 48 * 2 * .pi; return V3(cos(a) * 0.168, 0.381, sin(a) * 0.168) }
        var crust = Prim.tube(lip + [lip[0]], radii: Array(repeating: 0.012, count: 49), sides: 8, seamTile: 0.1, material: "concrete.rough",
                              capEnd: false) { t, v in
            let n = Noise.fbm(V3(v * 9, t * 3, 0), octaves: 3, seed: ns)
            return max(0.25, 0.6 + n * 1.6)
        }
        crust.computeTangents()
        drum.add(crust)
        // Drum shaft boss under the base.
        drum.add(turned([(0.0, -0.44), (0.05, -0.44), (0.05, -0.36), (0.0, -0.36)], segments: 16, material: dark))
        let drumX = Xform(translation: pivot, rotation: simd_quatf(degrees: -tilt, axis: V3(0, 0, 1)))
        m.add(drum, drumX)
        // Yoke: arms from the pivot bearing down to the frame on both sides.
        let rail: Float = 0.3, zr: Float = 0.32
        for sz: Float in [-1, 1] {
            m.add(CFKit.pipe([pivot + V3(0, 0, sz * 0.4), pivot + V3(0.05, -0.25, sz * 0.38), V3(0.05, rail + 0.03, sz * zr)], radius: 0.022, sides: 10, material: paint))
            m.add(turned([(0, 0), (0.05, 0), (0.05, 0.06), (0, 0.06)], segments: 16, material: dark),
                  Xform(translation: pivot + V3(0, 0, sz * 0.38), rotation: simd_quatf(degrees: sz > 0 ? 90 : -90, axis: V3(1, 0, 0))))
        }
        // Handwheel on the +Z side.
        let hc = pivot + V3(0, 0, 0.5)
        let wheel = (0..<24).map { k -> V3 in let a = Float(k) / 24 * 2 * .pi; return hc + V3(cos(a) * 0.17, sin(a) * 0.17, 0) }
        m.add(CFKit.loop(wheel, radius: 0.012, sides: 8, material: dark))
        for k in 0..<4 {
            let a = Float(k) / 4 * 2 * .pi + 0.4
            m.add(CFKit.pipe([hc, hc + V3(cos(a) * 0.17, sin(a) * 0.17, 0)], radius: 0.008, sides: 6, material: dark))
        }
        m.add(CFKit.pipe([pivot + V3(0, 0, 0.42), hc], radius: 0.015, sides: 8, material: dark))
        // Frame: two side rails, cross members, wheel axle at -X, feet at +X, tow bar.
        for sz: Float in [-1, 1] {
            m.add(CFKit.pipe([V3(-0.5, 0.17, sz * zr), V3(-0.45, rail, sz * zr), V3(0.45, rail, sz * zr), V3(0.5, 0.0 + 0.03, sz * zr)],
                             radius: 0.022, sides: 10, per: 3, material: paint))
            m.add(Prim.roundedBox(V3(0.1, 0.012, 0.08), radius: 0.003, bevelSegments: 1, material: paint), Xform(translation: V3(0.5, 0.006, sz * zr)))
        }
        for x: Float in [-0.4, 0.05, 0.42] { m.add(CFKit.pipe([V3(x, rail, -zr), V3(x, rail, zr)], radius: 0.018, sides: 8, material: paint)) }
        m.add(CFKit.pipe([V3(0.42, rail, 0), V3(0.65, rail - 0.05, 0), V3(0.78, rail - 0.12, 0)], radius: 0.02, sides: 8, material: paint))
        m.add(turned([(0, 0), (0.035, 0), (0.035, 0.05), (0, 0.05)], segments: 12, material: dark),
              Xform(translation: V3(0.8, rail - 0.12, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        // Axle and wheels.
        let wr: Float = 0.17
        m.add(CFKit.pipe([V3(-0.5, wr, -0.45), V3(-0.5, wr, 0.45)], radius: 0.015, sides: 8, material: "metal.rust"))
        for sz: Float in [-1, 1] {
            let tire = turned([(0.09, -0.03), (0.13, -0.04), (0.165, -0.03), (wr, -0.01), (wr, 0.01), (0.165, 0.03), (0.13, 0.04), (0.09, 0.03)],
                              segments: 28, material: "rubber.tire", seamTile: 0.2)
            var t = tire
            CFKit.orient(&t) { p in let r = simd_length(V2(p.x, p.z)); return V3(p.x, 0, p.z) / max(r, 1e-4) * (r - 0.13) + V3(0, p.y, 0) }
            let x = Xform(translation: V3(-0.5, wr, sz * 0.42), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)))
            m.add(t, x)
            m.add(turned([(0.02, -0.045), (0.09, -0.035), (0.095, 0.0), (0.09, 0.035), (0.02, 0.045)], segments: 16, material: paint), x)
        }
        // Motor housing on the -Z side of the yoke, with a belt guard.
        m.add(Prim.roundedBox(V3(0.3, 0.24, 0.22), radius: 0.03, bevelSegments: 2, material: dark), Xform(translation: V3(-0.3, rail + 0.15, -0.12)).jittered(&rng, deg: 0.5))
        m.add(Prim.roundedBox(V3(0.36, 0.3, 0.04), radius: 0.015, bevelSegments: 1, material: paint), Xform(translation: V3(-0.22, rail + 0.3, -0.28)))
        groundAO(&m, height: 0.3, floor: 0.6)
        return LODModel(m)
    }
}
