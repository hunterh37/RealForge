import simd
import Foundation

/// Ten-gallon dairy can, 0.64 m tall with lid: 0.33 m body, shoulder to a 0.2 m neck, mushroom lid,
/// two side handles and a rolled foot ring, in aged galvanized steel.
public struct MilkCan: RealAsset {
    public static let id = "milk-can"
    public static let summary = "Ten-gallon dairy milk can: galvanized lathe body, shoulder and neck, mushroom lid, side handles."
    public static let tags = ["prop", "farm", "metal", "container"]
    public static let budget = 4_000
    public static let author = "hunter"

    public var material: MaterialKey = "metal.galvanized-aged"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R: Float = 0.165, t: Float = 0.002
        // Body: foot ring, wall with two swaged ribs, shoulder, neck, flared mouth (outside surface).
        let body: [(Float, Float)] = [
            (0, 0.012), (R - 0.02, 0.012), (R - 0.006, 0.004), (R + 0.004, 0.0), (R + 0.006, 0.012), (R + 0.002, 0.028),
            (R, 0.06), (R + 0.004, 0.14), (R, 0.15), (R, 0.3), (R + 0.004, 0.31), (R, 0.32), (R, 0.38),
            (R - 0.012, 0.42), (R - 0.04, 0.45), (0.105, 0.47), (0.1, 0.49), (0.1, 0.56), (0.104, 0.565), (0.112, 0.572), (0.11, 0.578),
            (0.1, 0.575), (0.098 - t, 0.57), (0.0, 0.57),
        ]
        m.add(turned(body, segments: 40, material: material, seamTile: 0.35))
        // Lid: plug into the neck, mushroom cap with a rolled edge, knob.
        let lift: Float = rng.chance(0.25) ? 0.01 : 0
        let lid: [(Float, Float)] = [
            (0.118, 0.574), (0.122, 0.578), (0.12, 0.585), (0.1, 0.6), (0.06, 0.615), (0.03, 0.62), (0.03, 0.635), (0.04, 0.64),
            (0.035, 0.648), (0.0, 0.65),
        ].map { ($0.0, $0.1 + lift) }
        var lidS = turned(lid, segments: 36, material: material, seamTile: 0.35)
        lidS.computeTangents()
        m.add(lidS, Xform(rotation: simd_quatf(degrees: lift > 0 ? 2.5 : 0, axis: V3(1, 0, 0))))
        // Side handles: flat bent straps on the shoulder.
        for sx: Float in [-1, 1] {
            let pts: [V3] = [V3(sx * (R - 0.004), 0.36, -0.05), V3(sx * (R + 0.035), 0.4, -0.045), V3(sx * (R + 0.04), 0.42, 0),
                             V3(sx * (R + 0.035), 0.4, 0.045), V3(sx * (R - 0.004), 0.36, 0.05)]
            m.add(CFKit.pipe(pts, radius: 0.0075, sides: 8, material: material))
        }
        groundAO(&m, height: 0.12, floor: 0.6)
        return LODModel(m)
    }
}
