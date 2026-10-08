import simd
import Foundation
import RealKit

/// Named point an app reads from a lineman scene: position on the drive or walk surface (world meters,
/// the shared lineman frame) and heading in degrees of yaw (0 = +Z south, 90 = +X east).
public struct LinemanMarker: Sendable, Hashable {
    public var name: String
    public var position: V3
    public var heading: Float
    public init(_ name: String, _ position: V3, heading: Float = 0) { self.name = name; self.position = position; self.heading = heading }
    /// Unit forward vector on the ground plane.
    public var forward: V3 { V3(sin(heading * .pi / 180), 0, cos(heading * .pi / 180)) }
    /// Scene spot: eye 1.7 m above the marker looking 10 m ahead.
    public var spot: RealScene.Spot { .init(name, eye: position + V3(0, 1.7, 0), target: position + forward * 10 + V3(0, 1.2, 0)) }
}

/// Utility service yard in the shared lineman frame (the south-west corner of `lineman-district`, so
/// the truck drives out of the gate onto the district's west street without any offset): a 36 x 40 m
/// concrete lot inside a chain-link fence with barbed wire and a rolled-open gate, a pre-engineered
/// steel line shop with roll-up bays, pole stacks on cribbing, cable reels, pallets, drums, a conex box,
/// flood light poles and striped truck stalls. Markers are public static data.
public struct LinemanYard: RealSceneBuilder {
    public static let id = "lineman-yard"
    public static let summary = "Utility service yard: concrete lot, chain-link fence and gate, steel line shop, pole stacks, cable reels, truck stalls."
    public static let tags = ["utility", "urban", "outdoor"]
    public static let author = "hunter"
    public init() {}

    // MARK: - Frame (shared with LinemanDistrict)

    /// Fence rectangle (inner corners), world XZ.
    public static let yardMin = V2(-106, 22)
    public static let yardMax = V2(-70, 62)
    /// Gate opening on the east fence (x = yardMax.x), world z range.
    public static let gateZ: ClosedRange<Float> = 39 ... 48
    /// Yard slab top (m).
    public static let slabTop: Float = 0.14

