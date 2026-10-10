import simd
import Foundation

/// Exterior wall lantern: cast backplate, scroll arm, cap, four corner posts around a glass cylinder
/// and a lit bulb. Black cast iron with a rust bloom at the screws.
public struct WallSconce: RealAsset {
    public static let id = "wall-sconce"
    public static let summary = "Exterior wall lantern, 0.38 m: cast backplate, scroll arm, glass cylinder with lit bulb, hooded cap."
    public static let tags = ["prop", "architecture", "facade", "trim", "light", "metal", "urban"]
    public static let budget = 8_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 10, distance: 0.9)

    public var height: Float = 0.38
    public var iron: MaterialKey = "metal.painted:1B1C1E"
    public var glass: MaterialKey = "glass.pane"
    public var bulb: MaterialKey = "emissive.warm"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let H = height, cx: Float = 0.16
        m.add(Prim.extrude(Shape2D.roundedRect(0.09, 0.2, radius: 0.015), depth: 0.014, bevel: 0.003, bevelSegments: 1, material: iron),
              Xform(translation: V3(0, 0.2, 0.007)))
        for dy: Float in [-0.07, 0.07] { hexBolt(&m, at: V3(0, 0.2 + dy, 0.014), normal: FA.Z, size: 0.012, material: "metal.rust") }
        FA.path(&m, [V3(0, 0.2, 0.012), V3(0, 0.2, 0.07), V3(0, 0.21, 0.12), V3(0, 0.25, cx - 0.01)], r: 0.008, iron, sides: 8)
        m.add(Prim.torus(major: 0.035, minor: 0.005, segments: 20, sides: 6, material: iron),
              Xform(translation: V3(0.0, 0.16, 0.075), rotation: FA.q(90, FA.Z)))
        // Lantern body.
        m.add(Prim.lathe([V2(0, 0), V2(0.04, 0), V2(0.058, 0.02), V2(0.062, 0.035), V2(0.0, 0.035)], segments: 20, material: iron), Xform(translation: V3(0, 0.0, cx)))
        m.add(Prim.cylinder(radius: 0.055, height: 0.17, bevel: 0.001, segments: 20, bevelSegments: 1, material: glass), Xform(translation: V3(0, 0.035, cx)))
        m.add(Prim.superellipsoid(V3(0.05, 0.08, 0.05), exponent: 2, subdivisions: 8, material: bulb), Xform(translation: V3(0, 0.1, cx)))
        for k in 0..<4 {
            let a = Float(k) * .pi / 2 + .pi / 4
            FA.rod(&m, V3(0.057 * cos(a), 0.035, cx + 0.057 * sin(a)), V3(0.057 * cos(a), 0.205, cx + 0.057 * sin(a)), r: 0.0035, iron, sides: 6)
        }
        m.add(Prim.lathe([V2(0.0, 0.205), V2(0.068, 0.205), V2(0.07, 0.215), V2(0.045, 0.255), V2(0.02, 0.28), V2(0.012, 0.3), V2(0.0, 0.305)],
                         segments: 24, material: iron), Xform(translation: V3(0, 0, cx)))
        groundAO(&m, height: 0.06, floor: 0.9)
        return LODModel(FA.centerZ(m))
    }
}
