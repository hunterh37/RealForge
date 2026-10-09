import simd
import Foundation

/// 3.3 m long, 0.6 m wide, hooks at 1.12 m, sling sag 0.5 m.
public struct HammockStand: RealAsset {
    public static let id = "hammock-stand"
    public static let summary = "Arc hammock stand with hammock, 1.1 m: powder-coated steel bow beams curving up to hooks, canvas sling and pillow."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "furniture", "metal", "fabric"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let steel = "metal.painted:2F3B33"
        for z: Float in [-0.3, 0.3] {
            var pts: [V3] = []
            for i in 0...40 {
                let x = -1.65 + 3.3 * Float(i) / 40, e = max(0, (abs(x) - 1.1) / 0.55)
                pts.append(V3(x, 0.06 + 1.06 * e * e, z))
            }
            K.rod(&m, pts, r: 0.025, steel, sides: 10)
        }
        for x: Float in [-1.1, 1.1] { K.rod(&m, [V3(x, 0.06, -0.3), V3(x, 0.06, 0.3)], r: 0.02, steel) }
        for x: Float in [-1.65, 1.65] { K.rod(&m, [V3(x, 1.12, -0.3), V3(x, 1.12, 0.3)], r: 0.015, steel) }
        var sling: [V3] = []
        for i in 0...24 {
            let t = Float(i) / 24
            sling.append(V3(-1.62 + 3.24 * t, 1.1 - 0.5 * 4 * t * (1 - t), 0))
        }
        m.add(Prim.sweep(Shape2D.roundedRect(0.9, 0.012, radius: 0.004), along: sling, up: V3(0, 0, 1), material: "fabric.canvas"))
        m.add(Prim.superellipsoid(V3(0.4, 0.1, 0.5), exponent: 3, subdivisions: 6, material: "fabric.canvas"), Xform(translation: V3(-0.9, 0.72, 0)))
        return K.finish(&m)
    }
}
