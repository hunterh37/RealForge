import simd
import Foundation

/// Quoin stack at an outside building corner: L-shaped chamfered stones alternating long and short
/// faces on the two walls. The corner arris is the vertical line at x = 0, z = 0 before centering;
/// the walls run along -X (front face, facing +Z) and -Z (side face, facing +X). Tile along Y.
public struct QuoinStack: RealAsset {
    public static let id = "quoin-stack"
    public static let summary = "Quoin stack, 1.8 m: alternating long and short chamfered corner stones wrapping a building corner; tiles along Y."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone", "wall"]
    public static let budget = 5_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 45, elevation: 10, distance: 1.05)

    /// Number of courses.
    public var courses = 6
    /// Course height including the joint (m).
    public var courseHeight: Float = 0.3
    /// Long and short face lengths (m), alternating per course.
    public var longFace: Float = 0.6
    public var shortFace: Float = 0.4
    /// Projection of the quoins proud of the wall faces (m).
    public var projection: Float = 0.025
    /// Depth the stones are bedded into the walls (m).
    public var bed: Float = 0.12
    /// Chamfer at the visible arrises (m).
    public var chamfer: Float = 0.015
    /// Rain streak and soot strength.
    public var weathering: Float = 0.5
    public var material: MaterialKey = "stone.limestone"
    /// Length of rendered wall returned on each face behind the quoins (m); 0 = quoins only.
    public var wallReturn: Float = 0.9
    public var wallMaterial: MaterialKey = "paint.stucco"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let pj = projection
        let tints = ["", ":D2C8B2", ":CFC4AC", ":DCD2BE"]
        for c in 0..<courses {
            var r = rng.fork(c)
            let a = c % 2 == 0 ? longFace : shortFace, b = c % 2 == 0 ? shortFace : longFace
            // Outline in (x, z): front leg along -X, side leg along -Z.
            let o: [V2] = [V2(pj, pj), V2(-a, pj), V2(-a, -bed), V2(-bed, -bed), V2(-bed, -b), V2(pj, -b)]
            let h = courseHeight - 0.01
            let s = Prim.extrude(o, depth: h, bevel: chamfer, bevelSegments: 1, material: material + r.pick(tints))
            // Extruded along Z; stand it up (outline y -> world z, depth -> y).
            m.add(s, Xform(translation: V3(r.float(-0.002...0.002), courseHeight * Float(c) + 0.005 + h / 2, 0),
                           rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))))
        }
        if wallReturn > 0 {
            let H = courseHeight * Float(courses), wt = bed - 0.004
            m.add(Prim.roundedBox(V3(wallReturn, H, wt), radius: 0.002, bevelSegments: 1, material: wallMaterial),
                  Xform(translation: V3(-wallReturn / 2, H / 2, -wt / 2)))
            m.add(Prim.roundedBox(V3(wt, H, wallReturn - wt), radius: 0.002, bevelSegments: 1, material: wallMaterial),
                  Xform(translation: V3(-wt / 2, H / 2, -wt - (wallReturn - wt) / 2)))
        }
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        groundAO(&m, height: 0.3, floor: 0.6)
        return LODModel(ArchTrimKit.ground(m))
    }
}
