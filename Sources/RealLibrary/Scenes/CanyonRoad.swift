import simd
import Foundation
import RealityKit
import RealKit

/// Two-lane desert highway, 7.4 m of asphalt with double yellow center lines and white edge lines,
/// running 500 m down a sandy canyon floor between red sandstone buttes up to ~45 m tall. Saguaro,
/// barrel cactus, agave, dry grass, rock piles and low dunes line the road. The camera stands on the
/// shoulder looking down the road; the demo opens it at golden hour.
public struct CanyonRoad: RealSceneBuilder {
    public static let id = "canyon-road"
    public static let summary = "Desert highway through a sandy canyon: sandstone buttes, dunes, saguaro, barrel cactus, agave, dry grass, rock piles."
    public static let tags = ["desert", "road", "outdoor", "rock"]
    public static let author = "hunter"

    /// Side of the detailed ground patch in meters.
    public var size: Float = 300
    public var laneWidth: Float = 3.6
    public var sand: MaterialKey = "ground.sand:B98A5E"
    public init() {}

    /// Road centerline x at z.
    func roadX(_ z: Float) -> Float { 6 * sin(z * 0.011 + 0.4) + 2 * sin(z * 0.031) - 6 * sin(0.4) }
    /// Road surface base height at z (gentle grade), easing to the far-ground level past the patch.
    func roadY(_ z: Float) -> Float {
        let fade = smoothstep(size * 0.36, size * 0.48, abs(z))
        return (0.6 * sin(z * 0.017) + 0.25 * sin(z * 0.043 + 1)) * (1 - fade) - 0.21 * fade
    }

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        scene.farGround = sand
        var rng = SeededRNG(seed: seed &+ 99)
        let ns = UInt32(truncatingIfNeeded: seed)
        let half = size / 2
        let roadHalf = laneWidth + 0.1

        // Canyon floor: low eroded relief, rising toward the canyon walls, flattened under the road.
        let patch = GroundPatch().with { $0.relief = 1.2; $0.featureSize = 22; $0.flatCenter = 0 }
        func y(_ x: Float, _ z: Float) -> Float {
            let d = abs(x - roadX(z))
            let natural = patch.height(x: x, z: z, seed: seed) + 0.012 * max(0, d - 20) * (1 + Noise.perlin(V3(z * 0.01, 0, 0), seed: ns))
            let road = roadY(z) - 0.03
            let k = smoothstep(roadHalf + 0.6, roadHalf + 7, d)
            let edge = 1 - smoothstep(half * 0.78, half * 0.98, max(abs(x), abs(z)))
            return (road + (natural - road) * k) * edge - 0.22 * (1 - edge)
        }
        func y(_ p: V2) -> Float { y(p.x, p.y) }
        scene.add(Model(name: "canyon-floor", surfaces: [SceneStrips.ground(size: size, segments: 250, material: sand, relief: 1.2) { y($0.x, $0.y) }]))

        // Road: asphalt ribbon, gravel shoulders and painted lines, from behind the camera to the horizon.
        let z0: Float = -520, z1: Float = 70
        var road = Model(name: "highway")
        road.add(SceneStrips.ribbon(material: "asphalt", z0: z0, z1: z1, width: roadHalf * 2, along: 400, across: 6, cx: roadX) { _, z in roadY(z) + 0.05 })
        for side: Float in [-1, 1] {
            road.add(SceneStrips.ribbon(material: "ground.gravel", z0: z0, z1: z1, width: 1.0, along: 300, across: 3, cx: { roadX($0) + side * (roadHalf + 0.45) }) { x, z in
                roadY(z) + 0.035 - 0.05 * abs(x - roadX(z) - side * (roadHalf + 0.45))
            })
            road.add(SceneStrips.ribbon(material: "concrete.smooth:E6E3DA", z0: z0, z1: z1, width: 0.12, along: 400, across: 1, cx: { roadX($0) + side * (roadHalf - 0.2) }) { _, z in roadY(z) + 0.056 })
            road.add(SceneStrips.ribbon(material: "concrete.smooth:D9A521", z0: z0, z1: z1, width: 0.1, along: 400, across: 1, cx: { roadX($0) + side * 0.1 }) { _, z in roadY(z) + 0.056 })
        }
        scene.add(road)

        // Buttes and mesas: big formations on both sides of the canyon, from 50 m out to the horizon.
        let buttes: [(V2, V3, Float)] = [
            (V2(-62, -40), V3(46, 30, 40), 20), (V2(52, -95), V3(34, 42, 30), -10), (V2(-70, -150), V3(70, 38, 50), 40),
            (V2(30, -175), V3(12, 34, 10), 15), (V2(80, -230), V3(80, 46, 55), 5), (V2(-36, -300), V3(16, 48, 14), -25),
            (V2(-90, -330), V3(90, 55, 60), 10), (V2(90, -380), V3(70, 60, 70), 15), (V2(-90, 30), V3(40, 26, 36), 60),
            (V2(24, -560), V3(140, 70, 80), 0), (V2(-160, -440), V3(110, 50, 70), 30),
        ]
        var talus: [[simd_float4x4]] = [[], []]
        for (i, b) in buttes.enumerated() {
            let (p, sz, yaw) = b
            let mesa = MesaRock().with { $0.size = sz; $0.bedHeight = sz.y / 9; $0.ledgeDepth = sz.y / 22; $0.lodDistances = [160, 380] }
            scene.add(mesa, at: place(p.x, p.y, y: y(p) - 0.6, yaw: yaw), seed: seed &+ UInt64(10 + i))
            // Talus skirt: scree fans scaled to the butte, apex against the foot, eight around the rim.
            let skirt = sz.y / 4.5, th = yaw * .pi / 180
            for k in 0..<8 {
                let a = Float(k) / 8 * 2 * .pi + rng.float(-0.25...0.25)
                let l = V2(cos(a) * sz.x * 0.45, sin(a) * sz.z * 0.45) + V2(cos(a), sin(a)) * skirt * 1.1
                let w = V2(l.x * cos(th) + l.y * sin(th), -l.x * sin(th) + l.y * cos(th))
                let q = p + w, dir = simd_normalize(w)
                talus[k % 2].append(Xform(translation: V3(q.x, y(q) - 0.25 * skirt, q.y), rotation: simd_quatf(angle: atan2(dir.x, dir.y), axis: .up),
                                          scale: V3(repeating: skirt * rng.float(0.85...1.2))).matrix)
            }
        }

