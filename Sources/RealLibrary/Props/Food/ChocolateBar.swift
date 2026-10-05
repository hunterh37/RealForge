import simd
import Foundation

/// Dark chocolate tablet lying flat, long side along +X: a 6 x 3 grid of pieces separated by beveled
/// V grooves on the glossy face, a flat back and softly rounded outer edges. One closed body
/// (grid vertices land on the groove lines); cut face `food.chocolate`.
public struct ChocolateBar: RealFood {
    public static let id = "chocolate-bar"
    public static let summary = "Dark chocolate bar, 15.5 x 7.5 cm: scored 3 x 6 tablet with beveled V grooves, glossy face and flat back."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 5000
    public static let author = "realityhd"
    public static let kind = FoodKind.dairy
    public static let preview = PreviewHint(azimuth: 25, elevation: 40, distance: 0.32, studio: true)

    /// Bar size (m).
    public var size = V3(0.155, 0.009, 0.075)
    /// Pieces along X and Z.
    public var columns = 6
    public var rows = 3
    /// Groove depth and half width (m).
    public var grooveDepth: Float = 0.0035
    public var grooveHalf: Float = 0.0028
    /// Material key.
    public var chocolate: MaterialKey = "food.chocolate"
    public init() {}

    public var coreCenter: V3 { V3(0, size.y / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == chocolate ? chocolate : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let h = size / 2
        func lines(_ n: Int, _ half: Float) -> [Float] { (1..<n).map { -half + 2 * half * Float($0) / Float(n) } }
        let gx = lines(columns, h.x), gz = lines(rows, h.z)
        func extra(_ g: [Float]) -> [Float] { g.flatMap { [$0 - grooveHalf, $0, $0 + grooveHalf] } }
        var s = FoodMesh.box(size, radius: 0.0018, edge: 0.006, bevelSegments: 2, extra: [extra(gx), [], extra(gz)], material: chocolate)
        func groove(_ v: Float, _ g: [Float]) -> Float {
            g.map { max(0, 1 - abs(v - $0) / grooveHalf) }.max() ?? 0
        }
        // A small chip off one corner piece and slight piece-to-piece height variation.
        let chip = V3(h.x * (rng.chance(0.5) ? 1 : -1), h.y, h.z * (rng.chance(0.5) ? 1 : -1))
        let jitter = (0..<(columns * rows)).map { _ in rng.float(-0.00015...0.00015) }
        s.deform { p in
            var q = p
            let up = (p.y + h.y) / size.y          // 0 at the back, 1 at the face
            let g = max(groove(p.x, gx), groove(p.z, gz))
            let ci = min(columns - 1, max(0, Int((p.x + h.x) / size.x * Float(columns))))
            let ri = min(rows - 1, max(0, Int((p.z + h.z) / size.z * Float(rows))))
            q.y -= up * (self.grooveDepth * g - jitter[ri * columns + ci] * (1 - g))
            let d = simd_distance(V3(p.x, p.y, p.z), chip)
            if d < 0.006 { q.y -= up * 0.0025 * (1 - d / 0.006) * (1 - d / 0.006) }
            return q
        }
        var m = Model(name: Self.id)
        m.add(s)
        m = m.transformed(Xform(translation: V3(0, h.y, 0)))
        groundAO(&m, height: 0.004, floor: 0.7)
        return LODModel(m)
    }
}
