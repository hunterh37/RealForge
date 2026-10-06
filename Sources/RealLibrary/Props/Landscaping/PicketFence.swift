import simd
import Foundation

/// White picket fence segment, 2.4 m (8 ft) bay, 1.07 m tall: two 4x4 posts with pyramid caps, two
/// 2x4 rails on the back, 1x4 pickets with pointed tops at 6 cm spacing, galvanized nail heads.
/// Paint is chipped and dirt-splashed near the ground; pickets vary slightly in height and lean.
public struct PicketFence: RealAsset {
    public static let id = "picket-fence"
    public static let summary = "White picket fence segment, 2.4 m x 1.07 m: 4x4 posts with caps, two back rails, pointed 1x4 pickets, nail heads, worn paint."
    public static let tags = ["prop", "garden", "outdoor", "landscaping", "wood", "fence", "barrier"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 10, distance: 1.05, studio: true)

    /// Post-center to post-center length along X (m).
    public var length: Float = 2.4
    /// Picket height (m).
    public var height: Float = 1.0
    /// Gap between pickets (m).
    public var gap: Float = 0.06
    /// Picket width (m).
    public var picketWidth: Float = 0.089
    /// Painted lumber material.
    public var paint: MaterialKey = "wood.barn-white"
    /// Nail material.
    public var nails: MaterialKey = "metal.galvanized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        let post: Float = 0.089, postH = height + 0.07
        let pt: Float = 0.019, railT: Float = 0.038, railH: Float = 0.089
        // Posts with pyramid caps.
        for sx: Float in [-0.5, 0.5] {
            let x = sx * length
            var r = rng.fork(Int(sx * 4 + 2))
            let pb = board(from: V3(x, 0, 0), to: V3(x, postH, 0), width: post, thick: post, up: V3(1, 0, 0), bevel: 0.004, material: paint)
            m.add(pb.0, pb.1.jittered(&r, deg: 0.3, offset: 0.001)); lite.add(pb.0, pb.1)
            let cap = Prim.loft([Prim.ring(Shape2D.rect(post + 0.02, post + 0.02), y: 0), Prim.ring(Shape2D.rect(post + 0.02, post + 0.02), y: 0.02),
                                 Prim.ring(Shape2D.rect(0.012, 0.012), y: 0.065)], capStart: true, capEnd: true, material: paint)
            m.add(cap, Xform(translation: V3(x, postH, 0))); lite.add(cap, Xform(translation: V3(x, postH, 0)))
        }
        // Rails on the back (-Z) of the pickets, between posts.
        let railZ = -(pt / 2 + railT / 2 + 0.001)
        let railLen = length - post - 0.002
        for y in [height * 0.2, height * 0.75] {
            let s = Prim.roundedBox(V3(railLen, railH, railT), radius: 0.004, bevelSegments: 1, material: paint)
            m.add(s, Xform(translation: V3(0, y, railZ))); lite.add(s, Xform(translation: V3(0, y, railZ)))
        }
        // Pickets on the front of the rails.
        let pitch = picketWidth + gap
        let span = length - post - 0.02
        let count = max(1, Int(span / pitch))
        let start = -Float(count - 1) * pitch / 2
        let w = picketWidth
        for i in 0..<count {
            var r = rng.fork(100 + i)
            let x = start + Float(i) * pitch
            let h = height - 0.05 + r.float(-0.006...0.006)
            let tip: Float = 0.055
            let outline = Shape2D.rounded([V2(0.06, -w / 2), V2(h - tip, -w / 2), V2(h, 0), V2(h - tip, w / 2), V2(0.06, w / 2)], radius: 0.004, segments: 2)
            let s = Prim.extrude(outline, depth: pt, bevel: 0.002, bevelSegments: 1, material: paint)
            let xf = Xform(translation: V3(x, 0, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))).jittered(&r, deg: 0.5, offset: 0.0015)
            m.add(s, xf); lite.add(s, xf)
            for y in [height * 0.2, height * 0.75] {
                for dx: Float in [-0.02, 0.02] {
                    m.add(Prim.cylinder(radius: 0.0032, height: 0.0015, bevel: 0.0006, segments: 8, bevelSegments: 1, material: nails),
                          Xform(translation: V3(x + dx, y + r.float(-0.01...0.01), pt / 2), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
                }
            }
        }
        let bb = m.bounds
        let shift = V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)
        m = m.transformed(Xform(translation: shift)); lite = lite.transformed(Xform(translation: shift))
        groundAO(&m, height: 0.3, floor: 0.55); groundAO(&lite, height: 0.3, floor: 0.55)
        return LODModel(levels: [m, lite], switchDistances: [12])
    }
}
