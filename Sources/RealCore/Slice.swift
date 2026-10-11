import simd

/// A cutting plane: points with `dot(normal, p) == offset`. The front side is where the normal points.
public struct SlicePlane: Sendable, Equatable {
    public var normal: V3
    public var offset: Float
    public init(normal: V3, offset: Float) { self.normal = simd_normalize(normal); self.offset = offset }
    /// Plane through `point` with `normal`.
    public init(point: V3, normal: V3) {
        let n = simd_normalize(normal)
        self.normal = n; self.offset = simd_dot(n, point)
    }
    public func distance(_ p: V3) -> Float { simd_dot(normal, p) - offset }
    /// The same plane in another space: `x` maps this plane's space into the target space.
    public func transformed(_ m: simd_float4x4) -> SlicePlane {
        let p = normal * offset
        let q = m * V4(p, 1)
        let nInv = simd_transpose(m.inverse)
        let n4 = nInv * V4(normal, 0)
        return SlicePlane(point: V3(q.x, q.y, q.z), normal: V3(n4.x, n4.y, n4.z))
    }
}

/// How to fill the hole a cut leaves in a closed shell.
public struct SliceCap: Sendable {
    /// Material of the cut face (flesh, crumb, wood end grain).
    public var material: MaterialKey
    /// Point the planar cut-face UVs are measured from (concentric center: onion, carrot core).
    public var origin: V3
    /// Added to cut-face UVs, in meters. Half the cap material's tile size centers a radial pattern
    /// drawn at uv 0.5 on `origin`.
    public var uvOffset: V2
    public init(material: MaterialKey, origin: V3 = .zero, uvOffset: V2 = .zero) {
        self.material = material; self.origin = origin; self.uvOffset = uvOffset
    }
}

public extension Surface {
    /// Splits this surface by `plane`. Triangles crossing the plane are cut; attributes interpolate along
    /// cut edges. Returns the parts on the back side (opposite the normal) and on the front side, plus the
    /// closed cut loops in this surface's space (ordered, unclosed point lists) for capping.
    func split(by plane: SlicePlane) -> (back: Surface, front: Surface, loops: [[V3]]) {
        var back = Surface(material: material), front = Surface(material: material)
        let hasN = normals.count == positions.count, hasUV = uvs.count == positions.count
        let hasT = tangents.count == positions.count, hasE = extra.count == positions.count
        let hasO = occlusion.count == positions.count, hasS = splat.count == positions.count
        // Signed distances, nudged off zero so no vertex sits exactly on the plane.
        let d: [Float] = positions.map { p in let v = plane.distance(p); return abs(v) < 1e-7 ? 1e-7 : v }
        var mapB = [Int32](repeating: -1, count: positions.count), mapF = mapB
        func copy(_ i: Int, into s: inout Surface, map: inout [Int32]) -> UInt32 {
            if map[i] >= 0 { return UInt32(map[i]) }
            s.positions.append(positions[i])
            if hasN { s.normals.append(normals[i]) }
            if hasUV { s.uvs.append(uvs[i]) }
            if hasT { s.tangents.append(tangents[i]) }
            if hasE { s.extra.append(extra[i]) }
            if hasO { s.occlusion.append(occlusion[i]) }
            if hasS { s.splat.append(splat[i]) }
            let k = UInt32(s.positions.count - 1); map[i] = Int32(k); return k
        }
        // Edge intersection vertices, shared by both triangles on an edge (one per side).
        var cutB: [UInt64: UInt32] = [:], cutF: [UInt64: UInt32] = [:], cutP: [UInt64: V3] = [:]
        func key(_ a: Int, _ b: Int) -> UInt64 { let lo = UInt64(min(a, b)), hi = UInt64(max(a, b)); return lo << 32 | hi }
        func cut(_ a: Int, _ b: Int) -> (UInt32, UInt32, UInt64) {
            let k = key(a, b)
            if let ib = cutB[k], let iF = cutF[k] { return (ib, iF, k) }
            let t = d[a] / (d[a] - d[b])
            func lerp3(_ x: V3, _ y: V3) -> V3 { x + (y - x) * t }
            let p = lerp3(positions[a], positions[b])
            cutP[k] = p
            func emit(_ s: inout Surface) -> UInt32 {
                s.positions.append(p)
                if hasN { let n = lerp3(normals[a], normals[b]); s.normals.append(simd_length(n) > 1e-8 ? simd_normalize(n) : normals[a]) }
                if hasUV { s.uvs.append(uvs[a] + (uvs[b] - uvs[a]) * t) }
                if hasT {
                    let ta = tangents[a], tb = tangents[b]
                    var tv = V3(ta.x, ta.y, ta.z) + (V3(tb.x, tb.y, tb.z) - V3(ta.x, ta.y, ta.z)) * t
                    tv = simd_length(tv) > 1e-8 ? simd_normalize(tv) : V3(ta.x, ta.y, ta.z)
                    s.tangents.append(V4(tv, ta.w))
                }
                if hasE { s.extra.append(extra[a] + (extra[b] - extra[a]) * t) }
                if hasO { s.occlusion.append(occlusion[a] + (occlusion[b] - occlusion[a]) * t) }
                if hasS { s.splat.append(splat[a] + (splat[b] - splat[a]) * t) }
                return UInt32(s.positions.count - 1)
            }
            let ib = emit(&back), iF = emit(&front)
            cutB[k] = ib; cutF[k] = iF
            return (ib, iF, k)
        }
        var segments: [(UInt64, UInt64)] = []
        var t = 0
        while t + 2 < indices.count {
            let v = [Int(indices[t]), Int(indices[t + 1]), Int(indices[t + 2])]
            t += 3
            let s = v.map { d[$0] >= 0 }
            if s[0] == s[1] && s[1] == s[2] {
                if s[0] { front.tri(copy(v[0], into: &front, map: &mapF), copy(v[1], into: &front, map: &mapF), copy(v[2], into: &front, map: &mapF)) }
                else { back.tri(copy(v[0], into: &back, map: &mapB), copy(v[1], into: &back, map: &mapB), copy(v[2], into: &back, map: &mapB)) }
                continue
            }
            // Rotate so v[r] is the lone vertex on its side; winding is preserved.
            let r = s[0] == s[1] ? 2 : (s[0] == s[2] ? 1 : 0)
            let a = v[r], b = v[(r + 1) % 3], c = v[(r + 2) % 3]
            let (abB, abF, kab) = cut(a, b), (acB, acF, kac) = cut(a, c)
            segments.append((kab, kac))
            if s[r] {
                // a alone in front: triangle (a, ab, ac) front; quad (ab, b, c, ac) back.
                let ia = copy(a, into: &front, map: &mapF)
                front.tri(ia, abF, acF)
                let ib = copy(b, into: &back, map: &mapB), ic = copy(c, into: &back, map: &mapB)
                back.tri(abB, ib, ic); back.tri(abB, ic, acB)
            } else {
                let ia = copy(a, into: &back, map: &mapB)
                back.tri(ia, abB, acB)
                let ib = copy(b, into: &front, map: &mapF), ic = copy(c, into: &front, map: &mapF)
                front.tri(abF, ib, ic); front.tri(abF, ic, acF)
            }
        }
        return (back, front, Self.chain(segments, cutP))
    }

