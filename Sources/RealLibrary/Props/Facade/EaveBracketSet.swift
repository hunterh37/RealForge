import simd
import Foundation

/// Eave bracket set 2.0 m: four carved wood brackets under a fascia board with soffit return.
public struct EaveBracketSet: RealAsset {
    public static let id = "eave-bracket-set"
    public static let summary = "Eave bracket set 2.0 m: four carved wood brackets under a fascia board with soffit return."
    public static let tags = ["prop", "facade", "trim", "ornament", "wood"]
    public static let budget = 3000
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "wood.painted-exterior:E9E4D6"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 2.0, d: Float = 0.4
        K.box(&m, V3(0, 0.46, d / 2 - 0.02), V3(w, 0.08, 0.04), material, bevel: 0.004)
        K.box(&m, V3(0, 0.49, 0), V3(w + 0.04, 0.02, d), material, bevel: 0.003)
        for i in 0..<4 {
            let x = -w / 2 + 0.2 + (w - 0.4) * Float(i) / 3
            let prof = Prim.extrude([V2(-0.15, 0.44), V2(0.15, 0.44), V2(0.13, 0.4), V2(-0.0, 0.2), V2(-0.12, 0.04), V2(-0.19, 0.04), V2(-0.19, 0.26)], depth: 0.06, bevel: 0.003, bevelSegments: 1, material: material)
            m.add(prof, Xform(translation: V3(x, 0, -0.03), rotation: simd_quatf(degrees: -90, axis: .up)))
            K.box(&m, V3(x, 0.2, d / 2 - 0.05), V3(0.06, 0.05, 0.05), material, bevel: 0.004)
        }
        return K.finish(&m, ao: 0.05)
    }
}
