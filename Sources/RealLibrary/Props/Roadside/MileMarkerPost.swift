import simd
import Foundation

/// Highway mile marker: flat green post, retroreflective green panel with white border and numeral bars.
public struct MileMarkerPost: RealAsset {
    public static let id = "mile-marker-post"
    public static let summary = "Green fiberglass mile marker, 1.2 m tall with a 15 x 45 cm retroreflective green panel and white numerals bars, rounded top and flat post."
    public static let tags = ["prop", "road", "sign", "plastic", "outdoor"]
    public static let budget = 4500
    public static let author = "realityhd"

    /// Overall post height in meters.
    public var height: Float = 1.2
    /// Post and panel colour (fiberglass green).
    public var greenMaterial = "plastic.white:1F6B3A"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let w: Float = 0.15, hp: Float = 0.45, t: Float = 0.012
        // Flat post (fiberglass blade) rounded at the top.
        let blade = Shape2D.rounded([V2(-w / 2, 0), V2(w / 2, 0), V2(w / 2, height), V2(-w / 2, height)], radius: 0.03, segments: 6)
        m.add(Prim.extrude(blade, depth: t, bevel: 0.0025, bevelSegments: 2, material: greenMaterial), Xform())
        // White border and numeral bars proud of the face.
        let top = height - 0.06, bot = top - hp
        let fz = t / 2 + 0.0006
        let borderC = (top + bot) / 2
        for (sx, sy, ww, hh) in [(Float(0), top - 0.01, w - 0.026, Float(0.012)), (0, bot + 0.01, w - 0.026, 0.012), (-(w / 2 - 0.016), borderC, 0.012, hp - 0.02), (w / 2 - 0.016, borderC, 0.012, hp - 0.02)] {
            m.add(Prim.roundedBox(V3(ww, hh, 0.0012), radius: 0.0004, bevelSegments: 1, material: "plastic.white"), Xform(translation: V3(sx, sy, fz)))
        }
        // "MILE" bar and digits as simple blocks: two numerals stacked.
        m.add(Prim.roundedBox(V3(0.06, 0.016, 0.0012), radius: 0.0004, bevelSegments: 1, material: "plastic.white"), Xform(translation: V3(0, top - 0.055, fz)))
        // Two seven-segment numerals ("47") stacked in the panel's lower half.
        let segs: [[Bool]] = [[true, true, true, false, false, true, true], [true, false, false, true, true, true, true]]  // a b c d e f g order: see below
        _ = segs
        // Segment layout: a top, b upper right, c lower right, d bottom, e lower left, f upper left, g middle.
        let digits: [[Bool]] = [[false, true, true, false, true, true, true],   // 4
                                [true, true, true, false, false, false, false]]  // 7
        for (k, dig) in digits.enumerated() {
            let cx: Float = 0, cyd = top - 0.19 - Float(k) * 0.14
            let sw: Float = 0.014, sl: Float = 0.052
            let place: [(Float, Float, Float, Float)] = [(0, sl + sw / 2, sl, sw), (sl / 2 + sw / 2, sl / 2 + sw / 2, sw, sl), (sl / 2 + sw / 2, -(sl / 2 + sw / 2), sw, sl),
                                                          (0, -(sl + sw / 2), sl, sw), (-(sl / 2 + sw / 2), -(sl / 2 + sw / 2), sw, sl), (-(sl / 2 + sw / 2), sl / 2 + sw / 2, sw, sl), (0, 0, sl, sw)]
            for (i, on) in dig.enumerated() where on {
                let (px, py, pw, ph) = place[i]
                m.add(Prim.roundedBox(V3(pw > ph ? pw * 0.7 : 0.012, pw > ph ? 0.012 : ph * 0.7, 0.0012), radius: 0.0005, bevelSegments: 1, material: "plastic.white"), Xform(translation: V3(cx + px * 0.62, cyd + py * 0.62 + 0.0, fz)))
            }
        }
        // Mounting bolts.
        for (x, y) in [(Float(-0.05), top - 0.03), (0.05, top - 0.03), (-0.05, bot + 0.03), (0.05, bot + 0.03)] {
            m.add(Prim.cylinder(radius: 0.006, height: 0.004, bevel: 0.0012, segments: 8, material: "metal.galvanized"), Xform(translation: V3(x, y, fz + 0.0006), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        // Soil mound and dirt splash up the lower post.
        m.add(Prim.superellipsoid(V3(0.2, 0.06, 0.2), exponent: 3, subdivisions: 5, material: "soil.potting"), Xform(translation: V3(0, 0.02, 0)))
        for _ in 0..<3 {
            m.add(Prim.superellipsoid(V3(rng.float(0.05...0.1), 0.05, 0.002), exponent: 3, subdivisions: 4, material: "plastic.black"), Xform(translation: V3(rng.float(-0.03...0.03), rng.float(0.08...0.2), fz + 0.0004)))
        }
        groundAO(&m, height: 0.1, floor: 0.6)
        return LODModel(m)
    }
}
