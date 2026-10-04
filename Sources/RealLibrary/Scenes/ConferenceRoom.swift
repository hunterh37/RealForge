import simd
import Foundation
import RealityKit
import RealKit

/// Glass-walled conference room, 7 x 5 m, 2.8 m grid ceiling: walnut boardroom table with eight mesh
/// chairs (some pushed back and turned), laptops, notebooks and mugs, wall display, mobile whiteboard,
/// window wall to the west and a frameless glass partition with door to the corridor.
public struct ConferenceRoom: RealSceneBuilder {
    public static let id = "conference-room"
    public static let summary = "Glass-walled conference room: boardroom table, eight mesh chairs, laptops and notes, wall display, whiteboard, window wall and glass door."
    public static let tags = ["office", "interior", "showcase"]
    public static let author = "realityhd"

    public var size = V3(7, 2.8, 5)
    public init() {}

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 11)
        let W = size.x, D = size.z, H = size.y
        var room = Room(size: size)
        room.floor = "carpet.tile:3E4248"
        let win = OpenOffice.extent(OfficeWindow())
        for z: Float in [-1.4, 0, 1.4] { room.openings.append(.init(.west, offset: z, width: win.x, sill: 0.8, head: 0.8 + win.y)) }
        room.openings.append(.init(.south, offset: 0, width: W - 0.4, sill: 0, head: H - 0.01))
        room.fixtureCells = room.fixturePattern(every: SIMD2(3, 3), inset: 0.9)
        scene.add(room.shell(), bake: true)
        scene.add(room.ceilingModel())
        for (i, op) in room.openings.enumerated() where op.wall == .west {
            scene.add(OfficeWindow(), at: place(-W / 2 - room.wallThickness / 2, op.offset, y: op.sill, yaw: 90), seed: seed &+ UInt64(i), state: i == 1 ? "tilted" : "closed")
        }
        // Glass partition: fixed panels with frosted manifestation band, glass door near the east end.
        var part = Model(name: "partition")
        let zp = D / 2 + room.wallThickness / 2
        let gd = OpenOffice.extent(GlassDoor())
        let doorX = W / 2 - 0.4 - gd.x / 2
        let left = -W / 2 + 0.2, right = doorX - gd.x / 2
        var x = left
        while x < right - 0.01 {
            let nx = min(right, x + 1.6)
            part.add(cuboid(V3(nx - x - 0.004, H - 0.04, 0.012), material: "glass.clear"), Xform(translation: V3((x + nx) / 2, (H - 0.04) / 2 + 0.02, zp)))
            part.add(cuboid(V3(nx - x - 0.004, 0.12, 0.014), material: "glass.frosted"), Xform(translation: V3((x + nx) / 2, 1.2, zp)))
            x = nx
        }
        for (y, h) in [(Float(0.02), Float(0.04)), (H - 0.02, 0.04)] {
            part.add(Prim.roundedBox(V3(right - left, h, 0.05), radius: 0.004, bevelSegments: 1, material: "metal.anodized"), Xform(translation: V3((left + right) / 2, y, zp)))
        }
        scene.add(part)
        scene.addLive(GlassDoor(), at: place(doorX, zp, yaw: 180), seed: seed &+ 5, state: "ajar")

        // Table and chairs.
        let tb = OpenOffice.extent(ConferenceTable())
        scene.add(ConferenceTable(), at: place(0.3, 0, yaw: 0), seed: seed &+ 10)
        let top = tb.y
        var chairs: [simd_float4x4] = []
        for side: Float in [-1, 1] { for k in 0..<3 {
            let x = 0.3 + (Float(k) - 1) * 1.0
            let out = rng.float(0.5...0.85)
            chairs.append(place(x + rng.float(-0.08...0.08), side * (tb.z / 2 + out), yaw: (side > 0 ? 180 : 0) + rng.float(-25...25)).matrix)
        }}
        chairs.append(place(0.3 - tb.x / 2 - 0.6, 0.1, yaw: 90 + rng.float(-15...15)).matrix)
        scene.field(OfficeChair(), seed: seed, state: "default", transforms: chairs)
        scene.addLive(OfficeChair(), at: place(0.3 + tb.x / 2 + 0.7, -0.2, yaw: -90 - 30), seed: seed &+ 20, state: "turned")
        scene.addLive(Laptop(), at: place(-0.7, -0.3, y: top, yaw: 10), seed: seed &+ 21, state: "on")
        scene.add(Laptop(), at: place(1.3, 0.32, y: top, yaw: 175), seed: seed &+ 22, state: "open")
        scene.addLive(HardcoverBook().with { $0.color = 0x1E2A38 }, at: place(0.3, -0.25, y: top, yaw: 5), seed: seed &+ 23, state: "open")
        for (i, p) in [V2(-0.4, 0.3), V2(1.0, -0.3), V2(0.4, 0.35)].enumerated() {
            scene.add(CoffeeMug(), at: place(p.x, p.y, y: top, yaw: rng.float(0...360)), seed: seed &+ UInt64(24 + i))
        }
        scene.add(PaperStack(), at: place(-0.2, 0.32, y: top, yaw: 170), seed: seed &+ 28)
        // Wall display on the east wall: bezel and an active screen.
        var tv = Model(name: "display")
        tv.add(Prim.roundedBox(V3(0.05, 0.98, 1.68), radius: 0.008, bevelSegments: 2, material: "plastic.matte:1A1B1D"), Xform(translation: V3(W / 2 - 0.045, 1.45, 0)))
        var screen = Prim.card(width: 1.62, height: 0.92, cell: (V2(0, 0), V2(1, 1)), material: "screen.ui", normal: V3(-1, 0, 0))
        screen = screen.transformed(Xform(translation: V3(W / 2 - 0.072, 1.45 - 0.46, 0), rotation: simd_quatf(degrees: -90, axis: .up)))
        tv.add(screen)
        scene.add(tv)
        scene.add(Whiteboard(), at: place(W / 2 - 0.8, -D / 2 + 0.7, yaw: -60), seed: seed &+ 30)
        scene.add(SnakePlant(), at: place(-W / 2 + 0.45, -D / 2 + 0.45), seed: seed &+ 31)
        scene.add(SnakePlant(), at: place(W / 2 - 0.45, D / 2 - 0.5), seed: seed &+ 32)
        scene.field(CeilingLight(), seed: seed, state: "on", transforms: room.fixtureCells.sorted { ($0.x, $0.y) < ($1.x, $1.y) }.map {
            let c = room.cellCenter($0); return place(c.x, c.z, y: H).matrix
        })

        scene.farGround = "paving.slab"
        scene.lighting = .init(sky: SunSky(elevation: 30, azimuth: 265, turbidity: 2.4), interior: .office, fog: 0)
        scene.bake = .interior
        scene.batchStatics = true
        scene.camera = .init(eye: V3(2.6, 1.6, 2.0), target: V3(-1.4, 0.9, -0.9), fov: 64)
        return scene
    }
}
