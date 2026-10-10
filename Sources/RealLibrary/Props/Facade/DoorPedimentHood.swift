import simd
import Foundation

/// Door hood 1.5 m: triangular pediment on scroll consoles with a dentil band, cast stone.
public struct DoorPedimentHood: RealAsset {
    public static let id = "door-pediment-hood"
    public static let summary = "Door hood 1.5 m: triangular pediment on scroll consoles with a dentil band, cast stone."
    public static let tags = ["prop", "facade", "door", "trim", "ornament", "stone"]
    public static let budget = 3400
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "stone.cast-stone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 1.5
        K.box(&m, V3(0, 0.36, 0.0), V3(w, 0.07, 0.4), material, bevel: 0.006)
        K.box(&m, V3(0, 0.325, 0.2), V3(w - 0.1, 0.03, 0.02), material, bevel: 0.003)
        for i in 0..<14 { K.box(&m, V3(-w / 2 + 0.12 + (w - 0.24) * Float(i) / 13, 0.31, 0.2), V3(0.04, 0.03, 0.03), material, bevel: 0.002) }
        let tri = Prim.extrude([V2(-w / 2 + 0.03, 0), V2(w / 2 - 0.03, 0), V2(0, 0.17)], depth: 0.32, bevel: 0.005, bevelSegments: 2, material: material)
        m.add(tri, Xform(translation: V3(0, 0.395, 0.0)))
        for sx: Float in [-1, 1] {
            let x = sx * (w / 2 - 0.12)
            K.box(&m, V3(x, 0.2, -0.12), V3(0.1, 0.3, 0.16), material, bevel: 0.005)
            K.box(&m, V3(x, 0.05, 0.1), V3(0.1, 0.1, 0.2), material, bevel: 0.005)
        }
        return K.finish(&m, ao: 0.05)
    }
}
