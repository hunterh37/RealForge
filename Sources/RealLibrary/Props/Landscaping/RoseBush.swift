import simd
import Foundation

/// Shrub rose, about 0.9 m wide and 1.0 m tall: upright green canes from a woody crown, an open crown
/// of dark serrated leaflets, 14-20 open red blooms (three nested whorls of cupped petals, 8-10 cm) and
/// a few tight buds. Lower canes are bare.
public struct RoseBush: RealAsset {
    public static let id = "rose-bush"
    public static let summary = "Shrub rose, 1.0 m: woody canes, dark serrated leaves, 14-20 red cupped blooms and buds."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 14000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 15)

    public var width: Float = 0.9
    public var height: Float = 1.0
    public var sprays = 820
    public var blooms: ClosedRange<Int> = 14...20
    public var bloomDiameter: ClosedRange<Float> = 0.09...0.115
    public var buds = 5
    public var leaf: MaterialKey = "leaf.rose"
    public var flower: MaterialKey = "flower.rose"
    public var cane: MaterialKey = "plant.stem:4A5A26"
    public var mass: MaterialKey = "leaf.boxwood-mass"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: 1), model(seed: seed, detail: 0.4)], switchDistances: [9])
    }

    func model(seed: UInt64, detail: Float) -> Model {
        var rng = SeededRNG(seed: seed)
        let w = rng.vary(width, 0.06), h = rng.vary(height, 0.05)
        let card: Float = 0.2
        // Three to five leafy lobes at different heights on their own canes: an open, uneven shrub.
        var m = Model(name: Self.id)
        var lobes: [ShrubKit.Crown] = []
        let nl = rng.int(3...5)
        for k in 0..<nl {
            let ang = Float(k) / Float(nl) * 2 * .pi + rng.float(-0.4...0.4)
            let off = rng.float(0.1...0.2)
            let ry = rng.float(0.2...0.28) * h
            let rxz = rng.float(0.22...0.3) * w
            let cy = h - ry - rng.float(0...0.3) * h
            lobes.append(ShrubKit.Crown(center: V3(cos(ang) * off, cy, sin(ang) * off), radii: V3(rxz, ry, rxz), exponent: 2,
                                        lumps: 0.5, lumpScale: 3, seed: rng.float(0...50), floorY: 0.1))
        }
        lobes.append(ShrubKit.Crown(center: V3(0, h * 0.42, 0), radii: V3(w * 0.34, h * 0.36, w * 0.34), exponent: 2,
                                    lumps: 0.5, lumpScale: 3, seed: rng.float(0...50), floorY: 0.12))
        var a = rng.fork(1)
        var c = rng.fork(2)
        var leafS = Surface(material: leaf)
        for (k, lobe) in lobes.enumerated() {
            m.add(ShrubKit.core(lobe, depth: 0.55, subdivisions: detail > 0.5 ? 5 : 3, material: mass))
            leafS.append(ShrubKit.sprays(lobe, count: Int(Float(sprays) * detail) / lobes.count, size: (card * 0.8)...(card * 1.15),
                                         depth: 0.65...1.02, minY: -0.5, tilt: 0.9, bend: 0.2...0.7, rng: &a, material: leaf))
            m.add(ShrubKit.stems(count: detail > 0.5 ? (k == lobes.count - 1 ? 4 : 3) : 1, rootRadius: 0.06, crown: lobe, reach: 0.5,
                                 radius: 0.006...0.011, sides: detail > 0.5 ? 5 : 3, rng: &c, material: cane))
        }
        m.add(leafS)
        // Blooms: three whorls of cupped petals, outer ones flared.
        var b = rng.fork(3)
        var flowers = Surface(material: flower)
        let segs = detail > 0.5 ? 15 : 10
        for _ in 0..<b.int(blooms) {
            let lobe = lobes[b.int(0...(lobes.count - 1))]
            var dir = b.unitVector(); dir.y = dir.y * 0.5 + 0.2; dir = simd_normalize(dir)
            let p0 = lobe.point(dir, depth: 1.0)
            let p = p0 + lobe.normal(p0) * 0.05
            let axis = simd_normalize(lobe.normal(p0) + V3(0, 0.5, 0) + b.unitVector() * 0.2)
            let d = b.float(bloomDiameter), r = d / 2
            let spin = b.float(0...6.28)
            let whorls: [[V2]] = [
                [V2(r * 0.12, 0), V2(r * 0.55, r * 0.28), V2(r * 0.88, r * 0.6), V2(r, r * 0.78)],
                [V2(r * 0.08, 0), V2(r * 0.42, r * 0.3), V2(r * 0.62, r * 0.68), V2(r * 0.64, r * 0.84)],
                [V2(r * 0.05, 0.002), V2(r * 0.3, r * 0.35), V2(r * 0.4, r * 0.75), V2(r * 0.3, r * 0.85)],
            ]
            for (k, prof) in whorls.enumerated() {
                flowers.append(ShrubKit.bloom(at: p + axis * r * 0.15, axis: axis, profile: prof, lobes: 5 - k, lobeDepth: 0.28 - Float(k) * 0.06,
                                              segments: segs, spin: spin + Float(k) * 0.7, weight: 0.6, material: flower))
            }
        }
        var bud = Surface(material: flower)
        for _ in 0..<(detail > 0.5 ? buds : 0) {
            let lobe = lobes[b.int(0...(lobes.count - 1))]
            var dir = b.unitVector(); dir.y = abs(dir.y) * 0.7 + 0.4; dir = simd_normalize(dir)
            let p = lobe.point(dir, depth: 1.02)
            let s = Prim.superellipsoid(V3(0.022, 0.036, 0.022), exponent: 2, subdivisions: 3, material: flower)
            bud.append(s, Xform(translation: p + V3(0, 0.02, 0), rotation: simd_quatf(angle: b.float(-0.3...0.3), axis: V3(1, 0, 0))))
        }
        if !bud.isEmpty { flowers.append(bud) }
        m.add(flowers)
        ShrubKit.finish(&m, height: 0.3, floor: 0.5)
        return ShrubKit.fit(m, size: V3(w, h, w * 0.99))
    }
}
