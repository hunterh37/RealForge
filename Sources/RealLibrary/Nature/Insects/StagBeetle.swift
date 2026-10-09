import simd
import Foundation

/// Male European stag beetle (Lucanus cervus), 6 cm with mandibles: black head and pronotum,
/// chestnut elytra, antler-like mandibles with an inner tine and forked tips, elbowed clubbed antennae.
public struct StagBeetle: RealArticulated {
    public static let id = "insect-stag-beetle"
    public static let summary = "Male stag beetle, 6 cm: black head and pronotum, chestnut elytra, antler mandibles; articulated legs, elytra, wings."
    public static let tags = ["nature", "insect", "crawling", "flying", "articulated"]
    public static let budget = 16_000
    public static let preview = PreviewHint(azimuth: 35, elevation: 25, distance: 1.0, ground: false, studio: true)
    public var shell: MaterialKey = "insect.chitin-chestnut"
    public var black: MaterialKey = "insect.chitin"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var p = InsectPlan(name: Self.id)
        p.height = 0.014
        p.bodyPivot = V3(0, 0.008, 0.004)
        p.thorax = [.init(V3(0, 0.0095, 0.0085), V3(0.0085, 0.0038, 0.0045), black) { q in V3(q.x * (1 + q.z * 40), q.y, q.z) },
                    .init(V3(0, 0.0068, 0.003), V3(0.006, 0.0028, 0.005), black)]
        p.neck = V3(0, 0.009, 0.0135)
        p.head = [.init(V3(0, 0.0092, 0.0175), V3(0.0095, 0.0032, 0.0042), black) { q in V3(q.x, q.y * (1 - abs(q.x) * 30), q.z) },
                  .init(V3(0.0088, 0.0098, 0.018), V3(0.0013, 0.0014, 0.0016), "insect.eye", mirror: true)]
        p.abdomenPivot = V3(0, 0.007, 0.002)
        p.abdomen = [.init(V3(0, 0.0068, -0.009), V3(0.0075, 0.0028, 0.0115), "insect.chitin-matte:2A1810")]
        p.legs = [
            .init(attach: V3(0.0035, 0.0065, 0.011), side: 1, yaw: 50, coxa: 0.0015, femur: 0.009, tibia: 0.011, tarsus: 0.008, lift: 28, radius: 0.0008, bulge: 1.3),
            .init(attach: V3(0.004, 0.0062, 0.003), side: 1, yaw: -5, coxa: 0.0015, femur: 0.010, tibia: 0.011, tarsus: 0.009, lift: 28, radius: 0.0008, bulge: 1.3),
            .init(attach: V3(0.004, 0.0062, -0.003), side: 1, yaw: -45, coxa: 0.0015, femur: 0.011, tibia: 0.012, tarsus: 0.010, lift: 28, radius: 0.0008, bulge: 1.3),
        ]
        p.legMat = black; p.antennaMat = black; p.spines = [3, 2, 2]
        p.antenna = .init(base: V3(0.0065, 0.0095, 0.021), dir: V3(0.6, 0.15, 0.75), length: 0.011, radius: 0.00035, curve: 0.2, elbow: 1.1, club: 1.8, beads: 6)
        p.elytra = .init(front: 0.004, length: 0.026, halfWidth: 0.0082, height: 0.0055, baseY: 0.0065, mat: shell, inner: "insect.chitin-matte:3A1810", atlas: false)
        p.hind = .init(.membraneHind, root: V3(0.003, 0.0105, 0.003), span: V3(1, 0.05, -0.35), chord: V3(0.35, 0, 1), length: 0.034, width: 0.016,
                       mat: "insect.membrane-amber", veins: "insect.veins-beetle", droop: 0.002,
                       folded: (V3(0.0025, 0.0095, 0.003), V3(0.12, 0, -1), V3(1, 0, 0.1), 0.016, 0.005))
        p.openWing = 10
        let black = black
        p.extra = { rig, d, L in
            for side: Float in [1, -1] {
                // Mandible: from the head front, out, forward and curving in, with an inner tine and forked tip.
                let pts = [V3(side * 0.0055, 0.0092, 0.020), V3(side * 0.0095, 0.0105, 0.028), V3(side * 0.0090, 0.0125, 0.036),
                           V3(side * 0.0045, 0.0135, 0.0425)]
                rig.add(InsectKit.limb(pts, radii: [0.0019, 0.0015, 0.0012, 0.0006], material: "insect.chitin-chestnut:4A1A0C", sides: d.sides, per: d.per), to: "head", lods: L)
                rig.add(InsectKit.limb([V3(side * 0.0094, 0.0108, 0.030), V3(side * 0.0058, 0.0110, 0.0315)], radii: [0.0007, 0.0002],
                                       material: "insect.chitin-chestnut:4A1A0C", sides: d.sides, per: 1), to: "head", lods: L)
                rig.add(InsectKit.limb([V3(side * 0.0062, 0.0132, 0.0405), V3(side * 0.0050, 0.0150, 0.0420)], radii: [0.0005, 0.00015],
                                       material: "insect.chitin-chestnut:4A1A0C", sides: d.sides, per: 1), to: "head", lods: L)
                // Palps.
                rig.add(InsectKit.limb([V3(side * 0.002, 0.0075, 0.0205), V3(side * 0.0035, 0.0062, 0.0235)], radii: [0.0003, 0.0002],
                                       material: black, sides: 4, per: 1), to: "head", lods: L)
            }
        }
        return InsectKit.assemble(p)
    }
}
