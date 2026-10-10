import simd
import Foundation

/// Azure damselfly (Coenagrion puella) male, 3.5 cm: slender sky-blue abdomen ringed black, widely
/// separated eyes on a dumbbell head, four stalked clear wings with dark pterostigmata held closed
/// over the abdomen at rest.
public struct Damselfly: RealArticulated {
    public static let id = "insect-damselfly"
    public static let summary = "Azure damselfly, 3.5 cm: slim blue abdomen with black rings, dumbbell head, stalked wings closed at rest; articulated."
    public static let tags = ["nature", "insect", "flying", "articulated"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 60, elevation: 25, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var p = InsectPlan(name: Self.id)
        let y: Float = 0.0045
        p.height = y + 0.004
        p.bodyPivot = V3(0, y, 0.0115)
        p.thorax = [.init(V3(0, y + 0.0004, 0.0115), V3(0.0014, 0.0019, 0.0028), "insect.chitin:4A90D0") { q in V3(q.x, q.y, q.z + q.y * 0.5) },
                    .init(V3(0, y + 0.0014, 0.0112), V3(0.0006, 0.0008, 0.0024), "insect.chitin:1A1A1C")]
        p.neck = V3(0, y + 0.0006, 0.0142)
        p.head = [.init(V3(0, y + 0.0007, 0.0150), V3(0.0022, 0.0009, 0.0009), "insect.chitin:1A1A1C"),
                  .init(V3(0.0021, y + 0.0009, 0.0150), V3(0.0010, 0.0011, 0.0010), "insect.eye:3A6A9A", mirror: true)]
        p.abdomenPivot = V3(0, y, 0.0088)
        p.abdomen = (0..<10).map { i in
            let mat: MaterialKey = (i == 1 || (i >= 2 && i <= 6 && true)) ? (i % 2 == 0 ? "insect.chitin:1A1A1C" : "insect.chitin:4A9AE0") : (i >= 7 ? "insect.chitin:4A9AE0" : "insect.chitin:1A1A1C")
            return .init(V3(0, y - 0.0001 * Float(i), 0.0080 - Float(i) * 0.0027), V3(0.0006, 0.00065, 0.0016), mat)
        }
        p.legs = [
            .init(attach: V3(0.0005, y - 0.0016, 0.0130), side: 1, yaw: 55, coxa: 0.0005, femur: 0.0028, tibia: 0.0032, tarsus: 0.0012, lift: 15, radius: 0.0002),
            .init(attach: V3(0.0006, y - 0.0016, 0.0118), side: 1, yaw: 15, coxa: 0.0005, femur: 0.0031, tibia: 0.0034, tarsus: 0.0013, lift: 18, radius: 0.0002),
            .init(attach: V3(0.0006, y - 0.0015, 0.0104), side: 1, yaw: -25, coxa: 0.0005, femur: 0.0034, tibia: 0.0037, tarsus: 0.0014, lift: 20, radius: 0.0002),
        ]
        p.legMat = "insect.chitin:1A1A1C"; p.antennaMat = "insect.chitin:1A1A1C"; p.spines = [3, 3, 3]
        p.antenna = .init(base: V3(0.0004, y + 0.0014, 0.0156), dir: V3(0.4, 0.5, 0.75), length: 0.0012, radius: 0.00006, curve: 0.2)
        p.fore = .init(.damselfly, root: V3(0.0005, y + 0.0022, 0.0125), span: V3(1, 0, 0.05), chord: V3(-0.05, 0, 1), length: 0.020, width: 0.0042,
                       rootV: 0.5, mat: "insect.membrane", veins: "insect.veins-damselfly",
                       folded: (V3(0.0004, y + 0.0024, 0.0125), V3(0.04, 0.12, -1), V3(0, 1, 0.12), 0.020, 0.0042))
        p.hind = .init(.damselfly, root: V3(0.0005, y + 0.0021, 0.0108), span: V3(1, 0, -0.05), chord: V3(0.05, 0, 1), length: 0.019, width: 0.0042,
                       rootV: 0.5, mat: "insect.membrane", veins: "insect.veins-damselfly",
                       folded: (V3(0.0006, y + 0.0023, 0.0108), V3(0.06, 0.1, -1), V3(0, 1, 0.1), 0.019, 0.0042))
        p.openWing = 5
        return InsectKit.assemble(p)
    }
}
