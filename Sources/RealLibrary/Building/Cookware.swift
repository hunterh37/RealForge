import simd
import Foundation

// Cookware construction: thin-walled lathed vessels with real wall thickness, cut or rolled rims,
// the inner floor as its own surface, and helpers for riveted handles.

/// How a vessel wall ends at the top.
public enum VesselRim: Sendable {
    /// Cut edge rounded over the wall thickness (tri-ply skillets, cast iron).
    case cut
    /// Edge curled outward into a hollow bead of this radius (bowls, sheet pans, saucepans).
    case rolled(Float)
}

/// A thin-walled vessel turned about +Y. `inner` is the cooking surface from the axis on the floor,
/// `(0, floorY)`, out along the floor and up the wall to the rim. The outer surface is `inner` offset
/// outward by `wall`, so the base sits at `floorY - wall`.
public struct Vessel: Sendable {
    public var inner: [V2]
    public var wall: Float
    /// Radius of the flat floor; the floor is split off as its own surface here.
    public var floorRadius: Float
    public var rim: VesselRim

    public init(inner: [V2], wall: Float, floorRadius: Float, rim: VesselRim = .cut) {
        self.inner = Shape2D.deduped(inner); self.wall = wall; self.floorRadius = floorRadius; self.rim = rim
    }

    /// Outward normals of the inner polyline (right of the direction of travel).
    func normals(_ p: [V2]) -> [V2] {
        p.indices.map { i in
            let a = p[max(0, i - 1)], b = p[min(p.count - 1, i + 1)]
            let d = simd_normalize(b - a)
            return V2(d.y, -d.x)
        }
    }

    /// The outer surface, rim to base order reversed (axis first), offset by `wall`.
    public var outer: [V2] {
        let n = normals(inner)
        return inner.indices.map { i in
            var q = inner[i] + n[i] * wall
            if i == 0 { q.x = 0 }
            return q
        }
    }

    /// Height of the floor's top (inner surface at the axis).
    public var floorY: Float { inner.first?.y ?? 0 }
    /// Height of the highest point of the rim.
    public var rimTop: Float { lipPoints().map(\.y).max() ?? (inner.last?.y ?? 0) }
    /// Outermost radius of the rim.
    public var rimOuterRadius: Float { max(lipPoints().map(\.x).max() ?? 0, outer.map(\.x).max() ?? 0) }

    /// Inner-surface radius at height `y` on the wall.
    public func innerRadius(at y: Float) -> Float { Vessel.radius(of: inner, at: y) }
    /// Outer-surface radius at height `y` on the wall.
    public func outerRadius(at y: Float) -> Float { Vessel.radius(of: outer, at: y) }
    /// Inner wall normal (pointing into the vessel, toward the axis) at height `y`, in the XY half-plane.
    public func innerNormal(at y: Float) -> V2 {
        let n = normals(inner)
        for i in 1..<inner.count where inner[i].y >= y && inner[i - 1].y <= y && inner[i].y > inner[i - 1].y { return -simd_normalize(n[i] + n[i - 1]) }
        return V2(-1, 0)
    }

    static func radius(of p: [V2], at y: Float) -> Float {
        for i in 1..<p.count where (p[i - 1].y - y) * (p[i].y - y) <= 0 && p[i].y != p[i - 1].y && p[i].x > 0.001 {
            let t = (y - p[i - 1].y) / (p[i].y - p[i - 1].y)
            return p[i - 1].x + (p[i].x - p[i - 1].x) * t
        }
        return p.last?.x ?? 0
    }

    /// Lip curve from the outer wall over the top to the inner rim point (profile order).
    func lipPoints(segments: Int = 8) -> [V2] {
        guard inner.count >= 2 else { return [] }
        let top = inner[inner.count - 1], prev = inner[inner.count - 2]
        let d = simd_normalize(top - prev), n = V2(d.y, -d.x)
        switch rim {
        case .cut:
            let r = wall / 2, c = top + n * r
            return (0...segments).map { k in
                let t = Float(k) / Float(segments) * .pi
                return c + (n * cos(t) + d * sin(t)) * r
            }
        case .rolled(let b):
            // Curl from the inner top point over and around a bead of radius b, tucking back to the wall.
            let c = top + n * b
            let alpha = acos(max(-1, min(1, 1 - wall / b)))
            let phiMax = 2 * Float.pi - alpha
            let steps = max(segments * 2, 12)
            let pts = (0...steps).map { k -> V2 in
                let phi = Float(k) / Float(steps) * phiMax
                return c + (-n * cos(phi) + d * sin(phi)) * b
            }
            return pts.reversed()
        }
    }

