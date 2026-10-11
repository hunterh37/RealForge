import simd
import Foundation
import RealityKit
import RealKit

/// Emergency department floor composed from the hospital rooms: the waiting and intake lobby opens
/// through double-acting doors into a 3.2 m treatment corridor; an ER treatment room opens off its west
/// side and an operating room off its east side, with a scrub sink, parked stretcher, wheelchair, IV
/// pole, crash cart and sanitizer stations along the corridor walls.
public struct HospitalFloor: RealSceneBuilder {
    public static let id = "hospital"
    public static let summary = "Full ER floor: waiting lobby, treatment corridor with scrub sink and parked equipment, ER treatment room and operating room, parked bed and oxygen, all doors and devices live."
    public static let tags = ["hospital", "medical", "interior", "showcase"]
    public static let author = "realityhd"

    public init() {}

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        let lobby = HospitalLobby(), er = ErRoom(), or = OperatingRoom()
        let t: Float = 0.2                                    // wall thickness
        let cW: Float = 3.2, cH: Float = 3.0, cL: Float = 16
        let lobbyNorth = -lobby.size.z / 2 - t                // outer face of the lobby north wall
        let cz = lobbyNorth - t - cL / 2                      // corridor center (walls back to back)
        let erZ = cz + 2.6, orZ = cz - 3.0

        scene.merge(lobby.build(seed: seed), at: .identity)

        // Corridor shell with holes for the lobby doors, the ER front and the OR doors.
        var corridor = Room(size: V3(cW, cH, cL))
        corridor.floor = "floor.vinyl"
        corridor.wall = "paint.hospital:E6E8E2"
        corridor.skirting = "rubber:4A4C4E"
        corridor.skirtingHeight = 0.1
        let hd = HospitalDoors()
        corridor.openings.append(.init(.south, offset: HospitalLobby.doorX, width: hd.openingWidth + 0.1, sill: 0, head: hd.openingHeight + 0.06))
        // The ER room is turned so its glazed front (local south) faces east into the corridor.
        corridor.openings.append(.init(.west, offset: erZ - cz - 0.4, width: 3.6, sill: 0, head: 2.4))
        corridor.openings.append(.init(.east, offset: orZ - cz + 1.6, width: hd.openingWidth + 0.1, sill: 0, head: hd.openingHeight + 0.06))
        corridor.fixtureCells = corridor.fixturePattern(every: SIMD2(2, 4), inset: 0.6)
        let at = place(0, cz)
        scene.add(corridor.shell(), at: at, bake: true)
        scene.add(corridor.ceilingModel(), at: at)
        scene.field(CeilingLight(), seed: seed, state: "on", transforms: corridor.fixtureCells.sorted { ($0.x, $0.y) < ($1.x, $1.y) }.map {
            let c = corridor.cellCenter($0); return place(c.x, c.z + cz, y: cH).matrix
        })
        // Crash rail along both walls.
        var rail = Model(name: "crash-rail")
        for sx: Float in [-1, 1] {
            rail.add(Prim.roundedBox(V3(0.03, 0.14, cL - 0.4), radius: 0.012, bevelSegments: 2, material: "vinyl.medical:B8B4AA"), Xform(translation: V3(sx * (cW / 2 - 0.015), 0.9, 0)))
        }
        scene.add(rail, at: at)

        // ER room west of the corridor, OR east of it.
        scene.merge(er.build(seed: seed &+ 100), at: place(-cW / 2 - 2 * t - er.size.z / 2, erZ, yaw: 90))
        scene.merge(or.build(seed: seed &+ 200), at: place(cW / 2 + 2 * t + or.size.x / 2, orZ))

        // Corridor dressing: scrub sink outside the OR, parked stretcher, wheelchair, IV pole, cart.
        scene.addLive(ScrubSink(), at: place(cW / 2 - 0.34, orZ + 0.4, yaw: -90), seed: seed &+ 1, state: "left-running")
        scene.addLive(ErStretcher(), at: place(-cW / 2 + 0.5, cz - 6.2, yaw: 180), seed: seed &+ 2, state: "transport")
        scene.addLive(Wheelchair(), at: place(-cW / 2 + 0.45, cz - 3.2, yaw: 90), seed: seed &+ 3, state: "brakes-on", grabbable: true)
        scene.addLive(IvPole(), at: place(cW / 2 - 0.4, cz + 5.2), seed: seed &+ 4, state: "low", grabbable: true)
        scene.addLive(CrashCart(), at: place(cW / 2 - 0.36, cz + 3.8, yaw: -90), seed: seed &+ 5, state: "sealed")
        // Parked bed on the east wall; oxygen cylinder between the stretcher and wheelchair.
        scene.addLive(HospitalBed(), at: place(cW / 2 - 0.55, cz - 5.6, yaw: 90), seed: seed &+ 8, state: "flat")
        scene.addLive(OxygenCylinder(), at: place(-cW / 2 + 0.12, cz - 4.6), seed: seed &+ 9, state: "closed")
        for (i, z) in [cz + 6.5, cz - 1.0].enumerated() {
            scene.addLive(SanitizerDispenser(), at: place(-cW / 2 + 0.051, z, y: 1.0, yaw: 90), seed: seed &+ UInt64(6 + i), state: "idle")
        }