    /// Chains cut segments (edge-key pairs) into closed loops. Open chains (non-manifold input) are
    /// closed straight across when their ends are near, dropped otherwise.
    private static func chain(_ rawSegs: [(UInt64, UInt64)], _ rawPos: [UInt64: V3]) -> [[V3]] {
        // Weld by position: UV and normal seams duplicate vertices, so edge keys alone do not connect.
        var weld: [SIMD3<Int32>: UInt64] = [:], pos: [UInt64: V3] = [:], canon: [UInt64: UInt64] = [:]
        for k in rawPos.keys.sorted() {
            let p = rawPos[k]!
            let q = SIMD3<Int32>(Int32((p.x * 2e5).rounded()), Int32((p.y * 2e5).rounded()), Int32((p.z * 2e5).rounded()))
            if let c = weld[q] { canon[k] = c } else { weld[q] = k; canon[k] = k; pos[k] = p }
        }
        let segs = rawSegs.compactMap { s -> (UInt64, UInt64)? in
            guard let a = canon[s.0], let b = canon[s.1] else { return nil }
            return (a, b)
        }
        var adj: [UInt64: [UInt64]] = [:]
        for (a, b) in segs where a != b { adj[a, default: []].append(b); adj[b, default: []].append(a) }
        var used = Set<UInt64>(), loops: [[V3]] = []
        // Start open chains at their ends first so they come out whole.
        let starts = adj.keys.sorted { (adj[$0]?.count ?? 0, $0) < (adj[$1]?.count ?? 0, $1) }
        for start in starts where !used.contains(start) {
            var loop: [UInt64] = [start]; used.insert(start)
            var cur = start, prev: UInt64? = nil
            while let next = adj[cur]?.first(where: { $0 != prev && !used.contains($0) }) {
                loop.append(next); used.insert(next); prev = cur; cur = next
            }
            guard loop.count >= 3 else { continue }
            let pts = loop.compactMap { pos[$0] }
            let closes = adj[cur]?.contains(start) ?? false
            if !closes, let f = pts.first, let l = pts.last {
                let span = pts.indices.dropFirst().reduce(Float(0)) { $0 + simd_distance(pts[$1], pts[$1 - 1]) }
                if simd_distance(f, l) > span * 0.15 { continue }
            }
            loops.append(pts)
        }
        return loops
    }

