import Foundation
import simd
import RealCore

/// One cross-section of a loft: an oriented superellipse with separate dorsal and ventral depth.
public struct LoftSection: Sendable {
    public var center: V3
    /// Unit vector toward u = 0.25 (the animal's right).
    public var right: V3
    /// Unit vector toward u = 0 (dorsal).
    public var up: V3
    public var halfWidth: Float
    public var halfDorsal: Float
    public var halfVentral: Float
    /// Superellipse exponent: 2 ellipse, above 2 boxier.
    public var exponent: Float

    public init(center: V3, right: V3, up: V3, halfWidth: Float, halfDorsal: Float, halfVentral: Float? = nil, exponent: Float = 2) {
        self.center = center; self.right = right; self.up = up
        self.halfWidth = halfWidth; self.halfDorsal = halfDorsal; self.halfVentral = halfVentral ?? halfDorsal; self.exponent = exponent
    }
}

/// Lofted bodies with an atlas UV layout: u runs around the section from the dorsal midline (0)
/// through the right flank (0.25) and belly (0.5) to the left flank (0.75), v runs along the loft.
/// Plumage and fur programs (`plumageBody`, `plumageHead`, `furCoat`) read that layout.
public enum Loft {
    /// Sections from `first` to `last` joined by quads. `uv` maps (u around, v along) to texture space.
    public static func build(_ sections: [LoftSection], segments: Int = 20, vRange: ClosedRange<Float> = 0...1,
                             material: MaterialKey, uv: ((Float, Float) -> V2)? = nil, caps: Bool = false) -> Surface {
        precondition(sections.count >= 2)
        var s = Surface(material: material)
        let n = sections.count
        let f = simd_normalize(sections[n - 1].center - sections[0].center)
        let handed = simd_dot(simd_cross(sections[0].right, sections[0].up), f) > 0
        for (i, sec) in sections.enumerated() {
            let v = vRange.lowerBound + (vRange.upperBound - vRange.lowerBound) * Float(i) / Float(n - 1)
            let e = 2 / max(sec.exponent, 0.5)
            for k in 0...segments {
                let u = Float(k) / Float(segments)
                let phi = u * 2 * .pi
                let sn = sin(phi), cs = cos(phi)
                let sx = sn < 0 ? -pow(-sn, e) : pow(sn, e)
                let cy = cs < 0 ? -pow(-cs, e) : pow(cs, e)
                let hy = cs >= 0 ? sec.halfDorsal : sec.halfVentral
                let p = sec.center + sec.right * (sec.halfWidth * sx) + sec.up * (hy * cy)
                s.add(p, sec.up, uv?(u, v) ?? V2(u, v))
            }
        }
        let row = UInt32(segments + 1)
        for i in 0..<(n - 1) { for k in 0..<segments {
            let a = UInt32(i) * row + UInt32(k)
            if handed { s.quad(a, a + row, a + row + 1, a + 1) } else { s.quad(a, a + 1, a + row + 1, a + row) }
        }}
        if caps {
            // Close both ends with a fan to the section centre so no opening shows at a seam.
            for (i, sec) in [(0, sections[0]), (n - 1, sections[n - 1])] {
                let v = vRange.lowerBound + (vRange.upperBound - vRange.lowerBound) * Float(i) / Float(n - 1)
                let c = UInt32(s.positions.count)
                s.add(sec.center, sec.up, uv?(0.5, v) ?? V2(0.5, v))
                let r0 = UInt32(i) * row
                for k in 0..<UInt32(segments) {
                    let flip = (i == 0) != handed
                    if flip { s.tri(c, r0 + k + 1, r0 + k) } else { s.tri(c, r0 + k, r0 + k + 1) }
                }
            }
        }
        s.recomputeNormals()
        s.computeTangents()
        return s
    }

