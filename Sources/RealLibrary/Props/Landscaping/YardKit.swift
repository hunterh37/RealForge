import simd
import Foundation

typealias K = YardKit

/// Builders shared by the yard props: boxes, beams, rods, arcs and the final recenter plus ground AO.
enum YardKit {
    static let ident = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

    /// Rounded box centered at `c`.
    static func box(_ m: inout Model, _ c: V3, _ size: V3, _ mat: String, bevel: Float = 0.003, rot: simd_quatf = ident) {
        m.add(Prim.roundedBox(size, radius: bevel, bevelSegments: 1, material: mat), Xform(translation: c, rotation: rot))
    }

    /// Board from `a` to `b`: `thick` along `up`, `width` across.
    static func beam(_ m: inout Model, _ a: V3, _ b: V3, _ width: Float, _ thick: Float, _ mat: String, up: V3 = .up) {
        let (s, x) = board(from: a, to: b, width: width, thick: thick, up: up, bevel: 0.003, material: mat)
        m.add(s, x)
    }

    /// Thin slat between `a` and `b` with a single-segment bevel (cheap for lattices).
    static func slat(_ m: inout Model, _ a: V3, _ b: V3, _ width: Float, _ thick: Float, _ mat: String, up: V3 = .up) {
        let d = b - a, len = simd_length(d), x = d / len
        let y = simd_normalize(up - x * simd_dot(up, x)), z = simd_cross(x, y)
        m.add(Prim.roundedBox(V3(len, thick, width), radius: 0.002, bevelSegments: 1, material: mat),
              Xform(translation: (a + b) / 2, rotation: simd_quatf(simd_float3x3(columns: (x, y, z)))))
    }

    /// Round rod through `pts`.
    static func rod(_ m: inout Model, _ pts: [V3], r: Float, _ mat: String, sides: Int = 8) {
        m.add(Prim.tube(pts, radii: Array(repeating: r, count: pts.count), sides: sides, seamTile: 0.1, material: mat))
    }

    /// Points on an XY-plane arc about `c` from `a0` to `a1` degrees; `z` offsets the plane.
    static func arc(_ c: V3, _ radius: Float, _ a0: Float, _ a1: Float, n: Int = 24) -> [V3] {
        (0...n).map { i in
            let a = (a0 + (a1 - a0) * Float(i) / Float(n)) * .pi / 180
            return c + V3(cos(a) * radius, sin(a) * radius, 0)
        }
    }

    static func yaw(_ deg: Float) -> simd_quatf { simd_quatf(degrees: deg, axis: .up) }

    /// Recenter on X/Z, base at y = 0, bake ground AO.
    static func finish(_ m: inout Model, ao: Float = 0.2) -> LODModel {
        let b = m.bounds
        let shift = V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)
        for i in m.surfaces.indices { m.surfaces[i].positions = m.surfaces[i].positions.map { $0 + shift } }
        groundAO(&m, height: ao)
        return LODModel(m)
    }
}
