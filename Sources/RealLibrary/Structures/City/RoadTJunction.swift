import simd
import Foundation

/// T-junction tile on the 12 m city grid: a through road along X (connects west and east) with a
/// branch leaving the south (+Z) edge. The closed north (-Z) edge has a gutter pan and an edge line;
/// the branch carries a crosswalk, stop bar and centre-line stub. Top at y = 0.1.
public struct RoadTJunction: RealAsset {
    public static let id = "road-t-junction"
    public static let summary = "T-junction road tile, 12 m snap cell: east-west through road with a south branch, crosswalk and stop bar on the branch, gutter on the closed side."
    public static let tags = ["structure", "city", "street", "road", "tile", "outdoor", "concrete"]
    public static let budget = 5000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 40, distance: 0.9)

    /// Cell edge length (m).
    public var cell: Float = CityGrid.roadCell
    /// Slab thickness = road surface height (m).
    public var top: Float = CityGrid.roadTop
    /// Travel lane width (m).
    public var laneWidth: Float = 3.6
    /// Gutter pan width (m).
    public var gutterWidth: Float = 0.6
    /// Number of sealed cracks.
    public var cracks = 5
    /// Surface materials.
    public var asphalt: MaterialKey = "asphalt.road"
    public var gutter: MaterialKey = "concrete.sidewalk:8C8982"
    public var yellow: MaterialKey = "paint.lane-yellow"
    public var white: MaterialKey = "paint.lane-white"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let h = cell / 2, y = top, lw: Float = 0.1
        citySlab(&m, x: cell, z: cell, top: top, material: asphalt)
        // Closed north edge: full gutter, joints every 3 m, white edge line.
        citySlab(&m, x: cell - 0.004, z: gutterWidth - 0.004, top: top + 0.0008, material: gutter, at: V2(0, -(h - gutterWidth / 2)))
        for k in 0..<4 { let x = -h + 1.5 + Float(k) * 3
            cityLayer(&m, outline: [V2(x - 0.006, -h), V2(x + 0.006, -h), V2(x + 0.006, -h + gutterWidth), V2(x - 0.006, -h + gutterWidth)].reversedIfCW(), y: y, lift: 0.0012, thick: 0.001, material: "asphalt.patch") }
        cityStripe(&m, V2(-h, -(laneWidth + lw / 2)), V2(h, -(laneWidth + lw / 2)), width: lw, y: y, material: white, rng: &rng)
        // South corners: gutter squares where the curb returns meet.
        for s: Float in [-1, 1] {
            citySlab(&m, x: gutterWidth - 0.004, z: gutterWidth - 0.004, top: top + 0.0008, material: gutter, at: V2(s * (h - gutterWidth / 2), h - gutterWidth / 2))
        }
        // Through double yellow line, broken where the branch's left turns cross (kept solid on the north half).
        cityStripe(&m, V2(-h, -lw), V2(h, -lw), width: lw, y: y, material: yellow, rng: &rng)
        cityStripe(&m, V2(-h, lw), V2(-3.2, lw), width: lw, y: y, material: yellow, rng: &rng)
        cityStripe(&m, V2(3.2, lw), V2(h, lw), width: lw, y: y, material: yellow, rng: &rng)
        // Branch leg entering from +Z: k = 3 maps the -X edge to +Z.
        cityLegMarkings(&m, k: 3, cell: cell, y: y, laneWidth: laneWidth, barSpan: 9.6, white: white, yellow: yellow, rng: &rng)
        for _ in 0..<cracks {
            citySealedCrack(&m, start: V2(rng.float(-5...5), rng.float(-4...4)), angle: rng.float(0...(2 * .pi)), length: rng.float(1.5...4),
                            y: y, bounds: h - 0.7, rng: &rng)
        }
        cityPatch(&m, center: V2(rng.float(-4...(-2)), rng.float(-3...(-1.5))), size: V2(1.8, 1.1), angle: 0.02, y: y, rng: &rng)
        for _ in 0..<8 {
            let c = V2(rng.float(-5.5...5.5), rng.pick([-1, 1]) * laneWidth / 2 + rng.float(-0.25...0.25)), r = rng.float(0.08...0.22)
            cityLayer(&m, outline: Shape2D.circle(r, ry: r * rng.float(0.6...1), segments: 10).map { $0 + c }, y: y, lift: 0.0006, thick: 0.0008, material: "asphalt.patch")
        }
        groundAO(&m, height: 0.05, floor: 0.85)
        return LODModel(m)
    }
}
