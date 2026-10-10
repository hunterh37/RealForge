import simd
import Foundation

/// Roof cupola: a 0.9 m square louvered belvedere on a painted base, four louvered openings, cornice,
/// a concave copper pyramid roof, a ball finial and a gold-leaf ball over the weather rod.
public struct RoofCupola: RealAsset {
    public static let id = "roof-cupola"
    public static let summary = "Roof cupola, 0.9 m: louvered square belvedere, cornice, copper pyramid roof, ball finial."
    public static let tags = ["prop", "architecture", "facade", "roof", "wood", "metal"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18, distance: 3.2)

    public var side: Float = 0.9
    public var shaftHeight: Float = 0.8
    public var paint: MaterialKey = "wood.barn-white"
    public var copper: MaterialKey = "metal.copper-patina"
    public var gild: MaterialKey = "metal.brass"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let S = side, H = shaftHeight, hs = S / 2
        // Base plinth and shaft frame.
        FA.box(&m, V3(S + 0.16, 0.18, S + 0.16), V3(0, 0.09, 0), paint, r: 0.006)
        FA.box(&m, V3(S + 0.08, 0.06, S + 0.08), V3(0, 0.21, 0), paint, r: 0.004)
        let y0: Float = 0.24
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            FA.box(&m, V3(0.08, H, 0.08), V3(sx * (hs - 0.04), y0 + H / 2, sz * (hs - 0.04)), paint, r: 0.004)
        } }
        // Louvered panels on all four faces.
        for face in 0..<4 {
            let r = FA.q(Float(face) * 90, FA.Y)
            for i in 0..<9 {
                let y = y0 + 0.1 + Float(i) * (H - 0.2) / 8
                m.add(Prim.roundedBox(V3(S - 0.16, 0.012, 0.07), radius: 0.002, bevelSegments: 1, material: paint),
                      Xform(translation: r.act(V3(0, y, hs - 0.04)), rotation: r * FA.q(-30, FA.X)))
            }
            m.add(Prim.roundedBox(V3(S - 0.16, 0.02, 0.012), radius: 0.001, bevelSegments: 1, material: "metal.wrought-iron"), Xform(translation: r.act(V3(0, y0 + H / 2, hs - 0.07)), rotation: r))
        }
        // Cornice and roof.
        let top = y0 + H
        FA.box(&m, V3(S + 0.2, 0.08, S + 0.2), V3(0, top + 0.04, 0), paint, r: 0.005)
        FA.box(&m, V3(S + 0.3, 0.04, S + 0.3), V3(0, top + 0.1, 0), paint, r: 0.004)
        let pyr = Prim.lathe([V2(0.0, 0.0), V2((S + 0.3) * 0.72, 0.0), V2((S + 0.3) * 0.58, 0.1), V2((S + 0.3) * 0.34, 0.26), V2((S + 0.3) * 0.14, 0.44), V2(0.02, 0.56), V2(0, 0.56)],
                             segments: 4, material: copper)
        m.add(pyr, Xform(translation: V3(0, top + 0.12, 0), rotation: FA.q(45, FA.Y)))
        FA.rod(&m, V3(0, top + 0.66, 0), V3(0, top + 0.9, 0), r: 0.012, gild)
        FA.ball(&m, r: 0.05, at: V3(0, top + 0.72, 0), gild)
        FA.ball(&m, r: 0.03, at: V3(0, top + 0.93, 0), gild)
        groundAO(&m, height: 0.15, floor: 0.8)
        return LODModel(FC.place(m))
    }
}
