import simd
import Foundation

/// Curb-inlet storm drain grate: a cast-iron bar grate seated in an angle frame inside a precast
/// concrete apron. The dark sump shows between the bars, with silt and a few leaves caught on the
/// cross ribs.
public struct StormDrainGrate: RealAsset {
    public static let id = "storm-drain-grate"
    public static let summary = "Storm drain inlet grate: cast-iron bar grate in a frame with a concrete apron."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal", "road"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 50, distance: 1.0)

    /// Apron size X, Z (m).
    public var apron = V2(0.95, 0.65)
    /// Grate opening X, Z (m).
    public var grate = V2(0.7, 0.42)
    /// Bar width and gap (m).
    public var bar: Float = 0.022
    public var gap: Float = 0.032
    /// Materials.
    public var iron: MaterialKey = "metal.cast-iron-street"
    public var polished: MaterialKey = "metal.cast-iron-worn"
    public var concrete: MaterialKey = "concrete.sidewalk:7E7A72"
    public var silt: MaterialKey = "ground.mud"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let top: Float = 0.035, gx = grate.x / 2, gz = grate.y / 2
        // Apron: four concrete strips around the opening.
        let ax = apron.x / 2, az = apron.y / 2, f: Float = 0.03
        for (cx, cz, sx, sz) in [(Float(0), -(az + gz + f) / 2, apron.x, az - gz - f), (0, (az + gz + f) / 2, apron.x, az - gz - f),
                                 (-(ax + gx + f) / 2, 0, ax - gx - f, 2 * (gz + f)), ((ax + gx + f) / 2, 0, ax - gx - f, 2 * (gz + f))] {
            m.add(Prim.roundedBox(V3(sx - 0.003, top, sz - 0.003), radius: 0.008, bevelSegments: 2, material: concrete), Xform(translation: V3(cx, top / 2, cz)))
        }
        // Sump floor with silt, deep shadowed.
        m.add(Prim.roundedBox(V3(grate.x + 2 * f, 0.004, grate.y + 2 * f), radius: 0.001, bevelSegments: 1, material: silt), Xform(translation: V3(0, 0.002, 0)))
        // Frame angle around the opening.
        for (cx, cz, sx, sz) in [(Float(0), -(gz + f / 2), grate.x + 2 * f, f), (0, gz + f / 2, grate.x + 2 * f, f), (-(gx + f / 2), 0, f, grate.y), (gx + f / 2, 0, f, grate.y)] {
            m.add(Prim.roundedBox(V3(sx, 0.012, sz), radius: 0.003, bevelSegments: 1, material: iron), Xform(translation: V3(cx, top - 0.004, cz)))
        }
        // Bars along Z (in the direction of flow toward the curb), two cross ribs below their tops.
        let n = Int((grate.x + gap) / (bar + gap))
        let used = Float(n) * bar + Float(n - 1) * gap
        for i in 0..<n {
            let x = -used / 2 + bar / 2 + Float(i) * (bar + gap)
            m.add(Prim.roundedBox(V3(bar, 0.03, grate.y - 0.004), radius: 0.004, bevelSegments: 1, material: i % 4 == 0 ? polished : iron),
                  Xform(translation: V3(x, top + 0.002 - 0.015, 0)))
        }
        for s: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(grate.x - 0.004, 0.018, 0.018), radius: 0.003, bevelSegments: 1, material: iron), Xform(translation: V3(0, top - 0.02, s * grate.y * 0.22)))
        }
        // Leaves and litter caught on the bars.
        for _ in 0..<7 {
            let p = V3(rng.float(-gx...gx), top + 0.004, rng.float(-gz...gz))
            m.add(Prim.superellipsoid(V3(rng.float(0.03...0.05), 0.002, rng.float(0.018...0.03)), exponent: 2, subdivisions: 2, material: rng.chance(0.5) ? "leaf.oak" : "mulch.bark"),
                  Xform(translation: p, rotation: simd_quatf(angle: rng.float(0...6.28), axis: .up)))
        }
        groundAO(&m, height: 0.04, floor: 0.7)
        return LODModel(m)
    }
}
