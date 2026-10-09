import simd
import Foundation

/// Jewel beetle (Chrysochroa fulgidissima), 3 cm: bullet-shaped, metallic green-gold body and
/// elytra with a broad red-violet longitudinal stripe on each, short serrate antennae.
public struct JewelBeetle: RealArticulated {
    public static let id = "insect-jewel-beetle"
    public static let summary = "Jewel beetle, 3 cm: metallic green elytra with red-violet stripes, tapered bullet body; articulated legs, elytra, wings."
    public static let tags = ["nature", "insect", "crawling", "flying", "articulated"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 35, elevation: 30, distance: 1.0, ground: false, studio: true)
    public var metal: MaterialKey = "insect.chitin-metallic"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var p = InsectPlan(name: Self.id)
        p.height = 0.009
        p.bodyPivot = V3(0, 0.005, 0.004)
        p.thorax = [.init(V3(0, 0.0058, 0.0065), V3(0.0052, 0.0026, 0.0035), metal) { q in V3(q.x * (1 - q.z * 60), q.y, q.z) },
                    .init(V3(0, 0.0042, 0.003), V3(0.004, 0.0018, 0.004), metal)]
        p.neck = V3(0, 0.0052, 0.0098)
        p.head = [.init(V3(0, 0.0050, 0.0113), V3(0.0030, 0.0022, 0.0018), metal),
                  .init(V3(0.0026, 0.0056, 0.0112), V3(0.0009, 0.0013, 0.0011), "insect.eye:4A3A30", mirror: true)]
        p.abdomenPivot = V3(0, 0.0042, 0.002)
        p.abdomen = [.init(V3(0, 0.0040, -0.0060), V3(0.0045, 0.0018, 0.0095), metal) { q in V3(q.x * (1 + q.z * 40), q.y, q.z) }]
        p.legs = [
            .init(attach: V3(0.0022, 0.0035, 0.0075), side: 1, yaw: 45, coxa: 0.0008, femur: 0.0045, tibia: 0.005, tarsus: 0.004, lift: 25, radius: 0.00045),
            .init(attach: V3(0.0025, 0.0034, 0.0025), side: 1, yaw: -5, coxa: 0.0008, femur: 0.005, tibia: 0.0055, tarsus: 0.0045, lift: 25, radius: 0.00045),
            .init(attach: V3(0.0025, 0.0034, -0.0015), side: 1, yaw: -45, coxa: 0.0008, femur: 0.0055, tibia: 0.006, tarsus: 0.005, lift: 25, radius: 0.00045),
        ]
        p.legMat = metal; p.antennaMat = "insect.chitin:1A2A1A"
        p.antenna = .init(base: V3(0.0018, 0.0058, 0.0125), dir: V3(0.5, 0.2, 0.85), length: 0.0055, radius: 0.0002, curve: 0.5, beads: 9)
        p.elytra = .init(front: 0.0028, length: 0.0205, halfWidth: 0.0052, height: 0.0034, baseY: 0.0040, mat: "insect.elytra-jewel", inner: "insect.chitin-matte:1A2A1A", atlas: true, wrap: 1.75)
        p.hind = .init(.membraneHind, root: V3(0.002, 0.0068, 0.002), span: V3(1, 0.05, -0.3), chord: V3(0.3, 0, 1), length: 0.022, width: 0.010,
                       mat: "insect.membrane-smoky", veins: "insect.veins-beetle", droop: 0.001,
                       folded: (V3(0.0015, 0.0062, 0.002), V3(0.1, 0, -1), V3(1, 0, 0.1), 0.012, 0.003))
        return InsectKit.assemble(p)
    }
}