        // Supply table on the west wall past the ER front, laid out with grabbable kit (3 across, 6 along).
        let tz = cz + 5.25, tx = -cW / 2 + 0.33, tableTop: Float = 0.86 + 0.003
        scene.add(HospitalFit.backTable(length: 1.4, depth: 0.6), at: place(tx, tz, yaw: 90))
        let kit: [(Float, Float, Float, (inout RealScene, Xform, UInt64) -> Void)] = [
            (-0.17, -0.58, 20, { $0.addLive(Stethoscope(), at: $1, seed: $2, state: "resting") }),
            (0.0, -0.58, -80, { $0.addLive(Sphygmomanometer(), at: $1, seed: $2, state: "deflated") }),
            (0.17, -0.58, 90, { $0.addLive(Otoscope(), at: $1, seed: $2, state: "on") }),
            (-0.17, -0.35, 10, { $0.addLive(Penlight(), at: $1, seed: $2, state: "off") }),
            (0.0, -0.35, -5, { $0.addLive(ReflexHammer(), at: $1, seed: $2, state: "stowed") }),
            (0.17, -0.35, 70, { $0.addLive(TympanicThermometer(), at: $1, seed: $2, state: "reading") }),
            (-0.17, -0.12, -90, { $0.addLive(PulseOximeter(), at: $1, seed: $2, state: "on") }),
            (0.0, -0.12, -70, { $0.addLive(Glucometer(), at: $1, seed: $2, state: "reading") }),
            (0.17, -0.12, 80, { $0.addLive(Laryngoscope(), at: $1, seed: $2, state: "folded") }),
            (-0.17, 0.12, 92, { $0.addLive(SurgicalScissors(), at: $1, seed: $2, state: "closed") }),
            (0.0, 0.12, 88, { $0.addLive(Hemostat(), at: $1, seed: $2, state: "closed-locked") }),
            (0.17, 0.12, 91, { $0.addLive(NeedleHolder(), at: $1, seed: $2, state: "locked-with-needle") }),
            (-0.17, 0.35, 90, { $0.addLive(TissueForceps(), at: $1, seed: $2, state: "open") }),
            (0.0, 0.35, 89, { $0.addLive(Scalpel(), at: $1, seed: $2, state: "shielded") }),
            (0.17, 0.35, 80, { $0.addLive(WeitlanerRetractor(), at: $1, seed: $2, state: "closed") }),
            (-0.17, 0.58, 15, { $0.addLive(Syringe(), at: $1, seed: $2, state: "drawn-5ml") }),
            (0.0, 0.58, 0, { $0.addLive(PillBottle(), at: $1, seed: $2, state: "open") }),
            (0.17, 0.58, -90, { $0.addLive(ClipboardChart(), at: $1, seed: $2, state: "open") }),
        ]
        for (i, k) in kit.enumerated() { k.3(&scene, place(tx + k.0, tz + k.1, y: tableTop, yaw: k.2), seed &+ UInt64(300 + i)) }
        // Crash cart top: syringes, pill bottles, a second chart and an AED within reach of the ER door.
        let cartX = cW / 2 - 0.36, cartZ = cz + 3.8, cartTop: Float = 1.048
        scene.addLive(Syringe(), at: place(cartX - 0.1, cartZ - 0.22, y: cartTop, yaw: 5), seed: seed &+ 330, state: "full")
        scene.addLive(Syringe(), at: place(cartX + 0.0, cartZ - 0.22, y: cartTop, yaw: -8), seed: seed &+ 331, state: "drawn-5ml")
        scene.addLive(PillBottle(), at: place(cartX + 0.12, cartZ - 0.05, y: cartTop), seed: seed &+ 332, state: "open")
        scene.addLive(PillBottle(), at: place(cartX + 0.04, cartZ + 0.02, y: cartTop), seed: seed &+ 333, state: "open")
        scene.addLive(ClipboardChart(), at: place(cartX - 0.06, cartZ + 0.2, y: cartTop, yaw: 90), seed: seed &+ 334, state: "open")
        scene.spots.append(.init("supplies", eye: V3(0.3, 1.65, tz + 0.2), target: V3(tx, 0.9, tz)))

        scene.farGround = "paving.slab"
        scene.lighting = .init(sky: SunSky(elevation: 34, azimuth: 165, turbidity: 2.4), interior: .clinical, fog: 0)
        scene.bake = .interior
        scene.batchStatics = true
        scene.camera = .init(eye: V3(0.4, 1.65, cz + 7.0), target: V3(-0.2, 1.3, cz - 4), fov: 68)
        scene.spots.insert(.init("corridor", eye: V3(0, 1.65, cz + 1.0), target: V3(0, 1.3, cz - 6)), at: 0)
        scene.spots.insert(.init("start", eye: scene.camera!.eye, target: scene.camera!.target), at: 0)
        return scene
    }
}
