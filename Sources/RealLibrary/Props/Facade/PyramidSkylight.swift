import simd
import Foundation

/// Pyramid rooftop skylight: galvanized flashing flange, a four-sided aluminum curb, glass faces lofted
/// to a small apex, four hip ribs and a base ring. Sits on y = 0, centered.
public struct PyramidSkylight: RealAsset {
    public static let id = "pyramid-skylight"
    public static let summary = "Pyramid rooftop skylight, 1.2 m: aluminum curb, four glass faces, hip ribs and flashing."
    public static let tags = ["prop", "architecture", "facade", "roof", "glass", "metal"]
    public static let budget = 7_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 25, distance: 2.4)

    public var size: Float = 1.2
    public var curbHeight: Float = 0.2
    public var apexHeight: Float = 0.6
    public var glass: MaterialKey = "glass.clear"
    public var frame: MaterialKey = "metal.anodized"
    public var flashing: MaterialKey = "metal.galvanized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let S = size, C = curbHeight, A = apexHeight, w: Float = 0.07
        FA.box(&m, V3(S + 0.24, 0.012, S + 0.24), V3(0, 0.006, 0), flashing, r: 0.002)
        for e: Float in [-1, 1] {
            FA.box(&m, V3(S, C, w), V3(0, 0.012 + C / 2, e * (S / 2 - w / 2)), frame, r: 0.004)
            FA.box(&m, V3(w, C, S - 2 * w + 0.004), V3(e * (S / 2 - w / 2), 0.012 + C / 2, 0), frame, r: 0.004)
        }
        let y1 = 0.012 + C, ins = S - 2 * w + 0.01
        let rings = [Prim.ring(Shape2D.rect(ins, ins), y: y1), Prim.ring(Shape2D.rect(0.06, 0.06), y: y1 + A)]
        m.add(Prim.loft(rings, capStart: false, capEnd: true, material: glass))
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            FA.rod(&m, V3(sx * ins / 2, y1, sz * ins / 2), V3(sx * 0.03, y1 + A, sz * 0.03), r: 0.012, frame, sides: 8)
        }}
        FA.ball(&m, r: 0.026, at: V3(0, y1 + A + 0.006, 0), frame)
        groundAO(&m, height: 0.1, floor: 0.8)
        return LODModel(FA.centerZ(m))
    }
}
