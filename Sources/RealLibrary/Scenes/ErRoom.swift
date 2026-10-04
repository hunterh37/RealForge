import simd
import Foundation
import RealityKit
import RealKit

/// Emergency department treatment room, 6 x 5 m, 3.0 m ceiling: stretcher in Fowler position under a
/// lit headwall with a wall-mounted vitals monitor, IV pole with a running infusion pump and overbed
/// table; the doctor's exam table and rolling stool on the west side; a casework counter on the east
/// wall with the diagnostic kit laid out (stethoscope, otoscope, ophthalmic penlight, thermometer,
/// oximeter, BP set, glucometer, syringe, pill bottle, laryngoscope, chart), a supply cabinet above,
/// sharps and sanitizer, X-ray viewer, crash cart and a privacy curtain across the glazed corridor
/// front. Every device is live; handheld instruments can be picked up.
public struct ErRoom: RealSceneBuilder {
    public static let id = "er-room"
    public static let summary = "ER treatment room: stretcher under a lit headwall, vitals monitor, IV pump, exam table and stool, counter with diagnostic instruments, crash cart, privacy curtain."
    public static let tags = ["hospital", "medical", "interior", "showcase"]
    public static let author = "realityhd"

    public var size = V3(6, 3.0, 5)
    public init() {}

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        let W = size.x, D = size.z, H = size.y
        var room = Room(size: size)
        room.floor = "floor.vinyl"
        room.wall = "paint.hospital:DCE4E2"
        room.ceiling = .grid(pitch: 0.6)
        room.skirting = "rubber:4A4C4E"
        room.skirtingHeight = 0.1
        // Glazed corridor front (south) with a 1.2 m sliding-door gap.
        room.openings.append(.init(.south, offset: 0.4, width: 3.6, sill: 0, head: 2.4))
        room.fixtureCells = room.fixturePattern(every: SIMD2(3, 3), inset: 0.9)
        scene.add(room.shell(), bake: true)
        scene.add(room.ceilingModel())
        var front = Model(name: "er-front")
        let zf = D / 2 + room.wallThickness / 2
        for (x0, x1) in [(Float(-1.4), Float(-0.15)), (Float(1.05), Float(2.2))] {
            front.add(cuboid(V3(x1 - x0 - 0.05, 2.3, 0.012), material: "glass.frosted"), Xform(translation: V3((x0 + x1) / 2, 1.2, zf)))
        }
        for x: Float in [-1.4, -0.15, 1.05, 2.2] {
            front.add(Prim.roundedBox(V3(0.05, 2.4, 0.12), radius: 0.004, bevelSegments: 1, material: "metal.anodized"), Xform(translation: V3(x, 1.2, zf)))
        }
        front.add(Prim.roundedBox(V3(3.6, 0.06, 0.12), radius: 0.004, bevelSegments: 1, material: "metal.anodized"), Xform(translation: V3(0.4, 2.37, zf)))
        scene.add(front)

        // Patient bay: headwall on the north wall, stretcher head to the wall.
        scene.addLive(Headwall(), at: place(0, -D / 2 + 0.08, y: 1.15), seed: seed &+ 1, state: "reading-light")
        scene.addLive(ErStretcher(), at: place(0, -D / 2 + 0.28 + 1.02, yaw: -90), seed: seed &+ 2, state: "fowler")
        scene.addLive(PatientMonitor(), at: place(1.55, -D / 2 + 0.11, y: 1.55), seed: seed &+ 3, state: "on")
        scene.addLive(IvPole(), at: place(-0.85, -1.15), seed: seed &+ 4, state: "high-with-bag")
        scene.addLive(InfusionPump(), at: place(-0.85, -1.09, y: 1.05), seed: seed &+ 5, state: "on")
        scene.addLive(OverbedTable(), at: place(0.95, -0.55, yaw: 90), seed: seed &+ 6, state: "high")
        scene.addLive(PrivacyCurtain(), at: place(0.4, D / 2 - 0.35, y: 0.3), seed: seed &+ 7, state: "half")

        // Doctor's exam table along the west wall, stool and scale beside it, X-ray viewer above.
        scene.addLive(ExamTable(), at: place(-W / 2 + 0.36, 0.95, yaw: 90), seed: seed &+ 10, state: "sitting")
        scene.addLive(DoctorStool(), at: place(-1.75, 1.75, yaw: -60), seed: seed &+ 11, state: "high")
        scene.addLive(XrayViewer(), at: place(-W / 2 + 0.053, -1.2, y: 1.3, yaw: 90), seed: seed &+ 12, state: "both-on")
        scene.addLive(MedicalScale(), at: place(-W / 2 + 0.35, -D / 2 + 0.4, yaw: 45), seed: seed &+ 13, state: "zeroed")

