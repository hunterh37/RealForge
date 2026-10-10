import simd
import Foundation

/// Butterfly bush (Buddleja davidii) in bloom, 1 m: an arching mound of lance-shaped grey-green
/// leaves topped by long conical panicles of tiny lilac-purple flowers with orange eyes, the classic
/// butterfly and bee magnet.
public struct FlowerBush: RealAsset {
    public static let id = "flower-bush"
    public static let summary = "Butterfly bush in bloom, 1 m: arching mound of grey-green leaves with long lilac flower panicles."
    public static let tags = ["prop", "plant", "flower", "garden", "outdoor", "landscaping"]
    public static let budget = 14_500
    public static let preview = PreviewHint(azimuth: 30, elevation: 15)

    public var width: Float = 1.2
    public var height: Float = 0.95
    public var panicles = 44
    public var leaf: MaterialKey = "leaf.privet"
    public var mass: MaterialKey = "leaf.privet-mass"
    public var flower: MaterialKey = "flower.hydrangea:A88ADA"
    public var stem: MaterialKey = "plant.stem:5A5038"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: 1), model(seed: seed, detail: 0.4)], switchDistances: [9])
    }

    func model(seed: UInt64, detail: Float) -> Model {
        var rng = SeededRNG(seed: seed)
        let w = rng.vary(width, 0.06), h = rng.vary(height, 0.06)
        let crown = ShrubKit.Crown(center: V3(0, h * 0.4, 0), radii: V3(w / 2 - 0.05, h * 0.58, w / 2 - 0.05),
                                   exponent: 2.2, lumps: 0.5, lumpScale: 2.4, seed: rng.float(0...50), floorY: 0.06)
        var m = Model(name: Self.id)
        m.add(ShrubKit.core(crown, depth: 0.86, subdivisions: detail > 0.5 ? 8 : 5, material: mass))
        var a = rng.fork(1)
        m.add(ShrubKit.sprays(crown, count: Int(700 * detail), size: 0.14...0.2, depth: 0.88...1.04, minY: -0.6, tilt: 0.7, bend: 0.3...0.7, rng: &a, material: leaf))
        // Panicles: arching cones of florets at the crown top.
        var b = rng.fork(2)
        var fl = Surface(material: flower)
        let n = Int(Float(panicles) * (detail > 0.5 ? 1 : 0.6))
        for _ in 0..<n {
            var dir = b.unitVector(); dir.y = abs(dir.y) * 0.6 + 0.25; dir = simd_normalize(dir)
            let base = crown.point(dir, depth: 0.95)
            let axis = simd_normalize(dir + V3(0, 0.25, 0))
            let len = b.float(0.24...0.34)
            let out = simd_normalize(axis + simd_normalize(V3(dir.x, 0, dir.z)) * 0.5 + V3(0, 0.3, 0))
            let mid = base + axis * 0.05
            let tip = mid + out * len
            let path = [base - axis * 0.06, mid]
            m.add(Prim.tube(path, radii: path.indices.map { _ in 0.003 }, sides: 4, seamTile: 0.02, material: stem, capEnd: true))
            // Panicle: a tapering cone of tightly packed florets (lumpy cube-sphere along the stalk axis).
            let pax = simd_normalize(tip - mid)
            let plen = len * 0.8
            let pc = mid + pax * plen * 0.48
            let rot = simd_quatf(from: V3(0, 1, 0), to: pax)
            let seedN = b.float(0...50)
            var cone = Prim.cubeSphere(subdivisions: detail > 0.5 ? 4 : 2, material: flower) { d in
                let t = (d.y + 1) / 2                                   // 0 base, 1 tip
                let r = 0.045 * pow(1 - t, 0.8) * (0.55 + 0.45 * sqrt(min(1, t * 4))) + 0.003
                let bump = 1 + 0.22 * abs(Noise.fbm(d * 9 + V3(seedN, 0, 0), octaves: 2))
                let q = V3(d.x / max(0.001, sqrt(1 - d.y * d.y)) * r * bump * sqrt(max(0, 1 - d.y * d.y)), d.y * plen * 0.5, d.z / max(0.001, sqrt(1 - d.y * d.y)) * r * bump * sqrt(max(0, 1 - d.y * d.y)))
                return pc + rot.act(q)
            }
            for i in cone.extra.indices { cone.extra[i] = V2(0.8, seedN) }
            m.add(cone)
        }
        m.add(fl)
        if detail > 0.5 {
            var s = rng.fork(3)
            m.add(ShrubKit.stems(count: 9, rootRadius: 0.1, crown: crown, reach: 0.6, radius: 0.008...0.016, rng: &s, material: stem))
        }
        ShrubKit.finish(&m, height: 0.3, floor: 0.45)
        return ShrubKit.fit(m, size: V3(w, h, w))
    }
}
