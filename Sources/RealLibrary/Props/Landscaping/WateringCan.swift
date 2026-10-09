import simd
import Foundation

/// 0.19 m body diameter, spout reaches 0.45 m forward.
public struct WateringCan: RealAsset {
    public static let id = "watering-can"
    public static let summary = "Galvanized watering can, 0.37 m: round body, long angled spout with rose, over-the-top bow handle and rear grip."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "tool", "metal", "handheld"]
    public static let budget = 4000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let zinc = "metal.galvanized"
        m.add(Prim.cylinder(radius: 0.095, height: 0.24, bevel: 0.006, segments: 28, material: zinc))
        m.add(Prim.torus(major: 0.095, minor: 0.005, segments: 28, sides: 6, material: zinc), Xform(translation: V3(0, 0.238, 0)))
        let sp = catmull([V3(0, 0.04, 0.085), V3(0, 0.16, 0.2), V3(0, 0.3, 0.38), V3(0, 0.36, 0.45)], per: 6)
        let radii = (0..<sp.count).map { 0.02 - 0.008 * Float($0) / Float(sp.count - 1) }
        m.add(Prim.tube(sp, radii: radii, sides: 10, seamTile: 0.1, material: zinc))
        let dir = simd_normalize(sp[sp.count - 1] - sp[sp.count - 3])
        m.add(Prim.lathe([V2(0, 0), V2(0.015, 0), V2(0.045, 0.05), V2(0, 0.055)], segments: 20, seamTile: 0.1, material: zinc),
              Xform(translation: sp[sp.count - 1], rotation: simd_quatf(from: V3(0, 1, 0), to: dir)))
        K.rod(&m, catmull([V3(0, 0.22, 0.08), V3(0, 0.34, 0.03), V3(0, 0.36, -0.03), V3(0, 0.27, -0.09)], per: 6), r: 0.007, zinc)
        K.rod(&m, catmull([V3(0, 0.22, -0.09), V3(0, 0.3, -0.16), V3(0, 0.22, -0.2), V3(0, 0.06, -0.1)], per: 6), r: 0.008, zinc)
        return K.finish(&m)
    }
}
