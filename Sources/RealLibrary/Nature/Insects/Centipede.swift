import simd
import Foundation

/// Brown stone centipede (Lithobius forficatus), 4 cm: flattened chestnut body of fifteen leg-bearing segments with alternating long and short tergites, forcipules under the head, long antennae and trailing hind legs.
public struct Centipede: RealArticulated {
    public static let id = "insect-centipede"
    public static let summary = "Stone centipede, 4 cm: flat chestnut segmented body, fifteen leg pairs, forcipules, long antennae; segment chain for undulation."
    public static let tags = ["nature", "insect", "crawling", "articulated"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 40, elevation: 35, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var s = InsectKit.Segmented(name: Self.id, count: 15, segLength: 0.0024,
                                    radius: { t in V2(0.0017 * (t > 0.85 ? 1 - (t - 0.85) * 2 : 1), 0.0006) },
                                    centerY: { _ in 0.0015 }, material: { i in i % 2 == 0 ? "insect.chitin-chestnut:7A3A18" : "insect.chitin-chestnut:6A3014" })
        s.plates = true
        s.height = 0.003
        let z0: Float = 7.5 * 0.0024
        s.neck = V3(0, 0.0015, z0)
        s.head = [.init(V3(0, 0.0015, z0 + 0.0013), V3(0.0016, 0.0006, 0.0014), "insect.chitin-chestnut:6A2E12"),
                  .init(V3(0.0012, 0.0018, z0 + 0.0016), V3(0.0003, 0.0002, 0.0003), "insect.eye", mirror: true)]
        s.antenna = .init(base: V3(0.0005, 0.0017, z0 + 0.0026), dir: V3(0.45, 0.1, 0.9), length: 0.012, radius: 0.0001, curve: 0.5, beads: 12)
        s.antennaMat = "insect.chitin-chestnut:8A4A20"
        s.legMat = "insect.chitin-soft:B07A40"
        s.leg = { i in
            let last = i == 14
            return InsectKit.Leg(attach: V3(0.0012, 0.0011, z0 - Float(i) * 0.0024 - 0.0012), side: 1, yaw: last ? -70 : 20 - Float(i) * 4, coxa: 0.0003,
                                 femur: last ? 0.004 : 0.0018, tibia: last ? 0.0045 : 0.0020, tarsus: last ? 0.002 : 0.0010, lift: last ? 5 : 30, radius: 0.00014, bulge: 1)
        }
        s.axis = V3(0, 1, 0)
        s.range = -20...20
        s.extra = { rig, d, L, zf in
            for side: Float in [1, -1] {
                rig.add(InsectKit.limb([V3(side * 0.0008, 0.0010, z0 + 0.0008), V3(side * 0.0011, 0.0009, z0 + 0.0024), V3(side * 0.0002, 0.0009, z0 + 0.0031)],
                                       radii: [0.0003, 0.0002, 0.00005], material: "insect.chitin:2A1208", sides: 5, per: d.per), to: "head", lods: L)
            }
        }
        s.states = [RigState("rest"),
                    RigState("walk-a", InsectKit.wave(15, amplitude: 7, wavelength: 7, phase: 0).merging(InsectKit.gait(22, swapped: false)) { a, _ in a }),
                    RigState("walk-b", InsectKit.wave(15, amplitude: 7, wavelength: 7, phase: 0.5).merging(InsectKit.gait(22, swapped: true)) { a, _ in a })]
        return InsectKit.assemble(s)
    }
}
