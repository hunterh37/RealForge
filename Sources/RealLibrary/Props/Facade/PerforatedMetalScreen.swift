import simd
import Foundation

/// Perforated metal facade screen: 0.9 x 1.8 m powder-coated panel built as a lattice of ring cells whose
/// hole size grows from bottom to top, folded return edges and four standoff brackets. Wall plane at z = 0.
public struct PerforatedMetalScreen: RealAsset {
    public static let id = "perforated-metal-screen"
    public static let summary = "Perforated metal screen, 0.9 x 1.8 m: gradient-hole panel, folded edges, four standoff brackets."
    public static let tags = ["prop", "architecture", "facade", "metal"]
    public static let budget = 14500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 10, distance: 3.0)

    public var width: Float = 0.9
    public var height: Float = 1.8
    public var pitch: Float = 0.12
    public var sheet: MaterialKey = "metal.powder-white"
    public var bracket: MaterialKey = "metal.anodized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = height, z: Float = 0.09
        let cols = Int(W / pitch), rows = Int(H / pitch)
        let x0 = -Float(cols - 1) * pitch / 2, y0 = (H - Float(rows - 1) * pitch) / 2
        for r in 0..<rows {
            let t = Float(r) / Float(rows - 1)
            // Land width shrinks as the hole opens up the panel.
            let land: Float = 0.016 - 0.008 * t
            FA.box(&m, V3(W - 0.04, land, 0.003), V3(0, y0 + Float(r) * pitch, z), sheet, r: 0.001)
            for c in 0..<cols {
                let hole = pitch * (0.22 + 0.2 * t)
                m.add(Prim.torus(major: hole, minor: 0.0055 + 0.002 * (1 - t), segments: 10, sides: 4, material: sheet),
                      Xform(translation: V3(x0 + Float(c) * pitch, y0 + Float(r) * pitch, z), rotation: FA.q(90, FA.X)))
            }
        }
        for c in 0..<cols { FA.box(&m, V3(0.012, H - 0.04, 0.003), V3(x0 + Float(c) * pitch, H / 2, z), sheet, r: 0.001) }
        // Folded perimeter return.
        FA.box(&m, V3(W, 0.03, 0.04), V3(0, 0.015, z - 0.018), sheet, r: 0.003)
        FA.box(&m, V3(W, 0.03, 0.04), V3(0, H - 0.015, z - 0.018), sheet, r: 0.003)
        for s: Float in [-1, 1] { FA.box(&m, V3(0.03, H, 0.04), V3(s * (W / 2 - 0.015), H / 2, z - 0.018), sheet, r: 0.003) }
        for x in [-W / 2 + 0.08, W / 2 - 0.08] {
            for y in [0.12, H - 0.12] {
                FA.rod(&m, V3(x, y, 0), V3(x, y, z - 0.03), r: 0.011, bracket, sides: 8)
                FA.cylZ(&m, r: 0.03, h: 0.008, at: V3(x, y, 0), bracket, bevel: 0.002, segments: 14)
            }
        }
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
