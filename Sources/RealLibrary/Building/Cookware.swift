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
    /// (tri-ply core); nil keeps it `exterior`.
    public func surfaces(segments: Int = 96, interior: MaterialKey, exterior: MaterialKey, base: MaterialKey? = nil,
                         baseUpTo: Float = 0, edge: MaterialKey? = nil, floorMaterial: MaterialKey? = nil,
                         seamTile: Float = 0.3) -> [(Role, Surface)] {
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
            return (role, Prim.lathe(p, segments: segments, seamTile: seamTile, material: mat))
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
