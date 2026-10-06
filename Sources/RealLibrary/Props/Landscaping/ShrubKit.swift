import simd
import Foundation

/// Builders shared by the landscaping plants: superellipsoid crowns, leaf-mass cores, bent leaf-spray
/// cards shaded with crown normals, woody stems, flower parts and a ground/depth occlusion pass.
enum ShrubKit {

    /// Crown volume: superellipsoid about `center` with `radii`, lumpy fBm surface, optional taper of
    /// the horizontal radius by height fraction (0 bottom, 1 top), flattened below `floorY`.
    struct Crown {
        var center: V3
        var radii: V3
        var exponent: Float = 2
        var lumps: Float = 0.08
        var lumpScale: Float = 3
        var seed: Float = 0
        var floorY: Float = 0.02
        var taper: (@Sendable (Float) -> Float)? = nil

        func local(_ dir: V3) -> V3 {
            let d = simd_normalize(dir), e = exponent
            let q = pow(pow(abs(d.x / radii.x), e) + pow(abs(d.y / radii.y), e) + pow(abs(d.z / radii.z), e), 1 / e)
            var p = d / max(q, 1e-5)
            if let taper {
                let k = taper(saturate((p.y + radii.y) / (2 * radii.y)))
                p.x *= k; p.z *= k
            }
            return p
        }

        /// Surface point toward `dir`, scaled by `depth` (1 = on the surface).
        func point(_ dir: V3, depth: Float = 1) -> V3 {
            let l = local(dir)
            let n = Noise.fbm(V3(l.x, l.y, l.z) * lumpScale + V3(seed, seed * 0.7, seed * 1.3), octaves: 3)
            var p = center + l * (1 + lumps * n) * depth
            if p.y < floorY { p.y = floorY + (p.y - floorY) * 0.12 }
            return p
        }

        /// Outward normal of the superellipsoid at a point.
        func normal(_ p: V3) -> V3 {
            let l = p - center, e = exponent
            func g(_ v: Float, _ r: Float) -> Float { (v < 0 ? -1 : 1) * pow(abs(v) / r, e - 1) / r }
            var n = V3(g(l.x, radii.x), g(l.y, radii.y), g(l.z, radii.z))
            if taper != nil { n.y *= 0.6 }
            let len = simd_length(n)
            return len > 1e-6 ? n / len : V3(0, 1, 0)
        }
    }

    /// Dense leaf-mass core just inside the crown so the cards never show daylight through the middle.
    static func core(_ c: Crown, depth: Float = 0.9, subdivisions: Int, material: MaterialKey) -> Surface {
        var s = Prim.cubeSphere(subdivisions: subdivisions, material: material) { dir in c.point(dir, depth: depth) }
        for i in s.positions.indices {
            let h = saturate((s.positions[i].y - c.floorY) / (2 * c.radii.y))
            s.occlusion[i] = 0.35 + 0.5 * h
            s.extra[i] = V2(0.08 * h, 0)
        }
        return s
    }

    /// Card placement: point, outward crown normal, depth fraction (0 deep ... 1 surface).
    typealias Spot = (p: V3, n: V3, depth: Float)

    static func crownSpot(_ c: Crown, rng: inout SeededRNG, depth: ClosedRange<Float>, minY: Float) -> Spot {
        var dir = rng.unitVector()
        if dir.y < minY { dir.y = minY + (minY - dir.y) * 0.3; dir = simd_normalize(dir) }
        let d = rng.float(depth)
        let p = c.point(dir, depth: d)
        return (p, c.normal(p), saturate((d - depth.lowerBound) / max(depth.upperBound - depth.lowerBound, 1e-4)))
    }

