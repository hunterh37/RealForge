import simd
import Foundation

/// Cedar lattice trellis panel, 1.85 m tall: two stiles with caps, an arched
/// top rail, a bottom rail and a diagonal lattice of thin slats clipped at the frame. Weathered grey.
/// Built in the XY plane, 0.06 m deep.
public struct GardenTrellis: RealAsset {
    public static let id = "garden-trellis"
    public static let summary = "Cedar lattice trellis, 1.85 m: two stiles, arched top rail, two-layer diagonal lattice, bottom rail."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "wood", "fence"]
    public static let budget = 13000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 10)

    /// Panel width (m).
    public var width: Float = 0.62
    /// Height above grade (m).
    public var height: Float = 1.85
    /// Lattice spacing (m).
    public var spacing: Float = 0.11
    /// Wood material.
    public var wood: MaterialKey = "wood.weathered"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let w = width, h = height, stile: Float = 0.04, d: Float = 0.04
        let arch: Float = 0.1, topY = h - arch - 0.03
        for s: Float in [-1, 1] {
            let (b, x) = board(from: V3(s * (w / 2 - stile / 2), 0, 0), to: V3(s * (w / 2 - stile / 2), topY + 0.02, 0), width: d, thick: stile, up: V3(1, 0, 0), material: wood)
            m.add(b, x.jittered(&rng, deg: 0.5))
            // Pointed stake top caps.
            m.add(Prim.roundedBox(V3(stile + 0.006, 0.02, d + 0.006), radius: 0.004, bevelSegments: 2, material: wood), Xform(translation: V3(s * (w / 2 - stile / 2), topY + 0.03, 0)))
        }
        // Bottom rail.
        m.add(plank(w - 2 * stile + 0.004, d, 0.035, material: wood), Xform(translation: V3(0, 0.12, 0)))
        // Arched top rail swept through an arc.
        let arcPts = (0...16).map { k -> V3 in
            let t = Float(k) / 16, x = -w / 2 + t * w
            return V3(x, topY + 0.02 + sin(t * .pi) * arch, 0)
        }
        m.add(Prim.sweep(Shape2D.roundedRect(0.045, d, radius: 0.005), along: arcPts, up: .up, grainAlongPath: true, material: wood))
        // Lattice: two diagonal sets in front/back layers, clipped to the frame.
        let x0 = -w / 2 + stile, x1 = w / 2 - stile, y0: Float = 0.12 + 0.0175, y1 = topY + 0.02
        let slatW: Float = 0.022, slatT: Float = 0.008
        for (layer, dir) in [(Float(-1), Float(1)), (Float(1), Float(-1))] {
            var c = -(x1 - x0) - (y1 - y0)
            while c < (x1 - x0) + (y1 - y0) {
                // Line x - dir * y = c in local (x - x0, y - y0).
                var pts: [V3] = []
                for y in stride(from: y0, through: y1, by: 0.01) {
                    let x = x0 + c + dir * (y - y0)
                    if x >= x0, x <= x1 { pts.append(V3(x, y, layer * (slatT / 2 + 0.0005))) }
                }
                if pts.count >= 2, simd_distance(pts.first!, pts.last!) > 0.03 {
                    let (b, x) = board(from: pts.first!, to: pts.last!, width: slatW, thick: slatT, up: V3(0, 0, 1), bevel: 0.002, material: wood)
                    m.add(b, x.jittered(&rng, deg: 0.15, offset: 0.0005))
                }
                c += spacing * 1.414
            }
        }
        groundAO(&m, height: 0.2)
        return LODModel(m)
    }
}
