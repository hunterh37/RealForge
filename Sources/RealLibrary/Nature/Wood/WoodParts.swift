import simd
import Foundation

/// Shared log geometry for wood and camp assets: end-grain caps, split firewood, peeled bark shells,
/// closed grids. Public so packs outside this module can build their own logs.
public enum WoodParts {

    /// End-grain UV for `wood.endgrain*` (tile size 1): the pith maps to the tile center and `radius`
    /// to 0.42 of the tile, where the texture draws the bark edge. `d` is the offset from the pith.
    public static func endGrainUV(_ d: V2, radius: Float, spin: Float = 0) -> V2 {
        let c = cos(spin), s = sin(spin)
        return V2(c * d.x - s * d.y, s * d.x + c * d.y) * (0.42 / max(radius, 1e-3)) + V2(0.5, 0.5)
    }

    /// Flips triangles whose face normal points toward `center(p)`. For star-shaped parts (logs about
    /// their axis, wedges about their centroid) this makes every face point outward.
    public static func orientOutward(_ s: inout Surface, center: (V3) -> V3) {
        for t in stride(from: 0, to: s.indices.count, by: 3) {
            let a = s.positions[Int(s.indices[t])], b = s.positions[Int(s.indices[t + 1])], c = s.positions[Int(s.indices[t + 2])]
            let n = simd_cross(b - a, c - a), m = (a + b + c) / 3
            if simd_dot(n, m - center(m)) < 0 { s.indices.swapAt(t + 1, t + 2) }
        }
    }

    /// Quad grid over `rows` of points (each row one ring, last column repeating the first for a closed
    /// tube). UVs per point. Faces are not oriented; call `orientOutward` or keep ring order consistent.
    public static func grid(_ rows: [[V3]], uvs: [[V2]], material: MaterialKey, occlusion: [[Float]]? = nil) -> Surface {
        var s = Surface(material: material)
        let cols = rows[0].count
        for (i, row) in rows.enumerated() {
            for (k, p) in row.enumerated() {
                s.add(p, .up, uvs[i][k])
                if let occlusion { s.occlusion[s.occlusion.count - 1] = occlusion[i][k] }
            }
        }
        let r = UInt32(cols)
        for i in 0..<(rows.count - 1) { for k in 0..<(cols - 1) {
            let a = UInt32(i) * r + UInt32(k)
            s.quad(a, a + 1, a + r + 1, a + r)
        }}
        return s
    }

    /// Flat cap over a closed outline, fanned from its centroid, normal `normal`. End-grain UVs come from
    /// the offset to `pith` in the (e1, e2) frame.
    public static func cap(_ outline: [V3], normal: V3, pith: V3, e1: V3, e2: V3, radius: Float, spin: Float, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let c = outline.reduce(V3.zero, +) / Float(outline.count)
        func uv(_ p: V3) -> V2 { let d = p - pith; return endGrainUV(V2(simd_dot(d, e1), simd_dot(d, e2)), radius: radius, spin: spin) }
        let ci = s.add(c, normal, uv(c))
        let idx = outline.map { s.add($0, normal, uv($0)) }
        for k in 0..<idx.count {
            let a = idx[k], b = idx[(k + 1) % idx.count]
            let n = simd_cross(s.positions[Int(a)] - c, s.positions[Int(b)] - c)
            if simd_dot(n, normal) >= 0 { s.tri(ci, a, b) } else { s.tri(ci, b, a) }
        }
        return s
    }

    /// Annulus between two closed outlines of equal count (bark ring seen on a sawn end).
    public static func ring(inner: [V3], outer: [V3], normal: V3, material: MaterialKey, uvScale: Float = 1) -> Surface {
        var s = Surface(material: material)
        let n = inner.count
        var acc: Float = 0
        for k in 0...n {
            let i = inner[k % n], o = outer[k % n]
            if k > 0 { acc += simd_distance(outer[k % n], outer[k - 1]) }
            s.add(i, normal, V2(acc, 0) * uvScale)
            s.add(o, normal, V2(acc, simd_distance(i, o)) * uvScale)
        }
        for k in 0..<UInt32(n) {
            let a = k * 2, b = a + 1, c = a + 3, d = a + 2
            let fn = simd_cross(s.positions[Int(b)] - s.positions[Int(a)], s.positions[Int(d)] - s.positions[Int(a)])
            if simd_dot(fn, normal) >= 0 { s.quad(a, b, c, d) } else { s.quad(a, d, c, b) }
        }
        return s
    }

