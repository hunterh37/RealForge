import simd
import Foundation

/// Road corner tile on the 12 m city grid: the two-lane road enters at the west (-X) edge and
/// leaves at the south (+Z) edge, bending around the south-west cell corner. The outer north-east
/// corner of the cell is raised sidewalk behind a curved granite curb and gutter pan, so the tile
/// joins `road-straight` on two edges and `sidewalk-curb` on the other two. Road top y = 0.1,
/// sidewalk top y = 0.25.
public struct RoadCorner: RealAsset {
    public static let id = "road-corner"
    public static let summary = "Road corner tile, 12 x 12 m snap cell: two-lane road turning 90 degrees between the west and south edges, curved double yellow line, granite curb and sidewalk filling the outer corner."
    public static let tags = ["structure", "city", "street", "road", "tile", "outdoor", "concrete", "stone"]
    public static let budget = 8600
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 210, elevation: 40, distance: 0.9)

    /// Cell edge length (m).
    public var cell: Float = CityGrid.roadCell
    /// Road surface height (m).
    public var top: Float = CityGrid.roadTop
    /// Sidewalk surface height (m).
    public var walkTop: Float = CityGrid.walkTop
    /// Travel lane width (m).
    public var laneWidth: Float = 3.6
    /// Gutter pan width (m).
    public var gutterWidth: Float = 0.6
    /// Curb width (m).
    public var curbWidth: Float = 0.15
    /// Number of sealed cracks.
    public var cracks = 5
    /// Surface materials.
    public var asphalt: MaterialKey = "asphalt.road"
    public var gutter: MaterialKey = "concrete.sidewalk:6F6C66"
    public var walk: MaterialKey = "concrete.sidewalk"
    public var curb: MaterialKey = "stone.granite-curb"
    public var yellow: MaterialKey = "paint.lane-yellow"
    public var white: MaterialKey = "paint.lane-white"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let h = cell / 2, y = top, c = V2(-h, h), R = cell
        citySlab(&m, x: cell, z: cell, top: top, material: asphalt)
        // Clipped arc limits for a ring radius r >= cell: where it meets the north and east edges.
        func aStart(_ r: Float) -> Float { r <= R ? -.pi / 2 : -asin(R / r) }
        func aEnd(_ r: Float) -> Float { r <= R ? 0 : -acos(R / r) }
        // Gutter pans: outer ring under the curb, inner quarter disc at the inside corner.
        let g0 = R - gutterWidth
        var gut = cityArc(c, R - 0.002, -.pi / 2, 0) + cityArc(c, g0, 0, -.pi / 2)
        gut = gut.reversedIfCW()
        cityLayer(&m, outline: gut, y: y, lift: 0.0004, thick: 0.0012, material: gutter)
        cityLayer(&m, outline: ([c] + cityArc(c, gutterWidth, -.pi / 2, 0)).reversedIfCW(), y: y, lift: 0.0004, thick: 0.0012, material: gutter)
        // Gutter joints every ~3 m of arc.
        for k in 1..<6 { let a = -Float.pi / 2 * (1 - Float(k) / 6), d = V2(cos(a), sin(a)), n = V2(-d.y, d.x) * 0.006
            cityLayer(&m, outline: [c + d * g0 - n, c + d * g0 + n, c + d * R + n, c + d * R - n].reversedIfCW(), y: y, lift: 0.0018, thick: 0.001, material: "asphalt.patch") }
        // Curved granite curb, cut into ~1.2 m stones with joints.
        let r1 = R + curbWidth
        let a0 = aStart(r1), a1 = aEnd(r1), stones = 16
        for i in 0..<stones {
            let s0 = -Float.pi / 2 + (Float.pi / 2) * Float(i) / Float(stones), s1 = -Float.pi / 2 + (Float.pi / 2) * Float(i + 1) / Float(stones)
            let o0 = max(s0, a0), o1 = min(s1, a1)
            let gap: Float = 0.003 / R
            var outline = cityArc(c, R, s0 + gap, s1 - gap, step: 0.2)
            if o1 > o0 { outline += cityArc(c, r1, o1 - gap, o0 + gap, step: 0.2) } else { continue }
            cityLayer(&m, outline: outline.reversedIfCW(), y: 0, lift: walkTop / 2 + rng.float(-0.003...0.001), thick: walkTop, bevel: 0.01, material: curb)
        }
        // Sidewalk fill behind the curb, cut into panels by radial and ring joints.
        let r2 = r1 + 0.004
        let fill = (cityArc(c, r2, aStart(r2), aEnd(r2)) + [V2(h, -h)]).reversedIfCW()
        cityLayer(&m, outline: fill, y: 0, lift: walkTop / 2 - 0.002, thick: walkTop - 0.004, bevel: 0.008, material: walk)
        for k in 1..<8 {
            let a = -Float.pi / 2 * (1 - Float(k) / 8), d = V2(cos(a), sin(a)), n = V2(-d.y, d.x) * 0.005
            // Joint from the curb out to the cell boundary along this ray.
            let far = min(abs(R / max(1e-3, d.x)), abs(R / max(1e-3, -d.y))) - 0.02
            guard far > r2 + 0.1 else { continue }
            cityLayer(&m, outline: [c + d * r2 - n, c + d * r2 + n, c + d * far + n, c + d * far - n].reversedIfCW(), y: walkTop - 0.002, lift: 0.0006, thick: 0.001, material: "asphalt.patch")
        }
        // Gum spots and drip stains on the walk.
        for _ in 0..<26 {
            let p = V2(rng.float(0...h), rng.float(-h...0)) + V2(0.2, -0.2)
            guard simd_distance(p, c) > r2 + 0.1, p.x < h - 0.05, p.y > -h + 0.05 else { continue }
            let r = rng.float(0.008...0.02)
            cityLayer(&m, outline: Shape2D.circle(r, segments: 8).map { $0 + p }, y: walkTop - 0.002, lift: 0.0006, thick: 0.001, material: "asphalt.worn")
        }
        // Lane paint around the bend: double yellow on the 6 m radius, white edge lines.
        let rc = R / 2
        for s: Float in [-1, 1] {
            cityArcStripe(&m, center: c, radius: rc + s * 0.1, from: -.pi / 2, to: 0, width: 0.1, y: y, material: yellow)
        }
        cityArcStripe(&m, center: c, radius: rc + laneWidth + 0.05, from: -.pi / 2, to: 0, width: 0.1, y: y, material: white)
        cityArcStripe(&m, center: c, radius: rc - laneWidth - 0.05, from: -.pi / 2, to: 0, width: 0.1, y: y, material: white)
        for _ in 0..<cracks {
            let a = rng.float(-1.4...(-0.2)), r = rng.float(3...10)
            citySealedCrack(&m, start: c + V2(cos(a), sin(a)) * r, angle: a + .pi / 2 + rng.float(-0.4...0.4), length: rng.float(1.5...3.5),
                            y: y, bounds: h - 0.7, rng: &rng)
        }
        groundAO(&m, height: 0.06, floor: 0.75)
        return LODModel(m)
    }
}
