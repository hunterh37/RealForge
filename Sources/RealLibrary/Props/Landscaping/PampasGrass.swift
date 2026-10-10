import simd
import Foundation

/// Pampas grass, 2.1 m: fountain of arching serrated blades and 14-22 tall stalks with feathery cream plumes.
public struct PampasGrass: RealAsset {
    public static let id = "pampas-grass"
    public static let summary = "Pampas grass, 2.1 m: fountain of arching blades and 14-22 stalks with cream plumes."
    public static let tags = ["prop", "landscaping", "garden", "plant", "grass", "outdoor"]
    public static let budget = 15000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 15)

    public var blades = 90...130
    public var plumes = 14...22
    public var bladeLength: ClosedRange<Float> = 1.0...1.6
    public var plumeHeight: ClosedRange<Float> = 1.6...2.1
    public var plumeColor = "EFE6D0"
    public var leaf: MaterialKey = "grass.reed"
    public var stem: MaterialKey = "plant.stem:B9B58A"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [10])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let plumeMat: MaterialKey = "leaf.plain:" + plumeColor
        var lf = Surface(material: leaf), st = Surface(material: stem), pl = Surface(material: plumeMat)
        var lr = rng.fork(1)
        for _ in 0..<lr.int(blades) {
            var b = PlantKit.Blade()
            let a = lr.float(0...(2 * .pi)), rr = 0.12 * sqrt(lr.float())
            b.root = V3(cos(a) * rr, 0, sin(a) * rr); b.yaw = a + lr.float(-0.3...0.3)
            b.length = lr.float(bladeLength); b.width = lr.float(0.012...0.02); b.lean = lr.float(0.15...0.7); b.curl = lr.float(1.2...1.9)
            b.segments = detail ? 8 : 4; b.u = V2(0.1, 0.9); b.ao = V2(0.4, 1); b.weight = V2(0, 0.8)
            lf.append(PlantKit.blade(b, material: leaf))
        }
        var sr = rng.fork(2)
        for i in 0..<sr.int(plumes) {
            let a = sr.float(0...(2 * .pi)), rr = 0.1 * sqrt(sr.float())
            let pts = PlantKit.arc(from: V3(cos(a) * rr, 0, sin(a) * rr), height: sr.float(plumeHeight), yaw: a, lean: sr.float(0.05...0.25), bend: sr.float(0.1...0.3), count: 6)
            st.append(PlantKit.stem(pts, radius: 0.006, tipRadius: 0.003, sides: 4, weight: V2(0, 0.8), phase: Float(i) * 0.4, material: stem))
            let top = pts[pts.count - 1], tan = simd_normalize(top - pts[pts.count - 2])
            let q = simd_quatf(from: V3(0, 1, 0), to: tan)
            for _ in 0..<(detail ? 26 : 12) {
                var b = PlantKit.Blade()
                b.root = V3(0, -0.2 * sr.float(0...1), 0); b.yaw = sr.float(0...(2 * .pi))
                b.length = sr.float(0.3...0.5); b.width = 0.014; b.lean = sr.float(0.05...0.4); b.curl = sr.float(0.1...0.5)
                b.segments = 3; b.u = V2(0.1, 0.9); b.weight = V2(0.8, 1); b.phase = Float(i) * 0.4; b.ao = V2(0.7, 1); b.upNormal = 0.8
                pl.append(PlantKit.blade(b, material: plumeMat), Xform(translation: top, rotation: q))
            }
        }
        for s in [lf, st, pl] where !s.isEmpty { m.add(s) }
        ShrubKit.finish(&m, height: 0.3, floor: 0.5)
        PlantKit.finish(&m)
        ShrubKit.clampGround(&m)
        return ShrubKit.centered(m)
    }
}
