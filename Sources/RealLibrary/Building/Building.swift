import simd
import Foundation

// Shared construction helpers for assets. Public so asset packs outside this module can use them.

/// Board along +X centered at origin with beveled edges; grain runs along its length (U).
public func plank(_ length: Float, _ width: Float, _ thick: Float, bevel: Float = 0.004, material: MaterialKey) -> Surface {
    Prim.roundedBox(V3(length, thick, width), radius: bevel, bevelSegments: 2, material: material)
}

/// Board placed between two points (its long axis), with `up` hint for its face normal.
public func board(from a: V3, to b: V3, width: Float, thick: Float, up: V3 = .up, bevel: Float = 0.004, material: MaterialKey, extend: Float = 0) -> (Surface, Xform) {
    let d = b - a, len = simd_length(d) + extend * 2
    let x = d / simd_length(d)
    var y = up - x * simd_dot(up, x)
    y = simd_length(y) < 1e-4 ? x.anyPerpendicular : simd_normalize(y)
    let z = simd_cross(x, y)
    return (plank(len, width, thick, bevel: bevel, material: material), Xform(translation: (a + b) / 2, rotation: simd_quatf(simd_float3x3(x, y, z))))
}

/// Vertical lathe from (radius, y) pairs.
public func turned(_ profile: [(Float, Float)], segments: Int = 40, material: MaterialKey, seamTile: Float = 0.25, grainVertical: Bool = false) -> Surface {
    Prim.lathe(profile.map { V2($0.0, $0.1) }, segments: segments, seamTile: seamTile, material: material, swapUV: grainVertical)
}

/// Contact-shadow AO toward the ground for a whole model.
public func groundAO(_ m: inout Model, height: Float = 0.25, floor: Float = 0.5) {
    for i in m.surfaces.indices {
        m.surfaces[i].occlusion = m.surfaces[i].positions.map { floor + (1 - floor) * smoothstep(0, height, $0.y) }
        m.surfaces[i].bakeCavityAO(strength: 0.6, floor: 0.6)
    }
}

public extension Xform {
    /// Tiny per-board rotation/offset so assembled props don't look CAD-perfect.
    func jittered(_ rng: inout SeededRNG, deg: Float = 0.6, offset: Float = 0.0015) -> Xform {
        var x = self
        x.rotation = simd_quatf(degrees: rng.float(-deg...deg), axis: rng.unitVector()) * x.rotation
        x.translation += rng.unitVector() * offset
        return x
    }
}

/// Catmull-Rom resample through control points.
public func catmull(_ p: [V3], per: Int) -> [V3] {
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