    /// Closed profile split into (points, role) runs: base, outerWall, lip, innerWall, floor.
    public enum Role: Sendable { case base, outerWall, lipOuter, edge, lipInner, innerWall, floor }

    /// Lathe surfaces for the whole vessel. `baseUpTo` splits the outer surface: below it `base`
    /// material (heat tint, seasoning), above it `exterior`. `edge` colors the middle of a cut lip
    /// (tri-ply core); nil keeps it `exterior`. `planarFloor` maps the floor with planar UVs (cast
    /// patterns); the default lathe UVs run around the floor (spin finish).
    public func surfaces(segments: Int = 96, interior: MaterialKey, exterior: MaterialKey, base: MaterialKey? = nil,
                         baseUpTo: Float = 0, edge: MaterialKey? = nil, floorMaterial: MaterialKey? = nil,
                         seamTile: Float = 0.3, planarFloor: Bool = false) -> [(Role, Surface)] {
        var runs: [(Role, [V2])] = []
        let out = outer
        let lip = lipPoints()
        // Outer: axis -> rim (stop below the lip join for rolled rims).
        var outerPts = out
        if case .rolled = rim, let join = lip.first {
            outerPts = out.filter { $0.y < join.y - 1e-4 }
            outerPts.append(join)
        }
        let split = base != nil ? baseUpTo : -1
        var basePts: [V2] = [], wallPts: [V2] = []
        for p in outerPts { if split >= 0 && p.y <= split && wallPts.isEmpty { basePts.append(p) } else { wallPts.append(p) } }
        if !basePts.isEmpty && !wallPts.isEmpty {
            // Insert the exact split point on both runs.
            let a = basePts.last!, b = wallPts.first!
            let t = (split - a.y) / max(1e-6, b.y - a.y)
            let s = a + (b - a) * max(0, min(1, t))
            basePts.append(s); wallPts.insert(s, at: 0)
        }
        if !basePts.isEmpty { runs.append((.base, basePts)) }
        if case .rolled = rim {
            if !wallPts.isEmpty { runs.append((.outerWall, wallPts)) }
            runs.append((.lipOuter, lip))
        } else {
            if !wallPts.isEmpty { runs.append((.outerWall, wallPts)) }
            let n = lip.count, a = n * 4 / 10, b = n * 6 / 10
            if edge != nil {
                runs.append((.lipOuter, Array(lip[0...a]))); runs.append((.edge, Array(lip[a...b]))); runs.append((.lipInner, Array(lip[b...])))
            } else {
                runs.append((.lipOuter, lip))
            }
        }
        // Inner: rim -> floor edge -> axis.
        let inv = Array(inner.reversed())
        var wall: [V2] = [], floor: [V2] = []
        for p in inv { if p.x > floorRadius + 1e-5 && floor.isEmpty { wall.append(p) } else { floor.append(p) } }
        if let a = wall.last, let b = floor.first, b.x < floorRadius - 1e-5 {
            let t = (a.x - floorRadius) / max(1e-6, a.x - b.x)
            let s = a + (b - a) * t
            wall.append(s); floor.insert(s, at: 0)
        } else if let b = floor.first { wall.append(b) }
        runs.append((.innerWall, wall))
        runs.append((.floor, floor))
        return runs.compactMap { role, pts in
            let p = Shape2D.deduped(pts)
            guard p.count >= 2 else { return nil }
            let mat: MaterialKey
            switch role {
            case .base: mat = base ?? exterior
            case .outerWall, .lipOuter: mat = exterior
            case .edge: mat = edge ?? exterior
            case .lipInner, .innerWall: mat = interior
            case .floor: mat = floorMaterial ?? interior
            }
            var s = Prim.lathe(p, segments: segments, seamTile: seamTile, material: mat)
            if planarFloor && role == .floor {
                // Planar meters instead of lathe UVs, so cell patterns do not pinch toward the axis.
                s.uvs = s.positions.map { V2($0.x + 0.5, -$0.z + 0.5) }
                s.computeTangents()
            }
            return (role, s)
        }
    }
}

