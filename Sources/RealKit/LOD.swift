import Foundation
import RealityKit
import RealCore

/// Where LOD distances are measured from. On visionOS, RealityKit can't read head pose from a System,
/// so either set `RealViewer.position` yourself (e.g. from ARKit `queryDeviceAnchor`) or call
/// `RealViewer.startTracking()` inside an ImmersiveSpace (see Viewer.swift).
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
    public var center: SIMD3<Float> = .zero
    public init(switchDistances: [Float], cullDistance: Float = 0, center: SIMD3<Float> = .zero) {
        self.switchDistances = switchDistances; self.cullDistance = cullDistance; self.center = center
    }
}

public struct RealLODSystem: System {
    static let query = EntityQuery(where: .has(RealLODComponent.self))
    /// Evaluate at most this often (seconds). LOD needs no per-frame precision.
    nonisolated(unsafe) public static var interval: Double = 0.2
    private var accumulator: Double = 0

    public init(scene: RealityKit.Scene) {}

    public mutating func update(context: SceneUpdateContext) {
        accumulator += context.deltaTime
        guard accumulator >= Self.interval else { return }
        accumulator = 0
        let viewer = MainActor.assumeIsolated { RealViewer.position }
        for e in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var lod = e.components[RealLODComponent.self] else { continue }
            let p = e.convert(position: lod.center, to: nil)
            let d = simd_distance(p, viewer)
            var level = lod.switchDistances.firstIndex(where: { d < $0 }) ?? lod.switchDistances.count
            // Hysteresis: only move to a coarser level once past the boundary by the margin.
            if lod.current >= 0, level != lod.current {
                let boundary = level > lod.current ? lod.switchDistances[lod.current] : lod.switchDistances[level]
                if abs(d - boundary) < boundary * lod.hysteresis { level = lod.current }
            }
            let culled = lod.cullDistance > 0 && d > lod.cullDistance
            if level != lod.current || culled {
                for c in e.children where c.name.hasPrefix("lod") {
                    let i = Int(c.name.dropFirst(3)) ?? 0
                    c.isEnabled = !culled && i == level
                }
                lod.current = level
                e.components.set(lod)
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
            if !castsShadow || i == levels.count - 1 && levels.count > 2 { e.components.set(DynamicLightShadowComponent(castsShadow: castsShadow && i < 2)) }
            root.addChild(e)
        }
        if levels.count > 1 {
            let b = levels[0].bounds
            root.components.set(RealLODComponent(switchDistances: switchDistances, center: (b.min + b.max) / 2))
        }
        return root
    }
}

public extension LODModel {
    /// Async variant with ShaderGraph (wind) materials.
    @MainActor
    func entityAsync(name: String = "asset", materials: RealMaterialCache? = nil) async throws -> Entity {
        let root = Entity()
        root.name = name
        for (i, m) in levels.enumerated() {
            let e = try await m.modelEntityAsync(materials: materials)
            e.name = "lod\(i)"
            e.isEnabled = i == 0
            if i >= 2 { e.components.set(DynamicLightShadowComponent(castsShadow: false)) }
            root.addChild(e)
        }
        if levels.count > 1 {
            let b = levels[0].bounds
            root.components.set(RealLODComponent(switchDistances: switchDistances, center: (b.min + b.max) / 2))
        }
        return root
    }
}
