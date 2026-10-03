import simd
import Foundation
import RealityKit
import RealKit

/// City-park walkway: meadow ground, asphalt path with concrete curbs, benches, lamps, bins, hydrant,
/// bollards, and shade trees with grass.
public struct ParkPath: RealSceneBuilder {
    public static let id = "park-path"
    public static let summary = "City-park walkway: asphalt path with curbs, benches, lamps, bins, hydrant, shade trees and 22k grass clumps."
    public static let tags = ["urban", "park", "street"]

    public var length: Float = 60
    public init() {}
    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed)
        let ground = GroundPatch().with { $0.size = 90; $0.segments = 128; $0.relief = 0.25; $0.flatCenter = 10; $0.material = "ground.meadow" }
        scene.singles.append(.init(asset: ground.build(seed: seed), at: .identity))
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
        var oaks: [simd_float4x4] = [], birches: [simd_float4x4] = []
        for p in treeSpots {
            let m = Xform(translation: V3(p.x, y(p) - 0.1, p.y), rotation: simd_quatf(degrees: rng.float(0...360), axis: .up), scale: V3(repeating: rng.float(0.85...1.15))).matrix
            if rng.chance(0.6) { oaks.append(m) } else { birches.append(m) }
        }
        scene.fields.append(.init(asset: OakTree().build(seed: seed &+ 4), transforms: oaks, options: opts))
        scene.fields.append(.init(asset: BirchTree().build(seed: seed &+ 5), transforms: birches, options: opts))
        var gopts = RealInstancing.Options(); gopts.cellSize = 8; gopts.cullDistance = 28; gopts.shadowCasterMaxLOD = -1
        let blades = Scatter.uniform(count: 22000, outerRadius: 30, seed: seed &+ 6) { abs($0.y) > 1.75 }
        scene.fields.append(.init(asset: GrassClump().with { $0.height = 0.22; $0.width = 0.35 }.build(seed: seed &+ 7),
                                  transforms: blades.map { Xform(translation: V3($0.x, y($0) - 0.02, $0.y), rotation: simd_quatf(degrees: rng.float(0...360), axis: .up),
                                                                  scale: V3(repeating: rng.float(0.7...1.3))).matrix }, options: gopts))
        scene.camera = .init(eye: V3(-7, 1.65, 0.4), target: V3(6, 1.0, -1.2), fov: 60)
        return scene
    }
}
