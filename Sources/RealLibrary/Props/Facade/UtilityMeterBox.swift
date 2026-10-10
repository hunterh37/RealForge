import simd
import Foundation

/// Electric service cabinet with meter: 0.45 x 0.65 m painted steel enclosure, glass-faced meter dial
/// with a locking ring, hinged door with hasp and padlock, rooftop weather hood and two conduits.
/// Wall plane at z = 0.
public struct UtilityMeterBox: RealAsset {
    public static let id = "utility-meter-box"
    public static let summary = "Electric meter cabinet, 0.45 x 0.65 m: steel enclosure, dial meter with seal ring, hasp, padlock, conduits."
    public static let tags = ["prop", "architecture", "facade", "utility", "electrical", "metal"]
    public static let budget = 4000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 8, distance: 1.9)

    public var width: Float = 0.45
    public var height: Float = 0.65
    public var depth: Float = 0.2
    public var shell: MaterialKey = "metal.transformer-gray"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = height, D = depth, y0: Float = 0.2
        FA.box(&m, V3(W, H, D), V3(0, y0 + H / 2, D / 2), shell, r: 0.006)
        // Weather hood.
        m.add(Prim.extrude([V2(0, 0), V2(0.06, -0.02), V2(0.06, -0.035), V2(0, -0.015)], depth: W + 0.04, bevel: 0.002, bevelSegments: 1, material: shell),
              Xform(translation: V3(0, y0 + H + 0.0, D), rotation: FA.q(90, FA.Y) * FA.q(90, FA.Z) * FA.q(-90, FA.Z)))
        FA.box(&m, V3(W + 0.04, 0.03, D + 0.03), V3(0, y0 + H + 0.015, D / 2 + 0.01), shell, r: 0.005, rot: FA.q(-5, FA.X))
        // Meter: base ring, glass, dial, seal ring.
        let mc = V3(0, y0 + H * 0.58, D)
        FA.cylZ(&m, r: 0.095, h: 0.03, at: mc, "plastic.black", bevel: 0.004, segments: 28)
        FA.cylZ(&m, r: 0.082, h: 0.07, at: mc, "glass.clear", bevel: 0.003, segments: 28)
        FA.cylZ(&m, r: 0.07, h: 0.04, at: mc + V3(0, 0, 0.0), "plastic.white", bevel: 0.002, segments: 28)
        m.add(Prim.torus(major: 0.09, minor: 0.008, segments: 28, sides: 6, material: "metal.galvanized"), Xform(translation: mc + V3(0, 0, 0.07), rotation: FA.q(90, FA.X)))
        for k in 0..<5 { FA.box(&m, V3(0.018, 0.026, 0.004), V3(-0.04 + Float(k) * 0.02, mc.y + 0.02, D + 0.043), "plastic.black", r: 0.0005) }
        FA.box(&m, V3(0.1, 0.004, 0.003), V3(0, mc.y - 0.03, D + 0.042), "emissive.signal-red", r: 0.0005)
        // Door seam, hasp and padlock.
        FA.box(&m, V3(W - 0.04, 0.004, 0.003), V3(0, y0 + H * 0.28, D + 0.002), "metal.galvanized-aged", r: 0.0005)
        FA.box(&m, V3(0.04, 0.12, 0.012), V3(W / 2 - 0.05, y0 + H * 0.28, D + 0.008), "metal.galvanized", r: 0.002)
        m.add(Prim.roundedBox(V3(0.034, 0.04, 0.018), radius: 0.004, bevelSegments: 1, material: "metal.brass"), Xform(translation: V3(W / 2 - 0.05, y0 + H * 0.28 - 0.045, D + 0.02)))
        m.add(Prim.torus(major: 0.012, minor: 0.003, segments: 12, sides: 6, arc: .pi, material: "metal.steel"),
              Xform(translation: V3(W / 2 - 0.05, y0 + H * 0.28 - 0.025, D + 0.02), rotation: FA.q(90, FA.X)))
        FA.box(&m, V3(0.12, 0.04, 0.003), V3(-0.1, y0 + H * 0.12, D + 0.002), "plastic.yellow", r: 0.001)
        // Conduits down to the ground and up into the wall.
        for x in [-0.1, 0.1] as [Float] {
            FA.rod(&m, V3(x, y0, D * 0.5), V3(x, 0, D * 0.5), r: 0.017, "metal.galvanized", sides: 12)
            FA.cylZ(&m, r: 0.026, h: 0.02, at: V3(x, 0.03, 0.0), "metal.galvanized", bevel: 0.003, segments: 12)
        }
        FA.path(&m, [V3(0, y0 + H, D * 0.5), V3(0, y0 + H + 0.12, D * 0.5), V3(0, y0 + H + 0.14, 0.0)], r: 0.016, "metal.galvanized", sides: 10)
        groundAO(&m, height: 0.12, floor: 0.85)
        return LODModel(FC.place(m))
    }
}
