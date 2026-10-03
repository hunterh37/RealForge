import simd
import Foundation

/// Front-load dumpster, 4 cubic yards: 1.83 m wide, 1.2 m tall, 1.35 m deep at the top with a sloped front,
/// pressed vertical ribs, side fork pockets, a rolled top rim, two black plastic lids (one may be ajar) and
/// rusty skids. Painted steel with chips and dirt.
public struct Dumpster: RealAsset {
    public static let id = "dumpster"
    public static let summary = "Front-load dumpster, 1.8 m: sloped painted steel body, ribs, fork pockets, plastic lids, rusty skids."
    public static let tags = ["prop", "construction", "urban", "metal", "container"]
    public static let budget = 7_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)

    public var width: Float = 1.83
    public var height: Float = 1.2
    public var color: UInt32 = 0x1E4A2C
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let paint = String(format: "metal.painted:%06X", color)
        let W = width / 2, H = height, skid: Float = 0.08
        let back: Float = -0.62, frontBot: Float = 0.38, frontTop: Float = 0.73
        // Side profile (z, y), counter-clockwise: bottom, sloped front, top, back.
        let prof = CFKit.bevel([V2(back, skid), V2(frontBot, skid), V2(frontBot + 0.04, skid + 0.25), V2(frontTop, H), V2(back, H)], 0.03)
        let xs = stride(from: -W, through: W, by: W / 6).map { $0 }
        m.add(CFKit.extrude(prof, xs: xs, material: paint))
        // Rolled rim around the top.
        let rimY = H + 0.012
        let rimPts: [V3] = [V3(-W - 0.012, rimY, back - 0.012), V3(W + 0.012, rimY, back - 0.012), V3(W + 0.012, rimY, frontTop + 0.012), V3(-W - 0.012, rimY, frontTop + 0.012)]
        var rim: [V3] = []
        for i in 0..<4 { let a = rimPts[i], b = rimPts[(i + 1) % 4]; for k in 0..<6 { rim.append(simd_mix(a, b, V3(repeating: Float(k) / 6))) } }
        m.add(CFKit.loop(rim, radius: 0.022, sides: 8, material: paint))
        // Pressed ribs on front and back.
        for k in 0..<4 {
            let x = -W + width * (Float(k) + 0.5) / 4
            m.add(Prim.roundedBox(V3(0.07, H - skid - 0.12, 0.035), radius: 0.012, bevelSegments: 1, material: paint),
                  Xform(translation: V3(x, (H + skid) / 2, back - 0.006)))
            let a = V3(x, skid + 0.3, frontBot + 0.055), b = V3(x, H - 0.06, frontTop - 0.006)
            let (s, xf) = board(from: a, to: b, width: 0.07, thick: 0.035, up: simd_normalize(V3(0, -(frontTop - frontBot - 0.04), H - skid - 0.25)), bevel: 0.012, material: paint)
            m.add(s, xf)
        }
        // Fork pockets: rectangular channels along Z on both sides.
        for sx: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.07, 0.16, 1.15), radius: 0.01, bevelSegments: 1, material: paint), Xform(translation: V3(sx * (W + 0.035), 0.72, 0.02)))
            m.add(Prim.roundedBox(V3(0.004, 0.11, 1.16), radius: 0.001, bevelSegments: 1, material: "metal.rust"), Xform(translation: V3(sx * (W + 0.071), 0.72, 0.02)))
        }
        // Skids.
        for z: Float in [back + 0.12, frontBot - 0.1] {
            m.add(Prim.roundedBox(V3(width - 0.05, skid, 0.1), radius: 0.008, bevelSegments: 1, material: "metal.rust"), Xform(translation: V3(0, skid / 2, z)).jittered(&rng, deg: 0.3))
        }
        // Lids: hinged at the back, slightly domed; seed props one open.
        let depth = frontTop - back + 0.04
        for (i, sx) in [Float(-1), 1].enumerated() {
            let open: Float = rng.chance(0.35) && i == 0 ? rng.float(8...25) : rng.float(0...1.5)
            var lid = CFKit.blob(half: V3(W / 2 - 0.02, 0.025, depth / 2), power: 8, subdivisions: 6, material: "plastic.black")
            lid.positions = lid.positions.map { V3($0.x, $0.y + 0.012 * (1 - pow($0.z / (depth / 2), 2)), $0.z) }
            lid.recomputeNormals(); lid.computeTangents()
            let hinge = V3(sx * W / 2, H + 0.03, back - 0.03)
            let rot = simd_quatf(degrees: -open, axis: V3(1, 0, 0))
            m.add(lid, Xform(translation: hinge + rot.act(V3(0, 0.0, depth / 2)), rotation: rot))
        }
        groundAO(&m, height: 0.3, floor: 0.55)
        return LODModel(m)
    }
}
