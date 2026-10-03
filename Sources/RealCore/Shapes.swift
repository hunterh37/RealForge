import simd

// RealityHD 3 geometry kit: 2D outlines and the solids built from them (extrude, sweep, loft,
// superellipsoid, torus, helix, beveled cylinder) plus whole-surface deformers. UVs stay in meters.

/// Closed 2D outlines, counter-clockwise, in meters. Feed them to `Prim.extrude` and `Prim.sweep`.
public enum Shape2D {
    /// Axis-aligned rectangle centered at the origin.
    public static func rect(_ w: Float, _ h: Float) -> [V2] {
        [V2(-w / 2, -h / 2), V2(w / 2, -h / 2), V2(w / 2, h / 2), V2(-w / 2, h / 2)]
    }

    /// Rectangle with circular corners of `radius`, `segments` points per corner.
    public static func roundedRect(_ w: Float, _ h: Float, radius: Float, segments: Int = 4) -> [V2] {
        rounded(rect(w, h), radius: radius, segments: segments)
    }

    /// Circle or ellipse (`ry` defaults to `r`).
    public static func circle(_ r: Float, ry: Float? = nil, segments: Int = 24) -> [V2] {
        (0..<segments).map { k in
            let a = Float(k) / Float(segments) * 2 * .pi
            return V2(cos(a) * r, sin(a) * (ry ?? r))
        }
    }

    /// Superellipse |x/a|^n + |y/b|^n = 1; n = 2 ellipse, n = 4 squircle, n large approaches a rectangle.
    public static func superellipse(_ w: Float, _ h: Float, exponent n: Float = 4, segments: Int = 32) -> [V2] {
        (0..<segments).map { k in
            let a = Float(k) / Float(segments) * 2 * .pi
            let c = cos(a), s = sin(a)
            func f(_ v: Float) -> Float { (v < 0 ? -1 : 1) * pow(abs(v), 2 / n) }
            return V2(f(c) * w / 2, f(s) * h / 2)
        }
    }

    /// Regular polygon with `sides` corners (pentagon nut, octagonal post).
    public static func polygon(sides: Int, radius: Float, rotation: Float = 0) -> [V2] {
        (0..<sides).map { k in
            let a = Float(k) / Float(sides) * 2 * .pi + rotation
            return V2(cos(a) * radius, sin(a) * radius)
        }
    }

    /// Replaces every corner of a closed outline with a circular fillet (`segments` 0 = straight chamfer). Radius clamps to half the
    /// shorter adjacent edge, so it is safe on any outline.
    /// Drops consecutive points closer than `eps` (including last-to-first), which would make
    /// zero-length edges and NaN normals.
    public static func deduped(_ pts: [V2], eps: Float = 1e-5) -> [V2] {
        var out: [V2] = []
        for p in pts where out.last.map({ simd_distance($0, p) > eps }) ?? true { out.append(p) }
        while out.count > 1, simd_distance(out[0], out[out.count - 1]) <= eps { out.removeLast() }
        return out
    }

    public static func rounded(_ input: [V2], radius: Float, segments: Int = 4) -> [V2] {
        let pts = deduped(input)
        guard radius > 0, pts.count >= 3 else { return pts }
        var out: [V2] = []
        let n = pts.count
        for i in 0..<n {
            let p = pts[i], a = pts[(i + n - 1) % n], b = pts[(i + 1) % n]
            let da = simd_normalize(a - p), db = simd_normalize(b - p)
            let cosT = max(-0.999, min(0.999, simd_dot(da, db)))
            let half = acos(cosT) / 2
            let maxR = min(simd_distance(a, p), simd_distance(b, p)) * 0.5 * tan(half)
            let r = min(radius, maxR)
            let t = r / tan(half)                     // distance from corner to tangent points
            let p0 = p + da * t, p1 = p + db * t
            let center = p + simd_normalize(da + db) * (r / sin(half))
            let a0 = atan2(p0.y - center.y, p0.x - center.x)
            var a1 = atan2(p1.y - center.y, p1.x - center.x)
            // Sweep the short way round.
            var d = a1 - a0
            while d > .pi { d -= 2 * .pi }
            while d < -.pi { d += 2 * .pi }
            a1 = a0 + d
            if segments <= 0 { out.append(p0); out.append(p1); continue }   // chamfer
            for k in 0...segments {
                let ang = a0 + (a1 - a0) * Float(k) / Float(segments)
                out.append(center + V2(cos(ang), sin(ang)) * r)
            }
        }
        return out
    }

