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

/// Contact AO for every piece of a rig (base and all part options), measured at rest in asset space.
public func groundAO(_ rig: inout Rig, height: Float = 0.25, floor: Float = 0.5) {
    for l in rig.base.indices { groundAO(&rig.base[l], height: height, floor: floor) }
    for i in rig.parts.indices {
        for l in rig.parts[i].levels.indices { groundAO(&rig.parts[i].levels[l], height: height, floor: floor) }
        for o in rig.parts[i].alternates.indices { for l in rig.parts[i].alternates[o].indices { groundAO(&rig.parts[i].alternates[o][l], height: height, floor: floor) } }
    }
}

/// Sharp 12-triangle box centered at the origin, planar UVs in meters. For hidden or tiny parts
/// (drawer contents, file folders, shims) where a bevel would never be seen.
public func cuboid(_ size: V3, material: MaterialKey) -> Surface {
    var s = Surface(material: material)
    let h = size / 2
    let faces: [(V3, V3, V3)] = [(V3(1, 0, 0), V3(0, 0, -1), V3(0, 1, 0)), (V3(-1, 0, 0), V3(0, 0, 1), V3(0, 1, 0)),
                                 (V3(0, 1, 0), V3(1, 0, 0), V3(0, 0, -1)), (V3(0, -1, 0), V3(1, 0, 0), V3(0, 0, 1)),
                                 (V3(0, 0, 1), V3(1, 0, 0), V3(0, 1, 0)), (V3(0, 0, -1), V3(-1, 0, 0), V3(0, 1, 0))]
    for (n, u, v) in faces {
        let c = n * h, eu = u * h, ev = v * h
        let pts = [c - eu - ev, c + eu - ev, c + eu + ev, c - eu + ev]
        let base = UInt32(s.positions.count)
        for p in pts { s.add(p, n, V2(simd_dot(p, u), simd_dot(p, v))) }
        s.quad(base, base + 1, base + 2, base + 3)
    }
    s.computeTangents()
    return s
}
