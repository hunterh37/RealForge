import simd
import Foundation
import RealityKit
import RealKit

/// Autumn broadleaf wood, 72 m terrain: red Norway maple, golden aspen, beech and oak over a floor of
/// fallen leaves, with a trodden dirt path winding away from the viewer between a dead snag, fallen
/// logs, an old root stump, mossy rocks, ferns and mushroom clusters.
public struct AutumnWoods: RealSceneBuilder {
    public static let id = "autumn-woods"
    public static let summary = "Autumn wood of red maple, gold aspen, beech and oak over leaf litter, a dirt path winding past logs, a snag and mossy rocks."
    public static let tags = ["nature", "forest", "showcase"]
    public static let author = "realityhd"

    /// Terrain side length in meters.
    public var size: Float = 72
    /// Forest radius in meters.
    public var radius: Float = 33
    public var trees = 132
    /// Path tread width in meters.
    public var pathWidth: Float = 1.2
    public init() {}

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 99)
        let ns = UInt32(truncatingIfNeeded: seed)
        let base = GroundPatch().with { $0.size = size; $0.relief = 1.4; $0.featureSize = 11; $0.flatCenter = 2 }

        // Path centerline: wanders in x as it runs from the viewer (+z) into the wood (-z).
        func pathX(_ z: Float) -> Float { 2.2 * sin(z * 0.13 + 0.6) + 0.7 * sin(z * 0.37 + 2) }
        func pathD(_ p: V2) -> Float { abs(p.x - pathX(p.y)) * cos(atan(2.2 * 0.13 * cos(p.y * 0.13 + 0.6))) }
        func height(_ p: V2) -> Float {
            // Soften relief along the path so it reads as a worn tread.
            let h = base.height(x: p.x, z: p.y, seed: seed)
            let tread = 1 - smoothstep(pathWidth * 0.5, pathWidth * 2.2, pathD(p))
            // The wood climbs gently toward the edge so the horizon sits behind trunks.
            let rim = smoothstep(16, radius + 4, simd_length(p)) * 3.5
            return h + rim - tread * 0.04
        }
        func y(_ p: V2) -> Float { height(p) }
        func wear(_ p: V2) -> Float {
            let n = Noise.fbm(V3(p.x * 2.0, 1, p.y * 2.0), octaves: 3, seed: ns &+ 3) * 0.3
            return 1 - smoothstep(pathWidth * 0.45, pathWidth * 0.95, pathD(p) + n)
        }

        var terrain = Prim.terrain(size: V2(size, size), segments: 220, material: "ground.litter-path") { p in
            height(p) - smoothstep(size * 0.42, size * 0.5, max(abs(p.x), abs(p.y))) * 0.05
        }
        GroundMesh.shadeHollows(&terrain, gridSide: 221, radius: 6, relief: 1.4, strength: 0.6)
        terrain.paintSplat { wear(V2($0.x, $0.z)) }
        scene.add(Model(name: "autumn-ground", surfaces: [terrain]))

        func xf(_ p: V2, scale: ClosedRange<Float>, sink: Float) -> simd_float4x4 {
            Xform(translation: V3(p.x, y(p) - sink, p.y), rotation: simd_quatf(degrees: rng.float(0...360), axis: .up),
                  scale: V3(repeating: rng.float(scale))).matrix
        }
        func at(_ p: V2, yaw: Float, sink: Float = 0.02) -> Xform { place(p.x, p.y, y: y(p) - sink, yaw: yaw) }

        // Trees, 3 builds per species, kept off the path.
        let spots = Scatter.poisson(count: trees, outerRadius: radius, innerRadius: 0, minSpacing: 3.6, seed: seed &+ 1) { p in
            pathD(p) > pathWidth + 1.4 && simd_length(p - V2(0.5, 9)) > 3
        }
        var buckets: [[[simd_float4x4]]] = Array(repeating: [[], [], []], count: 4)
        var trunks: [V2] = []
        for p in spots {
            let r = rng.float()
            let s = r < 0.42 ? 0 : r < 0.72 ? 1 : r < 0.86 ? 2 : 3
            buckets[s][rng.int(0...2)].append(xf(p, scale: 0.8...1.15, sink: 0.1))
            trunks.append(p)
        }
        for v in 0..<3 {
            let k = UInt64(v)
            scene.field(MapleTree().with { $0.autumn = [1, 0.8, 0.95][v]; $0.leafDensity = 0.85 }, seed: seed &+ 10 &+ k, transforms: buckets[0][v], options: .trees)
            scene.field(AspenTree().with { $0.autumn = 1 }, seed: seed &+ 13 &+ k, transforms: buckets[1][v], options: .trees)
            scene.field(BeechTree().with { $0.height = 16 }, seed: seed &+ 16 &+ k, transforms: buckets[2][v], options: .trees)
            scene.field(OakTree(), seed: seed &+ 19 &+ k, transforms: buckets[3][v], options: .trees)
        }

        // Path-side features along the walk.
        func side(_ z: Float, _ off: Float) -> V2 { V2(pathX(z) + off, z) }
        scene.add(DeadSnag(), at: at(side(-6, -3.4), yaw: 40, sink: 0.08), seed: seed &+ 30)
        scene.add(DeadSnag().with { $0.height = 7 }, at: at(side(-21, 4.2), yaw: 160, sink: 0.08), seed: seed &+ 31)
        let logP = side(1.0, -3.6)
        scene.add(FallenLog().with { $0.length = 4.2; $0.buttDiameter = 0.48 }, at: at(logP, yaw: 70), seed: seed &+ 32)
        scene.add(FallenLog(), at: at(side(-13, -3.2), yaw: -20), seed: seed &+ 33)
        scene.add(FallenLog().with { $0.length = 2.6; $0.buttDiameter = 0.3; $0.topDiameter = 0.18 }, at: at(V2(-9, 4), yaw: 130), seed: seed &+ 34)
        let rootP = side(5.2, -2.4)
        scene.add(RootStump(), at: at(rootP, yaw: 15, sink: 0.03), seed: seed &+ 35)
        scene.add(LogStump(), at: at(side(-9, 2.6), yaw: 0, sink: 0.03), seed: seed &+ 36)
        let rocks: [(V2, Float)] = [(side(0.5, 2.3), 0.9), (side(-17, -2.8), 1.3), (V2(8, -4), 0.8), (V2(-10, -12), 1.1)]
        for (i, (p, s)) in rocks.enumerated() {
            scene.add(MossyRock().with { $0.size = V3(1.3, 0.8, 1.1) * s }, at: at(p, yaw: rng.float(0...360), sink: 0.06 * s), seed: seed &+ UInt64(40 + i))
        }

        // Leaf litter: heavy everywhere off the tread, lighter on its edges.
        let cover = RealInstancing.Options.groundCover(cull: 30)
        let litter = Scatter.uniform(count: 2600, outerRadius: radius * 0.85, seed: seed &+ 50) { p in
            let w = wear(p); return w < 0.3 || (w < 0.8 && Noise.perlin(V3(p.x * 2, 0, p.y * 2), seed: ns) > 0.2)
        }
        let lh = litter.count / 2
        scene.field(LeafLitter(), seed: seed &+ 51, transforms: litter[..<lh].map { xf($0, scale: 0.8...1.5, sink: 0.0) }, options: cover)
        scene.field(LeafLitter().with { $0.radius = 0.6 }, seed: seed &+ 52, transforms: litter[lh...].map { xf($0, scale: 0.8...1.4, sink: 0.0) }, options: cover)

        // Ferns in patches, bracken turned brown in the open.
        let ferns = Scatter.uniform(count: 1100, outerRadius: radius * 0.85, seed: seed &+ 53) { p in
            wear(p) < 0.05 && pathD(p) > pathWidth && Noise.perlin(V3(p.x * 0.18, 5, p.y * 0.18), seed: ns &+ 1) > 0.05
        }
        let fh = ferns.count * 3 / 5
        scene.field(Fern(), seed: seed &+ 54, transforms: ferns[..<fh].map { xf($0, scale: 0.7...1.15, sink: 0.02) }, options: cover)
        scene.field(Fern().with { $0.bracken = true }, seed: seed &+ 55, transforms: ferns[fh...].map { xf($0, scale: 0.8...1.2, sink: 0.02) }, options: cover)

        // Sparse dry grass on the path verge.
        let verge = Scatter.uniform(count: 900, outerRadius: radius * 0.7, seed: seed &+ 56) { p in
            let d = pathD(p); return d > pathWidth * 0.6 && d < pathWidth * 1.6
        }
        scene.field(DryGrass().with { $0.height = 0.35 }, seed: seed &+ 57, transforms: verge.map { xf($0, scale: 0.7...1.1, sink: 0.02) }, options: cover)

        // Mushrooms at tree feet, logs and stumps.
        var shrooms: [simd_float4x4] = []
        for c in trunks where rng.float() < 0.35 && simd_length(c) < 20 {
            let a = rng.float(0...6.28), p = c + V2(cos(a), sin(a)) * rng.float(0.45...0.9)
            shrooms.append(xf(p, scale: 0.8...1.3, sink: 0))
        }
        for p in [logP + V2(0.5, 0.6), logP + V2(-0.8, -0.5), rootP + V2(0.6, 0.3), side(-13, -2.4), side(-9, 2.0)] {
            shrooms.append(xf(p, scale: 1.0...1.3, sink: 0))
        }
        scene.field(MushroomCluster(), seed: seed &+ 58, transforms: shrooms, options: cover)
        scene.field(MushroomCluster().with { $0.capRadius = 0.045; $0.count = 2...4 }, seed: seed &+ 59,
                    transforms: shrooms.indices.filter { $0 % 3 == 0 }.map { _ in
                        let c = trunks[rng.int(0...(trunks.count - 1))]
                        return xf(c + V2(rng.float(-1...1), rng.float(-1...1)), scale: 0.9...1.2, sink: 0)
                    }, options: cover)

        scene.farGround = "ground.leaf-litter"
        let eye = V2(pathX(10), 10)
        let eyeY = y(eye) + 1.65
        let look = V2(pathX(-6), -6)
        scene.camera = .init(eye: V3(eye.x, eyeY, eye.y), target: V3(look.x, y(look) + 1.2, look.y), fov: 60)
        return scene
    }
}
