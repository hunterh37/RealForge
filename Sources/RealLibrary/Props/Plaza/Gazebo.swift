import simd
import Foundation

/// Hexagonal park gazebo, 3.9 m across and 4 m tall: raised timber deck, six posts, rail, cone roof with finial.
public struct Gazebo: RealAsset {
    public static let id = "gazebo"
    public static let summary = "Hexagonal park gazebo, 3.9 m across: raised deck, six posts, railing, steel-clad cone roof."
    public static let tags = ["prop", "park", "outdoor", "wood"]
    public static let budget = 12300
    public static let author = "hunterh37"

    /// Roof color, sRGB hex.
    public var roofColor: UInt32 = 0x3C5A48
    /// Post and rail paint material.
    public var paint = "wood.barn-white"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let R: Float = 1.8
        m.add(Prim.extrude(Shape2D.polygon(sides: 6, radius: R + 0.1), depth: 0.5, bevel: 0.01, material: "concrete.rough"),
              Xform(translation: V3(0, 0.25, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        m.add(Prim.extrude(Shape2D.polygon(sides: 6, radius: R + 0.05), depth: 0.04, bevel: 0.004, material: "wood.weathered"),
              Xform(translation: V3(0, 0.52, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        let deck: Float = 0.54, postH: Float = 2.3
        var tops: [V3] = []
        for i in 0..<6 {
            let a = Float(i) * .pi / 3
            let p = V3(cos(a) * (R - 0.1), 0, sin(a) * (R - 0.1))
            K.box(&m, p + V3(0, deck + postH / 2, 0), V3(0.14, postH, 0.14), paint, bevel: 0.006)
            tops.append(p + V3(0, deck + postH, 0))
        }
        for i in 0..<6 {
            let a = tops[i], b = tops[(i + 1) % 6]
            K.beam(&m, a - V3(0, 0.07, 0), b - V3(0, 0.07, 0), 0.10, 0.12, paint)
            let lo = V3(a.x, deck + 0.95, a.z), hi = V3(b.x, deck + 0.95, b.z)
            K.beam(&m, lo, hi, 0.08, 0.05, paint)
            K.beam(&m, V3(a.x, deck + 0.12, a.z), V3(b.x, deck + 0.12, b.z), 0.08, 0.05, paint)
            for j in 1..<7 {
                let t = Float(j) / 7, p = a + (b - a) * t
                K.box(&m, V3(p.x, deck + 0.53, p.z), V3(0.035, 0.82, 0.035), paint, bevel: 0.004)
            }
        }
        let roofY = deck + postH
        m.add(turned([(0, roofY + 0.9), (0.06, roofY + 0.75), (R * 1.08, roofY - 0.02), (R * 1.08, roofY - 0.06), (0, roofY - 0.06)],
                      segments: 6, material: MaterialKey(stringLiteral: "metal.painted:" + String(roofColor, radix: 16, uppercase: true))))
        m.add(turned([(0, 0), (0.05, 0), (0.02, 0.12), (0.035, 0.2), (0, 0.32)], segments: 16, material: "metal.brass"),
              Xform(translation: V3(0, roofY + 0.88, 0)))
        return K.finish(&m, ao: 0.3)
    }
}
