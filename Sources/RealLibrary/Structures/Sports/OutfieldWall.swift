import simd
import Foundation

/// Padded outfield wall section, 4 m x 2.44 m (8 ft): painted CMU wall 0.2 m thick on a concrete
/// footing, field face covered by 1.2 m vinyl pad panels with sewn seams and bottom gaps, yellow
/// home-run line cap on top. Field face toward +Z, origin at the base center of the field face line;
/// tiles along X every `length` (sections may be yawed a few degrees to follow a curve).
public struct OutfieldWall: RealAsset {
    public static let id = "outfield-wall"
    public static let summary = "Padded outfield wall section, 4 m x 2.4 m: block wall, green vinyl pad panels, yellow home-run cap; tiles along X."
    public static let tags = ["structure", "sports", "wall", "barrier", "outdoor"]
    public static let budget = 6_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 25, elevation: 8, distance: 1.1)

    public var length: Float = 4.0
    public var height: Float = 2.44
    /// Padded panel width (seams between panels).
    public var panelWidth: Float = 1.0
    public var pad: MaterialKey = "padding.vinyl"
    public var block: MaterialKey = "masonry.cmu-green"
    public var cap: MaterialKey = "metal.painted:E2B21E"
    public init() {}

    /// Mesh in design coordinates (origin as documented above, before centering).
    func model(seed: UInt64) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length / 2, padT: Float = 0.1, wallT: Float = 0.2
        // Block wall behind the pads, slight overlap at the ends so tiled sections close.
        var wall = Prim.roundedBox(V3(length + 0.004, height - 0.06, wallT), radius: 0.01, bevelSegments: 1, material: block)
        wall.uvs = wall.uvs.map { $0 + V2(rng.float(0...0.8), 0) }
        m.add(wall, Xform(translation: V3(0, (height - 0.06) / 2, -padT - wallT / 2)))
        // Concrete footing lip at grade on the back.
        m.add(Prim.roundedBox(V3(length + 0.004, 0.12, 0.34), radius: 0.015, bevelSegments: 1, material: "concrete.rough"),
              Xform(translation: V3(0, 0.03, -padT - wallT / 2 - 0.02)))
        // Pad panels: foam slabs with rounded faces, 8 mm gaps, raised 3 cm off the track.
        let n = max(1, Int((length / panelWidth).rounded()))
        let pw = length / Float(n)
        for i in 0..<n {
            let x = -L + pw * (Float(i) + 0.5)
            let ph = height - 0.1 - 0.03
            var p = Prim.superellipsoid(V3(pw - 0.008, ph, padT), exponent: 8, subdivisions: 10, material: pad)
            p.uvs = p.uvs.map { $0 + V2(Float(i) * 0.37, 0) }
            let sag = rng.float(-0.004...0.004)
            m.add(p, Xform(translation: V3(x, 0.03 + ph / 2, -padT / 2 + sag)))
            // Sewn welt along the panel top and both edges.
            for sx: Float in [-1, 1] {
                m.add(Prim.tube([V3(x + sx * (pw / 2 - 0.02), 0.06, 0.001), V3(x + sx * (pw / 2 - 0.02), ph - 0.02, 0.001)], radii: [0.004, 0.004],
                                sides: 5, seamTile: 0.05, material: pad, capEnd: false))
            }
        }
        // Home-run line cap: folded steel coping over the wall and pad tops.
        let capW = padT + wallT + 0.04
        var c = Prim.roundedBox(V3(length + 0.004, 0.1, capW), radius: 0.008, bevelSegments: 2, material: cap)
        c.uvs = c.uvs.map { $0 + V2(rng.float(0...0.6), 0) }
        m.add(c, Xform(translation: V3(0, height - 0.05, -capW / 2 + 0.02)))
        m = m.transformed(Xform(translation: V3(0, -m.bounds.min.y, 0)))
        groundAO(&m, height: 0.4, floor: 0.6)
        return m
    }

    /// The mesh is re-centered on X/Z; `anchor` is where the design origin landed in mesh coordinates.
    /// Place the asset at `designPoint - anchor` (rotated with it) to put the design origin on `designPoint`.
    public func anchor(seed: UInt64 = 1) -> V2 { -BallKit.centerXZ(model(seed: seed)) }

    public func build(seed: UInt64) -> LODModel {
        let m = model(seed: seed), c = BallKit.centerXZ(m)
        return LODModel(m.transformed(Xform(translation: V3(-c.x, 0, -c.y))))
    }
}
