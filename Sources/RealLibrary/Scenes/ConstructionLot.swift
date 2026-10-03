import simd
import Foundation
import RealityKit
import RealKit

/// Building site, about 21 x 17.5 m inside a mesh-fence perimeter on bare dirt: a crushed-gravel pad, a
/// two-storey brick shell (12 x 5 m, 5.4 m walls, open window bays) with four scaffold bays on its front,
/// cement mixer, wheelbarrow, sandbags on pallets, rebar, cable reel, dumpster and jersey barriers. The
/// camera stands on the asphalt street in front, where cones and drums close the near lane at the gate.
public struct ConstructionLot: RealSceneBuilder {
    public static let id = "construction-lot"
    public static let summary = "Building site: brick shell with scaffold, gravel pad, mesh fence, mixer, sandbags, rebar, dumpster, cones and drums on the street."
    public static let tags = ["construction", "urban", "street", "outdoor"]
    public static let author = "hunter"

    /// Fence rectangle (inner corners) and the brick shell footprint.
    public var lotMin = V2(-10.5, -13)
    public var lotMax = V2(10.5, 4.5)
    public var shellX: ClosedRange<Float> = -9.5 ... 2.5
    public var shellFront: Float = -7
    public var shellDepth: Float = 5
    public var streetZ: ClosedRange<Float> = 6.5 ... 13.5
    public init() {}

    /// Brick box with world-space UVs so the coursing runs continuously across pieces. `brick.red` tiles
    /// eight 150 mm courses per 0.6 m; UVs at twice world meters give 75 mm courses of 215 mm bricks.
    static func brick(_ size: V3, at c: V3, material: MaterialKey = "brick.red") -> Surface {
        var s = Prim.roundedBox(size, radius: 0.01, bevelSegments: 1, material: material).transformed(Xform(translation: c))
        s.uvs = zip(s.positions, s.normals).map { p, n in
            let a = abs(n)
            if a.z >= a.x && a.z >= a.y { return V2(p.x, p.y) * 2 }
            if a.x >= a.y { return V2(p.z, p.y) * 2 }
            return V2(p.x, p.z) * 2
        }
        s.computeTangents()
        return s
    }

