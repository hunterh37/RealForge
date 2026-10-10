import simd
import Foundation

/// Living-wall panel: powder-coated steel tray on a 1.2 m module with four planting troughs and
/// clusters of hosta, boxwood and trailing leaves. Foliage mixes three species so tiled panels vary.
public struct GreenWallPanel: RealAsset {
    public static let id = "green-wall-panel"
    public static let summary = "Modular living-wall panel, 1.2 m square: powder-coated steel tray with hosta, boxwood and ivy foliage."
    public static let tags = ["prop", "architecture", "facade", "landscaping", "garden", "metal"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 8, distance: 2.0)

    public var size: Float = 1.2
    public var troughs = 4
    public var tray: MaterialKey = "metal.powdercoat:3E4448"
    public var species: [MaterialKey] = ["leaf.hosta", "leaf.boxwood", "leaf.plain"]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let S = size, fd: Float = 0.14
        FA.box(&m, V3(S, S, 0.012), V3(0, S / 2, 0.006), tray, r: 0.002)
        for e: Float in [-1, 1] { FA.box(&m, V3(0.025, S, fd), V3(e * (S / 2 - 0.0125), S / 2, fd / 2), tray, r: 0.003) }
        for y in [0.0125, S - 0.0125] { FA.box(&m, V3(S, 0.025, fd), V3(0, y, fd / 2), tray, r: 0.003) }
        let pitch = (S - 0.1) / Float(troughs)
        for r in 0..<troughs {
            let y = 0.08 + Float(r) * pitch + 0.02
            FA.box(&m, V3(S - 0.05, 0.012, 0.11), V3(0, y, 0.067), tray, r: 0.002)
            FA.box(&m, V3(S - 0.05, 0.05, 0.01), V3(0, y + 0.03, 0.115), tray, r: 0.002)
            m.add(Prim.superellipsoid(V3(S - 0.07, 0.05, 0.09), exponent: 5, subdivisions: 6, material: "soil.potting"), Xform(translation: V3(0, y + 0.03, 0.065)))
            for c in 0..<6 {
                let x = -S / 2 + 0.1 + (Float(c) + rng.float(-0.15...0.15)) * (S - 0.2) / 5
                let mat = species[(r + c) % species.count]
                for k in 0..<2 {
                    let a = rng.float(0...360), lean = rng.float(10...55)
                    m.add(Prim.superellipsoid(V3(0.22, 0.04, 0.17), exponent: 2.4, subdivisions: 4, material: mat),
                          Xform(translation: V3(x + rng.float(-0.03...0.03), y + 0.09 + rng.float(0...0.06), 0.1 + rng.float(0...0.05)),
                                rotation: FA.q(a, FA.Z) * FA.q(lean, FA.X)))
                }
            }
        }
        groundAO(&m, height: 0.12, floor: 0.8)
        return LODModel(FA.centerZ(m))
    }
}
