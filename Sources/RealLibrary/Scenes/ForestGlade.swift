import simd
import Foundation
import RealityKit
import RealKit

/// Open glade ringed by mixed conifer/broadleaf forest: terrain, ~140 instanced trees (3 variants per
/// species, 3 LODs), boulders, shrubs, and thousands of wind-animated grass clumps.
public struct ForestGlade: RealSceneBuilder {
    public static let id = "forest-glade"
    public static let summary = "Glade ringed by ~140 instanced spruce, oak and birch, boulders, shrubs, edge camp props and 7k grass clumps."
    public static let tags = ["nature", "forest", "camp"]

    public var radius: Float = 45
    public var gladeRadius: Float = 9
    public var trees = 140
    public var grass = 7000
    /// Camp props (picnic table, crates on a pallet, barrels, drum) along the glade's edge.
    public var edgeProps = true
    public init() {}

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
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

        // Edge camp: props sit just inside the tree line, facing the glade center.
        if edgeProps {
            func edge(_ deg: Float, _ r: Float, yawJitter: Float = 0) -> Xform {
                let a = deg * .pi / 180, p = V2(sin(a) * r, -cos(a) * r)
                let face = deg + 180 + rng.float(-yawJitter...yawJitter)
                return Xform(translation: V3(p.x, y(p) - 0.02, p.y), rotation: simd_quatf(degrees: face, axis: .up))
            }
            func one<A: RealAsset>(_ a: A, _ at: Xform, _ s: UInt64) { scene.singles.append(.init(asset: a.build(seed: seed &+ s), at: at)) }
            func local(_ base: Xform, _ x: Float, _ z: Float, y dy: Float = 0, yaw: Float) -> Xform {
                Xform(translation: base.translation + base.rotation.act(V3(x, dy, z)), rotation: base.rotation * simd_quatf(degrees: yaw, axis: .up))
            }
            one(PicnicTable(), edge(-28, gladeRadius - 1.2, yawJitter: 10), 60)
            let stack = edge(-52, gladeRadius - 0.6)
            one(Pallet(), stack, 61)
            one(WoodenCrate(), local(stack, -0.3, 0, y: 0.145, yaw: 4), 62)
            one(WoodenCrate(), local(stack, 0.3, 0.03, y: 0.145, yaw: -7), 63)
            one(WoodenCrate().with { $0.size = V3(0.45, 0.35, 0.35) }, local(stack, 0.05, 0, y: 0.59, yaw: 18), 64)
            let barrels = edge(-66, gladeRadius - 0.4)
            one(Barrel(), barrels, 65)
            one(Barrel(), local(barrels, 0.68, 0.2, yaw: 40), 66)
            one(OilDrum().with { $0.color = 0x3B5A2A }, edge(18, gladeRadius - 0.5, yawJitter: 30), 67)
            one(WoodenCrate(), edge(34, gladeRadius - 0.8, yawJitter: 25), 68)
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
