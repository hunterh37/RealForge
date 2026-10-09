import simd
import Foundation

/// 0.9 m by 0.6 m footprint, 0.4 m back wall, 0.25 m front wall.
public struct ColdFrame: RealAsset {
    public static let id = "cold-frame"
    public static let summary = "Cold frame, 0.4 m: cedar box sloping from back to front under a glass-lidded frame on two hinges."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "container", "wood", "glass"]
    public static let budget = 4500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let wood = "wood.cedar-weathered"
        for s: Float in [-1, 1] {
            let side = Prim.extrude([V2(-0.3, 0), V2(0.3, 0), V2(0.3, 0.4), V2(-0.3, 0.25)], depth: 0.02, bevel: 0.002, material: wood)
            m.add(side, Xform(translation: V3(s * 0.44, 0, 0), rotation: K.yaw(90)))
        }
        K.box(&m, V3(0, 0.125, 0.29), V3(0.9, 0.25, 0.02), wood)
        K.box(&m, V3(0, 0.2, -0.29), V3(0.9, 0.4, 0.02), wood)
        m.add(Prim.superellipsoid(V3(0.84, 0.1, 0.56), exponent: 8, subdivisions: 6, material: "soil.potting"), Xform(translation: V3(0, 0.13, 0)))
        let q = simd_quatf(degrees: 14, axis: V3(1, 0, 0)), c = V3(0, 0.343, 0)
        func lid(_ l: V3, _ s: V3, _ mat: String) { K.box(&m, c + q.act(l), s, mat, bevel: 0.002, rot: q) }
        for s: Float in [-1, 1] { lid(V3(s * 0.43, 0, 0), V3(0.04, 0.025, 0.617), wood) }
        for s: Float in [-1, 1] { lid(V3(0, 0, s * 0.289), V3(0.9, 0.025, 0.04), wood) }
        lid(V3(0, 0.002, 0), V3(0.82, 0.005, 0.57), "glass.pane")
        for s: Float in [-1, 1] { K.box(&m, V3(s * 0.3, 0.405, -0.3), V3(0.07, 0.012, 0.03), "metal.galvanized", bevel: 0.002) }
        return K.finish(&m)
    }
}
