import Foundation
import RealityKit
import RealKit

/// One-call entry points. Geometry is generated off the main actor (all generators are pure and
/// Sendable); GPU upload, texture synthesis and ShaderGraph compilation happen on the main actor.
public enum RealityHD {
    /// Register systems/components and pick a quality preset. Call once at app start.
    @MainActor
    public static func setup(_ quality: RealQuality.Preset = .balanced) {
        RealQuality.apply(quality)
        RealKitSetup.register()
    }

    /// Outdoor lighting rig. Add `env.root` to the scene and call `env.illuminate(content)`.
    @MainActor
    public static func environment(_ sky: SunSky = SunSky(), skybox: Bool = false) throws -> RealEnvironment {
        try RealEnvironment(sky, skybox: skybox)
    }

    /// Any catalog asset as an entity with LOD children (ShaderGraph wind/fog materials).
    public static func entity(_ id: String, seed: UInt64 = 1) async throws -> Entity {
        guard let t = Catalog.type(id) else { throw RealityHDError.unknown(id) }
        let lod = await Task.detached(priority: .userInitiated) { t.init().build(seed: seed) }.value
        return try await upload(lod, name: id)
    }

    /// Any RealAsset value (custom parameters) as an entity.
    public static func entity<A: RealAsset>(_ asset: A, seed: UInt64 = 1) async throws -> Entity {
        let lod = await Task.detached(priority: .userInitiated) { asset.build(seed: seed) }.value
        return try await upload(lod, name: A.id)
    }

    /// An articulated asset as a live entity: parts move with `entity.setArticulation("open")`,
    /// `nextArticulation()` or, with `interactive`, `realToggle()` from a tap gesture.
    public static func articulated(_ id: String, seed: UInt64 = 1, state: String? = nil, interactive: Bool = true) async throws -> Entity {
        guard let t = Catalog.type(id) as? any RealArticulated.Type else { throw RealityHDError.unknown(id) }
        let rig = await Task.detached(priority: .userInitiated) { t.init().rig(seed: seed) }.value
        return try await rig.entityAsync(name: id, state: state, interactive: interactive)
    }

    /// Lighting rig for a scene: its sky, fog and interior probe hints, with `sky` overriding the hint's sun.
    @MainActor
    public static func environment(for scene: RealScene, sky: SunSky? = nil, skybox: Bool = true) throws -> RealEnvironment {
        var s = sky ?? scene.lighting.sky ?? SunSky()
        if let fog = scene.lighting.fog { s.fogDensity = fog }
        if let k = scene.lighting.sunScale { s.sunLux *= k }
        return try RealEnvironment(s, skybox: skybox, interior: scene.lighting.interior)
    }

    /// A composed scene by id (see SceneCatalog.ids).
    public static func scene(_ id: String, seed: UInt64 = 1) async throws -> Entity {
        guard let s = await Task.detached(priority: .userInitiated, operation: { SceneCatalog.build(id, seed: seed) }).value else {
            throw RealityHDError.unknown(id)
        }
        return try await s.entity()
    }

    /// GPU-instanced field of one asset at the given transforms (forests, grass, rocks).
    public static func field<A: RealAsset>(_ asset: A, seed: UInt64 = 1, transforms: [simd_float4x4],
                                           options: RealInstancing.Options = RealInstancing.Options()) async throws -> Entity {
        let lod = await Task.detached(priority: .userInitiated) { asset.build(seed: seed) }.value
        return try await RealInstancing.field(lod, transforms: transforms, name: A.id, options: options)
    }

    @MainActor
    static func upload(_ lod: LODModel, name: String) async throws -> Entity {
        lod.levels.count == 1 ? try await lod.levels[0].modelEntityAsync() : try await lod.entityAsync(name: name)
    }

    public enum RealityHDError: Error { case unknown(String) }
}
