import simd
import Foundation
import RealityKit
import RealKit

/// Open glade ringed by mixed conifer/broadleaf forest: terrain with a worn trail, ~140 instanced spruce,
/// fir, Scots pine, oak, beech and birch (3 LODs), boulders and mossy rocks, deadwood, shrubs, ferns, leaf
/// litter, mushrooms, geometric grass tufts near the camera and card grass farther out.
public struct ForestGlade: RealSceneBuilder {
    public static let id = "forest-glade"
    public static let summary = "Glade ringed by ~140 mixed conifers and broadleaves, worn trail, mossy rocks, deadwood, ferns, litter, grass tufts and edge camp props."
    public static let tags = ["nature", "forest", "camp"]

    public var radius: Float = 45
    public var gladeRadius: Float = 9
    public var trees = 140
    public var grass = 7000
    /// Geometric grass tufts within `tuftRadius` of the camera (cards beyond).
    public var tufts = 4200
    public var tuftRadius: Float = 10
    /// Camp props (picnic table, crates on a pallet, barrels, drum) along the glade's edge.
    public var edgeProps = true
    public init() {}

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        // Trail: enters past the camp at the back left, crosses the glade and leaves to the right.
        let ground = GroundPatch().with {
            $0.size = radius * 2.2; $0.segments = 160; $0.relief = 0.6; $0.flatCenter = gladeRadius * 0.6
            $0.pathWidth = 1.4; $0.pathHeading = 28; $0.wornMaterial = "ground.forest-worn"
        }
        scene.singles.append(.init(asset: ground.build(seed: seed), at: .identity))
        func y(_ p: V2) -> Float { ground.height(x: p.x, z: p.y, seed: seed) }
        func trail(_ p: V2) -> Float { ground.pathWear(x: p.x, z: p.y, seed: seed) }
        let eye2 = V2(0, 6)
        func xf(_ p: V2, _ rng: inout SeededRNG, scale: ClosedRange<Float>, sink: Float = 0.05) -> simd_float4x4 {
            Xform(translation: V3(p.x, y(p) - sink, p.y), rotation: simd_quatf(degrees: rng.float(0...360), axis: .up),
                  scale: V3(repeating: rng.float(scale))).matrix
        }
        var rng = SeededRNG(seed: seed &+ 99)

        // Trees: ring around the glade, denser with distance.
        let spots = Scatter.poisson(count: trees, outerRadius: radius, innerRadius: gladeRadius + 3, minSpacing: 3.6, seed: seed &+ 1) { p in
            let d = simd_length(p); return d > gladeRadius + 6 || Float(abs(Noise.perlin(V3(p.x * 0.2, 0, p.y * 0.2)))) > 0.25
        }
        // Species mix: conifers dominate; each kind has 2-3 seeded variants, each variant one instanced field.
        let kinds: [(weight: Float, variants: Int, build: (UInt64) -> LODModel)] = [
            (0.32, 3, { Tree(.spruce).build(seed: $0) }),
            (0.12, 2, { FirTree().build(seed: $0) }),
            (0.08, 2, { ScotsPine().build(seed: $0) }),
            (0.18, 2, { Tree(.oak).build(seed: $0) }),
            (0.14, 2, { BeechTree().build(seed: $0) }),
            (0.16, 2, { Tree(.birch).build(seed: $0) }),
        ]
        var buckets: [[[simd_float4x4]]] = kinds.map { k in Array(repeating: [], count: k.variants) }
        var broadleaf: [V2] = []
        for p in spots {
            guard trail(p) < 0.3 else { continue }
            let r = rng.float()
            var acc: Float = 0, si = 0
            for (i, k) in kinds.enumerated() { acc += k.weight; if r < acc { si = i; break } }
            buckets[si][rng.int(0...(kinds[si].variants - 1))].append(xf(p, &rng, scale: 0.8...1.2, sink: 0.12))
            if si >= 3 { broadleaf.append(p) }
        }
        var opts = RealInstancing.Options(); opts.cellSize = 18
        for (si, k) in kinds.enumerated() {
            for v in 0..<k.variants where !buckets[si][v].isEmpty {
                scene.fields.append(.init(asset: k.build(seed &+ UInt64(si * 10 + v)), transforms: buckets[si][v], options: opts))
            }
        }