    /// Signed area (positive = counter-clockwise).
    public static func area(_ pts: [V2]) -> Float {
        var s: Float = 0
        for i in pts.indices { let a = pts[i], b = pts[(i + 1) % pts.count]; s += a.x * b.y - b.x * a.y }
        return s / 2
    }

    /// Outline offset along its vertex normals (positive grows a CCW outline). Miter clamped at 3x.
    public static func offset(_ input: [V2], _ d: Float) -> [V2] {
        let pts = deduped(input)
        let n = pts.count, ccw: Float = area(pts) >= 0 ? 1 : -1
        return (0..<n).map { i in
            let a = pts[(i + n - 1) % n], p = pts[i], b = pts[(i + 1) % n]
            let e0 = simd_normalize(p - a), e1 = simd_normalize(b - p)
            let n0 = V2(e0.y, -e0.x) * ccw, n1 = V2(e1.y, -e1.x) * ccw
            let m = simd_normalize(n0 + n1)
            let k = min(3, 1 / max(0.2, simd_dot(m, n0)))
            return p + m * d * k
        }
    }

    /// Ear-clipping triangulation of a simple polygon. Returns index triples into `pts`.
    public static func triangulate(_ pts: [V2]) -> [UInt32] {
        var idx = Array(0..<pts.count)
        if area(pts) < 0 { idx.reverse() }
        var out: [UInt32] = []
        func cross(_ o: V2, _ a: V2, _ b: V2) -> Float { (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) }
        func inside(_ p: V2, _ a: V2, _ b: V2, _ c: V2) -> Bool {
            cross(a, b, p) > 0 && cross(b, c, p) > 0 && cross(c, a, p) > 0
        }
        var guardCount = 0
        while idx.count > 3 && guardCount < 10_000 {
            guardCount += 1
            var clipped = false
            for i in idx.indices {
                let ia = idx[(i + idx.count - 1) % idx.count], ib = idx[i], ic = idx[(i + 1) % idx.count]
                let a = pts[ia], b = pts[ib], c = pts[ic]
                guard cross(a, b, c) > 1e-10 else { continue }
                if idx.contains(where: { $0 != ia && $0 != ib && $0 != ic && inside(pts[$0], a, b, c) }) { continue }
                out += [UInt32(ia), UInt32(ib), UInt32(ic)]
                idx.remove(at: i); clipped = true; break
            }
            if !clipped { break }
        }
        if idx.count == 3 { out += idx.map(UInt32.init) }
        return out
    }
}

public extension Prim {

