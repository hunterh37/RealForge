import simd
import Foundation

/// Turned roof finial: a square lead-clad plinth, a baluster stem with collars, a polished ball and a
/// fleur-de-lis spike with three petals. Sits on y = 0, 0.95 m tall.
public struct RoofFinial: RealAsset {
    public static let id = "roof-finial"
    public static let summary = "Roof finial, 0.95 m: lead-clad plinth, turned baluster, brass ball, three-petal fleur-de-lis spike."
    public static let tags = ["prop", "architecture", "facade", "roof", "ornament", "metal"]
    public static let budget = 4500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 10, distance: 2.0)

    public var body: MaterialKey = "metal.copper-patina"
    public var trim: MaterialKey = "metal.brass-aged"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        FA.box(&m, V3(0.26, 0.12, 0.26), V3(0, 0.06, 0), "metal.galvanized", r: 0.006)
        FA.box(&m, V3(0.2, 0.1, 0.2), V3(0, 0.17, 0), body, r: 0.008)
        m.add(Prim.lathe([V2(0, 0.22), V2(0.09, 0.22), V2(0.1, 0.235), V2(0.06, 0.26), V2(0.045, 0.3), V2(0.06, 0.34), V2(0.035, 0.38),
                          V2(0.03, 0.42), V2(0.05, 0.44), V2(0.05, 0.455), V2(0.028, 0.47), V2(0, 0.47)], segments: 20, material: body))
        m.add(Prim.superellipsoid(V3(0.15, 0.15, 0.15), exponent: 2, subdivisions: 10, material: trim), Xform(translation: V3(0, 0.55, 0)))
        m.add(Prim.torus(major: 0.06, minor: 0.008, segments: 24, sides: 6, material: trim), Xform(translation: V3(0, 0.63, 0)))
        m.add(Prim.lathe([V2(0.02, 0.62), V2(0.012, 0.75), V2(0.006, 0.88), V2(0, 0.95)], segments: 8, material: trim))
        for k in 0..<3 {
            let a = Float(k) * 2 * .pi / 3
            m.add(Prim.superellipsoid(V3(0.035, 0.16, 0.012), exponent: 2.2, subdivisions: 6, material: trim),
                  Xform(translation: V3(cos(a) * 0.04, 0.72, sin(a) * 0.04), rotation: simd_quatf(angle: -a, axis: FA.Y) * FA.q(k == 0 ? 0 : 22, FA.Z)))
        }
        groundAO(&m, height: 0.12, floor: 0.9)
        return LODModel(m)
    }
}
