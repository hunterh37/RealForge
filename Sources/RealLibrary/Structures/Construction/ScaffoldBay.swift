import simd
import Foundation

/// Tube-and-coupler scaffold bay, 2.0 m long x 1.3 m wide, two 2.0 m lifts: 48.3 mm galvanized standards on
/// base plates and sole boards, ledgers and transoms at each lift, a facade brace, a five-board platform
/// at the top lift with guard rails and a toe board, right-angle couplers at the joints.
/// Origin at the base center; bays repeat along X every `length` (adjacent bays share standards).
public struct ScaffoldBay: RealAsset {
    public static let id = "scaffold-bay"
    public static let summary = "Tube-and-coupler scaffold bay, 2 m x 1.3 m, two lifts: galvanized tubes, couplers, board platform, rails."
    public static let tags = ["structure", "construction", "metal", "wood"]
    public static let budget = 16_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 14)

    public var length: Float = 2.0
    public var width: Float = 1.3
    public var lift: Float = 2.0
    public var lifts = 2
    public var tube: MaterialKey = "metal.galvanized"
    public var boards: MaterialKey = "wood.weathered"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        let L = length / 2, Wd = width / 2, r: Float = 0.02415
        let top = lift * Float(lifts)
        let sole: Float = 0.04, plate: Float = 0.006
        func level(_ sides: Int, details: Bool) -> Model {
            var rng = SeededRNG(seed: seed)
            var m = Model(name: Self.id)
            var steel = Surface(material: tube)
            func pipe(_ a: V3, _ b: V3) {
                var t = Prim.tube([a, b], radii: [r, r], sides: sides, seamTile: 0.08, material: tube, capEnd: true)
                let c0 = t.add(a, simd_normalize(a - b), .zero)
                for k in 0..<UInt32(sides) { t.tri(c0, k + 1, k) }
                steel.append(t)
            }
            let y0 = sole + plate
            let corners: [V2] = [V2(-L, -Wd), V2(L, -Wd), V2(L, Wd), V2(-L, Wd)]
            for c in corners {
                let lean = V3(rng.float(-0.006...0.006), 0, rng.float(-0.006...0.006))
                pipe(V3(c.x, y0, c.y), V3(c.x, top + 1.05, c.y) + lean)
                m.add(Prim.roundedBox(V3(0.15, plate, 0.15), radius: 0.002, bevelSegments: 1, material: tube), Xform(translation: V3(c.x, sole + plate / 2, c.y)))
                m.add(turned([(0.03, 0), (0.03, 0.08), (0, 0.08)], segments: sides, material: tube), Xform(translation: V3(c.x, y0, c.y)))
            }
            // Sole boards under each pair of standards (along Z).
            for x in [-L, L] {
                m.add(plank(width + 0.5, 0.225, sole, bevel: 0.004, material: boards),
                      Xform(translation: V3(x, sole / 2, 0), rotation: simd_quatf(degrees: 90, axis: .up)).jittered(&rng, deg: 0.8, offset: 0.004))
            }
            var couplers: [V3] = []
            // Ledgers (along X) inside/outside and transoms (along Z) at each lift, plus a kicker at 0.15 m.
            for k in 0...lifts {
                let y = k == 0 ? Float(0.15) + sole : lift * Float(k)
                for z in [-Wd, Wd] {
                    pipe(V3(-L - 0.25, y, z + 0.05 * (z < 0 ? -1 : 1)), V3(L + 0.25, y, z + 0.05 * (z < 0 ? -1 : 1)))
                    couplers += [V3(-L, y, z), V3(L, y, z)]
                }
                if k > 0 {
                    for x in [-L, L] { pipe(V3(x + 0.05, y + 0.05, -Wd - 0.15), V3(x + 0.05, y + 0.05, Wd + 0.15)) }
                }
            }
            // Facade brace on the outside face (z = +Wd), corner to corner across both lifts.
            pipe(V3(-L - 0.1, 0.3, Wd + 0.1), V3(L + 0.1, top - 0.1, Wd + 0.1))
            couplers += [V3(-L, 0.4, Wd + 0.05), V3(L, top - 0.2, Wd + 0.05)]
            // Guard rails at 0.95 m and 0.5 m above the platform on the outside, and on the inside end.
            for h: Float in [0.5, 0.95] {
                pipe(V3(-L - 0.2, top + h, Wd + 0.05), V3(L + 0.2, top + h, Wd + 0.05))
                couplers += [V3(-L, top + h, Wd), V3(L, top + h, Wd)]
            }
            steel.computeTangents()
            m.add(steel)
            if details {
                for c in couplers {
                    let side: Float = c.z < 0 ? -1 : 1
                    m.add(Prim.roundedBox(V3(0.075, 0.075, 0.05), radius: 0.012, bevelSegments: 1, material: tube),
                          Xform(translation: c + V3(0, 0.03, side * 0.03)).jittered(&rng, deg: 3, offset: 0.002))
                }
            }
            // Platform: five 225 mm boards on the top transoms, banded ends.
            let by = top + 0.05 + r + 0.019
            for i in 0..<5 {
                let z = -Wd + 0.1 + 0.2275 * (Float(i) + 0.5) * (width - 0.2) / (5 * 0.2275)
                let len = length + rng.float(0.35...0.5)
                m.add(plank(len, 0.225, 0.038, bevel: 0.005, material: boards), Xform(translation: V3(rng.float(-0.05...0.05), by, z)).jittered(&rng, deg: 0.4, offset: 0.002))
                if details {
                    for sx: Float in [-1, 1] {
                        m.add(Prim.roundedBox(V3(0.03, 0.042, 0.229), radius: 0.002, bevelSegments: 1, material: tube), Xform(translation: V3(sx * (len / 2 - 0.05), by, z)))
                    }
                }
            }
            // Toe board on the outside edge.
            m.add(plank(length + 0.3, 0.15, 0.038, bevel: 0.005, material: boards),
                  Xform(translation: V3(0, by + 0.075, Wd - 0.035), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))).jittered(&rng, deg: 0.4))
            groundAO(&m, height: 0.3, floor: 0.6)
            return m
        }
        return LODModel(levels: [level(10, details: true), level(6, details: false)], switchDistances: [18])
    }
}