    /// Prism from a closed outline in the XY plane, `depth` along Z, centered at the origin, with a
    /// rounded bevel of `bevel` meters on both cap edges. Sides: U = arc length, V = z. Caps: planar XY.
    /// Corners of the outline shade smooth; fillet them with `Shape2D.rounded` for a crisp read.
    static func extrude(_ outline: [V2], depth: Float, bevel: Float = 0.003, bevelSegments: Int = 2,
                        caps: Bool = true, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let clean = Shape2D.deduped(outline)
        let pts = Shape2D.area(clean) >= 0 ? clean : clean.reversed()
        let n = pts.count
        let b = min(bevel, depth * 0.45)
        var arc: [Float] = [0]
        for i in 1...n { arc.append(arc[i - 1] + simd_distance(pts[i - 1], pts[i % n])) }
        // Ring k: (inset, z). Front bevel (z+), straight wall, back bevel (z-).
        var rings: [(Float, Float)] = []
        let seg = b > 0 ? max(1, bevelSegments) : 0
        for k in 0...seg { let t = seg == 0 ? 1 : Float(k) / Float(seg) * .pi / 2; rings.append((b * (1 - sin(t)), -depth / 2 + b * (1 - cos(t)))) }
        for k in 0...seg { let t = seg == 0 ? 0 : Float(k) / Float(seg) * .pi / 2; rings.append((b * (1 - cos(t)), depth / 2 - b * (1 - sin(t)))) }
        let ringPts = rings.map { Shape2D.offset(pts, -$0.0) }
        let row = UInt32(n + 1)
        var vAcc: Float = 0
        for (r, ring) in rings.enumerated() {
            if r > 0 { vAcc += abs(ring.1 - rings[r - 1].1) + abs(ring.0 - rings[r - 1].0) }
            for i in 0...n { let p = ringPts[r][i % n]; s.add(V3(p.x, p.y, ring.1), .up, V2(arc[i], vAcc)) }
        }
        for r in 0..<(rings.count - 1) { for i in 0..<n {
            let a = UInt32(r) * row + UInt32(i)
            s.quad(a, a + 1, a + row + 1, a + row)
        }}
        s.recomputeNormals(weldSeams: true)
        if caps {
            let tri = Shape2D.triangulate(pts)
            for (side, ringIndex) in [(Float(-1), 0), (1, rings.count - 1)] {
                let inner = ringPts[ringIndex], z = rings[ringIndex].1
                let base = UInt32(s.positions.count)
                for p in inner { s.add(V3(p.x, p.y, z), V3(0, 0, side), V2(side * p.x, p.y)) }
                for t in stride(from: 0, to: tri.count, by: 3) {
                    if side > 0 { s.tri(base + tri[t], base + tri[t + 1], base + tri[t + 2]) }
                    else { s.tri(base + tri[t], base + tri[t + 2], base + tri[t + 1]) }
                }
            }
        }
        s.computeTangents()
        return s
    }

    /// Sweeps a 2D cross-section along a 3D path with parallel-transport frames. Profile x maps to the
    /// frame normal, y to the binormal; `up` fixes the first frame (nil picks any). `scales` sizes the
    /// profile per path point. `closedPath` joins the end to the start (rings, frames, torus).
    /// U = profile arc length, V = path arc length (`grainAlongPath` swaps them so wood grain follows the
    /// path); `caps` closes open ends with flat triangulated caps.
    static func sweep(_ profile: [V2], along path: [V3], up: V3? = nil, scales: [Float]? = nil,
                      closedPath: Bool = false, caps: Bool = true, grainAlongPath: Bool = false, material: MaterialKey) -> Surface {
        precondition(path.count >= 2 && profile.count >= 3)
        var s = Surface(material: material)
        let prof = Shape2D.area(profile) >= 0 ? profile : profile.reversed()
        let n = prof.count, m = path.count
        var arc: [Float] = [0]
        for i in 1...n { arc.append(arc[i - 1] + simd_distance(prof[i - 1], prof[i % n])) }
        var tangents: [V3] = []
        for i in 0..<m {
            let a = closedPath ? path[(i + m - 1) % m] : path[max(0, i - 1)]
            let b = closedPath ? path[(i + 1) % m] : path[min(m - 1, i + 1)]
            tangents.append((b - a).normalized)
        }
        var normal: V3
        if let up { let u = up - tangents[0] * simd_dot(up, tangents[0]); normal = simd_length(u) > 1e-5 ? simd_normalize(u) : tangents[0].anyPerpendicular }
        else { normal = tangents[0].anyPerpendicular }
        var frames: [(V3, V3)] = []
        for i in 0..<m {
            if i > 0 {
                let t0 = tangents[i - 1], t1 = tangents[i]
                let axis = simd_cross(t0, t1), sl = simd_length(axis)
                if sl > 1e-6 { normal = simd_quatf(angle: atan2(sl, simd_dot(t0, t1)), axis: axis / sl).act(normal) }
                normal = simd_normalize(normal - t1 * simd_dot(normal, t1))
            }
            frames.append((normal, simd_cross(tangents[i], normal)))
        }
        let count = closedPath ? m + 1 : m
        var v: Float = 0
        for j in 0..<count {
            let i = j % m
            if j > 0 { v += simd_distance(path[i], path[(j - 1) % m]) }
            let (nn, bb) = frames[i], sc = scales?[i] ?? 1
            for k in 0...n {
                let p = prof[k % n] * sc
                s.add(path[i] + nn * p.x + bb * p.y, .up, grainAlongPath ? V2(v, arc[k]) : V2(arc[k], v))
            }
        }
        let row = UInt32(n + 1)
        for j in 0..<(count - 1) { for k in 0..<n {
            let a = UInt32(j) * row + UInt32(k)
            s.quad(a, a + 1, a + row + 1, a + row)
        }}
        s.recomputeNormals(weldSeams: true)
        if caps && !closedPath {
            let tri = Shape2D.triangulate(prof)
            for (end, sign) in [(0, Float(-1)), (m - 1, 1)] {
                let (nn, bb) = frames[end], sc = scales?[end] ?? 1
                let base = UInt32(s.positions.count)
                for p in prof { let q = p * sc; s.add(path[end] + nn * q.x + bb * q.y, tangents[end] * sign, q) }
                for t in stride(from: 0, to: tri.count, by: 3) {
                    if sign > 0 { s.tri(base + tri[t], base + tri[t + 1], base + tri[t + 2]) }
                    else { s.tri(base + tri[t], base + tri[t + 2], base + tri[t + 1]) }
                }
            }
        }
        s.computeTangents()
        return s
    }

