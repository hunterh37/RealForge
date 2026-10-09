import simd
import Foundation

/// Northern walking stick (Diapheromera femorata), 10 cm: wingless, twig-thin brown body with knobbed joints, long thin legs and antennae.
public struct StickInsect: RealArticulated {
    public static let id = "insect-stick-insect"
    public static let summary = "Walking stick, 10 cm: wingless twig-like brown body, knobbed joints, long thin legs and antennae; articulated legs."
    public static let tags = ["nature", "insect", "crawling", "articulated"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 50, elevation: 30, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var p = InsectPlan(name: Self.id)
        let y: Float = 0.0055
        let bark: MaterialKey = "insect.chitin-matte:6E5A3C"
        p.height = y + 0.004
        p.bodyPivot = V3(0, y, 0.020)
        p.thorax = [.init(V3(0, y, 0.022), V3(0.0012, 0.0013, 0.0185), bark),
                    .init(V3(0, y + 0.0001, 0.0405), V3(0.0010, 0.0010, 0.0016), bark)]
        p.neck = V3(0, y, 0.0420)
        p.head = [.init(V3(0, y + 0.0002, 0.0445), V3(0.0012, 0.0011, 0.0026), bark),
                  .init(V3(0.0010, y + 0.0006, 0.0458), V3(0.0004, 0.0005, 0.0005), "insect.eye:5A4A30", mirror: true)]
        p.abdomenPivot = V3(0, y, 0.0035)
        p.abdomen = (0..<5).map { i in .init(V3(0, y - 0.0001 * Float(i), -0.0025 - Float(i) * 0.0105), V3(0.0010 - 0.00008 * Float(i), 0.0011 - 0.00008 * Float(i), 0.0060), bark) }
        p.legs = [
            .init(attach: V3(0.0008, y - 0.0006, 0.0385), side: 1, yaw: 60, coxa: 0.001, femur: 0.022, tibia: 0.024, tarsus: 0.006, lift: 28, radius: 0.00035, bulge: 1),
            .init(attach: V3(0.0009, y - 0.0006, 0.0130), side: 1, yaw: 10, coxa: 0.001, femur: 0.017, tibia: 0.018, tarsus: 0.005, lift: 30, radius: 0.00035, bulge: 1),
            .init(attach: V3(0.0009, y - 0.0006, 0.0060), side: 1, yaw: -45, coxa: 0.001, femur: 0.020, tibia: 0.021, tarsus: 0.005, lift: 30, radius: 0.00035, bulge: 1),
        ]
        p.legMat = "insect.chitin-matte:7A6444"; p.antennaMat = bark
        p.antenna = .init(base: V3(0.0006, y + 0.0008, 0.0468), dir: V3(0.25, 0.15, 0.95), length: 0.050, radius: 0.0002, curve: 0.5)
        p.extra = { rig, d, L in
            guard d.lod == 0 else { return }
            // Bark-like nodules along the back.
            for i in 0..<6 {
                rig.add(InsectKit.blob(V3(0, y + 0.0011, 0.036 - Float(i) * 0.0055), V3(0.0005, 0.0003, 0.0007), material: bark, sub: 1), to: "body", lods: L)
            }
        }
        return InsectKit.assemble(p)
    }
}
