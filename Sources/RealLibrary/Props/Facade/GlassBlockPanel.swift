import simd
import Foundation

/// Glass-block window panel: 6 x 6 blocks of 190 mm with 10 mm mortar joints, a white aluminum
/// perimeter channel, bubbled and wavy faces on alternate blocks. Wall plane at z = 0.
public struct GlassBlockPanel: RealAsset {
    public static let id = "glass-block-panel"
    public static let summary = "Glass block panel, 1.2 m square: 6 x 6 frosted blocks in mortar joints inside an aluminum channel."
    public static let tags = ["prop", "architecture", "facade", "window", "glass"]
    public static let budget = 7500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 8, distance: 2.2)

    public var cols: Int = 6
    public var rows: Int = 6
    public var block: Float = 0.19
    public var joint: Float = 0.01
    public var glass: MaterialKey = "glass.frosted"
    public var mortar: MaterialKey = "concrete.smooth"
    public var channel: MaterialKey = "metal.powder-white"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let pitch = block + joint, W = Float(cols) * pitch + joint, H = Float(rows) * pitch + joint, d: Float = 0.08
        FA.box(&m, V3(W, H, d - 0.02), V3(0, H / 2, (d - 0.02) / 2), mortar, r: 0.002)
        for r in 0..<rows {
            for c in 0..<cols {
                let x = -W / 2 + joint + Float(c) * pitch + block / 2, y = joint + Float(r) * pitch + block / 2
                let g = rng.chance(0.5) ? glass : "glass.clear"
                m.add(Prim.superellipsoid(V3(block, block, d * 0.5), exponent: 8, subdivisions: 3, material: g),
                      Xform(translation: V3(x, y, d - 0.015)))
                m.add(Prim.superellipsoid(V3(block * 0.55, block * 0.55, 0.004), exponent: 3, subdivisions: 2, material: "glass.clear"),
                      Xform(translation: V3(x + rng.float(-0.01...0.01), y, d - 0.015 + d * 0.25)))
            }
        }
        for y in [0.0, H] { FA.box(&m, V3(W + 0.04, 0.025, d), V3(0, y, d / 2), channel, r: 0.003) }
        for x in [-W / 2, W / 2] { FA.box(&m, V3(0.025, H + 0.025, d), V3(x, H / 2, d / 2), channel, r: 0.003) }
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
