import simd
import Foundation

/// Shared rock geometry. A cube-sphere is ray-cast from the center: the radius along each direction is a
/// smooth minimum of a domain-warped, ridged ellipsoid and a set of fracture planes. The smooth minimum
/// leaves a small bevel on every fracture edge; planes cut close to the surface read as chips.
/// Optional horizontal strata recess soft beds, and the base is flattened and sunk into the ground.
public struct RockShape: Sendable {
    /// Full extents in meters (x, y, z) before seed variation.
    public var size: V3 = V3(1.6, 1.0, 1.3)
    /// Low-frequency shape noise (fraction of radius).
    public var lumps: Float = 0.22
    /// Domain warp of the shape noise (0 = plain fBm).
    public var warp: Float = 0.45
    /// Ridged erosion relief (fraction of radius): sharp crests, rounded hollows.
    public var erosion: Float = 0.1
    /// Fine surface relief (fraction of radius).
    public var detail: Float = 0.025
    /// Large fracture planes and their distance as a fraction of the ellipsoid radius.
    public var facets = 8
    public var facetDepth: ClosedRange<Float> = 0.62...0.86
    /// Small fracture planes near the surface.
    public var chips = 10
    /// Fracture planes stand vertical (broken outline of slabs and flat stones).
    public var verticalFacets = false
    /// Bevel width in meters at fracture edges.
    public var bevel: Float = 0.035
    /// Strata ledge depth in meters (0 = massive rock) and mean bed thickness.
    public var strata: Float = 0
    public var bedHeight: Float = 0.22
    /// Vertical erosion gullies on the sides (fraction of radius), for buttes and cliffs.
    public var gullies: Float = 0
    /// Superellipse exponent for the ellipsoid (2 = ellipsoid, 3...4 = boxy blocks).
    public var squareness: Float = 2
    /// Fraction of the height buried below y = 0.
    public var sink: Float = 0.15
    /// Bottom flattening: fraction of the half-height below center that is pressed flat.
    public var flatBase: Float = 0.55
    /// Upper surface flattening for slabs and stepping stones (0 = none, 1 = flat top at the cut).
    public var flatTop: Float = 0
    public init() {}

    public func with(_ edit: (inout RockShape) -> Void) -> RockShape { var c = self; edit(&c); return c }

