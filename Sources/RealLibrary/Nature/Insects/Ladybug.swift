import simd
import Foundation

/// Seven-spot ladybird (Coccinella septempunctata), 7 mm: domed red elytra with three black spots
/// each plus the shared scutellar spot, black pronotum with white front corners, small black head
/// with white cheek patches, short clubbed antennae, six short black legs. Flight wings fold under
/// the elytra at rest and spread in `wings-open`.
public struct Ladybug: RealArticulated {
    public static let id = "insect-ladybug"
    public static let summary = "Seven-spot ladybird, 7 mm: red domed elytra with seven black spots, white-marked pronotum; articulated legs, elytra and wings."
    public static let tags = ["nature", "insect", "crawling", "flying", "articulated"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 30, elevation: 28, distance: 1.0, ground: false, studio: true)

    /// Body length in meters (5-8 mm in the wild).
    public var length: Float = 0.007
    public var elytra: MaterialKey = "insect.elytra-ladybug"
    public var cuticle: MaterialKey = "insect.chitin"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        let k = length / 0.007
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [0.8])
        let black = cuticle, white = "insect.chitin:E8E4D8"
        let legs: [InsectKit.Leg] = [Float(1), -1].flatMap { side in
            [(0.0022, 40), (0.0009, -5), (-0.0005, -40)].enumerated().map { i, a in
                InsectKit.Leg(attach: V3(side * 0.0007, 0.0011, Float(a.0)) * k, side: side, yaw: Float(a.1), coxa: 0.0004 * k,
                              femur: 0.0016 * k, tibia: 0.0017 * k, tarsus: 0.0010 * k, lift: 18, radius: 0.00022 * k, bulge: 1.3)
            }
        }.sorted { ($0.attach.z, $0.side) > ($1.attach.z, $1.side) }
        rig.part("body", pivot: V3(0, 0.0016, 0.0010) * k, joint: .fixed)
        rig.part("head", parent: "body", pivot: V3(0, 0.0015, 0.0031) * k, joint: .hinge(axis: V3(1, 0, 0), -15...15, duration: 0.3))
        rig.part("abdomen", parent: "body", pivot: V3(0, 0.0013, 0.0006) * k, joint: .hinge(axis: V3(1, 0, 0), -10...10, duration: 0.3))
        InsectKit.declareLegs(&rig, legs)
        rig.part("elytra-l", parent: "body", pivot: V3(0.0002, 0.0033, 0.0016) * k, joint: .hinge(axis: V3(0, 0, 1), 0...75, duration: 0.25))
        rig.part("elytra-r", parent: "body", pivot: V3(-0.0002, 0.0033, 0.0016) * k, joint: .hinge(axis: V3(0, 0, 1), -75...0, duration: 0.25))
        rig.part("wing-l", parent: "body", pivot: V3(0.0009, 0.0027, 0.0007) * k, joint: .hinge(axis: V3(0, 0, 1), -70...70, duration: 0.05), options: 2)
        rig.part("wing-r", parent: "body", pivot: V3(-0.0009, 0.0027, 0.0007) * k, joint: .hinge(axis: V3(0, 0, 1), -70...70, duration: 0.05), options: 2)
        rig.part("antenna-l", parent: "head", pivot: V3(0.0005, 0.0015, 0.0038) * k, joint: .hinge(axis: .up, -30...30, duration: 0.3))
        rig.part("antenna-r", parent: "head", pivot: V3(-0.0005, 0.0015, 0.0038) * k, joint: .hinge(axis: .up, -30...30, duration: 0.3))

        for lod in 0..<2 {
            let d = InsectKit.Detail(lod: lod)
            let L = lod...lod
            // Pronotum: black shield with white anterolateral patches.
            rig.add(InsectKit.blob(V3(0, 0.0021, 0.0020) * k, V3(0.0022, 0.0010, 0.0011) * k, material: black, sub: d.sub) { p in
                V3(p.x, p.y + abs(p.x) * -0.18, p.z - p.x * p.x * 120 / k)
            }, to: "body", lods: L)
            for side: Float in [1, -1] {
                rig.add(InsectKit.blob(V3(side * 0.0016, 0.0023, 0.0026) * k, V3(0.00045, 0.0004, 0.00035) * k, material: white, sub: max(2, d.sub - 3)), to: "body", lods: L)
            }
            // Ventral sclerites (meso/metathorax) and the abdomen under the elytra.
            rig.add(InsectKit.blob(V3(0, 0.0013, 0.0009) * k, V3(0.0020, 0.0006, 0.0016) * k, material: black, sub: d.sub - 2), to: "body", lods: L)
            rig.add(InsectKit.blob(V3(0, 0.0012, -0.0012) * k, V3(0.0024, 0.0006, 0.0022) * k, material: black, sub: d.sub - 2), to: "abdomen", lods: L)
            // Head with white cheek spots and compound eyes.
            rig.add(InsectKit.blob(V3(0, 0.0015, 0.0034) * k, V3(0.0011, 0.0008, 0.00065) * k, material: black, sub: d.sub - 2), to: "head", lods: L)
            for side: Float in [1, -1] {
                rig.add(InsectKit.blob(V3(side * 0.00055, 0.0018, 0.0039) * k, V3(0.00028, 0.00018, 0.0001) * k, material: white, sub: 2), to: "head", lods: L)
                rig.add(InsectKit.blob(V3(side * 0.0009, 0.0016, 0.0035) * k, V3(0.00028, 0.00038, 0.00034) * k, material: "insect.eye", sub: max(2, d.sub - 3)), to: "head", lods: L)
                rig.add(InsectKit.antenna(base: V3(side * 0.0005, 0.0015, 0.0038) * k, dir: V3(side * 0.7, 0.1, 0.7), length: 0.0011 * k,
                                          radius: 0.00006 * k, curve: -0.3, side: side, club: 1.8, beads: 4, material: black, d: d),
                        to: side > 0 ? "antenna-l" : "antenna-r", lods: L)
            }
            for l in legs { rig.add(InsectKit.leg(l, material: black, d: d), to: InsectKit.legName(l.side, legIndex(l, legs)), lods: L) }
            for side: Float in [1, -1] {
                let el = InsectKit.elytron(side: side, front: 0.0016 * k, length: 0.0052 * k, halfWidth: 0.0028 * k, height: 0.0024 * k, baseY: 0.0009 * k,
                                           material: elytra, inner: "insect.chitin-matte:3A1410", atlas: true, d: d)
                for s in el { rig.add(s, to: side > 0 ? "elytra-l" : "elytra-r", lods: L) }
                let wingName = side > 0 ? "wing-l" : "wing-r"
                // Folded: tucked under the elytra along the body. Spread: out and slightly back.
                for s in InsectKit.wing(.membraneHind, root: V3(side * 0.0006, 0.0022, 0.0007) * k, span: V3(side * 0.15, 0, -1), chord: V3(side, 0, 0.1),
                                        length: 0.0036 * k, width: 0.0014 * k, material: "insect.membrane-smoky", veins: lod == 0 ? "insect.veins-beetle" : nil) {
                    rig.add(s, to: wingName, option: 0, lods: L)
                }
                for s in InsectKit.wing(.membraneHind, root: V3(side * 0.0009, 0.0027, 0.0007) * k, span: V3(side, 0.05, -0.35), chord: V3(side * 0.35, 0, 1),
                                        length: 0.0085 * k, width: 0.0042 * k, material: "insect.membrane-smoky", veins: "insect.veins-beetle", droop: 0.0004 * k) {
                    rig.add(s, to: wingName, option: 1, lods: L)
                }
            }
        }
        rig.states = [
            RigState("rest"),
            RigState("wings-open", ["elytra-l": 60, "elytra-r": -60, "wing-l": 12, "wing-r": -12], options: ["wing-l": 1, "wing-r": 1]),
            RigState("walk-a", InsectKit.gait(22, swapped: false)),
            RigState("walk-b", InsectKit.gait(22, swapped: true)),
        ]
        InsectKit.finish(&rig, height: 0.004 * k)
        return rig
    }

    private func legIndex(_ l: InsectKit.Leg, _ all: [InsectKit.Leg]) -> Int {
        let same = all.filter { $0.side == l.side }.sorted { $0.attach.z > $1.attach.z }
        return same.firstIndex { $0.attach == l.attach } ?? 0
    }
}
