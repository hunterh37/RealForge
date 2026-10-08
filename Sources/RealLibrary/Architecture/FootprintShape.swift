import simd
import Foundation

/// Axis-aligned rectangle on the plan (x, z).
public struct PlanRect: Codable, Hashable, Sendable {
    public var min: V2
    public var max: V2
    public init(min: V2, max: V2) { self.min = simd_min(min, max); self.max = simd_max(min, max) }
    public init(_ x0: Float, _ z0: Float, _ x1: Float, _ z1: Float) { self.init(min: V2(x0, z0), max: V2(x1, z1)) }
    public var size: V2 { max - min }
    public var center: V2 { (min + max) / 2 }
    public var area: Float { size.x * size.y }
    public func contains(_ p: V2, eps: Float = 1e-3) -> Bool {
        p.x >= min.x - eps && p.x <= max.x + eps && p.y >= min.y - eps && p.y <= max.y + eps
    }
    public func inset(_ d: Float) -> PlanRect { PlanRect(min: min + d, max: max - d) }
}

/// One footprint edge; `index` is the facade index used by `FacadeOverride`.
public struct FacadeEdge: Sendable, Hashable {
    public var index: Int
    public var ring: Int
    public var a: V2
    public var b: V2
    public var length: Float { simd_distance(a, b) }
    /// Unit direction a -> b.
    public var tangent: V2 { simd_normalize(b - a) }
    /// Outward normal (away from the building).
    public var normal: V2 { let t = tangent; return V2(-t.y, t.x) }
    public func point(_ s: Float) -> V2 { a + tangent * s }
}

/// Resolved footprint: rings (outer first, courtyard holes after), the facade edges and the
/// rectangular wings that floor plans subdivide.
public struct FootprintShape: Sendable {
    public var rings: [[V2]]
    public var wings: [PlanRect]
    public var edges: [FacadeEdge]

    public init(_ fp: Footprint) {
        var outer: [V2] = [], holes: [[V2]] = [], wings: [PlanRect] = []
        switch fp {
        case .rect(let W, let D):
            outer = [V2(-W / 2, D / 2), V2(W / 2, D / 2), V2(W / 2, -D / 2), V2(-W / 2, -D / 2)]
            wings = [PlanRect(-W / 2, -D / 2, W / 2, D / 2)]
        case .l(let W, let D, let lw0, let bd0):
            let lw = Swift.min(lw0, W - 2), bd = Swift.min(bd0, D - 2)
            outer = [V2(-W / 2, D / 2), V2(W / 2, D / 2), V2(W / 2, D / 2 - bd), V2(-W / 2 + lw, D / 2 - bd), V2(-W / 2 + lw, -D / 2), V2(-W / 2, -D / 2)]
            wings = [PlanRect(-W / 2, D / 2 - bd, W / 2, D / 2), PlanRect(-W / 2, -D / 2, -W / 2 + lw, D / 2 - bd)]
        case .u(let W, let D, let lw0, let bd0):
            let lw = Swift.min(lw0, W / 2 - 1), bd = Swift.min(bd0, D - 2)
            outer = [V2(-W / 2, D / 2), V2(W / 2, D / 2), V2(W / 2, -D / 2), V2(W / 2 - lw, -D / 2), V2(W / 2 - lw, D / 2 - bd),
                     V2(-W / 2 + lw, D / 2 - bd), V2(-W / 2 + lw, -D / 2), V2(-W / 2, -D / 2)]
            wings = [PlanRect(-W / 2, D / 2 - bd, W / 2, D / 2), PlanRect(-W / 2, -D / 2, -W / 2 + lw, D / 2 - bd), PlanRect(W / 2 - lw, -D / 2, W / 2, D / 2 - bd)]
        case .courtyard(let W, let D, let r0):
            let r = Swift.min(r0, Swift.min(W, D) / 2 - 1)
            outer = [V2(-W / 2, D / 2), V2(W / 2, D / 2), V2(W / 2, -D / 2), V2(-W / 2, -D / 2)]
            holes = [[V2(-W / 2 + r, -D / 2 + r), V2(W / 2 - r, -D / 2 + r), V2(W / 2 - r, D / 2 - r), V2(-W / 2 + r, D / 2 - r)]]
            wings = [PlanRect(-W / 2, D / 2 - r, W / 2, D / 2), PlanRect(-W / 2, -D / 2, W / 2, -D / 2 + r),
                     PlanRect(-W / 2, -D / 2 + r, -W / 2 + r, D / 2 - r), PlanRect(W / 2 - r, -D / 2 + r, W / 2, D / 2 - r)]
        case .polygon(let pts):
            outer = Shape2D.deduped(pts)
            if outer.count >= 2, simd_distance(outer[0], outer[outer.count - 1]) < 1e-4 { outer.removeLast() }
            wings = FootprintShape.decompose(outer)
        }
        if Self.shoelace(outer) > 0 { outer.reverse() }
        holes = holes.map { Self.shoelace($0) < 0 ? $0.reversed() : $0 }
        rings = [outer] + holes
        var edges: [FacadeEdge] = []
        for (ri, ring) in rings.enumerated() {
            for i in ring.indices {
                let a = ring[i], b = ring[(i + 1) % ring.count]
                if simd_distance(a, b) > 1e-3 { edges.append(FacadeEdge(index: edges.count, ring: ri, a: a, b: b)) }
            }
        }
        self.wings = wings
        self.edges = edges
    }