    /// A loft ring: a 2D outline (CCW) laid in the XZ plane at height `y`, matching `lathe` orientation
    /// (outline x to +X, outline y to -Z), then shifted by `offset`.
    static func ring(_ outline: [V2], y: Float, offset: V3 = .zero) -> [V3] {
        outline.map { V3($0.x, y, -$0.y) + offset }
    }

    /// Skins rings of equal point count (each ring a closed loop, in order along the body). Use it for
    /// spouts, hulls and any body whose cross-section changes shape. Build rings with `Prim.ring` (or any
    /// loop wound the same way) for outward normals. U around, V along. `capStart` and
    /// `capEnd` fan-close the first and last ring at their centroids.
    static func loft(_ rings: [[V3]], capStart: Bool = false, capEnd: Bool = false, material: MaterialKey) -> Surface {
        precondition(rings.count >= 2 && rings.allSatisfy { $0.count == rings[0].count })
        var s = Surface(material: material)
        let n = rings[0].count
        var vAcc: [Float] = [0]
        for r in 1..<rings.count {
            let d = zip(rings[r], rings[r - 1]).reduce(Float(0)) { $0 + simd_distance($1.0, $1.1) } / Float(n)
            vAcc.append(vAcc[r - 1] + d)
        }
        for (r, ring) in rings.enumerated() {
            var u: Float = 0
            for k in 0...n {
                if k > 0 { u += simd_distance(ring[k % n], ring[(k - 1) % n]) }
                s.add(ring[k % n], .up, V2(u, vAcc[r]))
            }
        }
        let row = UInt32(n + 1)
        for r in 0..<(rings.count - 1) { for k in 0..<n {
            let a = UInt32(r) * row + UInt32(k)
            s.quad(a, a + 1, a + row + 1, a + row)
        }}
        for (flag, r, flip) in [(capStart, 0, true), (capEnd, rings.count - 1, false)] where flag {
            let c = rings[r].reduce(V3.zero, +) / Float(n)
            let ci = s.add(c, .up, V2(0, vAcc[r]))
            let base = UInt32(r) * row
            for k in 0..<UInt32(n) { flip ? s.tri(base + k + 1, base + k, ci) : s.tri(base + k, base + k + 1, ci) }
        }
        s.recomputeNormals(weldSeams: true)
        s.computeTangents()
        return s
    }

