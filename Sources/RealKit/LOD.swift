import Foundation
import RealityKit
import RealCore

/// Where LOD distances are measured from (scene space). On visionOS call
/// `await RealViewerTracker.shared.start()` inside an ImmersiveSpace to follow the head; otherwise set
/// `RealViewer.position` yourself.
@MainActor
public enum RealViewer {
    public static var position: SIMD3<Float> = SIMD3(0, 1.6, 0)
}

/// Discrete LOD switching: children named "lod0", "lod1", ... are enabled by distance from the viewer
/// to this entity (or its bounds center). Hysteresis prevents popping back and forth at a boundary.
public struct RealLODComponent: Component {
    public var switchDistances: [Float]
    public var hysteresis: Float = 0.08
    /// Fully hide beyond this distance (0 = never).
    public var cullDistance: Float = 0
    public var current: Int = -1
    /// True while hidden past `cullDistance` (every LOD child disabled).
    public var culled = false
    public var center: SIMD3<Float> = .zero
    /// Bounds diagonal (meters): small objects fall under `RealPerformance.detailCullDistance`.
    public var size: Float = .infinity
    /// Ground cover: `cullDistance` scales with `RealPerformance.groundCoverDistance`.
    public var groundCover = false
    public init(switchDistances: [Float], cullDistance: Float = 0, center: SIMD3<Float> = .zero, size: Float = .infinity, groundCover: Bool = false) {
        self.switchDistances = switchDistances; self.cullDistance = cullDistance; self.center = center
        self.size = size; self.groundCover = groundCover
    }
}

public struct RealLODSystem: System {
    static let query = EntityQuery(where: .has(RealLODComponent.self))
    /// Evaluate at most this often (seconds). LOD needs no per-frame precision.
    nonisolated(unsafe) public static var interval: Double = 0.2
    /// Starts full so the first update picks levels before LOD0 of every cell renders for a tick.
    private var accumulator: Double = .greatestFiniteMagnitude

    public init(scene: RealityKit.Scene) {}

    public mutating func update(context: SceneUpdateContext) {
        accumulator += context.deltaTime
        guard accumulator >= Self.interval else { return }
        accumulator = 0
        let viewer = MainActor.assumeIsolated { RealViewer.refresh(); return RealViewer.position }
        let perf = RealPerformance.active, adapt = RealPerformance.adaptiveScale
        let bias = max(0.05, perf.lodBias * adapt)
        var switches = 0
        for e in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var lod = e.components[RealLODComponent.self] else { continue }
            let p = e.convert(position: lod.center, to: nil)
            let d = simd_distance(p, viewer)
            let culled = perf.hidden(distance: d, cullDistance: lod.cullDistance, groundCover: lod.groundCover, size: lod.size, adaptive: adapt)
            // Switch distances scale with the bias; hysteresis works on the scaled distance.
            let ed = d / bias
            var level = lod.switchDistances.firstIndex(where: { ed < $0 }) ?? lod.switchDistances.count
            // Hysteresis: only move to a coarser level once past the boundary by the margin.
            if lod.current >= 0, level != lod.current {
                let boundary = level > lod.current ? lod.switchDistances[lod.current] : lod.switchDistances[level]
                if abs(ed - boundary) < boundary * lod.hysteresis { level = lod.current }
            }
            if level != lod.current || culled != lod.culled {
                Self.apply(level: level, culled: culled, under: e)
                if level != lod.current { switches += 1 }
                lod.current = level
                lod.culled = culled
                e.components.set(lod)
            }
        }
        RealPerformanceSystem.lodSwitchCounter += switches
    }
}

extension RealLODSystem {
    /// Enables `lod<level>` children of `e` and of its descendants (articulated parts, option groups),
    /// without crossing into entities that run their own LOD.
    static func apply(level: Int, culled: Bool, under e: Entity) {
        for c in e.children {
            if c.name.hasPrefix("lod"), let i = Int(c.name.dropFirst(3)) {
                let on = !culled && i == level
                if on { c.realApplyShadowPolicy() }
                c.isEnabled = on
            } else if !c.components.has(RealLODComponent.self) {
                apply(level: level, culled: culled, under: c)
            }
        }
    }
}

public enum RealKitSetup {
    @MainActor private static var registered = false
    /// Registers components/systems. Call once (e.g. in App.init). Idempotent.
    @MainActor public static func register() {
        guard !registered else { return }
        registered = true
        RealLODComponent.registerComponent()
        RealLODSystem.registerSystem()
        RealJointComponent.registerComponent()
        RealArticulationComponent.registerComponent()
        RealArticulationSystem.registerSystem()
        RealRenderCostComponent.registerComponent()
        RealSunComponent.registerComponent()
        RealPerformanceSystem.registerSystem()
    }
}

public extension LODModel {
    /// Entity with one child per LOD ("lod0"...), switched by RealLODSystem.
    @MainActor
    func entity(name: String = "asset", materials: RealMaterialCache? = nil, castsShadow: Bool = true) throws -> Entity {
        let root = Entity()
        root.name = name
        for (i, m) in levels.enumerated() {
            let e = try m.modelEntity(materials: materials)
            e.name = "lod\(i)"
            e.isEnabled = i == 0
            e.realTagCost(m.cost(lod: i, size: levels[0].boundsDiagonal, shadowEligible: castsShadow))
            root.addChild(e)
        }
        if levels.count > 1 {
            let b = levels[0].bounds
            root.components.set(RealLODComponent(switchDistances: switchDistances, center: (b.min + b.max) / 2, size: simd_length(b.max - b.min)))
        }
        return root
    }
}

public extension LODModel {
    /// Async variant with ShaderGraph (wind) materials.
    @MainActor
    func entityAsync(name: String = "asset", materials: RealMaterialCache? = nil, castsShadow: Bool = true) async throws -> Entity {
        let root = Entity()
        root.name = name
        for (i, m) in levels.enumerated() {
            let e = try await m.modelEntityAsync(materials: materials)
            e.name = "lod\(i)"
            e.isEnabled = i == 0
            e.realTagCost(m.cost(lod: i, size: levels[0].boundsDiagonal, shadowEligible: castsShadow))
            root.addChild(e)
        }
        if levels.count > 1 {
            let b = levels[0].bounds
            root.components.set(RealLODComponent(switchDistances: switchDistances, center: (b.min + b.max) / 2, size: simd_length(b.max - b.min)))
        }
        return root
    }
}

public extension Model {
    /// Cost tag for one mesh entity built from this model.
    func cost(lod: Int, size: Float, instances: Int = 1, shadowEligible: Bool = true, lodShift: Int = 0) -> RealRenderCostComponent {
        RealRenderCostComponent(triangles: triangleCount, drawCalls: surfaces.filter { !$0.isEmpty }.count, instances: instances,
                                size: size, lod: lod, shadowEligible: shadowEligible, lodShift: lodShift)
    }
}
