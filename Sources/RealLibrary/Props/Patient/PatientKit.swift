import simd
import Foundation
import RealCore

/// Shared tube-frame and hardware helpers for the Patient props (bent tubes with real bend radii,
/// weld beads, braked casters, telescoping lift columns, label quads).
enum PatientKit {
    /// Polyline with every interior corner replaced by a bend of `radius` (mandrel-bent tube).
    static func bend(_ p: [V3], radius: Float, seg: Int = 5) -> [V3] {
        guard p.count > 2 else { return p }
        var out = [p[0]]
        for i in 1..<(p.count - 1) {
            let a = p[i - 1], b = p[i], c = p[i + 1]
            let d0 = simd_normalize(a - b), d1 = simd_normalize(c - b)
            let theta = acos(max(-1, min(1, simd_dot(d0, d1))))
            if theta > .pi - 0.01 { out.append(b); continue }
            let t = min(radius / tan(theta / 2), simd_length(a - b) * 0.49, simd_length(c - b) * 0.49)
            let p0 = b + d0 * t, p1 = b + d1 * t
            for k in 0...seg {
                let s = Float(k) / Float(seg)
                out.append((1 - s) * (1 - s) * p0 + 2 * (1 - s) * s * b + s * s * p1)
            }
        }
        out.append(p[p.count - 1])
        return out
    }

    /// Round tube along a path.
    static func tube(_ path: [V3], r: Float, sides: Int = 12, material: MaterialKey, caps: Bool = true, closed: Bool = false) -> Surface {
        Prim.sweep(Shape2D.circle(r, segments: sides), along: path, closedPath: closed, caps: caps && !closed, material: material)
    }

    /// Straight round rod between two points.
    static func rod(_ a: V3, _ b: V3, r: Float, sides: Int = 12, material: MaterialKey) -> Surface {
        tube([a, b], r: r, sides: sides, material: material)
    }

    /// Rectangular tube or bar between two points (w across, h along `up`), edges rounded at `r`.
    static func bar(_ a: V3, _ b: V3, w: Float, h: Float, r: Float = 0.003, up: V3 = .up, seg: Int = 1, material: MaterialKey) -> Surface {
        let d = b - a, len = simd_length(d)
        let x = d / len
        var y = up - x * simd_dot(up, x)
        y = simd_length(y) < 1e-4 ? x.anyPerpendicular : simd_normalize(y)
        let z = simd_cross(x, y)
        return Prim.roundedBox(V3(len, h, w), radius: r, bevelSegments: seg, material: material)
            .transformed(Xform(translation: (a + b) / 2, rotation: simd_quatf(simd_float3x3(x, y, z))))
    }

    /// Bent-rod pull handle: bar along X at `standoff` in +Z, posts back to z = 0.
    static func pull(length: Float, standoff: Float, r: Float, sides: Int = 8, material: MaterialKey) -> Surface {
        let h = length / 2
        return tube(bend([V3(-h, 0, -0.002), V3(-h, 0, standoff), V3(h, 0, standoff), V3(h, 0, -0.002)], radius: min(0.012, standoff * 0.6), seg: 3),
                    r: r, sides: sides, material: material)
    }

    /// Fillet weld bead ringing a tube of radius `r` at `p` (tube axis `axis`).
    static func weld(at p: V3, axis: V3, r: Float, bead: Float = 0.0016, material: MaterialKey) -> Surface {
        Prim.torus(major: r + bead * 0.3, minor: bead, segments: 12, sides: 4, material: material)
            .transformed(Xform(translation: p, rotation: facing(axis)))
    }

    /// Box centered at `c`.
    static func box(_ size: V3, _ c: V3, r: Float = 0.003, seg: Int = 2, material: MaterialKey) -> Surface {
        Prim.roundedBox(size, radius: r, bevelSegments: seg, material: material).transformed(Xform(translation: c))
    }

    /// Swivel caster from `caster(...)` plus a total-lock brake pedal on the fork top, pointing along `yaw`.
    static func brakedCaster(_ m: inout Model, at p: V3, height: Float, wheelRadius: Float, yaw: Float = 0, pedalYaw: Float? = nil,
                             frame: MaterialKey, wheel: MaterialKey, hub: MaterialKey, pedal: MaterialKey?, detail: Bool) {
        caster(&m, at: p, height: height, wheelRadius: wheelRadius, yaw: yaw, frame: frame, wheel: wheel, hub: hub)
        guard let pedal else { return }
        let q = simd_quatf(degrees: pedalYaw ?? yaw, axis: .up)
        // Lever from the swivel head over the wheel, ending in a ribbed foot pad.
        let y = height - 0.018
        let a = p + V3(0, y, 0), b = p + q.act(V3(-wheelRadius - 0.045, y + 0.004, 0))
        m.add(bar(a, b, w: 0.016, h: 0.006, r: 0.002, material: frame))
        m.add(Prim.roundedBox(V3(0.045, 0.012, 0.03), radius: 0.004, bevelSegments: detail ? 2 : 1, material: pedal),
              Xform(translation: b + V3(0, 0.004, 0), rotation: q))
    }

