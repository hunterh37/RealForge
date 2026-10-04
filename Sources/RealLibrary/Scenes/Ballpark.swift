import simd
import Foundation
import RealityKit
import RealKit

/// Regulation ballpark. Home plate at the origin, center field toward -Z. A checkerboard-mowed field
/// with a clay infield and mound, ringed by a padded wall (8 ft in fair ground, 4 ft along the foul
/// lines) with yellow foul poles, a chain-link backstop with hood behind the plate, block dugouts with
/// bat racks down both lines, aluminum bleachers behind the foul walls and the backstop, six light
/// towers, and oaks and maples past the outfield. The camera stands in the right-handed batter's box
/// looking out at the mound.
public struct Ballpark: RealSceneBuilder {
    public static let id = "ballpark"
    public static let summary = "Regulation ballpark: striped turf, clay infield and mound, padded walls, foul poles, backstop, dugouts, bleachers, light towers, trees beyond."
    public static let tags = ["sports", "outdoor", "showcase"]
    public static let author = "hunter"

    /// Field geometry (base paths, wall distances, foul ground).
    public var field = BaseballDiamond()
    /// Bleacher sections per foul side and behind the plate.
    public var bleacherSections = 5
    public var towers = true
    public init() {}

    /// Yaw (degrees) that turns local +Z toward the ground direction d (x, z).
    static func yawFacing(_ d: V2) -> Float { atan2(d.x, d.y) * 180 / .pi }

