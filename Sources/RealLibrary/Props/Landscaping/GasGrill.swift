import simd
import Foundation

/// Cabinet 1.0 m by 0.5 m, cooking height 0.9 m, lid top 1.21 m, shelves extend width to 1.8 m.
public struct GasGrill: RealAsset {
    public static let id = "gas-grill"
    public static let summary = "Gas grill cart, 1.2 m: black cabinet with two doors, stainless firebox and domed lid, knobs, side shelves, rear wheels."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "appliance", "metal"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let black = "metal.painted:232326", steel = "metal.stainless"
        let quarter = simd_quatf(degrees: 90, axis: V3(1, 0, 0))
        K.box(&m, V3(0, 0.55, 0), V3(1.0, 0.5, 0.5), black, bevel: 0.006)
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * 0.245, 0.55, 0.255), V3(0.47, 0.44, 0.012), black, bevel: 0.004)
            m.add(barHandle(length: 0.12, standoff: 0.03, radius: 0.007, material: steel), Xform(translation: V3(s * 0.08, 0.7, 0.26)))
            for lz: Float in [-1, 1] { K.box(&m, V3(s * 0.47, 0.15, lz * 0.21), V3(0.04, 0.3, 0.04), black) }
        }
        K.box(&m, V3(0, 0.3, 0), V3(0.9, 0.02, 0.44), steel, bevel: 0.003)
        K.box(&m, V3(0, 0.91, 0), V3(1.04, 0.16, 0.52), steel, bevel: 0.008)
        K.box(&m, V3(0, 1.1, -0.01), V3(1.04, 0.22, 0.5), steel, bevel: 0.09)
        m.add(barHandle(length: 0.7, standoff: 0.055, radius: 0.012, material: steel), Xform(translation: V3(0, 1.12, 0.25)))
        m.add(Prim.cylinder(radius: 0.03, height: 0.012, bevel: 0.002, segments: 16, material: "metal.painted:EDEDED"),
              Xform(translation: V3(0, 1.12, 0.245), rotation: quarter))
        for i in 0..<4 {
            m.add(Prim.cylinder(radius: 0.02, height: 0.025, bevel: 0.003, segments: 14, material: black),
                  Xform(translation: V3(-0.3 + 0.2 * Float(i), 0.9, 0.26), rotation: quarter))
        }
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * 0.73, 0.86, 0), V3(0.42, 0.025, 0.42), steel, bevel: 0.004)
            for lz: Float in [-1, 1] { K.box(&m, V3(s * 0.73, 0.7, lz * 0.19), V3(0.015, 0.34, 0.015), black, bevel: 0.002) }
            m.add(Prim.cylinder(radius: 0.06, height: 0.03, bevel: 0.005, segments: 18, material: "rubber.tire"),
                  Xform(translation: V3(s * 0.53, 0.06, -0.3), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        }
        return K.finish(&m)
    }
}
