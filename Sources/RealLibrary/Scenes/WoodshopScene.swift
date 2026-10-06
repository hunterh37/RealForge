import simd
import Foundation
import RealKit

/// Fixed floor plan of the `woodshop` scene. A game reads these values to spawn live machines at the
/// station spots (build the scene with `stations = false`) and to place the player. Floor y = 0, +Y up,
/// +Z toward the entrance (south wall), -Z toward the back wall where the benches stand. Yaw is degrees
/// about +Y; yaw 0 means the asset's front (+Z) faces the entrance.
public struct WoodshopLayout: Sendable {
    /// One work station: where its furniture or machine stands and where the operator stands.
    public struct Station: Sendable, Equatable {
        public var name: String
        /// Base point of the station's main asset (floor contact, or the bench top for bench-top machines).
        public var position: V3
        /// Degrees about +Y. 0 = front faces +Z.
        public var yaw: Float
        /// Floor point where the operator stands, facing the station.
        public var operatorSpot: V3
        public init(name: String, position: V3, yaw: Float, operatorSpot: V3) {
            self.name = name; self.position = position; self.yaw = yaw; self.operatorSpot = operatorSpot
        }
        /// Placement transform for the station's main asset.
        public var transform: simd_float4x4 { place(position.x, position.z, y: position.y, yaw: yaw).matrix }
        /// Placement as an `Xform`.
        public var xform: Xform { place(position.x, position.z, y: position.y, yaw: yaw) }
    }

    /// A wall-mounted or free-standing single item the game may spawn itself (`stations = false`).
    public struct Spot: Sendable, Equatable {
        public var position: V3
        public var yaw: Float
        public init(position: V3, yaw: Float) { self.position = position; self.yaw = yaw }
        public var transform: simd_float4x4 { place(position.x, position.z, y: position.y, yaw: yaw).matrix }
        public var xform: Xform { place(position.x, position.z, y: position.y, yaw: yaw) }
    }

    // MARK: room

    /// Floor height.
    public static let floorY: Float = 0
    /// Ceiling height above the floor (drywall underside).
    public static let ceilingHeight: Float = 2.75
    /// Interior size: 8.0 m along X, 6.4 m along Z.
    public static let roomSize = V3(8.0, 2.75, 6.4)
    /// Interior extents: x in [-4, 4], z in [-3.6, 2.8].
    public static let roomMin = V3(-4.0, 0, -3.6)
    public static let roomMax = V3(4.0, 2.75, 2.8)
    /// Center of the floor plan (the room is offset 0.4 m toward -Z).
    public static let roomCenter = V3(0, 0, -0.4)
    /// Back wall inner face (z), where the lumber rack and pegboard hang.
    public static let backWallZ: Float = -3.6
    /// East wall inner face (x): door, fire extinguisher, first aid kit.
    public static let eastWallX: Float = 4.0
    /// West wall inner face (x): the two windows.
    public static let westWallX: Float = -4.0
    /// Door opening on the east wall: center z and clear width (m); the leaf opens into the room.
    public static let doorCenterZ: Float = 2.0
    /// Window centers on the west wall (z) and their sill height.
    public static let windowCentersZ: [Float] = [-1.6, 1.0]
    public static let windowSill: Float = 1.0

    // MARK: stations

