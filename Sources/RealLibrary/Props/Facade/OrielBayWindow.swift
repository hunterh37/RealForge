import simd
import Foundation

/// Oriel bay window: a three-faceted projecting window 1.9 m wide and 1.4 m tall, carried on a stepped
/// corbel underside, with painted casements in each facet, a stone sill band and a standing-seam
/// copper hip roof. Wall plane at z = 0.
public struct OrielBayWindow: RealAsset {
    public static let id = "oriel-bay-window"
    public static let summary = "Oriel bay window, 1.9 m: three facets, corbelled underside, casements, copper hip roof."
    public static let tags = ["prop", "architecture", "facade", "window", "wood", "glass"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 12, distance: 4.4)

    public var frontWidth: Float = 1.1
    public var height: Float = 1.4
    public var projection: Float = 0.55
    public var paint: MaterialKey = "wood.barn-white"
    public var roof: MaterialKey = "metal.copper-patina"
    public var stone: MaterialKey = "stone.limestone"
    public var glass: MaterialKey = "glass.clear"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let F = frontWidth, H = height, P = projection, base: Float = 0.45
        let ang: Float = atan2(P, 0.4) * 180 / .pi            // angled facet turn
        let sideLen = sqrt(P * P + 0.4 * 0.4)
        func facet(center: V3, width: Float, yaw: Float) {
            let rot = FA.q(yaw, FA.Y)
            func at(_ x: Float, _ y: Float, _ z: Float) -> V3 { center + rot.act(V3(x, y, z)) }
            let fr = Float(0.07)
            // Frame (jambs, head, transom, sill) and glass.
            for e: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(fr, H, 0.07), radius: 0.003, bevelSegments: 1, material: paint), Xform(translation: at(e * (width / 2 - fr / 2), base + H / 2, 0), rotation: rot))
            }
            for y in [base + 0.03, base + H * 0.68, base + H - 0.03] {
                m.add(Prim.roundedBox(V3(width, 0.06, 0.07), radius: 0.003, bevelSegments: 1, material: paint), Xform(translation: at(0, y, 0), rotation: rot))
            }
            m.add(Prim.roundedBox(V3(width - 2 * fr, H - 0.1, 0.01), radius: 0.001, bevelSegments: 1, material: glass), Xform(translation: at(0, base + H / 2, 0), rotation: rot))
            m.add(Prim.roundedBox(V3(0.04, H - 0.1, 0.05), radius: 0.003, bevelSegments: 1, material: paint), Xform(translation: at(0, base + H / 2, 0.005), rotation: rot))
            // Stone sill band below the window and paneled apron.
            m.add(Prim.roundedBox(V3(width + 0.06, 0.06, 0.1), radius: 0.004, bevelSegments: 1, material: stone), Xform(translation: at(0, base - 0.03, 0.02), rotation: rot))
            m.add(Prim.roundedBox(V3(width - 0.1, base - 0.1, 0.02), radius: 0.004, bevelSegments: 1, material: paint), Xform(translation: at(0, base / 2 - 0.02, 0), rotation: rot))
        }
        let zf = P
        facet(center: V3(0, 0, zf), width: F, yaw: 0)
        let sx = F / 2 + 0.4 / 2, sz = P / 2
        facet(center: V3(sx, 0, sz), width: sideLen, yaw: ang)
        facet(center: V3(-sx, 0, sz), width: sideLen, yaw: -ang)
        // Stepped corbel soffit under the bay: three tiers.
        for t in 0..<3 {
            let w = F + 0.8 - Float(t) * 0.25
            let d = P - Float(t) * 0.12
            FA.box(&m, V3(w, 0.1, d), V3(0, 0.05 + Float(2 - t) * 0.1 - 0.12 + 0.12, d / 2 + 0.0), t == 2 ? stone : paint, r: 0.004)
        }
        // Hip roof: low pyramid fan from the front facets back to the wall, with standing seams.
        let top = base + H + 0.06
        let hip = Prim.roundedBox(V3(F + 0.8, 0.05, P + 0.12), radius: 0.003, bevelSegments: 1, material: roof)
        m.add(hip, Xform(translation: V3(0, top + 0.04, (P + 0.12) / 2 - 0.02), rotation: FA.q(-12, FA.X)))
        for k in -3...3 {
            m.add(Prim.roundedBox(V3(0.012, 0.016, P + 0.1), radius: 0.003, bevelSegments: 1, material: roof),
                  Xform(translation: V3(Float(k) * 0.27, top + 0.06, (P + 0.12) / 2 - 0.02), rotation: FA.q(-12, FA.X)))
        }
        groundAO(&m, height: 0.12, floor: 0.8)
        return LODModel(FA.centerZ(FC.place(m)).transformed(Xform(translation: .zero)))
    }
}
