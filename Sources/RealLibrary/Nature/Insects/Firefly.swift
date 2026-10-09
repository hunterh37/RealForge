import simd
import Foundation

/// Common eastern firefly (Photinus pyralis), 1.5 cm: soft-bodied beetle with a pink pronotum and
/// black central spot shielding the head, dark elytra edged pale yellow, and a two-segment lantern at
/// the abdomen tip. `glow` option 0 is lit (emissive firefly gold #FFF2B5), option 1 dark.
public struct Firefly: RealArticulated {
    public static let id = "insect-firefly"
    public static let summary = "Firefly, 1.5 cm: pink-shielded head, pale-edged dark elytra, emissive gold lantern (glow part); articulated legs, elytra, wings."
    public static let tags = ["nature", "insect", "flying", "glowing", "articulated"]
    public static let budget = 12_000
    public static let preview = PreviewHint(azimuth: 145, elevation: 25, distance: 1.0, ground: false, studio: true)
    public var lantern: MaterialKey = "insect.lantern"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var p = InsectPlan(name: Self.id)
        p.height = 0.0055
        p.bodyPivot = V3(0, 0.0034, 0.003)
        p.thorax = [.init(V3(0, 0.0040, 0.0047), V3(0.0028, 0.0009, 0.0021), "insect.chitin-soft:E89A90") { q in V3(q.x, q.y + (q.x * q.x) * -60, q.z) },
                    .init(V3(0, 0.0049, 0.0046), V3(0.0008, 0.00035, 0.0011), "insect.chitin:1A1614"),
                    .init(V3(0, 0.0032, 0.0025), V3(0.0018, 0.0010, 0.0020), "insect.chitin:2A2420")]
        p.neck = V3(0, 0.0034, 0.0055)
        p.head = [.init(V3(0, 0.0033, 0.0062), V3(0.0011, 0.0009, 0.0009), "insect.chitin:1A1614"),
                  .init(V3(0.0009, 0.0034, 0.0063), V3(0.0006, 0.0007, 0.0006), "insect.eye", mirror: true)]
        p.abdomenPivot = V3(0, 0.0030, 0.0018)
        p.abdomen = [.init(V3(0, 0.0027, -0.0022), V3(0.0021, 0.0009, 0.0042), "insect.chitin-matte:4A3A30")]
        p.legs = [
            .init(attach: V3(0.0008, 0.0028, 0.0042), side: 1, yaw: 45, coxa: 0.0004, femur: 0.0025, tibia: 0.0028, tarsus: 0.0018, lift: 30, radius: 0.0002),
            .init(attach: V3(0.0009, 0.0027, 0.0024), side: 1, yaw: 0, coxa: 0.0004, femur: 0.0027, tibia: 0.0030, tarsus: 0.0020, lift: 30, radius: 0.0002),
            .init(attach: V3(0.0009, 0.0027, 0.0008), side: 1, yaw: -45, coxa: 0.0004, femur: 0.0030, tibia: 0.0034, tarsus: 0.0022, lift: 30, radius: 0.0002),
        ]
        p.legMat = "insect.chitin:2A2420"; p.antennaMat = "insect.chitin:1A1614"
        p.antenna = .init(base: V3(0.0005, 0.0037, 0.0069), dir: V3(0.45, 0.25, 0.85), length: 0.0058, radius: 0.00013, curve: 0.5, beads: 10)
        p.elytra = .init(front: 0.0028, length: 0.0100, halfWidth: 0.0025, height: 0.0014, baseY: 0.0031, mat: "insect.elytra-firefly", inner: "insect.chitin-matte:2A2420", atlas: true, wrap: 1.7)
        p.hind = .init(.membraneHind, root: V3(0.0011, 0.0040, 0.0026), span: V3(1, 0.05, -0.3), chord: V3(0.3, 0, 1), length: 0.012, width: 0.005,
                       mat: "insect.membrane-smoky", veins: "insect.veins-beetle",
                       folded: (V3(0.0009, 0.0036, 0.0026), V3(0.1, 0, -1), V3(1, 0, 0.1), 0.0075, 0.0018))
        p.openWing = 15
        p.extraParts = { rig in
            rig.part("glow", parent: "abdomen", pivot: V3(0, 0.0025, -0.0055), joint: .hinge(axis: V3(1, 0, 0), -15...15, duration: 0.3), options: 2)
        }
        let lantern = lantern
        p.extra = { rig, d, L in
            for (o, m) in [(0, lantern), (1, "insect.lantern-off")] {
                rig.add(InsectKit.blob(V3(0, 0.0025, -0.0066), V3(0.0019, 0.0008, 0.0016), material: m, sub: d.sub - 2), to: "glow", option: o, lods: L)
            }
        }
        p.extraStates = [RigState("dark", [:], options: ["glow": 1])]
        return InsectKit.assemble(p)
    }
}
