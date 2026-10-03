import simd
import Foundation

public struct Barrel: RealAsset {
    public static let id = "barrel"
    public static let summary = "Oak barrel: bulged lathe body with stave grooves, two rusted iron hoop pairs, inset lid."
    public static let tags = ["prop", "wood", "container"]
    public static let budget = 10_000
    public var height: Float = 0.9
    public var radius: Float = 0.29
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let h = height, r = radius, staves = 18
        // Body: bulge profile, with staves as separate lathe slices (gap via slight per-stave inset).
        var prof: [(Float, Float)] = []
        for i in 0...16 {
            let t = Float(i) / 16, bulge = sin(t * .pi) * 0.12
            prof.append((r * (0.88 + bulge), t * h))
        }
        var body = turned(prof, segments: staves * 4, material: "wood.oak", seamTile: 0.5, grainVertical: true)
        // Stave grooves: pull every 4th ring vertex column inward a little.
        for i in body.positions.indices {
            let p = body.positions[i]
            let a = atan2(-p.z, p.x), k = (a / (2 * .pi) * Float(staves)).truncatingRemainder(dividingBy: 1)
            let groove = 1 - 0.012 * smoothstep(0.08, 0, min(abs(k), abs(1 - abs(k))))
            body.positions[i] = V3(p.x * groove, p.y, p.z * groove)
        }
        body.recomputeNormals(); body.computeTangents()
        m.add(body)
        // Hoops.
        for y in [0.08, 0.25, 0.75, 0.92] as [Float] {
            let rr = r * (0.88 + sin(y * .pi) * 0.12) + 0.004
            m.add(turned([(rr - 0.002, y * h - 0.02), (rr + 0.003, y * h - 0.018), (rr + 0.003, y * h + 0.018), (rr - 0.002, y * h + 0.02)],
                         segments: 64, material: "metal.rust", seamTile: 0.3))
        }
        // Lid recessed 2 cm, with chime ring.
        m.add(turned([(0, h - 0.02), (r * 0.86, h - 0.02), (r * 0.88, h - 0.005), (r * 0.9, h)], segments: 48, material: "wood.oak", seamTile: 0.5))
        groundAO(&m, height: 0.2, floor: 0.55)
        return LODModel(m)
    }
}
