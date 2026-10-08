import simd
import Foundation

/// Geometry accumulator for the generator: one surface per material, world-space planar UVs in meters
/// (walls map u along the wall and v up, so brick and stone courses run continuously across pieces).
public struct MeshBucket: Sendable {
    var surfaces: [MaterialKey: Surface] = [:]
    public init() {}

    public var triangleCount: Int { surfaces.values.reduce(0) { $0 + $1.triangleCount } }

    /// Planar quad p0..p3 (counter-clockwise seen from the front). UVs project on the dominant plane.
    public mutating func quad(_ p0: V3, _ p1: V3, _ p2: V3, _ p3: V3, _ mat: MaterialKey) {
        poly([p0, p1, p2, p3], mat)
    }

    /// Convex planar polygon, counter-clockwise from the front.
    public mutating func poly(_ pts: [V3], _ mat: MaterialKey) {
        guard pts.count >= 3 else { return }
        var n = V3.zero
        for i in 1..<(pts.count - 1) { n += simd_cross(pts[i] - pts[0], pts[i + 1] - pts[0]) }
        guard simd_length(n) > 1e-9 else { return }
        n = simd_normalize(n)
        var s = surfaces[mat] ?? Surface(material: mat)
        let base = UInt32(s.positions.count)
        for p in pts { s.add(p, n, Self.uv(p, n)) }
        for i in 1..<(pts.count - 1) { s.tri(base, base + UInt32(i), base + UInt32(i + 1)) }
        surfaces[mat] = s
    }

    /// Polygon flipped as needed so its normal points along `facing`.
    public mutating func poly(_ pts: [V3], _ mat: MaterialKey, facing f: V3) {
        guard pts.count >= 3 else { return }
        var n = V3.zero
        for i in 1..<(pts.count - 1) { n += simd_cross(pts[i] - pts[0], pts[i + 1] - pts[0]) }
        poly(simd_dot(n, f) < 0 ? pts.reversed() : pts, mat)
    }

    static func uv(_ p: V3, _ n: V3) -> V2 {
        if abs(n.y) > 0.7 { return V2(p.x, -p.z) }
        let t = simd_normalize(V3(-n.z, 0, n.x))
        return V2(simd_dot(p, t), p.y)
    }

    /// Oriented box: `o` origin corner, edges `u`, `v`, `w` (any handedness). Face materials:
    /// `faces(n)` picks per outward normal.
    public mutating func box(_ o: V3, _ u: V3, _ v: V3, _ w: V3, _ mat: (V3) -> MaterialKey) {
        let c = o + (u + v + w) / 2
        let corners: [[V3]] = [[o, o + v, o + v + w, o + w], [o + u, o + u + w, o + u + v + w, o + u + v],
                               [o, o + w, o + u + w, o + u], [o + v, o + u + v, o + u + v + w, o + v + w],
                               [o, o + u, o + u + v, o + v], [o + w, o + w + v, o + u + v + w, o + u + w]]
        for f in corners {
            let fc = (f[0] + f[1] + f[2] + f[3]) / 4
            let out = fc - c
            let n = simd_cross(f[1] - f[0], f[2] - f[0])
            let pts = simd_dot(n, out) < 0 ? f.reversed() : f
            guard simd_length(n) > 1e-10 else { continue }
            poly(Array(pts), mat(simd_normalize(out)))
        }
    }
    public mutating func box(_ o: V3, _ u: V3, _ v: V3, _ w: V3, _ mat: MaterialKey) { box(o, u, v, w) { _ in mat } }

    /// Axis-aligned box from center and size.
    public mutating func aabb(center c: V3, size s: V3, _ mat: MaterialKey) {
        box(c - s / 2, V3(s.x, 0, 0), V3(0, s.y, 0), V3(0, 0, s.z), mat)
    }

    public mutating func add(_ m: Model, _ x: Xform = .identity) {
        for s in m.surfaces {
            var t = surfaces[s.material] ?? Surface(material: s.material)
            t.append(s, x)
            surfaces[s.material] = t
        }
    }

    public func model(_ name: String) -> Model {
        var m = Model(name: name)
        for k in surfaces.keys.sorted() {
            var s = surfaces[k]!
            if s.tangents.count != s.positions.count { s.computeTangents() }
            m.add(s)
        }
        return m
    }
}

