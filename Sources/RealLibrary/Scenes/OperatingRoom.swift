import simd
import Foundation
import RealityKit
import RealKit

/// General surgery operating room, 7 x 7 m, 3.2 m ceiling, no windows: static-dissipative sheet vinyl,
/// large-format wall tile, operating table at the center under a dual-head LED surgical light, an
/// anesthesia ceiling boom with its vitals monitor and the anesthesia workstation at the head, a draped
/// Mayo stand over the foot, a draped back table with an opened sterilization container and the
/// instrument set (Mayo scissors, Kelly hemostat, needle holder, Adson forceps, scalpel, Weitlaner
/// retractor), IV pole and pump, X-ray viewer, supply cabinet, sharps, waste and double-acting doors.
public struct OperatingRoom: RealSceneBuilder {
    public static let id = "operating-room"
    public static let summary = "Operating room: surgical table under a dual-head LED light, anesthesia boom and workstation, draped Mayo stand and back table with instruments, doors."
    public static let tags = ["hospital", "medical", "interior", "showcase"]
    public static let author = "realityhd"

    public var size = V3(7, 3.2, 7)
    public init() {}

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        let W = size.x, D = size.z, H = size.y
        var room = Room(size: size)
        room.floor = "floor.vinyl-or"
        room.wall = "tile.wall-or"
        room.ceiling = .flat
        room.ceilingMaterial = "paint.hospital:F2F3F2"
        room.skirting = "floor.vinyl-or"
        room.skirtingHeight = 0.15
        let hd = HospitalDoors()
        room.openings.append(.init(.west, offset: 1.6, width: hd.openingWidth + 0.1, sill: 0, head: hd.openingHeight + 0.06))
        scene.add(room.shell(), bake: true)
        scene.add(room.ceilingModel())
        scene.addLive(hd, at: place(-W / 2 - room.wallThickness / 2, 1.6, yaw: 90), seed: seed &+ 1, state: "closed")

        // Laminar-flow ceiling diffuser array over the table (lit panels in a stainless frame).
        var laminar = Model(name: "laminar-ceiling")
        laminar.add(Prim.roundedBox(V3(3.0, 0.04, 3.4), radius: 0.006, bevelSegments: 1, material: "metal.casework"), Xform(translation: V3(0, H - 0.02, 0)))
        for i in 0..<3 { for k in 0..<3 where !(i == 1 && k == 1) {
            laminar.add(cuboid(V3(0.9, 0.006, 1.0), material: "emissive.panel"), Xform(translation: V3(Float(i - 1) * 0.98, H - 0.043, Float(k - 1) * 1.1)))
        }}
        scene.add(laminar)

        // Table at the center under the light; anesthesia at the head (-Z).
        scene.addLive(OperatingTable(), at: place(0, 0.1), seed: seed &+ 2, state: "flat")
        scene.addLive(SurgicalLight().with { $0.mountHeight = H - 0.045 }, at: place(0, 0.1), seed: seed &+ 3, state: "positioned")
        scene.addLive(CeilingBoom().with { $0.mountHeight = H }, at: place(-1.5, -1.9), seed: seed &+ 4, state: "deployed-on")
        scene.addLive(AnesthesiaMachine(), at: place(0.85, -2.25, yaw: 0), seed: seed &+ 5, state: "running")
        scene.addLive(IvPole(), at: place(-0.75, -1.25), seed: seed &+ 6, state: "high-with-bag")
        scene.addLive(InfusionPump(), at: place(-0.75, -1.19, y: 1.05), seed: seed &+ 7, state: "on")
        scene.addLive(DoctorStool(), at: place(0.0, -1.75, yaw: 10), seed: seed &+ 8, state: "high")

        // Scrub side: Mayo stand over the foot, back table along the east side.
        scene.addLive(MayoStand(), at: place(0.25, 1.75, yaw: 180), seed: seed &+ 10, state: "high")
        let bx: Float = 2.2, bz: Float = 1.6, top: Float = 0.86 + 0.003
        scene.add(HospitalFit.backTable(), at: place(bx, bz, yaw: 90))
        scene.addLive(InstrumentContainer(), at: place(bx, bz + 0.35, y: top, yaw: 90), seed: seed &+ 11, state: "open")
        scene.addLive(SurgicalScissors(), at: place(bx - 0.2, bz - 0.2, y: top, yaw: 92), seed: seed &+ 12, state: "closed")
        scene.addLive(Hemostat(), at: place(bx - 0.08, bz - 0.22, y: top, yaw: 88), seed: seed &+ 13, state: "closed-locked")
        scene.addLive(NeedleHolder(), at: place(bx + 0.04, bz - 0.2, y: top, yaw: 91), seed: seed &+ 14, state: "locked-with-needle")
        scene.addLive(TissueForceps(), at: place(bx + 0.16, bz - 0.24, y: top, yaw: 90), seed: seed &+ 15, state: "open")
        scene.addLive(Scalpel(), at: place(bx + 0.27, bz - 0.22, y: top, yaw: 89), seed: seed &+ 16, state: "shielded")
        scene.addLive(WeitlanerRetractor(), at: place(bx - 0.1, bz - 0.55, y: top, yaw: 80), seed: seed &+ 17, state: "closed")
        scene.addLive(Syringe(), at: place(bx + 0.2, bz - 0.55, y: top, yaw: 95), seed: seed &+ 18, state: "full")

        // Walls: X-ray viewer, supply cabinet, sharps and sanitizer; waste and crash cart near the door.
        scene.addLive(XrayViewer(), at: place(0.6, -D / 2 + 0.053, y: 1.3), seed: seed &+ 20, state: "both-on")
        scene.addLive(SupplyCabinet(), at: place(W / 2 - 0.177, -1.4, y: 1.4, yaw: -90), seed: seed &+ 21, state: "closed")
        scene.add(HospitalFit.counter(length: 1.8, doors: 3), at: place(W / 2 - 0.305, -1.4, yaw: -90))
        scene.addLive(SharpsContainer(), at: place(W / 2 - 0.062, 0.2, y: 1.15, yaw: -90), seed: seed &+ 22, state: "closed")
        scene.addLive(SanitizerDispenser(), at: place(-W / 2 + 0.051, 0.3, y: 1.0, yaw: 90), seed: seed &+ 23, state: "idle")
        scene.addLive(BiohazardBin(), at: place(-2.9, 2.9, yaw: 45), seed: seed &+ 24, state: "open")
        scene.addLive(CrashCart(), at: place(-2.9, -2.8, yaw: 90), seed: seed &+ 25, state: "sealed")

        scene.farGround = nil
        scene.lighting = .init(sky: SunSky(elevation: 40, azimuth: 150, turbidity: 2.4), interior: .operatingRoom, fog: 0, sunScale: 0)
        scene.bake = .interior
        scene.batchStatics = true
        scene.camera = .init(eye: V3(2.6, 1.7, 2.9), target: V3(-0.3, 0.9, -0.6), fov: 68)
        return scene
    }
}
