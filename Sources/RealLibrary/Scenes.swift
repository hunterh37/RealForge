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
    public init(name: String) { self.name = name }

    @MainActor
    public func entity(materials: RealMaterialCache? = nil) async throws -> Entity {
        let root = Entity()
        root.name = name
        for f in fields { root.addChild(try await RealInstancing.field(f.asset, transforms: f.transforms, options: f.options, materials: materials)) }
        for s in singles {
            let e: Entity
            if s.asset.levels.count == 1 { e = try await s.asset.levels[0].modelEntityAsync(materials: materials) }
            else { e = try await s.asset.entityAsync(materials: materials) }
            e.transform = Transform(scale: s.at.scale, rotation: s.at.rotation, translation: s.at.translation)
            root.addChild(e)
        }
        return root
    }
}

public enum SceneCatalog {
    public static let ids: [String] = ["forest-glade"]
    public static func build(_ id: String, seed: UInt64) -> RealScene? {
        switch id {
        case "forest-glade": return ForestGlade().build(seed: seed)
        default: return nil
        }
    }
}

/// Open glade ringed by mixed conifer/broadleaf forest: terrain, ~140 instanced trees (3 variants per
/// species, 3 LODs), boulders, shrubs, and thousands of wind-animated grass clumps.
public struct ForestGlade {
    public var radius: Float = 45
    public var gladeRadius: Float = 9
    public var trees = 140
    public var grass = 7000
    public init() {}

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: "forest-glade")
        let ground = GroundPatch().with { $0.size = radius * 2.2; $0.segments = 160; $0.relief = 0.6; $0.flatCenter = gladeRadius * 0.6 }
        scene.singles.append(.init(asset: ground.build(seed: seed), at: .identity))
        func y(_ p: V2) -> Float { ground.height(x: p.x, z: p.y, seed: seed) }
        func xf(_ p: V2, _ rng: inout SeededRNG, scale: ClosedRange<Float>, sink: Float = 0.05) -> simd_float4x4 {
            Xform(translation: V3(p.x, y(p) - sink, p.y), rotation: simd_quatf(degrees: rng.float(0...360), axis: .up),
                  scale: V3(repeating: rng.float(scale))).matrix
        }
        var rng = SeededRNG(seed: seed &+ 99)

        // Trees: ring around the glade, denser with distance.
        let spots = Scatter.poisson(count: trees, outerRadius: radius, innerRadius: gladeRadius + 3, minSpacing: 3.6, seed: seed &+ 1) { p in
            let d = simd_length(p); return d > gladeRadius + 6 || Float(abs(Noise.perlin(V3(p.x * 0.2, 0, p.y * 0.2)))) > 0.25
        }
        let species: [(TreeSpecies, Float)] = [(.spruce, 0.5), (.oak, 0.28), (.birch, 0.22)]
        var buckets: [[[simd_float4x4]]] = species.map { _ in [[], [], []] }
        for p in spots {
            let r = rng.float()
            var acc: Float = 0, si = 0
            for (i, s) in species.enumerated() { acc += s.1; if r < acc { si = i; break } }
            buckets[si][rng.int(0...2)].append(xf(p, &rng, scale: 0.8...1.2, sink: 0.12))
        }
        var opts = RealInstancing.Options(); opts.cellSize = 18
        for (si, (sp, _)) in species.enumerated() {
            for v in 0..<3 where !buckets[si][v].isEmpty {
                scene.fields.append(.init(asset: Tree(sp).build(seed: seed &+ UInt64(si * 10 + v)), transforms: buckets[si][v], options: opts))
            }
        }

        // Shrubs at the forest edge.
        let shrubSpots = Scatter.poisson(count: 45, outerRadius: radius * 0.9, innerRadius: gladeRadius + 1, minSpacing: 2.2, seed: seed &+ 2)
        scene.fields.append(.init(asset: Shrub().build(seed: seed &+ 3), transforms: shrubSpots.map { xf($0, &rng, scale: 0.7...1.4) }, options: opts))

        // Boulders: a few in the glade, more in the woods.
        let rocks = Scatter.poisson(count: 16, outerRadius: radius * 0.8, innerRadius: 4, minSpacing: 5, seed: seed &+ 4)
        for (i, p) in rocks.enumerated() {
            scene.singles.append(.init(asset: Boulder().with { $0.size = V3(1.4, 0.9, 1.2) * rng.float(0.6...1.6) }.build(seed: seed &+ UInt64(40 + i)),
                                       at: Xform(translation: V3(p.x, y(p), p.y), rotation: simd_quatf(degrees: rng.float(0...360), axis: .up))))
        }

        // Grass: dense in the glade, thinning under the canopy, culled with distance.
        var gopts = RealInstancing.Options(); gopts.cellSize = 8; gopts.cullDistance = 30; gopts.shadowCasterMaxLOD = -1
        let blades = Scatter.uniform(count: grass, outerRadius: radius * 0.7, seed: seed &+ 5) { p in
            let d = simd_length(p)
            let density = d < gladeRadius ? 1 : max(0.15, 1 - (d - gladeRadius) / 18)
            return Float(Noise.perlin(V3(p.x * 0.35, 1, p.y * 0.35))) * 0.5 + 0.5 < density
        }
        let half = blades.count / 2
        scene.fields.append(.init(asset: GrassClump().build(seed: seed &+ 6), transforms: blades[..<half].map { xf($0, &rng, scale: 0.7...1.3, sink: 0.02) }, options: gopts))
        scene.fields.append(.init(asset: GrassClump().with { $0.height = 0.3; $0.width = 0.4 }.build(seed: seed &+ 7),
                                  transforms: blades[half...].map { xf($0, &rng, scale: 0.7...1.3, sink: 0.02) }, options: gopts))

        let eyeY = y(V2(0, 6)) + 1.6
        scene.camera = .init(eye: V3(0, eyeY, 6), target: V3(-6, eyeY + 1.2, -14), fov: 60)
        return scene
    }
}
