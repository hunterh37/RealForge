import simd
import Foundation

/// Eave bracket set: three curved timber brackets with turned pendants under a soffit board and
/// fascia. Brackets are cut from 70 mm stock, soffit and fascia are painted tongue-and-groove.
public struct EaveBracketSet: RealAsset {
    public static let id = "eave-bracket-set"
    public static let summary = "Eave bracket set, 2.4 m run: three curved timber brackets under a soffit board with drop pendants."
    public static let tags = ["prop", "architecture", "facade", "trim", "wood"]
    public static let budget = 9_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: -8, distance: 2.4)

    public var width: Float = 2.4
    public var projection: Float = 0.4
    public var drop: Float = 0.45
    public var paint: MaterialKey = "wood.painted-exterior"
    public var accent: MaterialKey = "wood.painted-shaker-worn:5B4636"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, P = projection, D = drop
        let top = D + 0.03
        // Soffit board (planks run along X) and fascia.
        for i in 0..<5 {
            let z = 0.04 + Float(i) * (P - 0.04) / 5 + (P - 0.04) / 10
            FA.box(&m, V3(W, 0.024, (P - 0.04) / 5 - 0.002), V3(0, top - 0.012, z), paint, r: 0.002)
        }
        FA.box(&m, V3(W, 0.14, 0.025), V3(0, top - 0.07 + 0.012, P - 0.0125), paint, r: 0.003)
        // Bracket profile in (out, up): curved quadrant with a scroll tip.
        var pts: [V2] = []
        let yTop = top - 0.024, yBot: Float = 0.0
        for k in 0...10 {
            let t = Float(k) / 10
            pts.append(V2(0.05 + (P - 0.08) * (1 - t) * (1 - t), yTop - (yTop - yBot) * t))
        }
        pts += [V2(0.0, yBot), V2(0.0, yTop)]
        let prof = Shape2D.rounded(Shape2D.deduped(pts), radius: 0.006)
        for x in [-W * 0.36, 0, W * 0.36] {
            FA.side(&m, prof, thick: 0.07, at: V3(x + rng.float(-0.002...0.002), 0, 0), paint)
            // Turned pendant below the bracket foot.
            m.add(Prim.lathe([V2(0.0, 0.0), V2(0.012, 0.02), V2(0.026, 0.055), V2(0.018, 0.085), V2(0.03, 0.12), V2(0.022, 0.15), V2(0.0, 0.16)],
                             segments: 16, material: accent), Xform(translation: V3(x, yTop - 0.17, P - 0.06)))
        }
        FA.box(&m, V3(W, 0.03, 0.02), V3(0, top - 0.02, 0.012), paint, r: 0.002)
        groundAO(&m, height: 0.08, floor: 0.85)
        return LODModel(FA.centerZ(m))
    }
}
