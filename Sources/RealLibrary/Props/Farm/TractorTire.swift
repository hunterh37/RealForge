import simd
import Foundation

/// Rear tractor tire, 18.4-38 size: 1.75 m outside diameter, 0.47 m section, 0.97 m bead. Chevron lugs on the
/// crown, bulged sidewalls. Lies flat by default (feeder or silage weight); `upright` stands it on its tread.
public struct TractorTire: RealAsset {
    public static let id = "tractor-tire"
    public static let summary = "Rear tractor tire, 1.75 m: bulged sidewalls, chevron tread lugs, worn rubber; flat or upright."
    public static let tags = ["prop", "farm", "rubber", "vehicle"]
    public static let budget = 9_500
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 30)

    public var outerRadius: Float = 0.875
    public var beadRadius: Float = 0.485
    public var section: Float = 0.47
    public var lugsPerSide = 22
    public var upright = false
    public var material: MaterialKey = "rubber.tire"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let R = outerRadius, B = beadRadius, W = section
        let crown = R - 0.04
        // Closed cross-section, counter-clockwise in (r, y): bottom sidewall out, crown up, top sidewall in, bead down.
        let prof: [V2] = [
            V2(B, 0.075), V2(B + 0.02, 0.035), V2(B + 0.08, 0.02), V2(0.62, 0.008), V2(0.72, 0.0), V2(0.79, 0.012), V2(crown - 0.01, 0.045),
            V2(crown, 0.09), V2(crown + 0.004, W * 0.5), V2(crown, W - 0.09), V2(crown - 0.01, W - 0.045), V2(0.79, W - 0.012),
            V2(0.72, W), V2(0.62, W - 0.008), V2(B + 0.08, W - 0.02), V2(B + 0.02, W - 0.035), V2(B, W - 0.075), V2(B - 0.004, W * 0.5), V2(B, 0.075),
        ]
        func level(_ seg: Int, lugs: Bool, bevel: Int) -> Model {
            var m = Model(name: Self.id)
            m.add(Prim.lathe(prof, segments: seg, seamTile: 0.5, material: material))
            if lugs {
                let n = lugsPerSide
                for side in 0..<2 {
                    for i in 0..<n {
                        let a = (Float(i) + (side == 0 ? 0 : 0.5)) / Float(n) * 2 * .pi
                        let dir = V3(cos(a), 0, -sin(a))
                        let yc: Float = side == 0 ? W * 0.3 : W * 0.7
                        let lug = Prim.roundedBox(V3(0.08, 0.32, 0.075), radius: 0.018, bevelSegments: bevel, material: material)
                        // Lug local: x radial, y along the chevron, z around. Tilt 45 degrees in the tread plane.
                        let tilt = simd_quatf(degrees: side == 0 ? 42 : -42, axis: V3(1, 0, 0))
                        let face = simd_quatf(from: V3(1, 0, 0), to: dir)
                        let pos = dir * (crown + 0.018) + V3(0, yc, 0)
                        m.add(lug, Xform(translation: pos, rotation: face * tilt).jittered(&rng, deg: 0.5, offset: 0.001))
                    }
                }
            }
            if upright {
                m = m.transformed(Xform(translation: V3(0, R, -W / 2), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
            groundAO(&m, height: 0.2, floor: 0.6)
            return m
        }
        return LODModel(levels: [level(64, lugs: true, bevel: 1), level(32, lugs: false, bevel: 1)], switchDistances: [15])
    }
}