        // Shrubs at the forest edge.
        let shrubSpots = Scatter.poisson(count: 45, outerRadius: radius * 0.9, innerRadius: gladeRadius + 1, minSpacing: 2.2, seed: seed &+ 2)
        scene.fields.append(.init(asset: Shrub().build(seed: seed &+ 3), transforms: shrubSpots.map { xf($0, &rng, scale: 0.7...1.4) }, options: opts))

        // Rocks: bare boulders in the open glade, moss-covered ones under the canopy.
        let rocks = Scatter.poisson(count: 16, outerRadius: radius * 0.8, innerRadius: 4, minSpacing: 5, seed: seed &+ 4) { trail($0) < 0.2 }
        for (i, p) in rocks.enumerated() {
            let at = Xform(translation: V3(p.x, y(p), p.y), rotation: simd_quatf(degrees: rng.float(0...360), axis: .up))
            let k = rng.float(0.6...1.5)
            if simd_length(p) > gladeRadius + 2 {
                scene.singles.append(.init(asset: MossyRock().with { $0.size = V3(1.3, 0.8, 1.1) * k }.build(seed: seed &+ UInt64(40 + i)), at: at))
            } else {
                scene.singles.append(.init(asset: Boulder().with { $0.size = V3(1.4, 0.9, 1.2) * k }.build(seed: seed &+ UInt64(40 + i)), at: at))
            }
        }

