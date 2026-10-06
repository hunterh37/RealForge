import simd
import Foundation

/// Low-voltage pagoda path light, 0.55 m above grade: spiked ground stake, round bronze stem, frosted
/// glass diffuser under a wide conical hat with a drip rim and finial, low-voltage cable. The lamp
/// part has off and on options; on lights a warm point light under the hat.
public struct PathLight: RealArticulated {
    public static let id = "path-light"
    public static let summary = "Low-voltage pagoda path light, 0.55 m: ground stake, bronze stem, frosted glass diffuser under a wide conical cap; off/on states with a downward point light."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "light", "metal", "articulated"]
    public static let budget = 4000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 18, distance: 1.0)

    /// Height of the hat apex above the ground (m).
    public var height: Float = 0.55
    /// Hat diameter (m).
    public var hatDiameter: Float = 0.2
    /// Body finish.
    public var finish: MaterialKey = "metal.powdercoat:3B3128"
    /// Light intensity when on (lumen-ish RealityKit units).
    public var intensity: Float = 900
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 1)
        let R = hatDiameter / 2
        let hatBase = height - 0.07, glassTop = hatBase - 0.004, glassBottom = hatBase - 0.11
        var m = Model(name: Self.id)
        // Stake: a short spiked collar visible at grade.
        m.add(turned([(0, 0), (0.016, 0.0), (0.022, 0.012), (0.022, 0.03), (0.018, 0.036), (0, 0.036)], segments: 20, material: "plastic.black"))
        // Stem.
        m.add(Prim.cylinder(radius: 0.011, height: glassBottom - 0.02 - 0.034, bevel: 0.002, segments: 18, material: finish), Xform(translation: V3(0, 0.034, 0)))
        // Lower cup that holds the glass.
        m.add(turned([(0, glassBottom - 0.022), (0.016, glassBottom - 0.022), (0.038, glassBottom - 0.008), (0.04, glassBottom + 0.004),
                      (0.034, glassBottom + 0.006), (0, glassBottom + 0.006)], segments: 32, material: finish))
        // Three slim posts from cup to hat.
        for i in 0..<3 {
            let a = Float(i) / 3 * 2 * .pi + 0.4
            m.add(Prim.cylinder(radius: 0.0035, height: hatBase - glassBottom, bevel: 0.001, segments: 8, material: finish),
                  Xform(translation: V3(cos(a) * 0.039, glassBottom, sin(a) * 0.039)))
        }
        // Hat: wide shallow cone with a down-turned drip rim and finial.
        let hat: [V2] = [V2(0, hatBase + 0.002), V2(R - 0.012, hatBase - 0.002), V2(R - 0.002, hatBase - 0.012), V2(R, hatBase - 0.009),
                         V2(R - 0.002, hatBase - 0.004), V2(R - 0.004, hatBase), V2(0.03, height - 0.022), V2(0.012, height - 0.012),
                         V2(0.006, height - 0.004), V2(0, height)]
        m.add(Prim.lathe(hat, segments: 40, seamTile: 0.3, material: finish))
        // Dust ring on the hat crown.
        m.add(Prim.lathe([V2(0.06, hatBase + 0.026), V2(0.04, hatBase + 0.034)], segments: 40, seamTile: 0.2, material: "metal.powdercoat:6A5C48"),
              Xform(translation: V3(0, 0.0015, 0)))
        // Cable leaving the stake.
        let cable = catmull([V3(0.012, 0.02, 0), V3(0.05, 0.006, 0.01), V3(0.075, 0.005, 0.03), V3(0.095, 0.005, 0.06)], per: 5)
        m.add(Prim.tube(cable, radii: cable.map { _ in 0.004 }, sides: 6, seamTile: 0.05, material: "plastic.black"))
        rig.base[0] = m

        rig.part("lamp", pivot: V3(0, glassBottom, 0), joint: .fixed, options: 2)
        let glass = [V2(0.032, glassBottom + 0.004), V2(0.034, glassBottom + 0.05), V2(0.032, glassTop)]
        rig.add(Prim.lathe(glass, segments: 32, seamTile: 0.2, material: "glass.frosted"), to: "lamp", option: 0)
        rig.add(Prim.lathe(glass, segments: 32, seamTile: 0.2, material: "emissive.warm"), to: "lamp", option: 1)
        rig.lights = [RigLight(name: "path", kind: .point, part: "lamp", option: 1, position: V3(0, glassBottom + 0.06, 0),
                               intensity: intensity, attenuationRadius: 2.5)]
        _ = rng.float(0...1)
        groundAO(&rig, height: 0.08)
        rig.states = [RigState("off"), RigState("on", options: ["lamp": 1])]
        return rig
    }
}