    /// Two-storey brick shell: walls with window openings, concrete lintels and sills, a floor slab,
    /// and an unfinished stepped top course.
    func shell(seed: UInt64) -> Model {
        var rng = SeededRNG(seed: seed &+ 404)
        var m = Model(name: "brick-shell")
        let t: Float = 0.3, x0 = shellX.lowerBound, x1 = shellX.upperBound
        let zf = shellFront, zb = shellFront - shellDepth
        let course: Float = 0.075
        let windowsX: [ClosedRange<Float>] = [(-8.1)...(-6.9), (-5.1)...(-3.9), (-2.1)...(-0.9), 0.9...2.1]
        let floors: [(Float, Float)] = [(0.9, 2.25), (3.6, 4.95)]
        var walls = Surface(material: "brick.red")
        // Front wall: solid bands between window rows, piers between windows.
        let bands: [(Float, Float)] = [(0, 0.9), (2.25, 3.6)]
        for (y0, y1) in bands { walls.append(Self.brick(V3(x1 - x0, y1 - y0, t), at: V3((x0 + x1) / 2, (y0 + y1) / 2, zf - t / 2))) }
        for (y0, y1) in floors {
            var edges: [Float] = [x0]
            for w in windowsX { edges += [w.lowerBound, w.upperBound] }
            edges.append(x1)
            for k in stride(from: 0, to: edges.count, by: 2) {
                let a = edges[k], b = edges[k + 1]
                walls.append(Self.brick(V3(b - a, y1 - y0, t), at: V3((a + b) / 2, (y0 + y1) / 2, zf - t / 2)))
            }
        }
        // Top course: stepped where the bricklayers stopped.
        var x = x0
        while x < x1 - 0.01 {
            let w = min(x1 - x, rng.float(0.9...2.4))
            let top = 4.95 + course * Float(rng.int(0...5))
            walls.append(Self.brick(V3(w, top - 4.95, t), at: V3(x + w / 2, (4.95 + top) / 2, zf - t / 2)))
            x += w
        }
        // Side and back walls (full height, plain).
        let h: Float = 5.25
        for sx in [x0 + t / 2, x1 - t / 2] { walls.append(Self.brick(V3(t, h, shellDepth - t), at: V3(sx, h / 2, (zf + zb) / 2 - t / 2))) }
        walls.append(Self.brick(V3(x1 - x0, h, t), at: V3((x0 + x1) / 2, h / 2, zb + t / 2)))
        walls.bakeCavityAO(strength: 0.4, floor: 0.75)
        m.add(walls)
        // Precast lintels and sills, a footing course and the first floor slab.
        var conc = Surface(material: "concrete.smooth")
        for (y0, y1) in floors { for w in windowsX {
            conc.append(Prim.roundedBox(V3(w.upperBound - w.lowerBound + 0.3, 0.15, t + 0.02), radius: 0.008, bevelSegments: 1, material: "concrete.smooth"),
                        Xform(translation: V3((w.lowerBound + w.upperBound) / 2, y1 + 0.075, zf - t / 2)))
            conc.append(Prim.roundedBox(V3(w.upperBound - w.lowerBound + 0.1, 0.06, t + 0.08), radius: 0.008, bevelSegments: 1, material: "concrete.smooth"),
                        Xform(translation: V3((w.lowerBound + w.upperBound) / 2, y0 + 0.03, zf - t / 2 + 0.04)))
        }}
        conc.append(Prim.roundedBox(V3(x1 - x0 - 2 * t, 0.2, shellDepth - 2 * t), radius: 0.01, bevelSegments: 1, material: "concrete.smooth"),
                    Xform(translation: V3((x0 + x1) / 2, 3.0, (zf + zb) / 2)))
        m.add(conc)
        m.add(Prim.roundedBox(V3(x1 - x0 + 0.1, 0.12, t + 0.1), radius: 0.02, bevelSegments: 1, material: "concrete.rough"),
              Xform(translation: V3((x0 + x1) / 2, 0.03, zf - t / 2)))
        groundAO(&m)
        return m
    }

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 77)
        let ground = GroundPatch().with { $0.size = 80; $0.segments = 192; $0.relief = 0.25; $0.flatCenter = 16; $0.material = "ground.site" }
        func y(_ p: V2) -> Float { ground.height(x: p.x, z: p.y, seed: seed) }
        func yv(_ x: Float, _ z: Float) -> Float { y(V2(x, z)) }

        // Gravel pad inside the fence and through the gate to the street; ragged edges.
        let lot = (lotMin, lotMax)
        func pad(_ x: Float, _ z: Float) -> Float {
            let n = Noise.fbm(V3(x * 0.9, 2, z * 0.9), octaves: 3, seed: 13) * 0.6
            let dx = max(lot.0.x - 0.4 - x, x - lot.1.x - 0.4), dz = max(lot.0.y - 0.4 - z, z - lot.1.y - 0.2)
            let inLot = max(dx, dz)
            let gate = max(abs(x) - 3.4, max(z - streetZ.lowerBound, lot.1.y - z))
            let d = min(inLot, gate) + n
            // Bare dirt worn into the pad near the shell and along tire paths.
            let worn = smoothstep(0.25, 0.5, Noise.fbm(V3(x * 0.25, 7, z * 0.25), octaves: 3, seed: 29)) * 0.7
            return (1 - smoothstep(-0.3, 0.3, d)) * (1 - worn)
        }
        var groundModel = ground.build(seed: seed).levels[0]
        for i in groundModel.surfaces.indices { groundModel.surfaces[i].paintSplat { pad($0.x, $0.z) } }
        scene.add(groundModel)
        scene.farGround = "ground.dirt"

        // Street: asphalt carriageway with a concrete curb on the lot side.
        let sz0 = streetZ.lowerBound, sz1 = streetZ.upperBound, sLen: Float = 76
        var street = Model(name: "street")
        let zc = (sz0 + sz1) / 2, hw = (sz1 - sz0) / 2
        func road(_ x: Float, _ z: Float) -> Float { yv(x, z) + 0.03 + 0.04 * (1 - pow((z - zc) / hw, 2)) }
        var asphalt = Prim.terrain(size: V2(sLen, sz1 - sz0), segments: 96, material: "asphalt") { p in road(p.x, p.y + zc) }
        asphalt.uvs = asphalt.uvs.map { $0 * 1.6 }   // finer aggregate: about 1 cm stones at the curb
        asphalt.computeTangents()
        street.add(asphalt, Xform(translation: V3(0, 0, zc)))
        // Road paint: dashed yellow center line, solid white edge lines, slightly worn.
        var dx: Float = -sLen / 2 + 1
        while dx < sLen / 2 - 3 {
            street.add(Prim.roundedBox(V3(3, 0.004, 0.11), radius: 0.001, bevelSegments: 1, material: "concrete.smooth:D9A520"),
                       Xform(translation: V3(dx + 1.5, road(dx + 1.5, zc) + 0.001, zc)))
            dx += 9
        }
        for ez in [sz0 + 0.45, sz1 - 0.45] {
            let segs = 38
            var line = Surface(material: "concrete.smooth:E6E3DA")
            for i in 0..<segs {
                let x0 = -sLen / 2 + Float(i) * sLen / Float(segs)
                line.append(Prim.roundedBox(V3(sLen / Float(segs) - 0.02, 0.004, 0.12), radius: 0.001, bevelSegments: 1, material: "concrete.smooth:E6E3DA"),
                            Xform(translation: V3(x0 + sLen / Float(segs) / 2, road(x0 + sLen / Float(segs) / 2, ez) + 0.001, ez)))
            }
            street.add(line)
        }
        street.add(Prim.roundedBox(V3(sLen, 0.15, 0.18), radius: 0.02, bevelSegments: 2, material: "concrete.smooth"),
                   Xform(translation: V3(0, 0.06, sz0 - 0.05)))
        // Far-side curb and sidewalk slabs (1.5 m flags with joints).
        street.add(Prim.roundedBox(V3(sLen, 0.15, 0.18), radius: 0.02, bevelSegments: 2, material: "concrete.smooth"),
                   Xform(translation: V3(0, 0.06, sz1 + 0.05)))
        var fx: Float = -sLen / 2
        while fx < sLen / 2 {
            street.add(Prim.roundedBox(V3(1.49, 0.1, 1.9), radius: 0.008, bevelSegments: 1, material: "concrete.smooth"),
                       Xform(translation: V3(fx + 0.75, yv(fx + 0.75, sz1 + 1.1) + 0.04, sz1 + 1.1), rotation: simd_quatf(degrees: rng.float(-0.3...0.3), axis: V3(1, 0, 0))))
            fx += 1.5
        }
        scene.add(street)

        // Fence perimeter: runs along X, last panel of each run keeps its trailing foot.
        let panel: Float = 3.5
        func run(from a: V2, count: Int, yaw: Float, seedBase: UInt64) {
            let dir = V2(cos(yaw * .pi / 180), -sin(yaw * .pi / 180))
            for i in 0..<count {
                let c = a + dir * (panel * (Float(i) + 0.5))
                let f = ConstructionFence().with { $0.trailingFoot = i == count - 1 }
                scene.add(f, at: place(c.x, c.y, y: yv(c.x, c.y), yaw: yaw), seed: seed &+ seedBase &+ UInt64(i))
            }
        }
        run(from: V2(lotMin.x, lotMax.y), count: 2, yaw: 0, seedBase: 100)            // front left of the gate
        run(from: V2(lotMax.x - 2 * panel, lotMax.y), count: 2, yaw: 0, seedBase: 110) // front right
        run(from: V2(lotMin.x, lotMin.y), count: 6, yaw: 0, seedBase: 120)             // back
        run(from: V2(lotMin.x - 0.25, lotMax.y - 0.2), count: 5, yaw: 90, seedBase: 130) // left side, front to back
        run(from: V2(lotMax.x + 0.25, lotMax.y - 0.2), count: 5, yaw: 90, seedBase: 140) // right side

        // Brick shell with scaffold bays along its front.
        scene.add(shell(seed: seed))
        let bayZ = shellFront + 0.12 + 0.65
        for (i, bx) in ([-8.0, -6.0, -4.0, -2.0] as [Float]).enumerated() {
            scene.add(ScaffoldBay(), at: place(bx, bayZ, y: yv(bx, bayZ)), seed: seed &+ 200 &+ UInt64(i))
        }

        // Site props.
        func one<A: RealAsset>(_ a: A, _ x: Float, _ z: Float, yaw: Float, s: UInt64, dy: Float = 0) {
            scene.add(a, at: place(x, z, y: yv(x, z) + dy, yaw: yaw), seed: seed &+ s)
        }
        one(CementMixer(), 0.6, -4.3, yaw: 205, s: 300)
        one(Wheelbarrow(), -0.9, -3.0, yaw: 130, s: 301)
        one(Pallet(), 5.2, -6.2, yaw: 4, s: 302)
        one(Sandbag().with { $0.courses = 3; $0.perCourse = 4 }, 5.2, -6.2, yaw: 4, s: 303, dy: 0.144)
        one(Pallet(), 6.7, -4.6, yaw: 88, s: 304)
        one(Sandbag().with { $0.courses = 2; $0.perCourse = 4 }, 6.7, -4.6, yaw: 88, s: 305, dy: 0.144)
        for k in 0..<3 { one(Pallet(), 8.6, -8.4, yaw: 91 + Float(k) * 3, s: 306 &+ UInt64(k), dy: Float(k) * 0.144) }
        one(Sandbag(), 4.1, -4.9, yaw: 63, s: 309)
        one(RebarBundle(), 5.8, -1.2, yaw: 78, s: 310)
        one(RebarBundle().with { $0.length = 2.4 }, 7.0, -1.0, yaw: 82, s: 311)
        one(CableSpool(), -6.2, -2.0, yaw: 30, s: 312)
        one(Dumpster(), 7.4, -11.4, yaw: 180, s: 313)
        one(Sawhorse(), 2.8, -2.2, yaw: 15, s: 314)
        one(OilDrum(), 9.4, -6.2, yaw: 40, s: 315)
        one(OilDrum(), 9.5, -5.5, yaw: 200, s: 316)
        // Jersey barriers inside the gate, splayed to channel trucks.
        one(JerseyBarrier(), -5.4, 3.0, yaw: 8, s: 320)
        one(JerseyBarrier(), 5.3, 3.1, yaw: -6, s: 321)
        one(JerseyBarrier(), -8.6, 2.9, yaw: 1, s: 322)

        // Lane closure on the street: cones along the lane line, drums at the taper and the gate.
        let laneZ = sz0 + 2.6
        var x: Float = -14
        var k: UInt64 = 0
        while x <= 14 {
            let dz: Float = x < -9 ? (x + 14) / 5 * 2.2 - 2.2 : 0   // taper toward the curb
            let jitter = V2(rng.float(-0.08...0.08), rng.float(-0.08...0.08))
            let p = V2(x, laneZ + dz) + jitter
            if abs(x) > 8.5 { one(TrafficBarrel(), p.x, p.y, yaw: rng.float(0...360), s: 400 &+ k, dy: 0.05) }
            else { one(TrafficCone(), p.x, p.y, yaw: rng.float(0...360), s: 400 &+ k, dy: 0.05) }
            x += 2.4; k += 1
        }
        one(TrafficCone(), -3.2, sz0 + 0.5, yaw: 60, s: 450, dy: 0.05)
        one(TrafficBarrel(), 3.8, sz0 + 0.6, yaw: 10, s: 451, dy: 0.05)

        // Rain puddles in the ruts.
        one(Puddle().with { $0.radius = 0.8 }, -1.6, 1.4, yaw: 20, s: 500)
        one(Puddle().with { $0.radius = 1.0 }, 3.2, -2.9, yaw: 140, s: 502)

        // Lumber pile: sawn 2x8 boards laid flat in eight layers on three bearers.
        var lumber = Model(name: "lumber")
        for bz: Float in [-1.6, 0, 1.6] { lumber.add(plank(1.1, 0.09, 0.09, material: "wood.weathered"), Xform(translation: V3(0, 0.045, bz))) }
        var lr = rng.fork(800)
        for layer in 0..<8 { for k in 0..<5 {
            if layer == 7 && k > 2 { continue }
            let len = lr.float(3.6...4.2)
            lumber.add(plank(len, 0.195, 0.045, material: "wood.pine"),
                       Xform(translation: V3(Float(k) * 0.2 - 0.4, 0.09 + 0.0225 + Float(layer) * 0.046, lr.float(-0.15...0.15)), rotation: simd_quatf(degrees: 90, axis: .up)).jittered(&lr, deg: 0.25, offset: 0.0008))
        }}
        groundAO(&lumber)
        scene.add(lumber, at: place(-4.2, -3.6, y: yv(-4.2, -3.6), yaw: 72))

        // Dry grass along the fence lines and on the open ground beyond the lot.
        func fenceDist(_ p: V2) -> Float {
            let dx = min(abs(p.x - lotMin.x), abs(p.x - lotMax.x)), dz = min(abs(p.y - lotMin.y), abs(p.y - lotMax.y))
            let onX = p.x > lotMin.x - 1 && p.x < lotMax.x + 1, onZ = p.y > lotMin.y - 1 && p.y < lotMax.y + 1
            return min(onZ ? dx : 99, onX ? dz : 99)
        }
        let grassSpots = Scatter.uniform(count: 13000, outerRadius: 32, seed: seed &+ 600) { p in
            if p.y > sz0 - 0.4 && p.y < sz1 + 0.3 { return false }
            if abs(p.x) < 3.6 && p.y > lotMax.y - 1 { return false }
            let inside = p.x > lotMin.x && p.x < lotMax.x && p.y > lotMin.y && p.y < lotMax.y
            if inside { return fenceDist(p) < 0.5 && pad(p.x, p.y) < 0.6 }
            return fenceDist(p) < 0.9 || Noise.fbm(V3(p.x * 0.2, 5, p.y * 0.2), octaves: 3, seed: 61) > -0.1
        }
        let half = grassSpots.count / 2
        for (j, chunk) in [Array(grassSpots[..<half]), Array(grassSpots[half...])].enumerated() {
            scene.field(DryGrass().with { $0.height = j == 0 ? 0.4 : 0.55 }, seed: seed &+ 610 &+ UInt64(j), transforms: chunk.map {
                place($0.x, $0.y, y: y($0) - 0.02, yaw: rng.float(0...360), scale: rng.float(0.7...1.25)).matrix
            }, options: .groundCover(cull: 30))
        }

        // Trees on the neighboring plots.
        let treeSpots = Scatter.poisson(count: 18, outerRadius: 38, innerRadius: 18, minSpacing: 7, seed: seed &+ 700) { $0.y < -15 || abs($0.x) > 18 && $0.y < 3 }
        var oaks: [simd_float4x4] = [], birches: [simd_float4x4] = []
        for p in treeSpots {
            let mtx = place(p.x, p.y, y: y(p) - 0.1, yaw: rng.float(0...360), scale: rng.float(0.85...1.15)).matrix
            if rng.chance(0.6) { oaks.append(mtx) } else { birches.append(mtx) }
        }
        scene.field(OakTree(), seed: seed &+ 701, transforms: oaks, options: .trees)
        scene.field(BirchTree(), seed: seed &+ 702, transforms: birches, options: .trees)

        let eye = V2(-4.5, sz1 + 1.2)
        scene.camera = .init(eye: V3(eye.x, yv(eye.x, eye.y) + 0.09 + 1.65, eye.y), target: V3(0.5, 1.2, -6), fov: 60)
        return scene
    }
}