        for v in 0..<2 { scene.field(ScreePile().with { $0.material = "rock.redstone"; $0.rocks = 200 }, seed: seed &+ UInt64(200 + v), transforms: talus[v], options: .trees) }

        // Dunes drifted against the canyon floor, slip faces downwind (+X).
        let dunes = Scatter.poisson(count: 9, outerRadius: 90, innerRadius: 14, minSpacing: 22, seed: seed &+ 2) { p in
            abs(p.x - roadX(p.y)) > 16 && !buttes.contains { simd_length($0.0 - p) < max($0.1.x, $0.1.z) * 0.7 }
        }
        for (i, p) in dunes.enumerated() {
            let d = SandDune().with { $0.material = sand; $0.peak = rng.float(1.4...2.8); $0.halfWidth = rng.float(4.5...7) }
            scene.add(d, at: place(p.x, p.y, y: y(p) - 0.15, yaw: rng.float(-20...20)), seed: seed &+ UInt64(30 + i))
        }

        func off(_ p: V2, _ m: Float) -> Bool {
            abs(p.x - roadX(p.y)) > roadHalf + m && !buttes.contains { simd_length($0.0 - p) < max($0.1.x, $0.1.z) * 0.62 }
                && !dunes.contains { simd_length($0 - p) < 7 }
        }
        func scatter(_ n: Int, radius: Float, spacing: Float, margin: Float, _ s: UInt64) -> [V2] {
            Scatter.poisson(count: n, outerRadius: radius, minSpacing: spacing, seed: seed &+ s) { off($0, margin) }
        }
        func fields<A: RealAsset>(_ a: A, _ pts: [V2], _ s: UInt64, sink: Float, scale: ClosedRange<Float>, lean: Float = 0,
                                  options: RealInstancing.Options) {
            var b = [[simd_float4x4]](repeating: [], count: 3)
            for p in pts { b[rng.int(0...2)].append(SceneStrips.xform(p, y: y(p) - sink, &rng, scale: scale, lean: lean)) }
            for v in 0..<3 { scene.field(a, seed: seed &+ s &+ UInt64(v), transforms: b[v], options: options) }
        }

        fields(Saguaro(), scatter(90, radius: 140, spacing: 9, margin: 6, 40), 40, sink: 0.1, scale: 0.6...1.15, lean: 3, options: .trees)
        fields(BarrelCactus(), scatter(160, radius: 70, spacing: 3, margin: 3, 50), 50, sink: 0.05, scale: 0.6...1.3, options: .groundCover(cull: 70))
        fields(Agave(), scatter(70, radius: 70, spacing: 4, margin: 3, 60), 60, sink: 0.05, scale: 0.6...1.2, options: .groundCover(cull: 70))

        // Dry grass in clumps, thicker in the shallow wash along the road shoulders.
        let grassPts = Scatter.uniform(count: 5000, outerRadius: 45, seed: seed &+ 70) { p in
            off(p, 1.4) && Noise.fbm(V3(p.x * 0.18, 0, p.y * 0.18), octaves: 3, seed: ns &+ 5) > -0.05
        }
        let mid = grassPts.count / 2
        scene.field(DryGrass(), seed: seed &+ 71, transforms: grassPts[..<mid].map { SceneStrips.xform($0, y: y($0) - 0.02, &rng, scale: 0.6...1.3) }, options: .groundCover(cull: 40))
        scene.field(DryGrass().with { $0.height = 0.3 }, seed: seed &+ 72, transforms: grassPts[mid...].map { SceneStrips.xform($0, y: y($0) - 0.02, &rng, scale: 0.6...1.3) }, options: .groundCover(cull: 40))

        // Rock piles and loose sandstone blocks.
        for (i, p) in scatter(10, radius: 60, spacing: 12, margin: 5, 80).enumerated() {
            scene.add(RockPile().with { $0.material = "rock.sandstone"; $0.radius = rng.float(0.7...1.4); $0.height = rng.float(0.4...0.9) },
                      at: place(p.x, p.y, y: y(p) - 0.05, yaw: rng.float(0...360)), seed: seed &+ UInt64(81 + i))
        }
        for (i, p) in scatter(14, radius: 70, spacing: 8, margin: 4, 95).enumerated() {
            scene.add(Boulder().with { $0.material = "rock.redstone"; $0.size = V3(1.6, 1.0, 1.3) * rng.float(0.5...1.6) },
                      at: place(p.x, p.y, y: y(p) - 0.05, yaw: rng.float(0...360)), seed: seed &+ UInt64(100 + i))
        }

        let ez: Float = 22
        let eye = V2(roadX(ez) + roadHalf + 1.4, ez)
        let eyeY = y(eye) + 1.65
        scene.camera = .init(eye: V3(eye.x, eyeY, eye.y), target: V3(roadX(-90), eyeY + 1.5, -90), fov: 60)
        return scene
    }
}
