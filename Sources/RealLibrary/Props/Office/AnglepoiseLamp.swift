import simd
import Foundation

/// Spring-balanced desk lamp after the Anglepoise 1227 (1935): stepped cast-iron base, swivel turret
/// with a fork, twin flat-bar lower and upper arms on chrome knuckles, four coil tension springs, domed
/// enamel shade with rolled rim, white reflector, warm bulb, chrome rear cap with switch, cloth cable.
public struct AnglepoiseLamp: RealAsset {
    public static let id = "anglepoise-lamp"
    public static let summary = "Spring-balanced desk lamp after the Anglepoise 1227: stepped cast base, twin parallel arms, four tension springs, domed shade."
    public static let tags = ["prop", "office", "light", "metal", "interior"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 52, elevation: 12, distance: 1.15, studio: true)

    /// Enamel color (sRGB hex).
    public var color: UInt32 = 0x1B1B1C
    /// Lower arm angle from horizontal (degrees, >90 leans back) and upper arm angle (degrees).
    public var lowerAngle: Float = 96
    public var upperAngle: Float = 24
    /// Shade tilt below horizontal (degrees).
    public var shadeTilt: Float = 68
    public var arm: Float = 0.34
    public var lit = true
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let paint = "metal.enamel:" + String(format: "%06X", color)
        let chrome: MaterialKey = "metal.chrome", Z = V3(0, 0, 1)
        // Stepped base and turret.
        m.add(turned([(0, 0), (0.104, 0), (0.108, 0.004), (0.108, 0.022), (0.102, 0.028), (0.08, 0.03), (0.076, 0.034), (0.074, 0.046),
                      (0.068, 0.05), (0.03, 0.052), (0.026, 0.058), (0, 0.058)], segments: 40, material: paint))
        m.add(Prim.cylinder(radius: 0.105, height: 0.003, bevel: 0.001, segments: 32, bevelSegments: 1, material: "rubber"), Xform(translation: V3(0, -0.0005, 0)))
        m.add(Prim.cylinder(radius: 0.022, height: 0.02, bevel: 0.003, segments: 20, material: paint), Xform(translation: V3(0, 0.056, 0)))
        let P0 = V3(0, 0.088, 0)
        for s: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.03, 0.04, 0.005), radius: 0.002, bevelSegments: 1, material: paint), Xform(translation: V3(0, 0.08, s * 0.0255)))
        }
        // Arms: twin flat bars in the XY plane, chrome knuckles at the pivots.
        let la = radians(lowerAngle), ua = radians(upperAngle)
        let P1 = P0 + V3(cos(la), sin(la), 0) * arm
        let P2 = P1 + V3(cos(ua), sin(ua), 0) * arm
        func bars(_ a: V3, _ b: V3, gap: Float) {
            for s: Float in [-1, 1] {
                let (bar, x) = board(from: a, to: b, width: 0.013, thick: 0.0045, up: Z, bevel: 0.0014, material: paint, extend: 0.012)
                m.add(bar, Xform(translation: x.translation + Z * s * gap, rotation: x.rotation))
            }
        }
        bars(P0, P1, gap: 0.021)
        bars(P1, P2, gap: 0.014)
        for (p, w) in [(P0, Float(0.064)), (P1, 0.05), (P2, 0.04)] {
            m.add(Prim.cylinder(radius: 0.0045, height: w, bevel: 0.0012, segments: 12, material: chrome),
                  Xform(translation: p - Z * w / 2, rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            for s: Float in [-1, 1] {
                m.add(Prim.cylinder(radius: 0.0085, height: 0.004, bevel: 0.0013, segments: 14, material: chrome),
                      Xform(translation: p + Z * s * (w / 2 - 0.002) - Z * 0.002, rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
        }
        // Tension knobs (wing nuts) on the elbow and head knuckles.
        for p in [P1, P2] {
            m.add(Prim.cylinder(radius: 0.011, height: 0.006, bevel: 0.002, segments: 14, material: chrome),
                  Xform(translation: p + Z * 0.024, rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            m.add(Prim.roundedBox(V3(0.03, 0.009, 0.004), radius: 0.003, bevelSegments: 1, material: chrome),
                  Xform(translation: p + Z * 0.027, rotation: simd_quatf(degrees: 30, axis: Z)))
        }
        // Tension springs: from the turret's rear lever up to a bracket on the lower arm.
        let up = simd_normalize(P1 - P0)
        for (i, z) in [-0.046, -0.034, 0.034, 0.046].enumerated() {
            let a = P0 + V3(0.028, -0.026, Float(z))
            let b = P0 + up * 0.15 + V3(0.012, 0, Float(z) * 0.7)
            let len = simd_distance(a, b) - 0.012
            let turns: Float = 18 + Float(i % 2) * 2
            let spring = Prim.helix(radius: 0.0062, pitch: len / turns, turns: turns, wire: 0.0013, perTurn: 7, sides: 3, material: chrome)
            m.add(spring, Xform(translation: a + simd_normalize(b - a) * 0.006, rotation: facing(b - a)))
            m.add(Prim.tube([a, a + simd_normalize(b - a) * 0.007], radii: [0.0012, 0.0012], sides: 4, seamTile: 0.01, material: chrome))
            m.add(Prim.tube([b - simd_normalize(b - a) * 0.007, b], radii: [0.0012, 0.0012], sides: 4, seamTile: 0.01, material: chrome))
        }
        m.add(Prim.roundedBox(V3(0.016, 0.012, 0.1), radius: 0.003, bevelSegments: 1, material: paint), Xform(translation: P0 + V3(0.028, -0.026, 0)))
        m.add(Prim.roundedBox(V3(0.012, 0.01, 0.07), radius: 0.003, bevelSegments: 1, material: paint), Xform(translation: P0 + up * 0.15 + V3(0.012, 0, 0)))
        // Shade: domed shell (outer enamel, inner white reflector), rolled rim, rear cap, switch, bulb.
        let d = simd_normalize(V3(cos(radians(-shadeTilt)), sin(radians(-shadeTilt)), 0))
        let q = facing(d)
        let rear = P2 + d * 0.022
        let outer = Profile.smooth([V2(0.026, 0), V2(0.031, 0.018), V2(0.043, 0.05), V2(0.055, 0.09), V2(0.0625, 0.122)], per: 4)
        m.add(Prim.lathe(outer, segments: 36, seamTile: 0.3, material: paint), Xform(translation: rear, rotation: q))
        m.add(Prim.lathe(outer.map { V2($0.x - 0.0016, $0.y) }, segments: 36, seamTile: 0.3, material: "plastic.white").flipped(), Xform(translation: rear, rotation: q))
        m.add(Prim.torus(major: 0.0625, minor: 0.0022, segments: 36, sides: 6, material: paint), Xform(translation: rear + d * 0.122, rotation: q))
        m.add(turned([(0, -0.034), (0.012, -0.033), (0.022, -0.026), (0.025, -0.012), (0.028, 0.0), (0.026, 0.004)], segments: 24, material: chrome),
              Xform(translation: rear, rotation: q))
        // Ventilation slots around the shade shoulder.
        for k in 0..<10 {
            let a = Float(k) / 10 * 2 * .pi
            let rr: Float = 0.0335
            let local = V3(cos(a) * rr, 0.024, -sin(a) * rr)
            m.add(Prim.roundedBox(V3(0.004, 0.012, 0.0016), radius: 0.0007, bevelSegments: 1, material: "plastic.black"),
                  Xform(translation: rear + q.act(local), rotation: q * simd_quatf(angle: a + .pi / 2, axis: .up) * simd_quatf(degrees: 14, axis: V3(1, 0, 0))))
        }
        let side = simd_normalize(simd_cross(d, Z))
        let topDir = simd_dot(side, V3(0, 1, 0)) > 0 ? side : -side
        m.add(Prim.cylinder(radius: 0.0035, height: 0.016, bevel: 0.0012, segments: 10, material: chrome),
              Xform(translation: rear - d * 0.027 + topDir * 0.017, rotation: facing(topDir)))
        if lit {
            m.add(Prim.superellipsoid(V3(0.044, 0.052, 0.044), exponent: 2, subdivisions: 5, material: "emissive.bulb"), Xform(translation: rear + d * 0.052, rotation: q))
        }
        // Cloth cable: out of the cap, along the arms, off the base onto the desk.
        let back = V3(-0.11, 0, 0)
        let cable = catmull([rear - d * 0.03, P1 + V3(-0.012, 0, -0.03), P0 + V3(-0.026, -0.01, -0.03), V3(-0.09, 0.032, -0.03),
                             back + V3(-0.03, 0.004, -0.04), back + V3(-0.06, 0.003, rng.float(-0.08...0.08))], per: 5)
        m.add(Prim.tube(cable.map { $0.y < 0.0028 ? V3($0.x, 0.0028, $0.z) : $0 }, radii: cable.map { _ in 0.0028 }, sides: 6, seamTile: 0.02,
                        material: "fabric.canvas:2A2826"))
        // Center the footprint.
        let bb = m.bounds
        m = m.transformed(Xform(translation: V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)))
        groundAO(&m, height: 0.05, floor: 0.6)
        return LODModel(m)
    }
}
