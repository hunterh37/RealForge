import simd
import Foundation

/// Limestone cliff section 6 m long and 6 m high (4 to 8 m works), 1.6 m deep: bedded strata with protruding
/// hard beds, undercut soft beds, jointed blocks and a rounded top lip. The face is +Z. Modular along X:
/// both ends share one profile, so sections repeat at `place(x + i * length, z)`. 3 LODs.
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
            // End caps: fan from the profile centroid. The profile is identical at both ends.
            for (end, x) in [(0, -L / 2), (1, L / 2)] {
                let ring = rows.map { point(x, $0) }
                let c = ring.reduce(V3.zero, +) / Float(ring.count)
                let ci = s.add(V3(x, c.y, c.z), V3(end == 0 ? -1 : 1, 0, 0), V2(c.z, c.y))
                let first = UInt32(s.positions.count)
                for p in ring { _ = s.add(p, V3(end == 0 ? -1 : 1, 0, 0), V2(p.z, p.y)) }
                for k in 0..<UInt32(ring.count - 1) {
                    if end == 0 { s.tri(ci, first + k, first + k + 1) } else { s.tri(ci, first + k + 1, first + k) }
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
