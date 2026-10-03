import simd
import Foundation

/// Shared builders for ground assets: an eroded noise field and an irregular disc mesh whose rim
/// sinks below y = 0 so it blends into whatever ground it is placed on.
enum GroundMesh {
    /// fBm whose octaves fade where the accumulated slope is steep (Quilez-style "eroded" noise):
    /// smooth flanks, detail kept in flats and valleys. Roughly -1...1.
    static func eroded(_ p: V2, octaves: Int, seed: UInt32, gain: Float = 0.5) -> Float {
        var sum: Float = 0, amp: Float = 0.5, q = p
        var d = V2.zero
        let e: Float = 0.01
        for o in 0..<octaves {
            let s = seed &+ UInt32(o) &* 31
            let n = Noise.perlin(V3(q.x, 0, q.y), seed: s)
            let nx = Noise.perlin(V3(q.x + e, 0, q.y), seed: s), nz = Noise.perlin(V3(q.x, 0, q.y + e), seed: s)
            d += V2(nx - n, nz - n) / e * amp
            sum += amp * n / (1 + simd_dot(d, d) * 0.6)
            q = V2(q.x * 1.6 - q.y * 1.2, q.x * 1.2 + q.y * 1.6)   // rotate + scale x2
            amp *= gain
        }
        return sum * 1.6
    }

    /// Irregular disc: center vertex plus `rings` x `sectors` polar grid. `outline(angle)` gives the rim
    /// radius in meters, `height(p, t)` the surface height at p with t = 0 center ... 1 rim.
    /// UVs are meters (x, -z), matching `Prim.terrain`.
    static func disc(material: MaterialKey, rings: Int, sectors: Int, outline: (Float) -> Float,
                     height: (V2, Float) -> Float) -> Surface {
        var s = Surface(material: material)
        s.add(V3(0, height(.zero, 0), 0), .up, .zero)
        for r in 1...rings {
            let t = Float(r) / Float(rings)
            for k in 0..<sectors {
                let a = Float(k) / Float(sectors) * 2 * .pi
                let p = V2(cos(a), sin(a)) * outline(a) * t
                s.add(V3(p.x, height(p, t), p.y), .up, V2(p.x, -p.y))
            }
        }
        let n = UInt32(sectors)
        for k in 0..<n { s.tri(0, 1 + (k + 1) % n, 1 + k) }
        for r in 0..<UInt32(rings - 1) {
            let a0 = 1 + r * n, b0 = 1 + (r + 1) * n
            for k in 0..<n {
                let k1 = (k + 1) % n
                s.quad(a0 + k, a0 + k1, b0 + k1, b0 + k)
            }
        }
        s.recomputeNormals(weldSeams: false)
        s.computeTangents()
        return s
    }

    /// Hollow occlusion for a square grid surface (vertex order as `Prim.terrain`): vertices below the
    /// average of their neighbors `radius` cells away darken, scaled by `relief` meters.
    static func shadeHollows(_ s: inout Surface, gridSide n: Int, radius r: Int, relief: Float, strength: Float) {
        guard s.positions.count == n * n else { return }
        let y = s.positions.map(\.y)
        func h(_ i: Int, _ j: Int) -> Float { y[min(max(j, 0), n - 1) * n + min(max(i, 0), n - 1)] }
        for j in 0..<n { for i in 0..<n {
            var acc: Float = 0
            for (di, dj) in [(r, 0), (-r, 0), (0, r), (0, -r), (r, r), (-r, -r), (r, -r), (-r, r)] { acc += h(i + di, j + dj) }
            let depth = max(0, acc / 8 - h(i, j))
            s.occlusion[j * n + i] *= saturate(1 - depth / max(relief, 0.01) * 2.5 * strength)
        }}
    }

    /// Rim falloff for discs: 1 inside, easing to 0 at t = 1, so heights can sink below the ground.
    static func rim(_ t: Float, from: Float = 0.7) -> Float { 1 - smoothstep(from, 1, t) }

    /// Wobbly outline radius for disc builders.
    static func outline(_ a: Float, radius: Float, wobble: Float, seed: UInt32) -> Float {
        let c = V3(cos(a), sin(a), 0) * 1.3
        return radius * (1 + wobble * Noise.fbm(c + V3(0, 0, Float(seed % 97)), octaves: 3, seed: seed))
    }
}
