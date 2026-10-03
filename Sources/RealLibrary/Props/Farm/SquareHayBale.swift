import simd
import Foundation

/// Small square bale, 0.9 x 0.46 x 0.36 m (36 x 18 x 14 in), about 25 kg: ten compressed flakes with
/// uneven edges, two polypropylene twine bands pressed into the straw.
public struct SquareHayBale: RealAsset {
    public static let id = "square-hay-bale"
    public static let summary = "Small square hay bale, 0.9 m: ten lumpy compressed flakes, two orange twine bands pressed in."
    public static let tags = ["prop", "farm"]
    public static let budget = 4_500
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 32, elevation: 18)

    /// Length, height and width in meters.
    public var size = V3(0.9, 0.36, 0.46)
    public var flakes = 10
    public var straw: MaterialKey = "straw.hay"
    public var twine: MaterialKey = "plastic.orange"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let s = V3(rng.vary(size.x, 0.06), rng.vary(size.y, 0.03), rng.vary(size.z, 0.03))
        let ns = UInt32(truncatingIfNeeded: seed)
        var m = Model(name: Self.id)
        let fw = s.x / Float(flakes)
        let bandX: [Float] = [-s.x * 0.24, s.x * 0.24]
        func pinch(_ wx: Float) -> Float { bandX.map { 1 - smoothstep(0.0, 0.035, abs(wx - $0)) }.max()! }
        for f in 0..<flakes {
            var fr = rng.fork(f)
            let cx = -s.x / 2 + fw * (Float(f) + 0.5)
            let off = V3(0, fr.float(-0.004...0.006), fr.float(-0.008...0.008))
            let fs = Float(f)
            var flake = CFKit.blob(half: V3(fw * 0.74, s.y / 2, s.z / 2), power: 7, subdivisions: 5, material: straw) { p in
                let n = Noise.fbm(V3(p.y * 9, p.z * 9, fs * 1.7), octaves: 3, seed: ns)
                return n * 0.012 - pinch(cx + p.x) * 0.008
            }
            // Turn the strand direction per flake so the sides read as loose, crossing stalks.
            let ua = fr.float(0...(2 * .pi)), cu = cos(ua), su = sin(ua)
            flake.uvs = flake.uvs.map { V2(cu * $0.x - su * $0.y, su * $0.x + cu * $0.y) }
            flake.computeTangents()
            flake.bakeCavityAO(strength: 0.4, floor: 0.7)
            let rot = simd_quatf(degrees: fr.float(-2...2), axis: V3(1, 0, 0)) * simd_quatf(degrees: fr.float(-2.5...2.5), axis: .up)
            m.add(flake, Xform(translation: V3(cx, s.y / 2, 0) + off, rotation: rot))
        }
        for bx in bandX {
            let pts = (0..<28).map { k -> V3 in
                let p = CFKit.superellipse(Float(k) / 28 * 2 * .pi, half: V2(s.z / 2 - 0.002, s.y / 2 - 0.002), power: 7)
                return V3(bx, s.y / 2 + p.y, p.x)
            }
            m.add(CFKit.loop(pts, radius: 0.003, sides: 5, material: twine))
        }
        groundAO(&m, height: 0.15, floor: 0.55)
        // LOD1: one block, no twine.
        var low = CFKit.blob(half: s / 2, power: 7, subdivisions: 6, material: straw)
        low.occlusion = low.positions.map { 0.55 + 0.45 * smoothstep(-s.y / 2, 0, $0.y) }
        let l1 = Model(name: Self.id, surfaces: [low.transformed(Xform(translation: V3(0, s.y / 2, 0)))])
        return LODModel(levels: [m, l1], switchDistances: [15])
    }
}
