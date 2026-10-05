import simd
import Foundation
import RealityKit
import RealKit

/// A composed scene: instanced fields + single hero assets + live articulated assets + lights +
/// camera and lighting hints.
public struct RealScene {
    public struct Field { public var asset: LODModel; public var transforms: [simd_float4x4]; public var options: RealInstancing.Options }
    public struct Single {
        public var asset: LODModel; public var at: Xform
        /// Receives the scene AO bake (room shells, floors, large furniture).
        public var bake = false
        public init(asset: LODModel, at: Xform, bake: Bool = false) { self.asset = asset; self.at = at; self.bake = bake }
    }
    /// An articulated asset kept live: its parts are entities that animate between states.
    public struct Articulated {
        public var rig: Rig; public var at: Xform; public var state: String?; public var interactive: Bool
        /// Can be picked up by hand (visionOS).
        public var grabbable = false
        /// Entity name (default: the asset id), for `findEntity(named:)` in apps.
        public var name: String? = nil
    }
    public struct Camera { public var eye: V3; public var target: V3; public var fov: Float }
    /// Named standing point (teleport destination in the demo): eye at standing height, looking at `target`.
    public struct Spot {
        public var name: String; public var eye: V3; public var target: V3
        public init(_ name: String, eye: V3, target: V3) { self.name = name; self.eye = eye; self.target = target }
    }
    /// How the scene wants to be lit. `RealityHD.environment(for:)` and `realityhd render` apply it.
    public struct Lighting {
        /// Sun and sky (nil = the caller's choice).
        public var sky: SunSky?
        /// Indoor probe replacing the sky IBL (the sun and skybox still show through windows).
        public var interior: InteriorLight?
        /// Fog density override (interiors: 0).
        public var fog: Float?
        /// Sun illuminance multiplier.
        public var sunScale: Float?
        public init(sky: SunSky? = nil, interior: InteriorLight? = nil, fog: Float? = nil, sunScale: Float? = nil) {
            self.sky = sky; self.interior = interior; self.fog = fog; self.sunScale = sunScale
        }
    }

    public var name: String
    public var fields: [Field] = []
    public var singles: [Single] = []
    public var rigs: [Articulated] = []
    /// Scene lights (lamps, spots). Keep it to a handful: every light costs every lit pixel.
    public var lights: [RigLight] = []
    public var camera: Camera?
    /// Teleport destinations. `merge` adds each merged scene's spots, or its camera when it has none.
    public var spots: [Spot] = []
    public var lighting = Lighting()
    /// Huge flat ground under everything so the horizon is land fading into aerial haze.
    public var farGround: MaterialKey? = "ground.meadow"
    /// Merge static singles into one mesh per material per cell (fewer draw calls and entities).
    /// LOD sets with the same switch distances merge together; glass merges separately without shadows.
    public var batchStatics = false
    public var batchCell: Float = 8
    /// Bake scene ambient occlusion into singles marked `bake` when the entity is built.
    public var bake: AOBake.Settings?
    public init(name: String) { self.name = name }

    @MainActor
    public func entity(materials: RealMaterialCache? = nil) async throws -> Entity {
        let root = Entity()
        root.name = name
        for f in fields { root.addChild(try await RealInstancing.field(f.asset, transforms: f.transforms, options: f.options, materials: materials)) }
        if let farGround {
            let far = Model(name: "far-ground", surfaces: [Prim.terrain(size: V2(4000, 4000), segments: 8, material: farGround) { _ in -0.25 }])
            let e = try await far.modelEntityAsync(materials: materials)
            e.components.set(DynamicLightShadowComponent(castsShadow: false))
            root.addChild(e)
        }
        var statics = singles
        if let bake { statics = await Self.baked(statics, rigs: rigs, fields: fields, settings: bake) }
        let perf = RealPerformance.active
        if batchStatics || perf.forceBatching {
            for g in Self.batches(statics, cell: batchCell, detailSize: perf.detailSize) {
                root.addChild(try await Self.upload(g.asset, at: .identity, materials: materials))
            }
        } else {
            for s in statics { root.addChild(try await Self.upload(s.asset, at: s.at, materials: materials)) }
        }
        for r in rigs {
            let e = try await r.rig.entityAsync(name: r.name, state: r.state, materials: materials, interactive: r.interactive, grabbable: r.grabbable)
            e.transform = Transform(scale: r.at.scale, rotation: r.at.rotation, translation: r.at.translation)
            // Grab home is the placed pose, so `resetGrab()` returns the object to its spot in the scene.
            if var g = e.components[RealGrabComponent.self] { g.home = e.transform; e.components.set(g) }
            root.addChild(e)
        }
        for l in Self.budgetLights(lights, max: perf.maxSceneLights) {
            let e = Entity()
            e.name = "light:\(l.name)"
            l.configure(e)
            root.addChild(e)
            e.look(at: l.position + l.direction, from: l.position, relativeTo: root)
        }
        return root
    }