/// U-channel cross-section (stay-cool handles): open underneath, `width` across, `height` tall, sheet `t`
/// thick, in sweep profile coordinates (x up, y across).
public func channelSection(width: Float, height: Float, thickness t: Float, segments: Int = 10) -> [V2] {
    var p: [V2] = []
    let w = width / 2
    for k in 0...segments {               // outer arch, +y to -y over the top
        let a = Float(k) / Float(segments) * .pi
        p.append(V2(sin(a) * height, cos(a) * w))
    }
    p.append(V2(-t * 0.3, -w + t * 0.5))  // rounded lip
    for k in 0...segments {               // inner arch back
        let a = .pi - Float(k) / Float(segments) * .pi
        p.append(V2(sin(a) * (height - t), cos(a) * (w - t)))
    }
    p.append(V2(-t * 0.3, w - t * 0.5))
    return p
}

/// Flat-head pan rivet: a low dome of `radius` on a surface with normal `n` (inside the pan the heads are
/// nearly flush, so `height` stays small).
public func panRivet(_ m: inout Model, at p: V3, normal n: V3, radius: Float = 0.0042, height: Float = 0.0011,
                     material: MaterialKey) {
    var prof: [V2] = [V2(0, -0.0008), V2(radius, -0.0008), V2(radius, 0)]
    for k in 1...4 { let t = Float(k) / 4 * .pi / 2; prof.append(V2(radius * cos(t), height * sin(t))) }
    m.add(Prim.lathe(prof, segments: 16, seamTile: 0.03, material: material), Xform(translation: p, rotation: facing(n)))
}

/// Where a stay-cool handle ends up (vessel axis at the origin).
public struct HandleLayout: Sendable {
    /// Centerline of the channel, wall to loop.
    public var path: [V3]
    /// Center of the hang loop and the handle direction at the end.
    public var loopCenter: V3
    public var direction: V3
    /// Farthest +X reach of the loop.
    public var maxX: Float
    /// A point on the handle top about two thirds along.
    public var grip: V3
}

/// Layout of a riveted stay-cool handle mounted on `vessel` at height `mountY`, running +X for `length`
/// and rising `rise` meters.
public func stayCoolHandleLayout(vessel v: Vessel, mountY: Float, length L: Float, rise: Float) -> HandleLayout {
    let s = V3(v.outerRadius(at: mountY) + 0.003, mountY, 0)
    let ctrl = [s, s + V3(0.105 * L, 0.256 * rise, 0), s + V3(0.316 * L, 0.58 * rise, 0), s + V3(0.553 * L, 0.837 * rise, 0), s + V3(0.79 * L, rise, 0)]
    let path = catmull(ctrl, per: 4)
    let e = path[path.count - 1], t = simd_normalize(e - path[path.count - 2])
    let lc = e + t * 0.016 + V3(0, 0.0045, 0)
    return HandleLayout(path: path, loopCenter: lc, direction: t, maxX: lc.x + t.x * (0.0165 + 0.0045),
                        grip: path[path.count * 2 / 3] + V3(0, 0.011, 0))
}

