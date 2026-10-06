import simd
import Foundation

/// Potted boxwood: a 0.42 m clipped ball on a short trunk in a 0.46 m tapered terracotta pot with a
/// rolled rim, potting mix 4 cm below the rim and a faint mineral bloom on the clay.
public struct PottedBoxwood: RealAsset {
    public static let id = "potted-boxwood"
    public static let summary = "Potted boxwood: clipped 0.42 m ball on a short trunk in a 0.46 m terracotta pot with rolled rim."
    public static let tags = ["prop", "landscaping", "garden", "plant", "ceramic", "decor", "outdoor"]
    public static let budget = 11000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 15)

    /// Pot rim diameter, foot diameter and height, meters.
    public var potTop: Float = 0.46
    public var potFoot: Float = 0.32
    public var potHeight: Float = 0.4
    /// Ball diameter and clear trunk between soil and ball, meters.
    public var ballDiameter: Float = 0.42
    public var trunkClear: Float = 0.05
    public var sprays = 1200
    public var pot: MaterialKey = "ceramic.terracotta"
    public var soil: MaterialKey = "soil.potting"
    public var leaf: MaterialKey = "leaf.boxwood"
    public var mass: MaterialKey = "leaf.boxwood-mass"
    public var wood: MaterialKey = "bark.oak-dry"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: 1), model(seed: seed, detail: 0.4)], switchDistances: [9])
    }

    func model(seed: UInt64, detail: Float) -> Model {
        var m = Model(name: Self.id)
        let R = potTop / 2, Rf = potFoot / 2, H = potHeight
        let segs = detail > 0.5 ? 44 : 22
        // Tapered wall, rolled rim band (2 cm proud, 6 cm deep), chamfered foot.
        let rimH: Float = 0.065
        let wallTop = R - 0.018
        let outer: [V2] = [V2(0, 0), V2(Rf - 0.008, 0), V2(Rf, 0.008),
                           V2(wallTop, H - rimH), V2(R - 0.004, H - rimH + 0.006), V2(R, H - rimH + 0.02), V2(R, H - 0.012), V2(R - 0.004, H - 0.002)]
        m.add(Prim.lathe(Profile.shell(outer, wall: 0.014, floor: 0.025, lipSegments: detail > 0.5 ? 4 : 2), segments: segs, seamTile: 0.1, material: pot))
        let soilY = H - 0.04, inner = R - 0.02
        var dirt = Prim.lathe([V2(0, soilY - 0.04), V2(inner, soilY - 0.04), V2(inner, soilY - 0.004), V2(inner * 0.5, soilY + 0.006), V2(0, soilY + 0.01)],
                              segments: segs, seamTile: 0.1, material: soil)
        if detail > 0.5 {
            dirt = dirt.subdivided()
            dirt.displace { p, n in n.y > 0.5 ? Noise.fbm(V3(p.x * 30, 0, p.z * 30), octaves: 2) * 0.005 : 0 }
        }
        m.add(dirt)
        let center = V3(0, soilY + trunkClear + ballDiameter / 2, 0)
        BoxwoodBall.ball(&m, center: center, diameter: ballDiameter, sprays: Int(Float(sprays) * detail), shoots: detail > 0.5 ? 30 : 0,
                         trunkBase: soilY - 0.01, seed: seed, coreSubdiv: detail > 0.5 ? 9 : 5, leaf: leaf, mass: mass, wood: wood)
        ShrubKit.finish(&m, height: 0.12, floor: 0.55)
        let b = m.bounds
        return m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
    }
}
