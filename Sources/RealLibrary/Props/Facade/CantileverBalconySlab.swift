import simd
import Foundation

/// Cantilever balcony: a 2.4 x 1.4 m board-formed concrete slab 0.18 m thick with a thermal-break
/// strip, drip edge, glass balustrade with stainless handrail and standoff clamps, and soffit downlights.
public struct CantileverBalconySlab: RealAsset {
    public static let id = "cantilever-balcony-slab"
    public static let summary = "Cantilever balcony, 2.4 m: concrete slab, thermal break, glass balustrade, downlights."
    public static let tags = ["prop", "architecture", "facade", "concrete", "glass", "metal"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 38, elevation: 18, distance: 5.2)

    public var width: Float = 2.4
    public var depth: Float = 1.4
    public var thickness: Float = 0.18
    public var concrete: MaterialKey = "concrete.smooth"
    public var steel: MaterialKey = "metal.stainless"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, D = depth, T = thickness
        FA.box(&m, V3(W, T, D), V3(0, T / 2, D / 2), concrete, r: 0.006)
        FA.box(&m, V3(W - 0.02, 0.03, 0.06), V3(0, T - 0.015, 0.03), "plastic.black", r: 0.002)   // thermal break
        FA.box(&m, V3(W, 0.02, 0.03), V3(0, 0.01, D - 0.015), steel, r: 0.002)                    // drip edge
        // Board-formed grooves on the slab edge.
        for i in 0..<5 { FA.box(&m, V3(W - 0.02, 0.003, 0.003), V3(0, 0.03 + Float(i) * 0.03, D + 0.001), "concrete.rough", r: 0.0005) }
        // Glass balustrade: panels on a bottom shoe, handrail on three sides.
        let gh: Float = 1.05, base = T
        let sides: [(V3, V3)] = [(V3(-W / 2 + 0.05, base, D - 0.05), V3(W / 2 - 0.05, base, D - 0.05)),
                                 (V3(-W / 2 + 0.05, base, 0.05), V3(-W / 2 + 0.05, base, D - 0.05)),
                                 (V3(W / 2 - 0.05, base, 0.05), V3(W / 2 - 0.05, base, D - 0.05))]
        for (a, b) in sides {
            let mid = (a + b) / 2, len = simd_length(b - a)
            let yaw: Float = abs(b.x - a.x) > 0.01 ? 0 : 90
            m.add(Prim.roundedBox(V3(len, gh - 0.1, 0.014), radius: 0.002, bevelSegments: 1, material: "glass.clear"), Xform(translation: mid + V3(0, gh / 2, 0), rotation: FA.q(yaw, FA.Y)))
            m.add(Prim.roundedBox(V3(len, 0.06, 0.04), radius: 0.004, bevelSegments: 1, material: steel), Xform(translation: mid + V3(0, 0.03, 0), rotation: FA.q(yaw, FA.Y)))
            FA.rod(&m, a + V3(0, gh, 0), b + V3(0, gh, 0), r: 0.02, steel, sides: 12)
        }
        for e: Float in [-1, 1] { for z: Float in [0.05, D - 0.05] {
            FA.rod(&m, V3(e * (W / 2 - 0.05), base, z), V3(e * (W / 2 - 0.05), base + gh, z), r: 0.02, steel, sides: 10)
        } }
        for i in 1..<4 {
            let x = -W / 2 + 0.05 + Float(i) * (W - 0.1) / 4
            for y: Float in [0.3, 0.8] { FA.cylZ(&m, r: 0.016, h: 0.026, at: V3(x, base + y, D - 0.05 - 0.013), steel, segments: 12) }
        }
        // Soffit downlights.
        for i in 0..<3 {
            let x = -W / 3 + Float(i) * W / 3
            m.add(Prim.cylinder(radius: 0.04, height: 0.012, bevel: 0.002, segments: 18, bevelSegments: 1, material: steel), Xform(translation: V3(x, -0.006, D * 0.6)))
            m.add(Prim.cylinder(radius: 0.028, height: 0.004, bevel: 0.001, segments: 18, bevelSegments: 1, material: "emissive.warm"), Xform(translation: V3(x, -0.01, D * 0.6)))
        }
        groundAO(&m, height: 0.12, floor: 0.85)
        return LODModel(FA.centerZ(m.transformed(Xform(translation: V3(0, 0.012, 0)))))
    }
}
