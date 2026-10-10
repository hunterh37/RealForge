import Foundation
import simd
import RealCore

/// Individual feathers as alpha-cut cards. UV: u across the vane (rachis near 0.5), v from base (0) to
/// tip (1), matching the `plumageFeather` program.
public enum Feather {
    /// - Parameters:
    ///   - base: where the quill enters the body.
    ///   - direction: unit vector along the feather toward its tip.
    ///   - normal: unit vector the upper surface faces (perpendicular to `direction`).
    ///   - camber: how far the vane edges sit below the rachis (convex upper surface).
    ///   - droop: tip bend along -normal.
    ///   - curl: tip bend sideways.
    ///   - shade: ambient occlusion at the base and the tip.
    ///   - flipSide: mirror the vane (feathers of the left wing and tail half).
    public static func card(base: V3, direction: V3, normal: V3, length: Float, width: Float, camber: Float = 0, droop: Float = 0,
                            curl: Float = 0, shade: V2 = V2(0.6, 1), flipSide: Bool = false, material: MaterialKey) -> Surface {
        let d = simd_normalize(direction)
        var n = normal - d * simd_dot(normal, d)
        n = simd_length(n) < 1e-5 ? d.anyPerpendicular : simd_normalize(n)
        var side = simd_cross(d, n)
        if flipSide { side = -side }
        var s = Surface(material: material)
        let nv = 6
        for j in 0..<nv {
            let t = Float(j) / Float(nv - 1)
            for a in -1...1 {
                let af = Float(a)
                let p = base + d * (t * length) + side * (af * width * 0.5 + curl * t * t) - n * (droop * t * t + camber * af * af)
                s.add(p, n, V2(flipSide ? (1 - (af + 1) / 2) : (af + 1) / 2, t))
                s.occlusion[s.occlusion.count - 1] = shade.x + (shade.y - shade.x) * t
            }
        }
        for j in 0..<(nv - 1) { for a in 0..<2 {
            let i0 = UInt32(j * 3 + a)
            s.quad(i0, i0 + 3, i0 + 4, i0 + 1)
        }}
        s.recomputeNormals(weldSeams: false)
        // Keep the upper surface facing `n` regardless of side flips.
        if let first = s.normals.first, simd_dot(first, n) < 0 { s.normals = s.normals.map { -$0 } }
        s.computeTangents()
        return s
    }
}
