import simd
import Foundation

/// 0.62 m diameter at the belly, 0.93 m high, four galvanized hoops.
public struct RainBarrel: RealAsset {
    public static let id = "rain-barrel"
    public static let summary = "Rain barrel, 0.93 m: hooped cedar barrel with open top and water, brass-look spigot low on the front."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "container", "wood"]
    public static let budget = 4500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let wood = "wood.cedar-weathered", H: Float = 0.93
        func r(_ y: Float) -> Float { 0.26 + 0.05 * sin(.pi * y / H) }
        var prof: [(Float, Float)] = [(0, 0)]
        for i in 0...12 { let y = H * Float(i) / 12; prof.append((r(y), y)) }
        prof += [(r(H) - 0.02, H), (r(H) - 0.02, H - 0.1)]
        m.add(turned(prof, segments: 40, material: wood, grainVertical: true))
        m.add(Prim.lathe([V2(r(H) - 0.021, H - 0.06), V2(0, H - 0.06)], segments: 40, seamTile: 1, material: "water.pond"))
        for y: Float in [0.1, 0.3, 0.62, 0.84] {
            m.add(Prim.torus(major: r(y) + 0.003, minor: 0.009, segments: 40, sides: 6, material: "metal.galvanized"), Xform(translation: V3(0, y, 0)))
        }
        K.rod(&m, [V3(0, 0.16, r(0.16)), V3(0, 0.16, r(0.16) + 0.1)], r: 0.013, "metal.brass-aged")
        K.rod(&m, [V3(-0.04, 0.185, r(0.16) + 0.1), V3(0.04, 0.185, r(0.16) + 0.1)], r: 0.007, "metal.brass-aged")
        return K.finish(&m)
    }
}
