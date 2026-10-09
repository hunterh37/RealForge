import simd
import Foundation

/// Common green darner (Anax junius), 8 cm: huge wrap-around compound eyes, green thorax, long
/// segmented sky-blue abdomen with dark dorsal stripe, four net-veined clear wings with pterostigmata
/// held flat at rest.
public struct Dragonfly: RealArticulated {
    public static let id = "insect-dragonfly"
    public static let summary = "Green darner dragonfly, 8 cm: green thorax, blue segmented abdomen, net-veined clear wings held flat; articulated."
    public static let tags = ["nature", "insect", "flying", "articulated"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 30, elevation: 40, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var p = InsectPlan(name: Self.id)
        let y: Float = 0.0085
        p.height = y + 0.006
        p.bodyPivot = V3(0, y, 0.026)
        p.thorax = [.init(V3(0, y + 0.0008, 0.026), V3(0.0036, 0.0046, 0.0062), "insect.chitin-soft:5FA040") { q in V3(q.x, q.y, q.z + q.y * 0.6) }]
        p.neck = V3(0, y + 0.001, 0.0315)
        p.head = [.init(V3(0, y + 0.0012, 0.0340), V3(0.0034, 0.0030, 0.0026), "insect.chitin-soft:7FB050"),
                  .init(V3(0.0022, y + 0.0020, 0.0340), V3(0.0026, 0.0030, 0.0030), "insect.eye:4A6A3A", mirror: true),
                  .init(V3(0, y - 0.0002, 0.0368), V3(0.0018, 0.0012, 0.0008), "insect.chitin-soft:C8D068")]
        p.abdomenPivot = V3(0, y, 0.020)
        p.abdomen = (0..<10).map { i in
            let t = Float(i) / 9
            let r: Float = i < 2 ? 0.0021 : 0.0014 + 0.0002 * t
            let mat: MaterialKey = i < 2 ? "insect.chitin-soft:5FA040" : (i > 7 ? "insect.chitin:2A3A60" : "insect.chitin:3A78C0")
            return .init(V3(0, y - 0.0004 * t, 0.0175 - Float(i) * 0.0052), V3(r, r * 1.05, 0.0030), mat)
        }
        p.legs = [
            .init(attach: V3(0.001, y - 0.004, 0.030), side: 1, yaw: 55, coxa: 0.001, femur: 0.006, tibia: 0.007, tarsus: 0.003, lift: 10, radius: 0.0004),
            .init(attach: V3(0.0012, y - 0.004, 0.027), side: 1, yaw: 15, coxa: 0.001, femur: 0.007, tibia: 0.008, tarsus: 0.003, lift: 12, radius: 0.0004),
            .init(attach: V3(0.0012, y - 0.0038, 0.024), side: 1, yaw: -25, coxa: 0.001, femur: 0.008, tibia: 0.009, tarsus: 0.0035, lift: 15, radius: 0.0004),
        ]
        p.legMat = "insect.chitin:1A1614"; p.antennaMat = "insect.chitin:1A1614"; p.spines = [4, 4, 4]
        p.antenna = .init(base: V3(0.0006, y + 0.0028, 0.0362), dir: V3(0.4, 0.5, 0.75), length: 0.0025, radius: 0.0001, curve: 0.2)
        p.fore = .init(.dragonflyFore, root: V3(0.0012, y + 0.0040, 0.0285), span: V3(1, 0, 0.06), chord: V3(-0.06, 0, 1), length: 0.048, width: 0.0105,
                       rootV: 0.58, mat: "insect.membrane", veins: "insect.veins-dragonfly-fore", droop: 0.002)
        p.hind = .init(.dragonflyHind, root: V3(0.0012, y + 0.0038, 0.0222), span: V3(1, 0, -0.08), chord: V3(0.08, 0, 1), length: 0.046, width: 0.0150,
                       rootV: 0.55, mat: "insect.membrane", veins: "insect.veins-dragonfly-hind", droop: 0.002)
        p.restWing = -4; p.openWing = 25
        return InsectKit.assemble(p)
    }
}
