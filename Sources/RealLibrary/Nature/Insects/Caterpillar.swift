import simd
import Foundation

/// Monarch caterpillar (fifth instar), 5 cm: twelve body segments banded yellow, black and white, black-and-yellow striped head, two pairs of black filaments, three pairs of true legs and five pairs of prolegs.
public struct Caterpillar: RealArticulated {
    public static let id = "insect-caterpillar"
    public static let summary = "Monarch caterpillar, 5 cm: yellow-black-white banded segments, filaments, true legs and prolegs; segment chain for crawl waves."
    public static let tags = ["nature", "insect", "crawling", "articulated"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 50, elevation: 30, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var s = InsectKit.Segmented(name: Self.id, count: 12, segLength: 0.0039,
                                    radius: { t in let r: Float = 0.0029 * (t < 0.1 ? 0.85 + t * 1.5 : (t > 0.85 ? 1 - (t - 0.85) * 1.6 : 1)); return V2(r, r * 0.95) },
                                    centerY: { _ in 0.0034 }, material: { _ in "insect.caterpillar" })
        s.bandUV = true
        s.height = 0.008
        let z0: Float = 6 * 0.0039
        s.neck = V3(0, 0.0034, z0)
        s.head = [.init(V3(0, 0.0030, z0 + 0.0015), V3(0.0022, 0.0022, 0.0018), "insect.chitin:1A1816"),
                  .init(V3(0, 0.0036, z0 + 0.0026), V3(0.0012, 0.0008, 0.0006), "insect.chitin:E0C030"),
                  .init(V3(0.0012, 0.0024, z0 + 0.0028), V3(0.0005, 0.0004, 0.0003), "insect.chitin:E8E4D8", mirror: true)]
        s.antenna = .init(base: V3(0.0010, 0.0022, z0 + 0.0030), dir: V3(0.4, -0.3, 0.8), length: 0.0007, radius: 0.00012, curve: 0)
        s.antennaMat = "insect.chitin:1A1816"
        s.legMat = "insect.chitin:1A1816"
        s.leg = { i in
            if i < 3 { return InsectKit.Leg(attach: V3(0.0012, 0.0012, z0 - Float(i) * 0.0039 - 0.002), side: 1, yaw: 30, coxa: 0.0003, femur: 0.0010, tibia: 0.0012, tarsus: 0.0004, lift: -10, radius: 0.0003, bulge: 1) }
            if (5...8).contains(i) || i == 11 { return InsectKit.Leg(attach: V3(0.0014, 0.0012, z0 - Float(i) * 0.0039 - 0.002), side: 1, yaw: 0, coxa: 0.0004, femur: 0.0006, tibia: 0.0011, tarsus: 0.0005, lift: -30, radius: 0.0006, bulge: 1) }
            return nil
        }
        s.extra = { rig, d, L, zf in
            // Filaments: long pair behind the head (segment 1), short pair near the tail (segment 9).
            for (seg, len) in [(1, Float(0.012)), (9, Float(0.0055))] {
                for side: Float in [1, -1] {
                    let b = V3(side * 0.0018, 0.0058, zf(seg) - 0.002)
                    let pts = [b, b + V3(side * 0.002, len * 0.45, seg == 1 ? len * 0.3 : -len * 0.3), b + V3(side * 0.004, len * 0.6, seg == 1 ? len * 0.7 : -len * 0.7)]
                    rig.add(InsectKit.limb(pts, radii: [0.00028, 0.0002, 0.00008], material: "insect.chitin:141210", sides: 4, per: d.per), to: InsectKit.segmentName(seg), lods: L)
                }
            }
        }
        s.states = [RigState("rest"),
                    RigState("walk-a", InsectKit.wave(12, amplitude: 9, wavelength: 6, phase: 0)),
                    RigState("walk-b", InsectKit.wave(12, amplitude: 9, wavelength: 6, phase: 0.5))]
        return InsectKit.assemble(s)
    }
}
