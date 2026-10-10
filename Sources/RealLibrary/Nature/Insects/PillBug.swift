import simd
import Foundation

/// Common pill bug (Armadillidium vulgare), 1.2 cm: slate-grey arched tergites in seven overlapping plates plus head and tail, pale flecks, seven pairs of short legs, short antennae; rolls into a ball (conglobation).
public struct PillBug: RealArticulated {
    public static let id = "insect-pill-bug"
    public static let summary = "Pill bug, 1.2 cm: slate-grey arched segmented plates, seven leg pairs, short antennae; segment chain rolls into a ball (curled)."
    public static let tags = ["nature", "insect", "crawling", "articulated"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 40, elevation: 30, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var s = InsectKit.Segmented(name: Self.id, count: 9, segLength: 0.00125,
                                    radius: { t in V2(0.0034 * (t > 0.7 ? 1 - (t - 0.7) * 1.4 : 1), 0.0022 * (t > 0.7 ? 1 - (t - 0.7) * 1.2 : 1)) },
                                    centerY: { _ in 0.0009 }, material: { i in i % 2 == 0 ? "insect.chitin:5A5E62" : "insect.chitin:4E5256" })
        s.plates = true
        s.height = 0.004
        let z0: Float = 4.5 * 0.00125
        s.neck = V3(0, 0.0012, z0)
        s.head = [.init(V3(0, 0.0012, z0 + 0.0005), V3(0.0018, 0.0011, 0.0008), "insect.chitin:3E4246"),
                  .init(V3(0.0012, 0.0015, z0 + 0.0006), V3(0.0003, 0.0003, 0.0003), "insect.eye", mirror: true)]
        s.antenna = .init(base: V3(0.0008, 0.0010, z0 + 0.0011), dir: V3(0.6, 0.1, 0.8), length: 0.0024, radius: 0.00009, curve: 0.8, beads: 4)
        s.antennaMat = "insect.chitin:4A4E52"
        s.legMat = "insect.chitin-matte:8A8478"
        s.leg = { i in
            guard i < 7 else { return nil }
            return InsectKit.Leg(attach: V3(0.0012, 0.0008, z0 - Float(i) * 0.00125 - 0.0006), side: 1, yaw: 40 - Float(i) * 12, coxa: 0.0003, femur: 0.0011,
                                 tibia: 0.0011, tarsus: 0.0005, lift: 20, radius: 0.00012, bulge: 1)
        }
        s.range = -45...45
        s.extra = { rig, d, L, zf in
            guard d.lod == 0 else { return }
            // Pale flecks on the plates.
            for i in 0..<7 { for side: Float in [1, -1] {
                rig.add(InsectKit.blob(V3(side * 0.0016, 0.0027, zf(i) - 0.0006), V3(0.0003, 0.0001, 0.0002), material: "insect.chitin:9A9A90", sub: 1), to: InsectKit.segmentName(i), lods: L)
            }}
        }
        var curled: [String: Float] = ["head": -25]
        for i in 0..<9 { curled[InsectKit.segmentName(i)] = -36 }
        s.states = [RigState("rest"),
                    RigState("walk-a", InsectKit.gait(22, swapped: false)),
                    RigState("walk-b", InsectKit.gait(22, swapped: true)),
                    RigState("curled", curled)]
        return InsectKit.assemble(s)
    }
}
