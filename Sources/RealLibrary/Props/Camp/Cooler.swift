import simd
import Foundation

/// 50-quart hard cooler, 66 x 42 x 44 cm: tapered molded body, white domed lid with hinge knuckles and a
/// front latch, swing handles on both ends, drain plug, scuffs and dirt from the plastic program.
public struct Cooler: RealAsset {
    public static let id = "cooler"
    public static let summary = "50-quart hard cooler, 66 x 42 x 44 cm: tapered molded body, domed white lid, hinges, latch, swing handles, drain plug."
    public static let tags = ["prop", "camp", "plastic", "container"]
    public static let budget = 4_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 18, distance: 1.1)

    public var size = V3(0.66, 0.44, 0.42)
    /// Body color (sRGB hex); the lid stays white.
    public var bodyColor: UInt32 = 0x2C5A88
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let body = "plastic.white:" + String(format: "%06X", bodyColor)
        let L = size.x, H = size.y, W = size.z
        let bodyH = H - 0.075
        // Body: rounded box tapering 4 percent toward the base.
        var b = Prim.roundedBox(V3(L, bodyH, W), radius: 0.035, bevelSegments: 3, material: body)
        b.positions = b.positions.map { p in
            let t = (p.y + bodyH / 2) / bodyH
            let k: Float = 0.96 + 0.04 * t
            return V3(p.x * k, p.y + bodyH / 2, p.z * k)
        }
        b.recomputeNormals(); b.computeTangents()
        m.add(b)
        // Recessed base band.
        m.add(Prim.roundedBox(V3(L * 0.93, 0.02, W * 0.9), radius: 0.008, bevelSegments: 2, material: "plastic.black"), Xform(translation: V3(0, 0.008, 0)))
        // Lid: slightly larger, domed top.
        var lid = Prim.roundedBox(V3(L + 0.008, 0.07, W + 0.008), radius: 0.03, bevelSegments: 3, material: "plastic.white")
        lid.positions = lid.positions.map { p in
            var q = p
            if p.y > 0 { q.y += 0.012 * (1 - pow(p.x / (L / 2), 2)) * (1 - pow(p.z / (W / 2), 2)) }
            return q
        }
        lid.recomputeNormals(); lid.computeTangents()
        m.add(lid, Xform(translation: V3(0, bodyH + 0.037, 0)))
        // Parting-line shadow gap.
        m.add(Prim.roundedBox(V3(L - 0.01, 0.006, W - 0.01), radius: 0.002, bevelSegments: 1, material: "plastic.black"), Xform(translation: V3(0, bodyH + 0.001, 0)))
        // Hinge knuckles at the back, latch at the front, drain plug.
        for x: Float in [-0.2, 0.2] {
            m.add(Prim.tube([V3(x - 0.04, bodyH + 0.01, -W / 2 - 0.006), V3(x + 0.04, bodyH + 0.01, -W / 2 - 0.006)], radii: [0.011, 0.011], sides: 10,
                            seamTile: 0.1, material: "plastic.white"))
        }
        m.add(Prim.roundedBox(V3(0.07, 0.06, 0.018), radius: 0.005, bevelSegments: 2, material: "plastic.black"), Xform(translation: V3(0, bodyH - 0.005, W / 2 + 0.004)))
        m.add(turned([(0, 0), (0.016, 0), (0.016, 0.012), (0.011, 0.016), (0, 0.016)], segments: 14, material: "plastic.white"),
              Xform(translation: V3(L / 2 - 0.08, 0.05, W / 2 - 0.005), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Swing handles on both ends, hanging from pivots.
        for s: Float in [-1, 1] {
            let x = s * (L / 2 * 0.99 + 0.012)
            let drop = rng.float(0.0...0.02)
            let path = catmull([V3(x, bodyH - 0.06, -0.12), V3(x + s * 0.012, bodyH - 0.13 - drop, -0.1), V3(x + s * 0.018, bodyH - 0.15 - drop, 0),
                                V3(x + s * 0.012, bodyH - 0.13 - drop, 0.1), V3(x, bodyH - 0.06, 0.12)], per: 5)
            m.add(Prim.tube(path, radii: path.map { _ in 0.0085 }, sides: 8, seamTile: 0.1, material: "plastic.black", capEnd: false))
            for z: Float in [-0.12, 0.12] {
                m.add(turned([(0, 0), (0.016, 0), (0.016, 0.012), (0, 0.014)], segments: 12, material: "plastic.black"),
                      Xform(translation: V3(x - s * 0.006, bodyH - 0.06, z), rotation: simd_quatf(degrees: -90 * s, axis: V3(0, 0, 1))))
            }
        }
        groundAO(&m, height: 0.12, floor: 0.6)
        return LODModel(m.transformed(Xform(rotation: simd_quatf(degrees: rng.float(-2...2), axis: .up))))
    }
}
