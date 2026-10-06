import simd
import Foundation

/// Shared geometry for the woodshop hand tools: holed plates (saw totes, squares), framed lofts with an
/// explicit up vector (hammer heads, handles), outline smoothing and the rest-pose transform that lays a
/// tool authored in its own frame onto the bench (y = 0) and centers it on X/Z.
enum HTKit {
    /// Chaikin corner cutting on a closed outline (each pass doubles the point count).
    static func chaikin(_ pts: [V2], _ iterations: Int = 2) -> [V2] {
        var p = pts
        for _ in 0..<iterations {
            var o: [V2] = []
            for i in p.indices {
                let a = p[i], b = p[(i + 1) % p.count]
                o.append(a * 0.75 + b * 0.25); o.append(a * 0.25 + b * 0.75)
            }
            p = o
        }
        return p
    }

    /// Ellipse outline (CCW) centered at `c`, semi-axes `a` along `angle` and `b` across it.
    static func ellipse(_ c: V2, a: Float, b: Float, angle: Float = 0, n: Int = 32) -> [V2] {
        let u = V2(cos(angle), sin(angle)), v = V2(-sin(angle), cos(angle))
        return (0..<n).map { k in
            let t = Float(k) / Float(n) * 2 * .pi
            return c + u * (a * cos(t)) + v * (b * sin(t))
        }
    }

    /// Stadium (rounded slot) outline from `p0` to `p1` of half-width `r`, CCW.
    static func slot(_ p0: V2, _ p1: V2, r: Float, n: Int = 8) -> [V2] {
        let d = simd_normalize(p1 - p0), a0 = atan2(d.y, d.x)
        var out: [V2] = []
        for k in 0...n { let a = a0 - .pi / 2 + Float(k) / Float(n) * .pi; out.append(p1 + V2(cos(a), sin(a)) * r) }
        for k in 0...n { let a = a0 + .pi / 2 + Float(k) / Float(n) * .pi; out.append(p0 + V2(cos(a), sin(a)) * r) }
        return out
    }

    /// Plate in the XY plane with through-holes, `depth` along Z (centered), both cap edges rounded by
    /// `bevel` (holes too). Walls: U = arc length, V = z. Caps: planar XY (back cap mirrored in U).
    static func plate(outer: [V2], holes: [[V2]] = [], depth: Float, bevel: Float, segments: Int = 2,
                      material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let o0 = Shape2D.deduped(outer)
        let O = Shape2D.area(o0) >= 0 ? o0 : o0.reversed()
        let H: [[V2]] = holes.map { h in let d = Shape2D.deduped(h); return Shape2D.area(d) < 0 ? d : d.reversed() }
        let b = min(bevel, depth * 0.45)
        let seg = b > 0 ? max(1, segments) : 0
        var rings: [(Float, Float)] = []
        for k in 0...seg { let t = seg == 0 ? 1 : Float(k) / Float(seg) * .pi / 2; rings.append((b * (1 - sin(t)), -depth / 2 + b * (1 - cos(t)))) }
        for k in 0...seg { let t = seg == 0 ? 0 : Float(k) / Float(seg) * .pi / 2; rings.append((b * (1 - cos(t)), depth / 2 - b * (1 - sin(t)))) }
        let loops: [([V2], Float)] = [(O, 1)] + H.map { ($0, -1) }
        for (loop, sign) in loops {
            let n = loop.count
            let rp = rings.map { Shape2D.offset(loop, -$0.0 * sign) }
            var arc: [Float] = [0]
            for i in 1...n { arc.append(arc[i - 1] + simd_distance(loop[i - 1], loop[i % n])) }
            let base = UInt32(s.positions.count), row = UInt32(n + 1)
            var vAcc: Float = 0
            for (r, ring) in rings.enumerated() {
                if r > 0 { vAcc += abs(ring.1 - rings[r - 1].1) + abs(ring.0 - rings[r - 1].0) }
                for i in 0...n { let p = rp[r][i % n]; s.add(V3(p.x, p.y, ring.1), .up, V2(arc[i], vAcc)) }
            }
            for r in 0..<(rings.count - 1) { for i in 0..<n {
                let a = base + UInt32(r) * row + UInt32(i)
                s.quad(a, a + 1, a + row + 1, a + row)
            }}
        }
        s.recomputeNormals(weldSeams: true)
        // Caps: keyhole polygon (outer with each hole bridged in), ear-clipped.
        var poly = b > 0 ? Shape2D.offset(O, -b) : O
        let capH = H.map { b > 0 ? Shape2D.offset($0, b) : $0 }
        var allEdges: [(V2, V2)] = []
        func edges(_ l: [V2]) -> [(V2, V2)] { l.indices.map { (l[$0], l[($0 + 1) % l.count]) } }
        allEdges += edges(poly); for h in capH { allEdges += edges(h) }
        func crosses(_ a: V2, _ b: V2) -> Bool {
            func cr(_ o: V2, _ p: V2, _ q: V2) -> Float { (p.x - o.x) * (q.y - o.y) - (p.y - o.y) * (q.x - o.x) }
            for (c, d) in allEdges {
                if simd_distance(c, a) < 1e-7 || simd_distance(d, a) < 1e-7 || simd_distance(c, b) < 1e-7 || simd_distance(d, b) < 1e-7 { continue }
                let d1 = cr(a, b, c), d2 = cr(a, b, d), d3 = cr(c, d, a), d4 = cr(c, d, b)
                if (d1 > 0) != (d2 > 0) && (d3 > 0) != (d4 > 0) { return true }
            }
            return false
        }
        // Densify long outer edges so every hole finds a short, direct bridge.
        if !capH.isEmpty {
            var dense: [V2] = []
            for i in poly.indices {
                let a = poly[i], b = poly[(i + 1) % poly.count]
                let k = max(1, Int(simd_distance(a, b) / 0.006))
                for j in 0..<k { dense.append(a + (b - a) * (Float(j) / Float(k))) }
            }
            poly = dense
        }
        for h in capH {
            var best: (Int, Int, Float)? = nil
            for j in h.indices { for i in poly.indices {
                let d = simd_distance(poly[i], h[j])
                if best == nil || d < best!.2, !crosses(poly[i], h[j]) { best = (i, j, d) }
            }}
            let (i, j, _) = best ?? (0, 0, 0)
            let ring = Array(h[j...] + h[..<j])
            poly = Array(poly[...i]) + ring + [h[j], poly[i]] + Array(poly[(i + 1)...])
        }
        let tri = Shape2D.triangulate(poly)
        for side: Float in [-1, 1] {
            let base = UInt32(s.positions.count)
            for p in poly { s.add(V3(p.x, p.y, side * depth / 2), V3(0, 0, side), V2(side * p.x, p.y)) }
            for t in stride(from: 0, to: tri.count, by: 3) {
                if side > 0 { s.tri(base + tri[t], base + tri[t + 1], base + tri[t + 2]) }
                else { s.tri(base + tri[t], base + tri[t + 2], base + tri[t + 1]) }
            }
        }
        s.computeTangents()
        return s
    }

