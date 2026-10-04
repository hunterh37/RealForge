import simd
import Foundation
import RealityKit
import RealKit

/// Corner executive office, 6 x 4.8 m, 2.9 m plaster ceiling, oak floor: walnut executive desk facing the
/// door with an open book, a laptop and a lit banker's lamp, leather club chair, two full bookcases,
/// storage cupboard, wool rug, two tall windows with low golden sun raking across the floor. The lamp,
/// book, laptop, desk drawers, door and one window are live articulated assets.
public struct ExecutiveOffice: RealSceneBuilder {
    public static let id = "executive-office"
    public static let summary = "Corner executive office: walnut desk with open book, laptop and lit banker's lamp, bookcases, club chair, rug, golden sun through tall windows."
    public static let tags = ["office", "interior", "showcase"]
    public static let author = "realityhd"

    public var size = V3(6, 2.9, 4.8)
    public init() {}

    public func room() -> Room {
        var r = Room(size: size)
        r.floor = "wood.oak"
        r.ceiling = .flat
        r.wall = "paint.wall:CFC6B4"
        r.skirting = "wood.veneer-walnut"
        r.skirtingHeight = 0.12
        let win = OpenOffice.extent(OfficeWindow())
        for x: Float in [-1.2, 1.2] { r.openings.append(.init(.south, offset: x, width: win.x, sill: 0.75, head: 0.75 + win.y)) }
        r.openings.append(.init(.west, offset: 0.4, width: win.x, sill: 0.75, head: 0.75 + win.y))
        let door = OpenOffice.extent(OfficeDoor())
        r.openings.append(.init(.north, offset: size.x / 2 - 1.0, width: door.x, sill: 0, head: door.y))
        return r
    }

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 7)
        let room = room()
        let W = size.x, D = size.z, H = size.y
        scene.add(room.shell(), bake: true)
        scene.add(room.ceilingModel())
        for (i, op) in room.openings.enumerated() {
            switch op.wall {
            case .south:
                let at = place(op.offset, D / 2 + room.wallThickness / 2, y: op.sill, yaw: 180)
                if i == 0 { scene.addLive(OfficeWindow(), at: at, seed: seed &+ 1, state: "tilted") } else { scene.add(OfficeWindow(), at: at, seed: seed &+ 2, state: "closed") }
            case .west:
                scene.add(OfficeWindow(), at: place(-W / 2 - room.wallThickness / 2, op.offset, y: op.sill, yaw: 90), seed: seed &+ 3, state: "closed")
            case .north:
                scene.addLive(OfficeDoor(), at: place(op.offset, -D / 2 - room.wallThickness / 2), seed: seed &+ 4, state: "open")
            case .east: break
            }
        }
        // Rug under the desk zone.
        var rug = Model(name: "rug")
        rug.add(Prim.roundedBox(V3(3.0, 0.012, 2.2), radius: 0.005, bevelSegments: 2, material: "carpet.rug:6A3A2A"), Xform(translation: V3(0.2, 0.006, 0.4)))
        scene.add(rug, bake: true)

        // Desk facing the door (user sits on the window side, +Z), drawers live.
        let desk = OpenOffice.extent(ExecutiveDesk())
        let dz: Float = 0.3
        scene.addLive(ExecutiveDesk(), at: place(0.2, dz, yaw: 180), seed: seed &+ 10, state: "closed")
        let top = desk.y
        scene.addLive(BankerLamp(), at: place(0.2 - desk.x * 0.36, dz - 0.18, y: top, yaw: 160), seed: seed &+ 11, state: "on")
        scene.addLive(HardcoverBook(), at: place(0.0, dz + 0.12, y: top, yaw: 186), seed: seed &+ 12, state: "open")
        scene.addLive(Laptop(), at: place(0.2 + desk.x * 0.27, dz + 0.05, y: top, yaw: 200), seed: seed &+ 13, state: "on")
        scene.add(CoffeeMug(), at: place(0.2 + desk.x * 0.05, dz - 0.25, y: top, yaw: 40), seed: seed &+ 14)
        scene.add(PaperStack(), at: place(0.2 - desk.x * 0.12, dz - 0.25, y: top, yaw: 175), seed: seed &+ 15)
        for i in 0..<3 {
            scene.add(HardcoverBook().with { $0.color = [0x5A2A22, 0x22384E, 0x2E4430][i] },
                      at: place(0.2 + desk.x * 0.4, dz - 0.2, y: top + Float(i) * 0.033, yaw: 175 + rng.float(-8...8)), seed: seed &+ UInt64(16 + i), state: "closed")
        }
        // Desk chair behind (window side), visitor club chairs in front.
        scene.addLive(OfficeChair(), at: place(0.25, dz - desk.z / 2 - 0.0 + desk.z + 0.35, yaw: 180 + 10), seed: seed &+ 20, state: "default")
        scene.add(ChesterfieldArmchair(), at: place(-1.6, -1.5, yaw: 35), seed: seed &+ 21)
        // Bookcases on the east wall, storage cupboard by the door.
        let bk = OpenOffice.extent(Bookshelf())
        for (i, z) in [Float(-1.2), -1.2 + bk.x + 0.02].enumerated() {
            scene.add(Bookshelf(), at: place(W / 2 - bk.z / 2 - 0.02, z, yaw: -90), seed: seed &+ UInt64(30 + i))
        }
        let sc = OpenOffice.extent(StorageCabinet())
        scene.add(StorageCabinet().with { $0.color = 0x3A3B3E }, at: place(-W / 2 + sc.x / 2 + 0.3, -D / 2 + sc.z / 2 + 0.02), seed: seed &+ 40, state: "closed")
        scene.add(SnakePlant(), at: place(-W / 2 + 0.45, D / 2 - 0.45, yaw: 20), seed: seed &+ 41)
        scene.add(PedalBin(), at: place(1.6, dz + 0.1), seed: seed &+ 42, state: "closed")
        // Two ceiling downlights as luminaires in the plaster.
        scene.field(CeilingLight(), seed: seed, state: "on", transforms: [place(-1.2, 0, y: H - 0.004).matrix, place(1.6, 0, y: H - 0.004).matrix])

        scene.farGround = "grass.lawn"
        scene.lighting = .init(sky: SunSky(elevation: 9, azimuth: 205, turbidity: 3.0), interior: .warm, fog: 0)
        scene.bake = .interior
        scene.batchStatics = true
        scene.camera = .init(eye: V3(-2.4, 1.6, -1.9), target: V3(0.6, 0.85, 0.9), fov: 62)
        return scene
    }
}