    /// Removes triangles whose centroid fails `keep` (peeled bark) and closes every hole edge with a lip
    /// `thickness` deep, so the bark reads as a layer over the wood beneath. Normals are recomputed for
    /// the remaining shell before the lips are added; lips get flat normals facing into the hole.
    public static func peel(_ s: inout Surface, thickness: Float, keep: (V3) -> Bool) {
        s.recomputeNormals()
        func key(_ i: UInt32) -> SIMD3<Int32> { SIMD3<Int32>((s.positions[Int(i)] * 1e4).rounded(.toNearestOrAwayFromZero)) }
        var kept: [UInt32] = [], removed = Set<[SIMD3<Int32>]>()
        for t in stride(from: 0, to: s.indices.count, by: 3) {
            let a = s.indices[t], b = s.indices[t + 1], c = s.indices[t + 2]
            if keep((s.positions[Int(a)] + s.positions[Int(b)] + s.positions[Int(c)]) / 3) { kept += [a, b, c] }
            else { for (x, y) in [(a, b), (b, c), (c, a)] { removed.insert([key(x), key(y)]) } }
        }
        s.indices = kept
        var lips: [(UInt32, UInt32)] = []
        for t in stride(from: 0, to: kept.count, by: 3) {
            for (x, y) in [(kept[t], kept[t + 1]), (kept[t + 1], kept[t + 2]), (kept[t + 2], kept[t])] where removed.contains([key(y), key(x)]) {
                lips.append((x, y))
            }
        }
        for (a, b) in lips {
            let pa = s.positions[Int(a)], pb = s.positions[Int(b)]
            let na = s.normals[Int(a)], nb = s.normals[Int(b)]
            let qa = pa - na * thickness, qb = pb - nb * thickness
            let fn = simd_cross(pa - pb, qb - pb).normalized
            let ua = s.uvs[Int(a)], ub = s.uvs[Int(b)]
            let i0 = s.add(pb, fn, ub), i1 = s.add(pa, fn, ua)
            let i2 = s.add(qa, fn, ua + V2(0, thickness)), i3 = s.add(qb, fn, ub + V2(0, thickness))
            s.occlusion[Int(i2)] = 0.55; s.occlusion[Int(i3)] = 0.55
            s.quad(i0, i1, i2, i3)
        }
        compact(&s)
        s.computeTangents()
    }

    /// Drops unreferenced vertices.
    public static func compact(_ s: inout Surface) {
        var map = [Int](repeating: -1, count: s.positions.count)
        var o = Surface(material: s.material)
        for i in s.indices where map[Int(i)] < 0 {
            let j = Int(i)
            map[j] = o.positions.count
            o.positions.append(s.positions[j]); o.normals.append(s.normals[j]); o.uvs.append(s.uvs[j])
            o.extra.append(j < s.extra.count ? s.extra[j] : .zero); o.occlusion.append(j < s.occlusion.count ? s.occlusion[j] : 1)
        }
        o.indices = s.indices.map { UInt32(map[Int($0)]) }
        s = o
    }