    /// Superellipsoid (rounded box to ellipsoid) of full `size`, centered. `exponent` 2 is an
    /// ellipsoid, 4 a soft cushion, 8+ a crisp rounded box. `bulge(dir) -> scale` adds puff or dents.
    static func superellipsoid(_ size: V3, exponent: Float = 6, subdivisions: Int = 10, material: MaterialKey,
                               bulge: ((V3) -> Float)? = nil) -> Surface {
        let n = max(2, exponent)
        var s = cubeSphere(subdivisions: subdivisions, material: material) { d in
            // Radial projection onto |x|^n + |y|^n + |z|^n = 1.
            let t = pow(pow(abs(d.x), n) + pow(abs(d.y), n) + pow(abs(d.z), n), -1 / n)
            return d * t * size / 2 * (bulge?(d) ?? 1)
        }
        // Re-map UVs to box-projected meters (cubeSphere's are on the unit sphere).
        for i in s.positions.indices {
            let p = s.positions[i], n = s.normals[i], a = simd_abs(n)
            s.uvs[i] = a.x >= a.y && a.x >= a.z ? V2(p.z * (n.x > 0 ? -1 : 1), p.y) : (a.y >= a.z ? V2(p.x, p.z * (n.y > 0 ? -1 : 1)) : V2(p.x * (n.z > 0 ? 1 : -1), p.y))
        }
        s.computeTangents()
        return s
    }

    /// Torus in the XZ plane around +Y. `arc` < 2 pi gives an open bend (handles, hoops).
    static func torus(major: Float, minor: Float, segments: Int = 32, sides: Int = 12, arc: Float = 2 * .pi,
                      minorY: Float? = nil, material: MaterialKey) -> Surface {
        let closed = arc >= 2 * .pi - 1e-4
        let count = closed ? segments : segments + 1
        let path = (0..<count).map { k -> V3 in
            let a = arc * Float(k) / Float(segments)
            return V3(cos(a) * major, 0, -sin(a) * major)
        }
        return sweep(Shape2D.circle(minor, ry: minorY, segments: sides), along: path, up: .up, closedPath: closed, caps: !closed, material: material)
    }

    /// Coil spring / thread along +Y from y = 0. `wire` is the wire radius.
    static func helix(radius: Float, pitch: Float, turns: Float, wire: Float, perTurn: Int = 24, sides: Int = 8,
                      material: MaterialKey) -> Surface {
        let steps = max(2, Int(turns * Float(perTurn)))
        let path = (0...steps).map { k -> V3 in
            let t = Float(k) / Float(perTurn), a = t * 2 * .pi
            return V3(cos(a) * radius, t * pitch, sin(a) * radius)
        }
        return tube(path, radii: path.map { _ in wire }, sides: sides, seamTile: 0.05, material: material)
    }

    /// Solid cylinder along +Y from y = 0 to `height`, both rims rounded by `bevel`.
    static func cylinder(radius: Float, height: Float, bevel: Float = 0.003, segments: Int = 32, bevelSegments: Int = 3,
                         topBevel: Bool = true, bottomBevel: Bool = true, seamTile: Float = 0.25, material: MaterialKey,
                         grainVertical: Bool = false) -> Surface {
        lathe(Profile.roundedCylinder(radius: radius, height: height, bevel: bevel, segments: bevelSegments,
                                      top: topBevel, bottom: bottomBevel),
              segments: segments, seamTile: seamTile, material: material, swapUV: grainVertical)
    }
}

/// Lathe profiles: arrays of (radius, y) points for `Prim.lathe` / `turned`.
public enum Profile {
    /// Closed solid cylinder with rounded rims.
    public static func roundedCylinder(radius r: Float, height h: Float, bevel: Float, segments: Int = 3,
                                       top: Bool = true, bottom: Bool = true) -> [V2] {
        let b = min(bevel, r * 0.5, h * 0.5)
        var p: [V2] = [V2(0, 0)]
        if bottom && b > 0 {
            for k in 0...segments { let t = Float(k) / Float(segments) * .pi / 2; p.append(V2(r - b + sin(t) * b, b - cos(t) * b)) }
        } else { p.append(V2(r, 0)) }
        if top && b > 0 {
            for k in 0...segments { let t = Float(k) / Float(segments) * .pi / 2; p.append(V2(r - b + cos(t) * b, h - b + sin(t) * b)) }
        } else { p.append(V2(r, h)) }
        p.append(V2(0, h))
        return p
    }

