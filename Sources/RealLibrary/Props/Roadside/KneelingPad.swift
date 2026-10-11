import simd
import Foundation

/// Closed-cell foam kneeling pad with textured top, handle cutout and grimy end.
public struct KneelingPad: RealAsset {
    public static let id = "kneeling-pad"
    public static let summary = "40 x 25 cm closed-cell foam kneeling pad, 3 cm thick, blue with a black textured face and a carry-handle cutout."
    public static let tags = ["prop", "tool", "outdoor", "rubber", "handheld"]
    public static let budget = 4000
    public static let author = "realityhd"

    /// Pad length (X), thickness (Y) and width (Z) in meters.
    public var size = V3(0.40, 0.03, 0.25)
    /// Foam colour.
    public var foamMaterial = "rubber.silicone-gray:2F5E9E"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = size.x, T = size.y, W = size.z
        let outline = Shape2D.roundedRect(L, W, radius: 0.04, segments: 6)
        // Foam slab (XZ plane): extrude in XY then lay flat.
        let lay = simd_quatf(degrees: -90, axis: V3(1, 0, 0))
        var hole = Shape2D.roundedRect(0.1, 0.022, radius: 0.011, segments: 6).map { V2($0.x, $0.y - 0.0) }
        hole = hole.map { V2($0.x, $0.y) }
        m.add(Prim.extrude(outline, depth: T, bevel: 0.007, bevelSegments: 3, material: foamMaterial), Xform(translation: V3(0, T / 2, 0), rotation: lay))
        // Black textured top skin with a raised rim and a pebble grid.
        m.add(Prim.extrude(Shape2D.offset(outline, -0.012), depth: 0.004, bevel: 0.0015, bevelSegments: 2, material: "rubber.floor-mat"), Xform(translation: V3(0, T + 0.0015, 0), rotation: lay))
        // Raised ribs across the top face, skipping the handle zone.
        for i in 0..<14 {
            let x = (Float(i) + 0.5) / 14 - 0.5
            if abs(x * L) < 0.062 {
                for sz: Float in [-1, 1] {
                    m.add(Prim.roundedBox(V3(0.007, 0.0014, W * 0.5 - 0.05), radius: 0.0004, bevelSegments: 1, material: "rubber.floor-mat"),
                          Xform(translation: V3(x * (L - 0.05), T + 0.0046, sz * (W * 0.25 + 0.0125))))
                }
            } else {
                m.add(Prim.roundedBox(V3(0.007, 0.0014, W - 0.05), radius: 0.0004, bevelSegments: 1, material: "rubber.floor-mat"), Xform(translation: V3(x * (L - 0.05), T + 0.0046, 0)))
            }
        }
        // Handle cutout: a dark recess with a lip, set into the top face.
        m.add(Prim.extrude(hole, depth: 0.0016, bevel: 0.0006, bevelSegments: 1, material: "plastic.black"), Xform(translation: V3(0, T + 0.0058, 0), rotation: lay))
        m.add(Prim.extrude(Shape2D.roundedRect(0.108, 0.03, radius: 0.015, segments: 6), depth: 0.0012, bevel: 0.0004, bevelSegments: 1, material: foamMaterial), Xform(translation: V3(0, T + 0.0054, 0), rotation: lay))
        // Dirt scuffs: dark grime patches near one end, knee dents.
        for _ in 0..<4 {
            m.add(Prim.superellipsoid(V3(rng.float(0.03...0.06), 0.0012, rng.float(0.02...0.045)), exponent: 3, subdivisions: 4, material: "plastic.black"),
                  Xform(translation: V3(rng.float(0.1...0.17), T + 0.0054, rng.float(-0.06...0.06))))
        }
        groundAO(&m, height: 0.04, floor: 0.55)
        return LODModel(m)
    }
}
