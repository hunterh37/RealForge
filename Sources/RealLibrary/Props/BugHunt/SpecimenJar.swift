import simd
import Foundation

/// Glass specimen jar, 13 cm tall: thick-walled clear glass with a rolled lip and a punted base,
/// a tapered cork stopper, a twine-tied paper label band.
public struct SpecimenJar: RealAsset {
    public static let id = "specimen-jar"
    public static let summary = "Glass specimen jar, 13 cm: thick clear glass, rolled lip, tapered cork stopper, twine-tied paper label; handheld."
    public static let tags = ["prop", "container", "glass", "antique", "handheld"]
    public static let budget = 5_000
    public static let preview = PreviewHint(azimuth: 30, elevation: 20, distance: 1.0, studio: true)

    public var radius: Float = 0.042
    public var height: Float = 0.11
    public var glass: MaterialKey = "glass.clear"
    public var cork: MaterialKey = "leather.split-tan:B08A58"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(segments: 48), model(segments: 20)], switchDistances: [3])
    }

    func model(segments: Int) -> Model {
        let r = radius, h = height, wall: Float = 0.0028
        var m = Model(name: Self.id)
        // Outer wall up, rolled lip, inner wall down to the punted floor (one closed lathe).
        let neck = r * 0.78
        let prof: [V2] = [V2(0.0001, 0.006), V2(r * 0.5, 0.004), V2(r * 0.92, 0.0), V2(r, 0.004), V2(r, h * 0.82), V2(r * 0.96, h * 0.88),
                          V2(neck, h * 0.93), V2(neck, h - 0.004), V2(neck + 0.0035, h - 0.002), V2(neck + 0.0035, h), V2(neck - wall, h),
                          V2(neck - wall, h * 0.93), V2(r - wall * 1.1, h * 0.87), V2(r - wall, h * 0.82), V2(r - wall, wall + 0.004), V2(r * 0.5, wall + 0.007), V2(0.0001, wall + 0.008)]
        m.add(Prim.lathe(prof, segments: segments, seamTile: 0.05, material: glass))
        // Cork: tapered plug with a domed top.
        let cp: [(Float, Float)] = [(0, h - 0.016), (neck - wall - 0.0004, h - 0.016), (neck - wall + 0.0006, h), (neck + 0.002, h + 0.004),
                                    (neck + 0.002, h + 0.016), (neck, h + 0.019), (0, h + 0.02)]
        m.add(turned(cp, segments: segments, material: cork))
        // Paper label band and twine.
        let lp: [(Float, Float)] = [(r + 0.0004, h * 0.32), (r + 0.0004, h * 0.6)]
        var label = turned([(r + 0.0003, h * 0.32), (r + 0.0006, h * 0.325), (r + 0.0006, h * 0.595), (r + 0.0003, h * 0.6)], segments: segments, material: "paper.sheet:EADDBA")
        label.material = "paper.sheet:EADDBA"
        _ = lp
        m.add(label)
        // Printed sepia border rules on the label.
        for y in [h * 0.34, h * 0.58] {
            m.add(Prim.torus(major: r + 0.0007, minor: 0.00025, segments: segments, sides: 4, material: "paper.sheet:5A3A22"), Xform(translation: V3(0, y, 0)))
        }
        m.add(Prim.torus(major: neck + 0.0012, minor: 0.0011, segments: segments, sides: 6, material: "sack.jute"), Xform(translation: V3(0, h * 0.95, 0)))
        groundAO(&m, height: 0.03, floor: 0.6)
        return m
    }
}
