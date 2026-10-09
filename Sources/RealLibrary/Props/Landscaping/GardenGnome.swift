import simd
import Foundation

public struct GardenGnome: RealAsset {
    public static let id = "garden-gnome"
    public static let summary = "Painted resin garden gnome, 0.35 m: red pointed cap, white beard, blue coat, black belt and boots."
    public static let tags = ["prop", "landscaping", "garden", "decor", "outdoor"]
    public static let budget = 6000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        m.add(Prim.lathe([V2(0, 0), V2(0.07, 0), V2(0.075, 0.03), V2(0.065, 0.14), V2(0.05, 0.19), V2(0, 0.2)], segments: 24, seamTile: 0.2, material: "ceramic.cobalt"))
        m.add(Prim.cylinder(radius: 0.071, height: 0.012, bevel: 0.003, segments: 24, material: "plastic.black"), Xform(translation: V3(0, 0.08, 0)))
        m.add(Prim.lathe([V2(0, 0.0), V2(0.08, 0.0), V2(0.08, 0.025), V2(0, 0.03)], segments: 20, seamTile: 0.2, material: "plastic.black"))
        m.add(Prim.superellipsoid(V3(0.1, 0.12, 0.09), exponent: 2, subdivisions: 4, material: "plastic.white"), Xform(translation: V3(0, 0.17, 0.02)))
        m.add(Prim.superellipsoid(V3(0.075, 0.07, 0.07), exponent: 2, subdivisions: 4, material: "ceramic.bisque"), Xform(translation: V3(0, 0.215, 0.05)))
        m.add(Prim.superellipsoid(V3(0.02, 0.02, 0.02), exponent: 2, subdivisions: 3, material: "ceramic.terracotta"), Xform(translation: V3(0, 0.215, 0.09)))
        m.add(Prim.lathe([V2(0, 0), V2(0.05, 0), V2(0.04, 0.06), V2(0.015, 0.12), V2(0, 0.135)], segments: 24, seamTile: 0.2, material: "metal.enamel"), Xform(translation: V3(0, 0.215, 0.0)))
        return K.finish(&m)
    }
}
