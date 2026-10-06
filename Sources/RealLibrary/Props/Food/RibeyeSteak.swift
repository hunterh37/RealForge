import simd
import Foundation

/// Raw boneless ribeye steak, 2.5 cm thick, lying flat. The lean eye is a slab with an irregular
/// rounded plan, soft uneven faces and marbling in `food.beef-raw`; a fat cap wraps the outer edge
/// over the spinalis side and a thin fat seam crosses the steak between the eye and the cap, both
/// as separate closed shells (cut face `food.beef-fat`). Lean cut face: `food.beef-section`.
public struct RibeyeSteak: RealFood {
    public static let id = "ribeye-steak"
    public static let summary = "Raw boneless ribeye, 20 x 14 x 2.5 cm: marbled lean eye, spinalis cap, fat seam and fat cap rim."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let kind = FoodKind.protein
    public static let preview = PreviewHint(azimuth: 25, elevation: 40, distance: 0.45, studio: true)

    /// Plan length along X (m).
    public var length: Float = 0.2
    /// Plan width along Z (m).
    public var width: Float = 0.14
    /// Thickness (m).
    public var thickness: Float = 0.025
    /// Fat cap width outside the lean (m).
    public var fatCap: Float = 0.0072
    /// Material keys.
    public var lean: MaterialKey = "food.beef-raw"
    public var leanCut: MaterialKey = "food.beef-section"
    public var fat: MaterialKey = "food.beef-fat"
    public init() {}

    public var coreCenter: V3 { V3(0, thickness / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        if key == lean { return leanCut }
        if key == fat { return fat }
        return nil
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let a0 = length / 2, b0 = width / 2, T = thickness
        let ph = (0..<5).map { _ in rng.float(0...6.28) }
        // Ribeye plan: oval, fuller on the cap side (-Z), a shallow notch where the tail meets.
        let radius: (Float) -> Float = { a in
            let e = 1 / sqrt(pow(cos(a) / a0, 2) + pow(sin(a) / b0, 2))
            let lobe = 1 + 0.05 * sin(a) + 0.035 * cos(2 * a + ph[0]) + 0.02 * sin(3 * a + ph[1]) + 0.012 * sin(5 * a + ph[2])
            let notch = 1 - 0.06 * exp(-pow((a - 4.6) / 0.25, 2))
            return e * lobe * notch * 0.97
        }
        let outline = RecipeMesh.loop(radius: radius)
        var eye = RecipeMesh.slab(outline: outline, thickness: T, bevel: 0.0035, edge: 0.0055, material: lean)
        let seedU = UInt32(truncatingIfNeeded: seed)
        let shape: (V3) -> V3 = { p in
            var q = p
            let f = q.y / T                       // 0 bottom, 1 top
            let topW = smoothstep(0.5, 1, f), botW = 1 - smoothstep(0, 0.5, f)
            let n1 = RecipeMesh.noise(V3(p.x, 0, p.z), 28, seed: seedU &+ 3)
            let n2 = RecipeMesh.noise(V3(p.x, 0, p.z), 70, seed: seedU &+ 4)
            // Soft dome and uneven butcher-cut faces; bottom settles flatter.
            let rr = simd_length(V2(p.x / a0, p.z / b0))
            q.y += topW * (0.0006 * (1 - rr * rr) + 0.0007 * n1 + 0.00025 * n2)
            q.y += botW * (0.0003 * n1)
            // Sides bulge a little at mid height.
            let side = 4 * f * (1 - f)
            let k = 1 + 0.012 * side + 0.004 * n1
            q.x *= k; q.z *= k
            return q
        }
        eye.deform(shape)
        eye = FoodMesh.boxUV(eye)
        var m = Model(name: Self.id)
        m.add(eye)
        // Fat cap: a rounded band hugging the outer edge on the cap side.
        let capPath: [V3] = stride(from: Float(0.35), through: 2.85, by: 0.05).map { a in
            let r = radius(a) * 1.0 + 0.0015
            return V3(r * cos(a), T * 0.5, -r * sin(a))
        }
        let hw = fatCap, hh = T * 0.5 * 0.96
        let capS = RecipeMesh.sweep(capPath, edge: 0.004, endBulge: 0.3, material: fat) { t, ang in
            let taper = pow(sin(Float.pi * t), 0.35)
            let w = max(0.0004, hw * taper * (0.85 + 0.15 * sin(t * 9 + ph[3]))), h = hh * (0.55 + 0.45 * taper)
            let c = abs(cos(ang)), s = abs(sin(ang)), e: Float = 2.4
            return 1 / pow(pow(c / h, e) + pow(s / w, e), 1 / e)
        }
        var capD = capS
        capD.deform(shape)
        m.add(capD)
        // Fat seam between the eye and the spinalis cap, flush with both faces.
        let seamPath: [V3] = stride(from: Float(0.55), through: 2.6, by: 0.06).map { a in
            let r = radius(a) * (0.62 + 0.06 * sin(a * 3 + ph[4]))
            return V3(r * cos(a), T * 0.5, -r * sin(a) + 0.006)
        }
        let seam = RecipeMesh.sweep(seamPath, edge: 0.004, endBulge: 0.5, material: fat) { t, ang in
            let taper = pow(sin(Float.pi * t), 0.5)
            let w: Float = 0.0016 * taper + 0.0003, h = T * 0.5 + 0.0003
            let c = abs(cos(ang)), s = abs(sin(ang)), e: Float = 4
            return 1 / pow(pow(c / h, e) + pow(s / w, e), 1 / e)
        }
        var seamD = seam
        seamD.deform(shape)
        m.add(seamD)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.01, floor: 0.7)
        return LODModel(m)
    }
}
