import simd
import Foundation

/// Limestone cliff section 6 m long and 6 m high (4 to 8 m works), 1.6 m deep: bedded strata with protruding
/// hard beds, undercut soft beds, jointed blocks and a rounded top lip. The face is +Z. Modular along X:
/// both ends share one profile, so with `endTaper = 0` sections repeat at `place(x + i * length, z)`. By default
/// the ends taper into the ground with rounded rock caps. 3 LODs.
public struct CliffFace: RealAsset {
    public static let id = "cliff-face"
    public static let summary = "Cliff section, 6 x 6 m: bedded strata ledges, undercuts, jointed blocks, rounded lip; tiles along X, 3 LODs."
    public static let tags = ["nature", "rock", "terrain"]
    public static let budget = 40_000
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 20, elevation: 10)

    public var length: Float = 6
    public var height: Float = 6
    public var depth: Float = 1.6
    /// Mean bed thickness and how far hard beds stand out, in meters.
    public var bedHeight: Float = 0.55
    public var ledgeDepth: Float = 0.28
    public var material: MaterialKey = "rock.limestone"
    /// Length over which each free end shrinks toward the back and the ground, in meters. 0 keeps the full
    /// profile at both ends, for tiling sections edge to edge.
    public var endTaper: Float = 1.8
    /// How far the rounded end caps swell out past each end, in meters (0 = flat).
    public var endBulge: Float = 0.25
    /// Grid spacing in meters per LOD.
    public var spacing: [Float] = [0.07, 0.15, 0.34]
    public var lodDistances: [Float] = [25, 60]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let ns = UInt32(truncatingIfNeeded: seed) &+ 11
        let L = length, H = height
        // Beds: boundaries from y = -0.3 up to the top, each with hardness and block joints.
        struct Bed { var y0: Float; var y1: Float; var hard: Float; var joints: [Float]; var offsets: [Float] }
        // Joint set shared by most beds (joints cut through several beds), plus a few bed-only joints.
        var shared: [Float] = []
        var jx = rng.float(0...2)
        while jx < L - 0.3 { shared.append(jx); jx += rng.float(1.4...3.6) }
        var beds: [Bed] = []
        var y: Float = -0.3
        while y < H {
            let t = rng.float(0.45...1.6) * bedHeight
            var joints = shared.filter { _ in rng.chance(0.75) }
            if rng.chance(0.4) { joints.append(rng.float(0...L)) }
            if joints.isEmpty { joints = [rng.float(0...L)] }
            joints.sort()
            let hard = powf(rng.float(0...1), 1.6)
            beds.append(Bed(y0: y, y1: min(H + 0.2, y + t), hard: hard, joints: joints,
                            offsets: joints.map { _ in rng.float(-0.06...0.05) }))
            y += t
        }
        // Periodic in x: blend each noise with its copy one length over.
        func per(_ x: Float, _ f: (Float) -> Float) -> Float {
            let w = smoothstep(-L / 2, L / 2, x)
            return lerp(f(x), f(x - L), w)
        }
        func n2(_ x: Float, _ y: Float, _ s: Float, _ oct: Int, _ sd: UInt32) -> Float {
            per(x) { Noise.fbm(V3($0 * s, y * s, 0.37), octaves: oct, seed: sd) }
        }
        /// Outward offset of the face (meters, +z) at (x, y).
        func face(_ x: Float, _ y: Float) -> Float {
            let yw = y + n2(x, y, 0.3, 2, ns) * 0.45 + n2(x, y, 1.2, 2, ns &+ 7) * 0.08
            let bi = beds.firstIndex { yw < $0.y1 } ?? beds.count - 1
            let b = beds[bi]
            let t = saturate((yw - b.y0) / max(b.y1 - b.y0, 0.01))
            // Hard beds protrude with a flat top; soft beds recess and undercut the bed above.
            var z = (b.hard - 0.35) * 2 * ledgeDepth
            z -= ledgeDepth * 0.6 * (1 - b.hard) * smoothstep(0.6, 1, t)
            z -= 0.05 * (1 - smoothstep(0, 0.12, t)) + 0.04 * smoothstep(0.9, 1, t)
            // Joint blocks: per-block setback, beveled at joints. Joints wrap at the ends.
            let u = (x + L / 2).truncatingRemainder(dividingBy: L)
            var k = b.joints.lastIndex { $0 <= u } ?? (b.joints.count - 1)
            if k < 0 { k = 0 }
            let j0 = b.joints[k], j1 = k + 1 < b.joints.count ? b.joints[k + 1] : b.joints[0] + L
            let uu = u < j0 ? u + L : u
            let edgeD = min(uu - j0, j1 - uu)
            z += b.offsets[k] - 0.12 * (1 - smoothstep(0, 0.05, edgeD)) * (0.5 + b.hard)
            // Lean back, large bulges, fine relief.
            z -= y * 0.06
            z += n2(x, y, 0.18, 2, ns &+ 5) * 2.4 + n2(x, y, 0.5, 3, ns &+ 1) * 0.8 + n2(x, y, 3, 3, ns &+ 2) * 0.05
            return z
        }
        func top(_ x: Float, _ zz: Float) -> Float {
            H + per(x) { Noise.fbm(V3($0 * 0.4, 0.11, zz * 0.6), octaves: 3, seed: ns &+ 3) } * 0.9
        }
        func level(_ sp: Float) -> Surface {
            let nx = max(4, Int((L / sp).rounded()))
            let nFace = max(6, Int((H + 0.3) / sp)), nTop = max(3, Int(depth / sp)), nBack = max(2, Int(H / (sp * 4)))
            // Profile rows: (kind, parameter).
            var rows: [(Int, Float)] = []
            for j in 0...nFace { rows.append((0, -0.3 + (H + 0.3) * Float(j) / Float(nFace))) }
            for j in 1...nTop { rows.append((1, Float(j) / Float(nTop))) }
            for j in 1...nBack { rows.append((2, H - (H + 0.3) * Float(j) / Float(nBack))) }
            func point(_ x: Float, _ r: (Int, Float)) -> V3 {
                // Free ends: over `endTaper` the section shrinks toward the back and the ground, so the cliff
                // dies into the slope and the end cap stays small.
                var p = rawPoint(x, r)
                if endTaper > 0 {
                    // Beds stay level: the face recedes and everything above a falling ceiling is pressed down
                    // onto it (soft minimum), which reads as the upper beds having weathered away.
                    let t = pow(smoothstep(L / 2 - endTaper, L / 2, abs(x)), 1.2)
                    let ceiling = H - t * H * 0.7
                    let k: Float = 0.35
                    let hcl = saturate(0.5 + 0.5 * (ceiling - p.y) / k)
                    p.y = lerp(ceiling, p.y, hcl) - k * hcl * (1 - hcl)
                    p.z = -depth * 0.8 + (p.z + depth * 0.8) * (1 - t * 0.6)
                }
                return p
            }
            func rawPoint(_ x: Float, _ r: (Int, Float)) -> V3 {
                switch r.0 {
                case 0:
                    // Round the lip over the last 0.4 m.
                    let lip = smoothstep(H - 0.5, H, r.1)
                    return V3(x, r.1 - lip * lip * 0.12, face(x, r.1) - lip * 0.25)
                case 1:
                    let zf = face(x, H) - 0.25, z = lerp(zf, -depth, r.1)
                    return V3(x, top(x, z) - 0.12 * (1 - smoothstep(0, 0.2, r.1)), z)
                default:
                    return V3(x, r.1, -depth - 0.05 * n2(x, r.1, 1, 2, ns &+ 4))
                }
            }
            var s = Surface(material: material)
            for r in rows { for i in 0...nx {
                let x = -L / 2 + L * Float(i) / Float(nx)
                let p = point(x, r)
                let uv = r.0 == 1 ? V2(x, p.z) : V2(x, p.y)
                _ = s.add(p, V3(0, 0, 1), uv)
            }}
            let row = UInt32(nx + 1)
            for j in 0..<UInt32(rows.count - 1) { for i in 0..<UInt32(nx) {
                let a = j * row + i
                s.quad(a, a + 1, a + row + 1, a + row)
            }}
            // End caps: concentric rings shrinking from the profile toward its centroid, bulged outward along X
            // with rocky noise so a free end reads as a weathered rock end. The profile is identical at both ends.
            let capRings = max(3, Int(8 * 0.07 / sp))
            for (end, x) in [(0, -L / 2), (1, L / 2)] {
                let dir: Float = end == 0 ? -1 : 1
                let ring = rows.map { point(x, $0) }
                // Center of the profile's bounding box (the face rows are far denser than the back rows).
                let lo = ring.reduce(V3(repeating: .greatestFiniteMagnitude)) { simd_min($0, $1) }
                let hi = ring.reduce(V3(repeating: -.greatestFiniteMagnitude)) { simd_max($0, $1) }
                let c = (lo + hi) / 2
                func capPoint(_ p: V3, _ f: Float) -> V3 {
                    var q = lerp(p, V3(x, c.y, c.z), f)
                    let rough = Noise.fbm(V3(q.y * 0.9, q.z * 0.9, Float(end) * 7.1), octaves: 3, seed: ns &+ 9) * 0.35
                        + Noise.fbm(V3(q.y * 3, q.z * 3, Float(end) * 3.3), octaves: 2, seed: ns &+ 10) * 0.06
                    q.x += dir * (endBulge * (1 - (1 - f) * (1 - f)) + rough * smoothstep(0, 0.35, f) * min(1, endBulge * 3))
                    return q
                }
                let n = UInt32(ring.count)
                var prev = UInt32(s.positions.count)
                for p in ring { _ = s.add(p, V3(dir, 0, 0), V2(p.z, p.y)) }
                for k in 1...capRings {
                    let f = Float(k) / Float(capRings + 1)
                    let cur = UInt32(s.positions.count)
                    for p in ring { let q = capPoint(p, f); _ = s.add(q, V3(dir, 0, 0), V2(q.z, q.y)) }
                    for m in 0..<(n - 1) {
                        if end == 0 { s.quad(prev + m, prev + m + 1, cur + m + 1, cur + m) } else { s.quad(prev + m, cur + m, cur + m + 1, prev + m + 1) }
                    }
                    prev = cur
                }
                let cp = capPoint(c, 1)
                let ci = s.add(cp, V3(dir, 0, 0), V2(cp.z, cp.y))
                for m in 0..<(n - 1) {
                    if end == 0 { s.tri(ci, prev + m, prev + m + 1) } else { s.tri(ci, prev + m + 1, prev + m) }
                }
            }
            s.recomputeNormals(weldSeams: false)
            s.computeTangents()
            s.occlusion = Array(repeating: 1, count: s.positions.count)
            s.bakeCavityAO(strength: 1.4)
            rockContactAO(&s, height: 1.5)
            return s
        }
        // Center the footprint on Z (face extends forward of z = 0).
        let levels = spacing.map { sp -> Model in
            var s = level(sp)
            s.positions = s.positions.map { $0 + V3(0, 0, depth / 2 - 0.1) }
            return Model(name: Self.id, surfaces: [s])
        }
        return LODModel(levels: levels, switchDistances: lodDistances)
    }
}