    /// One bent leaf-spray card: base half tilted toward `n`, tip half bent further out. Shading normal
    /// is the crown normal so the mass lights as a volume. UVs cover the whole card (atlas grid inside).
    static func card(_ s: inout Surface, spot: Spot, width w: Float, height h: Float, tilt: Float, bend: Float,
                     rng: inout SeededRNG, top: Float, windScale: Float = 1) {
        let n = spot.n
        var cn = simd_normalize(n + rng.unitVector() * tilt)
        if simd_dot(cn, n) < 0.2 { cn = simd_normalize(cn + n) }
        var up = V3(0, 1, 0) - cn * simd_dot(V3(0, 1, 0), cn)
        if simd_length(up) < 1e-3 { up = cn.anyPerpendicular }
        up = simd_normalize(up)
        let spin = rng.float(-1.3...1.3)
        let v = simd_quatf(angle: spin, axis: cn).act(up)
        let side = simd_normalize(simd_cross(v, cn))
        let vb = simd_normalize(v * cos(bend) + cn * sin(bend))
        var base = spot.p - v * (h * 0.45)
        if base.y < 0.004 { base.y = 0.004 }
        let mid = base + v * (h * 0.5), tip = mid + vb * (h * 0.5)
        let shade = simd_normalize(n * 0.8 + cn * 0.2)
        let occ = 0.42 + 0.58 * spot.depth
        let phase = rng.float(0...1)
        let rows: [(V3, Float, Float)] = [(base, 0, 0.7), (mid, 0.5, 0.88), (tip, 1, 1)]
        var idx: [[UInt32]] = []
        for (c, vv, o) in rows {
            let hy = saturate(c.y / max(top, 0.05))
            let wind = windScale * (0.15 + 0.85 * hy) * (0.4 + 0.6 * vv)
            var c0 = c - side * w / 2, c1 = c + side * w / 2
            c0.y = max(c0.y, 0.003); c1.y = max(c1.y, 0.003)
            let k0 = s.add(c0, shade, V2(0, vv), extra: V2(wind, phase))
            let k1 = s.add(c1, shade, V2(1, vv), extra: V2(wind, phase))
            let a = occ * o * (0.7 + 0.3 * hy)
            s.occlusion[Int(k0)] = a; s.occlusion[Int(k1)] = a
            idx.append([k0, k1])
        }
        s.quad(idx[0][0], idx[0][1], idx[1][1], idx[1][0])
        s.quad(idx[1][0], idx[1][1], idx[2][1], idx[2][0])
    }

    /// `count` cards over a crown.
    static func sprays(_ c: Crown, count: Int, size: ClosedRange<Float>, aspect: Float = 1, depth: ClosedRange<Float> = 0.86...1.02,
                       minY: Float = -0.6, tilt: Float = 0.7, bend: ClosedRange<Float> = 0.2...0.6,
                       rng: inout SeededRNG, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let top = c.center.y + c.radii.y
        for _ in 0..<count {
            let spot = crownSpot(c, rng: &rng, depth: depth, minY: minY)
            let sz = rng.float(size)
            card(&s, spot: spot, width: sz, height: sz * aspect, tilt: tilt, bend: rng.float(bend), rng: &rng, top: top)
        }
        return s
    }

    /// Woody stems from a root disc up into the crown interior.
    static func stems(count: Int, rootRadius: Float, crown c: Crown, reach: Float = 0.55, radius: ClosedRange<Float>,
                      sides: Int = 5, rng: inout SeededRNG, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        for _ in 0..<count {
            let a = rng.float(0...(2 * .pi)), r = rootRadius * sqrt(rng.float())
            let root = V3(cos(a) * r, 0.002, sin(a) * r)
            var dir = rng.unitVector(); dir.y = abs(dir.y) * 0.6 + 0.4; dir = simd_normalize(dir)
            let end = c.point(dir, depth: reach * rng.float(0.8...1.1))
            let mid = (root + end) * 0.5 + V3(rng.float(-0.03...0.03), 0, rng.float(-0.03...0.03))
            let pts = catmull([root, V3(root.x, 0.06, root.z) * 1.0 + (end - root) * 0.05, mid, end], per: 3)
            let r0 = rng.float(radius)
            let radii = pts.indices.map { r0 * (1 - 0.7 * Float($0) / Float(pts.count - 1)) }
            s.append(Prim.tube(pts, radii: radii, sides: sides, seamTile: 0.05, material: material, capEnd: true))
        }
        return s
    }

    /// Lumpy ball of florets (hydrangea mophead, flower clusters). Underside flattened toward `up`.
    static func floretBall(center: V3, radius: Float, up: V3, subdivisions: Int, seed: Float, material: MaterialKey) -> Surface {
        let u = simd_normalize(up)
        var s = Prim.cubeSphere(subdivisions: subdivisions, material: material) { dir in
            let k = simd_dot(dir, u)
            let flat: Float = k < -0.2 ? 0.55 + 0.45 * (1 + k) / 0.8 : 1
            let bump = 1 + 0.1 * Noise.fbm(dir * 4 + V3(seed, 0, 0), octaves: 2) + 0.09 * abs(Noise.fbm(dir * 11 + V3(0, seed, 0), octaves: 1))
            return center + dir * radius * bump * flat
        }
        for i in s.positions.indices {
            let k = simd_dot(simd_normalize(s.positions[i] - center), u)
            s.occlusion[i] = 0.55 + 0.45 * saturate(k + 0.6)
            s.extra[i] = V2(0.6, seed)
        }
        return s
    }

