import simd
import Foundation

/// A 2D molding profile drawn bottom to top. `x` is projection from the wall plane (or radius for a
/// lathe), `y` is height. Material lies on the left of the walking direction (toward the wall or axis).
/// Each element call appends to the current end point; joints between elements are creased unless an
/// element continues smoothly (the two halves of a cyma).
///
/// ```swift
/// var p = ArchProfile()            // starts at (0, 0) on the wall
/// p.step(0.04); p.fillet(0.03)      // fascia
/// p.cymaReversa(0.04, 0.03)         // bed mold
/// p.step(0.12); p.fillet(0.1)       // corona
/// p.cymaRecta(0.08, 0.07)           // crown
/// let s = ArchTrimKit.sweep(p, length: 1.2, material: "stone.limestone")
/// ```
public struct ArchProfile: Sendable {
    public var points: [V2]
    /// Crease flag per point (true = hard normal break).
    public var sharp: [Bool]

    public init(_ start: V2 = .zero) { points = [start]; sharp = [true] }

    public var end: V2 { points[points.count - 1] }
    public var maxX: Float { points.map(\.x).max() ?? 0 }
    public var minY: Float { points.map(\.y).min() ?? 0 }
    public var maxY: Float { points.map(\.y).max() ?? 0 }

    mutating func push(_ p: V2, sharp s: Bool) {
        if simd_distance(p, end) < 1e-6 { sharp[sharp.count - 1] = sharp[sharp.count - 1] || s; return }
        points.append(p); sharp.append(s)
    }

    /// Straight segment by (dx, dy).
    public mutating func line(_ dx: Float, _ dy: Float) { push(end + V2(dx, dy), sharp: true) }
    /// Vertical flat face (fillet, listel, fascia) of height `h`.
    public mutating func fillet(_ h: Float) { line(0, h) }
    /// Horizontal step outward (+) or back toward the wall (-).
    public mutating func step(_ d: Float) { line(d, 0) }
    /// Moves straight to an absolute point.
    public mutating func to(_ p: V2) { push(p, sharp: true) }

    /// Quarter ellipse rising `h` while moving `d` (signed). Convex bulges away from the material.
    public mutating func quarter(_ h: Float, _ d: Float, convex: Bool, segments: Int = 6, smoothEnd: Bool = false) {
        let p0 = end, p1 = p0 + V2(d, h)
        let chord = p1 - p0
        let a = V2(p1.x, p0.y)
        func left(_ c: V2) -> Bool { let q = c - p0; return chord.x * q.y - chord.y * q.x > 0 }
        let useA = convex ? left(a) : !left(a)
        for k in 1...segments {
            let t = Float(k) / Float(segments) * .pi / 2
            let p = useA ? V2(p1.x - d * cos(t), p0.y + h * sin(t)) : V2(p0.x + d * sin(t), p1.y - h * cos(t))
            push(p, sharp: k == segments && !smoothEnd)
        }
    }
    /// Convex quarter round (echinus, ovolo) rising `h`, projecting `d`.
    public mutating func ovolo(_ h: Float, _ d: Float, segments: Int = 6) { quarter(h, d, convex: true, segments: segments) }
    /// Concave quarter hollow (cove) rising `h`, projecting `d`.
    public mutating func cavetto(_ h: Float, _ d: Float, segments: Int = 6) { quarter(h, d, convex: false, segments: segments) }
    /// Ogee crown: concave below, convex above, projecting `d` over height `h`.
    public mutating func cymaRecta(_ h: Float, _ d: Float, segments: Int = 5) {
        quarter(h / 2, d / 2, convex: false, segments: segments, smoothEnd: true)
        quarter(h / 2, d / 2, convex: true, segments: segments)
    }
    /// Reverse ogee (talon, bed mold): convex below, concave above.
    public mutating func cymaReversa(_ h: Float, _ d: Float, segments: Int = 5) {
        quarter(h / 2, d / 2, convex: true, segments: segments, smoothEnd: true)
        quarter(h / 2, d / 2, convex: false, segments: segments)
    }
    /// Half-round torus of radius `r` (rises 2r, projects r) on a vertical face.
    public mutating func torus(_ r: Float, segments: Int = 8) {
        let p0 = end
        for k in 1...segments {
            let t = Float(k) / Float(segments) * .pi
            push(p0 + V2(r * sin(t), r - r * cos(t)), sharp: k == segments)
        }
    }
    /// Small half round (astragal bead).
    public mutating func bead(_ r: Float) { torus(r, segments: 6) }
    /// Scotia: hollow half round of height `h` cut `depth` into the face.
    public mutating func scotia(_ h: Float, depth: Float, segments: Int = 8) {
        let p0 = end
        for k in 1...segments {
            let t = Float(k) / Float(segments) * .pi
            push(p0 + V2(-depth * sin(t), h / 2 * (1 - cos(t))), sharp: k == segments)
        }
    }
    /// Appends another profile drawn from its own origin.
    public mutating func append(_ o: ArchProfile) {
        let base = end - o.points[0]
        for (i, p) in o.points.enumerated().dropFirst() { push(p + base, sharp: o.sharp[i]) }
    }
    public func scaled(_ k: Float) -> ArchProfile { var c = self; c.points = points.map { $0 * k }; return c }
    public func scaled(_ k: V2) -> ArchProfile { var c = self; c.points = points.map { $0 * k }; return c }
    public func shifted(_ d: V2) -> ArchProfile { var c = self; c.points = points.map { $0 + d }; return c }
}

