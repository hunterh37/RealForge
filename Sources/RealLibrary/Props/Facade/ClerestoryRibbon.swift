import simd
import Foundation

/// Clerestory ribbon window: 3.6 x 0.6 m anodized frame with six fixed panes, two outward-tilted hopper
/// vents, mullions with pressure plates, a sloped sill flashing and a thin concrete lintel above.
/// Wall plane at z = 0.
public struct ClerestoryRibbon: RealAsset {
    public static let id = "clerestory-ribbon"
    public static let summary = "Clerestory ribbon window, 3.6 x 0.6 m: anodized frame, six panes, two tilted hopper vents, flashing, lintel."
    public static let tags = ["prop", "architecture", "facade", "window", "metal", "glass"]
    public static let budget = 3000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 8, distance: 5.5)

    public var width: Float = 3.6
    public var height: Float = 0.6
    public var panes: Int = 6
    public var frame: MaterialKey = "metal.anodized"
    public var glass: MaterialKey = "glass.pane"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = height, n = panes, pw = W / Float(n), d: Float = 0.1, f: Float = 0.04
        FA.box(&m, V3(W + 0.1, 0.09, d + 0.05), V3(0, H + 0.045, (d + 0.05) / 2), "concrete.smooth", r: 0.004)
        m.add(Prim.extrude([V2(0, 0), V2(0.14, -0.035), V2(0.14, -0.05), V2(0, -0.0)], depth: W + 0.06, bevel: 0.002, bevelSegments: 1, material: "metal.galvanized"),
              Xform(translation: V3(0, 0, 0), rotation: FA.q(-90, FA.Y)))
        for y in [f / 2, H - f / 2] { FA.box(&m, V3(W, f, d), V3(0, y, d / 2), frame, r: 0.003) }
        for i in 0...n {
            let x = -W / 2 + Float(i) * pw
            FA.box(&m, V3(f, H, d), V3(x, H / 2, d / 2), frame, r: 0.003)
            if i > 0 && i < n { FA.box(&m, V3(0.06, H - 0.04, 0.008), V3(x, H / 2, d + 0.004), "metal.aluminum-brushed", r: 0.002) }
        }
        for i in 0..<n {
            let cx = -W / 2 + (Float(i) + 0.5) * pw
            let vent = i == 1 || i == 4
            if vent {
                // Hopper sash hinged at the bottom, tipped outward.
                m.add(Prim.roundedBox(V3(pw - 0.09, H - 0.1, 0.014), radius: 0.003, bevelSegments: 1, material: glass),
                      Xform(translation: V3(cx, H / 2 - 0.02, d + 0.03), rotation: FA.q(-20, FA.X)))
                FA.rod(&m, V3(cx - 0.1, 0.06, d - 0.01), V3(cx - 0.1, 0.16, d + 0.05), r: 0.005, "metal.steel", sides: 6)
            } else {
                FA.box(&m, V3(pw - f - 0.01, H - 2 * f - 0.01, 0.012), V3(cx, H / 2, d / 2), glass, r: 0.001)
            }
        }
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
