import simd
import Foundation

public struct StreetLamp: RealAsset {
    public static let id = "street-lamp"
    public static let summary = "Victorian cast-iron street lamp: fluted base, tapered pole, lantern with glowing glass."
    public static let tags = ["prop", "urban", "light", "metal"]
    public static let budget = 10_000
    public var height: Float = 3.6
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let iron: MaterialKey = "metal.iron", h = height
        m.add(turned([(0.0, 0), (0.17, 0), (0.17, 0.05), (0.14, 0.08), (0.13, 0.32), (0.1, 0.38), (0.1, 0.45), (0.075, 0.5), (0.06, 0.62),
                      (0.05, h * 0.5), (0.042, h - 0.55), (0.06, h - 0.52), (0.06, h - 0.48), (0.035, h - 0.45), (0.0, h - 0.45)], segments: 32, material: iron))
        // Lantern: tapered frame (4 posts), glass, cap and finial.
        let base = h - 0.45
        m.add(turned([(0, base), (0.12, base), (0.13, base + 0.03), (0, base + 0.03)], segments: 4, material: iron, seamTile: 0.2),
              Xform(rotation: simd_quatf(degrees: 45, axis: .up)))
        m.add(turned([(0.09, base + 0.03), (0.15, base + 0.36)], segments: 4, material: "glass.lamp", seamTile: 0.2), Xform(rotation: simd_quatf(degrees: 45, axis: .up)))
        for k in 0..<4 {
            let a = Float(k) * .pi / 2
            let d0 = V3(cos(a), 0, sin(a)) * 0.095 * 1.4142 / 1.4142, d1 = V3(cos(a), 0, sin(a)) * 0.155
            m.add(Prim.tube([V3(d0.x, base + 0.03, d0.z), V3(d1.x, base + 0.37, d1.z)], radii: [0.008, 0.008], sides: 6, seamTile: 0.1, material: iron))
        }
        m.add(turned([(0.0, base + 0.36), (0.2, base + 0.36), (0.2, base + 0.38), (0.06, base + 0.5), (0.02, base + 0.52), (0.03, base + 0.56), (0, base + 0.6)],
                     segments: 4, material: iron, seamTile: 0.2), Xform(rotation: simd_quatf(degrees: 45, axis: .up)))
        groundAO(&m, height: 0.4, floor: 0.6)
        return LODModel(m)
    }
}
