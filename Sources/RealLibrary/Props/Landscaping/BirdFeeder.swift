import simd
import Foundation

/// Hopper 200 mm wide, 260 mm roof, on a 26 mm pole.
public struct BirdFeeder: RealAsset {
    public static let id = "bird-feeder"
    public static let summary = "Pole-mounted bird feeder, 1.43 m: steel pole with ground plate, cedar hopper with glass sides, roof, tray and perch."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "decor", "wood"]
    public static let budget = 4500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let wood = "wood.cedar-weathered", steel = "metal.painted:2E2E30"
        m.add(Prim.cylinder(radius: 0.06, height: 0.012, bevel: 0.003, segments: 20, material: steel))
        K.rod(&m, [V3(0, 0, 0), V3(0, 1.2, 0)], r: 0.013, steel, sides: 10)
        K.box(&m, V3(0, 1.21, 0), V3(0.26, 0.016, 0.22), wood)
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * 0.105, 1.285, 0), V3(0.016, 0.135, 0.17), wood)
            K.box(&m, V3(0, 1.285, s * 0.085), V3(0.2, 0.12, 0.004), "glass.pane")
        }
        for s: Float in [-1, 1] {
            K.beam(&m, V3(s * 0.17, 1.36, 0), V3(0, 1.42, 0), 0.26, 0.014, wood, up: V3(0, 1, 0))
        }
        K.rod(&m, [V3(-0.09, 1.22, 0.13), V3(0.09, 1.22, 0.13)], r: 0.006, wood)
        return K.finish(&m)
    }
}