    /// A split firewood piece along +X, centered at the origin with the pith on the X axis. `sweep` is the
    /// wedge angle (2π keeps an unsplit round). Bark on the outer arc with a visible bark layer at the
    /// ends and split faces, rough split faces in `split` (grain along X), end-grain caps in `end`.
    public static func splitPiece(length: Float, radius: Float, start: Float, sweep: Float, barkThickness: Float = 0.012,
                                  bark: MaterialKey = "bark.oak-dry", split: MaterialKey = "wood.oak", end: MaterialKey = "wood.endgrain",
                                  arcSegments: Int = 8, lengthSegments: Int = 2, barkScale: Float = 2.5, seed: UInt64) -> Model {
        var rng = SeededRNG(seed: seed)
        let ns = UInt32(truncatingIfNeeded: seed)
        let full = sweep >= 2 * .pi - 1e-3
        let na = max(3, arcSegments), nx = max(1, lengthSegments)
        let bend = V2(rng.float(-0.012...0.012), rng.float(-0.012...0.012))
        let spinA = rng.float(0...(2 * .pi)), spinB = rng.float(0...(2 * .pi))
        let half = length / 2
        // Section outline radii (bark surface), with knobbly noise; shared by every slice.
        func r(_ a: Float, _ x: Float) -> Float {
            radius * (1 + 0.05 * Noise.fbm(V3(cos(a) * 1.5, sin(a) * 1.5, x * 3), octaves: 3, seed: ns))
        }
        func dir(_ a: Float) -> V2 { V2(cos(a), sin(a)) }
        func at(_ x: Float, _ q: V2) -> V3 {
            let t = x / max(half, 1e-3)
            let b = bend * (1 - t * t)
            return V3(x, q.x + b.x, q.y + b.y)
        }
        let xs = (0...nx).map { -half + length * Float($0) / Float(nx) }
        let angles = (0...na).map { start + sweep * Float($0) / Float(na) }
        let arcCount = full ? na : na + 1
        var m = Model(name: "split")
        // Bark arc.
        // Bark U wraps a whole number of texture tiles on full rounds so the seam is invisible.
        let tile = max(MaterialLibrary.spec(for: bark).tileSize, 0.05)
        let uFull = max(tile, (2 * .pi * radius * barkScale / tile).rounded() * tile)
        let uPerRad = uFull / (2 * .pi)
        var bRows: [[V3]] = [], bUV: [[V2]] = []
        for x in xs {
            var row: [V3] = [], uv: [V2] = []
            for (k, a) in angles.enumerated() {
                let aa = full && k == na ? angles[0] : a
                row.append(at(x, dir(aa) * r(aa, x))); uv.append(V2((a - start) * uPerRad, x * barkScale))
            }
            bRows.append(row); bUV.append(uv)
        }
        var barkS = grid(bRows, uvs: bUV, material: bark)
        let pith0 = V2.zero
        let centroid: V2 = full ? .zero : dir(start + sweep / 2) * radius * (sweep < .pi ? 0.55 : 0.4)
        func axisCenter(_ p: V3) -> V3 {
            let t = p.x / max(half, 1e-3), b = bend * (1 - t * t)
            return V3(p.x, centroid.x + b.x, centroid.y + b.y)
        }
        orientOutward(&barkS, center: axisCenter)
        m.add(barkS)
        // Split faces: rough, slightly wavy planes from the pith to the bark.
        if !full {
            for (fi, a) in [angles[0], angles[na]].enumerated() {
                let nr = 3
                var rows: [[V3]] = [], uvs: [[V2]] = []
                var barkRows: [[V3]] = [], barkUV: [[V2]] = []
                let fn = V2(-sin(a), cos(a)) * (fi == 0 ? 1 : -1)
                for x in xs {
                    let rr = r(a, x), inner = rr - barkThickness
                    var row: [V3] = [], uv: [V2] = []
                    for j in 0...nr {
                        let t = Float(j) / Float(nr)
                        let wave: Float = (j == 0 || j == nr) ? 0 : 0.006 * Noise.perlin(V3(x * 9, t * 3, Float(fi) * 7), seed: ns &+ 3)
                        row.append(at(x, pith0 + dir(a) * inner * t + fn * wave)); uv.append(V2(x, inner * t + Float(fi) * 0.37))
                    }
                    rows.append(row); uvs.append(uv)
                    barkRows.append([at(x, dir(a) * inner), at(x, dir(a) * rr)]); barkUV.append([V2(x, 0), V2(x, barkThickness)])
                }
                var face = grid(rows, uvs: uvs, material: split)
                orientOutward(&face, center: axisCenter)
                m.add(face)
                var strip = grid(barkRows, uvs: barkUV, material: bark)
                orientOutward(&strip, center: axisCenter)
                m.add(strip)
            }
        }
        // End caps: wood polygon plus the bark ring.
        for (side, x) in [(-1 as Float, -half), (1 as Float, half)] {
            var innerPts: [V3] = [], outerPts: [V3] = []
            for k in 0..<arcCount {
                let a = angles[k], rr = r(a, x)
                innerPts.append(at(x, dir(a) * (rr - barkThickness))); outerPts.append(at(x, dir(a) * rr))
            }
            let n = V3(side, 0, 0)
            let pith = at(x, pith0)
            let outline = full ? innerPts : [pith] + innerPts
            m.add(cap(outline, normal: n, pith: pith, e1: V3(0, 1, 0), e2: V3(0, 0, side), radius: radius - barkThickness,
                      spin: side < 0 ? spinA : spinB, material: end))
            if full {
                m.add(ring(inner: innerPts, outer: outerPts, normal: n, material: bark))
            } else {
                // Open ring along the arc only.
                var s = Surface(material: bark)
                for k in 0..<arcCount {
                    s.add(innerPts[k], n, V2(Float(k) * 0.02, 0)); s.add(outerPts[k], n, V2(Float(k) * 0.02, barkThickness))
                }
                for k in 0..<UInt32(arcCount - 1) {
                    let a = k * 2, b = a + 1, c = a + 3, d = a + 2
                    let fn = simd_cross(s.positions[Int(b)] - s.positions[Int(a)], s.positions[Int(d)] - s.positions[Int(a)])
                    if simd_dot(fn, n) >= 0 { s.quad(a, b, c, d) } else { s.quad(a, d, c, b) }
                }
                m.add(s)
            }
        }
        for i in m.surfaces.indices {
            // Cap and ring normals are set; everything else gets flat-ish recomputed normals.
            if m.surfaces[i].material != end { m.surfaces[i].recomputeNormals(weldSeams: false) }
            m.surfaces[i].computeTangents()
        }
        return m
    }
}