    /// Transform putting an asset's design origin (`anchor` in mesh coordinates) at p with a yaw.
    static func put(_ anchor: V2, at p: V2, yaw: Float) -> Xform {
        let a = simd_quatf(degrees: yaw, axis: .up).act(V3(anchor.x, 0, anchor.y))
        return place(p.x - a.x, p.y - a.z, yaw: yaw)
    }

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 77)
        let f = field
        let d1 = V2(0.70710678, -0.70710678), d3 = V2(-0.70710678, -0.70710678)
        scene.add(f, at: Self.put(f.anchor(seed: seed), at: .zero, yaw: 0), seed: seed)

        // Ground outside the wall line: worn turf, with concrete walks under the stands.
        scene.farGround = "turf.worn"
        scene.add(Model(name: "outer-turf", surfaces: [Prim.terrain(size: V2(420, 420), segments: 4, material: "turf.worn") { _ in -0.03 }]),
                  at: place(0, -50))

        // Backstop: center section on the plate line, wings running along the foul walls (45 degrees).
        let half = f.foulWidth * 1.41421356 - f.backstopDistance
        let wing: Float = 7
        let backstop = Backstop().with { $0.centerWidth = half * 2; $0.wingWidth = wing; $0.wingAngle = 45 }
        scene.add(backstop, at: Self.put(backstop.anchor(seed: seed &+ 1), at: V2(0, f.backstopDistance), yaw: 0), seed: seed &+ 1)

        // Dugouts on both foul walls between home and the bases, fronts on the wall line.
        let dugoutAlong: Float = 13, dugoutLen: Float = 10
        // 1B side wall: v = -F, points d1 * u + d3 * (-F); field is along +d3. 3B side mirrored.
        func sideWall(_ firstBase: Bool, _ along: Float, out: Float = 0) -> V2 {
            firstBase ? d1 * along + d3 * (-f.foulWidth - out) : d3 * along + d1 * (-f.foulWidth - out)
        }
        for fb in [true, false] {
            let p = sideWall(fb, dugoutAlong), dug = Dugout().with { $0.length = dugoutLen }, ds = seed &+ (fb ? 2 : 3)
            scene.add(dug, at: Self.put(dug.anchor(seed: ds), at: p, yaw: Self.yawFacing(fb ? d3 : d1)), seed: ds)
        }

        // Plate and bags. Bags at first and third sit in fair ground with a corner on the base point.
        scene.add(HomePlate(), at: place(0, -HomePlate.apexOffset, y: 0.004), seed: seed &+ 4)
        let bag: Float = 0.2286
        let b = f.bases
        let bagCenters = [b[0] - d1 * bag + d3 * bag, b[1], b[2] - d3 * bag + d1 * bag]
        for (i, c) in bagCenters.enumerated() {
            scene.add(BaseBag(), at: place(c.x, c.y, y: 0.006, yaw: 45), seed: seed &+ 5 &+ UInt64(i))
        }
        // Gear: bat and helmet by the third-base on-deck circle, a ball bucket at the first-base dugout,
        // a ball on the mound apron.
        scene.add(BaseballBat(), at: place(-11.2, 0.9, y: 0.006, yaw: 62), seed: seed &+ 60)
        scene.add(BaseballBat().with { $0.twoTone = true }, at: place(-12.1, 0.2, y: 0.006, yaw: 20), seed: seed &+ 61)
        scene.add(BattingHelmet(), at: place(-10.6, -0.3, y: 0.006, yaw: 140), seed: seed &+ 62)
        let bucketAt = sideWall(true, dugoutAlong - dugoutLen / 2 - 1.2, out: -1.0)
        scene.add(BallBucket(), at: place(bucketAt.x, bucketAt.y, yaw: 30), seed: seed &+ 63)
        scene.add(Baseball(), at: place(0.9, -16.2, y: 0.03, yaw: 70), seed: seed &+ 64)

        // Wall: 4 m sections along the wall line, except over the backstop and the dugout fronts.
        let line = f.wallLine(samples: 1440)
        var fair: [simd_float4x4] = [], foul: [simd_float4x4] = []
        let wallFair = OutfieldWall(), wallFoul = OutfieldWall().with { $0.height = 1.22 }
        let aFair = wallFair.anchor(seed: seed &+ 10), aFoul = wallFoul.anchor(seed: seed &+ 11)
        var acc: Float = 0
        var last = line[0]
        let sectionLen: Float = 4
        for i in 1...line.count {
            let p = line[i % line.count]
            acc += simd_distance(p, last); last = p
            guard acc >= sectionLen else { continue }
            acc = 0
            // Chord over the last 4 m.
            var j = i, run: Float = 0
            while run < sectionLen, j > 0 { run += simd_distance(line[j % line.count], line[(j - 1) % line.count]); j -= 1 }
            let a = line[j % line.count], b = p, mid = (a + b) / 2
            if mid.y > f.backstopDistance - wing * 0.7071 - 0.5 { continue }
            let u = simd_dot(mid, d1), v = simd_dot(mid, d3)
            let isFoul = u < 0 || v < 0
            if isFoul, abs(max(u, v) - dugoutAlong) < dugoutLen / 2 + 0.2 { continue }
            let dir = simd_normalize(b - a)
            var inward = V2(-dir.y, dir.x)
            if simd_dot(inward, BaseballDiamond.rayCenter - mid) < 0 { inward = -inward }
            let len = simd_distance(a, b)
            let x = Self.put(isFoul ? aFoul : aFair, at: mid, yaw: Self.yawFacing(inward))
            var mtx = x.matrix
            mtx.columns.0 *= len / sectionLen   // stretch along X to close the chord
            if isFoul { foul.append(mtx) } else { fair.append(mtx) }
        }
        scene.field(wallFair, seed: seed &+ 10, transforms: fair, options: .props)
        scene.field(wallFoul, seed: seed &+ 11, transforms: foul, options: .props)

        // Foul poles just behind the wall at the line, screens toward fair ground.
        for (i, pole) in f.foulPoles.enumerated() {
            let along = i == 0 ? d1 : d3
            let back = simd_normalize(pole) * 0.35
            scene.add(FoulPole(), at: place(pole.x + back.x, pole.y + back.y, yaw: atan2(-along.y, along.x) * 180 / .pi), seed: seed &+ 20 &+ UInt64(i))
        }

        // Bleachers: runs behind each foul wall past the dugouts, and two sections behind the backstop.
        var stands: [simd_float4x4] = []
        let aStand = Bleachers().anchor(seed: seed &+ 30)
        let secLen: Float = 7.3
        for fb in [true, false] {
            for k in 0..<bleacherSections {
                let p = sideWall(fb, dugoutAlong + dugoutLen / 2 + 1.5 + secLen * (Float(k) + 0.5), out: 1.6)
                stands.append(Self.put(aStand, at: p, yaw: Self.yawFacing(fb ? d3 : d1)).matrix)
            }
        }
        for sx: Float in [-1, 1] {
            stands.append(Self.put(aStand, at: V2(sx * (secLen / 2 + 0.05), f.backstopDistance + 2.2), yaw: 180).matrix)
        }
        scene.field(Bleachers(), seed: seed &+ 30, transforms: stands, options: .props)

        // Light towers: two behind each foul run, two past the outfield wall in the gaps.
        if towers {
            let target = V2(0, -40)
            var spots: [V2] = []
            for fb in [true, false] {
                spots.append(sideWall(fb, 20, out: 11))
                spots.append(sideWall(fb, 62, out: 9))
            }
            for a: Float in [-28, 28] {
                let r = f.wallDistance(degrees: a) + 10, rad = a * .pi / 180
                spots.append(V2(sin(rad) * r, -cos(rad) * r))
            }
            for (i, s) in spots.enumerated() {
                let d = simd_normalize(target - s)
                scene.add(LightTower(), at: place(s.x, s.y, yaw: atan2(-d.x, -d.y) * 180 / .pi), seed: seed &+ 40 &+ UInt64(i))
            }
        }

        // Trees past the outfield and behind the stands.
        var oaks: [simd_float4x4] = [], maples: [simd_float4x4] = []
        let ring = Scatter.uniform(count: 520, outerRadius: 175, seed: seed &+ 50) { p in
            let q = p + V2(0, -40)
            let foulSide = simd_dot(q, d1) < 0 || simd_dot(q, d3) < 0
            return !f.inside(q, shrink: foulSide ? -26 : -12)
        }
        for (i, p) in ring.enumerated() {
            let x = place(p.x, p.y - 40, y: -0.1, yaw: rng.float(0...360), scale: rng.float(0.85...1.25)).matrix
            if i % 2 == 0 { oaks.append(x) } else { maples.append(x) }
        }
        scene.field(OakTree(), seed: seed &+ 51, transforms: oaks, options: .trees)
        scene.field(MapleTree(), seed: seed &+ 52, transforms: maples, options: .trees)

        // In the right-handed batter's box, looking at the mound.
        scene.camera = .init(eye: V3(-0.95, 1.65, -0.15), target: V3(0, 1.0, -f.rubberDistance), fov: 60)
        return scene
    }
}