    /// Every static gets a LOD root (single-level assets too) so draw distance and detail culling reach it,
    /// and every mesh gets a cost tag so the shadow policy and stats see it.
    @MainActor
    static func upload(_ asset: LODModel, at: Xform, materials: RealMaterialCache?) async throws -> Entity {
        // Water and glass sheets: no sun shadow on the bed below.
        let surfaces = asset.levels[0].surfaces
        let glass = !surfaces.isEmpty && surfaces.allSatisfy({ MaterialLibrary.spec(for: $0.material).mode == .transparent })
        let e: Entity
        if asset.levels.count == 1 {
            e = Entity()
            e.name = asset.levels[0].name
            let m = try await asset.levels[0].modelEntityAsync(materials: materials)
            m.name = "lod0"
            let size = asset.levels[0].boundsDiagonal
            m.realTagCost(asset.levels[0].cost(lod: 0, size: size * at.scale.max(), shadowEligible: !glass))
            e.addChild(m)
            let b = asset.levels[0].bounds
            e.components.set(RealLODComponent(switchDistances: [], center: (b.min + b.max) / 2, size: size))
        } else {
            e = try await asset.entityAsync(materials: materials, castsShadow: !glass)
        }
        e.transform = Transform(scale: at.scale, rotation: at.rotation, translation: at.translation)
        return e
    }

    /// Brightest lights first, up to `max`.
    static func budgetLights(_ lights: [RigLight], max n: Int) -> [RigLight] {
        guard lights.count > n else { return lights }
        return Array(lights.enumerated().sorted { a, b in a.element.intensity != b.element.intensity ? a.element.intensity > b.element.intensity : a.offset < b.offset }
            .prefix(Swift.max(0, n)).map(\.element))
    }

    /// Static batching: singles grouped by cell and LOD layout, merged per material; transparent
    /// surfaces split into their own batch.
    /// `detailSize` > 0 keeps objects smaller than it in their own batches so detail culling and the
    /// shadow size rule still reach them.
    static func batches(_ singles: [Single], cell: Float, detailSize: Float = 0) -> [Single] {
        struct Key: Hashable { var cx: Int32; var cz: Int32; var distances: [Float]; var glass: Bool; var small: Bool }
        var groups: [Key: [Model]] = [:]
        var order: [Key] = []
        for s in singles {
            let c = s.at.translation / cell
            for glass in [false, true] {
                let levels = s.asset.levels.map { m -> Model in
                    var o = Model(name: m.name)
                    for surf in m.surfaces where (MaterialLibrary.spec(for: surf.material).mode == .transparent) == glass { o.add(surf, s.at) }
                    return o
                }
                guard levels[0].triangleCount > 0 else { continue }
                let small = detailSize > 0 && s.asset.levels[0].boundsDiagonal * s.at.scale.max() < detailSize
                let k = Key(cx: Int32(c.x.rounded(.down)), cz: Int32(c.z.rounded(.down)), distances: s.asset.switchDistances, glass: glass, small: small)
                // Mutate in place: copying the group out and back duplicated every merged vertex array per add.
                if groups[k] != nil {
                    for i in groups[k]!.indices { groups[k]![i].add(levels[min(i, levels.count - 1)]) }
                } else { groups[k] = levels; order.append(k) }
            }
        }
        return order.map { k in Single(asset: LODModel(levels: groups[k]!, switchDistances: k.distances), at: .identity) }
    }

    /// Applies the AO bake to `bake` singles in world space, occluded by everything static.
    static func baked(_ singles: [Single], rigs: [Articulated], fields: [Field], settings: AOBake.Settings) async -> [Single] {
        let receiversIdx = singles.indices.filter { singles[$0].bake }
        guard !receiversIdx.isEmpty else { return singles }
        let work = Task.detached(priority: .userInitiated) { () -> [Single] in
            var occluders: [Model] = []
            for (i, s) in singles.enumerated() where !s.bake {
                let lod = s.asset.levels[min(1, s.asset.levels.count - 1)]
                occluders.append(lod.transformed(s.at))
            }
            for r in rigs { let p = r.rig.posed(r.state); occluders.append(p.levels[min(1, p.levels.count - 1)].transformed(r.at)) }
            for f in fields where f.asset.levels[0].bounds.max.y - f.asset.levels[0].bounds.min.y > 0.15 {
                let lod = f.asset.levels[min(1, f.asset.levels.count - 1)]
                for t in f.transforms { occluders.append(lod.transformed(Xform(matrix: t))) }
            }
            // Receivers in world space; bake LOD0 only and carry the result back by local index.
            var receivers = receiversIdx.map { singles[$0].asset.levels[0].transformed(singles[$0].at) }
            AOBake.bake(&receivers, occluders: occluders, settings: settings)
            var out = singles
            for (k, i) in receiversIdx.enumerated() {
                var lod = out[i].asset
                for si in lod.levels[0].surfaces.indices { lod.levels[0].surfaces[si].occlusion = receivers[k].surfaces[si].occlusion }
                out[i].asset = lod
            }
            return out
        }
        return await work.value
    }