/// Riveted stay-cool handle: a bracket bent to the wall, two rivets with flat heads inside the vessel,
/// a U-channel flaring toward a hang loop. Vessel axis at the origin, handle along +X.
public func stayCoolHandle(_ m: inout Model, vessel v: Vessel, layout l: HandleLayout, width: Float = 0.024, height: Float = 0.011,
                           material: MaterialKey, detail: Bool) {
    let hy = l.path[0].y
    let ro = v.outerRadius(at: hy)
    var plate = Prim.superellipsoid(V3(0.026, 0.0065, 0.034), exponent: 3.2, subdivisions: detail ? 8 : 4, material: material)
    plate.deform { p in V3(p.x, p.y - p.z * p.z / (2 * ro), p.z) }
    let n2 = -v.innerNormal(at: hy)
    m.add(plate, Xform(translation: V3(ro + 0.0026, hy, 0), rotation: facing(simd_normalize(V3(n2.x, n2.y, 0)))))
    if detail {
        let ri = v.innerRadius(at: hy)
        for z: Float in [-0.0105, 0.0105] {
            let x = sqrt(ri * ri - z * z)
            let n = simd_normalize(V3(-n2.x * x / ri, -n2.y, -n2.x * z / ri))
            panRivet(&m, at: V3(x, hy, z) - n * 0.0002, normal: n, material: material)
            let xo = sqrt((ro + 0.0058) * (ro + 0.0058) - z * z)
            rivet(&m, at: V3(xo, hy, z), normal: simd_normalize(V3(xo, n2.y * ro, z)), radius: 0.0034, height: 0.0012, segments: 12, material: material)
        }
    }
    let path = l.path
    let scales = path.indices.map { i -> Float in 0.82 + 0.26 * Float(i) / Float(path.count - 1) }
    m.add(Prim.sweep(channelSection(width: width, height: height, thickness: 0.0022, segments: detail ? 10 : 5), along: path, up: .up,
                     scales: scales, grainAlongPath: true, material: material))
    let t = l.direction, z = V3(0, 0, 1), up = simd_normalize(simd_cross(z, t))
    let n = detail ? 28 : 14
    let loop = (0..<n).map { k -> V3 in
        let a = Float(k) / Float(n) * 2 * .pi
        return l.loopCenter + t * (0.0165 * cos(a)) + z * (0.0098 * (1 + 0.22 * cos(a)) * sin(a))
    }
    m.add(Prim.sweep(Shape2D.roundedRect(0.0058, 0.009, radius: 0.0026, segments: detail ? 3 : 1), along: loop, up: up,
                     closedPath: true, grainAlongPath: true, material: material))
}

/// Domed pot lid as a thin shell with a rolled edge bead, axis +Y. `radius` is the outer edge, `seatY`
/// the bottom of the bead, `dome` the rise of the center above the bead top.
public func domedLidProfile(radius R: Float, seatY: Float, dome: Float, shell: Float = 0.0008, bead b: Float = 0.0022) -> [V2] {
    let top = seatY + 2 * b
    func yTop(_ r: Float) -> Float { top + dome * (1 - pow(r / (R - b), 2)) }
    var p: [V2] = []
    let n = 7
    for k in 0..<n { let r = (R - 3 * b) * Float(k) / Float(n); p.append(V2(r, yTop(r) - shell)) }   // underside, center -> edge
    p.append(V2(R - 3 * b, yTop(R - 3 * b) - shell - 0.0005))
    for k in 0...8 { let a = -Float.pi / 2 + Float(k) / 8 * .pi; p.append(V2(R - b + cos(a) * b, seatY + b + sin(a) * b)) }   // bead
    for k in stride(from: n, through: 0, by: -1) { let r = (R - b) * Float(k) / Float(n); p.append(V2(r, yTop(r))) }        // top, edge -> center
    return Shape2D.deduped(p)
}

/// Loop handle for a lid: a flat strap arch along X with riveted feet, standing on a lid whose top
/// surface height is `surfaceY(r)`.
public func lidLoopHandle(_ m: inout Model, span: Float = 0.064, height: Float = 0.022, surfaceY: (Float) -> Float,
                          material: MaterialKey, detail: Bool) {
    let h = span / 2
    let y0 = surfaceY(h)
    let ctrl = [V3(-h, y0 + 0.0015, 0), V3(-h * 0.93, y0 + height * 0.55, 0), V3(-h * 0.55, y0 + height, 0), V3(h * 0.55, y0 + height, 0),
                V3(h * 0.93, y0 + height * 0.55, 0), V3(h, y0 + 0.0015, 0)]
    let path = catmull(ctrl, per: detail ? 5 : 3)
    m.add(Prim.sweep(Shape2D.roundedRect(0.013, 0.0032, radius: 0.0014, segments: detail ? 2 : 1), along: path, up: V3(0, 0, 1),
                     grainAlongPath: true, material: material))
    for s: Float in [-1, 1] {
        let x = s * h
        m.add(Prim.superellipsoid(V3(0.016, 0.003, 0.016), exponent: 3, subdivisions: detail ? 5 : 3, material: material),
              Xform(translation: V3(x, surfaceY(abs(x)) + 0.0012, 0)))
        if detail { rivet(&m, at: V3(x, surfaceY(abs(x)) + 0.0026, 0), normal: .up, radius: 0.0028, height: 0.001, segments: 10, material: material) }
    }
}
