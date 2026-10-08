import simd
import Foundation
import RealKit

/// Drivable city district for the lineman game, built on the 12 m road grid: a 120 m square loop of
/// two-lane streets split into four blocks by a cross street (corner, T-junction and intersection
/// tiles), granite-curbed sidewalks, generated buildings in eight styles, street trees, lamps, signals,
/// stop signs and hydrants. No parked cars: the 3.6 m lanes and 1.75 m shoulders keep a 2.6 m truck
/// clear. An overhead pole line with sagging conductors runs around the loop on the outer sidewalk;
/// the job-site pole stands opposite the south T-junction. The `lineman-yard` sits at the south-west
/// corner in the same frame, gate onto the west street. Markers and the route are public static data.
public struct LinemanDistrict: RealSceneBuilder {
    public static let id = "lineman-district"
    public static let summary = "Drivable city loop of four blocks: road tiles, sidewalks, generated buildings, signals, overhead pole line, job-site pole, service yard."
    public static let tags = ["utility", "urban", "street", "outdoor"]
    public static let author = "hunter"
    public init() {}

    // MARK: - Swappable assets and frame

    /// Catalog id of the line pole. Swap to "distribution-pole" once that branch merges.
    public static let poleAsset = "distribution-pole"
    /// Articulation state of the job-site pole when `poleAsset` is articulated.
    public static let jobPoleState = "damaged"
    /// Road centerlines (world x for north-south streets, world z for east-west streets).
    public static let streetLines: [Float] = [-60, 0, 60]
    /// Road cell, travel lane width, and the curb offset from a road centerline (m).
    public static let cell: Float = CityGrid.roadCell
    public static let laneWidth: Float = 3.6
    public static let curbOffset: Float = 6
    /// Road surface height (m) and sidewalk top (m).
    public static let roadTop: Float = CityGrid.roadTop
    public static let walkTop: Float = CityGrid.walkTop
    /// Pole line: square loop on the outer sidewalk, 0.7 m behind the curb, 4 spans per side.
    public static let poleLineOffset: Float = 66.7
    public static let spansPerSide = 4

    // MARK: - Markers (driving order)

    public static let spawn = LinemanYard.spawn
    public static let yardExit = LinemanYard.yardExit
    /// Truck parking zone: east-bound shoulder lane just west of the job pole, rear toward the pole.
    public static let park = LinemanMarker("park", V3(-4.5, roadTop, 64.0), heading: 90)
    /// Base of the job-site pole (outer south sidewalk, opposite the south T-junction).
    public static let jobsite = LinemanMarker("jobsite", V3(0, Self.walkTop, poleLineOffset), heading: 0)
    /// Waypoints from the yard stall to the parking zone, lane centers, right-hand traffic.
    public static let route: [LinemanMarker] = [
        spawn,
        yardExit,
        LinemanMarker("westStreet", V3(-61.8, roadTop, 46), heading: 0),
        LinemanMarker("swCorner", V3(-59.5, roadTop, 59.5), heading: 45),
        LinemanMarker("southStreet", V3(-36, roadTop, 61.8), heading: 90),
        LinemanMarker("approach", V3(-16, roadTop, 62.6), heading: 90),
        park,
    ]
    /// Every named marker (spawn, yardExit, park, jobsite, briefing, route waypoints).
    public static var markers: [LinemanMarker] {
        var out = route
        out.append(jobsite)
        out.append(LinemanYard.briefing)
        return out
    }