    /// Lathe flower (funnel, trumpet, cup) along `axis`, rim cut into `lobes` with a scalloped edge.
    /// `profile` is (radius, height) from the base.
    static func bloom(at base: V3, axis: V3, profile: [V2], lobes: Int, lobeDepth: Float, segments: Int, spin: Float,
                      weight: Float, material: MaterialKey) -> Surface {
        var s = Prim.lathe(profile, segments: segments, seamTile: 0.02, material: material)
        let hMax = profile.map(\.y).max() ?? 1
        s.deform { p in
            let t = saturate(p.y / max(hMax, 1e-4))
            let a = atan2(p.z, p.x)
            let lobe = 1 - lobeDepth * t * t * (1 - pow(abs(cos(a * Float(lobes) / 2)), 0.6))
            return V3(p.x * lobe, p.y - lobeDepth * 0.3 * t * t * (1 - lobe) * hMax, p.z * lobe)
        }
        s.recomputeNormals()
        let q = simd_quatf(from: V3(0, 1, 0), to: simd_normalize(axis)) * simd_quatf(angle: spin, axis: V3(0, 1, 0))
        var out = Surface(material: material)
        out.append(s, Xform(translation: base, rotation: q))
        for i in out.positions.indices { out.extra[i] = V2(weight, spin); out.occlusion[i] = 0.8 }
        return out
    }

    /// Flat-faced funnel flower: throat vertex sunk below the face, rim of `lobes` rounded petals cupped
    /// up by `cup * radius`. 3 rim vertices per lobe, one triangle fan.
    static func starFlower(_ s: inout Surface, center: V3, normal: V3, radius: Float, lobes: Int, cup: Float, throat: Float,
                           spin: Float, weight: Float, phase: Float) {
        let n = simd_normalize(normal)
        let e1 = simd_normalize(n.anyPerpendicular), e2 = simd_cross(n, e1)
        let c = s.add(center - n * throat, n, V2(0, 0), extra: V2(weight, phase))
        s.occlusion[Int(c)] = 0.55
        let rim = lobes * 3
        for k in 0..<rim {
            let a = Float(k) / Float(rim) * 2 * .pi + spin
            let local = Float(k % 3)          // 0 notch, 1 and 2 petal shoulders
            let r = radius * (local == 0 ? 0.62 : 1)
            let dir = e1 * cos(a) + e2 * sin(a)
            let p = center + dir * r + n * cup * radius * (r / radius)
            let i = s.add(p, simd_normalize(n * 0.8 + dir * 0.4), V2(cos(a) * r, sin(a) * r), extra: V2(weight, phase))
            s.occlusion[Int(i)] = 1
        }
        for k in 0..<UInt32(rim) { s.tri(c, c + 1 + k, c + 1 + (k + 1) % UInt32(rim)) }
    }

    /// Ground contact and depth occlusion: multiplies baked occlusion by a ground term (keeps card depth AO).
    static func finish(_ m: inout Model, height: Float, floor: Float) {
        for i in m.surfaces.indices {
            var s = m.surfaces[i]
            if s.occlusion.count != s.positions.count { s.occlusion = Array(repeating: 1, count: s.positions.count) }
            for k in s.positions.indices {
                s.occlusion[k] *= floor + (1 - floor) * smoothstep(0, height, s.positions[k].y)
            }
            m.surfaces[i] = s
        }
    }

    /// Scales and shifts to exactly `size` (X, Y, Z), centered on X/Z with the base at y = 0.
    static func fit(_ m: Model, size: V3) -> Model {
        let b = m.bounds, e = b.max - b.min
        let k = V3(size.x / max(e.x, 1e-4), size.y / max(e.y, 1e-4), size.z / max(e.z, 1e-4))
        var out = m
        for i in out.surfaces.indices {
            for v in out.surfaces[i].positions.indices {
                let p = out.surfaces[i].positions[v]
                out.surfaces[i].positions[v] = V3((p.x - (b.min.x + b.max.x) / 2) * k.x, (p.y - b.min.y) * k.y, (p.z - (b.min.z + b.max.z) / 2) * k.z)
            }
            if !out.surfaces[i].normals.isEmpty {
                out.surfaces[i].normals = out.surfaces[i].normals.map { simd_normalize($0 / k) }
            }
        }
        return out
    }

    /// Lays anything that dips below the ground (drooping blade tips) on it, so `fit` keeps the crown at y = 0.
    static func clampGround(_ m: inout Model, y: Float = 0.002) {
        for i in m.surfaces.indices {
            for v in m.surfaces[i].positions.indices where m.surfaces[i].positions[v].y < y {
                m.surfaces[i].positions[v].y = y
            }
        }
    }

    /// Recenters X/Z on the bounds center.
    static func centered(_ m: Model) -> Model {
        let b = m.bounds
        return m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, 0, -(b.min.z + b.max.z) / 2)))
    }
}
