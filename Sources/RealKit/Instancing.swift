import Foundation
import RealityKit
import RealCore

/// GPU-instanced placement of one LOD asset (forests, grass, rocks). Instances are bucketed into square
/// cells; each cell has one child per LOD carrying a MeshInstancesComponent, so a 2,000-tree forest is
/// (cells x LODs) draw calls instead of 2,000 entities, and every cell switches LOD as a unit.
@MainActor
public enum RealInstancing {
    public struct Options {
        public var cellSize: Float = 16
        public var cullDistance: Float = 0
        /// LOD levels at or beyond this index don't cast shadows (big win for dense fields).
        public var shadowCasterMaxLOD: Int = 1
        public var asyncMaterials = true
        /// Per-instance brightness variation, relative (0.1 = +-10%), plus a slow patch term so
        /// neighbors drift together. ShaderGraph: per instance in the shader. PBR fallback: instances
        /// are split across 3 brightness-scaled material copies.
        public var tintJitter: Float = 0.12
        /// Per-instance hue shift in turns (0.02 = about 7 degrees, biased toward yellow). ShaderGraph path only.
        public var hueJitter: Float = 0.02
        /// Extra uniform scale variation applied on top of the given transforms (0.15 = 0.85...1.15),
        /// hashed from each instance position so it is deterministic.
        public var scaleJitter: Float = 0
        public init() {}

        public func with(_ edit: (inout Options) -> Void) -> Options { var c = self; edit(&c); return c }

        /// Trees and large plants: 18 m cells.
        public static var trees: Options { Options().with { $0.cellSize = 18; $0.tintJitter = 0.12; $0.hueJitter = 0.014 } }
        /// Grass and ground cover: 8 m cells, culled past `cull` meters, no shadows.
        public static func groundCover(cull: Float = 30) -> Options {
            Options().with { $0.cellSize = 8; $0.cullDistance = cull; $0.shadowCasterMaxLOD = -1; $0.tintJitter = 0.16; $0.hueJitter = 0.02 }
        }
        /// Manufactured repeats (fence posts, bollards): no color drift.
        public static var props: Options { Options().with { $0.tintJitter = 0; $0.hueJitter = 0 } }
    }

