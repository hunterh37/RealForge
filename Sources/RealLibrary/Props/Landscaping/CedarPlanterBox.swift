import simd
import Foundation

/// Cedar planter box, 0.9 x 0.45 m and 0.45 m tall: four 2x2 corner posts on short feet, three courses
/// of 1x6 boards per side with small gaps, a mitred cap rail, potting soil 5 cm below the cap. Wood is
/// darker and greyer on the bottom course where it stays wet.
public struct CedarPlanterBox: RealAsset {
    public static let id = "cedar-planter-box"
    public static let summary = "Cedar planter box, 0.9 m: corner posts, horizontal board walls, cap rail, soil fill."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "wood", "container"]
    public static let budget = 7500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 25)

    /// Outer size (m).
    public var size = V3(0.9, 0.45, 0.45)
    /// Cedar material.
    public var cedar: MaterialKey = "wood.lumber-oak:A0663E"
    /// Bottom course material (wet, greyer).
    public var cedarWet: MaterialKey = "wood.lumber-oak:7A5640"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = size.x, D = size.z, H = size.y
        let post: Float = 0.045, bt: Float = 0.019, cap: Float = 0.022, feet: Float = 0.025
        let wallTop = H - cap
        let courses = 3
        let bh = (wallTop - feet) / Float(courses) - 0.004
        // Posts.
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(post, wallTop, post), radius: 0.004, bevelSegments: 2, material: cedarWet),
                  Xform(translation: V3(sx * (W / 2 - bt - post / 2), wallTop / 2, sz * (D / 2 - bt - post / 2))).jittered(&rng, deg: 0.2, offset: 0.0005))
        } }
        // Side boards, long sides along X and short sides along Z (rotated so grain runs along the board).
        for c in 0..<courses {
            let y = feet + (Float(c) + 0.5) * (bh + 0.004)
            let mat = c == 0 ? cedarWet : cedar
            for s: Float in [-1, 1] {
                m.add(plank(W - 0.004, bt, bh, bevel: 0.003, material: mat),
                      Xform(translation: V3(0, y, s * (D / 2 - bt / 2))).jittered(&rng, deg: 0.25, offset: 0.0008))
                m.add(plank(D - 2 * bt - 0.003, bt, bh, bevel: 0.003, material: mat),
                      Xform(translation: V3(s * (W / 2 - bt / 2), y, 0), rotation: simd_quatf(degrees: 90, axis: .up)).jittered(&rng, deg: 0.25, offset: 0.0008))
            }
        }
        // Cap rail: four boards, overhanging 12 mm.
        let o: Float = 0.012, cw: Float = 0.07
        for s: Float in [-1, 1] {
            m.add(plank(W + 2 * o, cw, cap, bevel: 0.004, material: cedar), Xform(translation: V3(0, H - cap / 2, s * (D / 2 + o - cw / 2))).jittered(&rng, deg: 0.15, offset: 0.0005))
            m.add(plank(D + 2 * o - 2 * cw - 0.004, cw, cap, bevel: 0.004, material: cedar),
                  Xform(translation: V3(s * (W / 2 + o - cw / 2), H - cap / 2, 0), rotation: simd_quatf(degrees: 90, axis: .up)).jittered(&rng, deg: 0.15, offset: 0.0005))
        }
        // Standoff feet under each corner.
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.06, feet, 0.06), radius: 0.003, bevelSegments: 1, material: cedarWet), Xform(translation: V3(sx * (W / 2 - 0.04), feet / 2, sz * (D / 2 - 0.04))))
        } }
        // Soil.
        var soil = Prim.roundedBox(V3(W - 2 * bt - 0.004, 0.02, D - 2 * bt - 0.004), radius: 0.006, bevelSegments: 1, material: "soil.potting")
        soil.displace { p, n in n.y > 0.5 ? 0.006 * sin(p.x * 40) * cos(p.z * 33) : 0 }
        m.add(soil, Xform(translation: V3(0, H - 0.05, 0)))
        groundAO(&m, height: 0.12)
        return LODModel(m)
    }
}
