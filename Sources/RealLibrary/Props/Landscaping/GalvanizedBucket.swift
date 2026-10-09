import simd
import Foundation

public struct GalvanizedBucket: RealAsset {
    public static let id = "galvanized-bucket"
    public static let summary = "Galvanized steel bucket, 0.3 m tall x 0.3 m: rolled rim, bail handle with wooden grip."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "container", "metal"]
    public static let budget = 3000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let g = "metal.galvanized-aged"
        m.add(Prim.lathe([V2(0, 0), V2(0.11, 0), V2(0.113, 0.01), V2(0.15, 0.3), V2(0.157, 0.305), V2(0.153, 0.308)], segments: 28, seamTile: 0.3, material: g))
        m.add(Prim.torus(major: 0.152, minor: 0.005, segments: 28, sides: 6, material: g), Xform(translation: V3(0, 0.306, 0)))
        K.rod(&m, K.arc(V3(0, 0.3, 0), 0.158, 0, 180, n: 18), r: 0.004, g, sides: 6)
        m.add(Prim.cylinder(radius: 0.012, height: 0.1, bevel: 0.003, segments: 10, material: "wood.beech-stained"), Xform(translation: V3(-0.05, 0.458, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        return K.finish(&m)
    }
}