    /// Smooths a coarse profile with Catmull-Rom (keeps the end points; `per` samples per span).
    public static func smooth(_ pts: [V2], per: Int = 4) -> [V2] {
        guard pts.count > 2 else { return pts }
        var out: [V2] = []
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(pts.count - 1, i + 2)]
            for k in 0..<per {
                let t = Float(k) / Float(per), t2 = t * t, t3 = t2 * t
                let a: V2 = 2 * p1, b: V2 = p2 - p0
                let c: V2 = 2 * p0 - 5 * p1 + 4 * p2 - p3
                let d: V2 = 3 * p1 - 3 * p2 + p3 - p0
                let q: V2 = a + b * t + c * t2 + d * t3
                out.append(0.5 * q)
            }
        }
        out.append(pts[pts.count - 1])
        return out
    }

    /// Thin-walled vessel: outer profile, then the same profile inset by `wall` back down to an inner
    /// floor `floor` above the base, with a rounded lip joining them. Outer profile runs base to rim.
    public static func shell(_ outer: [V2], wall: Float, floor: Float? = nil, lipSegments: Int = 3) -> [V2] {
        guard let rim = outer.last else { return outer }
        var p = outer
        let r = wall / 2
        let c = V2(rim.x - r, rim.y)
        for k in 1...lipSegments { let t = Float(k) / Float(lipSegments) * .pi; p.append(c + V2(cos(t), sin(t)) * r) }
        let fl = floor ?? wall
        for q in outer.reversed().dropFirst() where q.y > fl {
            // Inward normal offset: approximate by shrinking radius.
            p.append(V2(max(0, q.x - wall), q.y))
        }
        p.append(V2(max(0, (outer.first(where: { $0.y >= fl })?.x ?? wall) - wall), fl))
        p.append(V2(0, fl))
        return p
    }
}

public extension Surface {
    /// Moves every vertex through `f`, then rebuilds normals and tangents (bend, taper, sag).
    mutating func deform(_ f: (V3) -> V3) {
        positions = positions.map(f)
        recomputeNormals(weldSeams: true)
        computeTangents()
    }

    /// Pushes vertices along their normals by `amount(position, normal)` meters (dents, puffing).
    mutating func displace(_ amount: (V3, V3) -> Float) {
        if normals.count != positions.count { recomputeNormals() }
        positions = positions.indices.map { positions[$0] + normals[$0] * amount(positions[$0], normals[$0]) }
        recomputeNormals(weldSeams: true)
        computeTangents()
    }

    /// Splits every triangle into four (midpoints shared per edge). Use before `displace` on coarse meshes.
    func subdivided() -> Surface {
        var s = self
        var mid: [UInt64: UInt32] = [:]
        var idx: [UInt32] = []
        func m(_ a: UInt32, _ b: UInt32) -> UInt32 {
            let key = a < b ? UInt64(a) << 32 | UInt64(b) : UInt64(b) << 32 | UInt64(a)
            if let v = mid[key] { return v }
            let i = Int(a), j = Int(b)
            let v = s.add((positions[i] + positions[j]) / 2, (normals[i] + normals[j]).normalized, (uvs[i] + uvs[j]) / 2,
                          extra: extra.count == positions.count ? (extra[i] + extra[j]) / 2 : .zero)
            if occlusion.count == positions.count { s.occlusion[Int(v)] = (occlusion[i] + occlusion[j]) / 2 }
            mid[key] = v
            return v
        }
        for t in stride(from: 0, to: indices.count, by: 3) {
            let a = indices[t], b = indices[t + 1], c = indices[t + 2]
            let ab = m(a, b), bc = m(b, c), ca = m(c, a)
            idx += [a, ab, ca, ab, b, bc, ca, bc, c, ab, bc, ca]
        }
        s.indices = idx
        s.splat = []
        s.tangents = []
        s.computeTangents()
        return s
    }

    /// Flips winding and normals (inside faces of a shell).
    func flipped() -> Surface {
        var s = self
        for t in stride(from: 0, to: s.indices.count, by: 3) { s.indices.swapAt(t + 1, t + 2) }
        s.normals = s.normals.map { -$0 }
        s.computeTangents()
        return s
    }
}
