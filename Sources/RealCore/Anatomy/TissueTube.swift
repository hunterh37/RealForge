import simd

/// A soft-tissue strand: a smooth path through control points with an elliptical, tapering cross
/// section. Muscles, tendons, vessels, nerves and the skin envelope are all strands, rebuilt every
/// frame from the tracked bone frames.
public struct Strand {
    public var material: MaterialKey
    public var points: [V3]
    /// Direction of the section's first (rx) axis at each control point; nil = parallel transport.
    public var sideHints: [V3]?
    /// Section radii (rx along the side axis, ry across) at normalized arc length s in 0...1.
    public var profile: (Float) -> V2
    public var sides: Int
    public var samples: Int
    /// Meander amplitude (meters) and wavelength (meters) for tortuous vessels; 0 = straight.
    public var meander: Float = 0
    public var meanderWave: Float = 0.012
    /// Valve bulges: relative radius increase and spacing (meters).
    public var bulge: Float = 0
    public var bulgeSpacing: Float = 0.012
    public var seed: UInt32 = 0
    public var capStart = true, capEnd = true

    public init(_ material: MaterialKey, _ points: [V3], sideHints: [V3]? = nil, sides: Int = 10, samples: Int = 20, profile: @escaping (Float) -> V2) {
        self.material = material; self.points = points; self.sideHints = sideHints; self.sides = sides; self.samples = samples; self.profile = profile
    }

    /// Fusiform muscle belly: tendon radius at both ends, bulging between `a` and `b`.
    public static func belly(_ rx: Float, _ ry: Float, tendon: Float = 0.0008, a: Float = 0.05, b: Float = 0.9, power: Float = 0.75) -> (Float) -> V2 {
        { s in
            let u = saturate((s - a) / max(1e-4, b - a))
            let k = pow(max(0, sin(u * .pi)), power)
            return V2(tendon + (rx - tendon) * k, tendon + (ry - tendon) * k)
        }
    }

    public static func constant(_ rx: Float, _ ry: Float? = nil) -> (Float) -> V2 { { _ in V2(rx, ry ?? rx) } }

    /// Linear radii through stations (s, rx, ry).
    public static func stations(_ st: [(Float, Float, Float)]) -> (Float) -> V2 {
        { s in
            guard let first = st.first else { return V2(0.001, 0.001) }
            if s <= first.0 { return V2(first.1, first.2) }
            for i in 1..<st.count where s <= st[i].0 {
                let a = st[i - 1], b = st[i]
                let t = smoothstep(0, 1, (s - a.0) / max(1e-5, b.0 - a.0))
                return V2(lerp(a.1, b.1, t), lerp(a.2, b.2, t))
            }
            let l = st[st.count - 1]; return V2(l.1, l.2)
        }
    }
}

enum Spline {
    /// Centripetal Catmull-Rom through `p`, `n` samples, roughly uniform in arc length.
    static func sample(_ p: [V3], _ n: Int) -> (points: [V3], params: [Float]) {
        guard p.count > 1 else { return (p, p.map { _ in 0 }) }
        if p.count == 2 { return ((0..<n).map { lerp(p[0], p[1], Float($0) / Float(n - 1)) }, (0..<n).map { Float($0) / Float(n - 1) }) }
        let ext = [p[0] * 2 - p[1]] + p + [p[p.count - 1] * 2 - p[p.count - 2]]
        let segLen = (0..<(p.count - 1)).map { max(1e-6, simd_distance(p[$0], p[$0 + 1])) }
        let total = segLen.reduce(0, +)
        var out: [V3] = [], params: [Float] = []
        out.reserveCapacity(n); params.reserveCapacity(n)
        for k in 0..<n {
            var dist = Float(k) / Float(n - 1) * total
            var i = 0
            while i < segLen.count - 1 && dist > segLen[i] { dist -= segLen[i]; i += 1 }
            let t = min(1, dist / segLen[i])
            let p0 = ext[i], p1 = ext[i + 1], p2 = ext[i + 2], p3 = ext[i + 3]
            func tj(_ ti: Float, _ a: V3, _ b: V3) -> Float { ti + max(1e-4, sqrt(simd_distance(a, b))) }
            let t0: Float = 0, t1 = tj(t0, p0, p1), t2 = tj(t1, p1, p2), t3 = tj(t2, p2, p3)
            let tt = lerp(t1, t2, t)
            let a1 = p0 * ((t1 - tt) / (t1 - t0)) + p1 * ((tt - t0) / (t1 - t0))
            let a2 = p1 * ((t2 - tt) / (t2 - t1)) + p2 * ((tt - t1) / (t2 - t1))
            let a3 = p2 * ((t3 - tt) / (t3 - t2)) + p3 * ((tt - t2) / (t3 - t2))
            let b1 = a1 * ((t2 - tt) / (t2 - t0)) + a2 * ((tt - t0) / (t2 - t0))
            let b2 = a2 * ((t3 - tt) / (t3 - t1)) + a3 * ((tt - t1) / (t3 - t1))
            out.append(b1 * ((t2 - tt) / (t2 - t1)) + b2 * ((tt - t1) / (t2 - t1)))
            params.append(Float(i) + t)
        }
        return (out, params)
    }
}

