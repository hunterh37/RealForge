import simd
import Foundation

public struct TrafficCone: RealAsset {
    public static let id = "traffic-cone"
    public static let summary = "71 cm traffic cone: orange PVC, two reflective white bands, black rubber base."
    public static let tags = ["prop", "urban", "road"]
    public static let budget = 4_000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let base: Float = 0.035, top: Float = 0.71, r0: Float = 0.15, r1: Float = 0.03
        func r(_ y: Float) -> Float { lerp(r0, r1, (y - base) / (top - base)) }
        let bands: [(Float, Float, MaterialKey)] = [(base, 0.38, "plastic.orange"), (0.38, 0.48, "plastic.white"), (0.48, 0.53, "plastic.orange"),
                                                    (0.53, 0.6, "plastic.white"), (0.6, top, "plastic.orange")]
        for (a, b, mat) in bands {
            var prof: [(Float, Float)] = [(r(a), a), (r(b), b)]
            if b == top { prof += [(r1 * 0.9, top + 0.004), (0, top + 0.004)] }
            m.add(turned(prof, segments: 40, material: mat, seamTile: 0.2))
        }
        // Square rubber base with rounded corners and a raised collar.
        m.add(Prim.roundedBox(V3(0.38, base, 0.38), radius: 0.015, bevelSegments: 3, material: "rubber"), Xform(translation: V3(0, base / 2, 0)))
        m.add(turned([(r0 + 0.02, base), (r0 + 0.012, base + 0.012), (r0 - 0.002, base + 0.014)], segments: 40, material: "rubber"))
        groundAO(&m, height: 0.12, floor: 0.55)
        return LODModel(m)
    }
}
