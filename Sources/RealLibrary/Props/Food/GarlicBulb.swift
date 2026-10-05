import simd
import Foundation

/// Softneck garlic head standing on its root plate. Nested closed shells: papery purple-streaked
/// skin (uncapped when cut, with a short cut stem neck and a tuft of dry roots) over the clove mass,
/// whose cut face shows the ring of cloves (`food.garlic-section`, tile = bulb diameter, centered on
/// the vertical axis). Clove bulges show through the skin as vertical lobes.
public struct GarlicBulb: RealFood {
    public static let id = "garlic-bulb"
    public static let summary = "Garlic bulb, 6 cm: papery purple-streaked skin over segmented cloves, root plate with dry roots, cut stem neck."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let kind = FoodKind.vegetable
    public static let preview = PreviewHint(azimuth: 30, elevation: 25, distance: 0.24, studio: true)

    /// Bulb diameter (m).
    public var diameter: Float = 0.06
    /// Bulb height without the neck (m).
    public var bulbHeight: Float = 0.045
    /// Cut stem neck length (m).
    public var neck: Float = 0.011
    /// Clove count (lobes).
    public var cloves = 9
    /// Root count.
    public var roots = 40
    /// Material keys.
    public var skin: MaterialKey = "food.garlic-skin"
    public var flesh: MaterialKey = "food.garlic-clove"
    public var section: MaterialKey = "food.garlic-section"
    public var root: MaterialKey = "food.garlic-skin:B8A47E"
    public init() {}

    static let plate: Float = 0.0012
    public var coreCenter: V3 { V3(0, bulbHeight * 0.45 - Self.plate, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == flesh ? section : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let R = diameter / 2 / 1.05, H = bulbHeight
        let bulb: [V2] = [V2(0, 0.0045), V2(0.005, 0.0032), V2(0.01, 0.0018), V2(R * 0.55, 0.004), V2(R * 0.8, H * 0.14),
                          V2(R * 0.96, H * 0.32), V2(R, H * 0.48), V2(R * 0.94, H * 0.64), V2(R * 0.74, H * 0.82),
                          V2(R * 0.42, H * 0.95), V2(R * 0.16, H * 1.0), V2(0.0035, H + 0.002)]
        let fleshP = bulb.dropLast().map { V2($0.x * (1 - 0.0012 / R), $0.y - ($0.y > H * 0.9 ? 0.0008 : 0) + ($0.y < H * 0.2 ? 0.0009 : 0)) } + [V2(0, H * 0.985)]
        var skinP = bulb.map { V2($0.x == 0 ? 0 : $0.x + 0.0005, $0.y - ($0.y < 0.005 ? 0.0006 : 0)) }
        skinP.removeLast()
        skinP += [V2(0.0036, H + 0.002), V2(0.0026, H + neck * 0.5), V2(0.0021, H + neck), V2(0, H + neck + 0.0003)]
        var fl = FoodMesh.revolve(edge: 0.0042, seamTile: 0.05, material: flesh, curve: FoodMesh.profile(fleshP))
        var sk = FoodMesh.revolve(edge: 0.0033, seamTile: 0.05, material: skin, curve: FoodMesh.profile(skinP))
        let a0 = rng.float(0...6.28), n = Float(cloves)
        let amp = (0..<cloves).map { _ in rng.float(0.7...1.3) }
        let ph = rng.float(0...6.28)
        let shape: (V3) -> V3 = { p in
            let a = atan2(p.z, p.x)
            let t = min(1, max(0, p.y / H))
            let seg = (a - a0) / (2 * .pi / n)
            let i = ((Int(seg.rounded(.down)) % cloves) + cloves) % cloves
            let f = seg - seg.rounded(.down)
            // Rounded clove bulges with creases between them, fading at the plate and the neck.
            let bulge = pow(sin(.pi * f), 0.45) * amp[i]
            let fade = sin(.pi * min(1, t * 1.05))
            let k = 1 + 0.12 * (bulge - 0.72) * fade + 0.02 * sin(a * 2 + ph)
            var q = V3(p.x * k, p.y, p.z * k)
            if p.y > H * 0.9 { let w = (p.y - H * 0.9) / (H * 0.1 + self.neck); q.x += 0.0015 * w * w }
            return q
        }
        fl.deform(shape)
        sk.deform(shape)
        var m = Model(name: Self.id)
        m.add(fl); m.add(sk)
        // Dense dry root tuft from the plate, wiry and splayed.
        var rootS = Surface(material: root)
        for i in 0..<roots {
            var r = rng.fork(i)
            let a = r.float(0...6.28), rr = r.float(0...0.0075)
            let base = V3(cos(a) * rr, 0.004, sin(a) * rr)
            let out = simd_normalize(V3(cos(a) + r.float(-0.3...0.3), 0, sin(a) + r.float(-0.3...0.3)))
            let len = r.float(0.006...0.014)
            let pts = (0...4).map { k -> V3 in
                let t = Float(k) / 4
                var q = base + out * (len * t) + V3(0, -0.004 * t * t, 0)
                q.y = max(q.y, Self.plate + 0.0005)
                return q
            }
            let rad = r.float(0.00028...0.00045)
            rootS.append(FoodMesh.tube(pts, radii: pts.indices.map { rad * (1 - 0.4 * Float($0) / 4) }, sides: 4, endBulge: 0.3, material: root))
        }
        m.add(rootS)
        m = m.transformed(Xform(translation: V3(0, -Self.plate, 0)))
        groundAO(&m, height: 0.015, floor: 0.55)
        return LODModel(m)
    }
}