    // MARK: - Build

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 7001)
        let lines = Self.streetLines, h = Self.cell / 2

        // Lawn under everything, 4 cm up so it never fights the far ground.
        var g = MeshBucket()
        let R: Float = 150
        g.quad(V3(-R, 0.04, R), V3(R, 0.04, R), V3(R, 0.04, -R), V3(-R, 0.04, -R), "ground.meadow")
        scene.add(g.model("district-lawn"))

        // Roads: straight tiles as instanced fields (three seeds, random 180 flips), nodes as singles.
        var straight: [[simd_float4x4]] = [[], []]
        for i in -5...5 { for k in -5...5 {
            let x = Float(i) * Self.cell, z = Float(k) * Self.cell
            let onX = lines.contains(z), onZ = lines.contains(x)
            guard onX || onZ else { continue }
            if onX && onZ {
                let ai = abs(i), ak = abs(k)
                if ai == 5 && ak == 5 {
                    let yaw: Float = (i < 0 && k < 0) ? 90 : (i > 0 && k < 0) ? 0 : (i > 0 && k > 0) ? 270 : 180
                    scene.add(RoadCorner(), at: place(x, z, yaw: yaw), seed: seed &+ UInt64(10 + i + 5 + (k + 5) * 11))
                } else if ai == 0 && ak == 0 {
                    scene.add(RoadIntersection(), at: place(x, z), seed: seed &+ 3)
                } else {
                    let yaw: Float = k == -5 ? 0 : k == 5 ? 180 : i == -5 ? 90 : 270
                    scene.add(RoadTJunction(), at: place(x, z, yaw: yaw), seed: seed &+ UInt64(20 + i + k * 3))
                }
            } else {
                let yaw: Float = (onX ? 0 : 90) + (rng.chance(0.5) ? 180 : 0)
                straight[rng.int(0...1)].append(place(x, z, yaw: yaw).matrix)
            }
        }}
        for (v, t) in straight.enumerated() {
            scene.fields.append(.init(asset: Self.roadLOD(seed: seed &+ UInt64(40 + v)), transforms: t, options: Self.flat(cell: 36)))
        }

        // Sidewalks: block rings (curb toward the street) and the outer band around the loop.
        var walks: [[simd_float4x4]] = [[]], plain: [simd_float4x4] = [], curbs: [simd_float4x4] = []
        func walk(_ x: Float, _ z: Float, yaw: Float, curb: Bool = true) {
            if curb { walks[0].append(place(x, z, yaw: yaw).matrix) } else { plain.append(place(x, z, yaw: yaw).matrix) }
        }
        let blocks: [V2] = [V2(-30, -30), V2(30, -30), V2(-30, 30), V2(30, 30)]
        for c in blocks {
            let x0 = c.x - 24, x1 = c.x + 24, z0 = c.y - 24, z1 = c.y + 24
            for j in 0..<16 {
                let t = Float(j) * 3 + 1.5
                walk(x0 + t, z0 + 1.5, yaw: 0)
                walk(x0 + t, z1 - 1.5, yaw: 180)
                if j > 0 && j < 15 {
                    walk(x0 + 1.5, z0 + t, yaw: 90)
                    walk(x1 - 1.5, z0 + t, yaw: 270)
                }
            }
            // Second curb on the four corner tiles.
            curbs.append(place(x0 + 1.5, z0 + 1.5, y: 0.002, yaw: 90).matrix)
            curbs.append(place(x1 - 1.5, z0 + 1.5, y: 0.002, yaw: 270).matrix)
            curbs.append(place(x0 + 1.5, z1 - 1.5, y: 0.002, yaw: 90).matrix)
            curbs.append(place(x1 - 1.5, z1 - 1.5, y: 0.002, yaw: 270).matrix)
        }
        let gate = LinemanYard.gateZ
        for j in 0..<46 {
            let t = -67.5 + Float(j) * 3, inner = abs(t) < 54
            walk(t, -67.5, yaw: 180, curb: inner)
            walk(t, 67.5, yaw: 0, curb: inner)
            if abs(t) < 66 {
                walk(67.5, t, yaw: 90, curb: inner)
                if !(t > gate.lowerBound && t < gate.upperBound) { walk(-67.5, t, yaw: 270, curb: inner) }
            }
        }
        scene.fields.append(.init(asset: Self.sidewalkLOD(curb: true, seed: seed &+ 50), transforms: walks[0], options: Self.flat(cell: 24)))
        scene.fields.append(.init(asset: Self.sidewalkLOD(curb: false, seed: seed &+ 53), transforms: plain, options: Self.flat(cell: 24)))
        var curbModel = Model(name: "corner-curb")
        var crng = SeededRNG(seed: seed &+ 54)
        cityCurb(&curbModel, x0: -1.5, x1: 1.5, z: -1.5 + 0.15, material: "stone.granite-curb", rng: &crng)
        scene.fields.append(.init(asset: LODModel(curbModel), transforms: curbs, options: Self.flat(cell: 64)))

        // Block interiors: lawn pads at sidewalk height, buildings on the north and south frontages.
        var pads = MeshBucket()
        for c in blocks {
            let a = c - V2(21, 21), b = c + V2(21, 21)
            pads.box(V3(a.x, 0, a.y), V3(b.x - a.x, 0, 0), V3(0, Self.walkTop - 0.01, 0), V3(0, 0, b.y - a.y)) { n in n.y > 0.5 ? "ground.meadow" : "concrete.sidewalk:8C8982" }
        }
        scene.add(pads.model("block-pads"))
        composeBuildings(into: &scene, seed: seed, blocks: blocks)
        composeStreetscape(into: &scene, seed: seed, blocks: blocks, rng: &rng)
        composePoleLine(into: &scene, seed: seed)

        // Yard at the south-west corner, same frame.
        LinemanYard.compose(into: &scene, seed: seed)

        scene.farGround = "ground.meadow"
        scene.lighting = .init(sky: SunSky(elevation: 36, azimuth: 215, turbidity: 2.5))
        scene.batchStatics = true
        scene.batchCell = 24
        scene.camera = .init(eye: V3(-22, Self.walkTop + 1.7, 68.2), target: V3(8, 7.5, 63), fov: 64)
        scene.spots += Self.markers.map(\.spot)
        return scene
    }

    // MARK: - Tiles

    /// Flat ground tiles: no shadow casting, no color drift, coarse cells.
    static func flat(cell: Float) -> RealInstancing.Options {
        RealInstancing.Options.props.with { $0.cellSize = cell; $0.shadowCasterMaxLOD = -1 }
    }

    /// `sidewalk-curb` up close, a two-box slab and curb past 30 m.
    static func sidewalkLOD(curb: Bool, seed: UInt64) -> LODModel {
        let tile = SidewalkCurb().with { $0.hasCurb = curb; $0.spots = 8 }
        let h = tile.cell / 2, z0 = curb ? -h + tile.curbWidth : -h
        var m = MeshBucket()
        m.box(V3(-h, 0, z0), V3(2 * h, 0, 0), V3(0, tile.top, 0), V3(0, 0, h - z0), tile.walk)
        if curb { m.box(V3(-h, 0, -h), V3(2 * h, 0, 0), V3(0, tile.top, 0), V3(0, 0, tile.curbWidth), tile.curb) }
        return LODModel(levels: [tile.build(seed: seed).levels[0], m.model("sidewalk-curb-far")], switchDistances: [48])
    }

    /// `road-straight` up close, slab, gutters and paint lines past 40 m.
    static func roadLOD(seed: UInt64) -> LODModel {
        let r = RoadStraight()
        let h = r.cell / 2, y = r.top
        var m = MeshBucket()
        m.box(V3(-h, 0, -h + r.gutterWidth), V3(2 * h, 0, 0), V3(0, y, 0), V3(0, 0, r.cell - 2 * r.gutterWidth), r.asphalt)
        for s: Float in [-1, 1] {
            m.box(V3(-h, 0, s < 0 ? -h : h - r.gutterWidth), V3(2 * h, 0, 0), V3(0, y + 0.0008, 0), V3(0, 0, r.gutterWidth), r.gutter)
            for (z, mat) in [(s * r.lineWidth, r.yellow), (s * (r.laneWidth + r.lineWidth / 2), r.white)] {
                m.quad(V3(-h, y + 0.002, z + r.lineWidth / 2), V3(h, y + 0.002, z + r.lineWidth / 2), V3(h, y + 0.002, z - r.lineWidth / 2), V3(-h, y + 0.002, z - r.lineWidth / 2), mat)
            }
        }
        return LODModel(levels: [r.build(seed: seed).levels[0], m.model("road-straight-far")], switchDistances: [40])
    }

    // MARK: - Buildings

    /// Eight building variants (one per style), 13.8 m frontage, used three times each across the
    /// block frontages plus outer rows on the north and east streets (GPU-instanced fields).
    static func buildingSpecs() -> [BuildingSpec] {
        let row: [(String, Int, Float, RoofType?)] = [
            ("georgian", 3, 12, .hip), ("italianate", 4, 13, nil), ("brownstone", 4, 13, nil), ("haussmann", 6, 13, nil),
            ("federal", 3, 11, .gable), ("art-deco", 8, 13, nil), ("beaux-arts", 5, 13, nil), ("modernist", 7, 12, nil),
        ]
        return row.enumerated().map { i, r in
            let (style, floors, depth, roof) = r
            let st = ArchStyle.named(style)!
            var b = BuildingSpec(footprint: .rect(width: 13.8, depth: depth), floors: floors, style: style, seed: UInt64(31 + i))
            b.name = "lineman-\(style)"
            b.roof = roof
            b.interiors = false
            b.bayWidth = style == "modernist" ? 1.5 : (style == "brownstone" ? 2.3 : 3.0)
            if st.groundWindow == .storefront { b.groundFloorHeight = 4.4 }
            if style == "haussmann" { b.typicalFloorHeight = 3.2 }
            return b
        }
    }

    func composeBuildings(into scene: inout RealScene, seed: UInt64, blocks: [V2]) {
        let specs = Self.buildingSpecs()
        var xforms = Array(repeating: [simd_float4x4](), count: specs.count)
        func put(_ spec: Int, _ x: Float, _ z: Float, facing yaw: Float, frontLine: Float, axisZ: Bool) {
            let b = specs[spec], depth = FootprintShape(b.footprint).bounds.size.y
            let st = b.resolvedStyle
            let setback: Float = b.style == "brownstone" ? 2.6 : (st.groundRaise > 0.3 ? 0.8 : 0.15)
            // Center sits depth/2 behind the front line (+setback), away from the street the facade faces.
            let back = V2(-sin(yaw * .pi / 180), -cos(yaw * .pi / 180)) * (depth / 2 + setback)
            let c = axisZ ? V2(frontLine, z) + back : V2(x, frontLine) + back
            xforms[spec].append(place(c.x, c.y, y: Self.walkTop - 0.02, yaw: yaw).matrix)
        }
        var slot = 0
        func next() -> Int { defer { slot += 3 }; return slot % specs.count }
        for c in blocks {
            for (front, yaw) in [(c.y - 21, Float(180)), (c.y + 21, Float(0))] {
                for k in 0..<3 {
                    put(next(), c.x - 14 + Float(k) * 14, 0, facing: yaw, frontLine: front, axisZ: false)
                }
            }
        }
        // Outer rows across the north and east streets, 1.5 m behind the outer sidewalk.
        for k in 0..<7 {
            put(next(), -42 + Float(k) * 14, 0, facing: 0, frontLine: -70.5, axisZ: false)
            put(next(), 0, -42 + Float(k) * 14, facing: -90, frontLine: 70.5, axisZ: true)
        }
        // South street, set back behind front lawns, facing north.
        for k in 0..<7 { put(next(), -42 + Float(k) * 14, 0, facing: 180, frontLine: 72.5, axisZ: false) }
        // West street north of the yard, facing east.
        for k in 0..<4 { put(next(), 0, -42 + Float(k) * 14, facing: 90, frontLine: -70.5, axisZ: true) }
        for (i, t) in xforms.enumerated() where !t.isEmpty {
            var b = specs[i]
            b.seed = b.seed &+ seed &* 31
            scene.fields.append(.init(asset: BuildingGenerator.build(b).combined(), transforms: t, options: RealInstancing.Options.props.with { $0.cellSize = 64 }))
        }
    }

    // MARK: - Street furniture

    func composeStreetscape(into scene: inout RealScene, seed: UInt64, blocks: [V2], rng: inout SeededRNG) {
        var lamps: [simd_float4x4] = [], trees: [[simd_float4x4]] = [[], []], hydrants: [simd_float4x4] = []
        var courtTrees: [[simd_float4x4]] = [[], [], []], hedges: [simd_float4x4] = []
        for (bi, c) in blocks.enumerated() {
            // Four sides: (point at offset t along the side, inward normal).
            let sides: [(V2, V2, V2)] = [
                (V2(c.x - 24, c.y - 24), V2(1, 0), V2(0, 1)), (V2(c.x - 24, c.y + 24), V2(1, 0), V2(0, -1)),
                (V2(c.x - 24, c.y - 24), V2(0, 1), V2(1, 0)), (V2(c.x + 24, c.y - 24), V2(0, 1), V2(-1, 0)),
            ]
            for (si, (o, d, n)) in sides.enumerated() {
                for t: Float in [10, 38] {
                    let p = o + d * t + n * 0.65
                    lamps.append(place(p.x, p.y, y: Self.walkTop, yaw: rng.float(0...360)).matrix)
                }
                for t: Float in [17, 31] {
                    let p = o + d * t + n * 1.05
                    trees[rng.int(0...1)].append(place(p.x, p.y, y: Self.walkTop - 0.005, yaw: rng.float(0...360)).matrix)
                }
                if (si + bi) % 2 == 0 {
                    let p = o + d * 5.2 + n * 0.55
                    hydrants.append(place(p.x, p.y, y: Self.walkTop, yaw: rng.float(0...360)).matrix)
                }
            }
            // Courtyard: shade trees and hedges between the two building rows.
            for k in 0..<3 {
                let p = c + V2(-12 + Float(k) * 12 + rng.float(-2...2), rng.float(-2.5...2.5))
                courtTrees[k].append(place(p.x, p.y, y: Self.walkTop - 0.1, yaw: rng.float(0...360), scale: rng.float(0.75...0.9)).matrix)
            }
            for s: Float in [-1, 1] { for k in 0..<4 {
                hedges.append(place(c.x + s * 20.2, c.y - 2.25 + Float(k) * 1.5, y: Self.walkTop - 0.01, yaw: 90).matrix)
            }}
        }
        // Outer sidewalk hydrants (none under the pole line's job span).
        for p in [V2(-40, -67.8), V2(40, 67.8), V2(67.8, 22), V2(-67.8, -30)] { hydrants.append(place(p.x, p.y, y: Self.walkTop, yaw: rng.float(0...360)).matrix) }
        let street = RealInstancing.Options.props.with { $0.cellSize = 48; $0.cullDistance = 110 }
        scene.field(StreetLamp(), seed: seed &+ 60, transforms: lamps, options: street)
        let grates = RealInstancing.Options.trees.with { $0.cellSize = 64; $0.cullDistance = 90 }
        scene.field(TreeGrate(), seed: seed &+ 61, transforms: trees[0], options: grates)
        scene.field(TreeGrate(), seed: seed &+ 62, transforms: trees[1], options: grates)
        scene.field(FireHydrant(), seed: seed &+ 63, transforms: hydrants, options: street.with { $0.cullDistance = 60 })
        scene.field(MapleTree().with { $0.autumn = 0.1 }, seed: seed &+ 64, transforms: courtTrees[0], options: .trees)
        scene.field(OakTree(), seed: seed &+ 65, transforms: courtTrees[1], options: .trees)
        scene.field(MapleTree().with { $0.autumn = 0.2 }, seed: seed &+ 66, transforms: courtTrees[2], options: .trees)
        scene.field(PrivetHedge(), seed: seed &+ 67, transforms: hedges, options: .trees.with { $0.cellSize = 48 })

        // Outer lawn trees beyond the south street and around the yard.
        var outer: [[simd_float4x4]] = [[], []]
        for (k, p) in [V2(-40, 82), V2(-14, 86), V2(18, 80), V2(44, 88), V2(84, 60), V2(90, 20)].enumerated() {
            outer[k % 2].append(place(p.x, p.y, y: 0, yaw: rng.float(0...360), scale: rng.float(0.8...1.0)).matrix)
        }
        scene.field(OakTree(), seed: seed &+ 68, transforms: outer[0], options: .trees)
        scene.field(MapleTree().with { $0.autumn = 0.05 }, seed: seed &+ 69, transforms: outer[1], options: .trees)

        // Manholes in the lanes, curb inlets in the gutters near each node, trash cans at block corners.
        var holes: [simd_float4x4] = [], drains: [simd_float4x4] = [], cans: [simd_float4x4] = []
        for line in Self.streetLines { for t in stride(from: Float(-48), through: 48, by: 24) where abs(t) > 8 {
            let o = rng.float(-1.4...1.4)
            holes.append(place(t + o, line + 1.8 * (rng.chance(0.5) ? 1 : -1), y: Self.roadTop + 0.001, yaw: rng.float(0...360)).matrix)
            holes.append(place(line + 1.8 * (rng.chance(0.5) ? 1 : -1), t + o, y: Self.roadTop + 0.001, yaw: rng.float(0...360)).matrix)
        }}
        for a in Self.streetLines { for b in Self.streetLines {
            for s: Float in [-1, 1] {
                drains.append(place(a + s * 9, b + s * 5.62, y: Self.roadTop + 0.001, yaw: 0).matrix)
                drains.append(place(a + s * 5.62, b - s * 9, y: Self.roadTop + 0.001, yaw: 90).matrix)
            }
        }}
        for (bi, c) in blocks.enumerated() {
            let sx: Float = bi % 2 == 0 ? 1 : -1, sz: Float = bi < 2 ? 1 : -1
            cans.append(place(c.x + sx * 22.6, c.y + sz * 20.5, y: Self.walkTop, yaw: rng.float(0...360)).matrix)
            cans.append(place(c.x - sx * 20.5, c.y - sz * 22.6, y: Self.walkTop, yaw: rng.float(0...360)).matrix)
        }
        scene.field(ManholeCover(), seed: seed &+ 74, transforms: holes, options: Self.flat(cell: 48).with { $0.cullDistance = 70 })
        scene.field(StormDrainGrate(), seed: seed &+ 75, transforms: drains.filter { abs($0.columns.3.x) < 70 && abs($0.columns.3.z) < 70 },
                    options: Self.flat(cell: 48).with { $0.cullDistance = 60 })
        scene.field(TrashCan(), seed: seed &+ 76, transforms: cans, options: street.with { $0.cullDistance = 70 })
        scene.add(BusShelter(), at: place(-24, -68.1, y: Self.walkTop, yaw: 0), seed: seed &+ 77)
        scene.add(NewspaperBox(), at: place(-29.5, -67.2, y: Self.walkTop, yaw: 0), seed: seed &+ 78)
        scene.add(Mailbox(), at: place(-6.8, 13.5, y: Self.walkTop, yaw: 90), seed: seed &+ 79)

        // Signals at the center intersection: one mast arm per approach, pole on the far-left corner.
        let names = ["ELM ST", "MAIN ST", "ELM ST", "MAIN ST"]
        for (k, hd) in [V2(1, 0), V2(0, 1), V2(-1, 0), V2(0, -1)].enumerated() {
            let r = V2(-hd.y, hd.x)
            let pole = hd * 7.0 - r * 7.0
            // Asset: arm along +X from a pole at x = -width/2 + 0.3, heads face +Z. Map +Z to -heading, +X to right.
            let yaw = atan2(-hd.x, -hd.y) * 180 / .pi
            let sig = TrafficSignal().with { $0.armLength = 9.5; $0.phase = hd.x != 0 ? 2 : 0; $0.streetName = names[k] }
            let half = (sig.armLength + 0.12) / 2
            let localPole = V3(-half + 0.08, 0, 0)
            let q = simd_quatf(degrees: yaw, axis: .up)
            let at = V3(pole.x, Self.walkTop, pole.y) - q.act(localPole)
            scene.add(sig, at: Xform(translation: at, rotation: q), seed: seed &+ UInt64(70 + k))
        }
        // Stop signs on every T-junction branch (right side, facing approaching traffic) and corner name signs.
        let tees: [(V2, V2)] = [(V2(0, -60), V2(0, 1)), (V2(0, 60), V2(0, -1)), (V2(-60, 0), V2(1, 0)), (V2(60, 0), V2(-1, 0))]
        for (k, (p, d)) in tees.enumerated() {
            let hd = -d, r = V2(-hd.y, hd.x)
            let s = p + d * 7.4 + r * 6.6
            scene.add(StopSign(), at: place(s.x, s.y, y: Self.walkTop, yaw: atan2(d.x, d.y) * 180 / .pi), seed: seed &+ UInt64(80 + k))
            let n = p + d * 7.4 - r * 6.6
            scene.add(StreetNameSign().with { $0.lower = k < 2 ? (k == 0 ? "NORTH AVE" : "SOUTH AVE") : "ELM ST"; $0.upper = k < 2 ? "MAIN ST" : (k == 2 ? "WEST AVE" : "EAST AVE") },
                      at: place(n.x, n.y, y: Self.walkTop), seed: seed &+ UInt64(84 + k))
        }
    }

    // MARK: - Pole line

    /// Poles around the loop (corner poles on the bisector), conductors between matching insulator
    /// tops with catenary sag, and the job-site pole as its own single (live when articulated).
    func composePoleLine(into scene: inout RealScene, seed: UInt64) {
        let L = Self.poleLineOffset, n = Self.spansPerSide
        let corners = [V2(-L, -L), V2(L, -L), V2(L, L), V2(-L, L)]
        var pts: [V2] = []
        for c in 0..<4 {
            let a = corners[c], b = corners[(c + 1) % 4]
            for k in 0..<n { pts.append(a + (b - a) * Float(k) / Float(n)) }
        }
        let count = pts.count
        let variants = [seed &+ 90].map { s -> (LODModel, [V3]) in
            let m = Catalog.build(Self.poleAsset, seed: s) ?? UtilityPole().build(seed: s)
            return (m, Self.attachPoints(m))
        }
        let jobIndex = pts.firstIndex { abs($0.x - Self.jobsite.position.x) < 0.5 && abs($0.y - Self.jobsite.position.z) < 0.5 }
        var fieldX: [[simd_float4x4]] = [[]]
        var ends: [[V3]] = []
        for i in 0..<count {
            let prev = pts[(i + count - 1) % count], p = pts[i], next = pts[(i + 1) % count]
            let dir = simd_normalize(simd_normalize(next - p) + simd_normalize(p - prev))
            let yaw = atan2(dir.x, dir.y) * 180 / .pi
            let x = place(p.x, p.y, y: Self.walkTop - 0.02, yaw: yaw)
            let v = 0
            if i == jobIndex {
                if let t = Catalog.type(Self.poleAsset) as? any RealArticulated.Type {
                    let rig = t.init().rig(seed: seed &+ 92)
                    let state = rig.stateNames.contains(Self.jobPoleState) ? Self.jobPoleState : nil
                    scene.rigs.append(.init(rig: rig, at: x, state: state, interactive: true, grabbable: false, name: "jobsite-pole"))
                    ends.append(Self.attachPoints(rig.posed(state)).map { x.point($0) })
                } else {
                    scene.singles.append(.init(asset: variants[v].0, at: x))
                    ends.append(variants[v].1.map { x.point($0) })
                }
            } else {
                fieldX[v].append(x.matrix)
                ends.append(variants[v].1.map { x.point($0) })
            }
        }
        for v in 0..<1 { scene.fields.append(.init(asset: variants[v].0, transforms: fieldX[v], options: .props.with { $0.cellSize = 140 })) }
        // Down guys at the four corner poles: strand to a screw anchor 5 m out, yellow guard at the bottom.
        var guys = Model(name: "down-guys")
        for c in corners {
            let out = simd_normalize(c), top = V3(c.x, Self.walkTop + 10.6, c.y), anchor = V3(c.x + out.x * 5.5, 0.05, c.y + out.y * 5.5)
            guys.add(Prim.tube([top, anchor], radii: [0.0055, 0.0055], sides: 5, seamTile: 0.2, material: "metal.galvanized-aged"))
            let d = simd_normalize(top - anchor)
            guys.add(Prim.tube([anchor + d * 0.15, anchor + d * 2.6], radii: [0.028, 0.028], sides: 10, seamTile: 0.3, material: "plastic.yellow"))
            guys.add(Prim.tube([anchor - d * 0.3, anchor + d * 0.15], radii: [0.012, 0.012], sides: 6, seamTile: 0.2, material: "metal.galvanized"))
        }
        scene.add(guys)
        // Conductors: ACSR, weathered aluminum, ~0.9% sag of span.
        var wires = Model(name: "conductors")
        for i in 0..<count {
            let a = ends[i], b = ends[(i + 1) % count]
            for k in 0..<min(a.count, b.count) {
                let span = simd_length(b[k] - a[k]), sag = span * (k == a.count - 1 ? 0.012 : 0.009)
                let path = (0...20).map { j -> V3 in
                    let t = Float(j) / 20
                    return a[k] + (b[k] - a[k]) * t - V3(0, 4 * sag * t * (1 - t), 0)
                }
                wires.add(Prim.tube(path, radii: Array(repeating: k == a.count - 1 ? 0.0065 : 0.0085, count: path.count), sides: 6, seamTile: 0.3,
                                    material: "metal.galvanized-aged"))
            }
        }
        scene.add(wires)
    }

    /// Conductor attachment points of a pole model: tops of the insulator clusters (porcelain,
    /// ceramic or polymer surfaces) within 1.2 m of the highest one, ordered by local x then z.
    static func attachPoints(_ lod: LODModel) -> [V3] {
        let m = lod.levels[0]
        let mats = ["ceramic", "porcelain", "insulator", "polymer"]
        var pts: [V3] = []
        for s in m.surfaces where mats.contains(where: { s.material.hasPrefix($0) || s.material.contains(".\($0)") }) { pts += s.positions }
        guard let top = pts.map(\.y).max() else {
            return [-1.05, -0.35, 1.05].map { V3($0, 11.63, -0.1) } + [V3(0, 12.1, 0)]
        }
        var tops: [V3] = []
        for p in pts.filter({ $0.y > top - 1.2 }).sorted(by: { $0.y > $1.y }) {
            if !tops.contains(where: { simd_length(V2($0.x - p.x, $0.z - p.z)) < 0.15 }) { tops.append(p) }
        }
        return tops.sorted { abs($0.x - $1.x) > 0.05 ? $0.x < $1.x : $0.z < $1.z }
    }
}