/// Standalone profile elements (each starts at the origin) for apps that compose their own trim.
public extension ArchProfile {
    static func ogee(height h: Float, projection d: Float) -> ArchProfile { var p = ArchProfile(); p.cymaRecta(h, d); return p }
    static func cymaRecta(height h: Float, projection d: Float) -> ArchProfile { ogee(height: h, projection: d) }
    static func cymaReversa(height h: Float, projection d: Float) -> ArchProfile { var p = ArchProfile(); p.cymaReversa(h, d); return p }
    static func cavetto(height h: Float, projection d: Float) -> ArchProfile { var p = ArchProfile(); p.cavetto(h, d); return p }
    static func ovolo(height h: Float, projection d: Float) -> ArchProfile { var p = ArchProfile(); p.ovolo(h, d); return p }
    static func torus(radius r: Float) -> ArchProfile { var p = ArchProfile(); p.torus(r); return p }
    static func bead(radius r: Float) -> ArchProfile { var p = ArchProfile(); p.bead(r); return p }
    static func fillet(height h: Float) -> ArchProfile { var p = ArchProfile(); p.fillet(h); return p }
}

/// Sweeps, lathes and helpers for classical trim. Profiles are swept with hard creases, analytic
/// normals and 2D ray-cast occlusion, so a 1.2 m cornice costs a few hundred triangles.
public enum ArchTrimKit {
    struct PV { var p: V2; var n: V2; var v: Float; var ao: Float = 1 }

    static func rightNormal(_ e: V2) -> V2 { let l = simd_length(e); return l > 1e-9 ? V2(e.y, -e.x) / l : V2(1, 0) }

    /// Closes a profile against the wall plane x = 0: top back to the wall, wall down to the start.
    public static func closed(_ p: ArchProfile) -> ArchProfile {
        var c = p
        if abs(c.end.x) > 1e-6 { c.to(V2(0, c.end.y)) }
        if abs(c.points[0].x) > 1e-6 { c.to(V2(0, c.points[0].y)) }
        c.sharp[0] = true
        return c
    }

    /// Splits a profile into strips of vertices with per-vertex normals (creases duplicated).
    static func strips(_ pts: [V2], sharp: [Bool], loop: Bool, maxSeg: Float) -> [[PV]] {
        let n = pts.count
        let ne = loop ? n : n - 1
        let en = (0..<ne).map { rightNormal(pts[($0 + 1) % n] - pts[$0]) }
        var out: [[PV]] = []
        var cur: [PV] = []
        var v: Float = 0
        func normalAt(_ j: Int, from i: Int) -> V2 {
            // point j reached by edge i
            let next = loop ? j % n : j
            if sharp[next % n] || (!loop && (next == 0 || next == n - 1)) { return en[i] }
            let ni = loop ? next % n : next
            guard ni < ne else { return en[i] }
            return simd_normalize(en[i] + en[ni])
        }
        cur.append(PV(p: pts[0], n: en[0], v: 0))
        for i in 0..<ne {
            let a = pts[i], b = pts[(i + 1) % n]
            let len = simd_distance(a, b)
            let k = max(1, Int(ceil(len / maxSeg)))
            for s in 1..<k { cur.append(PV(p: a + (b - a) * Float(s) / Float(k), n: en[i], v: v + len * Float(s) / Float(k))) }
            v += len
            let j = i + 1
            cur.append(PV(p: b, n: normalAt(j, from: i), v: v))
            let isCrease = loop ? (sharp[j % n]) : (j < n - 1 && sharp[j])
            if isCrease && i < ne - 1 {
                out.append(cur)
                cur = [PV(p: b, n: en[i + 1], v: v)]
            }
        }
        out.append(cur)
        return out
    }