        // East counter with the diagnostic kit, supply cabinet and sharps above.
        let cx = W / 2 - 0.305, cz: Float = -0.4, top: Float = 0.91
        scene.add(HospitalFit.counter(length: 2.6), at: place(cx, cz, yaw: -90))
        scene.addLive(SupplyCabinet(), at: place(W / 2 - 0.177, cz - 0.55, y: 1.45, yaw: -90), seed: seed &+ 20, state: "left-open")
        scene.addLive(SharpsContainer(), at: place(W / 2 - 0.062, cz + 0.75, y: 1.2, yaw: -90), seed: seed &+ 21, state: "open")
        scene.addLive(SanitizerDispenser(), at: place(W / 2 - 0.051, D / 2 - 0.5, y: 1.0, yaw: -90), seed: seed &+ 22, state: "idle")
        // Kit along the counter (x across the depth, z along the run).
        let kx = cx + 0.05
        scene.addLive(Stethoscope(), at: place(kx, cz - 1.05, y: top, yaw: 20), seed: seed &+ 30, state: "resting")
        scene.addLive(Sphygmomanometer(), at: place(kx - 0.05, cz - 0.7, y: top, yaw: -80), seed: seed &+ 31, state: "deflated")
        scene.addLive(Otoscope(), at: place(kx + 0.12, cz - 0.42, y: top, yaw: 90), seed: seed &+ 32, state: "on")
        scene.addLive(Penlight(), at: place(kx - 0.12, cz - 0.4, y: top, yaw: 10), seed: seed &+ 33, state: "off")
        scene.addLive(ReflexHammer(), at: place(kx - 0.14, cz - 0.25, y: top, yaw: -5), seed: seed &+ 34, state: "stowed")
        scene.addLive(TympanicThermometer(), at: place(kx + 0.1, cz - 0.15, y: top, yaw: 70), seed: seed &+ 35, state: "reading")
        scene.addLive(PulseOximeter(), at: place(kx - 0.05, cz - 0.02, y: top, yaw: -90), seed: seed &+ 36, state: "on")
        scene.addLive(Glucometer(), at: place(kx + 0.1, cz + 0.12, y: top, yaw: -70), seed: seed &+ 37, state: "reading")
        scene.addLive(Syringe(), at: place(kx - 0.12, cz + 0.22, y: top, yaw: 15), seed: seed &+ 38, state: "drawn-5ml")
        scene.addLive(PillBottle(), at: place(kx + 0.12, cz + 0.36, y: top), seed: seed &+ 39, state: "open")
        scene.addLive(Laryngoscope(), at: place(kx - 0.05, cz + 0.52, y: top, yaw: 80), seed: seed &+ 40, state: "folded")
        scene.addLive(ClipboardChart(), at: place(kx, cz + 0.85, y: top, yaw: -90), seed: seed &+ 41, state: "open")

        // Code cart by the door, waste by the counter.
        scene.addLive(CrashCart(), at: place(W / 2 - 0.4, D / 2 - 1.3, yaw: -90), seed: seed &+ 50, state: "sealed")
        scene.addLive(BiohazardBin(), at: place(-1.0, -D / 2 + 0.35), seed: seed &+ 51, state: "closed")
        scene.addLive(Aed(), at: place(W / 2 - 0.4, D / 2 - 1.3, y: 1.38, yaw: -90), seed: seed &+ 52, state: "closed")

        scene.field(CeilingLight(), seed: seed, state: "on", transforms: room.fixtureCells.sorted { ($0.x, $0.y) < ($1.x, $1.y) }.map {
            let c = room.cellCenter($0); return place(c.x, c.z, y: H).matrix
        })
        scene.farGround = nil
        scene.lighting = .init(sky: SunSky(elevation: 40, azimuth: 150, turbidity: 2.4), interior: .clinical, fog: 0)
        scene.bake = .interior
        scene.batchStatics = true
        scene.camera = .init(eye: V3(2.1, 1.62, 2.2), target: V3(-1.2, 0.95, -0.8), fov: 72)
        return scene
    }
}
