import simd
import Foundation
import RealityKit
import RealKit

/// City-park walkway: meadow ground worn bare along the curbs and on a shortcut to the picnic table,
/// asphalt path with concrete curbs, benches, lamps, bins, hydrant, bollards, oak, maple and birch shade
/// trees, geometric grass tufts near the camera, card grass farther out, clover, dandelions and leaf litter.
public struct ParkPath: RealSceneBuilder {
    public static let id = "park-path"
    public static let summary = "City-park walkway: asphalt path with curbs, worn verges, benches, lamps, bins, hydrant, oak, maple and birch, grass tufts, clover and dandelions."
    public static let tags = ["urban", "park", "street"]

    public var length: Float = 60
    public init() {}
    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed)
        let ground = GroundPatch().with { $0.size = 90; $0.segments = 128; $0.relief = 0.25; $0.flatCenter = 10; $0.material = "ground.meadow-worn" }
        // Worn ground (splat): trampled verges along both curbs and a shortcut from the path to the picnic table.
        func wear(_ p: V2) -> Float {
            let ragged = Noise.fbm(V3(p.x * 1.7, 3, p.y * 1.7), octaves: 3, seed: 5) * 0.25
            let verge = (1 - smoothstep(0.15, 0.6, abs(p.y) - 1.66 + ragged)) * (0.75 + 0.25 * Float(Noise.perlin(V3(p.x * 0.2, 1, 0))))
            let a = V2(3.5, 1.7), b = V2(7.2, 6.2), ab = b - a
            let t = saturate(simd_dot(p - a, ab) / simd_dot(ab, ab))
            let shortcut = (1 - smoothstep(0.2, 0.55, simd_distance(p, a + ab * t) + ragged)) * smoothstep(0, 0.1, t)
            return min(1, max(verge, shortcut, 1 - smoothstep(0.9, 1.6, simd_distance(p, V2(8, 7)) + ragged)))
        }
        var groundModel = ground.build(seed: seed)
        for i in groundModel.levels[0].surfaces.indices { groundModel.levels[0].surfaces[i].paintSplat { wear(V2($0.x, $0.z)) } }
        scene.singles.append(.init(asset: groundModel, at: .identity))
        // Path: asphalt strip + curbs, slightly raised over the flat center.
        var path = Model(name: "path")
        path.add(Prim.terrain(size: V2(length, 3), segments: 24, material: "asphalt") { _ in 0.03 })
        for z: Float in [-1.58, 1.58] {
            path.add(Prim.roundedBox(V3(length, 0.14, 0.16), radius: 0.015, bevelSegments: 2, material: "concrete.smooth"), Xform(translation: V3(0, 0.05, z)))
        }
        scene.singles.append(.init(asset: LODModel(path), at: .identity))

        func one<A: RealAsset>(_ a: A, _ x: Float, _ z: Float, yaw: Float, s: UInt64) {
            scene.singles.append(.init(asset: a.build(seed: seed &+ s), at: place(x, z, yaw: yaw)))
        }
        for (i, x) in stride(from: -24, through: 24, by: 12).enumerated() {
            let xf = Float(x)
            one(StreetLamp(), xf, -2.2, yaw: 0, s: UInt64(10 + i))
            one(ParkBench(), xf + 4, -2.5, yaw: 0, s: UInt64(20 + i))
            if i % 2 == 0 { one(TrashCan(), xf + 6.2, -2.3, yaw: rng.float(0...360), s: UInt64(30 + i)) }
            one(Bollard(), xf - 1, 1.9, yaw: 0, s: 40)
        }
        one(FireHydrant(), 3, 2.3, yaw: 200, s: 50)
        one(Mailbox(), -9, 2.4, yaw: 180, s: 51)
        one(TrafficCone(), -3.5, 0.9, yaw: 20, s: 52)
        one(TrafficCone(), -2.4, 1.1, yaw: 70, s: 53)
        one(PicnicTable(), 8, 7, yaw: 15, s: 54)

        var opts = RealInstancing.Options(); opts.cellSize = 18
        func y(_ p: V2) -> Float { ground.height(x: p.x, z: p.y, seed: seed) }
        let treeSpots = Scatter.poisson(count: 40, outerRadius: 40, innerRadius: 6, minSpacing: 7, seed: seed &+ 3) { abs($0.y) > 5 }
        var oaks: [simd_float4x4] = [], birches: [simd_float4x4] = [], maples: [simd_float4x4] = []
        for p in treeSpots {
            let m = Xform(translation: V3(p.x, y(p) - 0.1, p.y), rotation: simd_quatf(degrees: rng.float(0...360), axis: .up), scale: V3(repeating: rng.float(0.85...1.15))).matrix
            let r = rng.float()
            if r < 0.4 { oaks.append(m) } else if r < 0.7 { maples.append(m) } else { birches.append(m) }
        }
        scene.fields.append(.init(asset: OakTree().build(seed: seed &+ 4), transforms: oaks, options: opts))
        scene.fields.append(.init(asset: BirchTree().build(seed: seed &+ 5), transforms: birches, options: opts))
        scene.fields.append(.init(asset: MapleTree().build(seed: seed &+ 8), transforms: maples, options: opts))

        // Grass: geometric tufts within ~10 m of the camera over thinner card clumps, cards alone beyond.
        // Nothing grows on the path or where the ground is worn.
        let gopts = RealInstancing.Options.groundCover(cull: 28)
        func xz(_ p: V2, _ scale: ClosedRange<Float>, sink: Float = 0.02) -> simd_float4x4 {
            Xform(translation: V3(p.x, y(p) - sink, p.y), rotation: simd_quatf(degrees: rng.float(0...360), axis: .up), scale: V3(repeating: rng.float(scale))).matrix
        }
        let eye2 = V2(-7, 0.4)
        func near(_ p: V2) -> Float { 1 - smoothstep(8, 10, simd_distance(p, eye2)) }
        func open(_ p: V2) -> Bool { abs(p.y) > 1.75 && wear(p) < 0.35 + 0.3 * Float(abs(Noise.perlin(V3(p.x * 4, 0, p.y * 4)))) }
        let blades = Scatter.uniform(count: 22000, outerRadius: 30, seed: seed &+ 6) { p in
            open(p) && Float(abs(Noise.perlin(V3(p.x * 3.1, 2, p.y * 3.1)))) * 2 >= near(p) * 0.6
        }
        scene.fields.append(.init(asset: GrassClump().with { $0.height = 0.22; $0.width = 0.35 }.build(seed: seed &+ 7),
                                  transforms: blades.map { xz($0, 0.7...1.3) }, options: gopts))
        let tufts = Scatter.uniform(count: 5200, outerRadius: 10, seed: seed &+ 9) { q in
            let p = q + eye2
            return open(p) && Float(abs(Noise.perlin(V3(p.x * 3.1, 2, p.y * 3.1)))) * 2 < near(p) * 0.6 + 0.4
        }.map { $0 + eye2 }
        let tuftXf = tufts.map { xz($0, 0.7...1.2, sink: 0.01) }
        scene.fields.append(.init(asset: GrassTuft().with { $0.height = 0.16 }.build(seed: seed &+ 10), transforms: tuftXf.enumerated().filter { $0.offset % 2 == 0 }.map(\.element), options: gopts))
        scene.fields.append(.init(asset: GrassTuft().with { $0.height = 0.2 }.build(seed: seed &+ 11), transforms: tuftXf.enumerated().filter { $0.offset % 2 == 1 }.map(\.element), options: gopts))

        // Lawn weeds in patches, leaf litter collecting under the trees.
        let clover = Scatter.uniform(count: 260, outerRadius: 24, seed: seed &+ 12) { p in open(p) && Noise.perlin(V3(p.x * 0.3, 7, p.y * 0.3)) > 0.15 }
        scene.fields.append(.init(asset: CloverPatch().build(seed: seed &+ 13), transforms: clover.map { xz($0, 0.8...1.5, sink: 0.005) }, options: gopts))
        let dandelions = Scatter.uniform(count: 160, outerRadius: 24, seed: seed &+ 14) { open($0) }
        scene.fields.append(.init(asset: Dandelion().build(seed: seed &+ 15), transforms: dandelions.map { xz($0, 0.8...1.2, sink: 0.005) }, options: gopts))
        var litter: [simd_float4x4] = []
        for p in treeSpots where simd_length(p) < 28 {
            for _ in 0..<2 {
                let q = p + V2(rng.float(-2.5...2.5), rng.float(-2.5...2.5))
                if abs(q.y) > 1.8 { litter.append(xz(q, 1.0...1.8, sink: 0)) }
            }
        }
        scene.fields.append(.init(asset: LeafLitter().build(seed: seed &+ 16), transforms: litter, options: gopts))
        scene.camera = .init(eye: V3(-7, 1.65, 0.4), target: V3(6, 1.0, -1.2), fov: 60)
        return scene
    }
}