    /// Truck spawn: center of stall 2, facing the gate (east).
    public static let spawn = LinemanMarker("spawn", V3(-91, slabTop, 43.5), heading: 90)
    /// Gate centerline at the fence line, heading out of the yard.
    public static let yardExit = LinemanMarker("yardExit", V3(-70, slabTop, 43.5), heading: 90)
    /// Walk-around and briefing point beside the spawn stall.
    public static let briefing = LinemanMarker("briefing", V3(-91, slabTop, 40.4), heading: 150)
    /// Every yard marker.
    public static let markers: [LinemanMarker] = [spawn, yardExit, briefing]

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        // Yard-only ground: a lawn apron around the lot and the driveway out to the street edge.
        var g = MeshBucket()
        let a = Self.yardMin - V2(14, 14), b = Self.yardMax + V2(14, 14)
        g.quad(V3(a.x, 0.04, b.y), V3(b.x, 0.04, b.y), V3(b.x, 0.04, a.y), V3(a.x, 0.04, a.y), "ground.meadow")
        scene.add(g.model("yard-apron"))
        Self.compose(into: &scene, seed: seed)
        scene.farGround = "ground.meadow"
        scene.lighting = .init(sky: SunSky(elevation: 34, azimuth: 215, turbidity: 2.6))
        scene.batchStatics = true
        scene.batchCell = 12
        scene.camera = .init(eye: V3(-74.5, slabTopEye, 40.5), target: V3(-97, 1.8, 55), fov: 64)
        scene.spots += Self.markers.map(\.spot)
        return scene
    }

    private var slabTopEye: Float { Self.slabTop + 1.7 }

    // MARK: - Composition

    /// Adds the fenced yard (slab, shop, fence, stock, props, lights) to `scene` in world coordinates.
    static func compose(into scene: inout RealScene, seed: UInt64) {
        var rng = SeededRNG(seed: seed &+ 4101)
        let lo = yardMin, hi = yardMax, top = slabTop

        // Slab: broom-finished concrete with saw-cut joints every 6 m, oil drips in the stalls,
        // and a driveway apron out through the gate to the street gutter.
        var slab = Model(name: "yard-slab")
        citySlab(&slab, x: hi.x - lo.x + 1, z: hi.y - lo.y + 1, top: top, material: "concrete.sidewalk:8F8B83", at: (lo + hi) / 2)
        var joints = Model(name: "yard-joints")
        for x in stride(from: lo.x + 6, to: hi.x, by: 6) {
            cityStripe(&joints, V2(x, lo.y), V2(x, hi.y), width: 0.012, y: top, material: "asphalt.sealant", rng: &rng)
        }
        for z in stride(from: lo.y + 6, to: hi.y, by: 6) {
            cityStripe(&joints, V2(lo.x, z), V2(hi.x, z), width: 0.012, y: top, material: "asphalt.sealant", rng: &rng)
        }
        // Truck stalls: yellow lines 4.2 m apart, 13 m long, west of the gate lane.
        for k in 0...3 {
            let z = 43.5 + Float(k) * 4.2 - 2.1
            cityStripe(&joints, V2(-100, z), V2(-85, z), width: 0.1, y: top, material: "paint.lane-yellow", rng: &rng)
        }
        cityStripe(&joints, V2(-100, 41.4), V2(-100, 54), width: 0.1, y: top, material: "paint.lane-yellow", rng: &rng)
        // Oil drips and tire scuffs.
        for k in 0..<3 {
            let zc = 43.5 + Float(k) * 4.2
            for _ in 0..<3 {
                let c = V2(rng.float(-97 ... -88), zc + rng.float(-0.9...0.9))
                let r = rng.float(0.12...0.3), ph = rng.float(0...6)
                let ring = (0..<18).map { i -> V2 in let t = Float(i) / 18 * 2 * .pi; return c + V2(cos(t) * 1.3, sin(t) * 0.8) * r * (1 + 0.22 * sin(t * 3 + ph)) }
                cityLayer(&joints, outline: ring, y: top, lift: 0.001, thick: 0.001, material: "concrete.rough:6E6A63")
            }
        }
        // Worn dark tire lane from the stalls to the gate.
        cityLayer(&joints, outline: [V2(-86, 40.6), V2(-70, 40.6), V2(-70, 46.4), V2(-86, 46.4)], y: top, lift: 0.0008, thick: 0.0008,
                  material: "concrete.rough:8C877E")
        scene.add(slab)
        scene.add(joints)
        // Driveway across the outer sidewalk band to the road edge (x = -66).
        var drive = Model(name: "yard-driveway")
        citySlab(&drive, x: 4.2, z: gateZ.upperBound - gateZ.lowerBound, top: 0.13, material: "concrete.sidewalk:9C988F",
                 at: V2(-68, (gateZ.lowerBound + gateZ.upperBound) / 2))
        scene.add(drive)

        scene.add(shop(seed: seed), bake: false)
        scene.add(fence(seed: seed))
        scene.add(poleStacks(seed: seed))
        scene.add(conex(), at: Xform(translation: V3(-104.4, top, 44.6), rotation: simd_quatf(degrees: 90, axis: .up)))
        scene.add(stock(seed: seed))
        scene.add(floodPole(), at: Xform(translation: V3(-105, top, 61)))
        scene.add(floodPole(), at: Xform(translation: V3(-71, top, 23), rotation: simd_quatf(degrees: 180, axis: .up)))
        scene.add(floodPole(), at: Xform(translation: V3(-71, top, 61), rotation: simd_quatf(degrees: -90, axis: .up)))

        // Cable reels: a grid of standard reels and a row of big ones.
        var reels: [simd_float4x4] = [], big: [simd_float4x4] = []
        for i in 0..<4 { for j in 0..<2 {
            reels.append(place(-80 + Float(i) * 1.25 + rng.float(-0.1...0.1), 57.2 + Float(j) * 1.4, y: top, yaw: rng.float(-6...6)).matrix)
        }}
        for i in 0..<3 { big.append(place(-79.6 + Float(i) * 2.1, 54.4, y: top, yaw: rng.float(-5...5), scale: 1.9).matrix) }
        scene.field(CableSpool(), seed: seed &+ 11, transforms: reels, options: .props)
        scene.field(CableSpool(), seed: seed &+ 12, transforms: big, options: .props)

        // Pallets with drums and crated stock along the shop front corner.
        var pallets: [simd_float4x4] = [], drums: [simd_float4x4] = []
        for i in 0..<4 {
            let p = V2(-78.4, 30.2 + Float(i) * 1.35)
            pallets.append(place(p.x, p.y, y: top, yaw: rng.float(-3...3)).matrix)
            if i < 3 { for d in 0..<4 {
                let o = V2(d % 2 == 0 ? -0.3 : 0.3, d < 2 ? -0.3 : 0.3)
                drums.append(place(p.x + o.x, p.y + o.y, y: top + 0.144, yaw: rng.float(0...360)).matrix)
            }}
        }
        scene.field(Pallet(), seed: seed &+ 13, transforms: pallets, options: .props)
        scene.field(OilDrum(), seed: seed &+ 14, transforms: drums, options: .props)
        scene.add(WoodenCrate(), at: place(-78.4, 34.25, y: top + 0.144, yaw: 8), seed: seed &+ 15)

        // Jersey barriers protecting the fence line behind the stalls, cones by the gate.
        var jerseys: [simd_float4x4] = []
        for k in 0..<3 { jerseys.append(place(-87.0 + Float(k) * 3.05, 61.0, y: top, yaw: 0).matrix) }
        scene.field(JerseyBarrier(), seed: seed &+ 16, transforms: jerseys, options: .props)
        var cones: [simd_float4x4] = []
        for k in 0..<6 { cones.append(place(-80.5 + Float(k % 3) * 0.32, 50.2 + Float(k / 3) * 0.3, y: top + 0.0, yaw: rng.float(0...360)).matrix) }
        cones.append(place(-72.2, 38.6, y: top, yaw: 20).matrix)
        cones.append(place(-72.2, 48.6, y: top, yaw: 70).matrix)
        scene.field(TrafficCone(), seed: seed &+ 17, transforms: cones, options: .props)
        scene.add(Dumpster(), at: place(-104.6, 51.6, y: top, yaw: 90), seed: seed &+ 18)
        // Weeds along the fence base, inside and out.
        var weeds: [simd_float4x4] = []
        var wr = SeededRNG(seed: seed &+ 4110)
        func weedLine(_ a: V2, _ b: V2, _ n: V2) {
            let len = simd_length(b - a)
            var t: Float = 0
            while t < len {
                let p = a + (b - a) * (t / len) + n * wr.float(-0.25...0.35)
                if !(p.x > hi.x - 0.5 && p.y > gateZ.lowerBound - 0.5 && p.y < gateZ.upperBound + 0.5) {
                    weeds.append(place(p.x, p.y, y: (abs(p.x - hi.x) < 0.3 || p.x < lo.x || p.y < lo.y || p.y > hi.y) ? 0.04 : top, yaw: wr.float(0...360), scale: wr.float(0.7...1.3)).matrix)
                }
                t += wr.float(0.5...1.4)
            }
        }
        weedLine(V2(lo.x, lo.y - 0.2), V2(hi.x, lo.y - 0.2), V2(0, -1)); weedLine(V2(lo.x, hi.y + 0.2), V2(hi.x, hi.y + 0.2), V2(0, 1))
        weedLine(V2(lo.x - 0.2, lo.y), V2(lo.x - 0.2, hi.y), V2(-1, 0)); weedLine(V2(hi.x + 0.2, lo.y), V2(hi.x + 0.2, hi.y), V2(1, 0))
        weedLine(V2(-79, hi.y - 0.25), V2(-71, hi.y - 0.25), V2(0, -1)); weedLine(V2(hi.x - 0.25, 50), V2(hi.x - 0.25, 61), V2(-1, 0))
        scene.field(DryGrass(), seed: seed &+ 20, transforms: weeds, options: .groundCover(cull: 45))
        // Shade trees on the lawn outside the fence.
        var oaks: [simd_float4x4] = [], maples: [simd_float4x4] = []
        for (k, p) in [V2(-114, 30), V2(-116, 58), V2(-92, 74), V2(-112, 12), V2(-80, 71)].enumerated() {
            (k % 2 == 0 ? { oaks.append($0) } : { maples.append($0) })(place(p.x, p.y, y: 0, yaw: rng.float(0...360), scale: rng.float(0.8...1.0)).matrix)
        }
        scene.field(OakTree(), seed: seed &+ 21, transforms: oaks, options: .trees)
        scene.field(MapleTree().with { $0.autumn = 0.05 }, seed: seed &+ 22, transforms: maples, options: .trees)
        scene.add(StopSign(), at: place(-71.4, 49.4, y: top, yaw: -90), seed: seed &+ 19)
    }

    // MARK: - Pieces

    /// Line stock: ecology-block bins of gravel and sand, a row of pole-top transformers on pallets,
    /// and a stack of crossarms on dunnage.
    static func stock(seed: UInt64) -> Model {
        var rng = SeededRNG(seed: seed &+ 4505)
        var m = Model(name: "line-stock")
        let y0 = slabTop
        // Two bins of 0.6 x 0.6 x 1.2 m lock blocks, open toward the yard (-X): back on the north fence.
        let block: MaterialKey = "concrete.rough:9A968C"
        for (b, fill) in [(Float(0), "ground.gravel"), (1, "ground.sand")] {
            let bx0: Float = -79 + b * 4.2, bx1 = bx0 + 3.6
            for course in 0..<3 {
                let y = y0 + Float(course) * 0.6 + 0.3
                for k in 0..<3 { m.add(Prim.roundedBox(V3(1.18, 0.58, 0.58), radius: 0.03, bevelSegments: 1, material: block),
                                       Xform(translation: V3(bx0 + 0.6 + Float(k) * 1.2 + (course % 2 == 0 ? 0 : 0.0), y, 22.6))) }
                for x in [bx0 + 0.3, bx1 - 0.3] { for k in 0..<3 {
                    m.add(Prim.roundedBox(V3(0.58, 0.58, 1.18), radius: 0.03, bevelSegments: 1, material: block),
                          Xform(translation: V3(x, y, 23.5 + Float(k) * 1.2 + rng.float(-0.01...0.01))))
                }}
            }
            // Heap: a lumpy mound slumping out of the bin.
            let c = V3((bx0 + bx1) / 2, y0, 24.4)
            var heap = Prim.terrain(size: V2(3.0, 4.2), segments: 22, material: fill) { p in
                let d = simd_length(V2(p.x / 1.5, (p.y + 0.4) / 2.1))
                return max(0, 1.25 * (1 - d * d)) + 0.06 * sin(p.x * 7 + p.y * 5)
            }
            heap = heap.transformed(Xform(translation: c))
            m.add(heap)
        }
        // Transformers on pallets along the east fence.
        for k in 0..<5 {
            let c = V3(-72.3, y0, 26.2 + Float(k) * 1.5)
            m.add(Prim.roundedBox(V3(1.1, 0.14, 1.1), radius: 0.01, bevelSegments: 1, material: "wood.pine-aged"), Xform(translation: c + V3(0, 0.07, 0)))
            let can = c + V3(rng.float(-0.05...0.05), 0.14, rng.float(-0.05...0.05))
            let tint = rng.pick(["metal.painted:8A9094", "metal.painted:7E878C", "metal.painted:9AA0A2"])
            m.add(turned([(0, 0), (0.29, 0), (0.3, 0.03), (0.3, 0.95), (0.32, 0.97), (0.32, 1.0), (0.22, 1.06), (0, 1.07)], segments: 22, material: tint), Xform(translation: can))
            for r in 0..<5 { m.add(Prim.torus(major: 0.302, minor: 0.008, segments: 22, sides: 4, material: tint), Xform(translation: can + V3(0, 0.17 + Float(r) * 0.16, 0))) }
            for s: Float in [-1, 1] {
                m.add(turned([(0, 0), (0.035, 0), (0.04, 0.03), (0.028, 0.05), (0.035, 0.07), (0.018, 0.11), (0, 0.11)], segments: 10, material: "ceramic.stoneware:6A6E66"),
                      Xform(translation: can + V3(s * 0.12, 1.04, 0)))
            }
            m.add(Prim.roundedBox(V3(0.2, 0.5, 0.06), radius: 0.01, bevelSegments: 1, material: "metal.galvanized"), Xform(translation: can + V3(0, 0.55, -0.33)))
        }
        // Crossarm stack: 2.4 m arms, 5 wide x 4 high, on two dunnage timbers.
        for z in [57.6, 59.4] as [Float] {
            m.add(Prim.roundedBox(V3(1.2, 0.1, 0.1), radius: 0.008, bevelSegments: 1, material: "wood.weathered"), Xform(translation: V3(-87.4, y0 + 0.05, z)))
        }
        for row in 0..<4 { for k in 0..<5 {
            let tint = rng.pick(["wood.lumber-oak:6A5C48", "wood.lumber-oak:5C503E", "wood.lumber-pine:6E6A50"])
            m.add(Prim.roundedBox(V3(0.09, 0.11, 2.4), radius: 0.006, bevelSegments: 1, material: tint),
                  Xform(translation: V3(-87.4 - 0.4 + Float(k) * 0.2 + rng.float(-0.01...0.01), y0 + 0.155 + Float(row) * 0.115, 58.5 + rng.float(-0.04...0.04))))
        }}
        groundAO(&m, height: 0.4, floor: 0.55)
        return m
    }

    /// Pre-engineered steel line shop, 24 x 14 m, 6.5 m eave, 1:12 gable along X; three roll-up bays
    /// on the south face (one open), man door, wall packs, sign band, wainscot and gutters.
    static func shop(seed: UInt64) -> Model {
        var rng = SeededRNG(seed: seed &+ 4202)
        let x0: Float = -104, x1: Float = -80, z0: Float = 24, z1: Float = 38, y0 = slabTop
        let eave: Float = 6.5, ridge: Float = eave + (z1 - z0) / 2 / 12
        var m = MeshBucket()
        let panel: MaterialKey = "metal.roofing:CFCDC4", wains: MaterialKey = "metal.painted:4D5862", trim: MaterialKey = "metal.painted:3E4852"
        // Walls (outer faces) as quads with rib boxes every 0.3 m on the long walls.
        func wall(_ a: V2, _ b: V2, h0: Float, h1: Float, _ mat: MaterialKey) {
            m.quad(V3(a.x, y0 + h0, a.y), V3(b.x, y0 + h0, b.y), V3(b.x, y0 + h1, b.y), V3(a.x, y0 + h1, a.y), mat)
        }
        let doorXs: [Float] = [-100, -94, -88], dw: Float = 4.3, dh: Float = 4.6
        // South (front) wall: built around the door openings.
        var edges: [Float] = [x0]
        for x in doorXs { edges += [x - dw / 2, x + dw / 2] }
        edges.append(x1)
        for k in stride(from: 0, to: edges.count, by: 2) {
            wall(V2(edges[k], z1), V2(edges[k + 1], z1), h0: 1.0, h1: eave, panel)
            wall(V2(edges[k], z1), V2(edges[k + 1], z1), h0: 0, h1: 1.0, wains)
        }
        for x in doorXs { wall(V2(x - dw / 2, z1), V2(x + dw / 2, z1), h0: dh, h1: eave, panel) }
        // North and end walls.
        wall(V2(x1, z0), V2(x0, z0), h0: 1.0, h1: eave, panel); wall(V2(x1, z0), V2(x0, z0), h0: 0, h1: 1.0, wains)
        wall(V2(x0, z0), V2(x0, z1), h0: 1.0, h1: eave, panel); wall(V2(x0, z0), V2(x0, z1), h0: 0, h1: 1.0, wains)
        wall(V2(x1, z1), V2(x1, z0), h0: 1.0, h1: eave, panel); wall(V2(x1, z1), V2(x1, z0), h0: 0, h1: 1.0, wains)
        // Gables.
        let zm = (z0 + z1) / 2
        m.poly([V3(x0, y0 + eave, z0), V3(x0, y0 + eave, z1), V3(x0, y0 + ridge, zm)], panel, facing: V3(-1, 0, 0))
        m.poly([V3(x1, y0 + eave, z0), V3(x1, y0 + eave, z1), V3(x1, y0 + ridge, zm)], panel, facing: V3(1, 0, 0))
        // Ribs: trapezoidal ribs every 0.305 m on all walls.
        func ribs(along a: V2, _ b: V2, out n: V2, h0: Float, h1: (Float) -> Float, skip: (Float) -> Bool = { _ in false }) {
            let len = simd_length(b - a), d = (b - a) / len
            var t: Float = 0.15
            while t < len - 0.1 {
                let p = a + d * t
                let along = p.x * abs(d.x) + p.y * abs(d.y)
                if !skip(along) {
                    let base = V3(p.x + n.x * 0.001, y0 + h0, p.y + n.y * 0.001)
                    m.box(base - V3(d.x, 0, d.y) * 0.02, V3(d.x, 0, d.y) * 0.04, V3(0, h1(along) - h0, 0), V3(n.x, 0, n.y) * 0.025, panel)
                }
                t += 0.305
            }
        }
        let inDoor: (Float) -> Bool = { x in doorXs.contains { abs(x - $0) < dw / 2 + 0.05 } }
        ribs(along: V2(x0, z1), V2(x1, z1), out: V2(0, 1), h0: 1.0, h1: { _ in eave }, skip: inDoor)
        ribs(along: V2(x0, z0), V2(x1, z0), out: V2(0, -1), h0: 1.0, h1: { _ in eave })
        for (x, nx) in [(x0, Float(-1)), (x1, 1)] {
            ribs(along: V2(x, z0), V2(x, z1), out: V2(nx, 0), h0: 1.0, h1: { z in eave + (ridge - eave) * (1 - abs(z - zm) / ((z1 - z0) / 2)) - 0.03 })
        }
        // Roof slopes with 0.3 m overhangs, ridge cap, eave trim and gutters.
        let ov: Float = 0.3
        func roofY(_ z: Float) -> Float { y0 + eave + (ridge - eave) * (1 - abs(z - zm) / ((z1 - z0) / 2)) }
        for (za, zb) in [(z0 - ov, zm), (zm, z1 + ov)] {
            let ya = roofY(za) + 0.06 - (za < z0 ? ov / 12 : 0) * 0 , yb = roofY(zb) + 0.06
            let p = [V3(x0 - ov, ya, za), V3(x1 + ov, ya, za), V3(x1 + ov, yb, zb), V3(x0 - ov, yb, zb)]
            m.poly(p, "metal.roofing:5E6468", facing: .up)
            m.poly(p.map { $0 - V3(0, 0.05, 0) }, "metal.roofing:5E6468", facing: -.up)
        }
        m.box(V3(x0 - ov, roofY(zm) + 0.04, zm - 0.18), V3(x1 - x0 + 2 * ov, 0, 0), V3(0, 0.06, 0), V3(0, 0, 0.36), trim)
        for (z, s) in [(z0 - ov, Float(-1)), (z1 + ov, 1)] {
            m.box(V3(x0 - ov, y0 + eave - 0.08, z), V3(x1 - x0 + 2 * ov, 0, 0), V3(0, 0.16, 0), V3(0, 0, s * 0.14), trim)
        }
        for (x, s) in [(x0 - ov, Float(-1)), (x1 + ov, 1)] {
            m.poly([V3(x, roofY(z0 - ov) - 0.02, z0 - ov), V3(x, roofY(zm) + 0.1, zm), V3(x, roofY(z1 + ov) - 0.02, z1 + ov),
                    V3(x, roofY(z1 + ov) - 0.2, z1 + ov), V3(x, roofY(zm) - 0.08, zm), V3(x, roofY(z0 - ov) - 0.2, z0 - ov)].reversed(), trim, facing: V3(s, 0, 0))
        }
        // Downspouts at the corners.
        for x in [x0 + 0.2, x1 - 0.2] { for (z, s) in [(z0, Float(-1)), (z1, 1)] {
            m.box(V3(x - 0.05, y0, z + s * 0.02), V3(0.1, 0, 0), V3(0, eave - 0.1, 0), V3(0, 0, s * 0.08), trim)
        }}
        // Corner trim.
        for x in [x0, x1] { for z in [z0, z1] {
            m.box(V3(x - 0.06, y0, z - 0.06), V3(0.12, 0, 0), V3(0, eave, 0), V3(0, 0, 0.12), trim)
        }}
        // Doors: two closed roll-up curtains with slats, one open bay showing a dark interior.
        for (i, x) in doorXs.enumerated() {
            let a = x - dw / 2, b = x + dw / 2
            // Jambs and head trim.
            m.box(V3(a - 0.15, y0, z1), V3(0.15, 0, 0), V3(0, dh + 0.15, 0), V3(0, 0, 0.06), trim)
            m.box(V3(b, y0, z1), V3(0.15, 0, 0), V3(0, dh + 0.15, 0), V3(0, 0, 0.06), trim)
            m.box(V3(a - 0.15, y0 + dh, z1), V3(dw + 0.3, 0, 0), V3(0, 0.15, 0), V3(0, 0, 0.06), trim)
            if i == 1 {
                // Open: curtain rolled into the hood, dark interior with a floor and back wall.
                m.quad(V3(a, y0, z1 - 13.8), V3(b, y0, z1 - 13.8), V3(b, y0 + dh, z1 - 13.8), V3(a, y0 + dh, z1 - 13.8), "metal.painted:2A2C2E")
                m.quad(V3(b, y0, z1 - 13.8), V3(b, y0, z1), V3(b, y0 + dh, z1), V3(b, y0 + dh, z1 - 13.8), "metal.painted:3A3C3E")
                m.quad(V3(a, y0, z1), V3(a, y0, z1 - 13.8), V3(a, y0 + dh, z1 - 13.8), V3(a, y0 + dh, z1), "metal.painted:3A3C3E")
                m.quad(V3(a, y0 + dh, z1), V3(b, y0 + dh, z1), V3(b, y0 + dh, z1 - 13.8), V3(a, y0 + dh, z1 - 13.8), "metal.painted:1E2022")
                m.quad(V3(a, y0 + 0.004, z1 - 13.8), V3(b, y0 + 0.004, z1 - 13.8), V3(b, y0 + 0.004, z1), V3(a, y0 + 0.004, z1), "concrete.shop")
                m.box(V3(a - 0.1, y0 + dh + 0.15, z1), V3(dw + 0.2, 0, 0), V3(0, 0.55, 0), V3(0, 0, 0.5), trim)
            } else {
                m.quad(V3(a, y0, z1 - 0.08), V3(b, y0, z1 - 0.08), V3(b, y0 + dh, z1 - 0.08), V3(a, y0 + dh, z1 - 0.08), "metal.painted:B4B8BA")
                var y: Float = 0.08
                while y < dh - 0.02 {
                    m.box(V3(a, y0 + y, z1 - 0.08), V3(dw, 0, 0), V3(0, 0.012, 0), V3(0, 0, 0.012), "metal.painted:8E9294")
                    y += 0.076
                }
                m.box(V3(a, y0, z1 - 0.08), V3(dw, 0, 0), V3(0, 0.06, 0), V3(0, 0, 0.03), "rubber")
            }
            // Bollards guarding the jambs.
            for bx in [a - 0.45, b + 0.45] {
                m.add(Model(name: "b", surfaces: [Prim.cylinder(radius: 0.084, height: 1.1, bevel: 0.02, segments: 14, material: "metal.signal-yellow")]),
                      Xform(translation: V3(bx, y0, z1 + 0.35)))
            }
            // Wall pack above each door.
            m.box(V3(x - 0.18, y0 + dh + 0.55, z1), V3(0.36, 0, 0), V3(0, 0.26, 0), V3(0, 0, 0.2), "metal.painted:2C2E30")
            m.quad(V3(x - 0.15, y0 + dh + 0.57, z1 + 0.202), V3(x + 0.15, y0 + dh + 0.57, z1 + 0.202), V3(x + 0.15, y0 + dh + 0.72, z1 + 0.202),
                   V3(x - 0.15, y0 + dh + 0.72, z1 + 0.202), "glass.lamp")
        }
        // Man door and a window by the office end.
        m.quad(V3(-83.4, y0, z1 + 0.02), V3(-82.4, y0, z1 + 0.02), V3(-82.4, y0 + 2.1, z1 + 0.02), V3(-83.4, y0 + 2.1, z1 + 0.02), "metal.painted:4D5862")
        m.box(V3(-83.5, y0, z1), V3(1.2, 0, 0), V3(0, 2.2, 0), V3(0, 0, 0.015), trim)
        m.box(V3(-82.65, y0 + 0.95, z1 + 0.02), V3(0.16, 0, 0), V3(0, 0.03, 0), V3(0, 0, 0.05), "metal.stainless")
        m.quad(V3(-81.9, y0 + 1.1, z1 + 0.02), V3(-80.6, y0 + 1.1, z1 + 0.02), V3(-80.6, y0 + 2.2, z1 + 0.02), V3(-81.9, y0 + 2.2, z1 + 0.02), "glass.pane")
        m.box(V3(-82.0, y0 + 1.0, z1), V3(1.5, 0, 0), V3(0, 1.3, 0), V3(0, 0, 0.012), trim)
        m.box(V3(-83.9, y0, z1), V3(3.6, 0, 0), V3(0, 0.18, 0), V3(0, 0, 1.4), "concrete.smooth")
        _ = rng
        var out = m.model("line-shop")
        // Sign band over the bays.
        citySignPlate(&out, outline: Shape2D.roundedRect(7.2, 0.9, radius: 0.04, segments: 2),
                      x: Xform(translation: V3(-94, y0 + 5.65, z1 + 0.03)), thickness: 0.01, border: 0.04, borderMaterial: "sign.white",
                      face: "sign.green", back: nil, text: [("LINE DEPT  YARD 3", V2(0, 0), 0.42, 0.75)])
        groundAO(&out, height: 0.5, floor: 0.55)
        return out
    }

    /// Chain-link perimeter: 2.4 m fabric on galvanized posts every 3 m, top rail, three strands of
    /// barbed wire on outward arms, and the rolled-open cantilever gate parked north of the opening.
    static func fence(seed: UInt64) -> Model {
        var rng = SeededRNG(seed: seed &+ 4303)
        var m = Model(name: "yard-fence")
        let lo = yardMin, hi = yardMax, y0 = slabTop, h: Float = 2.4
        let steel: MaterialKey = "metal.galvanized-aged"
        // Runs: (a, b, outward normal).
        var runs: [(V2, V2, V2)] = [
            (V2(lo.x, lo.y), V2(hi.x, lo.y), V2(0, -1)), (V2(lo.x, hi.y), V2(hi.x, hi.y), V2(0, 1)),
            (V2(lo.x, lo.y), V2(lo.x, hi.y), V2(-1, 0)),
            (V2(hi.x, lo.y), V2(hi.x, gateZ.lowerBound), V2(1, 0)), (V2(hi.x, gateZ.upperBound), V2(hi.x, hi.y), V2(1, 0)),
        ]
        // Gate leaf rolled open just outside the north run of the east fence.
        let gl = V2(hi.x + 0.35, gateZ.lowerBound - 9.6), gr = V2(hi.x + 0.35, gateZ.lowerBound - 0.4)
        runs.append((gl, gr, V2(1, 0)))
        for (i, (a, b, n)) in runs.enumerated() {
            let isGate = i == runs.count - 1
            let len = simd_length(b - a), d = (b - a) / len
            let lift: Float = isGate ? 0.12 : 0.05
            m.add(BallKit.fence(V3(a.x, y0 + lift, a.y), V3(b.x, y0 + lift, b.y), height: h - lift - 0.05, material: "fence.chainlink"))
            // Top rail and (gate) bottom rail and frame.
            m.add(Prim.tube([V3(a.x, y0 + h, a.y), V3(b.x, y0 + h, b.y)], radii: [0.021, 0.021], sides: 8, seamTile: 0.2, material: steel))
            if isGate {
                m.add(Prim.tube([V3(a.x, y0 + 0.1, a.y), V3(b.x, y0 + 0.1, b.y)], radii: [0.03, 0.03], sides: 8, seamTile: 0.2, material: steel))
                m.add(Prim.tube([V3(a.x, y0 + 0.1, a.y), V3(b.x, y0 + h, b.y)], radii: [0.016, 0.016], sides: 6, seamTile: 0.2, material: steel))
                for t in [0, len] {
                    let p = a + d * t
                    m.add(Prim.tube([V3(p.x, y0 + 0.1, p.y), V3(p.x, y0 + h, p.y)], radii: [0.03, 0.03], sides: 8, seamTile: 0.2, material: steel))
                }
                continue
            }
            // Bottom tension wire.
            m.add(Prim.tube([V3(a.x, y0 + 0.07, a.y), V3(b.x, y0 + 0.07, b.y)], radii: [0.003, 0.003], sides: 4, seamTile: 0.1, material: steel))
            let posts = max(1, Int((len / 3).rounded(.up)))
            for k in 0...posts {
                let p = a + d * (len * Float(k) / Float(posts))
                let terminal = k == 0 || k == posts
                let r: Float = terminal ? 0.044 : 0.03
                m.add(Prim.cylinder(radius: r, height: h + 0.08, bevel: 0.004, segments: 10, material: steel), Xform(translation: V3(p.x, y0, p.y)))
                m.add(Prim.cylinder(radius: r + 0.004, height: 0.05, bevel: 0.01, segments: 10, material: steel), Xform(translation: V3(p.x, y0 + h + 0.06, p.y)))
                m.add(Prim.cylinder(radius: 0.16, height: 0.03, bevel: 0.01, segments: 12, material: "concrete.rough"), Xform(translation: V3(p.x, y0 - 0.02, p.y)))
                // Barbed-wire arm: 45 degrees outward, 0.35 m.
                let arm0 = V3(p.x, y0 + h + 0.08, p.y), arm1 = arm0 + V3(n.x * 0.25, 0.25, n.y * 0.25)
                m.add(Prim.tube([arm0, arm1], radii: [0.012, 0.012], sides: 4, seamTile: 0.1, material: steel))
            }
            // Three barbed strands with slight sag between posts, barbs as tiny crosses every 0.12 m.
            for s in 0..<3 {
                let off = V3(n.x, 0, n.y) * (0.08 * Float(s + 1)) + V3(0, h + 0.08 + 0.08 * Float(s + 1), 0)
                var pts: [V3] = []
                let steps = max(2, Int(len / 1.5))
                for k in 0...steps {
                    let t = Float(k) / Float(steps), p = a + d * len * t
                    let sag = 0.015 * sin(t * Float(posts) * .pi) * sin(t * Float(posts) * .pi)
                    pts.append(V3(p.x, y0, p.y) + off - V3(0, sag, 0))
                }
                m.add(Prim.tube(pts, radii: Array(repeating: 0.0018, count: pts.count), sides: 3, seamTile: 0.1, material: steel))
            }
            _ = rng.float(0...1)
        }
        // Gate rollers and latch post at the opening.
        for z in [gateZ.lowerBound - 0.4, gateZ.lowerBound - 6] {
            m.add(Prim.cylinder(radius: 0.05, height: h + 0.3, bevel: 0.006, segments: 10, material: steel), Xform(translation: V3(hi.x + 0.7, y0, z)))
        }
        m.add(Prim.cylinder(radius: 0.05, height: h + 0.1, bevel: 0.006, segments: 10, material: steel), Xform(translation: V3(hi.x, y0, gateZ.upperBound + 0.05)))
        return m
    }

    /// Wood poles on timber cribbing in three stacks of 5-4-3 along the south fence, butts alternating,
    /// with steel stakes at the ends.
    static func poleStacks(seed: UInt64) -> Model {
        var rng = SeededRNG(seed: seed &+ 4404)
        var m = Model(name: "pole-stacks")
        let y0 = slabTop
        for (si, zc) in [Float(56.6), 59.6].enumerated() {
            let x0: Float = -104.2, length: Float = si == 0 ? 13.7 : 12.2
            for sx in [x0 + 1.0, x0 + length / 2, x0 + length - 1.0] {
                m.add(Prim.roundedBox(V3(0.15, 0.15, 2.4), radius: 0.01, bevelSegments: 1, material: "wood.weathered"),
                      Xform(translation: V3(sx, y0 + 0.075, zc)))
            }
            for (row, count) in [5, 4, 3].enumerated() {
                let r: Float = 0.155
                let y = y0 + 0.15 + r + Float(row) * r * 1.72
                for k in 0..<count {
                    let z = zc + (Float(k) - Float(count - 1) / 2) * r * 2.02
                    let flip = (k + row) % 2 == 0
                    let tint = rng.pick(["wood.lumber-oak:4C4238", "wood.lumber-oak:5A4A3A", "wood.lumber-pine:5E5A40"])
                    let tip: Float = 0.11 + rng.float(-0.01...0.01)
                    var s = turned([(0, 0), (r, 0), (r * 0.92 + tip * 0.08, length * 0.5), (tip, length), (0, length)], segments: 14, material: tint, grainVertical: true)
                    s = s.transformed(Xform(rotation: simd_quatf(degrees: flip ? -90 : 90, axis: V3(0, 0, 1))))
                    m.add(s, Xform(translation: V3(flip ? x0 : x0 + length, y + rng.float(-0.01...0.01), z)))
                    // Sawn butt face (end grain).
                    let bx = flip ? x0 - 0.002 : x0 + length + 0.002
                    m.add(Prim.cylinder(radius: r * 0.97, height: 0.004, bevel: 0.001, segments: 14, material: "wood.endgrain-weathered"),
                          Xform(translation: V3(bx, y, z), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
                }
            }
            for sx in [x0 + 1.0, x0 + length - 1.0] { for s: Float in [-1, 1] {
                m.add(Prim.cylinder(radius: 0.03, height: 1.1, bevel: 0.004, segments: 8, material: "metal.rust"),
                      Xform(translation: V3(sx, y0, zc + s * 0.95)))
            }}
        }
        groundAO(&m, height: 0.35, floor: 0.55)
        return m
    }

    /// 20 ft shipping container (storage), 6.06 x 2.44 x 2.59 m, corrugated walls, door end with bars.
    static func conex() -> Model {
        var m = MeshBucket()
        let L: Float = 6.06, W: Float = 2.44, H: Float = 2.59, paint: MaterialKey = "metal.painted:3F5F6E"
        m.aabb(center: V3(0, H / 2 + 0.05, 0), size: V3(L, H - 0.1, W), paint)
        // Corrugation on the long sides.
        var x = -L / 2 + 0.2
        while x < L / 2 - 0.2 {
            for s: Float in [-1, 1] { m.aabb(center: V3(x, H / 2, s * (W / 2 + 0.02)), size: V3(0.12, H - 0.3, 0.04), paint) }
            x += 0.28
        }
        // Corner castings and rails.
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            m.aabb(center: V3(sx * (L / 2 - 0.09), H / 2, sz * (W / 2 - 0.09)), size: V3(0.18, H, 0.18), "metal.painted:2F4652")
        }}
        // Door bars on the +X end.
        for z in [-0.8, -0.35, 0.35, 0.8] as [Float] {
            m.aabb(center: V3(L / 2 + 0.03, H / 2, z), size: V3(0.03, H - 0.3, 0.03), "metal.galvanized-aged")
        }
        var out = m.model("conex")
        groundAO(&out, height: 0.3, floor: 0.55)
        return out
    }

    /// 9 m galvanized flood light pole with two LED heads aimed into the yard (local +Z) and a hand hole.
    static func floodPole() -> Model {
        var m = Model(name: "flood-pole")
        let steel: MaterialKey = "metal.galvanized"
        m.add(Prim.cylinder(radius: 0.28, height: 0.5, bevel: 0.02, segments: 16, material: "concrete.smooth"))
        m.add(turned([(0, 0.5), (0.09, 0.5), (0.065, 9), (0, 9)], segments: 14, material: steel, seamTile: 0.3))
        m.add(Prim.roundedBox(V3(0.9, 0.08, 0.08), radius: 0.01, bevelSegments: 1, material: steel), Xform(translation: V3(0, 8.8, 0.05)))
        for s: Float in [-1, 1] {
            let c = V3(s * 0.35, 8.65, 0.22)
            m.add(Prim.roundedBox(V3(0.42, 0.08, 0.32), radius: 0.015, bevelSegments: 2, material: "metal.painted:2A2C2E"),
                  Xform(translation: c, rotation: simd_quatf(degrees: 35, axis: V3(1, 0, 0))))
            m.add(Prim.roundedBox(V3(0.36, 0.006, 0.26), radius: 0.005, bevelSegments: 1, material: "glass.lamp"),
                  Xform(translation: c + V3(0, -0.035, 0.025), rotation: simd_quatf(degrees: 35, axis: V3(1, 0, 0))))
        }
        groundAO(&m, height: 0.3, floor: 0.6)
        return m
    }
}
