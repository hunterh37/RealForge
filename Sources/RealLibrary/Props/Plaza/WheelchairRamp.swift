import simd
import Foundation

/// Accessible ramp, 1:12 slope: 0.45 m rise over 5.4 m run, 1.5 m wide, concrete slab with edge curbs and twin steel handrails.
public struct WheelchairRamp: RealAsset {
    public static let id = "wheelchair-ramp"
    public static let summary = "Accessible ramp at 1:12, 0.45 m rise over 5.4 m: concrete slab, edge curbs, twin steel handrails each side."
    public static let tags = ["prop", "urban", "concrete", "metal"]
    public static let budget = 900
    public static let author = "hunterh37"

    /// Rise in meters. Run is twelve times the rise.
    public var rise: Float = 0.45
    /// Clear width between curbs in meters.
    public var width: Float = 1.5
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let run = rise * 12, w = width
        m.add(Prim.extrude([V2(0, 0), V2(run, 0), V2(run, rise), V2(0, 0.02)], depth: w, bevel: 0.006, material: "concrete.sidewalk"), Xform(translation: V3(0, 0, 0)))
        for s: Float in [-1, 1] {
            let z = s * (w / 2 + 0.05)
            m.add(Prim.extrude([V2(0, 0), V2(run, 0), V2(run, rise + 0.1), V2(0, 0.12)], depth: 0.1, bevel: 0.006, material: "concrete.rough"), Xform(translation: V3(0, 0, z)))
            for i in 0...6 {
                let x = Float(i) / 6 * (run - 0.1) + 0.05
                let y0 = 0.02 + (rise - 0.02) * x / run
                rod(&m, V3(x, y0 + 0.1, z), V3(x, y0 + 0.9, z), 0.022, "metal.galvanized", sides: 10)
            }
            for h: Float in [0.7, 0.9] {
                let y0 = 0.02 + (rise - 0.02) * 0.05 / run
                rod(&m, V3(0.05, y0 + h, z), V3(run - 0.05, rise + h, z), 0.021, "metal.galvanized", sides: 10)
            }
        }
        return K.finish(&m, ao: 0.2)
    }
}
