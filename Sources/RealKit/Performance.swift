import Foundation
import Observation
import RealityKit
import RealCore
import RealMaterials

/// Package-wide render settings: texture resolution, LOD bias and culling, instance density, shadow
/// policy, shader feature levels, static batching, light and sky budgets, and the adaptive frame-rate
/// governor. Set once with `RealityHD.setup(...)` or assign `RealPerformance.current` at any time.
///
/// Live settings (LOD, culling, shadows, adaptive) take effect within one LOD tick. Build-time settings
/// (textures, shading, density, batching, lights, sky) apply to entities built afterwards;
/// `needsRebuild(from:)` reports when a loaded scene should be rebuilt.
public struct RealPerformance: Codable, Sendable, Hashable {
    public enum Tier: String, Codable, Sendable, CaseIterable, Identifiable {
        /// Long sessions, thermals first: half textures, short draw distance, sparse ground cover, few shadows.
        case battery
        /// Dense outdoor scenes at a steady 90 fps.
        case performance
        /// Library default (renders and tests use it).
        case balanced
        /// Sharper textures, LODs held longer, more shadow casters.
        case ultra
        /// Captures and offline renders: 4K textures, LOD bias 2, long shadows. Not for live sessions.
        case cinematic
        public var id: String { rawValue }
        public var settings: RealPerformance { RealPerformance(self) }
    }

    /// The tier these values came from (nil once edited by hand).
    public var tier: Tier?

    // Textures (build-time)
    /// Multiplier on every material's base resolution.
    public var textureScale: Float = 1
    /// Largest generated texture side.
    public var maxTextureSize: Int = 1024

    // LOD and culling (live)
    /// Multiplies every LOD switch distance. Below 1 drops detail sooner; above 1 holds it longer.
    public var lodBias: Float = 1
    /// Seconds between LOD evaluations.
    public var lodInterval: Double = 0.2
    /// Hide anything farther than this (meters, 0 = unlimited). Fog should cover the edge.
    public var drawDistance: Float = 0
    /// Objects smaller than `detailSize` (bounds diagonal, meters) hide past this distance (0 = never).
    public var detailCullDistance: Float = 0
    public var detailSize: Float = 0.6
    /// Multiplier on ground-cover cull distances (grass, flowers, pebbles).
    public var groundCoverDistance: Float = 1

    // Instancing (build-time)
    /// Fraction of ground-cover instances kept (hashed, deterministic).
    public var fieldDensity: Float = 1
    /// Fraction of ground-cover instances dropped at the coarsest LOD (the rest scale up to cover).
    public var distantThinning: Float = 0

    // Shadows (live)
    public var shadows = true
    /// Multiplier on the sun's shadow distance.
    public var shadowDistanceScale: Float = 1
    /// LOD levels above this don't cast shadows.
    public var shadowCasterMaxLOD = 1
    /// Objects smaller than this (bounds diagonal, meters) don't cast shadows.
    public var minShadowCasterSize: Float = 0

    // Shading (build-time). Each off switch compiles a cheaper ShaderGraph variant.
    public var wind = true
    public var translucency = true
    public var fog = true
    public var antiTile = true
    public var splat = true
    public var instanceVariation = true
    public var snowLayer = true
    public var waterFlow = true

    // Scene (build-time)
    /// Merge static singles of every scene (interiors already batch).
    public var forceBatching = false
    /// Scene lights kept (brightest first). Articulated lamp lights are not counted.
    public var maxSceneLights = 8
    /// Multiplier on the skybox texture width (capped at 8192).
    public var skyboxScale: Float = 1

    // Runtime governor
    /// Lower LOD bias, draw distances and shadow distance while frames run long; restore when they recover.
    public var adaptive = false
    public var targetFPS: Double = 90
    /// Lowest adaptive multiplier.
    public var minAdaptiveScale: Float = 0.45

    public init() { self.init(.balanced) }

