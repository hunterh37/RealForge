import simd
import Foundation

/// Sidewalk tile on the 3 m city grid: broom-finished concrete slabs separated by tooled expansion
/// joints, behind a granite curb whose road face sits on the -Z cell edge. Four tiles line one edge
/// of a 12 m road cell. Walk top y = 0.25; the curb shows a 15 cm reveal above the road (y = 0.1).
public struct SidewalkCurb: RealAsset {
    public static let id = "sidewalk-curb"
    public static let summary = "Sidewalk tile, 3 x 3 m snap cell: 1.5 m broom-finished concrete slabs with tooled expansion joints behind a 15 cm granite curb along the road edge (-Z)."
    public static let tags = ["structure", "city", "street", "road", "tile", "outdoor", "concrete", "stone"]
    public static let budget = 3000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 200, elevation: 30, distance: 1.0)

    /// Cell edge length (m).
    public var cell: Float = CityGrid.walkCell
    /// Walk surface height (m).
    public var top: Float = CityGrid.walkTop
    /// Curb width (m).
    public var curbWidth: Float = 0.15
    /// Slabs across the walk (X) and deep (Z).
    public var slabs = (x: 2, z: 2)
    /// Expansion joint width (m).
    public var joint: Float = 0.01
    /// Include the curb (false for an inner sidewalk tile).
    public var hasCurb = true
    /// Gum and stain spots.
    public var spots = 14
    /// Materials.
    public var walk: MaterialKey = "concrete.sidewalk"
    public var curb: MaterialKey = "stone.granite-curb"
    public var jointFill: MaterialKey = "asphalt.patch"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let h = cell / 2, z0 = hasCurb ? -h + curbWidth : -h
        if hasCurb { cityCurb(&m, x0: -h, x1: h, z: z0, top: top, width: curbWidth, stone: 1.5, material: curb, rng: &rng) }
        // Joint bed under the slabs (dark, shows in the gaps).
        citySlab(&m, x: cell - 0.03, z: h - z0 - 0.03, top: top - 0.02, material: jointFill, at: V2(0, (z0 + h) / 2))
        let sx = cell / Float(slabs.x), sz = (h - z0) / Float(slabs.z)
        for i in 0..<slabs.x { for j in 0..<slabs.z {
            let cx = -h + sx * (Float(i) + 0.5), cz = z0 + sz * (Float(j) + 0.5)
            // One slab per tile settles a few mm and tilts (tree roots, frost).
            let settle: Float = rng.chance(0.25) ? -rng.float(0.003...0.008) : rng.float(-0.0015...0.0015)
            var s = Prim.roundedBox(V3(sx - joint, top, sz - joint), radius: 0.008, bevelSegments: 2, material: walk)
            for k in s.positions.indices where s.normals[k].y > 0.7 { s.uvs[k] = V2(s.positions[k].x + cx * 1.7, s.positions[k].z + cz * 1.3) }
            s.computeTangents()
            m.add(s, Xform(translation: V3(cx, top / 2 + settle, cz), rotation: simd_quatf(angle: rng.float(-0.002...0.002), axis: V3(1, 0, 0.3).normalized)))
            // Tooled control joint across the middle of each slab.
            let n: Float = 0.003
            cityLayer(&m, outline: [V2(cx - sx / 2 + 0.03, cz - n), V2(cx + sx / 2 - 0.03, cz - n), V2(cx + sx / 2 - 0.03, cz + n), V2(cx - sx / 2 + 0.03, cz + n)],
                      y: top + settle, lift: 0.0003, thick: 0.0008, material: jointFill)
        }}
        for _ in 0..<spots {
            let p = V2(rng.float(-h + 0.1...h - 0.1), rng.float(z0 + 0.1...h - 0.1)), r = rng.float(0.008...0.022)
            cityLayer(&m, outline: Shape2D.circle(r, segments: 8).map { $0 + p }, y: top, lift: 0.0012, thick: 0.001, material: "asphalt.worn")
        }
        groundAO(&m, height: 0.06, floor: 0.75)
        return LODModel(m)
    }
}
