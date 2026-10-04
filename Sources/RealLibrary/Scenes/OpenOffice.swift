import simd
import Foundation
import RealityKit
import RealKit

/// Open-plan office floor, 18 x 12 m, 2.8 m suspended ceiling: ribbon of tilt-turn windows along the
/// south wall with afternoon sun across the carpet, three benches of back-to-back desks with task chairs,
/// monitors, keyboards, pedestals and desk clutter, filing cabinets and a storage cupboard along the north
/// wall by the door, LED troffers in the grid, plants, a water cooler and a mobile whiteboard.
/// Repeated items are instanced; the shell, cabinets and clutter are batched; the AO bake darkens the
/// carpet under every desk. Doors, drawers, a chair, a laptop and a window stay live (tap to toggle).
public struct OpenOffice: RealSceneBuilder {
    public static let id = "open-office"
    public static let summary = "Open-plan office floor with ribbon windows, bench desks, task chairs, screens, filing cabinets and LED ceiling, lit by sun and interior probe."
    public static let tags = ["office", "interior", "showcase"]
    public static let author = "realityhd"

    public var size = V3(18, 2.8, 12)
    public init() {}

    /// Size of an asset's LOD0 bounds.
    static func extent<A: RealAsset>(_ a: A) -> V3 { let b = a.build(seed: 1).levels[0].bounds; return b.max - b.min }

