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
        public init() {}

        public func with(_ edit: (inout Options) -> Void) -> Options { var c = self; edit(&c); return c }

        /// Trees and large plants: 18 m cells.
        public static var trees: Options { Options().with { $0.cellSize = 18 } }
        /// Grass and ground cover: 8 m cells, culled past `cull` meters, no shadows.
        public static func groundCover(cull: Float = 30) -> Options {
            Options().with { $0.cellSize = 8; $0.cullDistance = cull; $0.shadowCasterMaxLOD = -1 }
        }
    }

    /// - Parameter transforms: world-space (relative to the returned entity) instance transforms.
    public static func field(_ asset: LODModel, transforms: [simd_float4x4], name: String = "field",
                             options: Options = Options(), materials: RealMaterialCache? = nil) async throws -> Entity {
        let cache = materials ?? .shared
        let root = Entity()
        root.name = name
        guard !transforms.isEmpty else { return root }

        // Shared GPU resources per LOD.
        var meshes: [MeshResource] = []
        var mats: [[any RealityKit.Material]] = []
        var lodBounds: [BoundingBox] = []
        for m in asset.levels {
            meshes.append(try m.meshResource())
            var ms: [any RealityKit.Material] = []
            for s in m.surfaces where !s.isEmpty { ms.append(options.asyncMaterials ? await cache.materialAsync(s.material) : cache.material(s.material)) }
            mats.append(ms)
            let b = m.bounds
            lodBounds.append(BoundingBox(min: b.min, max: b.max))
        }

        var cells: [SIMD2<Int32>: [simd_float4x4]] = [:]
        for t in transforms {
            let p = SIMD2(t.columns.3.x, t.columns.3.z) / options.cellSize
            cells[SIMD2<Int32>(Int32(p.x.rounded(.down)), Int32(p.y.rounded(.down))), default: []].append(t)
        }

        for (key, list) in cells {
            let cell = Entity()
            cell.name = "cell_\(key.x)_\(key.y)"
            var center = SIMD3<Float>.zero
            for t in list { center += SIMD3(t.columns.3.x, t.columns.3.y, t.columns.3.z) }
            center /= Float(list.count)
            for (li, mesh) in meshes.enumerated() {
                let e = Entity()
                e.name = "lod\(li)"
                e.isEnabled = li == 0
                e.components.set(ModelComponent(mesh: mesh, materials: mats[li]))
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
            }
            if meshes.count > 1 || options.cullDistance > 0 {
                cell.components.set(RealLODComponent(switchDistances: asset.switchDistances, cullDistance: options.cullDistance, center: center))
            }
            root.addChild(cell)
        }
        return root
    }
}

public extension Xform {
    var float4x4: simd_float4x4 { matrix }
}
