import simd
import Foundation

/// Glass balcony: cast concrete slab with a drip groove, stainless base channel, five frameless
/// laminated glass panels on stainless standoffs and a round stainless handrail with end returns.
/// Wall plane at z = 0, y = 0 is the underside of the slab.
public struct GlassBalcony: RealAsset {
    public static let id = "glass-balcony"
    public static let summary = "Concrete balcony slab 2.4 m x 1.2 m with frameless glass balustrade on stainless standoffs and handrail."
    public static let tags = ["prop", "architecture", "facade", "concrete", "glass", "metal"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 40, elevation: 18, distance: 3.2)

    public var width: Float = 2.4
    public var depth: Float = 1.2
    public var slabThickness: Float = 0.16
    public var railHeight: Float = 1.05
    public var slab: MaterialKey = "concrete.smooth"
    public var glass: MaterialKey = "glass.clear"
    public var steel: MaterialKey = "metal.stainless"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, D = depth, T = slabThickness, RH = railHeight
        FA.box(&m, V3(W, T, D), V3(0, T / 2, D / 2), slab, r: 0.006)
        FA.box(&m, V3(W - 0.1, 0.012, 0.014), V3(0, 0.006, D - 0.06), "concrete.rough", r: 0.002)
        let gl: Float = 0.014, base: Float = T + 0.02
        func channel(from a: V3, to b: V3) {
            let d = b - a, len = simd_length(d), c = (a + b) / 2
            let yaw = atan2(d.x, d.z) * 180 / .pi
            FA.box(&m, V3(0.05, 0.05, len), c + V3(0, 0.025, 0), steel, r: 0.004, rot: FA.q(yaw, FA.Y))
        }
        let fx = W / 2 - 0.06, fz = D - 0.06
        channel(from: V3(-fx, T, fz), to: V3(fx, T, fz))
        channel(from: V3(-fx, T, 0.06), to: V3(-fx, T, fz))
        channel(from: V3(fx, T, 0.06), to: V3(fx, T, fz))
        // Front panels.
        let n = 3, pw = (2 * fx) / Float(n) - 0.012
        for i in 0..<n {
            let x = -fx + (Float(i) + 0.5) * (2 * fx / Float(n))
            FA.box(&m, V3(pw, RH - base + 0.01, gl), V3(x, base + (RH - base) / 2 - 0.02, fz), glass, r: 0.002)
            for e: Float in [-1, 1] { for yy in [base + 0.12, RH - 0.1] {
                FA.cylZ(&m, r: 0.011, h: 0.04, at: V3(x + e * (pw / 2 - 0.07), yy, fz - 0.014), steel, bevel: 0.002, segments: 14)
            }}
        }
        // Side panels.
        let sd = (fz - 0.06 - 0.06) / 2 - 0.006
        for e: Float in [-1, 1] { for i in 0..<2 {
            let z = 0.06 + (Float(i) + 0.5) * (fz - 0.06) / 2 + 0.03
            m.add(Prim.roundedBox(V3(sd, RH - base + 0.01, gl), radius: 0.002, bevelSegments: 1, material: glass),
                  Xform(translation: V3(e * fx, base + (RH - base) / 2 - 0.02, z), rotation: FA.q(90, FA.Y)))
        }}
        // Handrail with end returns to the wall.
        let ry = RH + 0.02
        FA.path(&m, [V3(-fx, ry, 0.05), V3(-fx, ry, fz - 0.03), V3(-fx + 0.03, ry, fz), V3(fx - 0.03, ry, fz), V3(fx, ry, fz - 0.03), V3(fx, ry, 0.05)], r: 0.022, steel, sides: 14)
        _ = rng.float()
        groundAO(&m, height: 0.1, floor: 0.7)
        return LODModel(FA.centerZ(m))
    }
}
