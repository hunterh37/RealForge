import simd
import Foundation

/// Shoulder-strap segment, exactly 1.0 m along +Y (y = 0...1), 38 mm wide (x) and 4 mm thick (z):
/// saddle-tan full-grain leather with burnished rolled edges and a row of saddle stitching inside
/// each edge on both faces. No end hardware and no detail that varies along Y, so it can be scaled
/// along Y at runtime.
public struct LeatherStrap: RealAsset {
    public static let id = "leather-strap"
    public static let summary = "Shoulder-strap segment, 1.0 m x 38 mm x 4 mm: saddle-tan leather, burnished edges, edge stitching both sides."
    public static let tags = ["prop", "leather"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 15, distance: 1.6, studio: true)

    /// Width (x), length (y) and thickness (z) in meters.
    public var size = V3(0.038, 1.0, 0.004)
    /// Strap leather (same as `crossbody-bag`).
    public var leather: MaterialKey = "leather.oxblood-worn:8E5228"
    /// Burnished edges.
    public var edge: MaterialKey = "leather.oxblood:3A2212"
    /// Waxed saddle thread.
    public var thread: MaterialKey = "fabric.linen:E6D7B0"
    /// Stitch row distance from each edge (m).
    public var stitchInset: Float = 0.0045
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        let w = size.x, len = size.y, t = size.z
        let path = [V3(0, 0, 0), V3(0, len, 0)]
        let ew: Float = 0.0045                                  // rolled edge band width
        var m = Model(name: Self.id)
        // Flat band, slightly thinner than the rolled edges so faces never coincide.
        m.add(Prim.sweep(Shape2D.rect(w - 2 * ew + 0.001, t - 0.0006), along: path, up: V3(1, 0, 0), material: leather))
        for sx: Float in [-1, 1] {
            let edgeBand = Prim.sweep(Shape2D.roundedRect(ew, t, radius: t * 0.48, segments: 4), along: path, up: V3(1, 0, 0), material: edge)
            m.add(edgeBand, Xform(translation: V3(sx * (w / 2 - ew / 2), 0, 0)))
        }
        let lite = m
        for sx: Float in [-1, 1] {
            for sz: Float in [-1, 1] {
                let x = sx * (w / 2 - stitchInset - 0.0012)
                m.add(stitches(along: [V3(x, 0.002, sz * (t / 2 - 0.00055)), V3(x, len - 0.002, sz * (t / 2 - 0.00055))],
                               normal: { _ in V3(0, 0, sz) }, pitch: 0.0045, thread: 0.0004, material: thread))
            }
        }
        return LODModel(levels: [m, lite], switchDistances: [2.5])
    }
}
