import simd
import Foundation

/// Insect wing and elytron outlines in a normalized wing frame: u runs from the wing root (0) to the
/// tip (1), v from the trailing/posterior edge (0) to the leading/costal edge (1). Geometry in
/// RealLibrary triangulates these outlines; the `insectWing` and `insectVeins` texture programs read
/// the same points (interpolated into the Metal source) to draw margins, bands and marginal veins, so
/// patterns line up with the cut edge.
public enum InsectWings {
    /// Outline index used as the `y` knob of `insectWing` / `insectVeins` materials.
    public enum Shape: Int, CaseIterable, Sendable {
        case monarchFore = 0, monarchHind, swallowtailFore, swallowtailHind, morphoFore, morphoHind,
             lunaFore, lunaHind, dragonflyFore, dragonflyHind, damselfly, beeFore, beeHind,
             cicadaFore, cicadaHind, membraneHind, tegmen, katydidTegmen
    }

    /// Points per resampled outline (Metal arrays use the same count).
    public static let count = 48

    static func controls(_ s: Shape) -> [V2] {
        func p(_ a: [(Float, Float)]) -> [V2] { a.map { V2($0.0, $0.1) } }
        switch s {
        case .monarchFore:
            return p([(0.00, 0.54), (0.05, 0.76), (0.30, 0.92), (0.62, 1.00), (0.87, 0.99), (0.99, 0.91), (0.97, 0.72),
                      (0.88, 0.50), (0.74, 0.28), (0.52, 0.17), (0.27, 0.20), (0.07, 0.36)])
        case .monarchHind:
            return p([(0.00, 0.64), (0.10, 0.87), (0.35, 0.98), (0.62, 0.96), (0.84, 0.84), (0.96, 0.62), (0.94, 0.40),
                      (0.80, 0.20), (0.56, 0.04), (0.30, 0.02), (0.11, 0.18), (0.02, 0.40)])
        case .swallowtailFore:
            return p([(0.00, 0.56), (0.05, 0.78), (0.35, 0.94), (0.70, 1.00), (0.93, 0.99), (1.00, 0.90), (0.93, 0.64),
                      (0.80, 0.40), (0.62, 0.22), (0.38, 0.15), (0.15, 0.24), (0.03, 0.40)])
        case .swallowtailHind:
            return p([(0.00, 0.72), (0.10, 0.91), (0.38, 1.00), (0.62, 0.95), (0.80, 0.80), (0.89, 0.61), (0.85, 0.44),
                      (0.75, 0.33), (0.68, 0.17), (0.64, 0.01), (0.58, 0.00), (0.57, 0.18), (0.46, 0.25), (0.28, 0.27),
                      (0.12, 0.36), (0.02, 0.52)])
        case .morphoFore:
            return p([(0.00, 0.52), (0.05, 0.76), (0.30, 0.93), (0.62, 1.00), (0.88, 0.98), (1.00, 0.86), (0.96, 0.62),
                      (0.86, 0.40), (0.70, 0.22), (0.48, 0.13), (0.24, 0.18), (0.06, 0.34)])
        case .morphoHind:
            return p([(0.00, 0.66), (0.10, 0.89), (0.36, 0.99), (0.64, 0.97), (0.86, 0.84), (0.98, 0.62), (0.95, 0.38),
                      (0.82, 0.18), (0.58, 0.03), (0.32, 0.02), (0.12, 0.17), (0.02, 0.40)])
        case .lunaFore:
            return p([(0.00, 0.56), (0.05, 0.80), (0.35, 0.95), (0.70, 1.00), (0.91, 0.98), (1.00, 0.88), (0.92, 0.62),
                      (0.74, 0.40), (0.50, 0.27), (0.25, 0.26), (0.06, 0.38)])
        case .lunaHind:
            return p([(0.00, 0.78), (0.13, 0.93), (0.40, 0.99), (0.60, 0.88), (0.68, 0.68), (0.66, 0.48), (0.61, 0.32),
                      (0.60, 0.14), (0.63, 0.01), (0.56, 0.00), (0.50, 0.12), (0.42, 0.30), (0.30, 0.44), (0.14, 0.51),
                      (0.03, 0.62)])
        case .dragonflyFore:
            return p([(0.00, 0.44), (0.02, 0.70), (0.20, 0.84), (0.60, 0.92), (0.90, 0.88), (1.00, 0.64), (0.93, 0.36),
                      (0.60, 0.20), (0.25, 0.17), (0.06, 0.24)])
        case .dragonflyHind:
            return p([(0.00, 0.28), (0.02, 0.76), (0.20, 0.88), (0.60, 0.92), (0.90, 0.86), (1.00, 0.62), (0.91, 0.36),
                      (0.56, 0.18), (0.26, 0.06), (0.08, 0.04)])
        case .damselfly:
            return p([(0.00, 0.46), (0.00, 0.56), (0.18, 0.58), (0.30, 0.76), (0.60, 0.90), (0.90, 0.86), (1.00, 0.62),
                      (0.90, 0.34), (0.60, 0.22), (0.32, 0.30), (0.18, 0.44)])
        case .beeFore:
            return p([(0.00, 0.50), (0.05, 0.76), (0.40, 0.92), (0.75, 0.96), (0.95, 0.86), (1.00, 0.62), (0.86, 0.36),
                      (0.50, 0.20), (0.20, 0.24), (0.04, 0.35)])
        case .beeHind:
            return p([(0.00, 0.52), (0.08, 0.80), (0.45, 0.92), (0.80, 0.88), (1.00, 0.66), (0.92, 0.38), (0.60, 0.18),
                      (0.25, 0.16), (0.05, 0.32)])
        case .cicadaFore:
            return p([(0.00, 0.50), (0.05, 0.80), (0.40, 0.95), (0.75, 0.98), (0.95, 0.86), (1.00, 0.60), (0.90, 0.38),
                      (0.60, 0.20), (0.25, 0.20), (0.05, 0.32)])
        case .cicadaHind:
            return p([(0.00, 0.50), (0.08, 0.84), (0.42, 0.96), (0.78, 0.90), (1.00, 0.66), (0.90, 0.36), (0.55, 0.14),
                      (0.22, 0.12), (0.04, 0.30)])
        case .membraneHind:
            return p([(0.00, 0.50), (0.05, 0.82), (0.45, 0.96), (0.80, 0.96), (1.00, 0.76), (0.95, 0.44), (0.62, 0.18),
                      (0.26, 0.10), (0.05, 0.28)])
        case .tegmen:
            return p([(0.00, 0.36), (0.03, 0.72), (0.40, 0.88), (0.80, 0.88), (1.00, 0.68), (0.96, 0.40), (0.62, 0.22),
                      (0.22, 0.18)])
        case .katydidTegmen:
            return p([(0.00, 0.40), (0.05, 0.76), (0.35, 0.96), (0.70, 0.99), (0.95, 0.82), (1.00, 0.56), (0.90, 0.30),
                      (0.55, 0.12), (0.20, 0.14), (0.03, 0.27)])
        }
    }

