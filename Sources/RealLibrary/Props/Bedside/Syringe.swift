import simd
import Foundation

/// Luer-lock syringe 10 ml: Single-use sterile syringe (BD 10 ml Luer-Lok class), new, crisp black print.. Parts: clear polypropylene barrel 16.5 mm OD with printed 0.2 ml graduations and numerals, oval finger flange, luer-lock collar with internal thread and luer tip, black rubber stopper with two sealing ribs and conical face, white cross-ribbed plunger rod with thumb press disc, saline fluid column (empty / 5 ml / 10 ml), white luer tip cap (option).
public struct Syringe: RealAsset {
    public static let id = "syringe"
    public static let summary = "10 ml luer-lock syringe: clear graduated barrel, finger flange, black rubber stopper, white ribbed plunger rod with thumb press, luer collar and cap."
    public static let tags = ["prop", "medical", "articulated", "handheld", "hospital", "plastic", "rubber"]
    public static let budget = 4500
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.112, 0.021, 0.034)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: plastic.clear plastic.medical rubber fluid.saline plastic.matte. Gate: realityhd gate syringe. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "plastic.clear"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