public extension Surface {
    /// Appends a strand with analytic normals and tangents (no recompute pass; cheap enough per frame).
    mutating func append(strand st: Strand, scale: Float = 1) {
        let n = max(2, st.samples)
        let (path0, params) = Spline.sample(st.points, n)
        guard path0.count >= 2 else { return }
        // Tangents and arc length.
        var tan = [V3](repeating: .zero, count: n)
        var arc = [Float](repeating: 0, count: n)
        for i in 0..<n {
            tan[i] = (path0[min(n - 1, i + 1)] - path0[max(0, i - 1)]).normalized
            if i > 0 { arc[i] = arc[i - 1] + simd_distance(path0[i], path0[i - 1]) }
        }
        let total = max(1e-5, arc[n - 1])
        // Section frames: side hint (interpolated between control points) or parallel transport.
        var side = [V3](repeating: .zero, count: n)
        var prev = tan[0].anyPerpendicular
        for i in 0..<n {
            var h: V3
            if let hints = st.sideHints, hints.count == st.points.count {
                let f = params[i], i0 = min(hints.count - 1, Int(f)), i1 = min(hints.count - 1, i0 + 1)
                h = lerp(hints[i0], hints[i1], f - Float(i0))
            } else if i > 0 {
                let t0 = tan[i - 1], t1 = tan[i]
                let ax = simd_cross(t0, t1), sl = simd_length(ax)
                h = sl > 1e-6 ? simd_quatf(angle: atan2(sl, simd_dot(t0, t1)), axis: ax / sl).act(prev) : prev
            } else { h = prev }
            h -= tan[i] * simd_dot(h, tan[i])
            if simd_length_squared(h) < 1e-10 { h = prev - tan[i] * simd_dot(prev, tan[i]) }
            side[i] = h.normalized; prev = side[i]
        }
        // Meander: smooth lateral wandering for vessels.
        var path = path0
        if st.meander > 0 {
            for i in 0..<n {
                let k = arc[i] / st.meanderWave
                let a = Noise.perlin(V3(k, 0.37, Float(st.seed) * 0.13), seed: st.seed) * 2
                let b = Noise.perlin(V3(k * 0.7, 5.1, Float(st.seed) * 0.29), seed: st.seed &+ 9) * 2
                let fade = smoothstep(0, 0.08, arc[i] / total) * smoothstep(0, 0.08, 1 - arc[i] / total)
                path[i] += (side[i] * a + simd_cross(tan[i], side[i]) * b * 0.4) * st.meander * scale * fade
            }
        }
        let sides = st.sides, row = UInt32(sides + 1)
        let base = UInt32(positions.count)
        let r0 = st.profile(0) * scale
        let perim = Float.pi * (r0.x + r0.y)
        for i in 0..<n {
            let s = arc[i] / total
            var r = st.profile(s) * scale
            if st.bulge > 0 {
                let ph = arc[i] / st.bulgeSpacing
                let b = pow(max(0, cos((ph - ph.rounded()) * .pi * 2)), 16)
                r *= 1 + st.bulge * b
            }
            let N = side[i], B = simd_cross(tan[i], N)
            for k in 0...sides {
                let a = Float(k) / Float(sides) * 2 * .pi
                let c = cos(a), sn = sin(a)
                let p = path[i] + N * (r.x * c) + B * (r.y * sn)
                let nrm = (N * (c / max(r.x, 1e-6)) + B * (sn / max(r.y, 1e-6))).normalized
                let t = (N * (-r.x * sn) + B * (r.y * c)).normalized
                positions.append(p); normals.append(nrm); uvs.append(V2(Float(k) / Float(sides) * perim, arc[i]))
                extra.append(.zero); occlusion.append(1); tangents.append(V4(t, 1))
            }
        }
        for i in 0..<UInt32(n - 1) { for k in 0..<UInt32(sides) {
            let a = base + i * row + k
            indices += [a, a + 1, a + row + 1, a, a + row + 1, a + row]
        }}
        func cap(_ i: Int, _ dir: Float) {
            let r = st.profile(i == 0 ? 0 : 1) * scale
            let tip = path[i] + tan[i] * (dir * min(r.x, r.y) * 0.6)
            let c = UInt32(positions.count)
            positions.append(tip); normals.append(tan[i] * dir); uvs.append(V2(perim / 2, arc[i] + dir * r.x))
            extra.append(.zero); occlusion.append(1); tangents.append(V4(side[i], 1))
            let ring = base + UInt32(i) * row
            for k in 0..<UInt32(sides) {
                if dir > 0 { indices += [ring + k, ring + k + 1, c] } else { indices += [ring + k + 1, ring + k, c] }
            }
        }
        if st.capStart { cap(0, -1) }
        if st.capEnd { cap(n - 1, 1) }
    }
}