    public init(_ tier: Tier) {
        self.tier = tier
        switch tier {
        case .battery:
            textureScale = 0.5; maxTextureSize = 512
            lodBias = 0.55; lodInterval = 0.25; drawDistance = 140; detailCullDistance = 10; groundCoverDistance = 0.5
            fieldDensity = 0.5; distantThinning = 0.6
            shadowDistanceScale = 0.3; shadowCasterMaxLOD = 0; minShadowCasterSize = 0.5
            wind = false; translucency = false; antiTile = false; splat = false; instanceVariation = false; waterFlow = false
            forceBatching = true; maxSceneLights = 2; skyboxScale = 0.5
            adaptive = true
        case .performance:
            textureScale = 0.5; maxTextureSize = 1024
            lodBias = 0.75; drawDistance = 260; detailCullDistance = 18; groundCoverDistance = 0.75
            fieldDensity = 0.75; distantThinning = 0.4
            shadowDistanceScale = 0.5; shadowCasterMaxLOD = 0; minShadowCasterSize = 0.25
            translucency = false; antiTile = false
            forceBatching = true; maxSceneLights = 4; skyboxScale = 0.75
            adaptive = true
        case .balanced:
            break
        case .ultra:
            maxTextureSize = 2048
            lodBias = 1.35; lodInterval = 0.15
            shadowDistanceScale = 1.5; shadowCasterMaxLOD = 2
            maxSceneLights = 16; skyboxScale = 2
        case .cinematic:
            textureScale = 2; maxTextureSize = 4096
            lodBias = 2; lodInterval = 0.1
            shadowDistanceScale = 2; shadowCasterMaxLOD = 3
            maxSceneLights = 32; skyboxScale = 2
        }
    }

    public func with(_ edit: (inout RealPerformance) -> Void) -> RealPerformance { var c = self; edit(&c); return c }

    // MARK: - Global state

    nonisolated(unsafe) private static var stored = RealPerformance()
    /// Bumped on every change; systems re-apply live policy when it moves.
    nonisolated(unsafe) public private(set) static var generation: UInt64 = 0
    /// Adaptive governor multiplier (1 = no reduction). Runtime only, never persisted.
    nonisolated(unsafe) public internal(set) static var adaptiveScale: Float = 1
    /// Largest sun shadow distance in use (meters, 0 = unknown). Meshes well past it stop casting.
    nonisolated(unsafe) public internal(set) static var shadowReach: Float = 0

    /// The active settings. Assigning applies them (texture quality, LOD interval, cache invalidation).
    @MainActor public static var current: RealPerformance {
        get { stored }
        set {
            let old = stored
            stored = newValue
            generation &+= 1
            if !newValue.adaptive { adaptiveScale = 1 }
            newValue.applyGlobals(previous: old)
        }
    }

    /// Settings read by systems and builders off the main actor.
    public static var active: RealPerformance { stored }

    @MainActor func applyGlobals(previous: RealPerformance) {
        RealQuality.textureScale = textureScale
        RealQuality.maxTextureSize = maxTextureSize
        RealLODSystem.interval = lodInterval
        if previous.textureScale != textureScale || previous.maxTextureSize != maxTextureSize {
            RealMaterialCache.shared.purge()
        } else if previous.shadingKey != shadingKey {
            RealMaterialCache.shared.invalidateShaders()
        }
    }

    // MARK: - Change classification

    var shadingKey: [Bool] { [wind, translucency, fog, antiTile, splat, instanceVariation, snowLayer, waterFlow] }

    /// Settings that only reach entities built after the change.
    struct BuildKey: Hashable {
        var tex: Float, maxTex: Int, shading: [Bool], density: Float, thinning: Float, batching: Bool, lights: Int, sky: Float
    }
    var buildKey: BuildKey {
        BuildKey(tex: textureScale, maxTex: maxTextureSize, shading: shadingKey, density: fieldDensity, thinning: distantThinning,
                 batching: forceBatching, lights: maxSceneLights, sky: skyboxScale)
    }

    /// True when a scene built with `previous` must be rebuilt to show these settings.
    public func needsRebuild(from previous: RealPerformance) -> Bool { buildKey != previous.buildKey }

    // MARK: - Persistence

    public static let defaultsKey = "realityhd.performance"

