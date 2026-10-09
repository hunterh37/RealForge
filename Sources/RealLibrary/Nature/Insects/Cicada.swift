import simd
import Foundation

/// Annual cicada (Neotibicen), 4 cm: broad head with wide-set eyes and three ocelli, green and black
/// thorax with a pale X-shaped cruciform elevation, stout black abdomen with tymbal covers, glassy
/// wings with green costal veins held roof-wise over the back.
public struct Cicada: RealArticulated {
    public static let id = "insect-cicada"
    public static let summary = "Annual cicada, 4 cm: green-black thorax, wide-set eyes, glassy green-veined wings held roof-wise; articulated."
    public static let tags = ["nature", "insect", "flying", "articulated"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 40, elevation: 30, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var p = InsectPlan(name: Self.id)
        let y: Float = 0.0075
        p.height = y + 0.007
        p.bodyPivot = V3(0, y, 0.006)
        p.thorax = [.init(V3(0, y + 0.0012, 0.0075), V3(0.0068, 0.0042, 0.0050), "insect.chitin-soft:4A7A38") { q in V3(q.x, q.y, q.z) },
                    .init(V3(0, y + 0.0040, 0.0060), V3(0.0030, 0.0018, 0.0034), "insect.chitin:1E2018"),
                    .init(V3(0, y + 0.0040, 0.0028), V3(0.0028, 0.0016, 0.0015), "insect.chitin-soft:9AB070")]
        p.neck = V3(0, y + 0.0008, 0.0122)
        p.head = [.init(V3(0, y + 0.0008, 0.0135), V3(0.0060, 0.0026, 0.0024), "insect.chitin:1E2018"),
                  .init(V3(0.0060, y + 0.0016, 0.0130), V3(0.0018, 0.0018, 0.0018), "insect.eye:5A6A4A", mirror: true),
                  .init(V3(0, y - 0.0006, 0.0150), V3(0.0022, 0.0022, 0.0014), "insect.chitin:2A3020")]
        p.abdomenPivot = V3(0, y, 0.0025)
        p.abdomen = [.init(V3(0, y - 0.0002, -0.0045), V3(0.0060, 0.0042, 0.0085), "insect.chitin:1E1C18") { q in V3(q.x * (1 + q.z * 30), q.y * (1 + q.z * 30), q.z) },
                     .init(V3(0.0035, y - 0.0005, 0.0012), V3(0.0022, 0.0020, 0.0022), "insect.chitin-soft:7A8A50", mirror: true)]
        p.legs = [
            .init(attach: V3(0.0018, y - 0.0028, 0.0105), side: 1, yaw: 55, coxa: 0.0012, femur: 0.0055, tibia: 0.006, tarsus: 0.003, lift: 25, radius: 0.0007, bulge: 1.6),
            .init(attach: V3(0.002, y - 0.0028, 0.0070), side: 1, yaw: 5, coxa: 0.0012, femur: 0.0055, tibia: 0.0065, tarsus: 0.0035, lift: 25, radius: 0.0006),
            .init(attach: V3(0.002, y - 0.0028, 0.0040), side: 1, yaw: -40, coxa: 0.0012, femur: 0.006, tibia: 0.0075, tarsus: 0.004, lift: 28, radius: 0.0006),
        ]
        p.legMat = "insect.chitin-soft:5A6A3A"; p.antennaMat = "insect.chitin:1E2018"; p.spines = [3, 2, 4]
        p.antenna = .init(base: V3(0.0025, y + 0.0014, 0.0150), dir: V3(0.6, 0.3, 0.7), length: 0.003, radius: 0.0001, curve: 0.2, beads: 5)
        p.fore = .init(.cicadaFore, root: V3(0.0030, y + 0.0042, 0.0080), span: V3(1, 0, -0.1), chord: V3(0.1, 0, 1), length: 0.034, width: 0.012,
                       rootV: 0.5, mat: "insect.membrane", veins: "insect.veins-cicada-fore", droop: 0.001,
                       folded: (V3(0.0026, y + 0.0045, 0.0080), V3(0.2, -0.12, -1), V3(0.35, -0.9, 0.0), 0.036, 0.011))
        p.hind = .init(.cicadaHind, root: V3(0.0030, y + 0.0036, 0.0050), span: V3(1, 0, -0.45), chord: V3(0.45, 0, 1), length: 0.020, width: 0.009,
                       rootV: 0.5, mat: "insect.membrane", veins: "insect.veins-cicada-hind",
                       folded: (V3(0.0026, y + 0.0036, 0.0050), V3(0.18, -0.12, -1), V3(0.4, -0.9, 0.0), 0.020, 0.008))
        p.openWing = 15
        p.extra = { rig, d, L in
            // Ocelli and the rostrum (sucking beak) along the chest.
            for x: Float in [-0.0007, 0, 0.0007] {
                rig.add(InsectKit.blob(V3(x, y + 0.0034, 0.0138 - abs(x)), V3(repeating: 0.00028), material: "insect.chitin:C83A2A", sub: 1), to: "head", lods: L)
            }
            rig.add(InsectKit.limb([V3(0, y - 0.0018, 0.0150), V3(0, y - 0.0030, 0.0115), V3(0, y - 0.0030, 0.0080)], radii: [0.0005, 0.0004, 0.0002],
                                   material: "insect.chitin:2A3020", sides: d.sides - 2, per: d.per), to: "head", lods: L)
        }
        return InsectKit.assemble(p)
    }
}
