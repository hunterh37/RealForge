import simd
import Foundation

/// Pedestrian wayfinding signpost, 3.0 m: round steel post, base collar, four arrow-shaped direction blades.
public struct WayfindingSignpost: RealAsset {
    public static let id = "wayfinding-signpost"
    public static let summary = "Pedestrian wayfinding signpost, 3 m: steel post with collar and four arrow-ended direction blades."
    public static let tags = ["prop", "urban", "street", "sign", "metal"]
    public static let budget = 2400
    public static let author = "hunterh37"

    /// Number of blades, 2 to 6.
    public var blades = 4
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        cy(&m, 0.12, 0.08, V3(0, 0, 0), "metal.cast-iron", bevel: 0.02)
        m.add(turned([(0, 0.08), (0.09, 0.08), (0.05, 0.3), (0.045, 0.34), (0, 0.34)], segments: 24, material: "metal.cast-iron"))
        cy(&m, 0.045, 2.75, V3(0, 0.3, 0), "metal.painted:2A2C30", bevel: 0.006, seg: 20)
        m.add(turned([(0, 0), (0.06, 0), (0.06, 0.03), (0.03, 0.08), (0, 0.09)], segments: 20, material: "metal.painted:2A2C30"), Xform(translation: V3(0, 3.0, 0)))
        let n = max(2, min(6, blades))
        for i in 0..<n {
            let y = 2.7 - Float(i) * 0.24, len = rng.float(0.62...0.78)
            let yaw = Float(i) * (360 / Float(n)) + rng.float(-10...10)
            let outline: [V2] = [V2(0, -0.09), V2(len - 0.1, -0.09), V2(len + 0.04, 0), V2(len - 0.1, 0.09), V2(0, 0.09)]
            m.add(Prim.extrude(outline, depth: 0.012, bevel: 0.003, material: "metal.painted:1F5E8C"),
                  Xform(translation: V3(0.05, y, 0), rotation: simd_quatf(degrees: yaw, axis: .up)))
            bx(&m, V3(len - 0.2, 0.012, 0.016), V3(0.05 + (len - 0.2) / 2 + 0.06, y, 0.0), "plastic.white", r: 0.002, yaw: yaw)
        }
        return K.finish(&m, ao: 0.2)
    }
}