    public func save(to defaults: UserDefaults = .standard, key: String = RealPerformance.defaultsKey) {
        if let d = try? JSONEncoder().encode(self) { defaults.set(d, forKey: key) }
    }

    /// Saved settings, or nil when absent or written by an incompatible version.
    public static func load(from defaults: UserDefaults = .standard, key: String = RealPerformance.defaultsKey) -> RealPerformance? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(RealPerformance.self, from: $0) }
    }

    // MARK: - Policy (pure; shared by systems, builders and estimators)

    /// Level to show at `distance` (nil = hidden). `switchDistances` as in `LODModel`.
    /// `cullDistance` is the entity's own cull (ground cover), `size` its bounds diagonal.
    public func level(distance d: Float, switchDistances: [Float], cullDistance: Float = 0, groundCover: Bool = false,
                      size: Float = .infinity, adaptive: Float = 1) -> Int? {
        if hidden(distance: d, cullDistance: cullDistance, groundCover: groundCover, size: size, adaptive: adaptive) { return nil }
        let e = d / max(0.05, lodBias * adaptive)
        return switchDistances.firstIndex(where: { e < $0 }) ?? switchDistances.count
    }

    public func hidden(distance d: Float, cullDistance: Float, groundCover: Bool, size: Float, adaptive: Float = 1) -> Bool {
        if cullDistance > 0 && d > cullDistance * (groundCover ? groundCoverDistance * adaptive : 1) { return true }
        if drawDistance > 0 && d > drawDistance * max(adaptive, 0.6) { return true }
        if detailCullDistance > 0 && size < detailSize && d > detailCullDistance * adaptive { return true }
        return false
    }

    /// Whether a mesh casts sun shadows. `eligible`: the author allows it (glass, sky, ground cover say no).
    /// `lodShift`: extra LOD levels allowed (instanced fields carry their option's caster limit).
    public func castsShadow(lod: Int, size: Float, eligible: Bool = true, lodShift: Int = 0) -> Bool {
        shadows && eligible && size >= minShadowCasterSize && lod <= shadowCasterMaxLOD + lodShift
    }

    /// Ground-cover instances kept at build time.
    public func thinned(_ transforms: [simd_float4x4]) -> [simd_float4x4] {
        guard fieldDensity < 1 else { return transforms }
        return transforms.filter { instanceHash(origin($0), salt: 11) < fieldDensity }
    }

    /// Instances drawn at LOD `level` of `levels` for a thinnable field: coarse levels drop a share and
    /// scale the survivors so coverage holds.
    public func instances(_ transforms: [simd_float4x4], level: Int, levels: Int) -> [simd_float4x4] {
        guard distantThinning > 0, levels > 1, level > 0 else { return transforms }
        let keep = max(0.15, 1 - distantThinning * Float(level) / Float(levels - 1))
        let grow = min(1.6, 1 / keep.squareRoot())
        return transforms.compactMap { t in
            guard instanceHash(origin(t), salt: 19) < keep else { return nil }
            return t * simd_float4x4(diagonal: SIMD4(grow, 1, grow, 1))
        }
    }
}

@inline(__always) func origin(_ t: simd_float4x4) -> SIMD3<Float> { SIMD3(t.columns.3.x, t.columns.3.y, t.columns.3.z) }

// MARK: - Per-entity cost and shadow eligibility

/// Render cost of one mesh entity (a LOD child, a field cell LOD, a batch). Drives the stats overlay and
/// the live shadow policy.
public struct RealRenderCostComponent: Component {
    public var triangles: Int
    public var drawCalls: Int
    public var instances: Int
    /// Bounds diagonal of one instance, meters.
    public var size: Float
    public var lod: Int
    /// The author allows shadows on this mesh.
    public var shadowEligible: Bool
    public var lodShift: Int
    /// Set by `RealLODSystem` while the mesh sits beyond the sun's shadow reach: it stops casting.
    var beyondShadowReach = false
    var appliedGeneration: UInt64 = .max

