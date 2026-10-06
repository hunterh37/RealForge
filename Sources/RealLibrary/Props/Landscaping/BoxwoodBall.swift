import simd
import Foundation

/// Clipped boxwood topiary ball, 0.6 m: tight sphere of small glossy leaf sprays over a dark leaf-mass
/// core, a short trunk under a lifted skirt, and a few fresh shoots growing past the shear line.
public struct BoxwoodBall: RealAsset {
    public static let id = "boxwood-ball"
    public static let summary = "Clipped boxwood topiary ball, 0.6 m: tight sphere of small glossy leaves, a few fresh shoots past the shear line."
    public static let tags = ["prop", "landscaping", "garden", "plant", "foliage", "outdoor"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 15)

    /// Ball diameter and overall height (the ball sits just off the ground on its trunk), meters.
    public var diameter: Float = 0.6
    public var height: Float = 0.58
    public var sprays = 1500
    /// Unclipped shoots poking past the surface.
    public var shoots = 45
    public var leaf: MaterialKey = "leaf.boxwood"
    public var mass: MaterialKey = "leaf.boxwood-mass"
    public var wood: MaterialKey = "bark.oak-dry"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: 1), model(seed: seed, detail: 0.4)], switchDistances: [9])
    }

    func model(seed: UInt64, detail: Float) -> Model {
        var m = Model(name: Self.id)
        Self.ball(&m, center: V3(0, height - diameter / 2, 0), diameter: diameter, sprays: Int(Float(sprays) * detail),
                  shoots: detail > 0.5 ? shoots : 0, trunkBase: 0, seed: seed, coreSubdiv: detail > 0.5 ? 10 : 6,
                  leaf: leaf, mass: mass, wood: wood)
        ShrubKit.finish(&m, height: 0.2, floor: 0.5)
        return ShrubKit.fit(m, size: V3(diameter, height, diameter))
    }

    /// Clipped ball on a short trunk from `trunkBase` (y) up into the ball. Shared with `PottedBoxwood`.
    static func ball(_ m: inout Model, center: V3, diameter: Float, sprays: Int, shoots: Int, trunkBase: Float, seed: UInt64,
                     coreSubdiv: Int, leaf: MaterialKey, mass: MaterialKey, wood: MaterialKey) {
        var rng = SeededRNG(seed: seed)
        let card: Float = 0.12
        let r = diameter / 2 - card * 0.3
        let crown = ShrubKit.Crown(center: center, radii: V3(r, r * 0.97, r), exponent: 2, lumps: 0.05, lumpScale: 6,
                                   seed: rng.float(0...50), floorY: trunkBase + 0.03)
        m.add(ShrubKit.core(crown, depth: 0.93, subdivisions: coreSubdiv, material: mass))
        var a = rng.fork(1)
        m.add(ShrubKit.sprays(crown, count: sprays, size: (card * 0.85)...(card * 1.1), depth: 0.93...1.0, minY: -0.85,
                              tilt: 0.45, bend: 0.05...0.3, rng: &a, material: leaf))
        if shoots > 0 {
            var b = rng.fork(2)
            m.add(ShrubKit.sprays(crown, count: shoots, size: 0.08...0.11, aspect: 1.6, depth: 1.03...1.1, minY: -0.2,
                                  tilt: 0.3, bend: 0.0...0.15, rng: &b, material: leaf))
        }
        // Trunk: two or three short stems from the base fork up into the ball.
        var t = rng.fork(3)
        var s = Surface(material: wood)
        for i in 0..<3 {
            let ang = Float(i) * 2.1 + t.float(-0.4...0.4)
            let top = center + V3(cos(ang) * r * 0.25, -r * 0.3, sin(ang) * r * 0.25)
            let pts = catmull([V3(0, trunkBase, 0), V3(0, trunkBase + (top.y - trunkBase) * 0.4, 0), top], per: 3)
            let r0: Float = i == 0 ? 0.016 : 0.011
            s.append(Prim.tube(pts, radii: pts.indices.map { r0 * (1 - 0.5 * Float($0) / Float(pts.count - 1)) }, sides: 6,
                               seamTile: 0.05, material: wood))
        }
        m.add(s)
    }
}