    /// Frames along a polyline: `up` is the dorsal hint, projected perpendicular to the path. `radius`
    /// gives (halfWidth, halfDorsal, halfVentral) at t in 0...1.
    public static func along(_ path: [V3], up hint: V3, count: Int, segments: Int = 20, vRange: ClosedRange<Float> = 0...1,
                             exponent: Float = 2, material: MaterialKey, radius: (Float) -> V3,
                             uv: ((Float, Float) -> V2)? = nil) -> Surface {
        let pts = resample(path, count: count)
        var secs: [LoftSection] = []
        for (i, p) in pts.enumerated() {
            let t = Float(i) / Float(count - 1)
            let a = pts[max(0, i - 1)], b = pts[min(count - 1, i + 1)]
            let f = simd_normalize(b - a)
            var u = hint - f * simd_dot(hint, f)
            if simd_length(u) < 1e-5 { u = f.anyPerpendicular }
            u = simd_normalize(u)
            let r = radius(t)
            secs.append(LoftSection(center: p, right: simd_normalize(simd_cross(f, u)), up: u, halfWidth: r.x, halfDorsal: r.y, halfVentral: r.z, exponent: exponent))
        }
        return build(secs, segments: segments, vRange: vRange, material: material, uv: uv)
    }

    /// Ellipsoid with semi-axes (width, up, length) along `axis`.
    public static func ellipsoid(center: V3, axis: V3, up hint: V3, radii: V3, rings: Int = 8, segments: Int = 14, material: MaterialKey,
                                 uv: ((Float, Float) -> V2)? = nil) -> Surface {
        let f = simd_normalize(axis)
        var u = hint - f * simd_dot(hint, f)
        if simd_length(u) < 1e-5 { u = f.anyPerpendicular }
        u = simd_normalize(u)
        let r = simd_normalize(simd_cross(f, u))
        var secs: [LoftSection] = []
        for i in 0..<rings {
            let t = Float(i) / Float(rings - 1)
            let z = (t * 2 - 1) * 0.985
            let k = max(0.04, (1 - z * z).squareRoot())
            secs.append(LoftSection(center: center + f * (z * radii.z), right: r, up: u, halfWidth: radii.x * k, halfDorsal: radii.y * k))
        }
        return build(secs, segments: segments, material: material, uv: uv)
    }

    /// Resamples a polyline to `count` points evenly by arc length (Catmull-Rom through the input).
    public static func resample(_ path: [V3], count: Int) -> [V3] {
        guard path.count > 2 else {
            guard path.count == 2 else { return path }
            return (0..<count).map { lerp(path[0], path[1], Float($0) / Float(count - 1)) }
        }
        let dense = catmullRom(path, per: 12)
        var acc: [Float] = [0]
        for i in 1..<dense.count { acc.append(acc[i - 1] + simd_distance(dense[i], dense[i - 1])) }
        let total = acc[acc.count - 1]
        var out: [V3] = []
        var j = 0
        for i in 0..<count {
            let d = total * Float(i) / Float(count - 1)
            while j < dense.count - 2 && acc[j + 1] < d { j += 1 }
            let span = max(acc[j + 1] - acc[j], 1e-9)
            out.append(lerp(dense[j], dense[j + 1], saturate((d - acc[j]) / span)))
        }
        return out
    }

    public static func catmullRom(_ p: [V3], per: Int) -> [V3] {
        guard p.count > 2 else { return p }
        var out: [V3] = []
        for i in 0..<(p.count - 1) {
            let p0 = p[max(0, i - 1)], p1 = p[i], p2 = p[i + 1], p3 = p[min(p.count - 1, i + 2)]
            for k in 0..<per {
                let t = Float(k) / Float(per), t2 = t * t, t3 = t2 * t
                let a = 2 * p1, b = p2 - p0, c = 2 * p0 - 5 * p1 + 4 * p2 - p3, d = -p0 + 3 * p1 - 3 * p2 + p3
                out.append(0.5 * (a + b * t + c * t2 + d * t3))
            }
        }
        out.append(p[p.count - 1])
        return out
    }
}

/// Piecewise-linear profile through (t, value) pairs, eased with smoothstep between knots.
public struct Profile: Sendable {
    public var knots: [V2]
    public init(_ knots: [V2]) { self.knots = knots.sorted { $0.x < $1.x } }
    public init(_ values: [Float]) {
        knots = values.enumerated().map { V2(Float($0.offset) / Float(max(1, values.count - 1)), $0.element) }
    }
    public func callAsFunction(_ t: Float) -> Float {
        guard let f = knots.first, let l = knots.last else { return 0 }
        if t <= f.x { return f.y }
        if t >= l.x { return l.y }
        for i in 0..<(knots.count - 1) where t <= knots[i + 1].x {
            let a = knots[i], b = knots[i + 1]
            let k = (t - a.x) / max(b.x - a.x, 1e-6)
            return a.y + (b.y - a.y) * (k * k * (3 - 2 * k) * 0.6 + k * 0.4)
        }
        return l.y
    }
}
