import simd
import Foundation

/// Victorian two-dial post clock, 4.3 m: a stepped cast-iron base with a door, a fluted column, a
/// drum head with two white dials (hour marks, Roman-style batons, black hands) behind brass bezels,
/// and a crown with a finial. Repainted green; the base shows chips.
public struct StreetClock: RealAsset {
    public static let id = "street-clock"
    public static let summary = "Two-dial post clock, 4.3 m: cast-iron column, fluted base, clock head with two white dials and a crown."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal", "antique"]
    public static let budget = 11000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 8, distance: 1.0)

    /// Overall height (m).
    public var height: Float = 4.3
    /// Dial radius (m).
    public var dialRadius: Float = 0.38
    /// Time shown (hours, minutes).
    public var time: (Int, Int) = (10, 9)
    /// Materials.
    public var paint: MaterialKey = "metal.painted:1F3A2C"
    public var brass: MaterialKey = "metal.brass-aged"
    public var dial: MaterialKey = "paint.wall:DCD6C4"
    public var hands: MaterialKey = "metal.painted:141414"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = dialRadius, cy = height - R - 0.17, drumD: Float = 0.3
        // Base and column.
        m.add(turned([(0, 0), (0.32, 0), (0.32, 0.06), (0.28, 0.09), (0.27, 0.5), (0.24, 0.54), (0.22, 0.75), (0.16, 0.85), (0.14, 1.0), (0, 1.0)], segments: 8, material: paint),
              Xform(rotation: simd_quatf(degrees: 22.5, axis: .up)))
        var col = Prim.lathe([V2(0.11, 1.0), V2(0.1, 1.1), V2(0.09, cy - R - 0.4), V2(0.12, cy - R - 0.3), V2(0.16, cy - R - 0.15), V2(0.16, cy - R - 0.05), V2(0, cy - R - 0.05)],
                             segments: 48, seamTile: 0.2, material: paint)
        col = col.displacedFlutes(count: 12, depth: 0.01, y0: 1.12, y1: cy - R - 0.42)
        m.add(col)
        for y in [Float(1.05), cy - R - 0.38] { m.add(Prim.torus(major: 0.11, minor: 0.018, segments: 28, sides: 8, material: paint), Xform(translation: V3(0, y, 0))) }
        // Access door on the base.
        m.add(Prim.roundedBox(V3(0.18, 0.3, 0.02), radius: 0.01, bevelSegments: 1, material: paint), Xform(translation: V3(0, 0.3, 0.265)))
        m.add(Prim.cylinder(radius: 0.012, height: 0.01, bevel: 0.003, segments: 10, material: brass), Xform(translation: V3(0.06, 0.3, 0.275), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Head: drum along Z with two dials.
        let drum = Xform(translation: V3(0, cy, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)))
        m.add(Prim.cylinder(radius: R + 0.05, height: drumD, bevel: 0.02, segments: 40, material: paint), drum.child(Xform(translation: V3(0, -drumD / 2, 0))))
        let (hh, mm) = time
        for s: Float in [1, -1] {
            let face = Xform(translation: V3(0, cy, s * (drumD / 2 + 0.002)), rotation: simd_quatf(angle: s > 0 ? 0 : .pi, axis: .up))
            m.add(Prim.torus(major: R + 0.012, minor: 0.018, segments: 48, sides: 8, material: brass), face.child(Xform(rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)))))
            m.add(Prim.cylinder(radius: R, height: 0.004, bevel: 0.001, segments: 40, material: dial), face.child(Xform(rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)))))
            for k in 0..<60 {
                let a = Float(k) / 60 * 2 * .pi, big = k % 5 == 0
                let len: Float = big ? 0.06 : 0.018, w: Float = big ? 0.014 : 0.004
                m.add(cuboid(V3(w, len, 0.001), material: hands), face.child(Xform(translation: V3(sin(a), cos(a), 0) * (R - 0.03 - len / 2) + V3(0, 0, 0.0045), rotation: simd_quatf(angle: -a, axis: V3(0, 0, 1)))))
            }
            let ma = Float(mm) / 60 * 2 * .pi, ha = (Float(hh % 12) + Float(mm) / 60) / 12 * 2 * .pi
            for (a, len, w) in [(ha, R * 0.62, Float(0.034)), (ma, R * 0.92, Float(0.022))] {
                m.add(Prim.roundedBox(V3(w, len, 0.004), radius: 0.002, bevelSegments: 1, material: hands),
                      face.child(Xform(translation: V3(sin(a), cos(a), 0) * (len / 2 - 0.03) + V3(0, 0, 0.008), rotation: simd_quatf(angle: -a, axis: V3(0, 0, 1)))))
            }
            m.add(Prim.cylinder(radius: 0.018, height: 0.012, bevel: 0.004, segments: 12, material: brass), face.child(Xform(translation: V3(0, 0, 0.004), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)))))
            m.add(Prim.cylinder(radius: R + 0.004, height: 0.003, bevel: 0.001, segments: 40, material: "glass.pane"), face.child(Xform(translation: V3(0, 0, 0.016), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)))))
        }
        // Crown and finial.
        m.add(turned([(0, cy + R + 0.03), (0.2, cy + R + 0.03), (0.22, cy + R + 0.06), (0.12, cy + R + 0.1), (0.08, cy + R + 0.12), (0.05, height - 0.06), (0.03, height - 0.04),
                      (0.02, height), (0, height)], segments: 20, material: paint))
        m.add(Prim.roundedBox(V3(0.12, 0.08, 0.16), radius: 0.02, bevelSegments: 2, material: paint), Xform(translation: V3(0, cy + R + 0.03, 0)))
        // Chips on the base.
        for _ in 0..<10 {
            let a = rng.float(0...6.28), y = rng.float(0.05...0.45)
            m.add(cuboid(V3(rng.float(0.01...0.03), rng.float(0.006...0.016), 0.001), material: "metal.rust"),
                  Xform(translation: V3(sin(a) * 0.263, y, cos(a) * 0.263), rotation: simd_quatf(angle: a, axis: .up)))
        }
        groundAO(&m, height: 0.3, floor: 0.6)
        return LODModel(m)
    }
}
