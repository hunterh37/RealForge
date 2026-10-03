import simd
import Foundation

/// Cluster of 3-7 brown-capped woodland mushrooms, caps 2.5-6 cm across on 3-8 cm stalks: lathe caps
/// with an inrolled margin, a gill disc on the underside and swollen stalk bases. LOD1: fewer segments.
public struct MushroomCluster: RealAsset {
    public static let id = "mushroom-cluster"
    public static let summary = "Cluster of 3-7 woodland mushrooms, caps 2.5-6 cm: lathe caps with inrolled margins, gilled undersides, stalks; 2 LODs."
    public static let tags = ["nature", "fungus", "plant"]
    public static let budget = 2_400
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 35, elevation: 20, distance: 1.0)

    public var count: ClosedRange<Int> = 3...7
    /// Largest cap radius, meters.
    public var capRadius: Float = 0.03
    public var capMaterial: MaterialKey = "fungus.cap"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m0 = Model(name: Self.id), m1 = Model(name: Self.id)
        let n = rng.int(count)
        for i in 0..<n {
            let a = rng.float(0...6.28), r = i == 0 ? 0 : rng.float(0.015...0.06)
            let young = rng.chance(0.3)
            let R = capRadius * (young ? rng.float(0.4...0.6) : rng.float(0.65...1))
            let stalkH = R * rng.float(1.6...2.6)
            let tilt = simd_quatf(angle: rng.float(0.05...0.35) * (r > 0 ? 1 : 0.3), axis: V3(-sin(a), 0, cos(a)))
            let x = Xform(translation: V3(cos(a) * r, -0.004, sin(a) * r), rotation: tilt * simd_quatf(angle: rng.float(0...6.28), axis: .up))
            for (lod, seg) in [(0, 14), (1, 8)] {
                var m = Model(name: Self.id)
                build(&m, R: R, stalkH: stalkH, young: young, seg: seg, rng: rng.fork(i))
                if lod == 0 { m0.add(m, x) } else { m1.add(m, x) }
            }
        }
        groundAO(&m0, height: 0.03, floor: 0.6); groundAO(&m1, height: 0.03, floor: 0.6)
        return LODModel(levels: [m0, m1], switchDistances: [4])
    }

    func build(_ m: inout Model, R: Float, stalkH: Float, young: Bool, seg: Int, rng: SeededRNG) {
        var rng = rng
        let rs = R * rng.float(0.16...0.22)
        let H = R * (young ? rng.float(0.7...0.85) : rng.float(0.35...0.55))
        let y0 = stalkH
        // Cap, rim to apex (outward normals): inrolled lip, then a dome.
        var cap: [V2] = [V2(R * 0.9, y0 + 0.02 * R), V2(R * 0.99, y0 + 0.08 * R)]
        let bands = seg > 10 ? 6 : 3
        for k in 1...bands {
            let f = Float(k) / Float(bands), ph = f * .pi / 2
            let rr = R * pow(cos(ph), 0.85)
            cap.append(V2(k == bands ? 0 : rr, y0 + 0.1 * R + H * sin(ph) * (1 + 0.04 * rng.float(-1...1))))
        }
        m.add(Prim.lathe(cap, segments: seg, seamTile: 0.06, material: capMaterial))
        // Gills: stalk out to just inside the lip (downward normals).
        m.add(Prim.lathe([V2(rs * 1.05, y0 + 0.14 * R), V2(R * 0.9, y0 + 0.03 * R)], segments: seg, seamTile: 0.04, material: "fungus.gills"))
        // Stalk, slightly swollen base, sunk 4 mm into the ground.
        let stalk: [V2] = [V2(rs * 1.35, 0), V2(rs * 1.15, 0.15 * y0), V2(rs * 0.98, 0.6 * y0), V2(rs * 0.95, y0 + 0.15 * R)]
        m.add(Prim.lathe(stalk, segments: max(6, seg - 4), seamTile: 0.05, material: "fungus.stalk"))
    }
}