    /// Woodworking bench against the back wall, pegboard above it (bottom edge 1.0 m).
    public static let workbench = Station(name: "workbench", position: V3(-2.4, 0, -3.0), yaw: 0, operatorSpot: V3(-2.4, 0, -2.25))
    /// Bench under the miter saw (a `Workbench`).
    public static let miterSawBench = Station(name: "miter-saw-bench", position: V3(2.4, 0, -3.0), yaw: 0, operatorSpot: V3(2.4, 0, -2.25))
    /// Miter saw on the bench top: x 2.4, y = bench top (0.864), z -3.05.
    public static let miterSaw = Station(name: "miter-saw", position: V3(2.4, 0.864, -3.05), yaw: 0, operatorSpot: V3(2.4, 0, -2.25))
    /// Cabinet table saw in the middle of the floor; stock feeds toward -Z.
    public static let tableSaw = Station(name: "table-saw", position: V3(0, 0, -0.9), yaw: 0, operatorSpot: V3(-0.22, 0, 0.12))
    /// Floor kept clear behind the table saw for outfeed: z from the saw down to this value, |x| < 0.6.
    public static let tableSawOutfeedMinZ: Float = -2.2
    /// Floor kept clear in front of the table saw for infeed: z from the saw up to this value.
    public static let tableSawInfeedMaxZ: Float = 0.6
    /// Two sawhorses, beams along Z (yaw 90).
    public static let sawhorses: [Station] = [
        Station(name: "sawhorse-left", position: V3(-2.85, 0, 1.2), yaw: 90, operatorSpot: V3(-2.4, 0, 1.9)),
        Station(name: "sawhorse-right", position: V3(-1.95, 0, 1.2), yaw: 90, operatorSpot: V3(-2.4, 0, 1.9)),
    ]
    /// Operator spot for the sawhorse station (between and in front of both horses).
    public static let sawhorsesOperator = V3(-2.4, 0, 1.9)
    /// Assembly bench in the south-east quarter.
    public static let assembly = Station(name: "assembly", position: V3(2.4, 0, 1.2), yaw: 0, operatorSpot: V3(2.4, 0, 1.95))
    /// Entrance spot just inside the room, facing -Z (toward the table saw).
    public static let entrance = V3(0, 0, 2.2)
    /// Direction the player faces at the entrance.
    public static let entranceFacing = V3(0, 0, -1)

    /// Every station whose furniture or machine is left out when `stations == false`.
    public static let stations: [Station] = [workbench, miterSawBench, miterSaw, tableSaw] + sawhorses + [assembly]

    // MARK: single items the game spawns itself when `stations == false`

    /// Rolling tool chest near the entrance, yaw -25.
    public static let toolChest = Spot(position: V3(0.75, 0, 1.45), yaw: -25)
    /// Fire extinguisher standing at the east wall, facing -X.
    public static let fireExtinguisher = Spot(position: V3(3.88, 0, 1.05), yaw: -90)
    /// First aid cabinet on the east wall (base 1.35 m), facing -X.
    public static let firstAidKit = Spot(position: V3(3.9, 1.35, 0.25), yaw: -90)
    /// Shop vacuum beside the table saw.
    public static let shopVac = Spot(position: V3(-1.05, 0, -0.55), yaw: 0)

    // MARK: lights

    /// Shop light fixtures (centers at the ceiling plane): 3 x 3 grid, long axis along X.
    public static let shopLights: [V3] = [Float(-2.4), 0, 2.4].flatMap { x in [Float(-2.4), -0.4, 1.6].map { z in V3(x, 2.75, z) } }
}

/// Home or school woodshop, 8 x 6.4 m, 2.75 m drywall ceiling: painted CMU walls over a sealed shop concrete
/// floor, a steel door on the east wall and two windows on the west wall with low afternoon sun. Woodworking
/// bench under a stocked pegboard at the back wall, a miter saw on its own bench, a cabinet table saw in the
/// middle with clear infeed and outfeed, two sawhorses with a plywood panel and circular saw, an assembly
/// bench with sander, jigsaw and clamps, lumber rack, nine chain-hung LED shop lights, sawdust under the
/// saws, offcuts, leaning plywood, shop vac, tool chest, extinguisher, first aid cabinet and floor cords.
/// Floor plan: `WoodshopLayout`. `stations = false` leaves the station furniture and machines out so a game
/// can spawn live ones there.
public struct WoodshopScene: RealSceneBuilder {
    public static let id = "woodshop"
    public static let summary = "Woodshop interior: CMU walls, shop concrete, workbench under a pegboard, miter saw bench, cabinet table saw, sawhorses, assembly bench, lumber rack, chain-hung shop lights and sawdust."
    public static let tags = ["workshop", "interior", "showcase"]
    public static let author = "hunter"

