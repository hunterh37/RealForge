import simd
import Foundation

/// Precast New Jersey barrier, 3.0 m long, 0.81 m tall, 0.61 m base, 0.15 m top: toe, 55 degree lower slope,
/// steep upper face, two drainage and forklift slots, steel connection loops at the ends, chipped arrises.
/// Origin at the center of the base; tile along X every `length`.
public struct JerseyBarrier: RealAsset {
    public static let id = "jersey-barrier"
    public static let summary = "Precast concrete New Jersey barrier, 3 m: safety-shape profile, forklift slots, end loops, chipped edges."
    public static let tags = ["structure", "construction", "road", "barrier", "concrete"]
    public static let budget = 4_500
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 28, elevation: 12)

    public var length: Float = 3.0
    public var material: MaterialKey = "concrete.rough"
    /// 0 = clean casting, 1 = heavily chipped arrises.
    public var wear: Float = 0.6
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let half: [V2] = [V2(0.305, 0), V2(0.305, 0.076), V2(0.127, 0.33), V2(0.075, 0.81)]
        let poly = [V2(-0.305, 0)] + half + half.reversed().map { V2(-$0.x, $0.y) }.dropLast()
        let profile = CFKit.bevel(Array(poly), 0.014)
        // Rings every 5 cm; slot edges get a doubled ring so the slot walls are vertical.
        let L = length / 2, slotC: Float = L * 0.5, slotW: Float = 0.26, slotH: Float = 0.065
        var xs: [Float] = [], lifted: [Bool] = []
        let edges = [-slotC - slotW / 2, -slotC + slotW / 2, slotC - slotW / 2, slotC + slotW / 2]
        var x = -L
        while x < L - 1e-4 {
            for e in edges where e > x && e < x + 0.05 {
                let inside = edges.firstIndex(of: e)! % 2 == 0
                xs.append(e); lifted.append(!inside)
                xs.append(e); lifted.append(inside)
            }
            x += 0.05
            if x < L - 0.01 { xs.append(x); lifted.append(abs(abs(x) - slotC) < slotW / 2) }
        }
        xs.insert(-L, at: 0); lifted.insert(false, at: 0); xs.append(L); lifted.append(false)
        let ns = UInt32(truncatingIfNeeded: seed)
        let center = V2(0, 0.35)
        var surf = CFKit.extrude(profile, xs: xs, material: material) { r, x, i, p in
            var q = p
            if lifted[r] && q.y < 0.03 { q.y = slotH }
            // Chips on the arrises (bevel points), strongest on the top edges and ends.
            if q.y > 0.04 {
                let endBoost: Float = abs(x) > L - 0.12 ? 1.6 : 1
                let n = Noise.fbm(V3(x * 7, Float(i) * 3.1, 0.5), octaves: 3, seed: ns)
                let chip = smoothstep(0.18, 0.4, n) * wear * endBoost * (q.y > 0.7 ? 1.4 : 0.8)
                q += simd_normalize(center - q) * chip * 0.018
            }
            return q
        }
        surf.bakeCavityAO(strength: 0.5, floor: 0.7)
        m.add(surf)
        // Connection loops of rebar at both ends.
        for sx: Float in [-1, 1] {
            for y: Float in [0.22, 0.62] {
                let zc: Float = y < 0.4 ? 0 : 0
                let pts: [V3] = [V3(sx * (L - 0.02), y - 0.05, zc), V3(sx * (L + 0.05), y - 0.04, zc), V3(sx * (L + 0.07), y, zc),
                                 V3(sx * (L + 0.05), y + 0.04, zc), V3(sx * (L - 0.02), y + 0.05, zc)]
                m.add(CFKit.pipe(pts, radius: 0.011, sides: 8, material: "metal.rust"), Xform().jittered(&rng, deg: 2, offset: 0.003))
            }
        }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
