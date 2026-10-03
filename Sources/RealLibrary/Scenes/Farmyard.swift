import simd
import Foundation
import RealityKit
import RealKit

/// Small farm: a red board-and-batten barn (12 x 8 m, 3 m eaves, 6 m ridge, galvanized standing-seam
/// roof) with a bare dirt yard in front, a 12 x 12 m split-rail paddock with a stock tank, hay bales,
/// milk cans, feed sacks, a wheelbarrow and an old tractor tire. Tall grass and wildflowers grow past the
/// yard; oaks and maples stand behind. The camera stands at the yard edge looking at the barn corner.
public struct Farmyard: RealSceneBuilder {
    public static let id = "farmyard"
    public static let summary = "Red barn corner with dirt yard, split-rail paddock, hay bales, trough, milk cans, tall grass and wildflower fields, oaks behind."
    public static let tags = ["farm", "outdoor"]
    public static let author = "hunter"

    /// Barn footprint (x range, z range) and paddock rectangle.
    public var barnX: ClosedRange<Float> = -12 ... 0
    public var barnZ: ClosedRange<Float> = -16 ... -8
    public var paddockMin = V2(3, -14)
    public var paddockMax = V2(15, -2)
    public init() {}

    /// Gable triangle above a side wall, in that wall's local frame (boards face +Z, width 8 m).
    static func gable(width: Float, eave: Float, rise: Float, seed: UInt64) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: "gable")
        let W = width / 2, bw: Float = 0.24, bt: Float = 0.022
        let n = Int((width / bw).rounded()), pitch = width / Float(n)
        for i in 0..<n {
            let x = -W + pitch * (Float(i) + 0.5)
            let top = eave + rise * (1 - (abs(x) + pitch / 2) / W) - 0.02
            guard top > eave + 0.05 else { continue }
            var s = Prim.roundedBox(V3(top - eave + 0.06, bt, pitch - 0.006), radius: 0.004, bevelSegments: 1, material: "wood.barn-red")
            let h = UInt32(truncatingIfNeeded: i &* 7919 &+ 13)
            s.uvs = s.uvs.map { $0 + V2(Float(h % 97) / 97 * 3.1, Float(h % 89) / 89 * 1.7) }
            m.add(s, Xform(translation: V3(x, (eave - 0.06 + top) / 2, bt / 2),
                           rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1)) * simd_quatf(degrees: 90, axis: V3(1, 0, 0))).jittered(&rng, deg: 0.15, offset: 0.001))
        }
        // Battens over the joints.
        for i in 1..<n {
            let x = -W + pitch * Float(i)
            let top = eave + rise * (1 - abs(x) / W) - 0.08
            guard top > eave + 0.1 else { continue }
            m.add(Prim.roundedBox(V3(top - eave, 0.019, 0.06), radius: 0.003, bevelSegments: 1, material: "wood.barn-red"),
                  Xform(translation: V3(x, (eave + top) / 2, bt + 0.0095), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1)) * simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        return m
    }

    /// Gable roof over the barn: two galvanized slabs with standing seams, ridge cap, white fascia.
    func roof() -> Model {
        var m = Model(name: "barn-roof")
        let zc = (barnZ.lowerBound + barnZ.upperBound) / 2, half = (barnZ.upperBound - barnZ.lowerBound) / 2
        let eave: Float = 3.0, rise: Float = 3.0, over: Float = 0.45, th: Float = 0.04
        let slope = (half * half + rise * rise).squareRoot(), len = slope + over
        let ang = atan2(rise, half) * 180 / .pi
        let xLen = barnX.upperBound - barnX.lowerBound + 0.8, xc = (barnX.lowerBound + barnX.upperBound) / 2
        let ridge = V3(xc, eave + rise + 0.03, zc)
        for side: Float in [1, -1] {
            let dir = V3(0, -rise / slope, side * half / slope)
            let nrm = V3(0, half / slope, side * rise / slope)
            let rot = simd_quatf(degrees: side * ang, axis: V3(1, 0, 0))
            let c = ridge + dir * (len / 2) + nrm * (th / 2)
            m.add(Prim.roundedBox(V3(xLen, th, len), radius: 0.008, bevelSegments: 1, material: "metal.galvanized-aged"), Xform(translation: c, rotation: rot))
            var seams = Surface(material: "metal.galvanized-aged")
            var x = -xLen / 2 + 0.3
            while x < xLen / 2 - 0.1 {
                seams.append(Prim.roundedBox(V3(0.022, 0.035, len), radius: 0.006, bevelSegments: 1, material: "metal.galvanized-aged"),
                             Xform(translation: c + nrm * (th / 2 + 0.0175) + V3(x, 0, 0), rotation: rot))
                x += 0.5
            }
            m.add(seams)
            let edge = ridge + dir * len
            m.add(Prim.roundedBox(V3(xLen, 0.2, 0.03), radius: 0.004, bevelSegments: 1, material: "wood.barn-white"),
                  Xform(translation: edge + V3(0, -0.06, side * 0.015)))
            // Rake boards along the gable edges.
            for gx in [barnX.lowerBound - 0.4, barnX.upperBound + 0.4] {
                m.add(Prim.roundedBox(V3(0.03, 0.2, len), radius: 0.004, bevelSegments: 1, material: "wood.barn-white"),
                      Xform(translation: V3(gx + (gx > xc ? 0.015 : -0.015), c.y - 0.06, c.z), rotation: rot))
            }
        }
        m.add(Prim.roundedBox(V3(xLen + 0.02, 0.06, 0.36), radius: 0.02, bevelSegments: 2, material: "metal.galvanized-aged"),
              Xform(translation: ridge + V3(0, 0.07, 0)))
        return m
    }

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 99)
        let ground = GroundPatch().with { $0.size = 90; $0.segments = 200; $0.relief = 0.45; $0.flatCenter = 20; $0.material = "ground.yard" }
        func y(_ p: V2) -> Float { ground.height(x: p.x, z: p.y, seed: seed) }
        func yv(_ x: Float, _ z: Float) -> Float { y(V2(x, z)) }

        // Bare dirt: the yard in front of the barn, a track to the paddock gate, trampled paddock.
        let pMin = paddockMin, pMax = paddockMax
        func boxDist(_ x: Float, _ z: Float, _ a: V2, _ b: V2) -> Float { max(max(a.x - x, x - b.x), max(a.y - z, z - b.y)) }
        func wear(_ x: Float, _ z: Float) -> Float {
            let n = Noise.fbm(V3(x * 0.7, 4, z * 0.7), octaves: 3, seed: 17) * 0.9
            let yard = boxDist(x, z, V2(barnX.lowerBound - 2, barnZ.upperBound - 0.5), V2(barnX.upperBound + 1.5, 3.5)) + n
            let track = boxDist(x, z, V2(barnX.upperBound, -3.0), V2(9.5, 1.0)) + n * 0.8
            let barn = boxDist(x, z, V2(barnX.lowerBound - 0.6, barnZ.lowerBound - 0.6), V2(barnX.upperBound + 0.8, barnZ.upperBound))
            let bare = 1 - smoothstep(-0.6, 0.4, min(min(yard, track), barn))
            // Farm lane toward the camera: two wheel ruts with a grass strip between.
            let lc = 6.6 + 0.6 * sin(z * 0.09), lr = abs(abs(x - lc) - 0.8) + n * 0.25
            let lane = (1 - smoothstep(0.18, 0.45, lr)) * smoothstep(-1.5, 0.5, z)
            let pad = boxDist(x, z, pMin, pMax)
            let trampled = (1 - smoothstep(-0.3, 0.3, pad)) * (0.15 + 0.75 * smoothstep(0.0, 0.5, Noise.fbm(V3(x * 0.35, 9, z * 0.35), octaves: 3, seed: 23)))
            return max(max(bare, trampled), lane)
        }
        var groundModel = ground.build(seed: seed).levels[0]
        for i in groundModel.surfaces.indices { groundModel.surfaces[i].paintSplat { wear($0.x, $0.z) } }
        scene.add(groundModel)

        // Barn: board-and-batten walls on all four sides, gables, corner boards, roof.
        let bx0 = barnX.lowerBound, bx1 = barnX.upperBound, bz0 = barnZ.lowerBound, bz1 = barnZ.upperBound
        let sec: Float = 4
        let nx = Int(((bx1 - bx0) / sec).rounded()), nz = Int(((bz1 - bz0) / sec).rounded())
        for i in 0..<nx {
            let x = bx0 + sec * (Float(i) + 0.5)
            scene.add(BarnWall().with { $0.door = i == nx / 2 }, at: place(x, bz1, y: yv(x, bz1)), seed: seed &+ 10 &+ UInt64(i))
            scene.add(BarnWall().with { $0.door = false }, at: place(x, bz0, y: yv(x, bz0), yaw: 180), seed: seed &+ 20 &+ UInt64(i))
        }
        for i in 0..<nz {
            let z = bz1 - sec * (Float(i) + 0.5)
            scene.add(BarnWall().with { $0.door = i == 0 }, at: place(bx1, z, y: yv(bx1, z), yaw: 90), seed: seed &+ 30 &+ UInt64(i))
            scene.add(BarnWall().with { $0.door = false }, at: place(bx0, z, y: yv(bx0, z), yaw: -90), seed: seed &+ 40 &+ UInt64(i))
        }
        let zc = (bz0 + bz1) / 2
        scene.add(Self.gable(width: bz1 - bz0, eave: 3, rise: 3, seed: seed &+ 50), at: place(bx1, zc, y: yv(bx1, zc), yaw: 90))
        scene.add(Self.gable(width: bz1 - bz0, eave: 3, rise: 3, seed: seed &+ 51), at: place(bx0, zc, y: yv(bx0, zc), yaw: -90))
        var corners = Model(name: "corner-boards")
        for (cx, cz) in [(bx1, bz1), (bx0, bz1), (bx1, bz0), (bx0, bz0)] {
            let sx: Float = cx > bx0 ? 1 : -1, sz: Float = cz > bz0 ? 1 : -1
            corners.add(Prim.roundedBox(V3(0.16, 3.0, 0.025), radius: 0.004, bevelSegments: 1, material: "wood.barn-white"),
                        Xform(translation: V3(cx - sx * 0.055, 1.5, cz + sz * 0.0525)))
            corners.add(Prim.roundedBox(V3(0.025, 3.0, 0.16), radius: 0.004, bevelSegments: 1, material: "wood.barn-white"),
                        Xform(translation: V3(cx + sx * 0.0525, 1.5, cz - sz * 0.055)))
        }
        scene.add(corners)
        scene.add(roof(), at: place(0, 0, y: yv(bx1, bz1)))

        // Paddock: a closed loop of rail-fence runs, each section bringing its -X post. The front run has a
        // gate gap; the section before the gap closes with its end post.
        func run(from a: V2, count: Int, yaw: Float, skip: Int? = nil, seedBase: UInt64) {
            let dir = V2(cos(yaw * .pi / 180), -sin(yaw * .pi / 180))
            for i in 0..<count where i != skip {
                let c = a + dir * (3 * (Float(i) + 0.5))
                let f = RailFence().with { $0.endPost = skip.map { i == $0 - 1 } ?? false }
                scene.add(f, at: place(c.x, c.y, y: yv(c.x, c.y), yaw: yaw), seed: seed &+ seedBase &+ UInt64(i))
            }
        }
        run(from: V2(pMin.x, pMax.y), count: 4, yaw: 0, skip: 1, seedBase: 100)   // front, gate in section 1
        run(from: V2(pMax.x, pMax.y), count: 4, yaw: 90, seedBase: 110)           // right, toward the back
        run(from: V2(pMax.x, pMin.y), count: 4, yaw: 180, seedBase: 120)          // back, toward -X
        run(from: V2(pMin.x, pMin.y), count: 4, yaw: -90, seedBase: 130)         // left, toward the front

        // Props.
        func one<A: RealAsset>(_ a: A, _ x: Float, _ z: Float, yaw: Float, s: UInt64, dy: Float = 0) {
            scene.add(a, at: place(x, z, y: yv(x, z) + dy, yaw: yaw), seed: seed &+ s)
        }
        one(WaterTrough(), 7.8, -3.4, yaw: 6, s: 200)
        one(MudPatch().with { $0.radius = 2.2 }, 7.6, -4.2, yaw: 40, s: 201)
        one(MudPatch().with { $0.radius = 1.8 }, 7.6, -0.6, yaw: 110, s: 202)
        one(Puddle().with { $0.radius = 0.7 }, -4.6, -4.4, yaw: 30, s: 203)
        one(Puddle().with { $0.radius = 0.5 }, 1.6, -1.2, yaw: 120, s: 204)
        // Hay: round bales along the paddock side and by the barn corner, a stack of small squares by the wall.
        one(RoundHayBale(), 17.2, -5.5, yaw: 84, s: 210)
        one(RoundHayBale(), 17.4, -7.3, yaw: 95, s: 211)
        one(RoundHayBale(), 2.5, -15.0, yaw: 8, s: 212)
        one(RoundHayBale(), 12.5, -11.2, yaw: 40, s: 213)
        var hr = rng.fork(220)
        for layer in 0..<3 { for k in 0..<(3 - layer) {
            let bx = -10.6 + Float(k) * 0.92 + Float(layer) * 0.46 + hr.float(-0.03...0.03)
            one(SquareHayBale(), bx, -7.2 + hr.float(-0.03...0.03), yaw: hr.float(-3...3), s: 220 &+ UInt64(layer * 4 + k), dy: Float(layer) * 0.36)
        }}
        one(SquareHayBale(), -8.4, -6.5, yaw: 70, s: 230)
        // By the door: milk cans and feed sacks.
        one(MilkCan(), -4.05, -7.55, yaw: 20, s: 240)
        one(MilkCan(), -3.7, -7.6, yaw: 140, s: 241)
        one(MilkCan(), -3.9, -7.25, yaw: 260, s: 242)
        one(FeedSack(), -8.1, -7.55, yaw: 15, s: 243)
        one(FeedSack(), -7.6, -7.5, yaw: -20, s: 244)
        one(FeedSack().with { $0.height = 0.62 }, -7.85, -7.15, yaw: 80, s: 245)
        one(Wheelbarrow(), -1.6, -4.6, yaw: 215, s: 250)
        one(TractorTire(), -6.8, -2.6, yaw: 0, s: 251)
        one(TractorTire().with { $0.upright = true }, 0.6, -13.0, yaw: 90, s: 252)

        // Fields: tall grass and wildflowers off the dirt, short grass where it thins near the yard.
        let barnPad = (V2(bx0 - 0.5, bz0 - 0.5), V2(bx1 + 0.5, bz1 + 0.3))
        let field = Scatter.uniform(count: 18000, outerRadius: 30, seed: seed &+ 300) { p in
            if boxDist(p.x, p.y, barnPad.0, barnPad.1) < 0 { return false }
            return wear(p.x, p.y) < 0.12
        }
        var tall: [[simd_float4x4]] = [[], []], flowers: [simd_float4x4] = []
        for p in field {
            let m = place(p.x, p.y, y: y(p) - 0.02, yaw: rng.float(0...360), scale: rng.float(0.75...1.25)).matrix
            if Noise.fbm(V3(p.x * 0.18, 1, p.y * 0.18), octaves: 2, seed: 41) > 0.3 && rng.chance(0.3) { flowers.append(m) }
            else if rng.chance(0.015) { flowers.append(m) }
            else { tall[rng.chance(0.5) ? 0 : 1].append(m) }
        }
        for j in 0..<2 {
            scene.field(TallGrass().with { $0.height = j == 0 ? 0.6 : 0.75 }, seed: seed &+ 310 &+ UInt64(j), transforms: tall[j], options: .groundCover(cull: 32))
        }
        scene.field(MeadowFlowers(), seed: seed &+ 312, transforms: flowers, options: .groundCover(cull: 32))
        // Short grass under the tall grass and thinning out onto the dirt.
        let short = Scatter.uniform(count: 40000, outerRadius: 28, seed: seed &+ 320) { p in
            if boxDist(p.x, p.y, barnPad.0, barnPad.1) < 0.3 { return false }
            return wear(p.x, p.y) < 0.5
        }
        scene.field(GrassClump().with { $0.height = 0.28; $0.width = 0.35 }, seed: seed &+ 321, transforms: short.map {
            place($0.x, $0.y, y: y($0) - 0.02, yaw: rng.float(0...360), scale: rng.float(0.6...1.1)).matrix
        }, options: .groundCover(cull: 30))

        // Shade trees behind the barn and along the far field.
        let treeSpots = Scatter.poisson(count: 16, outerRadius: 40, innerRadius: 20, minSpacing: 9, seed: seed &+ 400) { $0.y < -20 || ($0.x < -22 && $0.y < 0) }
        var oaks: [simd_float4x4] = [], maples: [simd_float4x4] = []
        for p in treeSpots {
            let m = place(p.x, p.y, y: y(p) - 0.1, yaw: rng.float(0...360), scale: rng.float(0.85...1.15)).matrix
            if rng.chance(0.55) { oaks.append(m) } else { maples.append(m) }
        }
        scene.field(OakTree(), seed: seed &+ 401, transforms: oaks, options: .trees)
        scene.field(MapleTree(), seed: seed &+ 402, transforms: maples, options: .trees)

        let eye = V2(7.0, 8.5)
        scene.camera = .init(eye: V3(eye.x, yv(eye.x, eye.y) + 1.65, eye.y), target: V3(-2.5, 1.8, -9), fov: 60)
        return scene
    }
}