    /// Signed area with the (x, z) shoelace; the outer ring is stored negative (outward = t x up).
    static func shoelace(_ p: [V2]) -> Float {
        var s: Float = 0
        for i in p.indices { let a = p[i], b = p[(i + 1) % p.count]; s += a.x * b.y - b.x * a.y }
        return s / 2
    }

    public var area: Float { rings.enumerated().reduce(0) { $0 + ($1.offset == 0 ? 1 : -1) * abs(Self.shoelace($1.element)) } }
    public var bounds: PlanRect {
        let o = rings[0]
        return PlanRect(min: o.reduce(V2(.infinity, .infinity)) { simd_min($0, $1) }, max: o.reduce(V2(-.infinity, -.infinity)) { simd_max($0, $1) })
    }

    static func inside(_ p: V2, _ ring: [V2]) -> Bool {
        var c = false
        var j = ring.count - 1
        for i in ring.indices {
            let a = ring[i], b = ring[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { c.toggle() }
            j = i
        }
        return c
    }

    public func contains(_ p: V2) -> Bool {
        guard Self.inside(p, rings[0]) else { return false }
        return !rings.dropFirst().contains { Self.inside(p, $0) }
    }

    /// Distance from `p` to the nearest footprint edge.
    public func boundaryDistance(_ p: V2) -> Float {
        edges.reduce(Float.infinity) { d, e in
            let ab = e.b - e.a, t = saturate(simd_dot(p - e.a, ab) / simd_length_squared(ab))
            return Swift.min(d, simd_distance(p, e.a + ab * t))
        }
    }
    public func onBoundary(_ p: V2, eps: Float = 0.02) -> Bool { boundaryDistance(p) < eps }

    /// Rectangles covering a polygon: cells of the vertex-coordinate grid whose centers are inside,
    /// merged into row runs, then runs with the same x span merged vertically.
    static func decompose(_ ring: [V2]) -> [PlanRect] {
        guard ring.count >= 3 else { return [] }
        let xs = Array(Set(ring.map { ($0.x * 1000).rounded() / 1000 })).sorted()
        let zs = Array(Set(ring.map { ($0.y * 1000).rounded() / 1000 })).sorted()
        var runs: [PlanRect] = []
        for j in 0..<(zs.count - 1) {
            var start: Int? = nil
            for i in 0...(xs.count - 1) {
                let inside = i < xs.count - 1 && Self.inside(V2((xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2), ring)
                if inside, start == nil { start = i }
                if !inside, let s = start { runs.append(PlanRect(xs[s], zs[j], xs[i], zs[j + 1])); start = nil }
            }
        }
        var merged: [PlanRect] = []
        for r in runs {
            if let k = merged.firstIndex(where: { abs($0.min.x - r.min.x) < 1e-3 && abs($0.max.x - r.max.x) < 1e-3 && abs($0.max.y - r.min.y) < 1e-3 }) {
                merged[k].max.y = r.max.y
            } else { merged.append(r) }
        }
        return merged
    }
}