    /// Closed outline resampled to `count` points evenly spaced by arc length (counter-clockwise).
    public static func outline(_ s: Shape) -> [V2] {
        let c = controls(s), n = c.count
        var dense: [V2] = []
        for i in 0..<n {
            let p0 = c[(i + n - 1) % n], p1 = c[i], p2 = c[(i + 1) % n], p3 = c[(i + 2) % n]
            for k in 0..<12 {
                let t = Float(k) / 12, t2 = t * t, t3 = t2 * t
                let a = 2 * p1, b = p2 - p0, cc = 2 * p0 - 5 * p1 + 4 * p2 - p3, d = -p0 + 3 * p1 - 3 * p2 + p3
                var q = 0.5 * (a + b * t + cc * t2 + d * t3)
                q = simd_clamp(q, V2(0, 0), V2(1, 1))
                dense.append(q)
            }
        }
        var lens: [Float] = [0]
        for i in 1...dense.count { lens.append(lens[i - 1] + simd_distance(dense[i - 1], dense[i % dense.count])) }
        let total = lens.last!
        var out: [V2] = []
        var j = 0
        for k in 0..<count {
            let target = Float(k) / Float(count) * total
            while j < dense.count - 1 && lens[j + 1] < target { j += 1 }
            let t = (target - lens[j]) / max(1e-6, lens[j + 1] - lens[j])
            out.append(simd_mix(dense[j], dense[(j + 1) % dense.count], V2(repeating: t)))
        }
        var area: Float = 0
        for i in 0..<out.count { let a = out[i], b = out[(i + 1) % out.count]; area += a.x * b.y - b.x * a.y }
        return area >= 0 ? out : out.reversed()
    }

    /// Metal declarations: `WING_PTS` (every outline, `count` points each) and `WING_N`.
    public static var metalSource: String {
        let pts = Shape.allCases.flatMap { outline($0) }
        let body = pts.map { String(format: "float2(%.4f, %.4f)", $0.x, $0.y) }.joined(separator: ", ")
        return "constant int WING_N = \(count);\nconstant float2 WING_PTS[\(pts.count)] = { \(body) };\n"
    }
}
