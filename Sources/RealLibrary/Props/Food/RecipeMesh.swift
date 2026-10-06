import simd
import RealCore

/// Closed-shell builders for the recipe food pack on top of `FoodMesh`: flat slabs from a plan outline
/// (slices, wedges, tortillas), swept bodies with a varying cross-section along a curved path (fat
/// caps, shrimp, bananas, scallion leaves), leaf blades, and an outward-winding guard.
public enum RecipeMesh {
    /// Signed volume of a closed surface (positive when it winds outward).
    public static func volume(_ s: Surface) -> Float {
        var v: Float = 0
        for t in stride(from: 0, to: s.indices.count, by: 3) {
            let a = s.positions[Int(s.indices[t])], b = s.positions[Int(s.indices[t + 1])], c = s.positions[Int(s.indices[t + 2])]
            v += simd_dot(a, simd_cross(b, c)) / 6
        }
        return v
    }

    /// Returns `s` wound outward (flips it when its signed volume is negative).
    public static func outward(_ s: Surface) -> Surface { volume(s) < 0 ? s.flipped() : s }

    /// Closed loop in the XZ plane (no repeated end point), counterclockwise seen from +Y in the
    /// FoodMesh sense (x = r cos a, z = -r sin a).
    public static func loop(count: Int = 256, radius: (Float) -> Float) -> [V2] {
        (0..<count).map { k in
            let a = Float(k) / Float(count) * 2 * .pi
            let r = radius(a)
            return V2(r * cos(a), -r * sin(a))
        }
    }

    /// Offsets a closed loop along its 2D normals (positive = outward for loops built by `loop`).
    public static func offsetLoop(_ pts: [V2], by d: Float) -> [V2] {
        let n = pts.count
        var area: Float = 0
        for i in 0..<n { let a = pts[i], b = pts[(i + 1) % n]; area += a.x * b.y - b.x * a.y }
        let sgn: Float = area > 0 ? 1 : -1
        return (0..<n).map { i in
            let t = simd_normalize(pts[(i + 1) % n] - pts[(i + n - 1) % n])
            let nrm = V2(t.y, -t.x) * sgn
            return pts[i] + nrm * d
        }
    }

    /// Flat slab from a plan outline, base at y = 0, thickness `thickness`, every edge rounded at
    /// `bevel` (quarter circles), faces filled with concentric rings so they carry interior vertices.
    /// UVs are planar meters (x, z).
    public static func slab(outline: [V2], thickness: Float, bevel: Float, edge: Float, bevelSegments: Int = 3,
                            material: MaterialKey) -> Surface {
        let r = min(bevel, thickness * 0.5 * 0.999)
        let c = outline.reduce(V2.zero, +) / Float(outline.count)
        let inner = offsetLoop(outline, by: -r)
        var rings: [[V3]] = [], vs: [Float] = []
        // Face rings from the centre out: count from the widest radius.
        let rMax = inner.map { simd_distance($0, c) }.max() ?? edge
        let faceRings = max(1, Int((rMax / edge).rounded()))
        func ring(_ base: [V2], scale: Float, y: Float) -> [V3] {
            let pts = base.map { c + ($0 - c) * scale }
            return FoodMesh.resampleLoop(pts, step: edge, minCount: 6).map { V3($0.x, y, $0.y) }
        }
        for k in 1...faceRings { rings.append(ring(inner, scale: Float(k) / Float(faceRings), y: 0)); vs.append(0) }
        // Bottom bevel, straight side, top bevel.
        let sideSteps = max(0, Int(((thickness - 2 * r) / edge).rounded()))
        var profile: [(Float, Float)] = []   // (outward offset from inner, y)
        for k in 1..<bevelSegments { let a = -Float.pi / 2 + Float(k) / Float(bevelSegments) * .pi / 2; profile.append((r * cos(a), r + r * sin(a))) }
        profile.append((r, r))
        for k in 1...max(1, sideSteps) where thickness - 2 * r > 1e-5 { profile.append((r, r + (thickness - 2 * r) * Float(k) / Float(max(1, sideSteps)))) }
        for k in 1..<bevelSegments { let a = Float(k) / Float(bevelSegments) * .pi / 2; profile.append((r * cos(a), thickness - r + r * sin(a))) }
        for (o, y) in profile {
            let pts = offsetLoop(inner, by: o)
            rings.append(FoodMesh.resampleLoop(pts, step: edge, minCount: 6).map { V3($0.x, y, $0.y) }); vs.append(y)
        }
        for k in stride(from: faceRings, through: 1, by: -1) { rings.append(ring(inner, scale: Float(k) / Float(faceRings), y: thickness)); vs.append(thickness) }
        var s = FoodMesh.loft(rings, v: vs, start: V3(c.x, 0, c.y), end: V3(c.x, thickness, c.y), startV: 0, endV: thickness,
                              uTotal: 1, material: material)
        s = outward(s)
        return FoodMesh.planarUV(s)
    }

