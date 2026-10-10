import simd
import Foundation

/// Terracotta frieze band: four glazed tiles, each with a raised border, a central rosette of eight
/// petals on a dome and four corner leaves. Tiles alternate two firings so the band reads hand-laid.
public struct TerracottaFriezePanel: RealAsset {
    public static let id = "terracotta-frieze-panel"
    public static let summary = "Terracotta frieze band, 2.4 m: four glazed tiles each with a raised rosette and leaf corners."
    public static let tags = ["prop", "architecture", "facade", "trim", "ornament", "ceramic"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 8, distance: 2.0)

    public var tiles = 4
    public var tileSize: Float = 0.6
    public var firingA: MaterialKey = "ceramic.terracotta"
    public var firingB: MaterialKey = "ceramic.terracotta:B8603F"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let S = tileSize, t: Float = 0.04
        let W = Float(tiles) * S
        for i in 0..<tiles {
            let cx = -W / 2 + (Float(i) + 0.5) * S
            let mat = i % 2 == 0 ? firingA : firingB
            FA.box(&m, V3(S - 0.006, S - 0.006, t), V3(cx, S / 2, t / 2), mat, r: 0.004)
            let b: Float = 0.032, z = t + 0.005
            FA.box(&m, V3(S - 0.06, b, 0.012), V3(cx, S - 0.04, z), mat, r: 0.003)
            FA.box(&m, V3(S - 0.06, b, 0.012), V3(cx, 0.04, z), mat, r: 0.003)
            FA.box(&m, V3(b, S - 0.12, 0.012), V3(cx - (S / 2 - 0.04), S / 2, z), mat, r: 0.003)
            FA.box(&m, V3(b, S - 0.12, 0.012), V3(cx + (S / 2 - 0.04), S / 2, z), mat, r: 0.003)
            m.add(Prim.superellipsoid(V3(0.1, 0.1, 0.05), exponent: 2, subdivisions: 4, material: mat), Xform(translation: V3(cx, S / 2, t + 0.004)))
            m.add(Prim.torus(major: 0.072, minor: 0.008, segments: 20, sides: 5, material: mat), Xform(translation: V3(cx, S / 2, t + 0.012), rotation: FA.q(90, FA.X)))
            for k in 0..<8 {
                let a = Float(k) * .pi / 4
                m.add(Prim.superellipsoid(V3(0.1, 0.035, 0.025), exponent: 2, subdivisions: 4, material: mat),
                      Xform(translation: V3(cx + 0.085 * cos(a), S / 2 + 0.085 * sin(a), t + 0.012), rotation: FA.q(a * 180 / .pi, FA.Z)))
            }
            for (sx, sy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)] as [(Float, Float)] {
                m.add(Prim.superellipsoid(V3(0.1, 0.04, 0.02), exponent: 2, subdivisions: 4, material: mat),
                      Xform(translation: V3(cx + sx * 0.19, S / 2 + sy * 0.19, t + 0.012), rotation: FA.q(sx * sy * 45 + rng.float(-3...3), FA.Z)))
            }
        }
        groundAO(&m, height: 0.08, floor: 0.85)
        return LODModel(FA.centerZ(m))
    }
}
