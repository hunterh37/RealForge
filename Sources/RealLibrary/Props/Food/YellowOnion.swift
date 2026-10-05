import simd
import Foundation

/// Yellow storage onion standing on its root plate. Two nested closed shells: the papery copper skin
/// (uncapped when cut, with a twisted dry neck and a ring of dried root stubs on the dimpled root
/// plate) over the white fleshy bulb, whose cut face shows concentric scale rings (`food.onion-rings`,
/// tile = bulb diameter, centered on the vertical axis).
public struct YellowOnion: RealFood {
    public static let id = "yellow-onion"
    public static let summary = "Yellow storage onion, 8 cm: papery copper skin over white fleshy scales, twisted neck, root plate with dry root stubs."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let kind = FoodKind.vegetable
    public static let preview = PreviewHint(azimuth: 30, elevation: 20, distance: 0.3, studio: true)

    /// Bulb diameter (m).
    public var diameter: Float = 0.078
    /// Height of the bulb shoulder-to-base, without the neck (m).
    public var bulbHeight: Float = 0.072
    /// Dry neck length above the bulb (m).
    public var neck: Float = 0.016
    /// Number of dried root stubs on the root plate.
    public var roots = 34
    /// Skin, flesh and cut-face keys.
    public var skin: MaterialKey = "food.onion-skin"
    public var flesh: MaterialKey = "food.onion"
    public var rings: MaterialKey = "food.onion-rings"
    /// Dried root stub key (skin paper tinted grey-tan).
    public var root: MaterialKey = "food.onion-skin:9A8466"
    /// Peeling outer layer (paler, thinner paper).
    public var flapKey: MaterialKey = "food.onion-skin:C99A62"
    public init() {}

