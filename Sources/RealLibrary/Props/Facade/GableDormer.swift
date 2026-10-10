import simd
import Foundation

/// Gable dormer: a 1.2 m wide pitched-roof dormer with painted cheeks, a double-hung window, a
/// bargeboard fascia with finial and a standing-seam roof. Sits on y = 0 against the roof slope.
public struct GableDormer: RealAsset {
    public static let id = "gable-dormer"
    public static let summary = "Gable dormer, 1.2 m: painted cheeks, double-hung window, bargeboards, finial, seam roof."
    public static let tags = ["prop", "architecture", "facade", "roof", "wood", "window"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 14, distance: 4.0)

    public var width: Float = 1.2
    public var wallHeight: Float = 1.2
    public var pitch: Float = 42
    public var paint: MaterialKey = "wood.barn-white"
    public var roof: MaterialKey = "metal.galvanized-aged"
    public var glass: MaterialKey = "glass.clear"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = wallHeight, D: Float = 1.0
        let rise = (W / 2) * tan(pitch * .pi / 180)
        // Front gable wall (rectangle plus triangle) as one extruded outline with a window hole built from frame pieces.
        let outline = [V2(-W / 2, 0), V2(W / 2, 0), V2(W / 2, H), V2(0, H + rise), V2(-W / 2, H)]
        m.add(Prim.extrude(outline, depth: 0.05, bevel: 0.003, bevelSegments: 1, material: paint), Xform(translation: V3(0, 0, D)))
        // Window: recessed frame, two sashes, muntins.
        let ww: Float = 0.62, wh: Float = 0.82, wy: Float = 0.2
        m.add(Prim.roundedBox(V3(ww + 0.14, wh + 0.14, 0.03), radius: 0.004, bevelSegments: 1, material: paint), Xform(translation: V3(0, wy + wh / 2, D + 0.04)))
        m.add(Prim.roundedBox(V3(ww, wh, 0.012), radius: 0.001, bevelSegments: 1, material: glass), Xform(translation: V3(0, wy + wh / 2, D + 0.058)))
        for (i, y) in [wy + 0.02, wy + wh / 2, wy + wh - 0.02].enumerated() {
            FA.box(&m, V3(ww + 0.04, i == 1 ? 0.05 : 0.04, 0.03), V3(0, y, D + 0.06), paint, r: 0.003)
        }
        for e: Float in [-1, 1] { FA.box(&m, V3(0.04, wh, 0.03), V3(e * ww / 2, wy + wh / 2, D + 0.06), paint, r: 0.003) }
        FA.box(&m, V3(0.025, wh, 0.025), V3(0, wy + wh / 2, D + 0.062), paint, r: 0.002)
        FA.box(&m, V3(ww + 0.2, 0.05, 0.12), V3(0, wy - 0.04, D + 0.07), paint, r: 0.004)
        // Cheeks run back to the main roof; triangular profile fills the sides.
        for e: Float in [-1, 1] {
            let cheek = [V2(0, 0), V2(D, 0), V2(D, H), V2(0, 0.1)]
            m.add(Prim.extrude(cheek, depth: 0.04, bevel: 0.002, bevelSegments: 1, material: paint),
                  Xform(translation: V3(e * (W / 2 - 0.02), 0, 0), rotation: FA.q(-90, FA.Y)))
        }
        // Roof planes with overhang and seams.
        let slope = sqrt((W / 2) * (W / 2) + rise * rise) + 0.12
        for e: Float in [-1, 1] {
            let r = FA.q(e * -pitch, FA.Z)
            let c = V3(e * (W / 4 + 0.02), H + rise / 2 + 0.03, D / 2 + 0.07)
            m.add(Prim.roundedBox(V3(slope, 0.03, D + 0.22), radius: 0.003, bevelSegments: 1, material: roof), Xform(translation: c, rotation: r))
            for k in 0..<5 {
                let z = -D / 2 + 0.08 + Float(k) * (D / 4)
                let off = r.act(V3(0, 0.02, 0))
                m.add(Prim.roundedBox(V3(slope, 0.014, 0.014), radius: 0.003, bevelSegments: 1, material: roof), Xform(translation: c + off + V3(0, 0, z), rotation: r))
            }
            // Bargeboard along the gable edge.
            let bc = V3(e * (W / 4 + 0.02), H + rise / 2 + 0.0, D + 0.07)
            m.add(Prim.roundedBox(V3(slope, 0.12, 0.025), radius: 0.003, bevelSegments: 1, material: paint), Xform(translation: bc, rotation: r))
        }
        FA.ball(&m, r: 0.04, at: V3(0, H + rise + 0.14, D + 0.07), paint)
        FA.rod(&m, V3(0, H + rise + 0.02, D + 0.07), V3(0, H + rise + 0.12, D + 0.07), r: 0.012, paint)
        groundAO(&m, height: 0.15, floor: 0.8)
        return LODModel(FA.centerZ(m))
    }
}
