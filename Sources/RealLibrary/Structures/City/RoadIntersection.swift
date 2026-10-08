import simd
import Foundation

/// Four-way intersection tile on the 12 m city grid: an asphalt box whose four legs each carry a
/// continental crosswalk, a stop bar and a centre-line stub. Connects to `road-straight` on every
/// edge. Concrete gutter squares sit at the four corners where the curb returns meet. Top at y = 0.1.
public struct RoadIntersection: RealAsset {
    public static let id = "road-intersection"
    public static let summary = "Four-way intersection tile, 12 m snap cell: asphalt box with continental crosswalks and stop bars on four legs, corner gutters, sealed cracks."
    public static let tags = ["structure", "city", "street", "road", "tile", "outdoor", "concrete"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 40, distance: 0.9)

    /// Cell edge length (m).
    public var cell: Float = CityGrid.roadCell
    /// Slab thickness = road surface height (m).
    public var top: Float = CityGrid.roadTop
    /// Travel lane width (m).
    public var laneWidth: Float = 3.6
    /// Gutter pan width (m).
    public var gutterWidth: Float = 0.6
    /// Number of sealed cracks.
    public var cracks = 6
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
        citySlab(&m, x: cell, z: cell, top: top, material: asphalt)
        for k in 0..<4 {
            let c = quarter(V2(h - gutterWidth / 2, h - gutterWidth / 2), k)
            citySlab(&m, x: gutterWidth - 0.004, z: gutterWidth - 0.004, top: top + 0.0008, material: gutter, at: c)
            cityLegMarkings(&m, k: k, cell: cell, y: y, laneWidth: laneWidth, barSpan: 6, white: white, yellow: yellow, rng: &rng)
        }
        for _ in 0..<cracks {
            citySealedCrack(&m, start: V2(rng.float(-3.5...3.5), rng.float(-3.5...3.5)), angle: rng.float(0...(2 * .pi)),
                            length: rng.float(1.5...4), y: y, bounds: h - 0.7, rng: &rng)
        }
        for _ in 0..<8 {
            let c = quarter(V2(rng.float(-5...(-3.6)), rng.float(1...2.6)), rng.int(0...3)), r = rng.float(0.08...0.22)
            cityLayer(&m, outline: Shape2D.circle(r, ry: r * rng.float(0.6...1), segments: 10).map { $0 + c }, y: y, lift: 0.0006, thick: 0.0008, material: "asphalt.patch")
        }
        groundAO(&m, height: 0.05, floor: 0.85)
        return LODModel(m)
    }
}
