import simd

/// CPU gradient noise for geometry displacement (rocks, terrain, bark flare, branch wobble).
/// Texture-space noise runs on the GPU in RealMaterials; this is the low-frequency counterpart.
public enum Noise {
    @inlinable static func hash(_ x: Int32, _ y: Int32, _ z: Int32, _ seed: UInt32) -> UInt32 {
        var h = UInt32(bitPattern: x) &* 0x8DA6B343 ^ UInt32(bitPattern: y) &* 0xD8163841 ^ UInt32(bitPattern: z) &* 0xCB1AB31F ^ seed &* 0x165667B1
        h ^= h >> 15; h = h &* 0x2C1B3C6D; h ^= h >> 12; h = h &* 0x297A2D39; h ^= h >> 15
        return h
    }

    /// 12 edge gradients of a cube as (axis a, axis b, sign a, sign b): grad = sa * d[a] + sb * d[b].
    /// Table lookup instead of a 12-way switch (the branch mispredicts on hashed input).
    @usableFromInline static let gradTable: [(UInt8, UInt8, Float, Float)] = [
        (0, 1, 1, 1), (0, 1, -1, 1), (0, 1, 1, -1), (0, 1, -1, -1),
        (0, 2, 1, 1), (0, 2, -1, 1), (0, 2, 1, -1), (0, 2, -1, -1),
        (1, 2, 1, 1), (1, 2, -1, 1), (1, 2, 1, -1), (1, 2, -1, -1),
    ]

    @inlinable static func grad(_ h: UInt32, _ d: V3) -> Float {
        let g = gradTable[Int(h % 12)]
        return g.2 * d[Int(g.0)] + g.3 * d[Int(g.1)]
    }

    /// Perlin gradient noise in roughly [-1, 1].
    public static func perlin(_ p: V3, seed: UInt32 = 0) -> Float {
        let f = p.rounded(.down), i = SIMD3<Int32>(Int32(f.x), Int32(f.y), Int32(f.z)), d = p - f
        let u = d * d * d * (d * (d * 6 - 15) + 10)
        func g(_ ox: Int32, _ oy: Int32, _ oz: Int32) -> Float {
            grad(hash(i.x + ox, i.y + oy, i.z + oz, seed), d - V3(Float(ox), Float(oy), Float(oz)))
        }
        let x00 = lerp(g(0, 0, 0), g(1, 0, 0), u.x), x10 = lerp(g(0, 1, 0), g(1, 1, 0), u.x)
        let x01 = lerp(g(0, 0, 1), g(1, 0, 1), u.x), x11 = lerp(g(0, 1, 1), g(1, 1, 1), u.x)
        return lerp(lerp(x00, x10, u.y), lerp(x01, x11, u.y), u.z)
    }

    public static func fbm(_ p: V3, octaves: Int = 4, lacunarity: Float = 2.03, gain: Float = 0.5, seed: UInt32 = 0) -> Float {
        var sum: Float = 0, amp: Float = 0.5, q = p
        for o in 0..<octaves { sum += amp * perlin(q, seed: seed &+ UInt32(o)); q *= lacunarity; amp *= gain }
        return sum
    }

    /// Ridged multifractal: sharp crests, good for rock ridges and erosion.
    public static func ridged(_ p: V3, octaves: Int = 4, seed: UInt32 = 0) -> Float {
        var sum: Float = 0, amp: Float = 0.5, q = p, weight: Float = 1
        for o in 0..<octaves {
            var n = 1 - abs(perlin(q, seed: seed &+ UInt32(o)))
            n *= n * weight
            weight = saturate(n * 2)
            sum += n * amp; q *= 2.1; amp *= 0.5
        }
        return sum
    }

    /// Worley F1 distance (cellular), for faceted stone.
    public static func worley(_ p: V3, seed: UInt32 = 0) -> (f1: Float, f2: Float) {
        let fl = p.rounded(.down), c = SIMD3<Int32>(Int32(fl.x), Int32(fl.y), Int32(fl.z))
        var f1: Float = 9, f2: Float = 9
        for z in -1...1 { for y in -1...1 { for x in -1...1 {
            let cell = c &+ SIMD3<Int32>(Int32(x), Int32(y), Int32(z))
            let h = hash(cell.x, cell.y, cell.z, seed)
            let j = V3(Float(h & 1023), Float((h >> 10) & 1023), Float((h >> 20) & 1023)) / 1023
            let d = simd_length_squared(V3(cell) + j - p)
            if d < f1 { f2 = f1; f1 = d } else if d < f2 { f2 = d }
        }}}
        return (f1.squareRoot(), f2.squareRoot())
    }
}
