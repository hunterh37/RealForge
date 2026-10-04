import simd
import Foundation
import RealityKit
import RealKit

/// Business-district plaza between two curtain-wall office blocks: large-format paving, raised concrete
/// planters with maple and Japanese maple, benches, bollards, street lamps, a lawn strip and street
/// furniture, late-afternoon sun raking across the glass.
public struct OfficePlaza: RealSceneBuilder {
    public static let id = "office-plaza"
    public static let summary = "Plaza between two curtain-wall office blocks: paving, planters with maples, benches, bollards and lamps in late-afternoon sun."
    public static let tags = ["urban", "outdoor", "showcase"]
    public static let author = "realityhd"

    public init() {}

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 13)
        // Two blocks framing the plaza (entrances face the plaza).
        scene.add(OfficeBlock(), at: place(-22, -24, yaw: 0), seed: seed &+ 1)
        scene.add(OfficeBlock().with { $0.floors = 8; $0.width = 26 }, at: place(24, -20, yaw: -90), seed: seed &+ 2)
        // Paving.
        var pave = Model(name: "plaza")
        pave.add(Prim.terrain(size: V2(90, 70), segments: 60, material: "paving.slab") { _ in 0 })
        scene.add(pave, at: place(0, -6))
        // Planters with trees.
        var planter = Model(name: "planter")
        let ps: Float = 3.2
        for (sx, sz, w, d) in [(Float(0), Float(-ps / 2 + 0.1), ps, Float(0.2)), (0, ps / 2 - 0.1, ps, 0.2), (-ps / 2 + 0.1, 0, 0.2, ps), (ps / 2 - 0.1, 0, 0.2, ps)] {
            planter.add(Prim.roundedBox(V3(w, 0.5, d), radius: 0.02, bevelSegments: 2, material: "concrete.smooth"), Xform(translation: V3(sx, 0.25, sz)))
        }
        planter.add(Prim.roundedBox(V3(ps - 0.4, 0.06, ps - 0.4), radius: 0.01, bevelSegments: 1, material: "soil.potting"), Xform(translation: V3(0, 0.4, 0)))
        groundAO(&planter, height: 0.2)
        let spots: [V2] = [V2(-8, 4), V2(0, 6), V2(8, 3), V2(-3, -6), V2(6, -7)]
        for (i, p) in spots.enumerated() {
            scene.add(planter, at: place(p.x, p.y, yaw: 0))
            if i % 2 == 0 { scene.add(MapleTree().with { $0.autumn = 0.2 }, at: place(p.x, p.y, y: 0.35, scale: 0.7), seed: seed &+ UInt64(10 + i)) }
            else { scene.add(JapaneseMaple(), at: place(p.x, p.y, y: 0.35), seed: seed &+ UInt64(10 + i)) }
            scene.add(ParkBench(), at: place(p.x, p.y + 2.4, yaw: 180), seed: seed &+ UInt64(20 + i))
        }
        // Bollards along the street edge, lamps.
        scene.field(Bollard(), seed: seed, transforms: stride(from: -20, through: 20, by: 2.0).map { place(Float($0), 14).matrix }, options: .props)
        for x in stride(from: -16, through: 16, by: 8) as StrideThrough<Float> {
            scene.add(StreetLamp(), at: place(x, 12.5, yaw: rng.float(-2...2)), seed: seed &+ 30)
        }
        scene.add(TrashCan(), at: place(3, 10.5), seed: seed &+ 40)
        scene.add(FireHydrant(), at: place(-11, 13.2, yaw: 30), seed: seed &+ 41)
        // Lawn strip with grass and a few flowers between the plaza and the street.
        var lawn = Model(name: "lawn")
        lawn.add(Prim.terrain(size: V2(44, 3), segments: 20, material: "ground.meadow") { _ in 0.02 })
        scene.add(lawn, at: place(0, 16.5))
        let tufts = Scatter.uniform(count: 700, outerRadius: 22, seed: seed &+ 50) { abs($0.y) < 1.4 }
        scene.field(GrassTuft(), seed: seed, transforms: tufts.map { place($0.x, 16.5 + $0.y, yaw: rng.float(0...360)).matrix }, options: .groundCover(cull: 40))
        scene.farGround = "ground.meadow"
        scene.lighting = .init(sky: SunSky(elevation: 18, azimuth: 235, turbidity: 2.6))
        scene.camera = .init(eye: V3(-3, 1.7, 13), target: V3(2, 6, -12), fov: 62)
        return scene
    }
}
