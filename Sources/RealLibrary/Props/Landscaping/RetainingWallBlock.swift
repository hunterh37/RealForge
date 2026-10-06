import simd
import Foundation

/// Segmental retaining wall, 1.2 m segment of 3 courses by default: 40 x 15 x 30 cm split-face concrete
/// blocks in running bond, each course set back 2 cm (batter), finished with 7.5 cm cap stones on
/// adhesive. Split faces are displaced rock-like; half blocks close the ends of alternate courses.
public struct RetainingWallBlock: RealAsset {
    public static let id = "retaining-wall-block"
    public static let summary = "Segmental retaining wall segment, 1.2 m x 3 courses: split-face concrete blocks in running bond with setback and cap stones."
    public static let tags = ["prop", "garden", "outdoor", "landscaping", "stone", "concrete", "wall"]
    public static let budget = 14_500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 14, distance: 1.05, studio: true)

    /// Segment length along X (m).
    public var length: Float = 1.2
    /// Number of block courses under the cap.
    public var courses: Int = 3
    /// Block face length, height and depth (m).
    public var blockSize = V3(0.4, 0.15, 0.3)
    /// Setback per course toward -Z (m).
    public var setback: Float = 0.02
    /// Cap stone thickness (m).
    public var capHeight: Float = 0.075
    /// Block material (split face).
    public var block: MaterialKey = "stone.wall-block"
    /// Cap stone material.
    public var cap: MaterialKey = "stone.cap"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var full = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        let bl = blockSize.x, bh = blockSize.y, bd = blockSize.z, gap: Float = 0.004
        let n = max(1, min(courses, 6))
        let detail = n * Int(ceil(length / bl)) <= 12 ? 8 : 5
        func blockSurface(_ len: Float, split: Bool, _ r: inout SeededRNG, sub: Int) -> Surface {
            var s = Prim.superellipsoid(V3(len, bh, bd), exponent: 14, subdivisions: sub, material: block)
            let sd = UInt32(truncatingIfNeeded: r.int(0...100_000))
            if split {
                s.displace { p, nrm in
                    guard nrm.z > 0.5 else { return 0 }
                    let edge = min(len / 2 - abs(p.x), bh / 2 - abs(p.y))
                    let f = Noise.fbm(p * 18, octaves: 4, seed: sd) * 0.012 + Noise.ridged(p * 7, octaves: 3, seed: sd + 1) * 0.008
                    return f * min(1, max(0, edge) / 0.015)
                }
                // Split face bulges a few mm proud and slopes back at the top lip.
                s.deform { p in p.z > 0 ? p + V3(0, 0, 0.006 * (1 - abs(p.x) / (len / 2))) : p }
            }
            return s
        }
        for c in 0..<n {
            let y = Float(c) * bh + bh / 2
            let z = -Float(c) * setback
            let stagger = c % 2 == 1
            var x = -length / 2
            var pieces: [Float] = []
            if stagger { pieces.append(bl / 2) }
            var rem = length - (pieces.first ?? 0)
            while rem > 0.05 { let l = min(bl, rem); pieces.append(l); rem -= l }
            for (i, l) in pieces.enumerated() {
                var r = rng.fork(c * 31 + i)
                let s = blockSurface(l - gap, split: true, &r, sub: detail)
                let xf = Xform(translation: V3(x + l / 2, y + r.float(-0.001...0.001), z + r.float(-0.003...0.003)),
                               rotation: simd_quatf(degrees: r.float(-0.6...0.6), axis: .up))
                full.add(s, xf)
                lite.add(Prim.roundedBox(V3(l - gap, bh, bd), radius: 0.006, bevelSegments: 1, material: block), xf)
                x += l
            }
        }
        // Cap stones: slight overhang on the face, bull-nosed front edge.
        let capY = Float(n) * bh
        let capD = bd + 0.03, capZ = -Float(n - 1) * setback + 0.015
        var x = -length / 2
        var i = 0
        while x < length / 2 - 0.05 {
            let l = min(0.45, length / 2 - x)
            var r = rng.fork(900 + i)
            let s = Prim.superellipsoid(V3(l - gap, capHeight, capD), exponent: 8, subdivisions: 5, material: cap)
            let xf = Xform(translation: V3(x + l / 2, capY + capHeight / 2 + 0.002, capZ), rotation: simd_quatf(degrees: r.float(-0.5...0.5), axis: .up))
            full.add(s, xf)
            lite.add(Prim.roundedBox(V3(l - gap, capHeight, capD), radius: 0.01, bevelSegments: 1, material: cap), xf)
            x += l; i += 1
        }
        let bb = full.bounds
        let shift = V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)
        full = full.transformed(Xform(translation: shift)); lite = lite.transformed(Xform(translation: shift))
        groundAO(&full, height: 0.2, floor: 0.55); groundAO(&lite, height: 0.2, floor: 0.55)
        return LODModel(levels: [full, lite], switchDistances: [8])
    }
}
