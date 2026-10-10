import simd
import Foundation

/// Black garden ant worker (Lasius niger), 5 mm: glossy dark brown-black head, mesosoma, petiole node and gaster, elbowed antennae, mandibles.
public struct GardenAnt: RealArticulated {
    public static let id = "insect-garden-ant"
    public static let summary = "Black garden ant worker, 5 mm: glossy head, mesosoma, petiole node and gaster, elbowed antennae; articulated legs."
    public static let tags = ["nature", "insect", "crawling", "articulated"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 40, elevation: 30, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var p = InsectPlan(name: Self.id)
        let y: Float = 0.0011
        let c: MaterialKey = "insect.chitin:221C18"
        p.height = y + 0.0008
        p.bodyPivot = V3(0, y, 0.0007)
        p.thorax = [.init(V3(0, y + 0.0001, 0.0008), V3(0.00032, 0.00032, 0.00070), c) { q in V3(q.x * (1 + q.z * 900), q.y + max(0, -q.z) * 0.2, q.z) },
                    .init(V3(0, y + 0.0002, 0.0000), V3(0.00012, 0.00022, 0.00009), c)]
        p.neck = V3(0, y + 0.0002, 0.0015)
        p.head = [.init(V3(0, y + 0.0002, 0.00195), V3(0.00048, 0.00042, 0.00048), c),
                  .init(V3(0.00042, y + 0.00028, 0.0020), V3(0.00012, 0.00015, 0.00015), "insect.eye", mirror: true)]
        p.abdomenPivot = V3(0, y + 0.0001, -0.0002)
        p.abdomen = [.init(V3(0, y + 0.00012, -0.0011), V3(0.00060, 0.00052, 0.00080), "insect.chitin:2A2420")]
        p.legs = [
            .init(attach: V3(0.0002, y - 0.0002, 0.0011), side: 1, yaw: 45, coxa: 0.0002, femur: 0.0011, tibia: 0.0012, tarsus: 0.0008, lift: 35, radius: 0.00007, bulge: 1.2),
            .init(attach: V3(0.0002, y - 0.0002, 0.0007), side: 1, yaw: 0, coxa: 0.0002, femur: 0.0012, tibia: 0.0013, tarsus: 0.0009, lift: 35, radius: 0.00007, bulge: 1.2),
            .init(attach: V3(0.0002, y - 0.0002, 0.0003), side: 1, yaw: -45, coxa: 0.0002, femur: 0.0013, tibia: 0.0015, tarsus: 0.0010, lift: 35, radius: 0.00007, bulge: 1.2),
        ]
        p.legMat = "insect.chitin:3A2E26"; p.antennaMat = "insect.chitin:3A2E26"
        p.antenna = .init(base: V3(0.00015, y + 0.0004, 0.0023), dir: V3(0.35, 0.55, 0.75), length: 0.0017, radius: 0.00004, curve: 0.3, elbow: 1.3, club: 0.4)
        p.extra = { rig, d, L in
            for side: Float in [1, -1] {
                rig.add(InsectKit.limb([V3(side * 0.0002, y - 0.0001, 0.0023), V3(side * 0.00012, y - 0.0001, 0.0027), V3(-side * 0.00005, y - 0.00012, 0.0028)],
                                       radii: [0.00008, 0.00006, 0.00002], material: "insect.chitin:4A3020", sides: 4, per: 1), to: "head", lods: L)
            }
        }
        return InsectKit.assemble(p)
    }
}
