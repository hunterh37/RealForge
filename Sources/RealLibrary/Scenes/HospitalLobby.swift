import simd
import Foundation
import RealityKit
import RealKit

/// Emergency department waiting and intake lobby, 16 x 12 m, 3.6 m ceiling: glazed street front with a
/// glass entrance door, sand sheet-vinyl floor, intake nurse station, two self check-in kiosks, rows of
/// beam seating facing a wall of wayfinding signs, a wheelchair by the door, sanitizer stations and
/// double-acting doors into the treatment corridor. Kiosks, doors, wheelchair and seating arms are live.
public struct HospitalLobby: RealSceneBuilder {
    public static let id = "hospital-lobby"
    public static let summary = "ER waiting and intake lobby: glazed entrance, intake nurse station, check-in kiosks, beam seating rows, wheelchair, sanitizer stations and doors to treatment."
    public static let tags = ["hospital", "medical", "interior", "showcase"]
    public static let author = "realityhd"

    public var size = V3(16, 3.6, 12)
    public init() {}

    /// North wall doors into the treatment corridor (x offset).
    public static let doorX: Float = 0

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 21)
        let W = size.x, D = size.z, H = size.y
        var room = Room(size: size)
        room.floor = "floor.vinyl-sand"
        room.wall = "paint.hospital:E4E2DA"
        room.ceiling = .grid(pitch: 0.6)
        room.skirting = "rubber"
        room.skirtingHeight = 0.1
        let gd = OpenOffice.extent(GlassDoor())
        room.openings.append(.init(.south, offset: 0, width: W - 2.0, sill: 0, head: H - 0.5))
        let hd = HospitalDoors()
        room.openings.append(.init(.north, offset: Self.doorX, width: hd.openingWidth + 0.1, sill: 0, head: hd.openingHeight + 0.06))
        room.fixtureCells = room.fixturePattern(every: SIMD2(4, 4), inset: 1.2)
        scene.add(room.shell(), bake: true)
        scene.add(room.ceilingModel())

        // Storefront glazing in ~2 m bays with the glass door in the middle bay.
        var glazing = Model(name: "glazing")
        let zf = D / 2 + room.wallThickness / 2, span = W - 2.0, gh = H - 0.5
        var lines: [Float] = [-gd.x / 2, gd.x / 2]
        let side = span / 2 - gd.x / 2
        let n = max(1, Int((side / 2.0).rounded()))
        for k in 0...n { let o = gd.x / 2 + side * Float(k) / Float(n); lines += [o, -o] }
        lines = Array(Set(lines.map { ($0 * 1000).rounded() / 1000 })).sorted()
        for (a, b) in zip(lines, lines.dropFirst()) where abs((a + b) / 2) > gd.x / 2 {
            glazing.add(cuboid(V3(b - a - 0.06, gh - 0.1, 0.012), material: "glass.clear"), Xform(translation: V3((a + b) / 2, gh / 2, zf)))
        }
        for x in lines {
            glazing.add(Prim.roundedBox(V3(0.06, gh, 0.16), radius: 0.005, bevelSegments: 1, material: "metal.anodized"), Xform(translation: V3(x, gh / 2, zf)))
        }
        glazing.add(Prim.roundedBox(V3(span, 0.1, 0.18), radius: 0.005, bevelSegments: 1, material: "metal.anodized"), Xform(translation: V3(0, gh - 0.05, zf)))
        glazing.add(Prim.roundedBox(V3(gd.x + 0.08, 0.08, 0.18), radius: 0.005, bevelSegments: 1, material: "metal.anodized"), Xform(translation: V3(0, gd.y + 0.04, zf)))
        glazing.add(cuboid(V3(gd.x, gh - gd.y - 0.18, 0.012), material: "glass.clear"), Xform(translation: V3(0, (gd.y + 0.08 + gh - 0.1) / 2, zf)))
        scene.add(glazing)
        scene.addLive(GlassDoor(), at: place(0, zf, yaw: 180), seed: seed &+ 1, state: "closed")
        // Walk-off entrance mat inside the door.
        var mat = Model(name: "entrance-mat")
        mat.add(Prim.roundedBox(V3(2.4, 0.012, 1.8), radius: 0.004, bevelSegments: 1, material: "carpet.tile:3A3C40"), Xform(translation: V3(0, 0.006, 0)))
        scene.add(mat, at: place(0, D / 2 - 1.1))

        // Treatment doors in the north wall, with a sign above and sanitizer stations either side.
        let zn = -D / 2 - room.wallThickness / 2
        scene.addLive(hd, at: place(Self.doorX, zn), seed: seed &+ 2, state: "closed")
        scene.add(HospitalFit.sign(width: 1.4, height: 0.3, label: "label.hazard"), at: place(Self.doorX, -D / 2, y: hd.openingHeight + 0.35))
        for sx: Float in [-1, 1] {
            scene.addLive(SanitizerDispenser(), at: place(Self.doorX + sx * 1.45, -D / 2 + 0.052, y: 1.0), seed: seed &+ UInt64(3 + Int(sx + 1)), state: "idle")
        }

        // Intake nurse station in the north-east, visitor side facing the waiting room.
        scene.addLive(NurseStation(), at: place(4.6, -3.0), seed: seed &+ 10, state: "screens-on", interactive: true)
        scene.add(OfficeChair(), at: place(4.2, -4.0, yaw: 190), seed: seed &+ 11, state: "default")
        scene.add(OfficeChair(), at: place(5.6, -3.9, yaw: 170), seed: seed &+ 12, state: "turned")
        scene.add(HospitalFit.sign(width: 1.2, height: 0.28), at: place(4.6, -D / 2, y: 2.3))

        // Self check-in kiosks inside the entrance, screens toward arrivals.
        scene.addLive(CheckInKiosk(), at: place(2.6, 2.6, yaw: 0), seed: seed &+ 13, state: "on")
        scene.addLive(CheckInKiosk(), at: place(3.5, 2.6, yaw: 0), seed: seed &+ 14, state: "printing")

        // Waiting area: benches facing east toward intake, in three bays.
        for (c, x) in [Float(-6.2), -4.0, -1.8].enumerated() {
            for (r, z) in [Float(-1.6), 1.2].enumerated() {
                let st = (r + c) % 3 == 1 ? "arms-up" : (r == 1 && c == 0 ? "tablet-down" : "default")
                scene.addLive(BeamSeating(), at: place(x, z, yaw: 90), seed: seed &+ UInt64(20 + r * 3 + c), state: st)
            }
        }
        // Wayfinding signs on the west half of the north wall.
        for (i, x) in [Float(-5.6), -3.6, -1.9].enumerated() {
            scene.add(HospitalFit.sign(width: 1.0, height: 0.55, label: i == 1 ? "label.rx" : "label.hazard"), at: place(x, -D / 2, y: 1.75))
        }
        scene.addLive(Wheelchair(), at: place(-6.6, 4.6, yaw: 120), seed: seed &+ 30, state: "brakes-on")
        scene.addLive(Wheelchair(), at: place(-7.2, 3.9, yaw: 110), seed: seed &+ 31, state: "ready")
        scene.addLive(BiohazardBin(), at: place(7.4, -1.0, yaw: -90), seed: seed &+ 32, state: "closed")
        scene.addLive(SanitizerDispenser(), at: place(-W / 2 + 0.052, 4.0, y: 1.0, yaw: 90), seed: seed &+ 33, state: "idle")
        for (i, p) in [V2(-W / 2 + 0.6, D / 2 - 0.7), V2(W / 2 - 0.6, D / 2 - 0.7), V2(-W / 2 + 0.6, -D / 2 + 0.7), V2(W / 2 - 0.6, 0.6)].enumerated() {
            scene.add(SnakePlant(), at: place(p.x, p.y, yaw: rng.float(0...360), scale: 1.25), seed: seed &+ UInt64(40 + i))
        }

        // Troffers in the lay-in grid.
        var lights: [simd_float4x4] = []
        for c in room.fixtureCells { lights.append(place(room.cellCenter(c).x, room.cellCenter(c).z, y: H).matrix) }
        if !lights.isEmpty { scene.field(CeilingLight(), seed: seed, state: "on", transforms: lights) }

        scene.farGround = "paving.slab"
        scene.lighting = .init(sky: SunSky(elevation: 34, azimuth: 165, turbidity: 2.4), interior: .clinical, fog: 0)
        scene.bake = .interior
        scene.batchStatics = true
        scene.camera = .init(eye: V3(6.2, 1.65, 4.4), target: V3(-3.0, 1.1, -2.2), fov: 70)
        return scene
    }
}
