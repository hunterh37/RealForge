import simd
import Foundation
import RealityKit
import RealKit

/// Snowy clearing about 20 m across inside a ring of snow-laden Norway spruce and balsam fir, 90 m of
/// snow ground with wind drifts, snow-capped granite boulders, a fallen trunk with snow on its bark,
/// a firewood rick and a chopping block, dead grass poking through. The camera stands in the clearing.
public struct WinterForest: RealSceneBuilder {
    public static let id = "winter-forest"
    public static let summary = "Snowy clearing ringed by snow-laden spruce and fir: drifts, snow-capped boulders, fallen log, firewood rick, chopping block."
    public static let tags = ["snow", "forest", "outdoor", "nature"]
    public static let author = "hunter"

    public var size: Float = 100
    public var clearing: Float = 11
    public var trees = 170
    public init() {}

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        scene.farGround = "ground.snow"
        var rng = SeededRNG(seed: seed &+ 99)
        let ns = UInt32(truncatingIfNeeded: seed)
        let ground = GroundPatch().with { $0.size = size; $0.segments = 200; $0.relief = 0.7; $0.featureSize = 11; $0.flatCenter = clearing * 0.5; $0.material = "ground.snow" }
        scene.add(ground, seed: seed)
        func y(_ p: V2) -> Float { ground.height(x: p.x, z: p.y, seed: seed) }

        // Forest ring: snowy spruce with balsam fir, denser with distance from the clearing.
        let spots = Scatter.poisson(count: trees, outerRadius: size * 0.47, innerRadius: clearing, minSpacing: 3.3, seed: seed &+ 1) { p in
            let d = simd_length(p)
            return d > clearing + 5 || Float(Noise.perlin(V3(p.x * 0.25, 0, p.y * 0.25), seed: ns)) > 0.15
        }
        var spruce = [[simd_float4x4]](repeating: [], count: 3), fir = [[simd_float4x4]](repeating: [], count: 3)
        for p in spots {
            let m = SceneStrips.xform(p, y: y(p) - 0.15, &rng, scale: 0.7...1.2)
            if rng.chance(0.72) { spruce[rng.int(0...2)].append(m) } else { fir[rng.int(0...2)].append(m) }
        }
        for v in 0..<3 {
            scene.field(SnowySpruce(), seed: seed &+ UInt64(10 + v), transforms: spruce[v], options: .trees)
            scene.field(FirTree(), seed: seed &+ UInt64(13 + v), transforms: fir[v], options: .trees)
        }
        // Young spruce at the clearing edge.
        let young = Scatter.poisson(count: 14, outerRadius: clearing + 4, innerRadius: clearing - 2, minSpacing: 2.5, seed: seed &+ 2)
        scene.field(SnowySpruce(), seed: seed &+ 16, transforms: young.map { SceneStrips.xform($0, y: y($0) - 0.1, &rng, scale: 0.18...0.35) }, options: .trees)
        scene.add(DeadSnag(), at: place(-14, -9, y: y(V2(-14, -9)) - 0.1, yaw: 40), seed: seed &+ 3)

        // Drifts banked against the trees, lee faces downwind (+X).
        let drifts = Scatter.poisson(count: 12, outerRadius: 30, innerRadius: 4, minSpacing: 7, seed: seed &+ 4)
        for (i, p) in drifts.enumerated() {
            let d = SnowDrift().with { $0.extent = V2(rng.float(2.5...4.5), rng.float(1.2...2.2)); $0.peak = rng.float(0.3...0.7) }
            scene.add(d, at: place(p.x, p.y, y: y(p) - 0.05, yaw: rng.float(-25...25)), seed: seed &+ UInt64(20 + i))
        }

        // Snow-capped boulders, sunk deep.
        let rocks = Scatter.poisson(count: 10, outerRadius: 28, innerRadius: 5, minSpacing: 5, seed: seed &+ 5) { p in
            !drifts.contains { simd_length($0 - p) < 3 }
        }
        for (i, p) in rocks.enumerated() {
            let b = Boulder().with { $0.size = V3(1.5, 0.9, 1.2) * rng.float(0.5...1.5); $0.material = "rock.granite-snow" }
            scene.add(b, at: place(p.x, p.y, y: y(p) - 0.12, yaw: rng.float(0...360)), seed: seed &+ UInt64(40 + i))
        }

        // Fallen trunk across the clearing edge, snow lying on the bark.
        let logAt = V2(4, -3.5)
        scene.add(FallenLog().with { $0.length = 5.5; $0.buttDiameter = 0.5; $0.topDiameter = 0.3; $0.bark = "bark.pine-snow"; $0.sink = 0.08 },
                  at: place(logAt.x, logAt.y, y: y(logAt), yaw: 28), seed: seed &+ 50)

        // Woodpile corner: firewood rick, chopping block, a few split pieces in the snow.
        let pile = V2(-3.2, -0.5)
        scene.add(FirewoodStack(), at: place(pile.x, pile.y, y: y(pile) - 0.04, yaw: 15), seed: seed &+ 51)
        let block = pile + V2(1.6, 1.1)
        scene.add(AxeInStump(), at: place(block.x, block.y, y: y(block) - 0.06, yaw: -30), seed: seed &+ 52)
        for k in 0..<3 {
            let q = block + V2(rng.float(-0.9...0.9), rng.float(0.3...1.0))
            scene.add(Firewood(), at: place(q.x, q.y, y: y(q) - 0.02, yaw: rng.float(0...360)), seed: seed &+ UInt64(53 + k))
        }

        // Dead grass through the snow, sparse and in patches.
        let tufts = Scatter.uniform(count: 1400, outerRadius: 26, seed: seed &+ 6) { p in
            Noise.fbm(V3(p.x * 0.2, 0, p.y * 0.2), octaves: 3, seed: ns &+ 9) > 0.08 && !rocks.contains { simd_length($0 - p) < 1.2 }
        }
        scene.field(DryGrass().with { $0.height = 0.32 }, seed: seed &+ 7, transforms: tufts.map { SceneStrips.xform($0, y: y($0) - 0.08, &rng, scale: 0.6...1.2) },
                    options: .groundCover(cull: 35))

        let eye = V2(0.5, 7)
        let eyeY = y(eye) + 1.65
        scene.camera = .init(eye: V3(eye.x, eyeY, eye.y), target: V3(-1, eyeY + 0.3, -14), fov: 60)
        return scene
    }
}
