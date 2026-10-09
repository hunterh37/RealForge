import simd
import Foundation

/// Table 0.72 m diameter and 0.74 m high, chairs 0.45 m seat height.
public struct BistroSet: RealAsset {
    public static let id = "bistro-set"
    public static let summary = "Bistro set, 0.9 m: round cedar-top table on a cast pedestal with two white tube-frame chairs facing it."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "furniture", "metal"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let white = "metal.painted:EDEBE4", cast = "metal.cast-iron"
        m.add(Prim.cylinder(radius: 0.36, height: 0.025, bevel: 0.004, segments: 36, material: "wood.cedar-weathered"), Xform(translation: V3(0, 0.715, 0)))
        m.add(Prim.torus(major: 0.36, minor: 0.008, segments: 36, sides: 6, material: cast), Xform(translation: V3(0, 0.715, 0)))
        m.add(turned([(0, 0), (0.2, 0), (0.2, 0.02), (0.08, 0.05), (0.03, 0.12), (0.03, 0.6), (0.06, 0.65), (0.08, 0.715), (0, 0.715)], segments: 28, material: cast))
        for s: Float in [-1, 1] {
            let zc = s * 0.62
            m.add(Prim.cylinder(radius: 0.19, height: 0.025, bevel: 0.004, segments: 28, material: white), Xform(translation: V3(0, 0.44, zc)))
            for lx: Float in [-1, 1] { for lz: Float in [-1, 1] {
                K.rod(&m, [V3(lx * 0.14, 0, zc + lz * 0.14), V3(lx * 0.14, 0.44, zc + lz * 0.14)], r: 0.008, white)
            } }
            var back = [V3(-0.15, 0.45, zc + s * 0.15)]
            back += K.arc(V3(0, 0.78, 0), 0.17, 180, 0, n: 14).map { V3($0.x, $0.y, zc + s * 0.19) }
            back.append(V3(0.15, 0.45, zc + s * 0.15))
            K.rod(&m, back, r: 0.008, white)
            K.rod(&m, [V3(-0.17, 0.62, zc + s * 0.19), V3(0.17, 0.62, zc + s * 0.19)], r: 0.006, white)
        }
        return K.finish(&m)
    }
}
