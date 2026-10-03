import simd
import Foundation

/// Ribbed cactus stems. Cross-section r(a) = R * (1 - depth + depth * |cos(a * ribs / 2)|^0.6): rounded ribs,
/// sharp V grooves. U runs one texture repeat per rib with the crest at u = 0 (matches `cactusRibs`);
/// V is arc length in meters.
enum CactusMesh {
    static func ribbed(_ path: [V3], radii: [Float], ribs: Int, depth: Float, perRib: Int, tile: Float, material: MaterialKey,
                       twist: Float = 0, weights: [Float]? = nil, phase: Float = 0) -> Surface {
        precondition(path.count >= 2 && radii.count == path.count)
        var s = Surface(material: material)
        let sides = ribs * perRib
        var tangents: [V3] = []
        for i in path.indices { tangents.append((path[min(path.count - 1, i + 1)] - path[max(0, i - 1)]).normalized) }
        // Start frame: a horizontal reference so rib crests line up between stems.
        var normal = simd_normalize(V3(1, 0, 0) - tangents[0] * tangents[0].x)
        if !normal.x.isFinite { normal = tangents[0].anyPerpendicular }
        var v: Float = 0
        for i in path.indices {
            if i > 0 {
                v += simd_distance(path[i], path[i - 1])
                let t0 = tangents[i - 1], t1 = tangents[i]
                let axis = simd_cross(t0, t1), sl = simd_length(axis)
                if sl > 1e-6 { normal = simd_quatf(angle: atan2(sl, simd_dot(t0, t1)), axis: axis / sl).act(normal) }
                normal = simd_normalize(normal - t1 * simd_dot(normal, t1))
            }
            let bin = simd_cross(tangents[i], normal)
            let w = weights?[i] ?? 0
            for k in 0...sides {
                let f = Float(k) / Float(sides)
                let a = f * 2 * .pi + twist * v
                let rib = pow(abs(cos(a * Float(ribs) / 2)), 0.6)
                let r = radii[i] * (1 - depth + depth * rib)
                let dir = normal * cos(a) + bin * sin(a)
                s.add(path[i] + dir * r, dir, V2(f * Float(ribs) * tile, v), extra: V2(w, phase))
            }
        }
        let row = UInt32(sides + 1)
        for i in 0..<(path.count - 1) { for k in 0..<sides {
            let a = UInt32(i) * row + UInt32(k)
            s.quad(a, a + 1, a + row + 1, a + row)
        }}
        // Close the top with a center vertex.
        let last = path.count - 1
        let tip = s.add(path[last] + tangents[last] * radii[last] * 0.3, tangents[last], V2(0, v + radii[last]), extra: V2(weights?.last ?? 0, phase))
        let base = UInt32(last) * row
        for k in 0..<UInt32(sides) { s.tri(base + k, base + k + 1, tip) }
        s.recomputeNormals()
        return s
    }

    /// Samples a path at roughly `spacing` meters, keeping both ends.
    static func resample(_ pts: [V3], spacing: Float) -> [V3] {
        var len: Float = 0
        var acc: [Float] = [0]
        for i in 1..<pts.count { len += simd_distance(pts[i], pts[i - 1]); acc.append(len) }
        let n = max(2, Int((len / spacing).rounded()) + 1)
        var out: [V3] = []
        var j = 0
        for k in 0..<n {
            let target = len * Float(k) / Float(n - 1)
            while j < pts.count - 2 && acc[j + 1] < target { j += 1 }
            let seg = max(acc[j + 1] - acc[j], 1e-6)
            out.append(lerp(pts[j], pts[j + 1], saturate((target - acc[j]) / seg)))
        }
        return out
    }

    /// Arc length at each point.
    static func arcLengths(_ pts: [V3]) -> [Float] {
        var acc: [Float] = [0]
        for i in 1..<pts.count { acc.append(acc[i - 1] + simd_distance(pts[i], pts[i - 1])) }
        return acc
    }

    /// Rounded dome over the last `r` meters of a stem of length `len`.
    static func dome(_ s: Float, len: Float, r: Float) -> Float {
        let x = (s - (len - r)) / r
        return x <= 0 ? 1 : max(0.06, (1 - x * x).squareRoot())
    }
}