    public init(triangles: Int, drawCalls: Int, instances: Int = 1, size: Float, lod: Int, shadowEligible: Bool = true, lodShift: Int = 0) {
        self.triangles = triangles; self.drawCalls = drawCalls; self.instances = instances
        self.size = size; self.lod = lod; self.shadowEligible = shadowEligible; self.lodShift = lodShift
    }
}

public extension Entity {
    /// Tags a mesh entity with its cost and applies the current shadow policy.
    func realTagCost(_ cost: RealRenderCostComponent) {
        components.set(cost)
        realApplyShadowPolicy(force: true)
    }

    /// Marks the mesh as past the shadow reach (or back inside it) and re-applies the policy when that changes.
    func realSetBeyondShadowReach(_ beyond: Bool) {
        guard var c = components[RealRenderCostComponent.self] else { return }
        if c.beyondShadowReach == beyond { realApplyShadowPolicy(); return }
        c.beyondShadowReach = beyond
        components.set(c)
        realApplyShadowPolicy(force: true)
    }

    /// Re-applies the shadow policy if settings moved since it was last applied.
    func realApplyShadowPolicy(force: Bool = false) {
        guard var c = components[RealRenderCostComponent.self] else { return }
        let gen = RealPerformance.generation
        guard force || c.appliedGeneration != gen else { return }
        c.appliedGeneration = gen
        components.set(c)
        let cast = !c.beyondShadowReach && RealPerformance.active.castsShadow(lod: c.lod, size: c.size, eligible: c.shadowEligible, lodShift: c.lodShift)
        components.set(DynamicLightShadowComponent(castsShadow: cast))
    }
}

public extension Model {
    /// Bounds diagonal in meters.
    var boundsDiagonal: Float { let b = bounds; return simd_length(b.max - b.min) }
}

/// Marks the sun entity of a `RealEnvironment` so shadow settings reach it live.
public struct RealSunComponent: Component {
    public var baseShadowDistance: Float
    public init(baseShadowDistance: Float) { self.baseShadowDistance = baseShadowDistance }
}

// MARK: - Stats

/// Live frame and scene statistics, refreshed twice a second by `RealPerformanceSystem`.
@MainActor @Observable
public final class RealStats {
    public static let shared = RealStats()
    public internal(set) var fps: Double = 0
    public internal(set) var frameMs: Double = 0
    /// Longest frame in the last window.
    public internal(set) var worstFrameMs: Double = 0
    /// Triangles of every enabled mesh (instances included), before frustum culling.
    public internal(set) var triangles = 0
    public internal(set) var drawCalls = 0
    public internal(set) var instances = 0
    public internal(set) var shadowCasters = 0
    public internal(set) var meshEntities = 0
    /// LOD switches per second.
    public internal(set) var lodSwitches = 0
    public internal(set) var adaptiveScale: Float = 1
    public internal(set) var textureMB = 0
    /// Walks every costed entity to fill the counts. Frame timing stays on regardless. Turn off in shipping
    /// builds that show no overlay; `collectInterval` sets the walk period.
    nonisolated(unsafe) public static var collecting = true
    nonisolated(unsafe) public static var collectInterval: Double = 0.5
    init() {}

    public var summary: String {
        String(format: "%.0f fps %.1f ms (max %.1f)  %dk tris  %d draws  %d inst  %d casters  adapt %.2f  tex %dMB",
               fps, frameMs, worstFrameMs, triangles / 1000, drawCalls, instances, shadowCasters, adaptiveScale, textureMB)
    }
}

// MARK: - System

/// Frame timing, stats, adaptive governor, and live shadow policy.
public struct RealPerformanceSystem: System {
    static let costQuery = EntityQuery(where: .has(RealRenderCostComponent.self))
    static let sunQuery = EntityQuery(where: .has(RealSunComponent.self))
    nonisolated(unsafe) static var lodSwitchCounter = 0
    static var collectWindow: Double { max(0.25, RealStats.collectInterval) }

    private var generation: UInt64 = .max
    private var sunScale: Float = -1
    private var window: Double = 0, frames = 0, worst: Double = 0
    private var ema: Double = 0
    private var slowFor: Double = 0, fastFor: Double = 0, cooldown: Double = 0

