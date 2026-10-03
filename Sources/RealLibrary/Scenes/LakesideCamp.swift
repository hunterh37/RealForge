import simd
import Foundation
import RealityKit
import RealKit

/// Lakeshore camp, 72 m terrain: a pond about 13 x 10 m with reeds and wet river stones, a dome tent,
/// fire ring with chairs, firewood, cooler, lantern and a canoe pulled up on the bank, ringed by
/// spruce, Scots pine and birch. The camera stands behind the fire looking across the camp to the water.
public struct LakesideCamp: RealSceneBuilder {
    public static let id = "lakeside-camp"
    public static let summary = "Pond-side camp: dome tent, fire ring, chairs, canoe on the bank, reeds and river stones, ringed by spruce, pine and birch."
    public static let tags = ["nature", "camp", "water", "forest", "showcase"]
    public static let author = "realforge"

    /// Terrain side length in meters.
    public var size: Float = 72
    /// Forest outer radius in meters.
    public var radius: Float = 33
    /// Open clearing radius around the camp in meters.
    public var clearing: Float = 12
    public var trees = 145
    /// Pond center and half-extents (x, z) in meters.
    public var pond = V2(7.5, -6)
    public var pondSize = V2(6.8, 5.2)
    /// Water surface height in meters.
    public var waterLevel: Float = -0.14
    public init() {}

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 99)
        let ns = UInt32(truncatingIfNeeded: seed)
        let base = GroundPatch().with { $0.size = size; $0.relief = 0.9; $0.featureSize = 14; $0.flatCenter = clearing * 0.9 }
        let fire = V2(-1.0, -2.0)

        // Pond: elliptical bowl with a ragged noisy shore.
        func pondR(_ p: V2) -> Float {
            let q = (p - pond) / pondSize
            return simd_length(q) + Noise.fbm(V3(p.x * 0.35, 2, p.y * 0.35), octaves: 3, seed: ns &+ 4) * 0.25
        }
        func height(_ p: V2) -> Float {
            let r = pondR(p)
            let bowl = -1.0 * (1 - smoothstep(0.35, 1.15, r))
            // The ground climbs gently into the forest so the horizon sits behind trees.
            let rim = smoothstep(clearing + 6, radius + 4, simd_length(p)) * 3.0
            return (base.height(x: p.x, z: p.y, seed: seed) + rim) * smoothstep(0.9, 1.6, r) + bowl
        }
        func y(_ p: V2) -> Float { height(p) }
        func wet(_ p: V2) -> Bool { height(p) < waterLevel + 0.04 }

        // Bare earth: fire circle, tent pad, a trodden line to the shore and a muddy waterline band.
        // Waterline traced by bisection along rays from the pond center.
        var shoreline: [V2] = []
        for i in 0..<720 {
            let a = Float(i) / 720 * 2 * .pi
            var lo: Float = 0.4, hi: Float = 2.0
            for _ in 0..<18 { let m = (lo + hi) / 2; if height(pond + V2(cos(a), sin(a)) * pondSize * m) < waterLevel { lo = m } else { hi = m } }
            shoreline.append(pond + V2(cos(a), sin(a)) * pondSize * lo)
        }
        // Landing spot: the waterline point nearest the fire.
        let shore = shoreline.min { simd_length($0 - fire) < simd_length($1 - fire) }!
        func segDist(_ p: V2, _ a: V2, _ b: V2) -> Float {
            let ab = b - a, t = max(0, min(1, simd_dot(p - a, ab) / simd_dot(ab, ab)))
            return simd_length(p - (a + ab * t))
        }
        func wear(_ p: V2) -> Float {
            let n = Noise.fbm(V3(p.x * 1.6, 5, p.y * 1.6), octaves: 3, seed: ns &+ 8) * 0.45
            let atFire = 1 - smoothstep(1.4, 2.6, simd_length(p - fire) + n)
            let tent = 1 - smoothstep(0.6, 1.8, simd_length((p - V2(-4.6, -5.4)) / V2(1.6, 1.2)) + n)
            let path = 1 - smoothstep(0.25, 0.75, segDist(p, fire, shore) + n * 0.8)
            let bank = 1 - smoothstep(0.02, 0.12, height(p) - waterLevel + n * 0.04)
            return max(max(atFire * 0.95, tent * 0.7), max(path * 0.8, bank))
        }

        var terrain = Prim.terrain(size: V2(size, size), segments: 220, material: "ground.meadow-worn") { p in
            height(p) - smoothstep(size * 0.42, size * 0.5, max(abs(p.x), abs(p.y))) * 0.05
        }
        GroundMesh.shadeHollows(&terrain, gridSide: 221, radius: 6, relief: 0.9, strength: 0.5)
        terrain.paintSplat { wear(V2($0.x, $0.z)) }
        scene.add(Model(name: "lakeside-ground", surfaces: [terrain]))

        // Water sheet; splat 1 at the waterline so the shallows show the bed.
        var water = Prim.terrain(size: pondSize * 2.6, segments: 80, material: "water.pond") { _ in 0 }
        water.paintSplat { p in 1 - smoothstep(0.0, 0.5, waterLevel - height(V2(p.x, p.z) + pond)) }
        scene.add(Model(name: "pond", surfaces: [water]), at: Xform(translation: V3(pond.x, waterLevel, pond.y)))

        func xf(_ p: V2, scale: ClosedRange<Float>, sink: Float, tilt: Float = 0) -> simd_float4x4 {
            var r = simd_quatf(degrees: rng.float(0...360), axis: .up)
            if tilt > 0 { r = simd_quatf(degrees: rng.float(-tilt...tilt), axis: V3(1, 0, 0)) * r }
            return Xform(translation: V3(p.x, y(p) - sink, p.y), rotation: r, scale: V3(repeating: rng.float(scale))).matrix
        }
        func at(_ p: V2, yaw: Float, sink: Float = 0.01) -> Xform { place(p.x, p.y, y: y(p) - sink, yaw: yaw) }
        /// Yaw that turns an asset's +Z front toward `target`.
        func face(_ p: V2, _ target: V2) -> Float { let d = target - p; return atan2(d.x, d.y) * 180 / .pi }

        // Forest edge: spruce, Scots pine and birch, 3 builds each. Birch keeps to the open fringe.
        let spots = Scatter.poisson(count: trees, outerRadius: radius, innerRadius: clearing, minSpacing: 3.2, seed: seed &+ 1) { p in
            pondR(p) > 1.45 && simd_length(p) > clearing + 2.5 * Float(Noise.perlin(V3(p.x * 0.15, 0, p.y * 0.15)) + 0.5)
        }
        var spruce: [[simd_float4x4]] = [[], [], []], pine: [[simd_float4x4]] = [[], [], []], birch: [[simd_float4x4]] = [[], [], []]
        var canopy: [V2] = []
        for p in spots {
            let edge = simd_length(p) < clearing + 6
            let r = rng.float()
            let v = rng.int(0...2)
            if edge && r < 0.4 || r < 0.15 { birch[v].append(xf(p, scale: 0.8...1.1, sink: 0.1)) }
            else if r < 0.6 { spruce[v].append(xf(p, scale: 0.8...1.25, sink: 0.1)) }
            else { pine[v].append(xf(p, scale: 0.85...1.15, sink: 0.1)) }
            canopy.append(p)
        }
        for v in 0..<3 {
            scene.field(SpruceTree(), seed: seed &+ UInt64(10 + v), transforms: spruce[v], options: .trees)
            scene.field(ScotsPine(), seed: seed &+ UInt64(13 + v), transforms: pine[v], options: .trees)
            scene.field(BirchTree(), seed: seed &+ UInt64(16 + v), transforms: birch[v], options: .trees)
        }

        // Camp. Fire in the middle, tent upslope, chairs facing the fire, kit around.
        scene.add(CampfireRing(), at: at(fire, yaw: 20, sink: 0.0), seed: seed &+ 20)
        let tentP = V2(-4.6, -5.6)
        scene.add(DomeTent(), at: at(tentP, yaw: face(tentP, fire) + 8, sink: 0), seed: seed &+ 21)
        let chair1 = V2(0.6, -0.6), chair2 = V2(-2.6, -0.9)
        scene.add(CampChair(), at: at(chair1, yaw: face(chair1, fire) + 6), seed: seed &+ 22)
        scene.add(CampChair().with { $0.fabricColor = 0x6B3A26 }, at: at(chair2, yaw: face(chair2, fire) - 10), seed: seed &+ 23)
        scene.add(Cooler(), at: at(V2(1.4, -1.3), yaw: 70), seed: seed &+ 24)
        scene.add(CampLantern(), at: at(V2(-2.85, -4.1), yaw: 30), seed: seed &+ 25)
        let wood = V2(-6.8, -3.2)
        scene.add(FirewoodStack(), at: at(wood, yaw: face(wood, fire) + 90, sink: 0.02), seed: seed &+ 26)
        scene.add(AxeInStump(), at: at(V2(-5.3, -2.1), yaw: 140), seed: seed &+ 27)
        scene.add(LogStump().with { $0.diameter = 0.42; $0.height = 0.38 }, at: at(V2(-1.2, -3.85), yaw: 10, sink: 0.04), seed: seed &+ 28)
        for i in 0..<3 {
            let p = fire + V2(-1.6 + Float(i) * 0.25, 0.9 + Float(i) * 0.12)
            scene.add(Firewood(), at: Xform(translation: V3(p.x, y(p) - 0.01, p.y),
                                            rotation: simd_quatf(degrees: rng.float(0...360), axis: .up)),
                      seed: seed &+ UInt64(30 + i))
        }
        // Canoe hauled up the bank, bow toward the water, a little heeled over.
        let inward = simd_normalize(pond - shore)
        let canoeP = shore + V2(inward.y, -inward.x) * 1.2 - inward * 0.6
        let canoeYaw = face(canoeP, canoeP + inward) - 90
        scene.add(Canoe(), at: Xform(translation: V3(canoeP.x, y(canoeP) - 0.03, canoeP.y),
                                     rotation: simd_quatf(degrees: canoeYaw, axis: .up) * simd_quatf(degrees: 4, axis: V3(1, 0, 0))), seed: seed &+ 35)
        /// False inside the canoe's footprint (2.6 x 0.55 m half extents) so grass and reeds stay out of the hull.
        func clear(_ p: V2) -> Bool {
            let d = p - canoeP
            return abs(simd_dot(d, inward)) > 2.6 || abs(simd_dot(d, V2(inward.y, -inward.x))) > 0.55
        }

        // Old wood at the forest edge.
        scene.add(FallenLog(), at: at(V2(-9.5, -11), yaw: 25, sink: 0.02), seed: seed &+ 40)
        scene.add(FallenLog().with { $0.length = 2.8; $0.buttDiameter = 0.32 }, at: at(V2(4, -15.5), yaw: -60, sink: 0.02), seed: seed &+ 41)
        scene.add(LogStump(), at: at(V2(-12.5, -3), yaw: 0, sink: 0.03), seed: seed &+ 42)
        scene.add(LogStump().with { $0.diameter = 0.38; $0.height = 0.3 }, at: at(V2(9, 4.5), yaw: 90, sink: 0.03), seed: seed &+ 43)

        // Shore: wet stone groups at the waterline, dry ones up the bank.
        for k in 0..<6 {
            let p = shoreline[(k * 113 + 40) % shoreline.count]
            if simd_length(p - canoeP) < 2.2 { continue }
            scene.add(RiverStones().with { $0.wet = true; $0.radius = 0.7 }, at: at(p, yaw: rng.float(0...360), sink: 0.03), seed: seed &+ UInt64(50 + k))
        }

        // Reeds and cattails in the shallows on the far and east banks.
        var reeds: [simd_float4x4] = [], reedsB: [simd_float4x4] = []
        for (i, p) in shoreline.enumerated() where i % 3 == 0 {
            let a = Float(i) / Float(shoreline.count) * 2 * .pi
            let side = sin(a) < 0.25 || cos(a) > 0.3            // far bank (z < pond) and east side
            if !side || Noise.perlin(V3(p.x * 0.4, 9, p.y * 0.4), seed: ns) < -0.15 { continue }
            let out = simd_normalize(p - pond) * rng.float(-0.6...0.4)
            let q = p + out
            if !clear(q) { continue }
            let t = xf(q, scale: 0.75...1.15, sink: 0.05)
            if i % 2 == 0 { reeds.append(t) } else { reedsB.append(t) }
        }
        scene.field(ReedClump(), seed: seed &+ 60, transforms: reeds, options: .trees)
        scene.field(ReedClump().with { $0.height = 1.4 }, seed: seed &+ 61, transforms: reedsB, options: .trees)

        // Ground cover. Grass avoids the worn ground and the water.
        let cover = RealInstancing.Options.groundCover(cull: 32)
        let grassSpots = Scatter.uniform(count: 26000, outerRadius: radius, seed: seed &+ 70) { p in
            !wet(p) && clear(p) && wear(p) < 0.25 && Float(Noise.perlin(V3(p.x * 0.3, 1, p.y * 0.3))) * 0.5 + 0.5 < (simd_length(p) < clearing + 4 ? 0.95 : 0.45)
        }
        // Blade tufts near the camp where they are seen up close; cheap card clumps farther out.
        let near = grassSpots.filter { simd_length($0 - V2(0, -1)) < 11 }
        let far = grassSpots.filter { simd_length($0 - V2(0, -1)) >= 11 }
        let half = near.count / 2
        scene.field(GrassTuft(), seed: seed &+ 71, transforms: near[..<half].map { xf($0, scale: 0.7...1.3, sink: 0.02) }, options: cover)
        scene.field(GrassTuft().with { $0.height = 0.35 }, seed: seed &+ 72, transforms: near[half...].map { xf($0, scale: 0.7...1.3, sink: 0.02) }, options: cover)
        scene.field(GrassClump().with { $0.height = 0.3; $0.width = 0.4 }, seed: seed &+ 73, transforms: far.map { xf($0, scale: 0.7...1.2, sink: 0.02) }, options: cover)

        // Tall grass along the bank and the clearing edge.
        let tall = Scatter.uniform(count: 1000, outerRadius: radius * 0.8, seed: seed &+ 74) { p in
            let r = pondR(p), d = simd_length(p)
            return !wet(p) && clear(p) && wear(p) < 0.15 && ((r > 1.0 && r < 1.5) || (d > clearing - 1 && d < clearing + 5))
        }
        scene.field(TallGrass(), seed: seed &+ 75, transforms: tall.map { xf($0, scale: 0.8...1.2, sink: 0.02) }, options: cover)

        // Wildflowers in drifts in the open meadow.
        let flowers = Scatter.uniform(count: 380, outerRadius: clearing + 3, seed: seed &+ 76) { p in
            !wet(p) && clear(p) && wear(p) < 0.1 && Noise.perlin(V3(p.x * 0.25, 4, p.y * 0.25), seed: ns &+ 1) > 0.12
        }
        scene.field(MeadowFlowers(), seed: seed &+ 77, transforms: flowers.map { xf($0, scale: 0.8...1.2, sink: 0.01) }, options: cover)

        // Under the trees: ferns, leaf litter, mushrooms by the logs and trunks.
        let shade = Scatter.uniform(count: 1400, outerRadius: radius, innerRadius: clearing, seed: seed &+ 78) { p in
            pondR(p) > 1.4 && Noise.perlin(V3(p.x * 0.2, 6, p.y * 0.2), seed: ns &+ 2) > -0.1
        }
        let ferns = shade.filter { _ in rng.float() < 0.55 }
        scene.field(Fern(), seed: seed &+ 79, transforms: ferns.map { xf($0, scale: 0.7...1.2, sink: 0.02) }, options: cover)
        let litter = Scatter.uniform(count: 500, outerRadius: radius, innerRadius: clearing - 2, seed: seed &+ 80) { pondR($0) > 1.3 }
        scene.field(LeafLitter(), seed: seed &+ 81, transforms: litter.map { xf($0, scale: 0.8...1.4, sink: 0.0) }, options: cover)
        var shrooms: [simd_float4x4] = []
        for c in canopy.prefix(40) where rng.float() < 0.5 {
            let a = rng.float(0...6.28), p = c + V2(cos(a), sin(a)) * rng.float(0.5...1.1)
            shrooms.append(xf(p, scale: 0.8...1.2, sink: 0.0))
        }
        for p in [V2(-9.0, -10.4), V2(-10.3, -11.5), V2(4.6, -15.0), V2(-12.0, -2.4)] { shrooms.append(xf(p, scale: 0.9...1.2, sink: 0)) }
        scene.field(MushroomCluster(), seed: seed &+ 82, transforms: shrooms, options: cover)

        scene.farGround = "ground.forest"
        let eye = V2(-1.8, 4.6)
        let eyeY = y(eye) + 1.65
        scene.camera = .init(eye: V3(eye.x, eyeY, eye.y), target: V3(2.5, eyeY - 0.9, -7), fov: 60)
        return scene
    }
}
