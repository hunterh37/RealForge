import simd
import Foundation

/// English lavender (Lavandula angustifolia) in bloom, 0.65 m across and 0.55 m tall: a dome of narrow
/// grey-green leaves, under 45-70 thin square stalks topped with 5-8 cm purple flower spikes made of
/// stacked whorls.
public struct LavenderClump: RealAsset {
    public static let id = "lavender-clump"
    public static let summary = "English lavender, 0.55 m: grey-green dome of narrow leaves under 45-70 stalks with purple flower spikes."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 14500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 18)

    public var width: Float = 0.65
    public var height: Float = 0.55
    /// Leaf blades in the foliage dome.
    public var leaves = 1700
    public var stalks: ClosedRange<Int> = 45...70
    public var foliage: MaterialKey = "leaf.lavender"
    public var stem: MaterialKey = "plant.stem:6E7A5A"
    public var flower: MaterialKey = "flower.lavender"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: 1), model(seed: seed, detail: 0.45)], switchDistances: [8])
    }

    func model(seed: UInt64, detail: Float) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let w = rng.vary(width, 0.06), h = rng.vary(height, 0.05)
        let dome = h * 0.64
        // Foliage: narrow blades radiating from the crown, lengths chosen so the tips fill a low dome.
        let R = w * 0.46
        var leafRng = rng.fork(1)
        var leafS = Surface(material: foliage)
        for _ in 0..<Int(Float(leaves) * detail) {
            var bl = PlantKit.Blade()
            let rr = 0.06 * sqrt(leafRng.float()), a = leafRng.float(0...(2 * .pi))
            bl.root = V3(cos(a) * rr, 0, sin(a) * rr)
            bl.yaw = a + leafRng.float(-0.4...0.4)
            let lean = acos(1 - leafRng.float(0...0.97))
            bl.lean = lean * 0.85
            bl.curl = lean * 0.25 + leafRng.float(0...0.15)
            let tipLen = 1 / sqrt(pow(sin(lean) / R, 2) + pow(cos(lean) / dome, 2))
            bl.length = tipLen * leafRng.float(0.75...1.02)
            bl.width = leafRng.float(0.004...0.006)
            bl.segments = detail > 0.5 ? 3 : 2
            let col = Float(leafRng.int(0...7))
            bl.u = V2((col + 0.15) / 8, (col + 0.85) / 8)
            bl.ao = V2(0.3, leafRng.float(0.8...1))
            bl.weight = V2(0, 0.45)
            bl.upNormal = 0.5
            leafS.append(PlantKit.blade(bl, material: foliage))
        }
        m.add(leafS)
        // Flower stalks with spikes.
        var sr = rng.fork(2)
        var stems = Surface(material: stem), spikes = Surface(material: flower)
        let count = Int(Float(sr.int(stalks)) * (detail > 0.5 ? 1 : 0.6))
        for i in 0..<count {
            let rr = 0.07 * sqrt(sr.float()), a = sr.float(0...(2 * .pi))
            let base = V3(cos(a) * rr, 0.02, sin(a) * rr)
            let lean = sr.float(0.05...0.42)
            let len = h * sr.float(0.8...1.0) - 0.06
            let pts = PlantKit.arc(from: base, height: len, yaw: a + sr.float(-0.3...0.3), lean: lean, bend: sr.float(0.05...0.25), count: 5)
            stems.append(PlantKit.stem(pts, radius: 0.0016, tipRadius: 0.0011, sides: 3, weight: V2(0, 0.9), phase: Float(i) * 0.37, material: stem))
            let tip = pts[pts.count - 1], ax = simd_normalize(tip - pts[pts.count - 2])
            let sl = sr.float(0.045...0.07)
            let rings = detail > 0.5 ? 5 : 3
            var sp: [V3] = [], rad: [Float] = []
            for k in 0...rings {
                let t = Float(k) / Float(rings)
                sp.append(tip + ax * (sl * t - 0.004))
                let whorl = 0.75 + 0.25 * abs(sin(t * Float(rings) * .pi * 0.5 + 0.3))
                rad.append(0.0055 * whorl * (k == rings ? 0.35 : (1 - 0.45 * t)))
            }
            spikes.append(Prim.tube(sp, radii: rad, sides: detail > 0.5 ? 5 : 4, seamTile: 0.03, material: flower,
                                    weights: sp.map { _ in 0.95 }, phase: Float(i) * 0.37, capEnd: true))
        }
        m.add(stems); m.add(spikes)
        ShrubKit.finish(&m, height: 0.2, floor: 0.45)
        PlantKit.finish(&m)
        ShrubKit.clampGround(&m)
        return ShrubKit.fit(m, size: V3(w, h, w * 0.99))
    }
}
