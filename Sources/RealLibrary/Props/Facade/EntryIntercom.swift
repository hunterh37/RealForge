import simd
import Foundation

/// Entry video intercom 0.1 x 0.2 m: brushed stainless faceplate, speaker grille, camera lens, call button and name strip.
public struct EntryIntercom: RealAsset {
    public static let id = "entry-intercom"
    public static let summary = "Entry video intercom 0.1 x 0.2 m: brushed stainless faceplate, speaker grille, camera lens, call button and name strip."
    public static let tags = ["prop", "facade", "door", "electronics", "metal"]
    public static let budget = 3700
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "metal.stainless"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        K.box(&m, V3(0, 0.1, 0), V3(0.1, 0.2, 0.04), material, bevel: 0.006)
        m.add(Prim.cylinder(radius: 0.012, height: 0.006, bevel: 0.001, segments: 16, material: "glass.tinted"), Xform(translation: V3(0, 0.175, 0.02), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        for r in 0..<4 { for c in 0..<5 { m.add(Prim.cylinder(radius: 0.0025, height: 0.002, bevel: 0.0005, segments: 6, material: "plastic.black"), Xform(translation: V3(-0.02 + 0.01 * Float(c), 0.14 - 0.008 * Float(r), 0.021), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)))) } }
        K.box(&m, V3(0, 0.08, 0.021), V3(0.06, 0.025, 0.004), "plastic.black", bevel: 0.001)
        m.add(Prim.cylinder(radius: 0.012, height: 0.006, bevel: 0.002, segments: 16, material: "plastic.white"), Xform(translation: V3(0, 0.05, 0.02), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        K.box(&m, V3(0, 0.025, 0.021), V3(0.07, 0.02, 0.003), "emissive.panel", bevel: 0.001)
        return K.finish(&m, ao: 0.05)
    }
}
