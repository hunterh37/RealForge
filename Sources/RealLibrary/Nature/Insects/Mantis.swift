import simd
import Foundation

/// European praying mantis (Mantis religiosa), 8 cm: leaf-green, long raised prothorax, triangular swivel head with large eyes at the corners, folded spined raptorial forelegs, tegmina along the abdomen.
public struct Mantis: RealArticulated {
    public static let id = "insect-mantis"
    public static let summary = "Praying mantis, 8 cm: green, long prothorax, triangular head, spined raptorial forelegs, folded tegmina; articulated."
    public static let tags = ["nature", "insect", "crawling", "flying", "articulated"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 60, elevation: 20, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var p = InsectPlan(name: Self.id)
        let y: Float = 0.010
        let green: MaterialKey = "insect.chitin-soft:7AAE4A"
        p.height = y + 0.016
        p.bodyPivot = V3(0, y, 0.006)
        p.thorax = [.init(V3(0, y + 0.0045, 0.0215), V3(0.0016, 0.0016, 0.0115), green) { q in V3(q.x * (1 + max(0, q.z) * 60), q.y + q.z * 0.42, q.z) },
                    .init(V3(0, y, 0.0060), V3(0.0028, 0.0026, 0.0062), green)]
        p.neck = V3(0, y + 0.0090, 0.0325)
        p.head = [.init(V3(0, y + 0.0098, 0.0350), V3(0.0040, 0.0028, 0.0017), green) { q in V3(q.x * (1 + q.y * 120), q.y, q.z) },
                  .init(V3(0.0036, y + 0.0112, 0.0350), V3(0.0013, 0.0016, 0.0014), "insect.eye:8AB060", mirror: true)]
        p.abdomenPivot = V3(0, y, 0.0005)
        p.abdomen = [.init(V3(0, y - 0.0004, -0.0185), V3(0.0040, 0.0030, 0.0190), green) { q in V3(q.x * (1 + q.z * 22), q.y * (1 + q.z * 18), q.z) }]
        p.legs = [
            .init(attach: V3(0.0012, y + 0.0005, 0.029), side: 1, yaw: 82, coxa: 0.0065, femur: 0.0125, tibia: 0.0085, tarsus: 0.003, lift: 35, radius: 0.0007, bulge: 1.7, folded: true),
            .init(attach: V3(0.0015, y - 0.0018, 0.0075), side: 1, yaw: 25, coxa: 0.001, femur: 0.014, tibia: 0.014, tarsus: 0.006, lift: 30, radius: 0.00045, bulge: 1),
            .init(attach: V3(0.0015, y - 0.0018, 0.0035), side: 1, yaw: -40, coxa: 0.001, femur: 0.017, tibia: 0.017, tarsus: 0.007, lift: 30, radius: 0.00045, bulge: 1),
        ]
        p.legMat = green; p.antennaMat = "insect.chitin-soft:8A9A50"; p.spines = [7, 0, 0]
        p.antenna = .init(base: V3(0.0008, y + 0.0110, 0.0362), dir: V3(0.3, 0.5, 0.8), length: 0.018, radius: 0.00012, curve: 0.6)
        p.fore = .init(.tegmen, root: V3(0.0016, y + 0.0028, 0.0085), span: V3(1, 0.1, -0.15), chord: V3(0.15, 0, 1), length: 0.040, width: 0.009,
                       rootV: 0.5, mat: "insect.tegmen-katydid", folded: (V3(0.0010, y + 0.0032, 0.0085), V3(0.03, -0.05, -1), V3(0.75, -0.25, 0), 0.036, 0.0075))
        p.hind = .init(.membraneHind, root: V3(0.0016, y + 0.0024, 0.0060), span: V3(1, 0.05, -0.35), chord: V3(0.35, 0, 1), length: 0.036, width: 0.022,
                       rootV: 0.5, mat: "insect.membrane-smoky", veins: "insect.veins-fan",
                       folded: (V3(0.0008, y + 0.0028, 0.0060), V3(0.03, -0.04, -1), V3(0.75, -0.25, 0), 0.032, 0.006))
        p.openWing = 25
        p.extra = { rig, d, L in
            // Black-ringed eye spot on the inner fore coxa.
            for side: Float in [1, -1] {
                rig.add(InsectKit.blob(V3(side * 0.0013, y - 0.0012, 0.0300), V3(0.0004, 0.0006, 0.0006), material: "insect.chitin:1A1A1A", sub: 1), to: "body", lods: L)
            }
        }
        return InsectKit.assemble(p)
    }
}
