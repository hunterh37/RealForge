import Foundation
import RealityKit
import RealKit

/// One-call entry points. Geometry is generated off the main actor (all generators are pure and
/// Sendable); GPU upload, texture synthesis and ShaderGraph compilation happen on the main actor.
public enum RealityHD {
    /// Register systems/components and apply a performance tier. Call once at app start.
    /// `adaptive` overrides the tier's governor switch.
    @MainActor
    public static func setup(_ tier: RealPerformance.Tier = .balanced, adaptive: Bool? = nil) {
        var s = RealPerformance(tier)
        if let adaptive { s.adaptive = adaptive }
        setup(s)
    }

    /// Register systems/components and apply explicit settings.
    @MainActor
    public static func setup(_ settings: RealPerformance) {
        RealKitSetup.register()
        RealPerformance.current = settings
    }

    /// Register systems/components and restore settings saved with `RealPerformance.save()`
    /// (or `fallback` on first launch). Returns the applied settings.
    @MainActor @discardableResult
    public static func setup(restoring key: String = RealPerformance.defaultsKey, fallback: RealPerformance.Tier = .balanced,
                             defaults: UserDefaults = .standard) -> RealPerformance {
        let s = RealPerformance.load(from: defaults, key: key) ?? RealPerformance(fallback)
        setup(s)
        return s
    }

    /// Texture-only presets (RealityHD 4 API).
    @MainActor
    public static func setup(quality: RealQuality.Preset) {
        RealQuality.apply(quality)
        RealKitSetup.register()
    }

    /// The active performance settings. Assigning applies live settings at once; build-time settings
    /// reach entities built afterwards (`RealPerformance.needsRebuild(from:)`).
    @MainActor
    public static var performance: RealPerformance {
        get { RealPerformance.current }
        set { RealPerformance.current = newValue }
    }

    /// Live frame and scene statistics (fps, triangles, draws, shadow casters, adaptive scale).
    @MainActor public static var stats: RealStats { RealStats.shared }

    /// Outdoor lighting rig. Add `env.root` to the scene and call `env.illuminate(content)`.
    @MainActor
    public static func environment(_ sky: SunSky = SunSky(), skybox: Bool = false) throws -> RealEnvironment {
        try RealEnvironment(sky, skybox: skybox)
    }

    /// Any catalog asset as an entity with LOD children (ShaderGraph wind/fog materials).
    /// `grabbable` (default: assets tagged `handheld`) adds hand pick-up on visionOS.
    public static func entity(_ id: String, seed: UInt64 = 1, grabbable: Bool? = nil) async throws -> Entity {
        guard let t = Catalog.type(id) else { throw RealityHDError.unknown(id) }
        let lod = await Task.detached(priority: .userInitiated) { t.init().build(seed: seed) }.value
        let e = try await upload(lod, name: id)
        if grabbable ?? t.handheld { await MainActor.run { let b = lod.levels[0].bounds; e.makeGrabbable(min: b.min, max: b.max) } }
        return e
    }

    /// Any RealAsset value (custom parameters) as an entity.
    public static func entity<A: RealAsset>(_ asset: A, seed: UInt64 = 1) async throws -> Entity {
        let lod = await Task.detached(priority: .userInitiated) { asset.build(seed: seed) }.value
        return try await upload(lod, name: A.id)
    }

    /// An articulated asset as a live entity: parts move with `entity.setArticulation("open")`,
    /// `nextArticulation()` or, with `interactive`, `realToggle()` from a tap gesture.
    /// `grabbable` (default: assets tagged `handheld`) lets a hand pick the whole object up while taps on
    /// parts still toggle them.
    public static func articulated(_ id: String, seed: UInt64 = 1, state: String? = nil, interactive: Bool = true,
                                   grabbable: Bool? = nil) async throws -> Entity {
        guard let t = Catalog.type(id) as? any RealArticulated.Type else { throw RealityHDError.unknown(id) }
        let rig = await Task.detached(priority: .userInitiated) { t.init().rig(seed: seed) }.value
        return try await rig.entityAsync(name: id, state: state, interactive: interactive, grabbable: grabbable ?? t.handheld)
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
        guard lod.levels.count == 1 else { return try await lod.entityAsync(name: name) }
        let e = try await lod.levels[0].modelEntityAsync()
        e.realTagCost(RealRenderCostComponent(triangles: lod.levels[0].triangleCount, drawCalls: lod.levels[0].surfaces.filter { !$0.isEmpty }.count,
                                              size: simd_length(lod.levels[0].bounds.max - lod.levels[0].bounds.min), lod: 0))
        return e
    }

    public enum RealityHDError: Error { case unknown(String) }
}
