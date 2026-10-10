import simd
import Foundation

/// Wall-mounted mini-split condenser: enamel casing on two steel rails, a round fan guard (rings and
/// spokes) over a hub, a side service panel with screws, and an insulated line set looping to the wall.
public struct MiniSplitCondenser: RealAsset {
    public static let id = "mini-split-condenser"
    public static let summary = "Wall-mounted mini-split condenser, 0.8 m: enamel casing, fan grille, service panel, bracket and line set."
    public static let tags = ["prop", "architecture", "facade", "metal", "urban"]
    public static let budget = 11_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 12, distance: 1.7)

    public var width: Float = 0.8
    public var height: Float = 0.55
    public var depth: Float = 0.28
    public var casing: MaterialKey = "metal.enamel:E4E4E0"
    public var steel: MaterialKey = "metal.galvanized"
    public var foam: MaterialKey = "plastic.black"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, H = height, D = depth, y0: Float = 0.12, z0: Float = 0.06
        FA.box(&m, V3(W, H, D), V3(0, y0 + H / 2, z0 + D / 2), casing, r: 0.014)
        for y in [y0 + 0.08, y0 + H - 0.08] { FA.box(&m, V3(W + 0.1, 0.04, 0.04), V3(0, y, 0.02), steel, r: 0.003) }
        for x in [-W * 0.35, W * 0.35] { FA.rod(&m, V3(x, y0 - 0.02, 0.02), V3(x, y0 + 0.02, z0 + 0.03), r: 0.01, steel, sides: 8) }
        // Fan guard on the front.
        let fx: Float = -0.06, fy = y0 + H / 2, fz = z0 + D
        for r: Float in [0.05, 0.1, 0.15, 0.2] {
            m.add(Prim.torus(major: r, minor: 0.0028, segments: 36, sides: 6, material: "metal.steel"), Xform(translation: V3(fx, fy, fz + 0.004), rotation: FA.q(90, FA.X)))
        }
        for k in 0..<12 {
            let a = Float(k) * .pi / 6
            FA.rod(&m, V3(fx, fy, fz + 0.004), V3(fx + 0.205 * cos(a), fy + 0.205 * sin(a), fz + 0.004), r: 0.0025, "metal.steel", sides: 5)
        }
        m.add(Prim.torus(major: 0.215, minor: 0.008, segments: 40, sides: 8, material: casing), Xform(translation: V3(fx, fy, fz + 0.002), rotation: FA.q(90, FA.X)))
        FA.cylZ(&m, r: 0.03, h: 0.02, at: V3(fx, fy, fz + 0.002), "plastic.black", bevel: 0.004, segments: 20)
        // Service panel on the right.
        FA.box(&m, V3(0.14, 0.34, 0.004), V3(W / 2 - 0.1, y0 + H / 2, fz + 0.002), "metal.enamel:D8D8D4", r: 0.001)
        for dy: Float in [-0.15, 0.15] { hexBolt(&m, at: V3(W / 2 - 0.1, y0 + H / 2 + dy, fz + 0.004), normal: FA.Z, size: 0.008, material: "metal.steel") }
        // Line set: foam-wrapped suction line and bare liquid line to the wall.
        let lx = W / 2 - 0.04
        for (i, r) in ([0.013, 0.007] as [Float]).enumerated() {
            let x = lx + Float(i) * 0.03
            FA.path(&m, [V3(x, y0 + 0.02, z0 + 0.06), V3(x, 0.05 + rng.float(0...0.01), z0 + 0.08), V3(x, 0.02, 0.05), V3(x, 0.02, 0.01)], r: r, i == 0 ? foam : "metal.copper", sides: 10)
        }
        groundAO(&m, height: 0.1, floor: 0.8)
        return LODModel(FA.centerZ(m))
    }
}
