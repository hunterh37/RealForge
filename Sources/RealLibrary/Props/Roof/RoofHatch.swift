import simd
import Foundation

/// Roof access hatch, 0.9 m square: insulated curb, hinged steel lid, flashing and a pull handle.
public struct RoofHatch: RealAsset {
    public static let id = "roof-hatch"
    public static let summary = "Roof access hatch, 0.9 m square: raised curb, hinged galvanized lid, counter-flashing, pull handle and hinges."
    public static let tags = ["prop", "roof", "building", "metal"]
    public static let budget = 2000
    public static let author = "hunterh37"

    /// Lid opening angle in degrees; 0 is closed.
    public var openAngle: Float = 0
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let S: Float = 0.9, curb: Float = 0.3
        bx(&m, V3(S + 0.3, 0.02, S + 0.3), V3(0, 0.01, 0), "metal.galvanized-aged", r: 0.004)
        bx(&m, V3(S, curb, S), V3(0, 0.02 + curb / 2, 0), "metal.galvanized", r: 0.01, bs: 2)
        bx(&m, V3(S + 0.04, 0.02, S + 0.04), V3(0, 0.02 + curb, 0), "metal.galvanized", r: 0.006)
        let hinge = V3(0, 0.02 + curb + 0.02, -S / 2 - 0.02)
        let rot = simd_quatf(degrees: -openAngle, axis: V3(1, 0, 0))
        let lid = [(V3(S + 0.08, 0.05, S + 0.08), V3(0, 0.025, (S + 0.08) / 2 + 0.02))]
        for (size, off) in lid {
            m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.galvanized-aged"), Xform(translation: hinge + rot.act(off), rotation: rot))
        }
        m.add(Prim.roundedBox(V3(0.25, 0.02, 0.03), radius: 0.006, material: "metal.steel"), Xform(translation: hinge + rot.act(V3(0, 0.06, S + 0.04)), rotation: rot))
        for x: Float in [-0.25, 0.25] { bx(&m, V3(0.08, 0.04, 0.03), V3(x, hinge.y + 0.01, hinge.z - 0.005), "metal.steel", r: 0.006) }
        return K.finish(&m, ao: 0.1)
    }
}