    /// Flat quad with 0...1 UVs (u along `right`, v down from the top edge), for labels and screens.
    static func panel(_ c: V3, right: V3, up: V3, w: Float, h: Float, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let n = simd_normalize(simd_cross(right, up)), r = right * (w / 2), u = up * (h / 2)
        let a = s.add(c - r - u, n, V2(0, 1)), b = s.add(c + r - u, n, V2(1, 1))
        let d = s.add(c + r + u, n, V2(1, 0)), e = s.add(c - r + u, n, V2(0, 0))
        s.quad(a, b, d, e)
        s.computeTangents()
        return s
    }

    /// Mattress segment along X (x0...x1, base at y0, height h, width w) and, when `sheet` is given, a
    /// fitted sheet over its top and upper sides with a few soft wrinkles.
    static func pad(_ x0: Float, _ x1: Float, y0: Float, h: Float, w: Float, material: MaterialKey, sheet: MaterialKey?, sub: Int, seed: UInt64) -> [Surface] {
        let cx = (x0 + x1) / 2, L = x1 - x0
        var out = [Prim.superellipsoid(V3(L, h, w), exponent: 8, subdivisions: sub, material: material).transformed(Xform(translation: V3(cx, y0 + h / 2, 0)))]
        if let sheet {
            let ph = Float(seed % 5) * 0.7
            var s = Prim.superellipsoid(V3(L + 0.006, h * 0.8, w + 0.006), exponent: 8, subdivisions: sub, material: sheet) { d in
                1 + 0.012 * sin(d.x * 9 + ph) * sin(d.z * 7) * max(0, d.y)
            }
            s = s.transformed(Xform(translation: V3(cx, y0 + h * 0.6 + 0.0015, 0)))
            out.append(s)
        }
        return out
    }

    /// Thin sheet (paper, linen) following a path, `width` across `across`; faces cross(across, tangent).
    /// UVs in meters. `offset(i, j)` moves vertex (path i, across j) for wrinkles and torn edges.
    static func ribbon(_ path: [V3], across: V3, width: Float, steps: Int, material: MaterialKey,
                       offset: ((Int, Int) -> V3)? = nil) -> Surface {
        var s = Surface(material: material)
        var v: Float = 0
        for i in path.indices {
            if i > 0 { v += simd_distance(path[i], path[i - 1]) }
            let t = simd_normalize(path[min(i + 1, path.count - 1)] - path[max(i - 1, 0)])
            let n = simd_normalize(simd_cross(across, t))
            for j in 0...steps {
                let u = (Float(j) / Float(steps) - 0.5) * width
                _ = s.add(path[i] + across * u + (offset?(i, j) ?? .zero), n, V2(v, u))
            }
        }
        let row = UInt32(steps + 1)
        for i in 0..<UInt32(path.count - 1) { for j in 0..<UInt32(steps) {
            let a = i * row + j
            s.quad(a, a + 1, a + row + 1, a + row)
        }}
        s.recomputeNormals(weldSeams: true)
        s.computeTangents()
        return s
    }

    /// Three-stage telescoping lift column (static housing in the base, two mimic sleeves, inner stage
    /// on `lift`). `bottom` is the housing floor, `top` the inner stage top at rest (meets the frame).
    /// Stages nest (each 6 mm smaller) and keep ~45 mm overlap at full `travel`.
    static func column(_ rig: inout Rig, name: String, at xz: V2, bottom: Float, top: Float, travel: Float, size: V2,
                       housing: MaterialKey, sleeve: MaterialKey, inner: MaterialKey) {
        let h = top - bottom
        let x = xz.x, z = xz.y
        for l in 0..<rig.lodCount {
            rig.base[l].add(box(V3(size.x, h * 0.92, size.y), V3(x, bottom + h * 0.46, z), r: 0.008, seg: l == 0 ? 2 : 1, material: housing))
            rig.base[l].add(box(V3(size.x + 0.02, 0.012, size.y + 0.02), V3(x, bottom + 0.006, z), r: 0.003, seg: 1, material: housing))
        }
        let s1 = name + "-sleeve1", s2 = name + "-sleeve2"
        let c = V3(x, bottom, z)
        rig.part(s1, pivot: c, joint: Joint(.prismatic, axis: .up, range: 0...travel / 3, mimic: .init("lift", ratio: 1.0 / 3)))
        rig.part(s2, pivot: c, joint: Joint(.prismatic, axis: .up, range: 0...travel * 2 / 3, mimic: .init("lift", ratio: 2.0 / 3)))
        rig.add(box(V3(size.x - 0.006, h * 0.92, size.y - 0.006), V3(x, bottom + 0.004 + h * 0.46, z), r: 0.006, seg: 1, material: sleeve), to: s1)
        rig.add(box(V3(size.x - 0.012, h * 0.92, size.y - 0.012), V3(x, bottom + 0.008 + h * 0.46, z), r: 0.005, seg: 1, material: sleeve), to: s2)
        rig.add(box(V3(size.x - 0.018, h - 0.012, size.y - 0.018), V3(x, bottom + 0.012 + (h - 0.012) / 2, z), r: 0.004, seg: 1, material: inner), to: "lift")
    }
}
