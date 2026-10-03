import simd
import Foundation

/// Two-person dome tent, 2.2 x 1.6 m footprint, 1.1 m high: two crossed poles under a ripstop fly that
/// sags between them, scalloped hem staked at the corners, inner tent and bathtub floor visible under
/// the hem, D-door zip, guy lines and steel pegs. 2 LODs.
public struct DomeTent: RealAsset {
    public static let id = "dome-tent"
    public static let summary = "Two-person dome tent, 2.2 x 1.6 m: crossed poles, sagging ripstop fly, inner tent, D-door zip, guy lines and pegs."
    public static let tags = ["prop", "camp", "fabric"]
    public static let budget = 9_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18, distance: 0.85)

    /// Fly footprint half extents (x, z) and peak height, meters.
    public var size = V3(2.2, 1.1, 1.6)
    /// Fly color (sRGB hex) on `fabric.nylon`.
    public var flyColor: UInt32 = 0x4A6538
    /// Inner tent color.
    public var innerColor: UInt32 = 0xC9C1A4
    /// Hem lift at the middle of each side, meters.
    public var hemLift: Float = 0.12
    /// Fabric sag between the poles, meters.
    public var sag: Float = 0.06
    public var guyLines = true
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let ns = UInt32(truncatingIfNeeded: seed)
        let a = rng.vary(size.x / 2, 0.03), b = rng.vary(size.z / 2, 0.03), H = rng.vary(size.y, 0.04)
        let fly = "fabric.nylon:" + String(format: "%06X", flyColor)
        let innerKey = "fabric.nylon:" + String(format: "%06X", innerColor)
        let floorKey = "fabric.nylon:2F3337"
        let diag = atan2(b, a)
        let poleAngles: [Float] = [diag, .pi - diag, .pi + diag, 2 * .pi - diag]
        // Rectangle boundary distance along direction t.
        func edge(_ t: Float) -> Float { min(a / max(abs(cos(t)), 1e-4), b / max(abs(sin(t)), 1e-4)) }
        // 0 on a pole line, 1 midway between poles.
        func between(_ t: Float) -> Float {
            let d = poleAngles.map { abs(remainder(t - $0, 2 * .pi)) }.min()!
            let span: Float = abs(remainder(t, .pi)) < .pi / 2 - diag || abs(remainder(t, .pi)) > .pi / 2 + diag ? diag : .pi / 2 - diag
            return sin(min(d / max(span, 0.01), 1) * .pi / 2)
        }
        func dome(_ s: Float, scale: Float = 1) -> Float { H * scale * pow(max(0, 1 - s * s), 0.55) }
        func hem(_ t: Float) -> Float { 0.015 + hemLift * between(t) }
        func flyPoint(_ t: Float, _ s0: Float) -> V3 {
            let sh = (1 - pow(min(hem(t) / H, 0.99), 1 / 0.55)).squareRoot()
            let s = s0 * sh
            let r = s * edge(t)
            var h = dome(s)
            let w = between(t)
            h -= sag * w * sin(.pi * s0) * 0.9
            // Tension wrinkles fanning toward the stake points.
            h += 0.011 * sin(t * 30 + Noise.perlin(V3(cos(t) * 3, s0 * 2, sin(t) * 3), seed: ns) * 4) * w * sin(.pi * s0)
            var p = V3(r * cos(t), h, -r * sin(t))
            // Walls bow inward a little between poles.
            p.x *= 1 - 0.04 * w * sin(.pi * s0); p.z *= 1 - 0.04 * w * sin(.pi * s0)
            return p
        }
        func lod(_ na: Int, _ nr: Int, detail: Bool) -> Model {
            var m = Model(name: Self.id)
            // Fly: polar grid, apex to hem.
            var rows: [[V3]] = [], uvs: [[V2]] = []
            var vAcc = [Float](repeating: 0, count: na + 1)
            for j in 0...nr {
                let s0 = Float(j) / Float(nr)
                var row: [V3] = [], uv: [V2] = []
                for k in 0...na {
                    let t = Float(k % na) / Float(na) * 2 * .pi
                    let p = flyPoint(t, max(s0, 0.001))
                    if j > 0 { vAcc[k] += simd_distance(p, rows[j - 1][k]) }
                    row.append(p); uv.append(V2(Float(k) / Float(na) * 2 * .pi * s0 * (a + b) / 2, vAcc[k]))
                }
                rows.append(row); uvs.append(uv)
            }
            var outer = WoodParts.grid(rows, uvs: uvs, material: fly)
            WoodParts.orientOutward(&outer) { _ in V3(0, H * 0.25, 0) }
            outer.recomputeNormals()
            outer.occlusion = outer.positions.map { 0.75 + 0.25 * smoothstep(0, H * 0.6, $0.y) }
            var under = outer
            for t in stride(from: 0, to: under.indices.count, by: 3) { under.indices.swapAt(t + 1, t + 2) }
            for i in under.positions.indices { under.positions[i] -= outer.normals[i] * 0.003 }
            under.normals = outer.normals.map { -$0 }
            under.occlusion = under.positions.map { _ in 0.55 }
            outer.computeTangents(); under.computeTangents()
            m.add(outer); m.add(under)
            // Inner tent: smaller dome down to the floor, seen under the hem.
            let ia = na / 2, ir = max(4, nr / 2)
            var irows: [[V3]] = [], iuvs: [[V2]] = []
            for j in 0...ir {
                let s = Float(j) / Float(ir) * 0.995
                var row: [V3] = [], uv: [V2] = []
                for k in 0...ia {
                    let t = Float(k % ia) / Float(ia) * 2 * .pi
                    let r = s * edge(t) * 0.9
                    row.append(V3(r * cos(t), dome(s, scale: 0.92) + 0.02, -r * sin(t))); uv.append(V2(t * (a + b) / 2, s * H))
                }
                irows.append(row); iuvs.append(uv)
            }
            var inner = WoodParts.grid(irows, uvs: iuvs, material: innerKey)
            WoodParts.orientOutward(&inner) { _ in V3(0, H * 0.2, 0) }
            inner.recomputeNormals(); inner.computeTangents()
            inner.occlusion = inner.positions.map { 0.45 + 0.4 * smoothstep(0, 0.4, $0.y) }
            m.add(inner)
            // Bathtub floor.
            m.add(Prim.roundedBox(V3(a * 1.8, 0.04, b * 1.8), radius: 0.015, bevelSegments: 2, material: floorKey), Xform(translation: V3(0, 0.02, 0)))
            // Pole tips into the corner grommets.
            for t in poleAngles {
                let c = V3(cos(t), 0, -sin(t)) * edge(t)
                let up = flyPoint(t, 0.93)
                let tip = c * 1.01 + V3(0, 0.01, 0)
                m.add(Prim.tube([tip, tip + (up - tip) * 0.6], radii: [0.0055, 0.0055], sides: 6, seamTile: 0.1, material: "metal.steel"))
                // Corner peg through the webbing.
                let pg = c * 1.06
                m.add(Prim.tube([pg - V3(0, 0.05, 0), pg + V3(0, 0.035, 0), pg + V3(0, 0.04, 0) + simd_normalize(c) * 0.02],
                                radii: [0.003, 0.003, 0.003], sides: 5, seamTile: 0.1, material: "metal.steel"))
            }
            if detail {
                // D-door zip on the +Z wall.
                var zip: [V3] = []
                for i in 0...36 {
                    let u = Float(i) / 36 * 2 - 1
                    let t = Float.pi * 1.5 + 0.42 * u
                    let s0 = 1 - 0.55 * pow(max(0, 1 - u * u), 0.5) - 0.02
                    let p = flyPoint(t, s0), q = flyPoint(t, s0 + 0.01)
                    let n = simd_normalize(simd_cross(q - p, flyPoint(t + 0.01, s0) - p))
                    zip.append(p + (simd_dot(n, V3(p.x, 0, p.z)) < 0 ? -n : n) * 0.009)
                }
                m.add(Prim.tube(zip, radii: zip.map { _ in 0.005 }, sides: 5, seamTile: 0.1, material: "plastic.black", capEnd: false))
                // Guy lines from mid-panel loops to pegs.
                if guyLines {
                    for t in [Float(0), .pi / 2, .pi, 1.5 * .pi] {
                        let p = flyPoint(t, 0.62)
                        let d = simd_normalize(V3(p.x, 0, p.z))
                        let g = d * (edge(t) + 0.75) + V3(0, 0.02, 0)
                        m.add(Prim.tube([p, g], radii: [0.0018, 0.0018], sides: 4, seamTile: 0.1, material: "fabric.nylon:D9D4C4", capEnd: false))
                        m.add(Prim.tube([g - V3(0, 0.06, 0), g + V3(0, 0.03, 0), g + V3(0, 0.035, 0) - d * 0.02],
                                        radii: [0.003, 0.003, 0.003], sides: 5, seamTile: 0.1, material: "metal.steel"))
                    }
                }
            }
            for i in m.surfaces.indices where m.surfaces[i].tangents.count != m.surfaces[i].positions.count { m.surfaces[i].computeTangents() }
            return m
        }
        return LODModel(levels: [lod(80, 16, detail: true), lod(32, 7, detail: false)], switchDistances: [15])
    }
}
