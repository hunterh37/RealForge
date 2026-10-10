import simd
import Foundation

/// Pyramid skylight 1.5 m square, 1.0 m high: insulated curb, four glass faces and aluminum hip ribs.
public struct PyramidSkylight: RealAsset {
    public static let id = "pyramid-skylight"
    public static let summary = "Pyramid skylight 1.5 m square, 1.0 m high: insulated curb, four glass faces and aluminum hip ribs."
    public static let tags = ["prop", "facade", "roof", "glass", "metal"]
    public static let budget = 2200
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "glass.pane"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let s: Float = 1.5, ch: Float = 0.2, ph: Float = 0.8
        K.box(&m, V3(0, ch / 2, 0), V3(s, ch, s), "metal.painted:C9CCCE", bevel: 0.008)
        K.box(&m, V3(0, ch + 0.01, 0), V3(s - 0.08, 0.02, s - 0.08), "metal.aluminum-brushed", bevel: 0.003)
        m.add(Prim.loft([Prim.ring(Shape2D.rect(s - 0.1, s - 0.1), y: ch + 0.02), Prim.ring(Shape2D.rect(0.04, 0.04), y: ch + 0.02 + ph)], capStart: false, capEnd: true, material: material))
        for (sx, sz) in [(-1, -1), (1, -1), (1, 1), (-1, 1)] as [(Float, Float)] {
            let a = V3(sx * (s / 2 - 0.05), ch + 0.02, sz * (s / 2 - 0.05)), b = V3(sx * 0.02, ch + 0.02 + ph, sz * 0.02)
            rod(&m, a, b, 0.012, "metal.aluminum-brushed", sides: 8)
        }
        cy(&m, 0.025, 0.04, V3(0, ch + 0.02 + ph, 0), "metal.aluminum-brushed", bevel: 0.004, seg: 12)
        return K.finish(&m, ao: 0.05)
    }
}
