import simd
import Foundation

/// A loose bundle of dry spaghetti (about 100 g, one generous portion for two) lying along X: ~110
/// strands 25.5 cm long and 1.8 mm thick, packed into a slumped 2.4 x 1.6 cm bundle with staggered
/// flat-cut ends and a few strands splayed out. Each strand is its own closed tube so cuts cap per
/// strand. Cook kind `batter`: the cook shader softens dry pasta toward `food.pasta-cooked`.
public struct Spaghetti: RealFood {
    public static let id = "spaghetti"
    public static let summary = "Dry spaghetti bundle, 25.5 cm: ~110 straight 1.8 mm strands, staggered cut ends, a few splayed; softens when boiled."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let kind = FoodKind.batter
    public static let preview = PreviewHint(azimuth: 35, elevation: 30, distance: 0.5, studio: true)

    /// Strand length (m).
    public var length: Float = 0.255
    /// Strand diameter (m).
    public var strand: Float = 0.0018
    /// Strand count.
    public var count = 110
    /// Material key.
    public var pasta: MaterialKey = "food.pasta-dry"
    public init() {}

    public var coreCenter: V3 { V3(0, 0.006, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == pasta ? pasta : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let r = strand / 2
        // Pack centers in a slumped ellipse (wider than tall), dart-throwing with min spacing.
        var centers: [V2] = []
        let hw: Float = 0.0135, hh: Float = 0.0088
        var tries = 0
        while centers.count < count && tries < 40_000 {
            tries += 1
            let p = V2(rng.float(-hw...hw), rng.float(-hh...hh))
            let e = pow(p.x / hw, 2) + pow(p.y / hh, 2)
            if e > 1 { continue }
            if centers.contains(where: { simd_distance($0, p) < strand * 1.02 }) { continue }
            centers.append(p)
        }
        var s = Surface(material: pasta)
        for (i, c) in centers.enumerated() {
            var rr = rng.fork(i)
            let stagger = rr.float(-0.004...0.004)
            let x0 = -length / 2 + stagger, x1 = length / 2 + stagger
            // Splay: outer strands fan out a little toward one end.
            let e = sqrt(pow(c.x / hw, 2) + pow(c.y / hh, 2))
            let splay = e > 0.8 && rr.float() < 0.25 ? rr.float(0.002...0.008) : rr.float(0...0.0012)
            let dir = rr.float(0...6.28)
            let endOff = V2(cos(dir), max(-0.2, sin(dir))) * splay
            let sag = rr.float(-0.0006...0.0006)
            let pts: [V3] = [V3(x0, c.y, c.x), V3(0, c.y + sag, c.x + sag), V3(x1, c.y + endOff.y, c.x + endOff.x)]
            let tube = FoodMesh.tube(pts, radii: [r, r, r], sides: 5, endBulge: 0, seamTile: 0.02, material: pasta)
            s.append(tube)
        }
        var m = Model(name: Self.id)
        m.add(s)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.008, floor: 0.55)
        return LODModel(m)
    }
}
