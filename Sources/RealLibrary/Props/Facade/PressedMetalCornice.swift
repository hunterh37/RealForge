import simd
import Foundation

/// Pressed-metal cornice 3.0 m: stepped crown profile with modillion blocks and egg-and-dart band.
public struct PressedMetalCornice: RealAsset {
    public static let id = "pressed-metal-cornice"
    public static let summary = "Pressed-metal cornice 3.0 m: stepped crown profile with modillion blocks and egg-and-dart band."
    public static let tags = ["prop", "facade", "trim", "ornament", "metal"]
    public static let budget = 4200
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "metal.painted:D8D2C2"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 3.0
        let prof: [V2] = [V2(-0.2, 0.0), V2(0.2, 0.0), V2(0.2, 0.05), V2(0.14, 0.09), V2(0.14, 0.2), V2(0.1, 0.24), V2(0.1, 0.3), V2(0.18, 0.34), V2(0.2, 0.4), V2(0.0, 0.5), V2(-0.2, 0.5)]
        m.add(Prim.extrude(prof, depth: w, bevel: 0.003, bevelSegments: 1, material: material), Xform(translation: V3(0, 0, 0), rotation: simd_quatf(degrees: -90, axis: .up)))
        let n = 12
        for i in 0..<n { K.box(&m, V3(-w / 2 + 0.15 + (w - 0.3) * Float(i) / Float(n - 1), 0.14, 0.17), V3(0.07, 0.1, 0.07), "metal.painted:C9C2AE", bevel: 0.004) }
        for i in 0..<30 { m.add(Prim.superellipsoid(V3(0.04, 0.05, 0.02), exponent: 2.2, subdivisions: 1, material: material), Xform(translation: V3(-w / 2 + 0.05 + (w - 0.1) * Float(i) / 29, 0.27, 0.11))) }
        return K.finish(&m, ao: 0.05)
    }
}
