import Foundation
import RealityKit
import RealKit

/// One-call entry points. Geometry is generated off the main actor (all generators are pure and
/// Sendable); GPU upload, texture synthesis and ShaderGraph compilation happen on the main actor.
public enum RealForge {
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
        guard let t = Catalog.type(id) else { throw RealForgeError.unknown(id) }
        let lod = await Task.detached(priority: .userInitiated) { t.init().build(seed: seed) }.value
        return try await upload(lod, name: id)
    }

    /// Any RealAsset value (custom parameters) as an entity.
    public static func entity<A: RealAsset>(_ asset: A, seed: UInt64 = 1) async throws -> Entity {
        let lod = await Task.detached(priority: .userInitiated) { asset.build(seed: seed) }.value
        return try await upload(lod, name: A.id)
    }

    /// A composed scene by id (see SceneCatalog.ids).
    public static func scene(_ id: String, seed: UInt64 = 1) async throws -> Entity {
        guard let s = await Task.detached(priority: .userInitiated, operation: { SceneCatalog.build(id, seed: seed) }).value else {
            throw RealForgeError.unknown(id)
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

    public enum RealForgeError: Error { case unknown(String) }
}