    /// 2D ambient occlusion: rays in the normal hemisphere against the profile (and the wall plane).
    static func occlusion(_ strips: inout [[PV]], edges: [V2], loop: Bool, wall: Bool, radius: Float) {
        let n = edges.count
        let ne = loop ? n : n - 1
        let dirs = (0..<9).map { k -> Float in (Float(k) / 8 - 0.5) * .pi * 0.9 }
        for s in strips.indices { for i in strips[s].indices {
            let pv = strips[s][i]
            let o = pv.p + pv.n * 2e-4
            var occ: Float = 0
            for a in dirs {
                let d = V2(pv.n.x * cos(a) - pv.n.y * sin(a), pv.n.x * sin(a) + pv.n.y * cos(a))
                var tMin = radius
                if wall && o.x > 1e-3 && d.x < -1e-4 { tMin = min(tMin, -o.x / d.x) }
                for e in 0..<ne {
                    let p = edges[e], q = edges[(e + 1) % n]
                    let r = q - p, den = d.x * r.y - d.y * r.x
                    guard abs(den) > 1e-9 else { continue }
                    let w = p - o
                    let t = (w.x * r.y - w.y * r.x) / den, u = (w.x * d.y - w.y * d.x) / den
                    if t > 1e-4 && u >= 0 && u <= 1 { tMin = min(tMin, t) }
                }
                occ += (1 - tMin / radius) * cos(a)
            }
            strips[s][i].ao = max(0.35, 1 - occ / 5.2)
        }}
    }

    /// Sweeps a profile straight along X from `start(p)` to `end(p)` (per profile point, so ends may be
    /// mitered or cut on any plane). Profile x maps to +Z (out of the wall), y to +Y. The profile is
    /// closed against the wall (`closeBack`), creased where flagged, and capped.
    public static func sweep(_ profile: ArchProfile, from start: (V2) -> Float, to end: (V2) -> Float,
                             material: MaterialKey, closeBack: Bool = true, caps: Bool = true, wallAO: Bool = true,
                             spans: Int? = nil, skipBack: Bool = false) -> Surface {
        let c = closeBack ? closed(profile) : profile
        let pts = c.points, n = pts.count
        let size = max(c.maxY - c.minY, c.maxX)
        var st = strips(pts, sharp: c.sharp, loop: closeBack, maxSeg: max(0.006, size / 24))
        occlusion(&st, edges: pts, loop: closeBack, wall: wallAO, radius: max(0.02, size * 0.25))
        var s = Surface(material: material)
        let spanCount = spans ?? 1
        let row = UInt32(spanCount + 1)
        for strip in st where !(skipBack && strip.allSatisfy { $0.p.x < 1e-5 }) {
            let base = UInt32(s.positions.count)
            for pv in strip {
                let nn = V3(0, pv.n.y, pv.n.x)
                let x0 = start(pv.p), x1 = end(pv.p)
                for j in 0...spanCount {
                    let x = x0 + (x1 - x0) * Float(j) / Float(spanCount)
                    s.add(V3(x, pv.p.y, pv.p.x), nn, V2(x, pv.v)); s.occlusion[s.occlusion.count - 1] = pv.ao
                }
            }
            for k in 0..<UInt32(strip.count - 1) { for j in 0..<UInt32(spanCount) {
                let a0 = base + k * row + j, b0 = a0 + 1, a1 = a0 + row, b1 = a1 + 1
                s.quad(a0, b0, b1, a1)
            }}
        }
        if caps && closeBack {
            let tri = Shape2D.triangulate(pts)
            let flip = Shape2D.area(pts) < 0
            for isEnd in [false, true] {
                let f = isEnd ? end : start
                // plane x = f(p) is linear in p: estimate its gradient for the cap normal
                let g = V2(f(V2(1, 0)) - f(.zero), f(V2(0, 1)) - f(.zero))
                var nrm = simd_normalize(V3(1, -g.y, -g.x))
                if !isEnd { nrm = -nrm }
                let base = UInt32(s.positions.count)
                for p in pts { s.add(V3(f(p), p.y, p.x), nrm, V2(p.x * (isEnd ? 1 : -1), p.y)); s.occlusion[s.occlusion.count - 1] = 0.85 }
                for t in stride(from: 0, to: tri.count, by: 3) {
                    let a = base + tri[t], b = base + tri[t + 1], cc = base + tri[t + 2]
                    if isEnd != flip { s.tri(a, cc, b) } else { s.tri(a, b, cc) }
                }
            }
        }
        _ = n
        s.computeTangents()
        return s
    }

