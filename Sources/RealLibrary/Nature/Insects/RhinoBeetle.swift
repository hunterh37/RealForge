import simd
import Foundation

/// European rhinoceros beetle (Oryctes nasicornis), 4.5 cm male: glossy chestnut-brown, a long
/// cephalic horn curving up and back, a ridged pronotum with a raised hump, stout toothed fore tibiae.
public struct RhinoBeetle: RealArticulated {
    public static let id = "insect-rhino-beetle"
    public static let summary = "Rhinoceros beetle, 4.5 cm male: glossy chestnut body, curved head horn, humped pronotum; articulated legs, elytra, wings."
    public static let tags = ["nature", "insect", "crawling", "flying", "articulated"]
    public static let budget = 16_000
    public static let preview = PreviewHint(azimuth: 40, elevation: 18, distance: 1.0, ground: false, studio: true)
    public var shell: MaterialKey = "insect.chitin-chestnut:4A1E0E"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var p = InsectPlan(name: Self.id)
        p.height = 0.024
        p.bodyPivot = V3(0, 0.009, 0.004)
        p.thorax = [.init(V3(0, 0.0115, 0.0085), V3(0.0098, 0.0058, 0.0062), shell) { q in
                        V3(q.x, q.y + max(0, q.y) * 0.4 * exp(-pow(q.z / 0.003, 2)) * (1 - abs(q.x) * 80), q.z) },
                    .init(V3(0, 0.008, 0.003), V3(0.0075, 0.0035, 0.006), shell)]
        p.neck = V3(0, 0.009, 0.014)
        p.head = [.init(V3(0, 0.0085, 0.0165), V3(0.0052, 0.0032, 0.0040), shell),
                  .init(V3(0.0045, 0.009, 0.016), V3(0.0011, 0.0012, 0.0013), "insect.eye", mirror: true)]
        p.abdomenPivot = V3(0, 0.008, 0.002)
        p.abdomen = [.init(V3(0, 0.0078, -0.0085), V3(0.0088, 0.0035, 0.0115), "insect.chitin:3A1A0E")]
        p.legs = [
            .init(attach: V3(0.004, 0.0068, 0.011), side: 1, yaw: 45, coxa: 0.0015, femur: 0.008, tibia: 0.009, tarsus: 0.008, lift: 30, radius: 0.0011, bulge: 1.3),
            .init(attach: V3(0.0045, 0.0066, 0.003), side: 1, yaw: -5, coxa: 0.0015, femur: 0.009, tibia: 0.0095, tarsus: 0.008, lift: 30, radius: 0.0011, bulge: 1.3),
            .init(attach: V3(0.0045, 0.0066, -0.003), side: 1, yaw: -45, coxa: 0.0015, femur: 0.010, tibia: 0.010, tarsus: 0.009, lift: 30, radius: 0.0011, bulge: 1.3),
        ]
        p.legMat = shell; p.antennaMat = shell; p.spines = [4, 3, 3]
        p.antenna = .init(base: V3(0.004, 0.0085, 0.019), dir: V3(0.7, 0.0, 0.7), length: 0.006, radius: 0.0003, curve: 0.3, elbow: 0.8, club: 2.5, beads: 3)
        p.elytra = .init(front: 0.0045, length: 0.024, halfWidth: 0.0098, height: 0.0068, baseY: 0.0072, mat: shell, inner: "insect.chitin-matte:3A1810", atlas: false)
        p.hind = .init(.membraneHind, root: V3(0.003, 0.0125, 0.003), span: V3(1, 0.05, -0.35), chord: V3(0.35, 0, 1), length: 0.036, width: 0.017,
                       mat: "insect.membrane-amber", veins: "insect.veins-beetle", droop: 0.002,
                       folded: (V3(0.0025, 0.0115, 0.003), V3(0.12, 0, -1), V3(1, 0, 0.1), 0.015, 0.006))
        p.openWing = 10
        let shell = shell
        p.extra = { rig, d, L in
            let horn = [V3(0, 0.0105, 0.0185), V3(0, 0.0150, 0.0215), V3(0, 0.0205, 0.0205), V3(0, 0.0240, 0.0170)]
            rig.add(InsectKit.limb(horn, radii: [0.0020, 0.0014, 0.0009, 0.0003], material: shell, sides: d.sides, per: d.per), to: "head", lods: L)
            // Clypeus and mandible tips under the horn.
            rig.add(InsectKit.blob(V3(0, 0.0075, 0.0205), V3(0.003, 0.0012, 0.0015), material: shell, sub: d.sub - 3), to: "head", lods: L)
        }
        return InsectKit.assemble(p)
    }
}