    public var coreCenter: V3 { V3(0, bulbHeight * 0.48, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == flesh ? rings : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let R = diameter / 2, H = bulbHeight
        // Bulb outline (radius, y): dimpled root plate, full belly at 40 %, shoulders tapering into the neck.
        let bulb: [V2] = [V2(0, 0.006), V2(0.006, 0.004), V2(0.012, 0.002), V2(R * 0.45, 0.0035), V2(R * 0.68, 0.009), V2(R * 0.84, H * 0.15), V2(R * 0.94, H * 0.26),
                          V2(R * 0.99, H * 0.36), V2(R, H * 0.46), V2(R * 0.95, H * 0.6), V2(R * 0.78, H * 0.76),
                          V2(R * 0.5, H * 0.9), V2(R * 0.2, H * 0.98), V2(0.0045, H + 0.002)]
        let fleshProfile = bulb.map { V2($0.x * (1 - 0.0008 / R) , $0.y) } + [V2(0, H + 0.004)]
        var skinProfile = bulb.map { V2($0.x == 0 ? 0 : $0.x + 0.0006, $0.y - ($0.y < 0.007 ? 0.0006 : 0)) }
        skinProfile.removeLast()
        skinProfile += [V2(0.0048, H + 0.002), V2(0.0032, H + neck * 0.4), V2(0.0022, H + neck * 0.85), V2(0.0018, H + neck), V2(0, H + neck + 0.0005)]
        var fl = FoodMesh.revolve(edge: 0.0052, seamTile: 0.06, material: flesh, curve: FoodMesh.profile(fleshProfile))
        var sk = FoodMesh.revolve(edge: 0.0042, seamTile: 0.08, material: skin, curve: FoodMesh.profile(skinProfile))
        // Shared asymmetry: lobed, slightly leaning bulb; the neck twists and bends.
        let ph = (0..<4).map { _ in rng.float(0...6.28) }
        let lean = V2(rng.float(-0.003...0.003), rng.float(-0.003...0.003))
        let shape: (V3) -> V3 = { p in
            let a = atan2(p.z, p.x)
            let t = min(1, max(0, p.y / H))
            let k = 1 + 0.025 * sin(a * 3 + ph[0]) * sin(.pi * t) + 0.015 * sin(a * 2 + ph[1])
            var q = V3(p.x * k, p.y, p.z * k)
            q.x += lean.x * t * t; q.z += lean.y * t * t
            if p.y > H * 0.9 {
                let n = (p.y - H * 0.9) / (H * 0.1 + self.neck)
                let tw = n * 3.0
                q = V3(q.x * cos(tw) - q.z * sin(tw), q.y, q.x * sin(tw) + q.z * cos(tw))
                q.x += 0.004 * n * n; q.z += 0.002 * n * n * sin(ph[2])
            }
            return q
        }
        // A torn outer skin layer peeling away near the shoulder: a thin closed shell that follows the
        // bulb, lifted and curled at its lower edge.
        let skinCurve = FoodMesh.profile(skinProfile)
        let samples = (0...200).map { skinCurve(Float($0) / 200) }
        func radius(at y: Float) -> Float {
            var best: Float = 0, bd: Float = .infinity
            for q in samples where q.y < H * 0.95 && abs(q.y - y) < bd { bd = abs(q.y - y); best = q.x }
            return best
        }
        let a0 = rng.float(0...6.28), y0 = H * rng.float(0.12...0.18), fh = H * 0.55, fw = R * 0.6
        let rag = (0..<3).map { _ in rng.float(0...6.28) }
        var flap = FoodMesh.sections(edge: 0.003, length: fh, seamTile: 0.08, material: flapKey) { t in
            let torn = 1 + 0.07 * sin(t * 8 + rag[0]) + 0.04 * sin(t * 15 + rag[1])
            let ends = pow(min(1, t * 6), 0.5) * pow(1 - t, 0.7)
            return (max(1e-4, fw * 0.55 * ends * (1.1 - 0.5 * t) * torn), 0.00025, 6, .zero)
        }
        flap.deform { p in
            let t = p.y / fh, y = y0 + p.y
            let across = p.x / fw
            let lift = 0.009 * pow(1 - t, 2.5) * (0.75 + 0.25 * across) + 0.0007
            let r = radius(at: y) + 0.0004 + lift + p.z
            let a = a0 + p.x / max(radius(at: y), 0.01)
            return V3(r * cos(a), y - 0.002 * pow(1 - t, 3), -r * sin(a))
        }
        fl.deform(shape)
        sk.deform(shape)
        flap.deform(shape)
        // Papery wrinkles on the skin only (pushes outward, so it stays outside the flesh).
        sk.displace { p, _ in
            let a = atan2(p.z, p.x)
            let r = 0.0003 * (1 + sin(a * 7 + p.y * 60 + ph[3])) + 0.0002 * (1 + sin(a * 11 - p.y * 40))
            return r * smoothstep(0.004, 0.012, p.y)
        }
        var m = Model(name: Self.id)
        m.add(fl)
        m.add(sk)
        m.add(flap)
        // Dried root stubs: short wiry closed tubes fanning from the root plate.
        for i in 0..<roots {
            var r = rng.fork(i)
            let a = Float(i) / Float(roots) * 2 * .pi + r.float(-0.2...0.2)
            let rr = r.float(0.0008...0.007)
            let base = V3(cos(a) * rr, 0.0045, sin(a) * rr)
            let out = V3(cos(a), 0, sin(a))
            let len = r.float(0.007...0.016)
            let droop = r.float(0.3...0.9)
            let curl = r.float(-1...1)
            let pts = (0...4).map { k -> V3 in
                let t = Float(k) / 4
                let side = simd_cross(out, .up) * curl * 0.003 * t * t
                return base + out * (len * t) + V3(0, -droop * 0.005 * t * t - 0.001 * t, 0) + side
            }
            let rad = r.float(0.0004...0.00065)
            m.add(FoodMesh.tube(pts, radii: pts.indices.map { rad * (1 - 0.5 * Float($0) / 4) }, sides: 5, endBulge: 0.3, material: root))
        }
        let bb = m.bounds
        m = m.transformed(Xform(translation: V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)))
        groundAO(&m, height: 0.02, floor: 0.55)
        return LODModel(m)
    }
}