        // Deadwood under the trees: fallen trunks, stumps and a standing snag; mushrooms beside them.
        var deadwood: [V2] = []
        let logSpots = Scatter.poisson(count: 9, outerRadius: radius * 0.75, innerRadius: gladeRadius + 2.5, minSpacing: 7, seed: seed &+ 8) { trail($0) < 0.1 }
        for (i, p) in logSpots.enumerated() {
            let at = Xform(translation: V3(p.x, y(p), p.y), rotation: simd_quatf(degrees: rng.float(0...360), axis: .up))
            switch i % 4 {
            case 0, 2: scene.singles.append(.init(asset: FallenLog().with { $0.length = rng.float(3...5.5) }.build(seed: seed &+ UInt64(70 + i)), at: at))
            case 1: scene.singles.append(.init(asset: RootStump().build(seed: seed &+ UInt64(70 + i)), at: at))
            default: scene.singles.append(.init(asset: i < 4 ? LogStump().build(seed: seed &+ UInt64(70 + i)) : DeadSnag().build(seed: seed &+ UInt64(70 + i)), at: at))
            }
            deadwood.append(p)
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

        // Grass: dense in the glade, thinning under the canopy, off the trail. Geometric tufts near the
        // camera over a thinner layer of card clumps, card clumps alone beyond.
        let gopts = RealInstancing.Options.groundCover(cull: 30)
        func meadow(_ p: V2) -> Bool {
            let d = simd_length(p)
            let density = d < gladeRadius ? 1 : max(0.15, 1 - (d - gladeRadius) / 18)
            return Float(Noise.perlin(V3(p.x * 0.35, 1, p.y * 0.35))) * 0.5 + 0.5 < density * (1 - trail(p))
        }
        func near(_ p: V2) -> Float { 1 - smoothstep(tuftRadius - 2, tuftRadius, simd_distance(p, eye2)) }
        let blades = Scatter.uniform(count: grass, outerRadius: radius * 0.7, seed: seed &+ 5) { p in
            meadow(p) && Float(abs(Noise.perlin(V3(p.x * 3.1, 2, p.y * 3.1)))) * 2 >= near(p) * 0.55
        }
        let half = blades.count / 2
        scene.fields.append(.init(asset: GrassClump().build(seed: seed &+ 6), transforms: blades[..<half].map { xf($0, &rng, scale: 0.7...1.3, sink: 0.02) }, options: gopts))
        scene.fields.append(.init(asset: GrassClump().with { $0.height = 0.3; $0.width = 0.4 }.build(seed: seed &+ 7),
                                  transforms: blades[half...].map { xf($0, &rng, scale: 0.7...1.3, sink: 0.02) }, options: gopts))
        let tuftSpots = Scatter.uniform(count: tufts, outerRadius: tuftRadius, seed: seed &+ 9) { q in
            let p = q + eye2
            return meadow(p) && Float(abs(Noise.perlin(V3(p.x * 3.1, 2, p.y * 3.1)))) * 2 < near(p)
        }.map { $0 + eye2 }
        let tuftXf = tuftSpots.map { xf($0, &rng, scale: 0.7...1.4, sink: 0.01) }
        scene.fields.append(.init(asset: GrassTuft().build(seed: seed &+ 10), transforms: tuftXf.enumerated().filter { $0.offset % 2 == 0 }.map(\.element), options: gopts))
        scene.fields.append(.init(asset: GrassTuft().with { $0.height = 0.34 }.build(seed: seed &+ 11), transforms: tuftXf.enumerated().filter { $0.offset % 2 == 1 }.map(\.element), options: gopts))

        // Wildflowers and tall grass in the glade, ferns and moss under the trees.
        let flowers = Scatter.uniform(count: 220, outerRadius: gladeRadius + 1, seed: seed &+ 12) { p in
            meadow(p) && trail(p) < 0.1 && Noise.perlin(V3(p.x * 0.4, 6, p.y * 0.4)) > 0.12
        }
        scene.fields.append(.init(asset: MeadowFlowers().build(seed: seed &+ 13), transforms: flowers.map { xf($0, &rng, scale: 0.8...1.2, sink: 0.01) }, options: gopts))
        let tall = Scatter.uniform(count: 260, outerRadius: gladeRadius + 5, innerRadius: gladeRadius - 1.5, seed: seed &+ 14) { trail($0) < 0.1 }
        scene.fields.append(.init(asset: TallGrass().build(seed: seed &+ 15), transforms: tall.map { xf($0, &rng, scale: 0.8...1.2, sink: 0.01) }, options: gopts))
        let ferns = Scatter.poisson(count: 320, outerRadius: radius * 0.7, innerRadius: gladeRadius + 1.5, minSpacing: 0.9, seed: seed &+ 16) { p in
            trail(p) < 0.1 && Noise.perlin(V3(p.x * 0.12, 4, p.y * 0.12)) > -0.1
        }
        let fernXf = ferns.map { xf($0, &rng, scale: 0.7...1.25, sink: 0.02) }
        scene.fields.append(.init(asset: Fern().build(seed: seed &+ 17), transforms: fernXf.enumerated().filter { $0.offset % 3 != 2 }.map(\.element), options: gopts))
        scene.fields.append(.init(asset: Fern().with { $0.bracken = true }.build(seed: seed &+ 18), transforms: fernXf.enumerated().filter { $0.offset % 3 == 2 }.map(\.element), options: gopts))
        let moss = Scatter.poisson(count: 60, outerRadius: radius * 0.7, innerRadius: gladeRadius + 2, minSpacing: 1.5, seed: seed &+ 19) { trail($0) < 0.1 }
        scene.fields.append(.init(asset: MossMound().build(seed: seed &+ 20), transforms: moss.map { xf($0, &rng, scale: 0.7...1.6, sink: 0.01) }, options: gopts))

        // Leaf litter under broadleaf crowns (and spilling onto the trail edge), mushrooms by the deadwood.
        var litter: [simd_float4x4] = []
        for (i, p) in broadleaf.enumerated() where i % 2 == 0 {
            for _ in 0..<3 {
                let q = p + V2(rng.float(-3...3), rng.float(-3...3))
                if simd_length(q) > gladeRadius - 1 { litter.append(xf(q, &rng, scale: 0.9...1.6, sink: 0.0)) }
            }
        }
        scene.fields.append(.init(asset: LeafLitter().build(seed: seed &+ 21), transforms: litter, options: gopts))
        var shrooms: [simd_float4x4] = []
        for p in deadwood {
            for _ in 0..<rng.int(2...4) {
                let a = rng.float(0...6.28), r = rng.float(0.5...1.6)
                shrooms.append(xf(p + V2(cos(a), sin(a)) * r, &rng, scale: 0.8...1.3, sink: 0.005))
            }
        }
        scene.fields.append(.init(asset: MushroomCluster().build(seed: seed &+ 22), transforms: shrooms, options: .groundCover(cull: 20)))

        let eyeY = y(V2(0, 6)) + 1.6
        scene.camera = .init(eye: V3(0, eyeY, 6), target: V3(-6, eyeY + 1.2, -14), fov: 60)
        return scene
    }
}
