import simd
import Foundation

/// Public bike repair station, 1.6 m post: steel column with hanger arm, tethered tools and a floor pump.
public struct BikeRepairStation: RealAsset {
    public static let id = "bike-repair-station"
    public static let summary = "Public bike repair station: stainless post with hanger arm, tethered tool heads and a floor pump."
    public static let tags = ["prop", "urban", "street", "metal"]
    public static let budget = 2100
    public static let author = "hunterh37"

    /// Post color, sRGB hex.
    public var postColor: UInt32 = 0x2D7DA8
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let paint = MaterialKey(stringLiteral: "metal.painted:" + String(postColor, radix: 16, uppercase: true))
        bx(&m, V3(0.34, 0.02, 0.34), V3(0, 0.01, 0), "metal.galvanized", r: 0.004)
        bx(&m, V3(0.12, 1.5, 0.1), V3(0, 0.77, 0), paint, r: 0.012, bs: 2)
        bx(&m, V3(0.14, 0.08, 0.12), V3(0, 1.55, 0), paint, r: 0.02, bs: 2)
        rod(&m, V3(0, 1.38, 0), V3(0.0, 1.38, 0.3), 0.015, "metal.stainless")
        rod(&m, V3(0.0, 1.38, 0.3), V3(0.0, 1.38, 0.55), 0.011, "metal.stainless")
        rod(&m, V3(0.0, 1.38, 0.55), V3(0.0, 1.31, 0.62), 0.011, "metal.stainless")
        for (i, x) in ([-0.05, 0.0, 0.05] as [Float]).enumerated() {
            let y = 1.1 - Float(i) * 0.14
            m.add(Prim.tube([V3(x * 1.2, y, 0.052), V3(x * 2 + 0.06, y - 0.1, 0.12), V3(x * 2 + 0.07, y - 0.18 - rng.float(0...0.05), 0.2)],
                            radii: [0.003, 0.003, 0.003], sides: 6, seamTile: 0.1, material: "metal.steel"))
            bx(&m, V3(0.03, 0.09, 0.03), V3(x * 2 + 0.07, y - 0.24, 0.2), "plastic.black", r: 0.006)
        }
        m.add(Prim.cylinder(radius: 0.035, height: 0.55, bevel: 0.006, segments: 16, material: "metal.stainless"), Xform(translation: V3(0.12, 0.08, 0.05)))
        bx(&m, V3(0.2, 0.03, 0.04), V3(0.12, 0.64, 0.05), "plastic.black", r: 0.008)
        bx(&m, V3(0.14, 0.02, 0.2), V3(0.12, 0.015, 0.05), "metal.galvanized", r: 0.004)
        return K.finish(&m, ao: 0.2)
    }
}