    /// One rock at the given cube-sphere subdivisions per LOD, sharing the same shape.
    /// Positions are grounded: center on X/Z, base at -sink * height.
    public func surfaces(seed: UInt64, material: MaterialKey, detail lods: [Int]) -> [Surface] {
        var rng = SeededRNG(seed: seed)
        let e = V3(rng.vary(size.x, 0.18), rng.vary(size.y, 0.2), rng.vary(size.z, 0.18)) / 2
        let ns = UInt32(truncatingIfNeeded: seed &* 0x9E37_79B9)
        let o1 = rng.unitVector() * 17, o2 = rng.unitVector() * 23, o3 = rng.unitVector() * 31
        func ell(_ d: V3) -> Float {
            let q = simd_abs(d / e), p = squareness
            let s = powf(q.x, p) + powf(q.y, p) + powf(q.z, p)
            return powf(max(s, 1e-9), -1 / p)
        }
        var planes: [(V3, Float)] = []
        for _ in 0..<facets {
            var n = rng.unitVector(); n.y *= verticalFacets ? 0.05 : 0.7
            n = simd_normalize(n)
            planes.append((n, ell(n) * rng.float(facetDepth)))
        }
        for _ in 0..<chips {
            var n = rng.unitVector(); n.y = verticalFacets ? n.y * 0.05 : abs(n.y) * 0.6 - 0.1
            n = simd_normalize(n)
            planes.append((n, ell(n) * rng.float(0.86...0.95)))
        }
        let topCut = flatTop > 0 ? e.y * rng.float(0.35...0.55) : 0
        let bed = bedHeight, bedPhase = rng.float(0...1)
        func smin(_ a: Float, _ b: Float, _ k: Float) -> Float {
            let h = max(k - abs(a - b), 0) / k
            return min(a, b) - h * h * k * 0.25
        }
        func radius(_ d: V3) -> Float {
            let wv = V3(Noise.fbm(d * 1.1 + o1, octaves: 3, seed: ns), Noise.fbm(d * 1.1 + o2, octaves: 3, seed: ns &+ 1),
                        Noise.fbm(d * 1.1 + o3, octaves: 3, seed: ns &+ 2))
            let dw = simd_normalize(d + wv * warp)
            var r = ell(d)
            let big = Noise.fbm(dw * 1.4, octaves: 3, seed: ns &+ 3)
            let ridge = Noise.ridged(dw * 2.6, octaves: 4, seed: ns &+ 4) - 0.35
            let fine = Noise.fbm(dw * 7, octaves: 3, seed: ns &+ 5)
            // Flat-topped shapes keep the upper hemisphere smooth so the cut stays planar.
            let calm: Float = flatTop > 0 ? 1 - flatTop * smoothstep(-0.05, 0.25, d.y) * 0.85 : 1
            r *= 1 + (big * lumps * 2 + ridge * erosion * 2 + fine * detail * 2) * calm
            if gullies > 0 {
                let g = Noise.ridged(V3(dw.x * 3.5, dw.y * 0.7, dw.z * 3.5), octaves: 3, seed: ns &+ 12)
                r *= 1 - gullies * smoothstep(0.35, 0.8, g) * (1 - abs(d.y))
            }
            for (n, k) in planes {
                let c = simd_dot(d, n)
                if c > 1e-3 {
                    let wob = 1 + 0.015 * Noise.fbm(d * 6 + n * 3, octaves: 2, seed: ns &+ 6)
                    r = smin(r, k * wob / c, bevel)
                }
            }
            if topCut > 0 && d.y > 1e-3 {
                let t = (topCut + 0.01 * Noise.fbm(d * 5, octaves: 2, seed: ns &+ 9) * e.y) / d.y
                r = smin(r, lerp(r, t, flatTop), bevel * 1.5)
            }
            if strata > 0 {
                // Soft beds recess horizontally; hardness is constant per bed with sharp changes.
                let y = d.y * r
                var b = y / bed + bedPhase + 0.25 * Noise.fbm(V3(d.x, 0, d.z) * 2, octaves: 2, seed: ns &+ 7)
                b += 0.35 * Noise.perlin(V3(0, b * 0.5, 0.5), seed: ns &+ 8)
                let i = b.rounded(.down), t = b - i
                func hard(_ k: Float) -> Float { 0.5 + 0.5 * Noise.perlin(V3(k * 0.618 + 0.31, 0.27, 0.73), seed: ns &+ 10) * 1.4 }
                let h = lerp(hard(i), hard(i + 1), smoothstep(0.88, 1.0, t))
                let undercut = smoothstep(0.7, 0.95, t) * 0.35
                let horiz = (1 - d.y * d.y).squareRoot()
                let vary = 0.55 + 0.9 * saturate(0.5 + Noise.fbm(V3(d.x * 2.5, i * 0.37, d.z * 2.5), octaves: 2, seed: ns &+ 11))
                r -= strata * ((1 - h) + undercut) * horiz * vary
            }
            return r
        }
        let flatY = -e.y * flatBase
        func shape(_ d: V3) -> V3 {
            var p = d * radius(d)
            if p.y < flatY { p.y = flatY + (p.y - flatY) * 0.12 }
            return p
        }
        let yaw = simd_quatf(angle: rng.float(0...(2 * .pi)), axis: V3(0, 1, 0))
        return lods.map { n in
            var s = Prim.cubeSphere(subdivisions: n, material: material) { yaw.act(shape($0)) }
            let b = s.bounds, h = b.max.y - b.min.y
            let off = V3(-(b.min.x + b.max.x) / 2, -b.min.y - h * sink, -(b.min.z + b.max.z) / 2)
            s.positions = s.positions.map { $0 + off }
            // Box-mapped UVs by dominant normal axis: cube-face UVs stretch where squashed shapes wrap a side
            // face over the top, which streaks the normal map.
            s.uvs = zip(s.positions, s.normals).map { p, n in
                let a = simd_abs(n)
                return a.y >= a.x && a.y >= a.z ? V2(p.x, p.z) : (a.x >= a.z ? V2(p.z, p.y) : V2(p.x, p.y))
            }
            s.computeTangents()
            s.occlusion = Array(repeating: 1, count: s.positions.count)
            s.bakeCavityAO(strength: 0.8)
            return s
        }
    }
}

