import simd
import Foundation

/// Cast concrete pedestal birdbath, 0.68 m tall, 0.6 m basin: square stepped plinth, fluted baluster
/// pedestal, scalloped basin with a rolled lip, standing water with a stain ring, moss at the foot.
public struct Birdbath: RealAsset {
    public static let id = "birdbath"
    public static let summary = "Cast concrete pedestal birdbath, 0.68 m: scalloped basin with water, fluted baluster pedestal, square plinth."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "concrete", "decor"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 25)

    /// Basin outer diameter (m).
    public var basinDiameter: Float = 0.6
    /// Overall height to the basin lip (m).
    public var height: Float = 0.68
    /// Number of scallops on the basin rim.
    public var scallops: Int = 8
    /// Cast stone material.
    public var stone: MaterialKey = "concrete.rough:9C978A"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = basinDiameter / 2, H = height
        // Plinth: two stepped square slabs.
        m.add(Prim.roundedBox(V3(0.3, 0.05, 0.3), radius: 0.01, bevelSegments: 2, material: stone), Xform(translation: V3(0, 0.025, 0)))
        m.add(Prim.roundedBox(V3(0.24, 0.035, 0.24), radius: 0.008, bevelSegments: 2, material: stone), Xform(translation: V3(0, 0.0665, 0)))
        // Baluster pedestal with flutes on the shaft.
        let base: Float = 0.083, top = H - 0.13
        let prof: [(Float, Float)] = [(0, base), (0.1, base), (0.1, base + 0.015), (0.085, base + 0.03), (0.075, base + 0.05),
                                     (0.062, base + 0.12), (0.055, base + 0.22), (0.058, base + 0.3), (0.07, top - 0.06),
                                     (0.09, top - 0.025), (0.1, top - 0.01), (0.1, top), (0, top)]
        var ped = turned(prof, segments: 48, material: stone, seamTile: 0.5)
        ped.displace { p, n in
            guard p.y > base + 0.06, p.y < top - 0.07 else { return 0 }
            let a = atan2(p.z, p.x), f = max(0, cos(a * 12))
            let fade = min(1, min(p.y - base - 0.06, top - 0.07 - p.y) / 0.03)
            return -0.011 * pow(f, 0.5) * fade * max(0, simd_dot(n, simd_normalize(V3(p.x, 0, p.z))))
        }
        m.add(ped, Xform(rotation: simd_quatf(degrees: rng.float(0...30), axis: .up)))
        // Basin: shell with thickness, scalloped rim.
        let lip: Float = H, bottom = top - 0.005
        let outer: [V2] = [V2(0, bottom), V2(0.1, bottom), V2(0.18, bottom + 0.04), V2(R - 0.03, lip - 0.04), V2(R, lip - 0.015), V2(R, lip - 0.004)]
        let inner: [V2] = [V2(R - 0.025, lip), V2(R - 0.035, lip - 0.02), V2(R - 0.09, lip - 0.06), V2(0.12, lip - 0.085), V2(0, lip - 0.09)]
        var bowl = Prim.lathe(outer + [V2(R - 0.006, lip)] + inner, segments: 64, seamTile: 0.5, material: stone)
        let sc = Float(scallops)
        bowl.deform { p in
            let r = simd_length(V2(p.x, p.z))
            guard r > R * 0.7 else { return p }
            let a = atan2(p.z, p.x), w = (r - R * 0.7) / (R * 0.3)
            let k = 1 + 0.035 * w * cos(a * sc)
            return V3(p.x * k, p.y + 0.008 * w * cos(a * sc), p.z * k)
        }
        m.add(bowl)
        // Water and stain ring.
        let wy = lip - 0.03
        m.add(Prim.lathe([V2(R - 0.05, wy), V2(0, wy)], segments: 48, seamTile: 1, material: "water.pond"))
        m.add(Prim.lathe([V2(R - 0.043, wy + 0.006), V2(R - 0.052, wy + 0.0015)], segments: 48, seamTile: 0.2, material: "concrete.rough:6E6B60"))
        // Moss tufts at the plinth foot.
        for i in 0..<5 {
            let a = Float(i) / 5 * 2 * .pi + rng.float(-0.3...0.3)
            let p = V3(cos(a) * 0.175, 0.0, sin(a) * 0.175)
            m.add(Prim.superellipsoid(V3(rng.float(0.04...0.07), 0.018, rng.float(0.03...0.05)), exponent: 2.5, subdivisions: 2, material: "moss.cushion"),
                  Xform(translation: p + V3(0, 0.004, 0), rotation: simd_quatf(degrees: rng.float(0...180), axis: .up)))
        }
        groundAO(&m, height: 0.2)
        return LODModel(m)
    }
}
