import simd
import Foundation

/// Straight two-lane road tile on the 12 m city grid. Traffic runs along X; the tile repeats
/// seamlessly along X. Two 3.6 m lanes, 1.8 m parking strips and 0.6 m concrete gutter pans fill
/// the 12 m between curbs (curbs live on the adjacent `sidewalk-curb` tiles). Top at y = 0.1.
public struct RoadStraight: RealAsset {
    public static let id = "road-straight"
    public static let summary = "Straight two-lane road tile, 12 x 12 m snap cell: asphalt slab with oil-stained lanes, double yellow centre line, white edge lines, concrete gutter pans, crack sealant and a utility patch."
    public static let tags = ["structure", "city", "street", "road", "tile", "outdoor", "concrete"]
    public static let budget = 3200
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 32, distance: 0.9)

    /// Cell edge length (m), X and Z.
    public var cell: Float = CityGrid.roadCell
    /// Slab thickness = road surface height (m).
    public var top: Float = CityGrid.roadTop
    /// Travel lane width (m).
    public var laneWidth: Float = 3.6
    /// Gutter pan width at each curb (m).
    public var gutterWidth: Float = 0.6
    /// Paint line width (m).
    public var lineWidth: Float = 0.1
    /// Draw the white parking/edge lines.
    public var edgeLines = true
    /// Number of sealed cracks.
    public var cracks = 5
    /// Utility-cut patches.
    public var patches = 1
    /// Surface materials.
    public var asphalt: MaterialKey = "asphalt.road"
        public var gutter: MaterialKey = "concrete.sidewalk:8C8982"
    public var yellow: MaterialKey = "paint.lane-yellow"
    public var white: MaterialKey = "paint.lane-white"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let h = cell / 2, y = top
        citySlab(&m, x: cell, z: cell - 2 * gutterWidth, top: top, material: asphalt)
        // Gutter pans: concrete strips at both curb edges, flush with the asphalt.
        for s: Float in [-1, 1] {
            citySlab(&m, x: cell - 0.004, z: gutterWidth - 0.004, top: top + 0.0008, material: gutter, at: V2(0, s * (h - gutterWidth / 2)))
            // Gutter joints every 3 m.
            for k in 0..<4 { let x = -h + 1.5 + Float(k) * 3
                cityLayer(&m, outline: [V2(x - 0.006, s * (h - gutterWidth)), V2(x + 0.006, s * (h - gutterWidth)), V2(x + 0.006, s * h), V2(x - 0.006, s * h)].sorted { _, _ in false }.reversedIfCW(), y: y, lift: 0.0012, thick: 0.001, material: "asphalt.patch") }
        }
        // Double yellow centre line, white edge lines between lane and parking.
        for s: Float in [-1, 1] {
            cityStripe(&m, V2(-h, s * lineWidth), V2(h, s * lineWidth), width: lineWidth, y: y, material: yellow, rng: &rng)
            if edgeLines { cityStripe(&m, V2(-h, s * (laneWidth + lineWidth / 2)), V2(h, s * (laneWidth + lineWidth / 2)), width: lineWidth, y: y, material: white, rng: &rng) }
        }
        for _ in 0..<patches {
            cityPatch(&m, center: V2(rng.float(-3...3), rng.pick([-1, 1]) * rng.float(1.2...2.6)), size: V2(rng.float(1.4...2.6), rng.float(0.9...1.4)),
                      angle: rng.float(-0.05...0.05), y: y, rng: &rng)
        }
        for _ in 0..<cracks {
            let along = rng.chance(0.6)
            citySealedCrack(&m, start: V2(rng.float(-5...5), rng.float(-4.5...4.5)), angle: (along ? 0 : .pi / 2) + rng.float(-0.4...0.4) + (rng.chance(0.5) ? .pi : 0),
                            length: rng.float(1.5...4.5), y: y, bounds: h - gutterWidth - 0.05, rng: &rng)
        }
        // Oil drips down the lane centres.
        for _ in 0..<10 {
            let c = V2(rng.float(-5.5...5.5), rng.pick([-1, 1]) * laneWidth / 2 + rng.float(-0.25...0.25))
            let r = rng.float(0.08...0.25)
            cityLayer(&m, outline: Shape2D.circle(r, ry: r * rng.float(0.6...1), segments: 10).map { $0 + c }, y: y, lift: 0.0006, thick: 0.0008, material: "asphalt.patch")
        }
        groundAO(&m, height: 0.05, floor: 0.85)
        return LODModel(m)
    }
}

extension Array where Element == V2 {
    /// Counter-clockwise copy (positive area).
    func reversedIfCW() -> [V2] { Shape2D.area(self) < 0 ? reversed() : self }
}
