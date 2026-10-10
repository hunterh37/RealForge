import simd
import Foundation

/// Glass entry canopy: a 12 mm laminated glass sheet pitched 5 degrees to shed water, fixed at four
/// stainless spider fittings, held by two tie rods up to wall plates and a flashing channel at the wall.
/// Wall plane at z = 0, y = 0 is the lower front edge of the glass.
public struct GlassEntryCanopy: RealAsset {
    public static let id = "glass-entry-canopy"
    public static let summary = "Glass entry canopy, 2.0 m x 1.1 m: laminated glass sheet on spider fittings and two stainless tie rods."
    public static let tags = ["prop", "architecture", "facade", "door", "glass", "metal"]
    public static let budget = 6_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 40, elevation: 14, distance: 3.0)

    public var width: Float = 2.0
    public var projection: Float = 1.1
    public var pitch: Float = 5
    public var rodHeight: Float = 0.9
    public var glass: MaterialKey = "glass.clear"
    public var steel: MaterialKey = "metal.stainless"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, P = projection, rise = tan(pitch * .pi / 180) * P
        let gt: Float = 0.012, y0: Float = 0.02
        let len = (P * P + rise * rise).squareRoot()
        m.add(Prim.roundedBox(V3(W, gt, len), radius: 0.003, bevelSegments: 1, material: glass),
              Xform(translation: V3(0, y0 + rise / 2, P / 2 + 0.02), rotation: FA.q(-pitch, FA.X)))
        FA.box(&m, V3(W, 0.05, 0.05), V3(0, y0 + rise + 0.03, 0.025), steel, r: 0.004)
        for sx: Float in [-1, 1] {
            let x = sx * (W / 2 - 0.1)
            for (z, y) in [(P - 0.08, y0 + rise * 0.07), (0.16, y0 + rise * 0.86)] {
                FA.cylZ(&m, r: 0.026, h: 0.02, at: V3(x, y - 0.01, z), steel, bevel: 0.003, segments: 16)
                FA.cylZ(&m, r: 0.008, h: 0.03, at: V3(x, y - 0.02, z), steel, bevel: 0.001, segments: 10)
            }
            FA.rod(&m, V3(x, y0 - 0.0, P - 0.08), V3(x, rodHeight, 0.03), r: 0.007, steel, sides: 10)
            FA.box(&m, V3(0.06, 0.1, 0.01), V3(x, rodHeight, 0.005), steel, r: 0.002)
            hexBolt(&m, at: V3(x, rodHeight, 0.011), normal: FA.Z, size: 0.012, material: "metal.steel")
        }
        groundAO(&m, height: 0.06, floor: 0.9)
        return LODModel(FA.centerZ(m))
    }
}