    // MARK: - building helpers

    /// One asset instance (hero object, not instanced).
    public mutating func add<A: RealAsset>(_ asset: A, at: Xform = .identity, seed: UInt64) {
        singles.append(.init(asset: asset.build(seed: seed), at: at))
    }

    /// An articulated asset baked static in one state (cheapest: merges and batches like any prop).
    public mutating func add<A: RealArticulated>(_ asset: A, at: Xform = .identity, seed: UInt64, state: String) {
        singles.append(.init(asset: asset.build(seed: seed, state: state), at: at))
    }

    /// An articulated asset kept live (animates on `setArticulation`, taps with `interactive`).
    /// `name` names the root entity (default: the asset id). `grabbable` (default: assets tagged `handheld`) lets a hand pick the whole object up.
    public mutating func addLive<A: RealArticulated>(_ asset: A, at: Xform = .identity, seed: UInt64, state: String? = nil, interactive: Bool = true,
                                                     grabbable: Bool? = nil, name: String? = nil) {
        rigs.append(.init(rig: asset.rig(seed: seed), at: at, state: state, interactive: interactive, grabbable: grabbable ?? A.handheld, name: name))
    }

    /// A one-off model (paths, pads, walls) that is not a catalog asset. `bake`: receive scene AO.
    public mutating func add(_ model: Model, at: Xform = .identity, bake: Bool = false) {
        singles.append(.init(asset: LODModel(model), at: at, bake: bake))
    }

    /// GPU-instanced copies of one asset build. Use for anything repeated more than ~10 times.
    public mutating func field<A: RealAsset>(_ asset: A, seed: UInt64, transforms: [simd_float4x4],
                                             options: RealInstancing.Options = RealInstancing.Options()) {
        guard !transforms.isEmpty else { return }
        fields.append(.init(asset: asset.build(seed: seed), transforms: transforms, options: options))
    }

    /// GPU-instanced copies of an articulated asset baked in one state.
    public mutating func field<A: RealArticulated>(_ asset: A, seed: UInt64, state: String, transforms: [simd_float4x4],
                                                   options: RealInstancing.Options = .props) {
        guard !transforms.isEmpty else { return }
        fields.append(.init(asset: asset.build(seed: seed, state: state), transforms: transforms, options: options))
    }

    /// LOD0 triangles if every instance were at LOD0 (upper bound used by budget tests).
    public var worstCaseTriangles: Int {
        singles.reduce(0) { $0 + $1.asset.levels[0].triangleCount }
            + fields.reduce(0) { $0 + $1.asset.levels[0].triangleCount * $1.transforms.count }
            + rigs.reduce(0) { $0 + $1.rig.posed($1.state).levels[0].triangleCount }
    }

    /// Entities created for the static part (draw-call estimate): singles or batches, plus field cells.
    public var staticEntityEstimate: Int { batchStatics ? Self.batches(singles, cell: batchCell).count : singles.count }

    /// Statics as they will be uploaded under `settings` (batched when the scene or the settings ask).
    public func uploadedStatics(_ settings: RealPerformance = .active) -> [Single] {
        batchStatics || settings.forceBatching ? Self.batches(singles, cell: batchCell, detailSize: settings.detailSize) : singles
    }
}

public extension Xform {
    /// TRS from an affine matrix (no shear).
    init(matrix m: simd_float4x4) {
        let c0 = V3(m.columns.0.x, m.columns.0.y, m.columns.0.z), c1 = V3(m.columns.1.x, m.columns.1.y, m.columns.1.z), c2 = V3(m.columns.2.x, m.columns.2.y, m.columns.2.z)
        let s = V3(simd_length(c0), simd_length(c1), simd_length(c2))
        let r = simd_float3x3(c0 / s.x, c1 / s.y, c2 / s.z)
        self.init(translation: V3(m.columns.3.x, m.columns.3.y, m.columns.3.z), rotation: simd_quatf(r), scale: s)
    }
}
