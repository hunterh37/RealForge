import simd
import Foundation

/// Oscillating lawn sprinkler, 0.5 m long: two bent aluminum sled runners, a plastic gear housing with
/// hose inlet and range dial at one end, an end bracket at the other, and a curved aluminum spray tube
/// with a row of brass nozzles between them.
public struct LawnSprinkler: RealAsset {
    public static let id = "lawn-sprinkler"
    public static let summary = "Oscillating lawn sprinkler, 0.5 m: aluminum spray tube with nozzle row on a sled base, gear housing, hose inlet."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "tool", "metal"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 28, distance: 1.0)

    /// Housing plastic.
    public var housing: MaterialKey = "plastic.yellow"
    /// Nozzle count.
    public var nozzles: Int = 17
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L: Float = 0.5, half = L / 2
        // Sled runners along X.
        for s: Float in [-1, 1] {
            let pts = catmull([V3(-half, 0.03, s * 0.08), V3(-half + 0.03, 0.006, s * 0.085), V3(half - 0.03, 0.006, s * 0.085), V3(half, 0.03, s * 0.08)], per: 5)
            m.add(Prim.sweep(Shape2D.roundedRect(0.006, 0.02, radius: 0.0025), along: pts, up: .up, material: "metal.aluminum-brushed"))
        }
        // Gear housing at -X with inlet.
        let hx = -half + 0.05
        m.add(Prim.roundedBox(V3(0.08, 0.075, 0.17), radius: 0.018, bevelSegments: 3, material: housing), Xform(translation: V3(hx, 0.052, 0)))
        m.add(Prim.cylinder(radius: 0.03, height: 0.008, bevel: 0.002, segments: 24, material: "plastic.black"),
              Xform(translation: V3(hx + 0.04, 0.06, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        m.add(Prim.roundedBox(V3(0.006, 0.03, 0.006), radius: 0.002, bevelSegments: 1, material: "plastic.white"), Xform(translation: V3(hx + 0.05, 0.07, 0.01)))
        // Hose inlet (brass thread) toward -X.
        m.add(Prim.cylinder(radius: 0.014, height: 0.035, bevel: 0.002, segments: 16, material: "metal.brass"),
              Xform(translation: V3(hx - 0.04, 0.04, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        for k in 0..<5 {
            m.add(Prim.torus(major: 0.0145, minor: 0.0015, segments: 16, sides: 4, material: "metal.brass"),
                  Xform(translation: V3(hx - 0.05 - Float(k) * 0.005, 0.04, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        }
        // End bracket at +X.
        let ex = half - 0.03
        m.add(Prim.extrude(Shape2D.rounded([V2(-0.04, 0), V2(0.04, 0), V2(0.012, 0.07), V2(-0.012, 0.07)], radius: 0.008), depth: 0.012, bevel: 0.002, material: housing),
              Xform(translation: V3(ex, 0.006, 0), rotation: simd_quatf(degrees: 90, axis: .up)))
        // Grime along the housing seam.
        m.add(Prim.roundedBox(V3(0.082, 0.004, 0.172), radius: 0.0015, bevelSegments: 1, material: "plastic.yellow:7A6A2A"), Xform(translation: V3(hx, 0.03, 0)))
        // Spray tube: shallow arc between housing and bracket, rolled 15 degrees.
        let tubeY: Float = 0.065
        let arc = (0...12).map { k -> V3 in
            let t = Float(k) / 12, x = hx + 0.04 + t * (ex - hx - 0.04)
            return V3(x, tubeY + sin(t * .pi) * 0.012, 0)
        }
        m.add(Prim.tube(arc, radii: arc.map { _ in 0.009 }, sides: 12, seamTile: 0.1, material: "metal.aluminum-brushed"))
        let roll = simd_quatf(degrees: rng.float(-20...20), axis: V3(1, 0, 0))
        for k in 0..<nozzles {
            let t = (Float(k) + 0.5) / Float(nozzles)
            let p = V3(hx + 0.06 + t * (ex - hx - 0.08), tubeY + sin((0.04 + t * 0.92) * .pi) * 0.012 + 0.008, 0)
            m.add(Prim.cylinder(radius: 0.0022, height: 0.006, bevel: 0.0008, segments: 6, material: "metal.brass"),
                  Xform(translation: V3(p.x, tubeY, 0) + roll.act(p - V3(p.x, tubeY, 0)), rotation: roll))
        }
        groundAO(&m, height: 0.05)
        return LODModel(m)
    }
}
