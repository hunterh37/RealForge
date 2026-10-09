import simd
import Foundation

/// Sacred dung beetle (Scarabaeus), 2 cm: broad, flattened, matte black; rake-toothed clypeus,
/// wide pronotum, front tibiae with four digging teeth, long slender hind legs for rolling balls.
public struct DungBeetle: RealArticulated {
    public static let id = "insect-dung-beetle"
    public static let summary = "Dung beetle, 2 cm: matte black flattened body, toothed shovel head and digging fore tibiae; articulated legs, elytra, wings."
    public static let tags = ["nature", "insect", "crawling", "flying", "articulated"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 35, elevation: 30, distance: 1.0, ground: false, studio: true)
    public var shell: MaterialKey = "insect.chitin-matte"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var p = InsectPlan(name: Self.id)
        p.height = 0.009
        p.bodyPivot = V3(0, 0.005, 0.002)
        p.thorax = [.init(V3(0, 0.0058, 0.0040), V3(0.0068, 0.0028, 0.0038), shell) { q in V3(q.x * (1 + q.z * 30), q.y, q.z) },
                    .init(V3(0, 0.0040, 0.001), V3(0.005, 0.0018, 0.004), shell)]
        p.neck = V3(0, 0.0048, 0.0075)
        p.head = [.init(V3(0, 0.0045, 0.0092), V3(0.0058, 0.0012, 0.0030), shell) { q in
                      // Clypeus: flat shovel with six teeth on the front edge.
                      let a = atan2(q.x, q.z)
                      let teeth = q.z > 0 ? 1 + 0.12 * max(0, cos(a * 12)) : 1
                      return V3(q.x * teeth, q.y, q.z * teeth) },
                  .init(V3(0.0046, 0.0046, 0.0082), V3(0.0008, 0.0007, 0.0008), "insect.eye", mirror: true)]
        p.abdomenPivot = V3(0, 0.004, 0.0)
        p.abdomen = [.init(V3(0, 0.0040, -0.0040), V3(0.0060, 0.0018, 0.0058), shell)]
        p.legs = [
            .init(attach: V3(0.0028, 0.0034, 0.0060), side: 1, yaw: 55, coxa: 0.0008, femur: 0.0045, tibia: 0.0055, tarsus: 0.002, lift: 20, radius: 0.0006, bulge: 1.4),
            .init(attach: V3(0.0032, 0.0033, 0.0010), side: 1, yaw: -10, coxa: 0.0008, femur: 0.0055, tibia: 0.0065, tarsus: 0.0045, lift: 30, radius: 0.00045),
            .init(attach: V3(0.0030, 0.0033, -0.0018), side: 1, yaw: -50, coxa: 0.0008, femur: 0.0070, tibia: 0.0085, tarsus: 0.0050, lift: 32, radius: 0.0004),
        ]
        p.legMat = shell; p.antennaMat = "insect.chitin:3A2A1A"; p.spines = [4, 2, 2]
        p.antenna = .init(base: V3(0.0030, 0.0042, 0.0095), dir: V3(0.8, 0, 0.6), length: 0.0028, radius: 0.00015, curve: 0.2, elbow: 0.8, club: 3, beads: 2)
        p.elytra = .init(front: 0.0016, length: 0.0105, halfWidth: 0.0060, height: 0.0034, baseY: 0.0040, mat: shell, inner: "insect.chitin-matte:2A2018", atlas: false, wrap: 1.85)
        p.hind = .init(.membraneHind, root: V3(0.0018, 0.0068, 0.001), span: V3(1, 0.05, -0.3), chord: V3(0.3, 0, 1), length: 0.017, width: 0.008,
                       mat: "insect.membrane-smoky", veins: "insect.veins-beetle", droop: 0.001,
                       folded: (V3(0.0015, 0.0064, 0.001), V3(0.1, 0, -1), V3(1, 0, 0.1), 0.007, 0.003))
        return InsectKit.assemble(p)
    }
}