    public init(scene: RealityKit.Scene) {}

    public mutating func update(context: SceneUpdateContext) {
        let dt = context.deltaTime
        guard dt > 0 else { return }
        let perf = RealPerformance.active
        frames += 1; window += dt; worst = max(worst, dt)
        ema = ema == 0 ? dt : ema * 0.9 + dt * 0.1

        if perf.adaptive { govern(dt, perf) }

        if RealPerformance.generation != generation {
            generation = RealPerformance.generation
            for e in context.entities(matching: Self.costQuery, updatingSystemWhen: .rendering) { e.realApplyShadowPolicy() }
            sunScale = -1
        }
        let s = perf.shadowDistanceScale * RealPerformance.adaptiveScale
        if s != sunScale {
            sunScale = s
            var reach: Float = 0
            for e in context.entities(matching: Self.sunQuery, updatingSystemWhen: .rendering) {
                guard let sun = e.components[RealSunComponent.self] else { continue }
                if perf.shadows { reach = max(reach, max(2, sun.baseShadowDistance * s)) }
                if perf.shadows {
                    var sh = DirectionalLightComponent.Shadow()
                    sh.shadowProjection = .automatic(maximumDistance: max(2, sun.baseShadowDistance * s))
                    sh.depthBias = 1.5
                    e.components.set(sh)
                } else {
                    e.components.remove(DirectionalLightComponent.Shadow.self)
                }
            }
            RealPerformance.shadowReach = reach
        }

        guard window >= Self.collectWindow else { return }
        guard RealStats.collecting else {
            // Timing only: no entity walk.
            let fps = Double(frames) / window, frameMs = window / Double(frames) * 1000, worstMs = worst * 1000
            window = 0; frames = 0; worst = 0
            MainActor.assumeIsolated {
                let st = RealStats.shared
                st.fps = fps; st.frameMs = frameMs; st.worstFrameMs = worstMs; st.adaptiveScale = RealPerformance.adaptiveScale
            }
            return
        }
        var tris = 0, draws = 0, inst = 0, casters = 0, meshes = 0
        for e in context.entities(matching: Self.costQuery, updatingSystemWhen: .rendering) where e.isActive {
            guard let c = e.components[RealRenderCostComponent.self] else { continue }
            meshes += 1; tris += c.triangles * c.instances; draws += c.drawCalls; inst += c.instances
            if e.components[DynamicLightShadowComponent.self]?.castsShadow ?? true { casters += 1 }
        }
        let fps = Double(frames) / window, frameMs = window / Double(frames) * 1000, worstMs = worst * 1000
        let switches = Int(Double(Self.lodSwitchCounter) / window)
        Self.lodSwitchCounter = 0
        window = 0; frames = 0; worst = 0
        MainActor.assumeIsolated {
            let st = RealStats.shared
            st.fps = fps; st.frameMs = frameMs; st.worstFrameMs = worstMs
            st.triangles = tris; st.drawCalls = draws; st.instances = inst; st.shadowCasters = casters; st.meshEntities = meshes
            st.lodSwitches = switches; st.adaptiveScale = RealPerformance.adaptiveScale
            st.textureMB = RealMaterialCache.shared.textureBytes / 1_048_576
        }
    }

    /// Steps the adaptive scale down after 0.75 s of long frames, up after 4 s at target (6 s after a drop).
    private mutating func govern(_ dt: Double, _ perf: RealPerformance) {
        let budget = 1 / max(30, perf.targetFPS)
        cooldown = max(0, cooldown - dt)
        if ema > budget * 1.12 { slowFor += dt; fastFor = 0 } else if ema < budget * 1.04 { fastFor += dt; slowFor = 0 }
        var scale = RealPerformance.adaptiveScale
        if slowFor > 0.75, scale > perf.minAdaptiveScale {
            scale = max(perf.minAdaptiveScale, scale * 0.88); slowFor = 0; cooldown = 6
        } else if fastFor > 4, cooldown == 0, scale < 1 {
            scale = min(1, scale * 1.08); fastFor = 0
        }
        RealPerformance.adaptiveScale = scale
    }
}
