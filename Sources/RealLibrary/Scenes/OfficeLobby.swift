import simd
import Foundation
import RealityKit
import RealKit

/// Ground-floor office lobby, 16 x 10 m, 4.5 m ceiling: glazed street front with a frameless glass door,
/// terrazzo floor, black-marble and walnut reception counter, a lift lobby of two elevator entrances in a
/// marble feature wall (one arriving), leather sofas and planters. Elevators, door and laptop are live.
public struct OfficeLobby: RealSceneBuilder {
    public static let id = "office-lobby"
    public static let summary = "Office lobby: glazed street front with glass door, terrazzo floor, marble reception desk, elevator bank, leather sofas and planters."
    public static let tags = ["office", "interior", "showcase"]
    public static let author = "realityhd"

    public var size = V3(16, 4.5, 10)
    public init() {}

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 9)
        let W = size.x, D = size.z, H = size.y
        var room = Room(size: size)
        room.floor = "stone.terrazzo"
        room.ceiling = .flat
        room.wall = "paint.wall:E2DED6"
        room.skirting = "metal.stainless"
        room.skirtingHeight = 0.06
        // Street front: full-height glazing in 2 m bays with the glass door bay in the middle.
        let gd = OpenOffice.extent(GlassDoor())
        room.openings.append(.init(.south, offset: 0, width: W - 1.0, sill: 0, head: H - 0.6))
        let el = OpenOffice.extent(ElevatorDoors())
        let lifts: [Float] = [-2.2, 2.2]
        for x in lifts { room.openings.append(.init(.north, offset: x, width: el.x, sill: 0, head: el.y)) }
        scene.add(room.shell(), bake: true)
        scene.add(room.ceilingModel())

        // Curtain glazing in the south opening, mullions every 2 m, glass door in the middle bay.
        var glazing = Model(name: "glazing")
        let zf = D / 2 + room.wallThickness / 2
        let span = W - 1.0, gh = H - 0.6
        let doorW = gd.x
        // Mullion lines every ~2 m, snapped so the door bay is clear.
        var lines: [Float] = [-doorW / 2, doorW / 2]
        let side = span / 2 - doorW / 2
        let n = max(1, Int((side / 2.0).rounded()))
        for k in 0...n { let o = doorW / 2 + side * Float(k) / Float(n); lines += [o, -o] }
        lines = Array(Set(lines.map { ($0 * 1000).rounded() / 1000 })).sorted()
        for (a, b) in zip(lines, lines.dropFirst()) where abs((a + b) / 2) > doorW / 2 {
            glazing.add(cuboid(V3(b - a - 0.08, gh - 0.1, 0.012), material: "glass.clear"), Xform(translation: V3((a + b) / 2, gh / 2, zf)))
        }
        for x in lines {
            glazing.add(Prim.roundedBox(V3(0.08, gh, 0.18), radius: 0.006, bevelSegments: 1, material: "metal.anodized-black"), Xform(translation: V3(x, gh / 2, zf)))
        }
        glazing.add(Prim.roundedBox(V3(span, 0.1, 0.2), radius: 0.006, bevelSegments: 1, material: "metal.anodized-black"), Xform(translation: V3(0, gh - 0.05, zf)))
        glazing.add(Prim.roundedBox(V3(doorW + 0.1, 0.1, 0.2), radius: 0.006, bevelSegments: 1, material: "metal.anodized-black"), Xform(translation: V3(0, gd.y + 0.05, zf)))
        glazing.add(cuboid(V3(doorW, gh - gd.y - 0.2, 0.012), material: "glass.clear"), Xform(translation: V3(0, (gd.y + 0.1 + gh - 0.1) / 2, zf)))
        scene.add(glazing)
        scene.addLive(GlassDoor(), at: place(0, zf, yaw: 180), seed: seed &+ 1, state: "closed")

        // Marble feature wall around the lifts (panels in front of the north wall, lift openings kept clear).
        var feature = Model(name: "feature-wall")
        let fz = -D / 2 + 0.02
        var px: Float = -6
        while px < 6 - 0.01 {
            let pw: Float = 1.2
            let c = px + pw / 2
            let clear = lifts.contains { abs(c - $0) < el.x / 2 + pw / 2 - 0.05 }
            if !clear {
                feature.add(Prim.roundedBox(V3(pw - 0.006, H - 0.2, 0.03), radius: 0.003, bevelSegments: 1, material: "stone.marble"), Xform(translation: V3(c, (H - 0.2) / 2, fz)))
            } else {
                feature.add(Prim.roundedBox(V3(pw - 0.006, H - 0.2 - el.y, 0.03), radius: 0.003, bevelSegments: 1, material: "stone.marble"), Xform(translation: V3(c, el.y + (H - 0.2 - el.y) / 2, fz)))
            }
            px += pw
        }
        scene.add(feature, bake: true)
        for (i, x) in lifts.enumerated() {
            scene.addLive(ElevatorDoors(), at: place(x, -D / 2 - ElevatorDoors().wallFaceZ + 0.032), seed: seed &+ UInt64(5 + i), state: i == 0 ? "arriving" : "called")
        }

        // Reception counter facing the entrance, laptop and lamp behind it.
        let rd = OpenOffice.extent(ReceptionDesk())
        scene.add(ReceptionDesk(), at: place(4.2, -0.6, yaw: 0), seed: seed &+ 10)
        scene.addLive(Laptop(), at: place(4.4, -0.6 - rd.z * 0.25, y: 0.74, yaw: 180), seed: seed &+ 11, state: "on")
        scene.add(OfficeChair(), at: place(4.4, -0.6 - rd.z / 2 - 0.45, yaw: 10), seed: seed &+ 12, state: "default")
        scene.add(DesktopMonitor(), at: place(3.6, -0.6 - rd.z * 0.25, y: 0.74, yaw: 185), seed: seed &+ 13, state: "on")

        // Waiting area: two sofas facing across a low marble table, planters.
        scene.add(LobbySofa(), at: place(-4.8, 1.0, yaw: 90), seed: seed &+ 20)
        scene.add(LobbySofa(), at: place(-2.4, 1.0, yaw: -90), seed: seed &+ 21)
        var table = Model(name: "coffee-table")
        table.add(Prim.roundedBox(V3(1.2, 0.04, 0.6), radius: 0.008, bevelSegments: 2, material: "stone.marble-dark"), Xform(translation: V3(0, 0.38, 0)))
        for sx: Float in [-1, 1] {
            table.add(Prim.roundedBox(V3(0.04, 0.36, 0.5), radius: 0.004, bevelSegments: 1, material: "metal.stainless"), Xform(translation: V3(sx * 0.5, 0.18, 0)))
        }
        groundAO(&table, height: 0.1)
        scene.add(table, at: place(-3.6, 1.0, yaw: 90))
        scene.add(HardcoverBook().with { $0.color = 0x2A2A2A }, at: place(-3.6, 1.15, y: 0.4, yaw: 80), seed: seed &+ 22, state: "closed")
        for (i, p) in [V2(-W / 2 + 0.6, D / 2 - 0.7), V2(W / 2 - 0.6, D / 2 - 0.7), V2(-W / 2 + 0.6, -D / 2 + 0.7), V2(-0.0, -D / 2 + 0.7), V2(W / 2 - 0.6, -D / 2 + 0.7)].enumerated() {
            scene.add(SnakePlant(), at: place(p.x, p.y, yaw: rng.float(0...360), scale: 1.3), seed: seed &+ UInt64(30 + i))
        }

        // Downlights in the plaster ceiling.
        var lights: [simd_float4x4] = []
        for gx in stride(from: -6, through: 6, by: 3) as StrideThrough<Float> { for gz in stride(from: -3, through: 3, by: 3) as StrideThrough<Float> {
            lights.append(place(gx, gz, y: H - 0.004).matrix)
        }}
        scene.field(CeilingLight(), seed: seed, state: "on", transforms: lights)

        scene.farGround = "paving.slab"
        scene.lighting = .init(sky: SunSky(elevation: 38, azimuth: 170, turbidity: 2.2), interior: .lobby, fog: 0)
        scene.bake = .interior
        scene.batchStatics = true
        scene.camera = .init(eye: V3(-0.5, 1.65, 4.2), target: V3(0.6, 1.4, -4.5), fov: 66)
        return scene
    }
}