    /// Lofts `section(i)` along `path` with frames locked to `up`: section x runs along t x up, y along up.
    /// U runs along the path (grain follows the part). Caps close both ends; normals face out.
    static func loft(_ path: [V3], up: V3, caps: Bool = true, material: MaterialKey, section: (Int) -> [V2]) -> Surface {
        var rings: [[V3]] = []
        for i in path.indices {
            let a = path[max(0, i - 1)], c = path[min(path.count - 1, i + 1)]
            let t = simd_normalize(c - a)
            let u = simd_normalize(up - t * simd_dot(up, t))
            let side = simd_cross(t, u)
            rings.append(section(i).map { path[i] + side * $0.x + u * $0.y })
        }
        var s = Prim.loft(rings, capStart: caps, capEnd: caps, material: material)
        for i in s.uvs.indices { s.uvs[i] = V2(s.uvs[i].y, s.uvs[i].x) }
        if SurgKit.volume(s) < 0 { s = s.flipped() }
        s.computeTangents()
        return s
    }

    /// Superellipse section points (CCW), `w` across x, `h` across y.
    static func section(_ w: Float, _ h: Float, n: Int, exponent: Float = 2.5) -> [V2] {
        SurgKit.section(w, h, n: n, exponent: exponent)
    }

    /// Domed split-nut head: two D-shaped brass halves with a slot between, axis +Z, base at z = 0.
    static func splitNut(radius r: Float, height h: Float, slot: Float, material: MaterialKey) -> [Surface] {
        var out: [Surface] = []
        for side: Float in [-1, 1] {
            var d: [V2] = []
            for k in 0...14 { let a = -Float.pi / 2 + Float(k) / 14 * .pi; d.append(V2(cos(a) * r, sin(a) * r)) }
            let half = d.map { V2($0.x + slot / 2, $0.y) }
            var e = Prim.extrude(half, depth: h, bevel: h * 0.7, bevelSegments: 3, material: material)
            e = e.transformed(Xform(translation: V3(0, 0, h / 2)))
            if side < 0 { e = e.transformed(Xform(rotation: simd_quatf(angle: .pi, axis: V3(0, 0, 1)))) }
            out.append(e)
        }
        return out
    }