    /// - Parameter transforms: world-space (relative to the returned entity) instance transforms.
    public static func field(_ asset: LODModel, transforms: [simd_float4x4], name: String = "field",
                             options: Options = Options(), materials: RealMaterialCache? = nil) async throws -> Entity {
        let cache = materials ?? .shared
        let root = Entity()
        root.name = name
        guard !transforms.isEmpty else { return root }

        // Shared GPU resources per LOD. `mats[lod][bucket]`: one bucket when the shader varies each
        // instance (or jitter is off), three brightness buckets on the PhysicallyBasedMaterial path.
        let jitter = options.tintJitter > 0 || options.hueJitter > 0
        var meshes: [MeshResource] = []
        var mats: [[[any RealityKit.Material]]] = []
        var lodBounds: [BoundingBox] = []
        var perInstanceShader = true
        for m in asset.levels {
            meshes.append(try m.meshResource())
            var ms: [any RealityKit.Material] = []
            for s in m.surfaces where !s.isEmpty {
                let mat: any RealityKit.Material
                if !options.asyncMaterials { mat = cache.material(s.material) }
                else if jitter { mat = await cache.materialAsync(s.material, hueJitter: options.hueJitter, valueJitter: options.tintJitter) }
                else { mat = await cache.materialAsync(s.material) }
                if jitter && !(mat is ShaderGraphMaterial) { perInstanceShader = false }
                ms.append(mat)
            }
            mats.append([ms])
            let b = m.bounds
            lodBounds.append(BoundingBox(min: b.min, max: b.max))
        }
        let buckets = jitter && !perInstanceShader && options.tintJitter > 0 ? 3 : 1
        if buckets > 1 {
            for (li, m) in asset.levels.enumerated() {
                let keys = m.surfaces.filter { !$0.isEmpty }.map(\.material)
                mats[li] = (0..<buckets).map { b in
                    let v = 1 + options.tintJitter * Float(b - 1)
                    return keys.enumerated().map { i, k in mats[li][0][i] is ShaderGraphMaterial ? mats[li][0][i] : cache.material(k, brightness: v) }
                }
            }
        }
        let transforms = options.scaleJitter > 0 ? transforms.map { t in
            let s = 1 + options.scaleJitter * (instanceHash(SIMD3(t.columns.3.x, t.columns.3.y, t.columns.3.z), salt: 7) * 2 - 1)
            return t * simd_float4x4(diagonal: SIMD4(s, s, s, 1))
        } : transforms

        var cells: [SIMD2<Int32>: [simd_float4x4]] = [:]
        for t in transforms {
            let p = SIMD2(t.columns.3.x, t.columns.3.z) / options.cellSize
            cells[SIMD2<Int32>(Int32(p.x.rounded(.down)), Int32(p.y.rounded(.down))), default: []].append(t)
        }

        for (key, all) in cells {
            let cell = Entity()
            cell.name = "cell_\(key.x)_\(key.y)"
            var center = SIMD3<Float>.zero
            for t in all { center += SIMD3(t.columns.3.x, t.columns.3.y, t.columns.3.z) }
            center /= Float(all.count)
            var groups = Array(repeating: [simd_float4x4](), count: buckets)
            for t in all {
                let b = buckets == 1 ? 0 : min(buckets - 1, Int(instanceHash(SIMD3(t.columns.3.x, t.columns.3.y, t.columns.3.z), salt: 3) * Float(buckets)))
                groups[b].append(t)
            }
            for (li, mesh) in meshes.enumerated() { for (bi, list) in groups.enumerated() where !list.isEmpty {
                let e = Entity()
                e.name = "lod\(li)"
                e.isEnabled = li == 0
                e.components.set(ModelComponent(mesh: mesh, materials: mats[li][bi]))
                let data = try LowLevelInstanceData(instanceCount: list.count)
                data.withMutableTransforms { buf in for (i, t) in list.enumerated() { buf[i] = t } }
                // Bounds of all instances (for culling).
                var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude), hi = -lo
                let b = lodBounds[li]
                for t in list {
                    for c in [b.min, b.max, SIMD3(b.min.x, b.max.y, b.max.z), SIMD3(b.max.x, b.min.y, b.min.z)] {
                        let w = t * SIMD4(c, 1)
                        lo = simd_min(lo, SIMD3(w.x, w.y, w.z)); hi = simd_max(hi, SIMD3(w.x, w.y, w.z))
                    }
                }
                e.components.set(try MeshInstancesComponent(mesh: mesh, instances: data, bounds: BoundingBox(min: lo, max: hi)))
                if li > options.shadowCasterMaxLOD { e.components.set(DynamicLightShadowComponent(castsShadow: false)) }
                cell.addChild(e)
            }}
            if meshes.count > 1 || options.cullDistance > 0 {
                cell.components.set(RealLODComponent(switchDistances: asset.switchDistances, cullDistance: options.cullDistance, center: center))
            }
            root.addChild(cell)
        }
        return root
    }
}

/// Deterministic 0..<1 hash of a position (instance variation that survives re-runs).
func instanceHash(_ p: SIMD3<Float>, salt: UInt32) -> Float {
    let q = SIMD3<Int32>((p * 97).rounded(.down))
    var h = UInt32(bitPattern: q.x) &* 0x8DA6B343 ^ UInt32(bitPattern: q.y) &* 0xD8163841 ^ UInt32(bitPattern: q.z) &* 0xCB1AB31F ^ salt &* 0x9E3779B9
    h ^= h >> 16; h &*= 0x7FEB352D; h ^= h >> 15; h &*= 0x846CA68B; h ^= h >> 16
    return Float(h >> 8) / Float(1 << 24)
}

public extension Xform {
    var float4x4: simd_float4x4 { matrix }
}
