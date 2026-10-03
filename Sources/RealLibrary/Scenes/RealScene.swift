import simd
import Foundation
import RealityKit
import RealKit

/// A composed scene: instanced fields + single hero assets + camera hint.
public struct RealScene {
    public struct Field { public var asset: LODModel; public var transforms: [simd_float4x4]; public var options: RealInstancing.Options }
    public struct Single { public var asset: LODModel; public var at: Xform }
    public struct Camera { public var eye: V3; public var target: V3; public var fov: Float }
    public var name: String
    public var fields: [Field] = []
    public var singles: [Single] = []
    public var camera: Camera?
    /// Huge flat ground under everything so the horizon is land fading into aerial haze.
    public var farGround: MaterialKey? = "ground.meadow"
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
        for s in singles {
            let e: Entity
            if s.asset.levels.count == 1 { e = try await s.asset.levels[0].modelEntityAsync(materials: materials) }
            else { e = try await s.asset.entityAsync(materials: materials) }
            e.transform = Transform(scale: s.at.scale, rotation: s.at.rotation, translation: s.at.translation)
            root.addChild(e)
        }
        return root
    }

    // MARK: - building helpers

    /// One asset instance (hero object, not instanced).
    public mutating func add<A: RealAsset>(_ asset: A, at: Xform = .identity, seed: UInt64) {
        singles.append(.init(asset: asset.build(seed: seed), at: at))
    }

    /// A one-off model (paths, pads, walls) that is not a catalog asset.
    public mutating func add(_ model: Model, at: Xform = .identity) {
        singles.append(.init(asset: LODModel(model), at: at))
    }

    /// GPU-instanced copies of one asset build. Use for anything repeated more than ~10 times.
    public mutating func field<A: RealAsset>(_ asset: A, seed: UInt64, transforms: [simd_float4x4],
                                             options: RealInstancing.Options = RealInstancing.Options()) {
        guard !transforms.isEmpty else { return }
        fields.append(.init(asset: asset.build(seed: seed), transforms: transforms, options: options))
    }

    /// LOD0 triangles if every instance were at LOD0 (upper bound used by budget tests).
    public var worstCaseTriangles: Int {
        singles.reduce(0) { $0 + $1.asset.levels[0].triangleCount }
            + fields.reduce(0) { $0 + $1.asset.levels[0].triangleCount * $1.transforms.count }
    }
}
