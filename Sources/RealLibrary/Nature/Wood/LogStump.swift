import simd
import Foundation

/// Felled-tree stump, 50 cm across and 40 cm tall: flared base with root buttresses running into the
/// ground, mossy bark sides, a weathered chainsaw cut on top with growth rings, radial checks and a
/// visible bark layer. 2 LODs.
public struct LogStump: RealAsset {
    public static let id = "log-stump"
    public static let summary = "Felled-tree stump, 50 cm across: root flare and buttresses, mossy bark, weathered sawn top with rings and checks."
    public static let tags = ["nature", "wood", "camp"]
    public static let budget = 4_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 28, distance: 1.0)

    /// Trunk diameter at the cut, meters.
    public var diameter: Float = 0.5
    /// Cut height above ground, meters.
    public var height: Float = 0.4
    /// Extra radius at ground level as a fraction of the trunk radius.
    public var flare: Float = 0.6
    /// Number of root buttresses.
    public var roots = 5
    /// Bark thickness seen on the cut, meters.
    public var barkThickness: Float = 0.022
    /// Cut tilt in degrees (chainsaw cuts are rarely level).
    public var tilt: Float = 4
    /// Surface root length as a multiple of the trunk radius scale (1 = short buttress roots).
    public var rootReach: Float = 1
    /// Height the roots arch above the ground before diving in, meters (eroded banks expose them).
    public var rootArch: Float = 0
    public var bark: MaterialKey = "bark.oak-mossy"
    /// Bark seen in cross-section on the cut (no moss).
    public var barkEdge: MaterialKey = "bark.oak"
    public var top: MaterialKey = "wood.endgrain-weathered"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let ns = UInt32(truncatingIfNeeded: seed)
        let R = rng.vary(diameter / 2, 0.15), H = rng.vary(height, 0.2)
        let rootAngles = (0..<roots).map { Float($0) / Float(roots) * 2 * .pi + rng.float(-0.4...0.4) }
        let rootSize = rootAngles.map { _ in rng.float(0.6...1.2) }
        let tiltDir = rng.float(0...(2 * .pi)), tiltK = tan(radians(rng.vary(tilt, 0.5)))
        let spin = rng.float(0...(2 * .pi))
        // Radius at angle a and height y: trunk with noise, flare and buttress lobes near the ground.
        func radius(_ a: Float, _ y: Float) -> Float {
            var lobe: Float = 0
            for (ra, s) in zip(rootAngles, rootSize) {
                let d = abs(remainder(a - ra, 2 * .pi))
                lobe += s * exp(-d * d / 0.05)
            }
            let low = exp(-max(y, 0) / (0.16 * R / 0.25))
            let n = Noise.fbm(V3(cos(a) * 2, y * 4, sin(a) * 2), octaves: 3, seed: ns) * 0.06
            return R * (1 + n + flare * low * (0.25 + lobe) + (y < 0 ? -y * 2 : 0))
        }
        func topY(_ a: Float, _ r: Float) -> Float { H + tiltK * r * cos(a - tiltDir) }
        func lod(_ na: Int, _ ny: Int) -> Model {
            var m = Model(name: Self.id)
            let tile = MaterialLibrary.spec(for: bark).tileSize
            let uTotal = max(tile, (2 * .pi * R / tile).rounded() * tile)
            var rows: [[V3]] = [], uvs: [[V2]] = [], occ: [[Float]] = []
            for j in 0...ny {
                let t = Float(j) / Float(ny)
                var row: [V3] = [], uv: [V2] = [], o: [Float] = []
                for k in 0...na {
                    let a = Float(k % na) / Float(na) * 2 * .pi
                    // Rows bunch toward the ground where the flare curves.
                    let y0: Float = -0.06
                    let y = y0 + (topY(a, R) - y0) * (t * t * 0.55 + t * 0.45)
                    let r = radius(a, y)
                    row.append(V3(r * cos(a), y, -r * sin(a)))
                    uv.append(V2(Float(k) / Float(na) * uTotal, y))
                    o.append(0.45 + 0.55 * smoothstep(-0.05, 0.25, y))
                }
                rows.append(row); uvs.append(uv); occ.append(o)
            }
            var side = WoodParts.grid(rows, uvs: uvs, material: bark, occlusion: occ)
            WoodParts.orientOutward(&side) { p in V3(0, p.y, 0) }
            side.recomputeNormals()
            m.add(side)
            // Top: bark ring, then the sawn face, slightly domed by weathering.
            let rim = rows[ny].dropLast()
            let inner = rim.enumerated().map { (k, p) -> V3 in
                let a = Float(k) / Float(na) * 2 * .pi
                let d = V2(p.x, p.z), l = simd_length(d)
                let q = d * ((l - barkThickness) / l)
                return V3(q.x, topY(a, l - barkThickness) - 0.004, q.y)
            }
            let n = simd_normalize(V3(-tiltK * cos(tiltDir), 1, tiltK * sin(tiltDir)))
            m.add(WoodParts.ring(inner: inner, outer: Array(rim), normal: n, material: barkEdge, uvScale: 1))
            var face = WoodParts.cap(inner, normal: n, pith: V3(0, H, 0), e1: V3(1, 0, 0), e2: V3(0, 0, -1),
                                     radius: R - barkThickness, spin: spin, material: top)
            face.positions[0].y += 0.006
            m.add(face)
            // Surface roots: tapered tubes leaving each buttress and diving under the leaf litter.
            if na > 24 {
                for (ra, sz) in zip(rootAngles, rootSize) {
                    let d = V3(cos(ra), 0, -sin(ra))
                    let r0 = radius(ra, 0.04)
                    let len = R * rng.float(0.7...1.2) * sz * rootReach
                    let side = V3(-d.z, 0, d.x) * rng.float(-0.15...0.15)
                    let pts = catmull([d * (r0 * 0.55) + V3(0, 0.12, 0), d * (r0 + len * 0.45) + side * len + V3(0, rootArch * rng.float(0.6...1.2), 0),
                                       d * (r0 + len) + side * len * 1.6 + V3(0, -0.16, 0)], per: 5)
                    let radii = pts.indices.map { i in R * 0.3 * sz * (1 - 0.6 * Float(i) / Float(pts.count - 1)) }
                    var root = Prim.tube(pts, radii: radii, sides: 10, seamTile: MaterialLibrary.spec(for: bark).tileSize, material: bark)
                    root.occlusion = root.positions.map { 0.5 + 0.5 * smoothstep(-0.02, 0.12, $0.y) }
                    m.add(root)
                }
            }
            for i in m.surfaces.indices { m.surfaces[i].computeTangents() }
            for i in m.surfaces.indices where m.surfaces[i].material != bark { m.surfaces[i].bakeCavityAO(strength: 0.5, floor: 0.7) }
            return m
        }
        return LODModel(levels: [lod(48, 16), lod(20, 7)], switchDistances: [14])
    }
}
