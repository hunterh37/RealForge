import simd
import Foundation

/// Horizontal sunshade louver bank: eight aerofoil aluminum blades at 140 mm pitch, tilted 30 degrees,
/// carried by two vertical outrigger arms cantilevered 0.45 m from the wall on cast wall plates.
/// Wall plane at z = 0.
public struct SunshadeLouverBank: RealAsset {
    public static let id = "sunshade-louver-bank"
    public static let summary = "Sunshade louver bank, 2.0 x 1.2 m: eight tilted aerofoil aluminum blades on two cantilever outriggers."
    public static let tags = ["prop", "architecture", "facade", "metal"]
    public static let budget = 4000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 40, elevation: 14, distance: 3.2)

    public var width: Float = 2.0
    public var blades: Int = 8
    public var pitch: Float = 0.14
    public var chord: Float = 0.2
    public var tilt: Float = 30
    public var blade: MaterialKey = "metal.anodized"
    public var arm: MaterialKey = "metal.aluminum-brushed"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, n = blades, H = Float(n - 1) * pitch + 0.2, proj: Float = 0.45
        // Aerofoil section (x out from the wall, y up) extruded along X.
        let c = chord
        let foil: [V2] = [V2(-c / 2, 0), V2(-c * 0.3, 0.017), V2(0, 0.024), V2(c * 0.3, 0.016), V2(c / 2, 0.003), V2(c * 0.3, -0.008), V2(0, -0.012), V2(-c * 0.3, -0.008)]
        for i in 0..<n {
            let y = 0.1 + Float(i) * pitch
            m.add(Prim.extrude(foil, depth: W - 0.12, bevel: 0.0015, bevelSegments: 1, material: blade),
                  Xform(translation: V3(0, y, 0.12 + proj * 0.5 + 0.0), rotation: FA.q(-90, FA.Y) * FA.q(tilt, FA.Z)))
        }
        for s: Float in [-1, 1] {
            let x = s * (W / 2 - 0.03)
            FA.box(&m, V3(0.04, H + 0.08, 0.012), V3(x, H / 2, 0.006), arm, r: 0.003)
            FA.box(&m, V3(0.025, 0.05, 0.12), V3(x, 0.05, 0.07), arm, r: 0.003)
            FA.box(&m, V3(0.025, 0.05, 0.12), V3(x, H - 0.05, 0.07), arm, r: 0.003)
            // Outrigger plate with a bolted blade seat per blade.
            FA.box(&m, V3(0.012, H, proj + 0.12), V3(x, H / 2, (proj + 0.12) / 2), arm, r: 0.003)
            for i in 0..<n { FA.cylX(&m, r: 0.012, h: 0.02, at: V3(x - s * 0.006, 0.1 + Float(i) * pitch, 0.12 + proj * 0.5), "metal.steel", bevel: 0.002, segments: 10) }
            FA.rod(&m, V3(x, 0.02, 0.012), V3(x, 0.02, proj + 0.1), r: 0.008, arm, sides: 8)
        }
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