    /// Unwelds a surface into flat-shaded triangles (knife facets, cut stone). UVs are kept.
    static func faceted(_ s: Surface) -> Surface {
        var o = Surface(material: s.material)
        for t in stride(from: 0, to: s.indices.count, by: 3) {
            let a = Int(s.indices[t]), b = Int(s.indices[t + 1]), c = Int(s.indices[t + 2])
            let pa = s.positions[a], pb = s.positions[b], pc = s.positions[c]
            let cr = simd_cross(pb - pa, pc - pa)
            guard simd_length(cr) > 1e-12 else { continue }
            let n = simd_normalize(cr)
            let i0 = o.add(pa, n, s.uvs[a]), i1 = o.add(pb, n, s.uvs[b]), i2 = o.add(pc, n, s.uvs[c])
            o.tri(i0, i1, i2)
        }
        o.computeTangents()
        return o
    }

    /// Fillets each corner of a closed outline with its own radius (`radii[i]` for `pts[i]`).
    static func fillet(_ pts: [V2], radii: [Float], segments: Int = 6) -> [V2] {
        var out: [V2] = []
        let n = pts.count
        for i in 0..<n {
            let p = pts[i], a = pts[(i + n - 1) % n], b = pts[(i + 1) % n]
            let r = radii[i]
            guard r > 0 else { out.append(p); continue }
            let da = simd_normalize(a - p), db = simd_normalize(b - p)
            let half = acos(max(-0.999, min(0.999, simd_dot(da, db)))) / 2
            let t = r / tan(half)
            let p0 = p + da * t, p1 = p + db * t
            let c = p + simd_normalize(da + db) * (r / sin(half))
            let a0 = atan2(p0.y - c.y, p0.x - c.x)
            var d = atan2(p1.y - c.y, p1.x - c.x) - a0
            while d > .pi { d -= 2 * .pi }
            while d < -.pi { d += 2 * .pi }
            for k in 0...segments { let ang = a0 + d * Float(k) / Float(segments); out.append(c + V2(cos(ang), sin(ang)) * r) }
        }
        return out
    }
}

/// Printed or engraved marks laid onto a surface: 2D strokes mapped through `place` (2D -> 3D on the
/// surface, slightly proud) with a fixed `normal`. Seven-segment stroke digits for scales.
struct HTInk {
    var surface: Surface
    let place: (V2) -> V3
    let normal: V3
    init(material: MaterialKey, normal: V3, place: @escaping (V2) -> V3) { surface = Surface(material: material); self.normal = normal; self.place = place }

    mutating func bar(_ a: V2, _ b: V2, _ w: Float) {
        let d = simd_normalize(b - a), n = V2(-d.y, d.x) * (w / 2)
        let q = [a - n, b - n, b + n, a + n]
        let i = q.map { surface.add(place($0), normal, $0) }
        let c = simd_cross(place(q[1]) - place(q[0]), place(q[3]) - place(q[0]))
        if simd_dot(c, normal) >= 0 { surface.quad(i[0], i[1], i[2], i[3]) } else { surface.quad(i[0], i[3], i[2], i[1]) }
    }
    mutating func digit(_ dgt: Int, at o: V2, u: V2, v: V2, h: Float, w: Float) {
        let masks = [63, 6, 91, 79, 102, 109, 125, 7, 127, 111]
        let gw = h * 0.5
        func P(_ a: Float, _ b: Float) -> V2 { o + u * (a * gw) + v * (b * h) }
        if dgt == 1 { bar(P(0.55, 0), P(0.55, 1), w); return }
        let segs: [(Float, Float, Float, Float)] = [(0, 1, 1, 1), (1, 1, 1, 0.5), (1, 0.5, 1, 0), (0, 0, 1, 0), (0, 0.5, 0, 0), (0, 1, 0, 0.5), (0, 0.5, 1, 0.5)]
        for (k, sg) in segs.enumerated() where masks[dgt] & (1 << k) != 0 { bar(P(sg.0, sg.1), P(sg.2, sg.3), w) }
    }
    mutating func number(_ n: Int, center c: V2, u: V2, v: V2, h: Float, w: Float) {
        let ds = String(n).compactMap { Int(String($0)) }
        let gw = h * 0.5, gap = h * 0.28
        let total = Float(ds.count) * gw + Float(ds.count - 1) * gap
        var o = c - u * (total / 2) - v * (h / 2)
        for d in ds { digit(d, at: o, u: u, v: v, h: h, w: w); o += u * (gw + gap) }
    }
    mutating func finished() -> Surface { surface.computeTangents(); return surface }
}