    /// Straight sweep of `length` centered on X; optional 45-degree outside-corner miters at either end.
    public static func sweep(_ profile: ArchProfile, length: Float, material: MaterialKey,
                             miterStart: Bool = false, miterEnd: Bool = false, closeBack: Bool = true, caps: Bool = true,
                             span: Float = 0.06) -> Surface {
        let h = length / 2
        return sweep(profile, from: { p in miterStart ? -h - p.x : -h }, to: { p in miterEnd ? h + p.x : h },
                     material: material, closeBack: closeBack, caps: caps, spans: max(1, Int((length / span).rounded())))
    }

    /// A run of `length` with both ends mitered and short returns back to the wall plane, the way a
    /// cornice or hood finishes over a window: the returns run along -Z/+Z at x = -length/2 and +length/2.
    public static func returnedRun(_ profile: ArchProfile, length: Float, material: MaterialKey, span: Float = 0.06) -> Surface {
        let h = length / 2
        var s = sweep(profile, length: length, material: material, miterStart: true, miterEnd: true, span: span)
        let left = sweep(profile, from: { _ in 0 }, to: { p in p.x }, material: material)
        let right = sweep(profile, from: { p in -p.x }, to: { _ in 0 }, material: material)
        s.append(left, Xform(translation: V3(-h, 0, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 1, 0))))
        s.append(right, Xform(translation: V3(h, 0, 0), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 1, 0))))
        return s
    }

    /// Sweeps a profile along a path in the XY plane (arches, segmental pediments). The profile's y
    /// follows the path's left normal (outward for a path drawn left to right over an arch), x goes +Z.
    public static func sweep(_ profile: ArchProfile, along path: [V2], material: MaterialKey, caps: Bool = true) -> Surface {
        let c = closed(profile)
        let pts = c.points
        let size = max(c.maxY - c.minY, c.maxX)
        var st = strips(pts, sharp: c.sharp, loop: true, maxSeg: max(0.006, size / 24))
        occlusion(&st, edges: pts, loop: true, wall: true, radius: max(0.02, size * 0.25))
        let m = path.count
        var tan: [V2] = [], arc: [Float] = [0]
        for i in 0..<m {
            let a = path[max(0, i - 1)], b = path[min(m - 1, i + 1)]
            tan.append(simd_normalize(b - a))
            if i > 0 { arc.append(arc[i - 1] + simd_distance(path[i], path[i - 1])) }
        }
        let up = tan.map { V2(-$0.y, $0.x) }
        var s = Surface(material: material)
        for strip in st {
            let base = UInt32(s.positions.count)
            let row = UInt32(strip.count)
            for k in 0..<m {
                for pv in strip {
                    let q = path[k] + up[k] * pv.p.y
                    let nn = V3(up[k].x * pv.n.y, up[k].y * pv.n.y, pv.n.x)
                    s.add(V3(q.x, q.y, pv.p.x), nn, V2(arc[k], pv.v)); s.occlusion[s.occlusion.count - 1] = pv.ao
                }
            }
            for k in 0..<UInt32(m - 1) { for i in 0..<(row - 1) {
                let a0 = base + k * row + i, a1 = a0 + 1, b0 = a0 + row, b1 = b0 + 1
                s.quad(a0, b0, b1, a1)
            }}
        }
        if caps {
            let tri = Shape2D.triangulate(pts)
            let flip = Shape2D.area(pts) < 0
            for isEnd in [false, true] {
                let k = isEnd ? m - 1 : 0
                let nrm = V3(tan[k].x, tan[k].y, 0) * (isEnd ? 1 : -1)
                let base = UInt32(s.positions.count)
                for p in pts { let q = path[k] + up[k] * p.y; s.add(V3(q.x, q.y, p.x), nrm, V2(p.x, p.y)); s.occlusion[s.occlusion.count - 1] = 0.85 }
                for t in stride(from: 0, to: tri.count, by: 3) {
                    let a = base + tri[t], b = base + tri[t + 1], cc = base + tri[t + 2]
                    if isEnd != flip { s.tri(a, cc, b) } else { s.tri(a, b, cc) }
                }
            }
        }
        s.computeTangents()
        return s
    }

    /// Lathe with creases (column bases, capitals, balusters). Profile x = radius, bottom to top.
    /// `displace(angle, y, r)` pushes points radially (flutes, acanthus) and recomputes those normals.
    public static func lathe(_ profile: ArchProfile, segments: Int = 32, material: MaterialKey, seamTile: Float = 0.3,
                             maxSeg: Float? = nil, displace: ((Float, Float, Float) -> Float)? = nil) -> Surface {
        let pts = profile.points
        let size = profile.maxY - profile.minY
        var st = strips(pts, sharp: profile.sharp, loop: false, maxSeg: maxSeg ?? max(0.015, size / 8))
        occlusion(&st, edges: pts, loop: false, wall: false, radius: max(0.015, profile.maxX * 0.3))
        let maxR = profile.maxX
        let circ = 2 * .pi * maxR
        let uTotal = circ < seamTile * 0.75 ? circ : max(seamTile, (circ / seamTile).rounded() * seamTile)
        var out = Surface(material: material)
        for strip in st {
            var s = Surface(material: material)
            let row = UInt32(segments + 1)
            for pv in strip {
                for k in 0...segments {
                    let t = Float(k) / Float(segments), a = t * 2 * .pi
                    var r = pv.p.x
                    if let displace, r > 1e-5 { r += displace(a, pv.p.y, r) }
                    s.add(V3(r * cos(a), pv.p.y, -r * sin(a)), V3(pv.n.x * cos(a), pv.n.y, -pv.n.x * sin(a)), V2(t * uTotal, pv.v))
                    s.occlusion[s.occlusion.count - 1] = pv.ao
                }
            }
            for i in 0..<UInt32(strip.count - 1) { for k in 0..<UInt32(segments) {
                let a = i * row + k
                s.quad(a, a + 1, a + row + 1, a + row)
            }}
            if displace != nil { s.recomputeNormals() }
            out.append(s)
        }
        out.computeTangents()
        return out
    }

    /// Beveled outline extrusion along Z from `z0` to `z1` (outline in XY). Blocks, keystones, brackets.
    public static func slab(_ outline: [V2], z0: Float, z1: Float, material: MaterialKey, bevel: Float = 0.004) -> Surface {
        var s = Prim.extrude(outline, depth: z1 - z0, bevel: bevel, bevelSegments: 2, material: material)
        let mid = (z0 + z1) / 2
        s.positions = s.positions.map { V3($0.x, $0.y, $0.z + mid) }
        return s
    }

    /// Rounded block centered at `c`.
    public static func block(_ size: V3, at c: V3, radius: Float = 0.004, material: MaterialKey) -> Surface {
        Prim.roundedBox(size, radius: radius, bevelSegments: 2, material: material).transformed(Xform(translation: c))
    }

    /// Shifts the model so it is centered on X/Z with its base at y = 0.
    public static func ground(_ m: Model) -> Model {
        let b = m.bounds
        return m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
    }

    /// Weathering baked into vertex occlusion: rain streaks running down from projections and soot on
    /// sheltered, downward-facing faces. `amount` 0 = fresh-cut stone. Call after the model is assembled.
    public static func weather(_ m: inout Model, seed: UInt64, amount: Float = 0.3) {
        let sd = UInt32(truncatingIfNeeded: seed &* 2654435761 &+ 77)
        for i in m.surfaces.indices {
            var s = m.surfaces[i]
            if s.occlusion.count != s.positions.count { s.occlusion = Array(repeating: 1, count: s.positions.count) }
            for v in s.positions.indices {
                let p = s.positions[v], n = s.normals[v]
                let streak = max(0, Noise.perlin(V3(p.x * 14 + p.z * 9, p.y * 1.2, 0.5), seed: sd) * 1.6
                                 + 0.4 * Noise.perlin(V3(p.x * 40 + p.z * 25, p.y * 3, 2.5), seed: sd &+ 1))
                let sheltered = saturate(-n.y) * 0.8
                let blotch = 0.5 + 0.5 * Noise.perlin(V3(p.x * 3, p.y * 3, p.z * 3), seed: sd &+ 2)
                s.occlusion[v] *= max(0.45, 1 - amount * (0.75 * streak * (0.4 + 0.6 * saturate(n.y + 1)) + sheltered * blotch))
            }
            m.surfaces[i] = s
        }
    }

    /// Volute: a rolled spiral fillet in the XY plane, bulging toward +Z, outer radius `radius`.
    /// Ionic capitals, console and modillion sides.
    public static func volute(radius: Float, turns: Float = 2.25, wire: Float, material: MaterialKey) -> Surface {
        let n = max(16, Int(turns * 14))
        var pts: [V3] = [], radii: [Float] = []
        for i in 0...n {
            let t = Float(i) / Float(n)
            let a = -t * turns * 2 * .pi
            let r = radius * (1 - 0.82 * t) - wire
            pts.append(V3(r * cos(a), r * sin(a), 0)); radii.append(wire * (1 - 0.45 * t))
        }
        var s = Prim.tube(pts, radii: radii, sides: 6, seamTile: 0.05, material: material)
        let eyeR = radius * 0.2
        s.append(Prim.superellipsoid(V3(eyeR * 2, eyeR * 2, wire * 2), exponent: 2, subdivisions: 2, material: material))
        return s
    }

    /// Egg-and-dart enrichment along X for an ovolo: eggs of `size` (width, height, depth) at `pitch`,
    /// with a thin dart between each pair. `at` is the egg center line (y, z) on the molding face.
    public static func eggAndDart(length: Float, pitch: Float, size: V3, at: V2, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let egg = Prim.superellipsoid(size, exponent: 2.2, subdivisions: 2, material: material)
        let dart = Prim.roundedBox(V3(size.x * 0.12, size.y * 0.9, size.z * 0.8), radius: size.x * 0.05, bevelSegments: 1, material: material)
        let n = max(1, Int((length / pitch).rounded())), p = length / Float(n)
        for i in 0..<n {
            let x = -length / 2 + p * (Float(i) + 0.5)
            s.append(egg, Xform(translation: V3(x, at.x, at.y)))
            if i > 0 { s.append(dart, Xform(translation: V3(x - p / 2, at.x - size.y * 0.05, at.y - size.z * 0.1))) }
        }
        return s
    }

    /// Bead-and-reel enrichment along X for an astragal of radius `r` centered at (y, z) = `at`.
    public static func beadAndReel(length: Float, r: Float, at: V2, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let bead = Prim.superellipsoid(V3(r * 3.2, r * 2.2, r * 2.2), exponent: 2, subdivisions: 2, material: material)
        let reel = Prim.superellipsoid(V3(r * 0.9, r * 2.1, r * 2.1), exponent: 2.4, subdivisions: 2, material: material)
        let pitch = r * 5.2
        let n = max(1, Int((length / pitch).rounded())), p = length / Float(n)
        for i in 0..<n {
            let x = -length / 2 + p * (Float(i) + 0.5)
            s.append(bead, Xform(translation: V3(x - p * 0.12, at.x, at.y)))
            s.append(reel, Xform(translation: V3(x + p * 0.3, at.x, at.y)))
        }
        return s
    }

    /// Carved rosette (flower boss) facing +Y: a domed lathe with `petals` lobes.
    public static func rosette(radius: Float, height: Float, petals: Int = 8, material: MaterialKey) -> Surface {
        var p = ArchProfile(V2(radius, 0))
        p.quarter(height * 0.7, -radius * 0.55, convex: true, segments: 4)
        p.quarter(height * 0.3, -radius * 0.45, convex: true, segments: 3)
        return lathe(p, segments: petals * 4, material: material, seamTile: 0.05, maxSeg: radius / 3) { a, y, r in
            let lobe = 0.5 + 0.5 * cos(a * Float(petals))
            return -r * 0.28 * (1 - lobe) * (1 - y / max(height, 1e-4) * 0.6)
        }
    }

    /// Ring of a regular polygon or circle in the XZ plane, used by lofts.
    public static func circle(_ r: Float, _ n: Int) -> [V2] { (0..<n).map { k in let a = Float(k) / Float(n) * 2 * .pi; return V2(r * cos(a), r * sin(a)) } }
}
