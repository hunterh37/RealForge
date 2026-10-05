import simd
import Foundation

/// Raw boneless skinless chicken breast lying along +X, thick rounded end at -X tapering to a thin tip
/// at +X. One closed shell: domed top, flattened underside, a gentle kidney curve in plan, the
/// tenderloin as a separate lobe along the -Z underside edge with a seam groove, and soft
/// irregular swelling. Fiber grain, fat striations, silverskin and wet sheen live in `food.chicken-raw`.
public struct ChickenBreast: RealFood {
    public static let id = "chicken-breast"
    public static let summary = "Raw boneless skinless chicken breast, 20 x 10 x 3 cm: teardrop lobe with tenderloin, fiber grain, fat striations, silverskin, wet sheen."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.protein
    public static let preview = PreviewHint(azimuth: 25, elevation: 35, distance: 0.45, studio: true)

    /// Length along X (m).
    public var length: Float = 0.2
    /// Widest plan width along Z (m).
    public var width: Float = 0.1
    /// Thickest point (m).
    public var thickness: Float = 0.03
    /// Surface material (raw).
    public var flesh: MaterialKey = "food.chicken-raw"
    /// Cut-face material (end grain).
    public var cutFace: MaterialKey = "food.chicken-flesh"
    /// Target triangle edge (m).
    public var edge: Float = 0.0032
    public init() {}

    public var coreCenter: V3 { V3(0, thickness * 0.45, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == flesh ? cutFace : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = length, hw = width / 2, ht = thickness / 2
        // Build along +Y (s = 0 thick round end), w = half thickness, d = half width.
        var s = FoodMesh.sections(edge: edge, length: L, seamTile: 0.06, material: flesh) { t in
            let plan = pow(sin(Float.pi * min(1, t * 1.6) * 0.5), 0.55) * (1 - 0.62 * pow(t, 1.4)) * pow(1 - t, 0.35)
            let thick = pow(sin(Float.pi * min(1, t * 2.2) * 0.5), 0.7) * (1 - 0.7 * pow(t, 1.2)) * pow(1 - t, 0.3)
            return (max(1e-4, ht * thick), max(1e-4, hw * plan), 2.0, .zero)
        }
        s = FoodMesh.layAlongX(s)
        // Now x along the length (0...L), y thickness (+-), z width (+-).
        let ph = (0..<6).map { _ in rng.float(0...6.28) }
        let bendAmt = rng.float(0.008...0.013)
        s.deform { p in
            let t = p.x / L
            var q = p
            // Flattened underside, fuller dome on top.
            let up = 0.5 + 0.5 * tanh(q.y / 0.002)   // smooth top/bottom split, no step at the rim
            q.y *= 0.42 + (0.63 + 0.1 * sin(t * 3 + ph[0])) * up
            // Tenderloin: a lobe along the -Z edge on the underside half of the length, with a seam.
            let lobe = smoothstep(0.12, 0.3, t) * (1 - smoothstep(0.7, 0.92, t))
            let edgeW = hw * (1 - 0.5 * t)
            let zn = q.z / max(edgeW, 1e-3)
            let k = smoothstep(-0.35, -0.75, zn) * lobe
            q.z -= 0.009 * k
            q.y += (0.003 * up - 0.0015 * (1 - up)) * k
            let seam = exp(-pow((zn + 0.48) / 0.11, 2)) * lobe * up
            q.y -= 0.0026 * seam
            // Soft swelling and fiber ripples (fibers fan from the thick end toward the tip).
            let swell = 0.0008 * sin(p.x * 60 + ph[1]) * sin(p.z * 70 + ph[2]) + 0.0004 * sin(p.x * 110 + p.z * 50 + ph[3])
            q.y += swell * (0.3 + 0.7 * up) * smoothstep(0, 0.1, t) * (1 - smoothstep(0.9, 1, t))
            // Kidney curve in plan.
            q.z += bendAmt * sin(Float.pi * t) - bendAmt * 0.5
            return q
        }
        var m = Model(name: Self.id)
        m.add(FoodMesh.fit(s, size: V3(L, thickness, width)))
        groundAO(&m, height: 0.012, floor: 0.75)
        return LODModel(m)
    }
}
