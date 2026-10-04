import simd
import Foundation

/// Foul pole, 18 m: 12 in yellow steel pipe on a bolted base plate, with a 0.6 m mesh screen on the
/// fair side from 3 m up to the top, braced by short arms. Origin at the pole base; the screen extends
/// toward +X (place with the screen facing fair territory).
public struct FoulPole: RealAsset {
    public static let id = "foul-pole"
    public static let summary = "Foul pole, 18 m: yellow 12 in steel pipe, bolted base plate, yellow mesh screen on the fair side."
    public static let tags = ["structure", "sports", "metal", "outdoor"]
    public static let budget = 3_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 6, distance: 1.0)

    public var height: Float = 18
    public var radius: Float = 0.16
    public var screenWidth: Float = 0.6
    public var paint: MaterialKey = "metal.painted:E8BC1E"
    public var screen: MaterialKey = "fence.chainlink-vinyl:E2B41C"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        m.add(Prim.cylinder(radius: radius, height: height, bevel: 0.01, segments: 20, material: paint))
        // Cap and base plate with anchor nuts.
        m.add(Prim.cylinder(radius: radius + 0.01, height: 0.02, bevel: 0.004, segments: 20, material: paint), Xform(translation: V3(0, height, 0)))
        m.add(Prim.roundedBox(V3(0.6, 0.03, 0.6), radius: 0.006, bevelSegments: 1, material: paint), Xform(translation: V3(0, 0.015, 0)))
        for (dx, dz) in [(Float(-1), Float(-1)), (1, -1), (1, 1), (-1, 1)] {
            hexBolt(&m, at: V3(dx * 0.24, 0.03, dz * 0.24), normal: .up, size: 0.03, material: "metal.galvanized")
        }
        // Screen: frame of 2 in pipe off the pole, mesh between.
        let y0: Float = 3, y1 = height - 0.3, x0 = radius + 0.02, x1 = radius + screenWidth
        let fr: Float = 0.03
        m.add(BallKit.pipe(V3(x1, y0, 0), V3(x1, y1, 0), radius: fr, material: paint))
        var y = y0
        while y <= y1 + 0.01 {
            m.add(BallKit.pipe(V3(0, y, 0), V3(x1, y, 0), radius: fr * 0.8, material: paint))
            y += (y1 - y0) / 5
        }
        m.add(BallKit.fence(V3(x0, y0, 0), V3(x1, y0, 0), height: y1 - y0, material: screen))
        groundAO(&m, height: 0.3, floor: 0.7)
        return LODModel(m)
    }
}
