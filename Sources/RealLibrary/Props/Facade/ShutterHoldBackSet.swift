import simd
import Foundation

/// Shutter hardware set: an open louvered shutter leaf (0.4 x 1.2 m) with two strap hinges on pintles,
/// a cast S-shaped shutter dog on the wall and a thumb latch, in painted wood and black iron.
public struct ShutterHoldBackSet: RealAsset {
    public static let id = "shutter-hold-back-set"
    public static let summary = "Open louvered shutter 0.4 x 1.2 m with strap hinges, pintles, S-shaped shutter dog and latch."
    public static let tags = ["prop", "architecture", "facade", "trim", "wood", "metal"]
    public static let budget = 11_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 8, distance: 2.8)

    public var width: Float = 0.4
    public var height: Float = 1.2
    public var paint: MaterialKey = "wood.painted-exterior"
    public var iron: MaterialKey = "metal.cast-iron"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = height, th: Float = 0.032
        // Shutter leaf standing off the wall by 0.12 m (open, hung from its hinge side).
        let z0: Float = 0.12
        FA.box(&m, V3(0.05, H, th), V3(-W / 2 + 0.025, H / 2, z0), paint, r: 0.003)
        FA.box(&m, V3(0.05, H, th), V3(W / 2 - 0.025, H / 2, z0), paint, r: 0.003)
        for y in [0.04 as Float, H / 2, H - 0.04] { FA.box(&m, V3(W, y == H / 2 ? 0.05 : 0.08, th), V3(0, y, z0), paint, r: 0.003) }
        let slats = 18
        for i in 0..<slats {
            let y = 0.1 + Float(i) * (H - 0.2) / Float(slats - 1)
            m.add(Prim.roundedBox(V3(W - 0.1, 0.05, 0.007), radius: 0.001, bevelSegments: 1, material: paint),
                  Xform(translation: V3(0, y, z0), rotation: FA.q(-38, FA.X)))
        }
        FA.rod(&m, V3(0, 0.07, z0), V3(0, H - 0.07, z0), r: 0.004, paint, sides: 5)
        // Strap hinges on the hinge side, pintles into the wall.
        let hx = -W / 2
        for y in [0.2 as Float, H - 0.2] {
            FA.box(&m, V3(0.3, 0.032, 0.008), V3(hx + 0.12, y, z0 + th / 2 + 0.004), iron, r: 0.002)
            let tip = [V2(0, 0.016), V2(0.06, 0.0), V2(0, -0.016)]
            m.add(Prim.extrude(tip, depth: 0.008, bevel: 0.001, bevelSegments: 1, material: iron), Xform(translation: V3(hx + 0.27, y, z0 + th / 2 + 0.004)))
            FA.rod(&m, V3(hx - 0.02, y, 0.0), V3(hx - 0.02, y, z0 + 0.01), r: 0.01, iron, sides: 8)
            FA.rod(&m, V3(hx - 0.02, y, z0 - 0.02), V3(hx + 0.01, y, z0 + 0.004), r: 0.009, iron, sides: 8)
            FA.box(&m, V3(0.04, 0.04, 0.01), V3(hx - 0.02, y, 0.005), iron, r: 0.002)
            for k in 0..<3 { hexBolt(&m, at: V3(hx + 0.06 + Float(k) * 0.08, y, z0 + th / 2 + 0.01), normal: FA.Z, size: 0.012, material: "metal.rust") }
        }
        // S-dog on the wall catching the free edge.
        let ex = W / 2 + 0.14, dy = H * 0.55
        FA.path(&m, catmull([V3(ex, dy + 0.1, 0.0), V3(ex + 0.02, dy + 0.05, 0.04), V3(ex - 0.02, dy, 0.07), V3(ex + 0.02, dy - 0.05, 0.1), V3(ex, dy - 0.1, z0 - 0.02)], per: 6), r: 0.009, iron, sides: 8)
        FA.box(&m, V3(0.04, 0.05, 0.012), V3(ex, dy + 0.1, 0.006), iron, r: 0.002)
        m.add(Prim.torus(major: 0.024, minor: 0.005, segments: 14, sides: 5, material: iron), Xform(translation: V3(ex, dy - 0.1, z0 - 0.02), rotation: FA.q(90, FA.X)))
        // Thumb latch on the free stile.
        FA.box(&m, V3(0.06, 0.028, 0.008), V3(W / 2 - 0.045, H * 0.5, z0 + th / 2 + 0.004), iron, r: 0.002)
        FA.rod(&m, V3(W / 2 - 0.08, H * 0.5, z0 + th / 2 + 0.008), V3(W / 2 - 0.01, H * 0.5 + 0.03, z0 + th / 2 + 0.01), r: 0.006, iron, sides: 6)
        groundAO(&m, height: 0.1, floor: 0.88)
        return LODModel(FA.centerZ(m))
    }
}
