import simd
import Foundation

/// 600 x 600 mm recessed LED panel for a 24 mm lay-in ceiling grid: white powder-coated steel frame with a
/// 20 mm visible flange, opal PMMA diffuser recessed 2 mm, shallow steel back tray and a driver box. Authored
/// in place: the diffuser face sits at y = 0 facing down, the body occupies y 0...0.06 (scenes hang it at
/// ceiling height). Option "diffuser" switches between the unlit opal face and the lit 4000 K panel.
public struct CeilingLight: RealArticulated {
    public static let id = "ceiling-light"
    public static let summary = "Recessed 600 x 600 mm LED ceiling panel: white steel frame flange, opal diffuser face that switches to a lit 4000 K panel."
    public static let tags = ["prop", "office", "light", "articulated"]
    public static let budget = 600
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: -32, distance: 1.25, ground: false, studio: true)

    /// Outer frame size (m); 0.595 fits a 600 mm grid module.
    public var size: Float = 0.595
    /// Visible flange width (m).
    public var flange: Float = 0.02
    public var frameColor: UInt32 = 0xEDEDEA
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [10])
        let paint: MaterialKey = "metal.powdercoat:" + String(format: "%06X", frameColor)
        let S = size, f = flange, frameH: Float = 0.011
        for l in 0..<2 {
            var m = Model(name: Self.id)
            // Flange rails: four beveled bars meeting at the corners, visible face at y = 0.
            let seg = l == 0 ? 1 : 0
            for k in 0..<4 {
                let along = k < 2
                let s = k % 2 == 0 ? Float(1) : -1
                let size3 = along ? V3(S, frameH, f) : V3(f, frameH, S - 2 * f + 0.002)
                let c = along ? V3(0, frameH / 2, s * (S - f) / 2) : V3(s * (S - f) / 2, frameH / 2, 0)
                m.add(seg > 0 ? Prim.roundedBox(size3, radius: 0.0015, bevelSegments: seg, material: paint) : cuboid(size3, material: paint),
                      Xform(translation: c))
            }
            // Back tray and driver box (hidden above the grid, kept simple).
            m.add(cuboid(V3(S - 0.03, 0.026, S - 0.03), material: paint), Xform(translation: V3(0, 0.024, 0)))
            m.add(cuboid(V3(0.2, 0.023, 0.06), material: "metal.galvanized"), Xform(translation: V3(0.08, 0.0485, -0.1)))
            m.add(cuboid(V3(0.04, 0.012, 0.02), material: "plastic.white"), Xform(translation: V3(-0.06, 0.0435, -0.1)))
            rig.base[l] = m
        }
        // Diffuser: opal sheet recessed 2 mm inside the flange; option 1 is the lit panel.
        rig.part("diffuser", pivot: V3(0, 0.002, 0), joint: .fixed, options: 2)
        let dw = S - 2 * f + 0.004
        rig.add(cuboid(V3(dw, 0.004, dw), material: "plastic.diffuser"), Xform(translation: V3(0, 0.004, 0)), to: "diffuser")
        rig.add(cuboid(V3(dw, 0.004, dw), material: "emissive.panel"), Xform(translation: V3(0, 0.004, 0)), to: "diffuser", option: 1)
        rig.states = [RigState("off"), RigState("on", options: ["diffuser": 1])]
        return rig
    }
}
