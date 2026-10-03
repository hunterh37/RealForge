import simd
import Foundation
import RealityKit
import RealKit

/// Alpine meadow, 90 m ground rising toward a 30 m limestone cliff band with scree at its foot, larch,
/// fir and Scots pine stands, a pebble stream with clear water, mossy boulders, wildflowers and grass;
/// hills up to ~60 m behind. The camera stands in the meadow looking up the stream toward the cliff.
public struct AlpineMeadow: RealSceneBuilder {
    public static let id = "alpine-meadow"
    public static let summary = "Alpine meadow below a limestone cliff band: scree, larch, fir and pine stands, pebble stream, mossy boulders, flowers."
    public static let tags = ["nature", "outdoor", "water", "rock"]
    public static let author = "hunter"

    public var size: Float = 120
    /// Meters the meadow rises from the camera to the cliff foot.
    public var rise: Float = 3
    public var cliffZ: Float = -28
    public var cliffHeight: Float = 8
    public var grass = 7000
    public init() {}

    /// Stream centerline x at z.
    func streamX(_ z: Float) -> Float { 5 + 2.6 * sin(z * 0.085 + 0.5) + 0.8 * sin(z * 0.23 + 2) }

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 99)
        let ns = UInt32(truncatingIfNeeded: seed)
        let patch = GroundPatch().with { $0.relief = 0.7; $0.featureSize = 14; $0.flatCenter = 0 }
        let half = size / 2

        // Base height without the stream channel: rolling relief plus a rise toward the cliff, both fading
        // at the edges so the patch meets the far ground.
        // The cliff band follows an arc of radius `arcR`; `cliffLine(x)` is its center line.
        let arcR: Float = 45, bandHalf: Float = 21
        func cliffLine(_ x: Float) -> Float { cliffZ + arcR - sqrt(max(0, arcR * arcR - x * x)) }
        func meadow(_ x: Float, _ z: Float) -> Float {
            patch.height(x: x, z: z, seed: seed) + rise * (1 - smoothstep(cliffZ, 12, z))
        }
        func base(_ x: Float, _ z: Float) -> Float {
            let edge = 1 - smoothstep(half * 0.72, half * 0.98, max(abs(x), abs(z)))
            // Bench behind the cliff at the height of its top, tapering past the ends of the band.
            let behind = smoothstep(-0.7, 0.5, cliffLine(x) - z) * (1 - smoothstep(bandHalf - 1, bandHalf + 7, abs(x)))
            let bench = behind * (cliffHeight + 0.1 + meadow(x, cliffLine(x)) - meadow(x, z))
            return (meadow(x, z) + bench) * edge - 0.22 * (1 - edge)
        }
        func streamDist(_ x: Float, _ z: Float) -> Float {
            abs(x - streamX(z)) + Noise.fbm(V3(x * 0.9, 2, z * 0.9), octaves: 3, seed: ns &+ 7) * 0.25
        }
        let streamTop: Float = cliffZ + 3.5
        // Channel depth fades in below the scree so the stream springs from the foot of the cliff.
        func channel(_ x: Float, _ z: Float) -> Float {
            let start = smoothstep(streamTop, streamTop + 3, z)
            return -0.42 * (1 - smoothstep(0.7, 2.1, streamDist(x, z))) * start
        }
        func y(_ x: Float, _ z: Float) -> Float { base(x, z) + channel(x, z) }
        func y(_ p: V2) -> Float { y(p.x, p.y) }

        var ground = SceneStrips.ground(size: size, segments: 240, material: "ground.alpine", relief: 0.8) { y($0.x, $0.y) }
        ground.paintSplat { p in
            let start = smoothstep(streamTop - 1, streamTop + 1.5, p.z)
            return (1 - smoothstep(0.9, 1.7, streamDist(p.x, p.z))) * start
        }
        scene.add(Model(name: "meadow-ground", surfaces: [ground]))

        // Water: a strip down the channel, level 0.22 m below the banks; splat is 1 at the waterline.
        func water(_ z: Float) -> Float { base(streamX(z), z) - 0.24 }
        var stream = SceneStrips.ribbon(material: "water.stream", z0: streamTop + 1.2, z1: half - 2, width: 3.2, along: 160, across: 8,
                                        cx: streamX) { _, z in water(z) }
        stream.paintSplat { p in 1 - smoothstep(0, 0.16, water(p.z) - y(p.x, p.z)) }
        scene.add(Model(name: "stream", surfaces: [stream]))

        // Backdrop hills, sunk so their flat border sits under the far ground.
        let hills = TerrainHill().with {
            $0.size = 360; $0.peak = 85; $0.featureSize = 50; $0.border = 8; $0.rockSlope = 0.75
            $0.material = "ground.meadow:2E3A22"; $0.rockMaterial = "rock.mountain"
        }
        let hillZ = cliffZ - 215
        scene.add(hills, at: place(0, hillZ, y: -0.4), seed: seed &+ 5)
        // Spruce-fir forest on the lower hill slopes, thinning out with height.
        func hillY(_ p: V2) -> Float { hills.height(x: p.x, z: p.y - hillZ, seed: seed &+ 5) - 0.4 }
        let slopeSpots = Scatter.poisson(count: 420, outerRadius: 200, minSpacing: 6, seed: seed &+ 7) { p in
            guard p.y < cliffZ - 22, p.y > hillZ - 60 else { return false }
            let h = hillY(p)
            let g = abs(hillY(p + V2(2, 0)) - h) + abs(hillY(p + V2(0, 2)) - h)
            return h > 1 && h < 30 * (0.7 + 0.6 * Float(Noise.perlin(V3(p.x * 0.03, 0, p.y * 0.03)) + 0.5)) && g < 2.2
        }
        var slopeTrees = [[simd_float4x4]](repeating: [], count: 3)
        for p in slopeSpots { slopeTrees[rng.int(0...2)].append(SceneStrips.xform(p, y: hillY(p) - 0.3, &rng, scale: 0.8...1.2)) }
        scene.field(FirTree(), seed: seed &+ 90, transforms: slopeTrees[0], options: .trees)
        scene.field(SpruceTree(), seed: seed &+ 91, transforms: slopeTrees[1], options: .trees)
        scene.field(LarchTree(), seed: seed &+ 92, transforms: slopeTrees[2], options: .trees)

        // Cliff band: seven 6 m sections facing the meadow on an arc of radius 45 m, each based at the
        // lowest ground under it.
        let sections = 7
        let step = 2 * asin(6 / 2 / arcR)
        var ends: [V2] = []
        for i in 0..<sections {
            let cliff = CliffFace().with { $0.height = cliffHeight; $0.depth = 2.4; $0.material = "rock.granite-bare" }
            let a = (Float(i) - Float(sections - 1) / 2) * step
            let c = V2(sin(a) * arcR, cliffZ + arcR - cos(a) * arcR)
            let lo = stride(from: -3, through: 3, by: 1).map { (d: Float) in meadow(c.x + d * cos(a), c.y + d * sin(a) + 1.2) }.min() ?? 0
            scene.add(cliff, at: Xform(translation: V3(c.x, lo - 0.15, c.y), rotation: simd_quatf(angle: -a, axis: .up)), seed: seed &+ 2)
            if i == 0 || i == sections - 1 { ends.append(c + V2(cos(a), sin(a)) * (i == 0 ? -3.6 : 3.6)) }
        }
        // Outcrops close off the ends of the band.
        scene.add(RockOutcrop().with { $0.size = V3(5.5, 5.2, 4) }, at: place(ends[0].x, ends[0].y, y: y(ends[0]) - 0.2, yaw: 80), seed: seed &+ 3)
        scene.add(RockOutcrop().with { $0.size = V3(5, 4.4, 3.6) }, at: place(ends[1].x, ends[1].y, y: y(ends[1]) - 0.2, yaw: -70), seed: seed &+ 4)
        scene.add(RockOutcrop().with { $0.size = V3(3.4, 2.3, 2.6) }, at: place(-9, -14, y: y(-9, -14) - 0.15, yaw: 30), seed: seed &+ 5)

        // Shrubs, young firs and grass along the cliff brink break up its top line.
        var brink = rng.fork(5)
        var shrubs: [simd_float4x4] = [], saplings: [simd_float4x4] = [], brinkGrass: [simd_float4x4] = []
        var bx: Float = -bandHalf - 4
        while bx < bandHalf + 4 {
            let p = V2(bx, cliffLine(bx) - brink.float(0.4...2.5))
            if brink.chance(0.55) { shrubs.append(SceneStrips.xform(p, y: y(p) - 0.1, &brink, scale: 0.6...1.3)) }
            else if brink.chance(0.5) { saplings.append(SceneStrips.xform(p, y: y(p) - 0.1, &brink, scale: 0.25...0.5)) }
            for _ in 0..<6 {
                let q = V2(bx + brink.float(-1.2...1.2), cliffLine(bx) - brink.float(0.1...3))
                brinkGrass.append(SceneStrips.xform(q, y: y(q) - 0.02, &brink, scale: 0.8...1.4))
            }
            bx += brink.float(1.5...3.2)
        }
        scene.field(Shrub(), seed: seed &+ 15, transforms: shrubs, options: .trees)
        scene.field(FirTree(), seed: seed &+ 16, transforms: saplings, options: .trees)
        scene.field(TallGrass(), seed: seed &+ 17, transforms: brinkGrass, options: .groundCover(cull: 80))

        // Scree fans at the cliff foot.
        for (i, x) in [Float(-12), -4, 6.5, 14].enumerated() {
            let z = cliffZ + 2.6 + x * x / (2 * 45) + rng.float(0...0.6)
            let s = ScreePile().with { $0.footprint = V2(rng.float(6...8), rng.float(4.5...5.5)); $0.height = rng.float(2...2.8); $0.material = "rock.granite-bare" }
            scene.add(s, at: place(x, z, y: y(x, z) - 0.1, yaw: rng.float(-15...15)), seed: seed &+ UInt64(10 + i))
        }

        // Conifer stands: Poisson spots inside a few stand circles, three species, three builds each.
        let stands: [(V2, Float)] = [(V2(-27, -14), 8), (V2(-34, 0), 6), (V2(28, -16), 8), (V2(36, -2), 6),
                                     (V2(-30, -44), 10), (V2(32, -42), 9), (V2(-4, -52), 6)]
        let treeSpots = Scatter.poisson(count: 120, outerRadius: half - 2, minSpacing: 3.4, seed: seed &+ 20) { p in
            stands.contains { simd_length(p - $0.0) < $0.1 * (0.8 + 0.4 * Float(Noise.perlin(V3(p.x * 0.2, 0, p.y * 0.2)) + 0.5)) }
                && streamDist(p.x, p.y) > 3 && abs(p.y - cliffZ - p.x * p.x / 90) > 2.5
        }
        var buckets = [[simd_float4x4]](repeating: [], count: 9)
        for p in treeSpots {
            let r = rng.float()
            let sp = r < 0.45 ? 0 : (r < 0.75 ? 1 : 2)
            buckets[sp * 3 + rng.int(0...2)].append(SceneStrips.xform(p, y: y(p) - 0.12, &rng, scale: 0.75...1.15))
        }
        for v in 0..<3 {
            scene.field(LarchTree(), seed: seed &+ UInt64(30 + v), transforms: buckets[v], options: .trees)
            scene.field(FirTree(), seed: seed &+ UInt64(33 + v), transforms: buckets[3 + v], options: .trees)
            scene.field(ScotsPine(), seed: seed &+ UInt64(36 + v), transforms: buckets[6 + v], options: .trees)
        }

        // Boulders in the meadow, the larger ones mossy, with moss cushions at their feet.
        let rocks = Scatter.poisson(count: 14, outerRadius: 30, minSpacing: 5, seed: seed &+ 40) { p in
            streamDist(p.x, p.y) > 2.5 && p.y > self.cliffZ + 6 && simd_length(p - V2(0, 16)) > 4
        }
        var mossSpots: [simd_float4x4] = []
        for (i, p) in rocks.enumerated() {
            let k = rng.float(0.6...1.5)
            let yaw = rng.float(0...360)
            if i % 2 == 0 {
                scene.add(MossyRock().with { $0.size = V3(1.3, 0.8, 1.1) * k }, at: place(p.x, p.y, y: y(p) - 0.05, yaw: yaw), seed: seed &+ UInt64(41 + i))
            } else {
                scene.add(Boulder().with { $0.size = V3(1.5, 0.9, 1.2) * k }, at: place(p.x, p.y, y: y(p) - 0.05, yaw: yaw), seed: seed &+ UInt64(41 + i))
            }
            for _ in 0..<3 {
                let a = rng.float(0...(2 * .pi)), r = 0.8 * k + rng.float(0...0.4)
                let q = p + V2(cos(a), sin(a)) * r
                mossSpots.append(SceneStrips.xform(q, y: y(q) - 0.02, &rng, scale: 0.7...1.4))
            }
        }
        scene.field(MossMound(), seed: seed &+ 60, transforms: mossSpots, options: .groundCover(cull: 40))

        // River stones along the stream: wet in the channel, dry on the banks.
        var wetStones: [simd_float4x4] = [], dryStones: [simd_float4x4] = []
        var z = streamTop + 2
        while z < 34 {
            let off = rng.float(-1.3...1.3)
            let p = V2(streamX(z) + off, z)
            let m = SceneStrips.xform(p, y: y(p) - 0.04, &rng, scale: 0.7...1.3)
            if abs(off) < 0.9 { wetStones.append(m) } else { dryStones.append(m) }
            z += rng.float(0.7...1.6)
        }
        scene.field(RiverStones().with { $0.wet = true; $0.radius = 0.5 }, seed: seed &+ 61, transforms: wetStones, options: .groundCover(cull: 60))
        scene.field(RiverStones().with { $0.radius = 0.55 }, seed: seed &+ 62, transforms: dryStones, options: .groundCover(cull: 60))

        // Meadow cover. Patchy noise masks keep flowers and clover in drifts instead of a uniform sprinkle.
        func open(_ p: V2, bank: Float = 1.6) -> Bool {
            streamDist(p.x, p.y) > bank && p.y > cliffZ + 4 && !rocks.contains { simd_length($0 - p) < 0.9 }
        }
        func drift(_ p: V2, _ k: Float, _ s: UInt32, _ cut: Float) -> Bool {
            Noise.fbm(V3(p.x * k, 0, p.y * k), octaves: 3, seed: ns &+ s) > cut
        }
        func cover<A: RealAsset>(_ a: A, _ n: Int, _ s: UInt64, radius: Float = 30, center: V2 = .zero, scale: ClosedRange<Float>,
                                 cull: Float = 30, _ accept: @escaping (V2) -> Bool) {
            let pts = Scatter.uniform(count: n, outerRadius: radius, seed: seed &+ s) { accept($0 + center) }.map { $0 + center }
            let mid = pts.count / 2
            scene.field(a, seed: seed &+ s, transforms: pts[..<mid].map { SceneStrips.xform($0, y: y($0) - 0.02, &rng, scale: scale) }, options: .groundCover(cull: cull))
            scene.field(a, seed: seed &+ s &+ 1, transforms: pts[mid...].map { SceneStrips.xform($0, y: y($0) - 0.02, &rng, scale: scale) }, options: .groundCover(cull: cull))
        }
        // Grass is densest around the camera, where single tufts would otherwise read as gaps.
        let eye = V2(-1.5, 17)
        cover(GrassTuft(), grass, 70, scale: 0.7...1.3, cull: 50) { open($0, bank: 1.2) }
        cover(GrassTuft().with { $0.height = 0.3 }, grass * 2, 80, radius: 14, center: eye, scale: 0.7...1.3) { open($0, bank: 1.2) }
        cover(TallGrass(), grass / 3, 72, scale: 0.7...1.2) { open($0) && drift($0, 0.15, 3, -0.05) }
        cover(TallGrass(), grass / 2, 82, radius: 12, center: eye, scale: 0.7...1.2) { open($0) && drift($0, 0.25, 13, -0.1) }
        cover(MeadowFlowers(), grass / 7, 74, scale: 0.7...1.1) { open($0) && drift($0, 0.2, 5, 0.05) }
        cover(Dandelion(), grass / 12, 76, scale: 0.8...1.2) { open($0) && drift($0, 0.3, 9, 0) }
        cover(CloverPatch(), grass / 10, 78, scale: 0.8...1.4) { open($0) && drift($0, 0.25, 11, 0.08) }

        let eyeY = y(eye) + 1.65
        scene.camera = .init(eye: V3(eye.x, eyeY, eye.y), target: V3(3, eyeY + 1.2, -20), fov: 60)
        return scene
    }
}
