import simd
import Foundation

/// Post-and-rail fence section, 3.0 m: one split chestnut-style post 1.35 m tall at the -X end and three split
/// rails (about 0.13 m wedges) tenoned through it, crooked and weathered. Tile along X every `length`; the
/// last section takes `endPost = true`.
public struct RailFence: RealAsset {
    public static let id = "rail-fence"
    public static let summary = "Split-rail fence section, 3 m: hewn post, three crooked wedge rails, weathered wood; tiles along X."
    public static let tags = ["structure", "farm", "fence", "wood"]
    public static let budget = 6_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 25, elevation: 12)

    public var length: Float = 3.0
    public var postHeight: Float = 1.35
    public var railHeights: [Float] = [0.38, 0.72, 1.06]
    /// Add the closing post at +X (for the last section of a run).
    public var endPost = false
    public var material: MaterialKey = "wood.weathered"
    public init() {}

    /// Split wedge cross-section (z, y), counter-clockwise, about `size` across.
    static func wedge(_ rng: inout SeededRNG, size: Float) -> [V2] {
        var pts: [V2] = []
        let a0 = rng.float(-0.3...0.3)
        // Rounded bark face (arc) plus two split faces meeting at an apex.
        for k in 0...5 { let a = a0 - 0.75 + Float(k) / 5 * 1.5; pts.append(V2(cos(a), sin(a)) * size * rng.float(0.93...1.0) + V2(-size * 0.35, 0)) }
        pts.append(V2(-size * 0.35, 0) + V2(cos(a0 + 2.6), sin(a0 + 2.6)) * size * 0.25)
        pts.append(V2(-size * 0.35, 0) + V2(cos(a0 - 2.6), sin(a0 - 2.6)) * size * 0.25)
        let c = pts.reduce(V2.zero, +) / Float(pts.count)
        return CFKit.bevel(pts.map { $0 - c }, 0.008)
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length / 2
        let posts: [Float] = endPost ? [-L, L] : [-L]
        for px in posts {
            var r = rng.fork(Int(px * 10) + 7)
            let prof = Self.wedge(&r, size: 0.13)
            let ys = stride(from: Float(0), through: postHeight, by: 0.1).map { $0 }
            let ns = UInt32(truncatingIfNeeded: seed &+ 11)
            var post = CFKit.extrude(prof, xs: ys, material: material) { _, x, i, p in
                let top: Float = x > postHeight - 0.08 ? 0.85 : 1   // weathered, rounded top
                return p * top + V2(Noise.perlin(V3(x * 1.5, Float(i), 0), seed: ns) * 0.01, 0)
            }
            post.bakeCavityAO(strength: 0.5, floor: 0.7)
            // Extruded along X; stand it up (X -> Y).
            m.add(post, Xform(translation: V3(px, 0, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1)) * simd_quatf(degrees: r.float(0...360), axis: V3(1, 0, 0))).jittered(&r, deg: 1.5, offset: 0))
        }
        for (k, hy) in railHeights.enumerated() {
            var r = rng.fork(100 + k)
            let prof = Self.wedge(&r, size: r.float(0.11...0.14))
            let x0 = -L - 0.12, x1 = L + 0.12
            let xs = stride(from: x0, through: x1, by: 0.12).map { $0 } + [x1]
            let crook = r.float(-0.04...0.04), crook2 = r.float(-0.03...0.03), twist = r.float(0...360)
            let ns = UInt32(truncatingIfNeeded: seed &+ UInt64(k))
            var rail = CFKit.extrude(prof, xs: xs, material: material) { _, x, i, p in
                let t = (x - x0) / (x1 - x0)
                // Tenons: ends taper to fit the post mortise.
                let taper = 1 - 0.45 * (1 - smoothstep(0.0, 0.05, t)) - 0.45 * smoothstep(0.95, 1.0, t)
                let q = p * taper + V2(Noise.perlin(V3(x * 2.0, Float(i) * 0.7, 3), seed: ns) * 0.006, 0)
                return q + V2(crook * sin(.pi * t) + crook2 * sin(2 * .pi * t), -0.02 * sin(.pi * t))
            }
            rail.bakeCavityAO(strength: 0.5, floor: 0.7)
            let roll = simd_quatf(degrees: twist, axis: V3(1, 0, 0))
            m.add(rail, Xform(translation: V3(0, hy, 0), rotation: roll).jittered(&r, deg: 0.6, offset: 0.004))
        }
        groundAO(&m, height: 0.3, floor: 0.6)
        return LODModel(m)
    }
}
