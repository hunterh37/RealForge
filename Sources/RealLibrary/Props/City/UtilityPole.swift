import simd
import Foundation

/// Wood distribution pole, 12 m above grade: a tapered, checked cedar pole with a crossarm on two
/// flat braces, three pin insulators, a pole-top transformer can on a bracket with its drop leads,
/// a ground-wire molding, step bolts, a pole tag and short wire stubs cut off at both sides.
public struct UtilityPole: RealAsset {
    public static let id = "utility-pole"
    public static let summary = "Wood utility pole, 12 m, with a crossarm, pin insulators, a pole-top transformer and wire stubs."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "wood", "metal"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 8, distance: 1.0)

    /// Height above grade (m).
    public var height: Float = 12
    /// Butt and top radius (m).
    public var butt: Float = 0.16
    public var tip: Float = 0.11
    /// Crossarm length (m).
    public var armLength: Float = 2.4
    /// Wire stub length each side (m).
    public var stub: Float = 0.5
    /// Include the transformer.
    public var transformer = true
    /// Materials.
    public var wood: MaterialKey = "wood.lumber-oak:4C4238"
    public var steel: MaterialKey = "metal.galvanized"
    public var porcelain: MaterialKey = "ceramic.stoneware:6A6E66"
    public var can: MaterialKey = "metal.painted:8A9094"
    public var wire: MaterialKey = "metal.copper"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let H = height
        func r(_ y: Float) -> Float { butt + (tip - butt) * y / H }
        let lean = V3(rng.float(-0.06...0.06), 0, rng.float(-0.06...0.06))
        m.add(turned([(0, 0), (butt, 0), (r(H * 0.5), H * 0.5), (tip, H - 0.04), (tip - 0.02, H), (0, H)], segments: 16, material: wood, grainVertical: true),
              Xform(rotation: simd_quatf(from: .up, to: simd_normalize(V3(0, H, 0) + lean))))
        let top = V3(0, H, 0) + lean
        func at(_ y: Float) -> V3 { V3(0, y, 0) + lean * (y / H) }
        // Crossarm (along X) through-bolted 0.6 m below the top, two flat braces.
        let ay = H - 0.6, ap = at(ay)
        m.add(Prim.roundedBox(V3(armLength, 0.11, 0.09), radius: 0.008, bevelSegments: 1, material: "wood.weathered"), Xform(translation: ap + V3(0, 0, r(ay) + 0.045)))
        for s: Float in [-1, 1] {
            let a = ap + V3(s * 0.7, -0.05, r(ay) + 0.02), b = at(ay - 0.6) + V3(0, 0, r(ay - 0.6) + 0.01)
            m.add(Prim.tube([a, b], radii: [0.012, 0.012], sides: 4, seamTile: 0.1, material: steel))
        }
        hexBolt(&m, at: ap + V3(0, 0, r(ay) + 0.09), normal: V3(0, 0, 1), size: 0.03, material: steel)
        // Pin insulators on the arm, and wire stubs tied in.
        var tips: [V3] = []
        for x in [-armLength / 2 + 0.15, -0.35, armLength / 2 - 0.15] {
            let base = ap + V3(x, 0.055, r(ay) + 0.045)
            m.add(Prim.cylinder(radius: 0.012, height: 0.08, bevel: 0.003, segments: 8, material: steel), Xform(translation: base))
            m.add(turned([(0.0, 0.06), (0.05, 0.06), (0.07, 0.08), (0.05, 0.1), (0.065, 0.13), (0.045, 0.15), (0.05, 0.17), (0.035, 0.2), (0, 0.21)], segments: 16, material: porcelain),
                  Xform(translation: base))
            tips.append(base + V3(0, 0.18, 0))
        }
        // Static / neutral on the pole top.
        let pin = top + V3(0, 0.03, 0)
        m.add(turned([(0.0, 0), (0.04, 0), (0.05, 0.05), (0.035, 0.09), (0, 0.1)], segments: 12, material: porcelain), Xform(translation: pin))
        tips.append(pin + V3(0, 0.08, 0))
        for t in tips {
            for s: Float in [-1, 1] {
                let pts = (0...4).map { i -> V3 in let u = Float(i) / 4; return t + V3(0, -0.05 * u * u, s * stub * u) }
                m.add(Prim.tube(pts, radii: Array(repeating: 0.007, count: pts.count), sides: 5, seamTile: 0.05, material: wire))
            }
        }
        // Transformer can on a bracket 2 m below the arm, with bushings and drop leads.
        if transformer {
            let ty = ay - 2.0, tp = at(ty) + V3(0, 0, r(ty))
            m.add(Prim.roundedBox(V3(0.2, 0.5, 0.06), radius: 0.01, bevelSegments: 1, material: steel), Xform(translation: tp + V3(0, 0.1, 0.03)))
            let c = tp + V3(0, 0, 0.3)
            m.add(turned([(0, 0), (0.24, 0), (0.25, 0.03), (0.25, 0.85), (0.27, 0.87), (0.27, 0.9), (0.18, 0.96), (0, 0.97)], segments: 24, material: can), Xform(translation: c))
            for k in 0..<5 { m.add(Prim.torus(major: 0.252, minor: 0.008, segments: 24, sides: 4, material: can), Xform(translation: c + V3(0, 0.15 + Float(k) * 0.15, 0))) }
            for s: Float in [-1, 1] {
                let b = c + V3(s * 0.1, 0.95, 0)
                m.add(turned([(0, 0), (0.03, 0), (0.035, 0.03), (0.025, 0.05), (0.03, 0.07), (0.015, 0.1), (0, 0.1)], segments: 10, material: porcelain), Xform(translation: b))
                let to = tips[s < 0 ? 0 : 2]
                let mid = (b + to) / 2 + V3(0, -0.4, 0.15)
                m.add(Prim.tube(catmull([b + V3(0, 0.1, 0), mid, to], per: 6), radii: Array(repeating: 0.006, count: 13), sides: 5, seamTile: 0.05, material: "rubber"))
            }
        }
        // Ground-wire molding down the back, step bolts, pole tag.
        m.add(Prim.roundedBox(V3(0.03, H - 3, 0.012), radius: 0.004, bevelSegments: 1, material: "plastic.matte:2A2A2A"),
              Xform(translation: at(1.5 + (H - 3) / 2) + V3(0, 0, -r(H / 2) - 0.004)))
        for k in 0..<10 {
            let y = 2.6 + Float(k) * 0.45, a: Float = (k % 2 == 0 ? 1 : -1) * 1.2
            let d = V3(sin(a), 0, cos(a))
            m.add(Prim.tube([at(y) + d * (r(y) - 0.01), at(y) + d * (r(y) + 0.13), at(y) + d * (r(y) + 0.13) + V3(0, 0.04, 0)], radii: [0.009, 0.009, 0.009], sides: 6, seamTile: 0.05, material: steel))
        }
        m.add(Prim.roundedBox(V3(0.09, 0.06, 0.004), radius: 0.005, bevelSegments: 1, material: "metal.aluminum-brushed"), Xform(translation: at(1.8) + V3(0, 0, r(1.8) + 0.002)))
        // Drying checks: dark splits running up the pole.
        for _ in 0..<9 {
            let a = rng.float(0...6.28), y0 = rng.float(0.5...6), len = rng.float(0.8...2.6), d = V3(sin(a), 0, cos(a))
            m.add(cuboid(V3(0.006, len, 0.004), material: "wood.lumber-oak:1E1812"), Xform(translation: at(y0 + len / 2) + d * (r(y0 + len / 2) - 0.0005), rotation: simd_quatf(angle: a, axis: .up)))
        }
        // Rust-streaked galvanized guard plate where car doors and mowers hit.
        m.add(Prim.lathe([V2(butt + 0.004, 0.0), V2(r(1.0) + 0.004, 1.0)], segments: 16, seamTile: 0.2, material: "metal.galvanized-aged"), Xform(rotation: simd_quatf(angle: 0, axis: .up)))
        // Staple-scars: a few old flyer remnants at eye height.
        for _ in 0..<3 {
            let a = rng.float(-0.6...0.6), y = rng.float(1.4...1.9), d = V3(sin(a), 0, cos(a))
            m.add(cuboid(V3(rng.float(0.05...0.12), rng.float(0.06...0.14), 0.0008), material: rng.pick(["paper.sheet", "sign.white:E8D070"])),
                  Xform(translation: at(y) + d * (r(y) + 0.003), rotation: simd_quatf(angle: a, axis: .up)))
        }
        groundAO(&m, height: 0.4, floor: 0.6)
        let b = m.bounds, cc = (b.min + b.max) / 2
        var out = Model(name: Self.id); out.add(m, Xform(translation: V3(-cc.x, 0, -cc.z)))
        return LODModel(out)
    }
}
