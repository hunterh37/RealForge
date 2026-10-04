import simd
import RealCore
import RealKit

/// What a scene costs from one viewpoint under given settings, before frustum culling. Mirrors the
/// runtime: field cells and statics pick their LOD with the same policy as `RealLODSystem`.
public struct RealSceneCost: Sendable, Equatable {
    /// Triangles of every visible mesh, instances included.
    public var triangles = 0
    /// Triangles drawn again into the sun shadow map.
    public var shadowTriangles = 0
    public var drawCalls = 0
    public var instances = 0
    /// Mesh entities shown (LOD children, field cells, batches).
    public var meshes = 0
    public var lights = 0

    /// Rough frame weight: main pass + shadow pass + per-draw overhead (one draw ~ 4k triangles).
    public var weight: Int { triangles + shadowTriangles + drawCalls * 4000 }
}

public extension RealScene {
    /// Cost seen from `viewer` (scene space; default: the camera hint) under `settings`.
    func estimate(viewer: V3? = nil, settings perf: RealPerformance = .active) -> RealSceneCost {
        let eye = viewer ?? camera?.eye ?? V3(0, 1.6, 0)
        var c = RealSceneCost()

        for f in fields {
            let o = f.options
            let all = o.thinnable ? perf.thinned(f.transforms) : f.transforms
            var cells: [SIMD2<Int32>: [simd_float4x4]] = [:]
            for t in all {
                let p = SIMD2(t.columns.3.x, t.columns.3.z) / o.cellSize
                cells[SIMD2<Int32>(Int32(p.x.rounded(.down)), Int32(p.y.rounded(.down))), default: []].append(t)
            }
            let size = f.asset.levels[0].boundsDiagonal
            for (_, list) in cells {
                var center = V3.zero
                for t in list { center += V3(t.columns.3.x, t.columns.3.y, t.columns.3.z) }
                center /= Float(list.count)
                let lodded = f.asset.levels.count > 1 || o.cullDistance > 0
                let level: Int?
                if lodded {
                    level = perf.level(distance: simd_distance(center, eye), switchDistances: f.asset.switchDistances,
                                       cullDistance: o.cullDistance, groundCover: o.thinnable)
                } else { level = 0 }
                guard let li = level else { continue }
                let shown = o.thinnable ? perf.instances(list, level: li, levels: f.asset.levels.count) : list
                guard !shown.isEmpty else { continue }
                let m = f.asset.levels[li]
                let tris = m.triangleCount * shown.count
                c.triangles += tris; c.instances += shown.count; c.meshes += 1
                c.drawCalls += m.surfaces.filter { !$0.isEmpty }.count
                if perf.castsShadow(lod: li, size: size, eligible: o.shadowCasterMaxLOD >= 0, lodShift: o.shadowCasterMaxLOD - 1) { c.shadowTriangles += tris }
            }
        }

        for s in uploadedStatics(perf) {
            let b = s.asset.levels[0].bounds
            let size = simd_length(b.max - b.min) * s.at.scale.max()
            let center = s.at.point((b.min + b.max) / 2)
            guard let li = perf.level(distance: simd_distance(center, eye), switchDistances: s.asset.switchDistances, size: size) else { continue }
            let m = s.asset.levels[min(li, s.asset.levels.count - 1)]
            let glass = !m.surfaces.isEmpty && m.surfaces.allSatisfy { MaterialLibrary.spec(for: $0.material).mode == .transparent }
            c.triangles += m.triangleCount; c.instances += 1; c.meshes += 1
            c.drawCalls += m.surfaces.filter { !$0.isEmpty }.count
            if perf.castsShadow(lod: li, size: size, eligible: !glass) { c.shadowTriangles += m.triangleCount }
        }

        for r in rigs {
            let posed = r.rig.posed(r.state)
            let b = posed.levels[0].bounds
            let size = simd_length(b.max - b.min)
            let li = perf.level(distance: simd_distance(r.at.point((b.min + b.max) / 2), eye), switchDistances: posed.switchDistances, size: .infinity) ?? 0
            let m = posed.levels[min(li, posed.levels.count - 1)]
            c.triangles += m.triangleCount; c.instances += 1; c.meshes += 1
            c.drawCalls += m.surfaces.filter { !$0.isEmpty }.count
            if perf.castsShadow(lod: li, size: size) { c.shadowTriangles += m.triangleCount }
        }
        c.lights = min(lights.count, perf.maxSceneLights)
        return c
    }
}