/// Contact darkening for rocks on the ground: a dark dirt line where the rock meets y = 0, a softer
/// gradient over the lower third, and the underside fully occluded.
func rockContactAO(_ s: inout Surface, height h: Float) {
    if s.occlusion.count != s.positions.count { s.occlusion = Array(repeating: 1, count: s.positions.count) }
    for i in s.positions.indices {
        let y = s.positions[i].y
        let line = lerp(0.35, 1, smoothstep(-0.02, 0.06 + h * 0.04, y))
        let broad = lerp(0.7, 1, smoothstep(0, h * 0.45, y))
        let under = s.normals.count == s.positions.count ? lerp(0.55, 1, smoothstep(-0.6, 0.1, s.normals[i].y)) : 1
        s.occlusion[i] = min(1, max(0, s.occlusion[i] * line * broad * under))
    }
}

/// Darken vertices that sit close to neighboring rocks (center, radius) in a pile.
func rockProximityAO(_ s: inout Surface, rocks: [(V3, Float)], skip: Int? = nil) {
    for i in s.positions.indices {
        var o: Float = 1
        let p = s.positions[i]
        for (k, (c, r)) in rocks.enumerated() where k != skip {
            let d = simd_distance(p, c)
            if d < r * 1.6 { o *= lerp(0.55, 1, smoothstep(r * 0.85, r * 1.6, d)) }
        }
        s.occlusion[i] *= o
    }
}

/// One rock in a multi-rock asset: shape, seed, placement and material.
struct RockPart {
    var shape: RockShape
    var seed: UInt64
    var xform: Xform
    var material: MaterialKey
}

/// Build a rock cluster per LOD. `detail(part, lod)` returns cube-sphere subdivisions, or nil to drop the
/// part at that LOD. Applies contact AO (after placement) and proximity AO between parts.
func rockCluster(name: String, parts: [RockPart], lods: Int, facets: Bool = false, detail: (Int, Int) -> Int?) -> [Model] {
    // Shape once per part at every subdivision it needs.
    var meshes: [[Int: Surface]] = []
    var spheres: [(V3, Float)] = []
    for (i, p) in parts.enumerated() {
        let subs = Array(Set((0..<lods).compactMap { detail(i, $0) })).sorted(by: >)
        let surfs = p.shape.surfaces(seed: p.seed, material: p.material, detail: subs)
        var byN: [Int: Surface] = [:]
        for (n, s) in zip(subs, surfs) { byN[n] = s.transformed(p.xform) }
        meshes.append(byN)
        if let n = subs.first, let s = byN[n] {
            let b = s.bounds, e = (b.max - b.min) / 2
            spheres.append(((b.min + b.max) / 2, (e.x + e.y + e.z) / 3))
        } else { spheres.append((.zero, 0)) }
    }
    let top = spheres.map { $0.0.y + $0.1 }.max() ?? 1
    return (0..<lods).map { lod in
        var m = Model(name: name)
        for i in parts.indices {
            guard let n = detail(i, lod), var s = meshes[i][n] else { continue }
            rockProximityAO(&s, rocks: spheres, skip: i)
            rockContactAO(&s, height: max(0.2, min(top, spheres[i].0.y + spheres[i].1)))
            m.add(facets ? facetted(s) : s)
        }
        return m
    }
}

/// Split every triangle into its own vertices with the face normal: hard edges for small low-poly
/// broken rocks, whose few large facets would otherwise smooth into a blob.
func facetted(_ s: Surface) -> Surface {
    var o = Surface(material: s.material)
    let occ = s.occlusion.count == s.positions.count ? s.occlusion : Array(repeating: 1, count: s.positions.count)
    let cap = s.indices.count
    o.positions.reserveCapacity(cap); o.normals.reserveCapacity(cap); o.uvs.reserveCapacity(cap)
    o.extra.reserveCapacity(cap); o.occlusion.reserveCapacity(cap * 2); o.indices.reserveCapacity(cap)
    for t in stride(from: 0, to: s.indices.count, by: 3) {
        let i0 = Int(s.indices[t]), i1 = Int(s.indices[t + 1]), i2 = Int(s.indices[t + 2])
        let n = simd_normalize(simd_cross(s.positions[i1] - s.positions[i0], s.positions[i2] - s.positions[i0]))
        guard n.x.isFinite else { continue }
        let base = UInt32(o.positions.count)
        for k in [i0, i1, i2] { _ = o.add(s.positions[k], n, s.uvs[k]); o.occlusion.append(occ[k]) }
        o.tri(base, base + 1, base + 2)
    }
    o.computeTangents()
    return o
}
