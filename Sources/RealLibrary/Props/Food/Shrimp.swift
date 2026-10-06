import simd
import Foundation

/// Raw peeled large shrimp (16/20 count) lying on its side, curled into a C, tail fan on. The body
/// is one swept shell along a 240 degree arc: laterally compressed oval section, thick cut head end
/// tapering to the tail, six segment ridges and a shallow deveined groove along the back (outer
/// curve). The tail is a fan of five thin translucent paddles (telson and uropods).
public struct Shrimp: RealFood {
    public static let id = "shrimp"
    public static let summary = "Raw peeled shrimp, 8 cm curled C: translucent grey-pink segmented body, deveined back, tail fan on."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.protein
    public static let preview = PreviewHint(azimuth: 20, elevation: 45, distance: 0.2, studio: true)

    /// Centerline curl radius (m).
    public var curl: Float = 0.0165
    /// Arc swept by the body (radians).
    public var arc: Float = 4.0
    /// Max body radius at the head end (m).
    public var bodyRadius: Float = 0.0094
    /// Material keys.
    public var body: MaterialKey = "food.shrimp-raw"
    public var flesh: MaterialKey = "food.shrimp-flesh"
    public var tail: MaterialKey = "food.shrimp-tail"
    public init() {}

    public var coreCenter: V3 { V3(0, bodyRadius * 0.7, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == body ? flesh : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let Rc = curl, R = bodyRadius
        let arcV = arc * rng.float(0.94...1.04)
        let yC = R * 0.72
        // Spiral slightly inward toward the tail.
        let n = 48
        let path: [V3] = (0...n).map { i in
            let t = Float(i) / Float(n), th = t * arcV
            let r = Rc * (1 - 0.18 * t)
            return V3(r * cos(th), yC - 0.0012 * t, -r * sin(th))
        }
        var L: Float = 0
        for i in 1...n { L += simd_distance(path[i], path[i - 1]) }
        let segs: Float = 6
        let bodyS = RecipeMesh.sweep(path, edge: 0.0018, endBulge: 0.35, seamTile: 0.06, material: body) { t, ang in
            let taper = 1 - 0.5 * pow(t, 1.5)
            let head = smoothstep(0, 0.06, t) * 0.25 + 0.75
            let r = R * taper * head
            // Segment ridges: each segment swells toward its leading edge.
            let sv = t * segs + 0.15, sp = sv - floor(sv)
            let ridge = 1 + 0.09 * (smoothstep(0.0, 0.08, sp) * (1 - smoothstep(0.08, 1.0, sp))) * smoothstep(0.03, 0.12, t) - 0.03 * smoothstep(0.85, 1.0, sp)
            let h = r * 0.76, w = r
            let c = cos(ang), s = sin(ang)
            var rr = ridge / sqrt(c * c / (h * h) + s * s / (w * w))
            // Deveined groove along the back (outer side, ang = pi/2) and a fuller dorsal edge.
            let d = ang - .pi / 2
            rr *= 1 + 0.06 * exp(-d * d / 0.5)
            rr -= 0.0007 * taper * exp(-d * d / 0.02)
            // Flatter belly with swimmeret scars.
            let v = ang - 3 * .pi / 2
            rr *= 1 - 0.07 * exp(-v * v / 0.3)
            return rr
        }
        var m = Model(name: Self.id)
        m.add(bodyS)
        // Tail fan at the path end, lying flat in the XZ plane.
        let pe = path[n], tanE = simd_normalize(path[n] - path[n - 2])
        let up = V3(0, 1, 0)
        let side = simd_normalize(simd_cross(tanE, up))
        var fan = Surface(material: tail)
        let fins: [(Float, Float, Float)] = [(-0.5, 0.015, 0.0052), (-0.24, 0.0165, 0.0058), (0, 0.018, 0.0045), (0.24, 0.0165, 0.0058), (0.5, 0.015, 0.0052)]
        for (k, f) in fins.enumerated() {
            var r = rng.fork(k)
            let ang = f.0 + r.float(-0.06...0.06), len = f.1 * r.float(0.95...1.05), wd = f.2
            var blade = RecipeMesh.blade(length: len, thickness: 0.00045, edge: 0.0016, uCenter: 0.015, material: tail) { t in
                wd * pow(sin(.pi * min(1, 0.1 + t * 0.86)), 0.45) * (0.5 + 0.5 * t)
            }
            let dir = simd_normalize(tanE * cos(ang) + side * sin(ang))
            let lat = simd_normalize(simd_cross(up, dir))
            let base = pe - tanE * 0.004 + V3(0, -0.0008 + 0.0002 * Float(k % 2), 0)
            blade.deform { q in
                let t = q.y / len
                return base + dir * q.y + lat * q.x + up * (q.z + 0.0012 * t * t - 0.0002 * Float(k % 2))
            }
            fan.append(RecipeMesh.outward(blade))
        }
        m.add(fan)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.006, floor: 0.7)
        _ = L
        return LODModel(m)
    }
}
