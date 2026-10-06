import simd
import Foundation
import RealityKit
import RealKit

/// Designed backyard, 14 x 10 m (x -7...7, z -10...0): a mown lawn with a herringbone paver patio on the
/// left holding a stone fire pit ringed by four Adirondack chairs, a cedar pergola over a second sitting
/// area on the right, a segmental retaining wall across the back with a mulch bed of boxwoods and
/// hydrangeas above it, kidney beds along the sides, path lights along the lawn edge, a birdbath, a
/// Japanese maple uplit by a spotlight, oaks and maples beyond. The camera stands at the house end.
public struct BackyardLandscape: RealSceneBuilder {
    public static let id = "backyard-landscape"
    public static let summary = "Designed 14 x 10 m backyard: lawn, paver patio with fire pit and Adirondack chairs, pergola, retaining wall, mulch beds with shrubs, path lights, trees."
    public static let tags = ["garden", "landscaping", "outdoor", "showcase"]
    public static let author = "realityhd"

    /// Yard extents (m).
    public var yardX: ClosedRange<Float> = -7 ... 7
    public var yardZ: ClosedRange<Float> = -10 ... 0
    /// Patio center and size (m).
    public var patioCenter = V2(-3.2, -4.4)
    public var patioSize: Float = 3.6
    public init() {}

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 99)
        let ground = GroundPatch().with { $0.size = 70; $0.segments = 128; $0.relief = 0.2; $0.flatCenter = 14; $0.material = "ground.meadow" }
        scene.add(ground, seed: seed)
        func y(_ p: V2) -> Float { ground.height(x: p.x, z: p.y, seed: seed) }
        func at(_ x: Float, _ z: Float, yaw: Float = 0, lift: Float = 0) -> Xform { place(x, z, y: y(V2(x, z)) + lift, yaw: yaw) }
        func face(_ from: V2, _ to: V2) -> Float { let d = to - from; return atan2(d.x, d.y) * 180 / .pi }

        // Lawn: an opaque thatch base over the yard, mown grass clumps on top away from hardscape and beds.
        let yx = yardX, yz = yardZ
        var lawn = Model(name: "lawn")
        lawn.add(Prim.terrain(size: V2(yx.upperBound - yx.lowerBound, yz.upperBound - yz.lowerBound), segments: 48, material: "grass.lawn-thatch") { p in
            y(V2(p.x, p.y + (yz.lowerBound + yz.upperBound) / 2)) + 0.012
        }, Xform(translation: V3(0, 0, (yz.lowerBound + yz.upperBound) / 2)))
        scene.add(lawn)

        // Hardscape and beds, as footprints for the grass mask.
        let pc = patioCenter, ph = patioSize / 2
        let pergolaC = V2(3.6, -5.6)
        let wallZ: Float = -9.0
        struct Bed { var c: V2; var r: Float; var shape: MulchBed.Shape; var yaw: Float }
        let beds = [Bed(c: V2(-6.0, -1.8), r: 1.1, shape: .kidney, yaw: 90),
                    Bed(c: V2(6.0, -2.2), r: 1.0, shape: .oval, yaw: 90),
                    Bed(c: V2(0.6, -7.6), r: 1.0, shape: .round, yaw: 0)]
        func covered(_ p: V2) -> Bool {
            if abs(p.x - pc.x) < ph + 0.15, abs(p.y - pc.y) < ph + 0.15 { return true }
            if abs(p.x - pergolaC.x) < 1.7, abs(p.y - pergolaC.y) < 1.7 { return true }
            if p.y < wallZ + 0.35 { return true }
            for b in beds where simd_distance(p, b.c) < b.r * (b.shape == .round ? 1.05 : 1.35) { return true }
            return false
        }

        // Paver patio with fire pit and four Adirondack chairs facing it.
        scene.add(PaverPatio().with { $0.w = patioSize; $0.d = patioSize }, at: at(pc.x, pc.y, lift: 0.005), seed: seed &+ 1)
        let padTop: Float = 0.065
        scene.add(StoneFirePit(), at: at(pc.x, pc.y, lift: padTop), seed: seed &+ 2)
        for i in 0..<4 {
            let a = (Float(i) * 90 + 45 + rng.float(-8...8)) * .pi / 180
            let p = pc + V2(sin(a), cos(a)) * 1.45
            scene.add(AdirondackChair(), at: at(p.x, p.y, yaw: face(p, pc) + rng.float(-6...6), lift: padTop), seed: seed &+ 3 &+ UInt64(i))
        }
        for (i, corner) in [V2(-1, -1), V2(1, -1)].enumerated() {
            let p = pc + corner * (ph - 0.3)
            scene.add(TerracottaPlanter(), at: at(p.x, p.y, lift: padTop), seed: seed &+ 8 &+ UInt64(i))
            scene.add(BoxwoodShrub().with { $0.width = 0.45; $0.height = 0.4 }, at: at(p.x, p.y, lift: padTop + 0.32), seed: seed &+ 10 &+ UInt64(i))
        }
        scene.add(SolarLantern(), at: at(pc.x + ph - 0.25, pc.y + ph - 0.25, lift: padTop), seed: seed &+ 12)

        // Pergola sitting area on a gravel pad, with planter boxes and the umbrella stored closed.
        var pad = Model(name: "pergola-pad")
        pad.add(Prim.terrain(size: V2(3.2, 3.2), segments: 16, material: "ground.raked-gravel") { _ in 0.02 })
        scene.add(pad, at: at(pergolaC.x, pergolaC.y))
        scene.add(Pergola(), at: at(pergolaC.x, pergolaC.y, lift: 0.02), seed: seed &+ 20)
        scene.add(AdirondackChair(), at: at(pergolaC.x - 0.5, pergolaC.y + 0.3, yaw: 160, lift: 0.02), seed: seed &+ 21)
        scene.add(AdirondackChair(), at: at(pergolaC.x + 0.6, pergolaC.y + 0.2, yaw: 205, lift: 0.02), seed: seed &+ 22)
        scene.add(CedarPlanterBox(), at: at(pergolaC.x, pergolaC.y - 1.25, lift: 0.02), seed: seed &+ 23)
        scene.add(HydrangeaBush().with { $0.width = 0.6; $0.height = 0.55 }, at: at(pergolaC.x, pergolaC.y - 1.25, lift: 0.42), seed: seed &+ 24)
        scene.add(PatioUmbrella(), at: at(pergolaC.x + 1.35, pergolaC.y - 1.3, lift: 0.02), seed: seed &+ 25, state: "closed")
        scene.add(GardenTrellis(), at: at(pergolaC.x - 1.45, pergolaC.y - 1.45, yaw: 90, lift: 0.02), seed: seed &+ 26)

        // Retaining wall across the back; raised mulch bed with boxwoods and hydrangeas behind it.
        let wallLen: Float = 1.2
        var x = yx.lowerBound + wallLen / 2
        var k: UInt64 = 0
        while x < yx.upperBound {
            scene.add(RetainingWallBlock(), at: at(x, wallZ), seed: seed &+ 30 &+ k)
            x += wallLen; k += 1
        }
        let raised: Float = 0.5
        var bedFill = Model(name: "raised-bed")
        bedFill.add(Prim.roundedBox(V3(yx.upperBound - yx.lowerBound, raised, 1.6), radius: 0.02, bevelSegments: 1, material: "mulch.bark"),
                    Xform(translation: V3(0, raised / 2 - 0.02, wallZ - 1.0)))
        scene.add(bedFill)
        var shrubs: [simd_float4x4] = [], hyd: [simd_float4x4] = []
        var sx = yx.lowerBound + 0.6
        while sx < yx.upperBound - 0.4 {
            let p = V2(sx + rng.float(-0.15...0.15), wallZ - 0.75 + rng.float(-0.15...0.15))
            let m = place(p.x, p.y, y: y(p) + raised - 0.04, yaw: rng.float(0...360), scale: rng.float(0.85...1.1)).matrix
            if Int((sx - yx.lowerBound) / 1.1) % 3 == 1 { hyd.append(m) } else { shrubs.append(m) }
            sx += 1.1
        }
        scene.field(BoxwoodShrub(), seed: seed &+ 40, transforms: shrubs, options: .trees)
        scene.field(HydrangeaBush(), seed: seed &+ 41, transforms: hyd, options: .trees)

        // Lawn beds: mulch with shrubs, a Japanese maple uplit by a spotlight.
        for (i, b) in beds.enumerated() {
            scene.add(MulchBed().with { $0.radius = b.r; $0.shape = b.shape }, at: at(b.c.x, b.c.y, yaw: b.yaw), seed: seed &+ 50 &+ UInt64(i))
        }
        let left = beds[0].c, right = beds[1].c, back = beds[2].c
        scene.add(HydrangeaBush(), at: at(left.x + 0.1, left.y - 0.4, lift: 0.04), seed: seed &+ 60)
        scene.add(BoxwoodShrub(), at: at(left.x - 0.1, left.y + 0.65, lift: 0.04), seed: seed &+ 61)
        scene.add(BoxwoodShrub().with { $0.width = 0.7; $0.height = 0.55 }, at: at(right.x, right.y + 0.5, lift: 0.04), seed: seed &+ 62)
        scene.add(HydrangeaBush(), at: at(right.x - 0.05, right.y - 0.45, lift: 0.04), seed: seed &+ 63)
        scene.add(JapaneseMaple().with { $0.height = 3.2 }, at: at(back.x, back.y, lift: 0.0), seed: seed &+ 64)
        scene.add(LandscapeSpotlight(), at: at(back.x + 0.55, back.y + 0.6, yaw: face(V2(back.x + 0.55, back.y + 0.6), back), lift: 0.04), seed: seed &+ 65, state: "on")

        // Path lights along the lawn edge from the house to the patio and along the side beds.
        let lights: [V2] = [V2(-1.0, -0.6), V2(-1.1, -2.2), V2(-1.2, -6.4), V2(-5.0, -3.0), V2(4.8, -1.0), V2(5.1, -3.4), V2(1.6, -3.9)]
        for (i, p) in lights.enumerated() {
            scene.add(PathLight(), at: at(p.x, p.y), seed: seed &+ 70 &+ UInt64(i), state: "on")
        }

        // Lawn ornaments and garden kit.
        scene.add(Birdbath(), at: at(1.9, -2.6, yaw: rng.float(0...360)), seed: seed &+ 80)
        scene.add(LawnSprinkler(), at: at(3.6, -1.5, yaw: 25), seed: seed &+ 81)
        scene.add(HoseReel(), at: at(6.4, -0.6, yaw: -100), seed: seed &+ 82)
        scene.add(Wheelbarrow(), at: at(6.2, -7.6, yaw: -60), seed: seed &+ 83)

        // Mown grass clumps on the lawn.
        let blades = Scatter.uniform(count: 9000, outerRadius: 9, seed: seed &+ 90) { p in
            let q = V2(p.x, p.y - 5)
            return yx.contains(q.x) && yz.contains(q.y) && !covered(q)
        }.map { V2($0.x, $0.y - 5) }
        scene.field(GrassClump().with { $0.height = 0.09; $0.width = 0.32; $0.material = "grass.lawn-card" }, seed: seed &+ 91, transforms: blades.map {
            place($0.x, $0.y, y: y($0) + 0.005, yaw: rng.float(0...360), scale: rng.float(0.8...1.2)).matrix
        }, options: .groundCover(cull: 26))

        // Trees beyond the yard.
        let treeSpots = Scatter.poisson(count: 14, outerRadius: 26, innerRadius: 11, minSpacing: 6.5, seed: seed &+ 100) { $0.y < -11 || abs($0.x) > 9.5 }
        var oaks: [simd_float4x4] = [], maples: [simd_float4x4] = []
        for p in treeSpots {
            let m = place(p.x, p.y, y: y(p) - 0.1, yaw: rng.float(0...360), scale: rng.float(0.85...1.1)).matrix
            if rng.chance(0.5) { oaks.append(m) } else { maples.append(m) }
        }
        scene.field(OakTree(), seed: seed &+ 101, transforms: oaks, options: .trees)
        scene.field(MapleTree(), seed: seed &+ 102, transforms: maples, options: .trees)

        let eye = V2(0.8, -0.2)
        scene.camera = .init(eye: V3(eye.x, y(eye) + 1.65, eye.y), target: V3(-0.8, 0.7, -5.5), fov: 62)
        return scene
    }
}