    /// true: station furniture and machines are placed (baked). false: those spots stay empty for live
    /// game copies, along with the tool chest, extinguisher, first aid kit and the station shop vac.
    public var stations: Bool = true
    public init() {}

    typealias L = WoodshopLayout

    /// Size of an asset's LOD0 bounds.
    static func extent<A: RealAsset>(_ a: A) -> V3 { let b = a.build(seed: 1).levels[0].bounds; return b.max - b.min }

    /// The room shell in room-local coordinates (centered on X/Z); placed at `WoodshopLayout.roomCenter`.
    public func room() -> Room {
        var r = Room(size: L.roomSize)
        r.floor = "concrete.shop"
        r.wall = "masonry.cmu-painted"
        r.skirting = "rubber:3C3D3F"
        r.skirtingHeight = 0.1
        r.ceiling = .none
        r.cell = 0.25
        let door = Self.extent(Self.door)
        r.openings.append(.init(.east, offset: L.doorCenterZ - L.roomCenter.z, width: door.x, sill: 0, head: door.y))
        let win = Self.extent(OfficeWindow())
        for z in L.windowCentersZ {
            r.openings.append(.init(.west, offset: z - L.roomCenter.z, width: win.x, sill: L.windowSill, head: L.windowSill + win.y))
        }
        return r
    }

    /// Lumens per shop-light point light.
    static let lampLumens: Float = 2600