    /// Planar cap for cut loops, facing `normal`. Loops nested inside others become holes (even-odd).
    static func cap(loops: [[V3]], normal: V3, cap: SliceCap) -> Surface {
        var s = Surface(material: cap.material)
        guard !loops.isEmpty else { return s }
        let ref: V3 = abs(normal.y) < 0.9 ? V3(0, 1, 0) : V3(1, 0, 0)
        let u = simd_normalize(simd_cross(ref, normal)), v = simd_cross(normal, u)
        let o = cap.origin
        func to2(_ p: V3) -> V2 { V2(simd_dot(p - o, u), simd_dot(p - o, v)) }
        var polys: [[V3]] = loops.map { Shape2DLoop.dedupe($0) }.filter { $0.count >= 3 }
        var flat = polys.map { $0.map(to2) }
        // Orient every loop counter-clockwise in (u, v) (u x v = normal, so CCW faces the normal).
        for i in flat.indices where Shape2D.area(flat[i]) < 0 { flat[i].reverse(); polys[i].reverse() }
        // Nesting depth: number of other loops containing a point of this one.
        let depth = flat.indices.map { i in flat.indices.filter { j in j != i && Shape2DLoop.contains(flat[j], flat[i][0]) }.count }
        for i in flat.indices where depth[i] % 2 == 0 {
            var outer = flat[i], outer3 = polys[i]
            // Direct holes: one level deeper and inside this loop.
            let holes = flat.indices.filter { j in depth[j] == depth[i] + 1 && Shape2DLoop.contains(flat[i], flat[j][0]) }
                .sorted { (flat[$0].map(\.x).max() ?? 0) > (flat[$1].map(\.x).max() ?? 0) }
            for h in holes {
                var hole = flat[h], hole3 = polys[h]
                hole.reverse(); hole3.reverse()                     // holes run clockwise
                (outer, outer3) = Shape2DLoop.bridge(outer, outer3, hole, hole3)
            }
            let tris = Shape2D.triangulate(outer)
            let base = UInt32(s.positions.count)
            for (k, p) in outer3.enumerated() {
                _ = s.add(p, normal, outer[k] + cap.uvOffset)
            }
            var t = 0
            while t + 2 < tris.count { s.tri(base + tris[t], base + tris[t + 1], base + tris[t + 2]); t += 3 }
        }
        s.occlusion = Array(repeating: 1, count: s.positions.count)
        s.computeTangents()
        return s
    }
}

/// Polygon helpers for capping (2D loops with matching 3D points).
enum Shape2DLoop {
    static func dedupe(_ p: [V3]) -> [V3] {
        var out: [V3] = []
        for q in p where out.last.map({ simd_distance($0, q) > 1e-6 }) ?? true { out.append(q) }
        if let f = out.first, let l = out.last, out.count > 1, simd_distance(f, l) <= 1e-6 { out.removeLast() }
        return out
    }

