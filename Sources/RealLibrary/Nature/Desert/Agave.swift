import simd
import Foundation

/// Century plant (Agave americana), ~1.3 m tall and 2.2 m across: rosette of 22-32 thick channeled leaves
/// up to 1.1 m long and 24 cm wide, inner leaves upright, outer leaves arching over; toothed margins,
/// dark terminal spines, blue-grey wax with bud imprints.
public struct Agave: RealAsset {
    public static let id = "agave"
    public static let summary = "Agave americana, ~1.3 m: rosette of 22-32 thick channeled blue-grey leaves with toothed margins and terminal spines, 3 LODs."
    public static let tags = ["nature", "desert"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 22, distance: 1.1)

    /// Longest (outer) leaf length, meters.
    public var leafLength: Float = 1.1
    /// Widest leaf width, meters.
    public var leafWidth: Float = 0.24
    public var leafCount: ClosedRange<Int> = 22...32
    public var material: MaterialKey = "leaf.agave"
    public var lodDistances: [Float] = [8, 22]
    public init() {}

    private struct Leaf { var spine: [V3]; var side: V3; var width: Float; var thick: Float; var curl: Float; var length: Float }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let n = rng.int(leafCount)
        let L = rng.vary(leafLength, 0.1)
        var leaves: [Leaf] = []
        var az = rng.float(0...(2 * .pi))
        for i in 0..<n {
            // i = 0 is the oldest, outermost leaf.
            let age = 1 - Float(i) / Float(max(1, n - 1))
            az += radians(137.5) + rng.float(-0.1...0.1)
            let a = V3(cos(az), 0, sin(az))
            let len = L * (0.45 + 0.55 * pow(age, 0.6)) * rng.vary(1, 0.08)
            let elev = radians(82 - 62 * pow(age, 0.8) + rng.float(-6...6))
            let droop = (0.15 + 1.4 * age * age) * rng.vary(1, 0.25)       // outer leaves arch over
            var d = simd_normalize(a * cos(elev) + V3(0, sin(elev), 0))
            var p = V3(0, 0.02 + 0.12 * (1 - age), 0) + a * (0.03 + 0.06 * age)
            let m = 16, ds = len / Float(m)
            var pts = [p]
            for k in 1...m {
                let t = Float(k) / Float(m)
                d = simd_normalize(d + V3(0, -droop * ds * t, 0))
                p += d * ds
                p.y = max(p.y, 0.015)
                pts.append(p)
            }
            leaves.append(Leaf(spine: pts, side: simd_normalize(simd_cross(V3.up, a)), width: leafWidth * (0.6 + 0.4 * age) * rng.vary(1, 0.1),
                               thick: 0.05 * (0.7 + 0.3 * age), curl: rng.float(0.1...0.22), length: len))
        }

