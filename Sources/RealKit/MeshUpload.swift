import Foundation
import Metal
import RealityKit
import RealCore

/// Interleaved GPU vertex, tightly packed: 72 bytes. (SIMD3<Float> is 16-byte aligned in Swift, so
/// fields are scalar to keep the declared Metal offsets exact.) uv1 = (wind weight, phase).
struct RFVertex {
    var px, py, pz: Float          // 0
    var nx, ny, nz: Float          // 12
    var tx, ty, tz: Float          // 24
    var bx, by, bz: Float          // 36
    var u0, v0: Float              // 48
    var u1, v1: Float              // 56
    var u2, v2: Float              // 64  (phase, reserved)
    init(_ p: SIMD3<Float>, _ n: SIMD3<Float>, _ t: SIMD3<Float>, _ b: SIMD3<Float>, _ uv: SIMD2<Float>, _ e: SIMD2<Float>, _ ao: Float) {
        px = p.x; py = p.y; pz = p.z; nx = n.x; ny = n.y; nz = n.z; tx = t.x; ty = t.y; tz = t.z
        bx = b.x; by = b.y; bz = b.z; u0 = uv.x; v0 = uv.y; u1 = e.x; v1 = e.y; u2 = ao; v2 = 0
    }
}

public extension Model {
    /// Uploads straight into a LowLevelMesh: one vertex/index buffer, one part per material.
    /// No CPU-side MeshResource processing, which matters when spawning forests at runtime.
    @MainActor
    func lowLevelMesh() throws -> LowLevelMesh {
        let surfaces = self.finalized().surfaces.filter { !$0.isEmpty }
        let vCount = surfaces.reduce(0) { $0 + $1.vertexCount }, iCount = surfaces.reduce(0) { $0 + $1.indices.count }
        let attrs: [LowLevelMesh.Attribute] = [
            .init(semantic: .position, format: .float3, offset: 0),
            .init(semantic: .normal, format: .float3, offset: 12),
            .init(semantic: .tangent, format: .float3, offset: 24),
            .init(semantic: .bitangent, format: .float3, offset: 36),
            .init(semantic: .uv0, format: .float2, offset: 48),
            .init(semantic: .uv1, format: .float2, offset: 56),
            .init(semantic: .uv2, format: .float2, offset: 64),
        ]
        let desc = LowLevelMesh.Descriptor(vertexCapacity: vCount, vertexAttributes: attrs,
                                           vertexLayouts: [.init(bufferIndex: 0, bufferStride: MemoryLayout<RFVertex>.stride)],
                                           indexCapacity: iCount, indexType: .uint32)
        let mesh = try LowLevelMesh(descriptor: desc)
        var parts: [LowLevelMesh.Part] = []
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            let v = raw.bindMemory(to: RFVertex.self)
            var k = 0
            for s in surfaces {
                for i in 0..<s.vertexCount {
                    let n = s.normals[i], t4 = s.tangents[i], t = SIMD3(t4.x, t4.y, t4.z)
                    // USD/RealityKit UV origin is bottom-left; our generators already use v-up.
                    // uv1 = (wind weight, baked AO). ShaderGraph only exposes uv0/uv1.
                    v[k] = RFVertex(s.positions[i], n, t, simd_cross(n, t) * t4.w, s.uvs[i], SIMD2(s.extra[i].x, s.occlusion[i]), s.extra[i].y)
                    k += 1
                }
            }
        }
        mesh.withUnsafeMutableIndices { raw in
            let idx = raw.bindMemory(to: UInt32.self)
            var base: UInt32 = 0, k = 0, partIndex = 0
            for s in surfaces {
                let start = k
                for i in s.indices { idx[k] = i + base; k += 1 }
                let b = s.bounds
                parts.append(LowLevelMesh.Part(indexOffset: start * 4, indexCount: s.indices.count, topology: .triangle,
                                               materialIndex: partIndex, bounds: BoundingBox(min: b.min, max: b.max)))
                base += UInt32(s.vertexCount); partIndex += 1
            }
        }
        mesh.parts.replaceAll(parts)
        return mesh
    }

    @MainActor
    func meshResource() throws -> MeshResource { try MeshResource(from: lowLevelMesh()) }

    /// ModelEntity with cached PBR materials (textures generated on first use).
    @MainActor
    func modelEntity(materials: RealMaterialCache? = nil) throws -> ModelEntity {
        let cache = materials ?? .shared
        let keys = self.surfaces.filter { !$0.isEmpty }.map(\.material)
        let e = ModelEntity(mesh: try meshResource(), materials: keys.map { cache.material($0) })
        e.name = name
        return e
    }
}