    public func room() -> Room {
        var r = Room(size: size)
        let win = Self.extent(OfficeWindow())
        // Ribbon windows on the south wall between 0.3 m piers, sill 0.85 m.
        let pitch = win.x + 0.3
        var x = -size.x / 2 + 0.45 + win.x / 2
        while x + win.x / 2 < size.x / 2 - 0.3 { r.openings.append(.init(.south, offset: x, width: win.x, sill: 0.85, head: 0.85 + win.y)); x += pitch }
        let door = Self.extent(OfficeDoor())
        r.openings.append(.init(.north, offset: size.x / 2 - 1.6, width: door.x, sill: 0, head: door.y))
        r.columns = [V2(-2.8, 0), V2(2.8, 0)]
        r.fixtureCells = r.fixturePattern(every: SIMD2(4, 3), inset: 1.2)
        return r
    }

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 4)
        let room = room()
        let W = size.x, D = size.z, H = size.y
        scene.add(room.shell(), bake: true)
        scene.add(room.ceilingModel())

        // Windows and the door in their openings (walls are 0.2 m; units sit mid-wall, interior side +Z).
        for (i, op) in room.openings.enumerated() where op.wall == .south {
            let at = place(op.offset, D / 2 + room.wallThickness / 2, y: op.sill, yaw: 180)
            if i == 4 { scene.addLive(OfficeWindow(), at: at, seed: seed &+ UInt64(i), state: "tilted") }
            else { scene.add(OfficeWindow(), at: at, seed: seed &+ UInt64(i), state: "closed") }
        }
        if let d = room.openings.first(where: { $0.wall == .north }) {
            scene.addLive(OfficeDoor(), at: place(d.offset, -D / 2 - room.wallThickness / 2, yaw: 0), seed: seed &+ 20, state: "ajar")
        }

        // Ceiling luminaires in the open grid cells.
        scene.field(CeilingLight(), seed: seed, state: "on", transforms: room.fixtureCells.sorted { ($0.x, $0.y) < ($1.x, $1.y) }.map {
            let c = room.cellCenter($0); return place(c.x, c.z, y: H).matrix
        })

        // Desk benches: back-to-back pairs along X, three benches of three desks per side.
        let desk = Self.extent(OfficeDesk())
        let top = desk.y
        var chairs: [simd_float4x4] = [], monitors: [simd_float4x4] = [], keyboards: [simd_float4x4] = [], pedestals: [simd_float4x4] = []
        var deskXf: [simd_float4x4] = []
        var liveChair = true, liveLaptop = true
        for benchZ: Float in [-2.4, 2.3] {
            for group: Float in [-1, 0, 1] {
                for k in 0..<3 {
                    let x = group * 5.4 + (Float(k) - 1) * desk.x
                    for facing: Float in [1, -1] {       // +1: user sits at +Z side of the pair
                        let z = benchZ + facing * desk.z / 2
                        let yaw: Float = facing > 0 ? 0 : 180
                        let toUser = V3(0, 0, facing)
                        deskXf.append(place(x, z, yaw: yaw).matrix)
                        let p = V3(x, top, z)
                        // Screen at the back, keyboard in front, clutter.
                        let mp = p - toUser * (desk.z * 0.28)
                        if rng.chance(0.82) { monitors.append(place(mp.x + rng.float(-0.05...0.05), mp.z, y: top, yaw: yaw + rng.float(-6...6)).matrix) }
                        else if liveLaptop && benchZ > 0 && group == -1 {
                            scene.addLive(Laptop(), at: place(x, z + facing * 0.05, y: top, yaw: yaw + 4), seed: seed &+ 31, state: "on"); liveLaptop = false
                        } else { scene.add(Laptop(), at: place(x, z + facing * 0.05, y: top, yaw: yaw + rng.float(-15...15)), seed: seed &+ 32, state: rng.chance(0.5) ? "on" : "closed") }
                        let kp = p + toUser * (desk.z * 0.18)
                        keyboards.append(place(kp.x + rng.float(-0.04...0.04), kp.z, y: top, yaw: yaw + rng.float(-4...4)).matrix)
                        if rng.chance(0.6) {
                            scene.add(CoffeeMug(), at: place(x + desk.x * 0.33, z + facing * rng.float(0...0.15), y: top, yaw: rng.float(0...360)), seed: seed &+ UInt64(rng.int(0...5)))
                        }
                        if rng.chance(0.45) {
                            scene.add(PaperStack(), at: place(x - desk.x * 0.32, z - facing * 0.05, y: top, yaw: yaw + rng.float(-20...20)), seed: seed &+ UInt64(rng.int(0...5)))
                        }
                        pedestals.append(place(x + desk.x * 0.27, z - facing * 0.06, yaw: yaw).matrix)
                        // Chair: pushed in or pulled out and turned.
                        let out = rng.float(0.42...0.75), turn = rng.float(-35...35)
                        let cz = z + facing * out
                        if liveChair && benchZ > 0 && group == -1 && k == 0 {
                            scene.addLive(OfficeChair(), at: place(x, cz, yaw: yaw + 180 + turn), seed: seed &+ 40, state: "default"); liveChair = false
                        } else { chairs.append(place(x + rng.float(-0.1...0.1), cz, yaw: yaw + 180 + turn).matrix) }
                    }
                }
            }
        }
        scene.field(OfficeDesk(), seed: seed, transforms: deskXf, options: .props)
        scene.field(OfficeChair(), seed: seed, state: "default", transforms: chairs)
        scene.field(DesktopMonitor(), seed: seed, state: "on", transforms: monitors)
        scene.field(KeyboardMouse(), seed: seed, transforms: keyboards, options: .props)
        scene.field(DeskPedestal(), seed: seed, state: "closed", transforms: pedestals)

        // North wall: filing cabinets, storage cupboard, water cooler; plants and whiteboard.
        let fc = Self.extent(FilingCabinet())
        for i in 0..<4 {
            let x = -W / 2 + 1.2 + Float(i) * (fc.x + 0.01)
            let at = place(x, -D / 2 + fc.z / 2 + 0.02)
            if i == 1 { scene.addLive(FilingCabinet(), at: at, seed: seed &+ UInt64(50 + i), state: "drawer2-open") }
            else { scene.add(FilingCabinet(), at: at, seed: seed &+ UInt64(50 + i), state: "closed") }
        }
        let sc = Self.extent(StorageCabinet())
        scene.add(StorageCabinet(), at: place(-W / 2 + 1.2 + 4 * (fc.x + 0.01) + sc.x / 2 + 0.1, -D / 2 + sc.z / 2 + 0.02), seed: seed &+ 60, state: "closed")
        scene.add(WaterCooler(), at: place(W / 2 - 3.2, -D / 2 + 0.3, yaw: rng.float(-5...5)), seed: seed &+ 61)
        for (i, p) in [V2(-W / 2 + 0.5, D / 2 - 0.5), V2(W / 2 - 0.5, D / 2 - 0.5), V2(-2.8, 0.55), V2(2.8, -0.55), V2(W / 2 - 0.5, -D / 2 + 0.6)].enumerated() {
            scene.add(SnakePlant(), at: place(p.x, p.y, yaw: rng.float(0...360)), seed: seed &+ UInt64(70 + i))
        }
        scene.add(Whiteboard(), at: place(W / 2 - 1.4, 0.2, yaw: -100), seed: seed &+ 80)
        scene.add(PedalBin(), at: place(W / 2 - 2.6, -D / 2 + 0.3), seed: seed &+ 81, state: "closed")

        scene.farGround = "paving.slab"
        scene.lighting = .init(sky: SunSky(elevation: 24, azimuth: 200, turbidity: 2.4), interior: .office, fog: 0)
        scene.bake = .interior
        scene.batchStatics = true
        scene.camera = .init(eye: V3(-8.2, 1.62, 4.9), target: V3(1.5, 1.0, -2.5), fov: 62)
        return scene
    }
}