    static func contains(_ poly: [V2], _ p: V2) -> Bool {
        var inside = false
        var j = poly.count - 1
        for i in poly.indices {
            let a = poly[i], b = poly[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    /// Splices a clockwise hole into a counter-clockwise outer loop through a bridge from the hole's
    /// rightmost vertex to the nearest visible outer vertex along +x.
    static func bridge(_ outer: [V2], _ outer3: [V3], _ hole: [V2], _ hole3: [V3]) -> ([V2], [V3]) {
        guard let hi = hole.indices.max(by: { hole[$0].x < hole[$1].x }) else { return (outer, outer3) }
        let m = hole[hi]
        var best = -1, bestX = Float.infinity
        var j = outer.count - 1
        for i in outer.indices {
            let a = outer[j], b = outer[i]
            if (a.y > m.y) != (b.y > m.y) {
                let x = (b.x - a.x) * (m.y - a.y) / (b.y - a.y) + a.x
                if x >= m.x && x < bestX { bestX = x; best = a.x > b.x ? j : i }
            }
            j = i
        }
        if best < 0 { best = outer.indices.min(by: { simd_distance(outer[$0], m) < simd_distance(outer[$1], m) }) ?? 0 }
        var o2: [V2] = [], o3: [V3] = []
        for i in 0...best { o2.append(outer[i]); o3.append(outer3[i]) }
        for k in 0...hole.count { let h = (hi + k) % hole.count; o2.append(hole[h]); o3.append(hole3[h]) }
        // Back to the bridge vertex, nudged so the two bridge edges are not collinear duplicates.
        let eps = V2(0, 1e-6)
        o2.append(outer[best] + eps); o3.append(outer3[best])
        for i in (best + 1)..<outer.count { o2.append(outer[i]); o3.append(outer3[i]) }
        return (o2, o3)
    }
}

public extension Model {
    /// Cuts the model with `plane` into the part behind the plane and the part in front. `cap` picks the
    /// cut-face fill per surface material (nil = leave that shell open, e.g. a thin peel over flesh).
    /// Empty halves come back with no surfaces.
    func sliced(by plane: SlicePlane, cap: (MaterialKey) -> SliceCap?) -> (back: Model, front: Model) {
        var back = Model(name: name + "-a"), front = Model(name: name + "-b")
        for s in surfaces where !s.isEmpty {
            let r = s.split(by: plane)
            if !r.back.isEmpty { back.surfaces.append(r.back) }
            if !r.front.isEmpty { front.surfaces.append(r.front) }
            guard let c = cap(s.material), !r.loops.isEmpty else { continue }
            // Back piece's cut face looks toward the plane normal; front piece's away from it.
            let capB = Surface.cap(loops: r.loops, normal: plane.normal, cap: c)
            var capF = capB.flippedFacing()
            capF.material = c.material
            Self.merge(capB, into: &back)
            Self.merge(capF, into: &front)
        }
        return (back, front)
    }

    private static func merge(_ s: Surface, into m: inout Model) {
        guard !s.isEmpty else { return }
        if let i = m.surfaces.firstIndex(where: { $0.material == s.material }) { m.surfaces[i].append(s) } else { m.surfaces.append(s) }
    }

    /// Enclosed volume in m^3 (divergence theorem over closed surfaces; open shells give an estimate).
    var volume: Float {
        var v: Float = 0
        for s in surfaces {
            var t = 0
            while t + 2 < s.indices.count {
                let a = s.positions[Int(s.indices[t])], b = s.positions[Int(s.indices[t + 1])], c = s.positions[Int(s.indices[t + 2])]
                v += simd_dot(a, simd_cross(b, c)) / 6
                t += 3
            }
        }
        return abs(v)
    }

    /// Area-weighted centroid of all triangles (cheap center of mass proxy).
    var surfaceCentroid: V3 {
        var acc = V3.zero, area: Float = 0
        for s in surfaces {
            var t = 0
            while t + 2 < s.indices.count {
                let a = s.positions[Int(s.indices[t])], b = s.positions[Int(s.indices[t + 1])], c = s.positions[Int(s.indices[t + 2])]
                let w = simd_length(simd_cross(b - a, c - a)) * 0.5
                acc += (a + b + c) / 3 * w; area += w
                t += 3
            }
        }
        return area > 0 ? acc / area : .zero
    }
}

public extension Surface {
    /// Same geometry facing the other way: reversed winding, negated normals and tangent handedness.
    func flippedFacing() -> Surface {
        var s = self
        var t = 0
        while t + 2 < s.indices.count { s.indices.swapAt(t + 1, t + 2); t += 3 }
        s.normals = s.normals.map { -$0 }
        s.tangents = s.tangents.map { V4($0.x, $0.y, $0.z, -$0.w) }
        return s
    }

    /// True when every edge is shared by exactly two triangles after welding positions within `weld`.
    func isClosed(weld: Float = 1e-5) -> Bool {
        var ids: [SIMD3<Int32>: Int] = [:], remap = [Int](repeating: 0, count: positions.count)
        for (i, p) in positions.enumerated() {
            let q = SIMD3<Int32>(Int32((p.x / weld).rounded()), Int32((p.y / weld).rounded()), Int32((p.z / weld).rounded()))
            if let j = ids[q] { remap[i] = j } else { ids[q] = i; remap[i] = i }
        }
        var edges: [UInt64: Int] = [:]
        var t = 0
        while t + 2 < indices.count {
            let v = [remap[Int(indices[t])], remap[Int(indices[t + 1])], remap[Int(indices[t + 2])]]
            t += 3
            if v[0] == v[1] || v[1] == v[2] || v[0] == v[2] { continue }
            for k in 0..<3 {
                let a = UInt64(min(v[k], v[(k + 1) % 3])), b = UInt64(max(v[k], v[(k + 1) % 3]))
                edges[a << 32 | b, default: 0] += 1
            }
        }
        return !edges.isEmpty && edges.values.allSatisfy { $0 == 2 }
    }
}