    /// Closed body swept along `path` (points, at least 2). `section(t, angle)` gives the radius at
    /// path fraction t and angle around the path (0 = `up`, increasing toward the side vector);
    /// `scaleY` squashes along `up`. Ends close at points pushed out by `endBulge` x end radius.
    /// U runs around (meters), V along the path (meters).
    public static func sweep(_ path: [V3], up: V3 = V3(0, 1, 0), edge: Float, endBulge: Float = 0.6, seamTile: Float = 0.05,
                             material: MaterialKey, section: (Float, Float) -> Float) -> Surface {
        // Resample the path to steps of `edge`.
        var cum: [Float] = [0]
        for i in 1..<path.count { cum.append(cum[i - 1] + simd_distance(path[i], path[i - 1])) }
        let L = cum.last!
        let n = max(2, Int((L / edge).rounded()))
        var pts: [V3] = []
        var j = 0
        for i in 0...n {
            let s = L * Float(i) / Float(n)
            while j < path.count - 2 && cum[j + 1] < s { j += 1 }
            let f = (s - cum[j]) / max(cum[j + 1] - cum[j], 1e-9)
            pts.append(path[j] + (path[j + 1] - path[j]) * f)
        }
        var rings: [[V3]] = [], vs: [Float] = []
        var maxPer: Float = 0
        for i in 0...n {
            let t = Float(i) / Float(n)
            let tan = simd_normalize(pts[min(n, i + 1)] - pts[max(0, i - 1)])
            var u = up - tan * simd_dot(up, tan)
            if simd_length(u) < 1e-5 { u = tan.anyPerpendicular }
            u = simd_normalize(u)
            let side = simd_cross(tan, u)
            let outline: [V2] = (0..<128).map { k in
                let a = Float(k) / 128 * 2 * .pi
                let r = max(1e-4, section(t, a))
                return V2(r * cos(a), r * sin(a))
            }
            let loop = FoodMesh.resampleLoop(outline, step: edge, minCount: 6)
            var per: Float = 0
            for k in 0..<loop.count { per += simd_distance(loop[k], loop[(k + 1) % loop.count]) }
            maxPer = max(maxPer, per)
            rings.append(loop.map { pts[i] + u * $0.x + side * $0.y })
            vs.append(L * t)
        }
        let t0 = simd_normalize(pts[1] - pts[0]), t1 = simd_normalize(pts[n] - pts[n - 1])
        let r0 = section(0, 0), r1 = section(1, 0)
        let uTotal = maxPer < seamTile * 0.75 ? maxPer : max(seamTile, (maxPer / seamTile).rounded() * seamTile)
        let s = FoodMesh.loft(rings, v: vs, start: pts[0] - t0 * r0 * endBulge, end: pts[n] + t1 * r1 * endBulge,
                              startV: -r0 * endBulge, endV: L + r1 * endBulge, uTotal: uTotal, material: material)
        return outward(s)
    }

    /// Thin leaf blade along +Y (length `length`), half-width `width(t)`, half-thickness `thickness`.
    /// UVs: u = x + `uCenter` (midrib at u = uCenter meters), v = y.
    public static func blade(length: Float, thickness: Float, edge: Float, uCenter: Float, material: MaterialKey,
                             width: (Float) -> Float) -> Surface {
        var s = FoodMesh.sections(edge: edge, length: length, seamTile: 0.02, material: material) { t in
            (max(1e-4, width(t)), thickness, 3, .zero)
        }
        s.uvs = s.positions.map { V2($0.x + uCenter, $0.y) }
        s.computeTangents()
        return s
    }

    /// Closed polygon (no repeated end point) with each corner filleted at `radius[i]` (0 = sharp),
    /// densified to steps near `step`.
    public static func roundedPolygon(_ pts: [V2], radius: [Float], step: Float) -> [V2] {
        let n = pts.count
        var out: [V2] = []
        for i in 0..<n {
            let p = pts[i], a = pts[(i + n - 1) % n], b = pts[(i + 1) % n]
            let da = simd_normalize(a - p), db = simd_normalize(b - p)
            let ang = acos(max(-1, min(1, simd_dot(da, db))))
            let r = radius[i]
            if r <= 0 || ang > 3.1 { out.append(p); continue }
            let tl = r / tan(ang / 2)
            let s0 = p + da * tl, s1 = p + db * tl
            let bis = simd_normalize(da + db)
            let c = p + bis * (r / sin(ang / 2))
            let a0 = atan2(s0.y - c.y, s0.x - c.x)
            var a1 = atan2(s1.y - c.y, s1.x - c.x)
            var d = a1 - a0
            while d > .pi { d -= 2 * .pi }
            while d < -.pi { d += 2 * .pi }
            a1 = a0 + d
            let k = max(2, Int((abs(d) * r / step).rounded()) + 1)
            for j in 0...k { let t = a0 + d * Float(j) / Float(k); out.append(c + V2(cos(t), sin(t)) * r) }
        }
        // Densify straight runs.
        var dense: [V2] = []
        for i in 0..<out.count {
            let p = out[i], q = out[(i + 1) % out.count]
            let l = simd_distance(p, q)
            let k = max(1, Int((l / step).rounded()))
            for j in 0..<k { dense.append(p + (q - p) * (Float(j) / Float(k))) }
        }
        return dense.enumerated().filter { i, p in simd_distance(p, dense[(i + 1) % dense.count]) > 1e-6 }.map(\.element)
    }

    /// Smoothly varying 3D value noise in -1...1 at frequency `f` (cycles per meter).
    public static func noise(_ p: V3, _ f: Float, seed: UInt32) -> Float { Noise.perlin(p * f, seed: seed) }
}
