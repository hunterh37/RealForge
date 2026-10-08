import simd
import Foundation

/// Ornamental iron park fence segment, 2.4 m between post centers: square posts with cast ball
/// caps, three flat rails, square pickets through the rails with cast spear finials, and a scroll
/// band between the lower rails. Panels tile along X post-to-post.
public struct OrnamentalFence: RealAsset {
    public static let id = "ornamental-fence"
    public static let summary = "Ornamental iron fence segment, 2.4 m: square posts with ball caps, rails and spear-top pickets."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal", "fence"]
    public static let budget = 7500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 10, distance: 1.0)

    /// Post spacing (m).
    public var span: Float = 2.4
    /// Picket height above grade (m).
    public var height: Float = 1.2
    /// Picket spacing (m).
    public var spacing: Float = 0.125
    /// Include the posts (false for the middle of a long run).
    public var posts = true
    /// Paint.
    public var iron: MaterialKey = "metal.painted:1C1D1E"
    public var worn: MaterialKey = "metal.iron"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let half = span / 2, ps: Float = 0.08
        if posts {
            for s: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(ps + 0.04, 0.03, ps + 0.04), radius: 0.006, bevelSegments: 1, material: worn), Xform(translation: V3(s * half, 0.015, 0)))
                m.add(Prim.roundedBox(V3(ps, height + 0.05, ps), radius: 0.006, bevelSegments: 2, material: iron), Xform(translation: V3(s * half, 0.03 + (height + 0.05) / 2, 0)))
                m.add(turned([(0, height + 0.08), (0.05, height + 0.08), (0.05, height + 0.1), (0.03, height + 0.12), (0.025, height + 0.13)] +
                             (0...8).map { i -> (Float, Float) in let a = -Float.pi / 2 + Float.pi * Float(i) / 8; return (0.045 * cos(a), height + 0.175 + 0.045 * sin(a)) },
                             segments: 16, material: iron), Xform(translation: V3(s * half, 0, 0)))
            }
        }
        // Rails: flat bars between the posts.
        let inner = span - ps
        for y in [Float(0.1), 0.3, height - 0.1] {
            m.add(Prim.roundedBox(V3(inner, 0.038, 0.012), radius: 0.003, bevelSegments: 1, material: iron), Xform(translation: V3(0, y, 0)))
        }
        // Pickets with spear finials; one picket slightly bent (old impact).
        let n = Int(inner / spacing)
        let x0 = -Float(n - 1) * spacing / 2
        for i in 0..<n {
            let x = x0 + Float(i) * spacing
            let bend: Float = i == n / 3 ? 0.015 : 0
            m.add(Prim.roundedBox(V3(0.016, height - 0.1, 0.016), radius: 0.002, bevelSegments: 1, material: iron),
                  Xform(translation: V3(x, 0.06 + (height - 0.1) / 2, 0), rotation: simd_quatf(angle: bend, axis: V3(0, 0, 1))))
            m.add(turned([(0, height - 0.05), (0.012, height - 0.05), (0.014, height - 0.04), (0.008, height - 0.035), (0.022, height - 0.02), (0.002, height + 0.04), (0, height + 0.045)],
                         segments: 4, material: iron), Xform(translation: V3(x + bend * (height - 0.1) * -0.5, 0, 0), rotation: simd_quatf(degrees: 45, axis: .up)))
        }
        // Scroll band: C-scrolls between the two lower rails.
        for i in 0..<(n - 1) {
            let x = x0 + (Float(i) + 0.5) * spacing
            let pts = (0...10).map { k -> V3 in let a = Float(k) / 10 * 1.6 * .pi; let r = 0.05 * (1 - Float(k) / 14); return V3(x + r * sin(a) * 0.9, 0.2 + r * cos(a), 0) }
            m.add(Prim.tube(pts, radii: Array(repeating: 0.004, count: pts.count), sides: 4, seamTile: 0.05, material: iron))
        }
        // Rust weeping at the bottom rail where water sits.
        for _ in 0..<6 {
            m.add(cuboid(V3(rng.float(0.02...0.06), rng.float(0.01...0.03), 0.0008), material: "metal.rust"),
                  Xform(translation: V3(rng.float(-half...half) * 0.9, 0.1 - 0.012, 0.0066)))
        }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
