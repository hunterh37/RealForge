import simd
import Foundation

/// Orange daylily (Hemerocallis fulva) clump in summer bloom, 0.8 m across: a fountain of 55-80 long
/// keeled strap leaves, 8-14 bare scapes rising above them, each with one or two open six-tepal trumpet
/// flowers (recurved, 10-12 cm) and a few closed buds.
public struct DaylilyClump: RealAsset {
    public static let id = "daylily-clump"
    public static let summary = "Daylily clump, 0.8 m: arching strap leaves and scapes with orange six-petal trumpet flowers and buds."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 10000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 15)

    public var width: Float = 0.8
    public var height: Float = 0.8
    public var leaves: ClosedRange<Int> = 55...80
    public var scapes: ClosedRange<Int> = 8...14
    public var leaf: MaterialKey = "grass.reed"
    public var stem: MaterialKey = "plant.stem:5E7230"
    public var flower: MaterialKey = "flower.daylily"
    public var bud: MaterialKey = "plant.stem:8A9A40"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [8])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        var lr = rng.fork(1)
        var leafS = Surface(material: leaf)
        for _ in 0..<lr.int(leaves) {
            var b = PlantKit.Blade()
            let rr = 0.05 * sqrt(lr.float()), a = lr.float(0...(2 * .pi))
            b.root = V3(cos(a) * rr, 0, sin(a) * rr)
            b.yaw = a + lr.float(-0.4...0.4)
            b.length = lr.float(0.45...0.75)
            b.width = lr.float(0.02...0.03)
            b.lean = lr.float(0.15...0.6)
            b.curl = lr.float(1.0...1.9)
            b.twist = lr.float(-0.6...0.6)
            b.fold = 0.22
            b.segments = detail ? 7 : 4
            let col = Float(lr.int(0...7))
            b.u = V2((col + 0.1) / 8, (col + 0.9) / 8)
            b.ao = V2(0.4, lr.float(0.85...1))
            b.weight = V2(0, 0.8)
            leafS.append(PlantKit.blade(b, material: leaf))
        }
        m.add(leafS)
        var sr = rng.fork(2)
        var stems = Surface(material: stem), petals = Surface(material: flower), buds = Surface(material: bud)
        for i in 0..<sr.int(scapes) {
            let rr = 0.04 * sqrt(sr.float()), a = sr.float(0...(2 * .pi))
            let base = V3(cos(a) * rr, 0, sin(a) * rr)
            let h = height * sr.float(0.82...0.95)
            let pts = PlantKit.arc(from: base, height: h, yaw: a, lean: sr.float(0.05...0.3), bend: sr.float(0.0...0.2), count: 5)
            stems.append(PlantKit.stem(pts, radius: 0.0032, tipRadius: 0.0022, sides: detail ? 5 : 3, weight: V2(0, 0.8), phase: Float(i) * 0.4, material: stem))
            let top = pts[pts.count - 1]
            // Open flowers face outward and up on short pedicels.
            for f in 0..<(sr.chance(0.6) ? 1 : 2) {
                let fy = a + Float(f) * 2.4 + sr.float(-0.5...0.5)
                let out = V3(cos(fy), 0, sin(fy))
                let c = top + out * 0.025 + V3(0, 0.005, 0)
                let tilt = simd_quatf(angle: sr.float(0.5...0.85), axis: simd_normalize(simd_cross(V3(0, 1, 0), out)))
                let spin = sr.float(0...1)
                for k in 0..<6 {
                    var p = PlantKit.Blade()
                    let outer = k % 2 == 0
                    p.root = .zero
                    p.yaw = Float(k) * .pi / 3 + spin
                    p.length = outer ? 0.07 : 0.075
                    p.width = outer ? 0.02 : 0.028
                    p.tipWidth = 0.25
                    p.lean = sr.float(0.45...0.6)
                    p.curl = sr.float(0.9...1.3)
                    p.fold = outer ? -0.12 : -0.2
                    p.segments = detail ? 4 : 2
                    p.u = V2(0, p.width); p.v = V2(0, p.length)
                    p.weight = V2(0.8, 0.95); p.phase = Float(i) * 0.4
                    p.ao = V2(0.55, 1); p.upNormal = 0.2
                    petals.append(PlantKit.blade(p, material: flower), Xform(translation: c + (outer ? V3(0, -0.002, 0) : .zero), rotation: tilt))
                }
                stems.append(PlantKit.stem([top, c], radius: 0.002, tipRadius: 0.0025, sides: 3, weight: V2(0.8, 0.9), phase: Float(i) * 0.4, material: stem))
            }
            if detail {
                for k in 0..<sr.int(2...3) {
                    let by = a + Float(k) * 2.0 + 1.2
                    let s = Prim.superellipsoid(V3(0.011, 0.05, 0.011), exponent: 2, subdivisions: 3, material: bud)
                    let rot = simd_quatf(angle: sr.float(0.2...0.6), axis: V3(-sin(by), 0, cos(by)))
                    buds.append(s, Xform(translation: top + V3(cos(by), 0, sin(by)) * 0.01 + V3(0, 0.02, 0), rotation: rot))
                }
            }
        }
        m.add(stems); m.add(petals)
        if !buds.isEmpty { m.add(buds) }
        ShrubKit.finish(&m, height: 0.2, floor: 0.45)
        PlantKit.finish(&m)
        ShrubKit.clampGround(&m)
        return ShrubKit.fit(m, size: V3(width, height, width * 0.99))
    }
}
