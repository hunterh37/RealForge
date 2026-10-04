import simd
import Foundation

/// Ballfield dugout, 10 m x 2.6 m, at grade: painted block back and end walls, concrete slab floor,
/// standing-seam steel roof on steel beams with a fascia, open front with a padded pipe rail and
/// chain-link screen, long aluminum bench, wooden bat rack and helmet shelf on the back wall. Open side
/// toward +Z (the field); origin at the base center of the front edge.
public struct Dugout: RealAsset {
    public static let id = "dugout"
    public static let summary = "Dugout, 10 m: block walls, slab floor, steel roof, padded front rail with chain-link screen, bench, bat rack, helmet shelf."
    public static let tags = ["structure", "sports", "wall", "concrete", "metal", "outdoor"]
    public static let budget = 24_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 20, elevation: 12, distance: 1.0)

    public var length: Float = 10
    public var depth: Float = 2.6
    public var height: Float = 2.5
    public var walls: MaterialKey = "masonry.cmu-green"
    public var roof: MaterialKey = "metal.galvanized"
    public var trim: MaterialKey = "metal.painted:1E3A2A"
    public var mesh: MaterialKey = "fence.chainlink-vinyl"
    public init() {}

    /// Mesh in design coordinates (origin as documented above, before centering).
    func model(seed: UInt64) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length / 2, wt: Float = 0.2, zBack = -depth
        // Slab floor, 10 cm proud of grade, broom-finished concrete.
        m.add(Prim.roundedBox(V3(length, 0.1, depth), radius: 0.012, bevelSegments: 1, material: "concrete.smooth"),
              Xform(translation: V3(0, 0.05, -depth / 2)))
        // Back wall and end walls.
        m.add(Prim.roundedBox(V3(length + 2 * wt, height, wt), radius: 0.01, bevelSegments: 1, material: walls),
              Xform(translation: V3(0, height / 2, zBack - wt / 2)))
        for sx: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(wt, height, depth), radius: 0.01, bevelSegments: 1, material: walls),
                  Xform(translation: V3(sx * (L + wt / 2), height / 2, -depth / 2)))
        }
        // Roof: steel beams front and back, purlins, standing-seam sheet sloping to the back, fascia.
        let roofY = height + 0.02, front: Float = 0.5
        m.add(Prim.roundedBox(V3(length + 2 * wt + 0.2, 0.2, 0.1), radius: 0.004, bevelSegments: 1, material: trim),
              Xform(translation: V3(0, roofY + 0.1, front - 0.05)))
        let slope: Float = 0.06
        let span = depth + wt + front + 0.1
        let ang = atan2(slope, span) * 180 / .pi
        var sheet = Model(name: "roof")
        sheet.add(Prim.roundedBox(V3(length + 2 * wt + 0.3, 0.012, span), radius: 0.004, bevelSegments: 1, material: roof))
        var x = -L - wt
        while x <= L + wt + 0.01 {
            sheet.add(Prim.roundedBox(V3(0.025, 0.035, span), radius: 0.006, bevelSegments: 1, material: roof), Xform(translation: V3(x, 0.02, 0)))
            x += 0.4
        }
        m.add(sheet, Xform(translation: V3(0, roofY + 0.22 + slope / 2, front - span / 2 + 0.05), rotation: simd_quatf(degrees: -ang, axis: V3(1, 0, 0))))
        // Front posts holding the beam.
        let posts = 4
        for i in 0...posts {
            let px = -L + length * Float(i) / Float(posts)
            m.add(Prim.roundedBox(V3(0.1, roofY, 0.1), radius: 0.004, bevelSegments: 1, material: trim), Xform(translation: V3(px, roofY / 2, front - 0.05)))
        }
        // Padded front rail at 1.05 m and the chain-link screen above it, two openings at the ends.
        let railY: Float = 1.05, gap: Float = 1.3
        let x0 = -L + gap, x1 = L - gap
        m.add(BallKit.pipe(V3(x0, railY, front), V3(x1, railY, front), radius: 0.03, material: trim))
        m.add(BallKit.pipe(V3(x0, 0.45, front), V3(x1, 0.45, front), radius: 0.025, material: trim))
        var pad = Prim.superellipsoid(V3(x1 - x0, 0.14, 0.16), exponent: 6, subdivisions: 12, material: "padding.vinyl")
        pad.uvs = pad.uvs.map { $0 + V2(rng.float(0...1), 0) }
        m.add(pad, Xform(translation: V3(0, railY + 0.07, front)))
        m.add(BallKit.fence(V3(x0, railY + 0.14, front), V3(x1, railY + 0.14, front), height: roofY - railY - 0.14, material: mesh))
        for px in stride(from: x0, through: x1 + 0.01, by: (x1 - x0) / 4) {
            m.add(Prim.cylinder(radius: 0.03, height: railY, bevel: 0.005, segments: 10, material: trim), Xform(translation: V3(px, 0.1, front)))
        }
        // Bench: aluminum plank seat on steel legs along the back wall.
        let benchZ = zBack + 0.45
        for k in 0..<2 {
            var p = Prim.roundedBox(V3(length - 0.6, 0.04, 0.2), radius: 0.008, bevelSegments: 1, material: "metal.aluminum-brushed")
            p.uvs = p.uvs.map { $0 + V2(Float(k) * 0.7, 0) }
            m.add(p, Xform(translation: V3(0, 0.55, benchZ - 0.11 + Float(k) * 0.22)))
        }
        var lx = -L + 0.5
        while lx <= L - 0.4 {
            m.add(Prim.roundedBox(V3(0.05, 0.45, 0.4), radius: 0.004, bevelSegments: 1, material: trim), Xform(translation: V3(lx, 0.1 + 0.225, benchZ)))
            lx += 1.8
        }
        // Bat rack: two oak rails with notches at the back wall's right end, helmet shelf on the left.
        let rackX = L - 1.6
        for (y, d) in [(Float(1.25), Float(0.12)), (0.35, 0.06)] {
            m.add(plank(1.4, 0.1, 0.03, material: "wood.oak"), Xform(translation: V3(rackX, 0.1 + y, zBack + d / 2 + 0.02)))
        }
        for i in 0..<10 {
            let bx = rackX - 0.6 + Float(i) * 0.135
            m.add(Prim.roundedBox(V3(0.02, 0.05, 0.12), radius: 0.004, bevelSegments: 1, material: "wood.oak"), Xform(translation: V3(bx, 0.1 + 1.28, zBack + 0.08)))
        }
        let shelfX = -L + 2.0
        m.add(plank(2.4, 0.3, 0.025, material: "wood.oak"), Xform(translation: V3(shelfX, 1.45, zBack + 0.16)))
        for bx: Float in [-1.1, 0, 1.1] {
            m.add(Prim.roundedBox(V3(0.03, 0.25, 0.28), radius: 0.004, bevelSegments: 1, material: trim), Xform(translation: V3(shelfX + bx, 1.32, zBack + 0.15)))
        }
        // Cubby dividers above the shelf.
        for i in 0...6 {
            m.add(plank(0.3, 0.3, 0.02, material: "wood.oak"), Xform(translation: V3(shelfX - 1.2 + Float(i) * 0.4, 1.62, zBack + 0.16), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        }
        m.add(plank(2.4, 0.3, 0.025, material: "wood.oak"), Xform(translation: V3(shelfX, 1.79, zBack + 0.16)))
        groundAO(&m, height: 0.6, floor: 0.55)
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
