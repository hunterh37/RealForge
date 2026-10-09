import simd
import Foundation

public struct GardenTrowel: RealAsset {
    public static let id = "garden-trowel"
    public static let summary = "Hand trowel, 0.32 m: stainless scooped blade, bent neck and ash handle with hang hole."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "tool", "handheld", "metal"]
    public static let budget = 3000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let st = "metal.stainless", ash = "wood.beech-stained"
        m.add(Prim.cylinder(radius: 0.017, height: 0.12, bevel: 0.006, segments: 14, material: ash), Xform(translation: V3(0, 0.02, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        K.rod(&m, [V3(0.1, 0.037, 0), V3(0.15, 0.04, 0), V3(0.18, 0.02, 0)], r: 0.005, st, sides: 8)
        m.add(Prim.extrude(Shape2D.rounded([V2(0, -0.04), V2(0.14, -0.04), V2(0.17, 0), V2(0.14, 0.04), V2(0, 0.04)], radius: 0.008), depth: 0.002, bevel: 0.0008, bevelSegments: 1, material: st), Xform(translation: V3(0.17, 0.016, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        return K.finish(&m)
    }
}