/// Frame on a wall: x along the wall, y up, z out of the outer face.
struct WallFrame {
    var origin: V3
    var t: V3
    var n: V3
    var xform: Xform {
        let yaw = atan2(-t.z, t.x)
        return Xform(translation: origin, rotation: simd_quatf(angle: yaw, axis: V3(0, 1, 0)))
    }
    func p(_ s: Float, _ y: Float, _ z: Float) -> V3 { origin + t * s + V3(0, y, 0) + n * z }
}

enum ArchMesh {
    /// Wall boxes between openings. `s0...s1` along the wall, `y0...y1` absolute heights, openings with
    /// sill/head relative to `floorY`. Exterior walls sit inward of the line (z in -t...0); interior walls
    /// are centered. Face materials: outer (+n), inner (-n), reveals and caps use `reveal`.
    static func wall(_ m: inout MeshBucket, seg: WallSegment, s0: Float, s1: Float, y0: Float, y1: Float, floorY: Float,
                     openings: [WallOpening], outer: MaterialKey, inner: MaterialKey, reveal: MaterialKey, solid: Bool = false) {
        let a = V3(seg.a.x, 0, seg.a.y)
        let t = V3(seg.tangent.x, 0, seg.tangent.y), n = V3(seg.normal.x, 0, seg.normal.y)
        let th = seg.thickness
        let zb: Float = seg.exterior ? -th : -th / 2
        var rects: [(Float, Float, Float, Float)] = []
        var s = s0
        let ops = solid ? [] : openings.sorted { $0.center < $1.center }
        for op in ops {
            let lo = Swift.max(s0, op.center - op.width / 2), hi = Swift.min(s1, op.center + op.width / 2)
            guard hi > lo else { continue }
            if lo > s { rects.append((s, lo, y0, y1)) }
            let sy = floorY + op.sill, hy = floorY + op.head
            if sy > y0 + 1e-3 { rects.append((lo, hi, y0, sy)) }
            if hy < y1 - 1e-3 { rects.append((lo, hi, hy, y1)) }
            s = hi
        }
        if s < s1 { rects.append((s, s1, y0, y1)) }
        for (r0, r1, ya, yb) in rects where r1 - r0 > 1e-3 && yb - ya > 1e-3 {
            let o = a + t * r0 + V3(0, ya, 0) + n * zb
            m.box(o, t * (r1 - r0), V3(0, yb - ya, 0), n * th) { f in
                let d = simd_dot(f, n)
                return d > 0.7 ? outer : (d < -0.7 ? inner : reveal)
            }
        }
    }

    /// Profile swept along a closed or open polyline of facade edges with mitered corners. Profile x is
    /// the projection out of the wall face, y the height above `y`.
    static func run(_ m: inout MeshBucket, ring: [V2], closed: Bool, y: Float, profile: [V2], material: MaterialKey, base: Float = 0) {
        let n = ring.count
        guard n >= 2, profile.count >= 2 else { return }
        func normal(_ i: Int) -> V2 { let t = simd_normalize(ring[(i + 1) % n] - ring[i]); return V2(-t.y, t.x) }
        let edgeCount = closed ? n : n - 1
        // Miter vector at each vertex (offset per unit of projection).
        func miter(_ v: Int) -> V2 {
            if !closed && (v == 0 || v == n - 1) { return normal(v == 0 ? 0 : n - 2) }
            let n0 = normal((v - 1 + n) % n), n1 = normal(v % n)
            let d = 1 + simd_dot(n0, n1)
            return d < 0.05 ? n1 : (n0 + n1) / d
        }
        for e in 0..<edgeCount {
            let i0 = e, i1 = (e + 1) % n
            let p0 = ring[i0], p1 = ring[i1], m0 = miter(i0), m1 = miter(i1)
            for k in 0..<(profile.count - 1) {
                let a = profile[k], b = profile[k + 1]
                let q0 = p0 + m0 * (a.x + base), q1 = p1 + m1 * (a.x + base), q2 = p1 + m1 * (b.x + base), q3 = p0 + m0 * (b.x + base)
                m.quad(V3(q0.x, y + a.y, q0.y), V3(q1.x, y + a.y, q1.y), V3(q2.x, y + b.y, q2.y), V3(q3.x, y + b.y, q3.y), material)
            }
        }
    }
}