        func level(_ lod: Int) -> Model {
            let stride = [1, 2, 4][lod], across = [5, 3, 2][lod]   // top-surface samples across (bottom gets across - 2)
            var body = Surface(material: material)
            var dark = Surface(material: "leaf.agave-spine")
            var trng = SeededRNG(seed: seed &+ 0x7EE7)
            for lf in leaves {
                let last = lf.spine.count - 1
                let idx = Array(Swift.stride(from: 0, through: last, by: stride)) + (last % stride == 0 ? [] : [last])
                var s = Surface(material: material)
                var arc: Float = 0
                var prev = lf.spine[0]
                for (r, i) in idx.enumerated() {
                    let c = lf.spine[i]
                    arc += simd_distance(c, prev); prev = c
                    let t = Float(i) / Float(last)
                    let tan = simd_normalize(lf.spine[min(last, i + 1)] - lf.spine[max(0, i - 1)])
                    let side = simd_normalize(lf.side - tan * simd_dot(lf.side, tan))
                    let up = simd_cross(side, tan)
                    // Lanceolate outline: widest ~25 percent along, tapering to the spine.
                    let w = lf.width * 0.5 * (0.72 + 0.28 * smoothstep(0, 0.35, t)) * pow(max(0, 1 - t), 0.6) + 0.002
                    let th = lf.thick * (1 - 0.85 * t) * 0.5 + 0.002
                    let channel = lf.curl * w
                    var section: [(Float, Float)] = []    // (x across, y up) around the ring
                    if lod == 2 {
                        section = [(-w, channel), (0, th), (w, channel), (0, -th)]
                    } else {
                        for j in 0..<across {
                            let x = (Float(j) / Float(across - 1)) * 2 - 1
                            section.append((x * w, channel * x * x + th * (1 - 0.85 * x * x)))
                        }
                        for j in Swift.stride(from: across - 2, through: 1, by: -1) {
                            let x = (Float(j) / Float(across - 1)) * 2 - 1
                            section.append((x * w, channel * x * x - th * (1 - 0.85 * x * x) * 1.3))
                        }
                    }
                    for (x, y) in section {
                        s.add(c + side * x + up * y, up, V2(x, arc), extra: V2(0.4 * t, 0))
                    }
                    if r > 0 {
                        let a0 = UInt32((r - 1) * section.count), a1 = UInt32(r * section.count)
                        let cnt = UInt32(section.count)
                        for j in 0..<cnt { s.quad(a0 + j, a0 + (j + 1) % cnt, a1 + (j + 1) % cnt, a1 + j) }
                    }
                }
                s.recomputeNormals(weldSeams: false)
                // Rosette interior and undersides in shade; base in contact with the ground.
                s.occlusion = s.positions.map { p in
                    let rr = simd_length(V2(p.x, p.z))
                    return saturate(0.45 + 0.55 * smoothstep(0.02, 0.5, rr + p.y * 0.4)) * (0.6 + 0.4 * smoothstep(0, 0.15, p.y))
                }
                body.append(s)
                // Terminal spine.
                let tip = lf.spine[last], tdir = simd_normalize(lf.spine[last] - lf.spine[last - 1])
                let sl = 0.035 * (lf.length / L + 0.3)
                var ts = Prim.tube([tip - tdir * 0.01, tip + tdir * sl * 0.6, tip + tdir * sl], radii: [0.0045, 0.0028, 0.0005],
                                   sides: lod == 0 ? 5 : 3, seamTile: 0.05, material: "leaf.agave-spine", capEnd: false)
                ts.occlusion = ts.positions.map { _ in 0.9 }
                dark.append(ts)
                // Marginal teeth, every ~4 cm, curved toward the tip.
                if lod == 0 {
                    var sd: Float = 0.08
                    while sd < lf.length - 0.06 {
                        let f = sd / lf.length * Float(last)
                        let i = min(Int(f), last - 1)
                        let c = lerp(lf.spine[i], lf.spine[i + 1], f - Float(i))
                        let t = sd / lf.length
                        let tan = simd_normalize(lf.spine[i + 1] - lf.spine[i])
                        let side = simd_normalize(lf.side - tan * simd_dot(lf.side, tan))
                        let up = simd_cross(side, tan)
                        let w = lf.width * 0.5 * (0.72 + 0.28 * smoothstep(0, 0.35, t)) * pow(max(0, 1 - t), 0.6) + 0.002
                        for sgn: Float in [-1, 1] {
                            let base = c + side * (sgn * w * 0.99) + up * (lf.curl * w)
                            let ts2 = trng.float(0.006...0.011)
                            let tipP = base + side * (sgn * ts2) + tan * ts2 * 0.6
                            let b0 = base - tan * ts2 * 0.5, b1 = base + tan * ts2 * 0.5
                            let top = base + up * 0.003, bot = base - up * 0.003
                            let q0 = dark.add(b0, -tan, .zero), q1 = dark.add(b1, tan, .zero)
                            let q2 = dark.add(top, up, .zero), q3 = dark.add(bot, -up, .zero), q4 = dark.add(tipP, side * sgn, .zero)
                            for k in [q0, q1, q2, q3, q4] { dark.occlusion[Int(k)] = 0.85 }
                            let mid = (b0 + b1 + top + bot + tipP) / 5
                            for (x, y, z) in [(q0, q2, q4), (q2, q1, q4), (q1, q3, q4), (q3, q0, q4)] {
                                let px = dark.positions[Int(x)], py = dark.positions[Int(y)], pz = dark.positions[Int(z)]
                                let nrm = simd_cross(py - px, pz - px)
                                if simd_dot(nrm, (px + py + pz) / 3 - mid) >= 0 { dark.tri(x, y, z) } else { dark.tri(x, z, y) }
                            }
                        }
                        sd += trng.float(0.035...0.05)
                    }
                }
            }
            body.computeTangents()
            dark.recomputeNormals(weldSeams: false)
            dark.computeTangents()
            var m = Model(name: Self.id)
            m.add(body)
            m.add(dark)
            return m
        }
        return LODModel(levels: [level(0), level(1), level(2)], switchDistances: lodDistances)
    }
}