    static let door = OfficeDoor().with { $0.leafMaterial = "metal.powdercoat:6E7A84"; $0.lippingMaterial = "metal.powdercoat:6E7A84"; $0.kickPlate = true }

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 11)
        let room = room()
        let H = L.ceilingHeight, T = room.wallThickness
        let shellAt = Xform(translation: L.roomCenter)
        scene.add(room.shell(), at: shellAt, bake: true)
        // Flat painted drywall ceiling (and the slab above it).
        let ceiling = room.with { $0.ceiling = .flat; $0.wall = "paint.wall:EEEDE8" }
        scene.add(ceiling.ceilingModel(), at: shellAt)

        // Door (live, tap to open) and windows.
        scene.addLive(Self.door, at: place(L.eastWallX + T / 2, L.doorCenterZ, yaw: -90), seed: seed &+ 1, state: "closed")
        for (i, z) in L.windowCentersZ.enumerated() {
            scene.add(OfficeWindow(), at: place(L.westWallX - T / 2, z, y: L.windowSill, yaw: 90), seed: seed &+ UInt64(2 + i), state: "closed")
        }

        // Shop lights hang on chains from the ceiling.
        let light = ShopLight()
        scene.field(light, seed: seed &+ 5, transforms: L.shopLights.map { place($0.x, $0.z, y: H - light.ceilingY).matrix }, options: .props)
        // Each fixture is also a light, stations first (performance tiers keep the first few).
        let order = [V2(0, -0.4), V2(-2.4, -2.4), V2(2.4, -2.4), V2(-2.4, 1.6), V2(2.4, 1.6), V2(0, -2.4), V2(0, 1.6), V2(-2.4, -0.4), V2(2.4, -0.4)]
        let lampY = H - light.ceilingY + light.housingY - 0.03
        for (i, c) in order.enumerated() {
            scene.lights.append(RigLight(name: "shop-light-\(i)", position: V3(c.x, lampY, c.y), color: V3(1, 0.96, 0.9),
                                         intensity: Self.lampLumens, attenuationRadius: 5.5))
        }

        addWalls(&scene, seed: seed, rng: &rng)
        addFloorDetail(&scene, seed: seed, rng: &rng)
        if stations { addStations(&scene, seed: seed, rng: &rng) }

        scene.farGround = nil
        scene.lighting = .init(sky: SunSky(elevation: 20, azimuth: 252, turbidity: 2.6), interior: Self.light, fog: 0)
        scene.bake = .interior
        scene.batchStatics = true
        scene.batchCell = 4
        scene.camera = .init(eye: V3(-1.15, 1.68, 2.6), target: V3(0.35, 0.85, -1.5), fov: 68)
        scene.spots = [
            .init("entrance", eye: L.entrance + V3(0, 1.65, 0), target: V3(0, 0.9, -0.9)),
            .init("table-saw", eye: L.tableSaw.operatorSpot + V3(0, 1.65, 0), target: V3(0, 0.86, -1.2)),
            .init("workbench", eye: L.workbench.operatorSpot + V3(0, 1.65, 0), target: V3(-2.4, 0.9, -3.0)),
            .init("miter-saw", eye: L.miterSaw.operatorSpot + V3(0, 1.65, 0), target: V3(2.4, 1.0, -3.05)),
            .init("sawhorses", eye: L.sawhorsesOperator + V3(0, 1.65, 0), target: V3(-2.4, 0.75, 1.2)),
            .init("assembly", eye: L.assembly.operatorSpot + V3(0, 1.65, 0), target: V3(2.4, 0.9, 1.2)),
        ]
        return scene
    }

    /// Interior probe: bright LED tubes, pale block walls, grey concrete, west windows.
    static let light = InteriorLight().with {
        $0.ceiling = SIMD3(0.66, 0.65, 0.63); $0.walls = SIMD3(0.56, 0.55, 0.52); $0.floor = SIMD3(0.34, 0.33, 0.31)
        $0.fixtures = SIMD3(6.0, 6.0, 5.8); $0.fixturePitch = 0.42; $0.fixtureSize = SIMD2(0.08, 0.36)
        $0.windowAzimuth = 270; $0.windowWidth = 55; $0.windowElevation = 0...30; $0.exposure = -0.45
    }

    // MARK: walls

    func addWalls(_ scene: inout RealScene, seed: UInt64, rng: inout SeededRNG) {
        // Pegboard above the workbench, bottom edge at 1.0 m.
        let peg = PegboardWall()
        scene.add(peg, at: place(L.workbench.position.x, L.backWallZ, y: 1.0), seed: seed &+ 20)
        let faceZ = L.backWallZ + peg.faceZ

        // Pegboard hand tools hung flat against the board.
        // Rest poses lie flat with +Y up; `hang` turns that up vector to +Z (out of the board), then a yaw
        // in the rest pose becomes an in-plane turn on the wall.
        let hang = simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))
        func upright(_ yaw: Float) -> simd_quatf { hang * simd_quatf(angle: yaw * .pi / 180, axis: V3(0, 1, 0)) }
        // Hand saw hung by its tote at the left edge, toe down.
        scene.add(HandSaw(), at: Xform(translation: V3(-2.93, 1.5, faceZ + 0.004), rotation: upright(-90)), seed: seed &+ 21)
        scene.add(ClawHammer(), at: Xform(translation: V3(-2.68, 1.5, faceZ + 0.004), rotation: upright(90)), seed: seed &+ 22)
        scene.add(SpeedSquare(), at: Xform(translation: V3(-2.25, 1.9, faceZ + 0.004), rotation: hang), seed: seed &+ 23)
        scene.add(WoodChisel(), at: Xform(translation: V3(-2.52, 1.45, faceZ + 0.004), rotation: upright(-90)), seed: seed &+ 24)

        // Lumber rack on the back wall, centered behind the table saw.
        scene.add(LumberRack(), at: place(0, L.backWallZ - LumberRack().wallZ), seed: seed &+ 27)

        // Wall receptacles (duplex boxes) at bench height and near the floor.
        var boxes = Model(name: "receptacles")
        let plates: [(V3, Float)] = [(V3(-1.3, 1.05, L.backWallZ), 0), (V3(1.3, 1.05, L.backWallZ), 0), (V3(3.6, 1.05, L.backWallZ), 0),
                                     (V3(L.eastWallX, 0.45, -0.3), -90), (V3(L.westWallX, 0.45, 0.2), 90), (V3(L.westWallX, 0.45, -2.6), 90)]
        for (p, yaw) in plates {
            let r = simd_quatf(angle: yaw * .pi / 180, axis: V3(0, 1, 0))
            boxes.add(Prim.roundedBox(V3(0.075, 0.12, 0.045), radius: 0.004, bevelSegments: 1, material: "metal.galvanized"),
                      Xform(translation: p + r.act(V3(0, 0, 0.0225)), rotation: r))
            for dy: Float in [-0.022, 0.022] {
                boxes.add(Prim.roundedBox(V3(0.034, 0.03, 0.006), radius: 0.003, bevelSegments: 1, material: "plastic.matte:E9E6DE"),
                          Xform(translation: p + r.act(V3(0, dy, 0.047)), rotation: r))
            }
        }
        // Conduit from each back-wall box up to the ceiling.
        for (p, yaw) in plates where yaw == 0 {
            boxes.add(Prim.cylinder(radius: 0.011, height: L.ceilingHeight - p.y - 0.06, bevel: 0, material: "metal.galvanized"),
                      Xform(translation: V3(p.x, p.y + 0.06, p.z + 0.02)))
        }
        scene.add(boxes)

        // Plywood leaning on the east wall: a full 4 x 8 sheet and a 2 x 4 panel in front of it.
        func lean(_ sheet: PlywoodSheet, z: Float, lean deg: Float, gap: Float, seed s: UInt64) {
            let d = deg * .pi / 180, L2 = sheet.length / 2
            let r = simd_quatf(angle: -d, axis: V3(0, 0, 1)) * simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1))
            scene.add(sheet, at: Xform(translation: V3(L.eastWallX - gap - L2 * sin(d), L2 * cos(d), z), rotation: r), seed: s)
        }
        lean(PlywoodSheet().with { $0.length = 2.44; $0.width = 1.22 }, z: -1.3, lean: 6, gap: 0.004, seed: seed &+ 25)
        lean(PlywoodSheet(), z: -1.15, lean: 9, gap: 0.03, seed: seed &+ 26)
    }

    // MARK: floor detail (always present)

    func addFloorDetail(_ scene: inout RealScene, seed: UInt64, rng: inout SeededRNG) {
        // Sawdust: heaps behind the table saw and under the miter bench, light scatter at every station.
        scene.add(SawdustPile().with { $0.size = 0.55; $0.height = 0.06 }, at: place(0.3, -1.55, yaw: 20), seed: seed &+ 30)
        scene.add(SawdustPile().with { $0.size = 0.5; $0.height = 0.05 }, at: place(2.25, -2.85, yaw: -40), seed: seed &+ 31)
        scene.add(SawdustPile().with { $0.size = 0.35; $0.height = 0.035 }, at: place(-0.45, -0.95, yaw: 70), seed: seed &+ 32)
        let scatter: [(V2, Float)] = [(V2(-0.3, -0.3), 0.3), (V2(0.4, -2.0), 0.35), (V2(2.6, -2.3), 0.3), (V2(-2.2, -2.5), 0.3),
                                      (V2(-2.4, 1.3), 0.45), (V2(2.4, 1.75), 0.25)]
        for (i, (p, s)) in scatter.enumerated() {
            scene.add(SawdustPile().with { $0.size = s; $0.height = 0.008; $0.shavings = 5; $0.chips = 4 },
                      at: place(p.x, p.y, yaw: rng.float(0...360)), seed: seed &+ UInt64(40 + i))
        }

        // Offcuts on the floor by the miter bench and the table saw.
        let offcuts: [(V3, Float, Float)] = [(V3(1.7, 0, -2.45), 0.32, 30), (V3(1.85, 0, -2.3), 0.21, -65), (V3(3.25, 0, -2.4), 0.45, 80),
                                             (V3(0.7, 0, -1.7), 0.28, 10), (V3(-0.65, 0, 0.45), 0.18, 120)]
        for (i, (p, len, yaw)) in offcuts.enumerated() {
            scene.add(Lumber().with { $0.length = len; $0.stamp = false; $0.grainOffset = V2(Float(i) * 0.37, 0) },
                      at: place(p.x, p.z, yaw: yaw), seed: seed &+ UInt64(50 + i))
        }

        // Crate of offcuts in the south-west corner, trash can in the north-west corner.
        scene.add(WoodenCrate(), at: place(-3.55, 2.35, yaw: 4), seed: seed &+ 60)
        for i in 0..<4 {
            scene.add(Lumber().with { $0.length = rng.float(0.25...0.42); $0.stamp = false },
                      at: Xform(translation: V3(-3.62 + Float(i) * 0.06, 0.32, 2.3 + rng.float(-0.08...0.08)),
                                rotation: simd_quatf(angle: rng.float(0.9...1.3), axis: V3(0, 0, 1)) * simd_quatf(angle: rng.float(0...3), axis: V3(0, 1, 0))),
                      seed: seed &+ UInt64(61 + i))
        }
        scene.add(TrashCan().with { $0.color = 0x4A4E52 }, at: place(-3.6, -2.25), seed: seed &+ 66)
        // Decor shop vac between the lumber rack and the miter bench (the station copy sits by the table saw).
        scene.add(ShopVac(), at: place(1.25, -3.25, yaw: -20), seed: seed &+ 67)

        // Orange extension cords on the floor: east receptacle to the assembly bench, west receptacle to the sawhorses.
        var cords = Model(name: "extension-cords")
        let r: Float = 0.0045
        let runs: [[V3]] = [
            [V3(3.97, 0.4, -0.3), V3(3.9, 0.02, -0.3), V3(3.7, r, -0.1), V3(3.3, r, 0.25), V3(3.05, r, 0.55), V3(2.95, r, 0.9), V3(3.1, r, 1.2)],
            [V3(-3.97, 0.4, 0.2), V3(-3.9, 0.02, 0.2), V3(-3.6, r, 0.45), V3(-3.3, r, 0.7), V3(-3.2, r, 1.05), V3(-3.3, r, 1.45), V3(-3.55, r, 1.6)],
        ]
        for run in runs {
            let pts = catmull(run, per: 6)
            cords.add(Prim.tube(pts, radii: Array(repeating: r, count: pts.count), sides: 8, seamTile: 0.05, material: "rubber:D2561C"))
            let end = run.last!, dir = simd_normalize(run[run.count - 1] - run[run.count - 2])
            let rot = simd_quatf(from: V3(0, 0, 1), to: dir)
            cords.add(Prim.roundedBox(V3(0.045, 0.026, 0.06), radius: 0.006, bevelSegments: 2, material: "rubber:D2561C"),
                      Xform(translation: end + V3(0, 0.013, 0) + dir * 0.03, rotation: rot))
        }
        scene.add(cords)
    }

    // MARK: stations

    func addStations(_ scene: inout RealScene, seed: UInt64, rng: inout SeededRNG) {
        let bench = Workbench()
        let top = bench.topY

        // Workbench station: hand work under the pegboard.
        scene.add(bench, at: L.workbench.xform, seed: seed &+ 100, state: "closed")
        let wx = L.workbench.position.x, wz = L.workbench.position.z
        scene.add(CordlessDrill(), at: place(wx + 0.5, wz - 0.05, y: top, yaw: -30), seed: seed &+ 101, state: "idle")
        scene.add(ScrewBox(), at: place(wx + 0.72, wz - 0.18, y: top, yaw: 8), seed: seed &+ 102)
        scene.add(WoodGlue(), at: place(wx - 0.75, wz - 0.2, y: top, yaw: 25), seed: seed &+ 103)
        scene.add(SafetyGlasses(), at: place(wx + 0.25, wz + 0.15, y: top, yaw: -15), seed: seed &+ 104)
        scene.add(Lumber().with { $0.length = 0.7; $0.width = 0.14; $0.thickness = 0.019; $0.material = "wood.lumber-oak" },
                  at: place(wx - 0.1, wz + 0.02, y: top, yaw: 4), seed: seed &+ 105)
        scene.add(BarClamp(), at: place(wx - 0.45, wz + 0.14, y: top, yaw: 80), seed: seed &+ 106)
        scene.add(BlockPlane(), at: place(wx + 0.05, wz - 0.17, y: top, yaw: 12), seed: seed &+ 107)
        scene.add(TapeMeasure(), at: place(wx + 0.42, wz + 0.17, y: top, yaw: -35), seed: seed &+ 108)
        scene.add(CarpenterPencil(), at: place(wx - 0.05, wz + 0.2, y: top, yaw: 18), seed: seed &+ 109)
        scene.add(WoodChisel(), at: place(wx + 0.3, wz - 0.2, y: top, yaw: 160), seed: seed &+ 114)
        scene.add(SpeedSquare(), at: place(wx - 0.32, wz - 0.12, y: top, yaw: -8), seed: seed &+ 115)

        // Miter saw on its own bench.
        scene.add(bench, at: L.miterSawBench.xform, seed: seed &+ 110, state: "closed")
        scene.add(MiterSaw(), at: L.miterSaw.xform, seed: seed &+ 111, state: "idle")
        scene.add(Lumber().with { $0.length = 0.9 }, at: place(L.miterSaw.position.x - 0.78, -2.86, y: top, yaw: 0), seed: seed &+ 112)
        scene.add(EarMuffs(), at: place(L.miterSaw.position.x + 0.62, -3.1, y: top, yaw: -20), seed: seed &+ 113)

        // Table saw with its push stick on the right wing.
        scene.add(TableSaw(), at: L.tableSaw.xform, seed: seed &+ 120, state: "idle")
        scene.add(PushStick(), at: place(L.tableSaw.position.x + 0.5, L.tableSaw.position.z + 0.1, y: TableSaw().tableTopY, yaw: 95), seed: seed &+ 121)

        // Sawhorses with a plywood panel and the circular saw.
        for (i, s) in L.sawhorses.enumerated() { scene.add(Sawhorse(), at: s.xform, seed: seed &+ UInt64(130 + i)) }
        let horseTop = Sawhorse().height
        scene.add(PlywoodSheet(), at: place(-2.4, 1.2, y: horseTop, yaw: 2), seed: seed &+ 132)
        scene.add(CircularSaw(), at: place(-2.15, 1.15, y: horseTop + 0.019, yaw: -90), seed: seed &+ 133)

        // Assembly bench: sanding and jigsaw work, clamps and glue.
        scene.add(bench, at: L.assembly.xform, seed: seed &+ 140, state: "closed")
        let ax = L.assembly.position.x, az = L.assembly.position.z
        scene.add(Lumber().with { $0.length = 0.8; $0.width = 0.184; $0.thickness = 0.019; $0.material = "wood.lumber-maple" },
                  at: place(ax - 0.1, az - 0.02, y: top), seed: seed &+ 141)
        scene.add(RandomOrbitSander(), at: place(ax + 0.15, az + 0.0, y: top + 0.019, yaw: 30), seed: seed &+ 142, state: "idle")
        scene.add(Jigsaw(), at: place(ax + 0.62, az - 0.12, y: top, yaw: -20), seed: seed &+ 143, state: "idle")
        scene.add(BarClamp(), at: place(ax - 0.6, az + 0.12, y: top, yaw: 95), seed: seed &+ 144)
        scene.add(WoodGlue(), at: place(ax - 0.78, az - 0.18, y: top, yaw: -10), seed: seed &+ 145)
        scene.add(ClawHammer(), at: place(ax + 0.45, az + 0.2, y: top, yaw: 160), seed: seed &+ 146)
        scene.add(CarpenterPencil(), at: place(ax + 0.2, az + 0.22, y: top, yaw: -70), seed: seed &+ 147)
        scene.add(TapeMeasure(), at: place(ax - 0.35, az - 0.2, y: top, yaw: 20), seed: seed &+ 148)

        // Single items the game spawns itself when stations are off.
        scene.add(ToolChest(), at: L.toolChest.xform, seed: seed &+ 150)
        scene.add(FireExtinguisher(), at: L.fireExtinguisher.xform, seed: seed &+ 151)
        scene.add(FirstAidKit(), at: L.firstAidKit.xform, seed: seed &+ 152, state: "closed")
        scene.add(ShopVac(), at: L.shopVac.xform, seed: seed &+ 153)
    }
}
