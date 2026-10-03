import simd
import Foundation

/// Scene building helpers for terrain-following strips (roads, streams, lane lines) and ground grids.
enum SceneStrips {
    /// Strip `width` wide whose center follows x = `cx(z)` from `z0` to `z1`. Vertex heights come from
    /// `y(x, z)`. UVs in meters: u along the strip, v across.
    static func ribbon(material: MaterialKey, z0: Float, z1: Float, width: Float, along: Int, across: Int,
                       cx: (Float) -> Float, y: (Float, Float) -> Float) -> Surface {
        var s = Surface(material: material)
        var dist: Float = 0, prev = V2(cx(z0), z0)
        for j in 0...along {
            let z = z0 + (z1 - z0) * Float(j) / Float(along)
            let c = V2(cx(z), z)
            dist += simd_length(c - prev); prev = c
            // Offset perpendicular to the centerline so the strip keeps its width on bends.
            let dz: Float = 0.05
            let t = simd_normalize(V2(cx(z + dz) - cx(z - dz), 2 * dz))
            let side = V2(t.y, -t.x)
            for i in 0...across {
                let v = (Float(i) / Float(across) - 0.5) * width
                let p = c + side * v
                _ = s.add(V3(p.x, y(p.x, p.y), p.y), .up, V2(dist, v))
            }
        }
        let row = UInt32(across + 1)
        for j in 0..<UInt32(along) { for i in 0..<UInt32(across) {
            let a = j * row + i
            s.quad(a, a + row, a + row + 1, a + 1)
        }}
        s.recomputeNormals(weldSeams: false)
        // Keep the strip facing up whichever way the quads wind.
        if (s.normals.first?.y ?? 1) < 0 {
            for k in stride(from: 0, to: s.indices.count, by: 3) { s.indices.swapAt(k + 1, k + 2) }
            s.recomputeNormals(weldSeams: false)
        }
        s.computeTangents()
        return s
    }

    /// Square ground grid with baked hollow occlusion.
    static func ground(size: Float, segments: Int, material: MaterialKey, hollows: Float = 0.5, relief: Float = 1,
                       height: (V2) -> Float) -> Surface {
        var s = Prim.terrain(size: V2(size, size), segments: segments, material: material, height: height)
        GroundMesh.shadeHollows(&s, gridSide: segments + 1, radius: max(2, segments / 40), relief: relief, strength: hollows)
        return s
    }

    /// Instance transform on the ground: random yaw, uniform scale, optional lean in degrees.
    static func xform(_ p: V2, y: Float, _ rng: inout SeededRNG, scale: ClosedRange<Float>, lean: Float = 0) -> simd_float4x4 {
        var q = simd_quatf(degrees: rng.float(0...360), axis: .up)
        if lean > 0 { q = simd_quatf(degrees: rng.float(-lean...lean), axis: V3(1, 0, 0)) * q }
        return Xform(translation: V3(p.x, y, p.y), rotation: q, scale: V3(repeating: rng.float(scale))).matrix
    }
}
