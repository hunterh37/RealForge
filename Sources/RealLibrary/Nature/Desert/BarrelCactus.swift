import simd
import Foundation

/// Fishhook barrel cactus (Ferocactus wislizeni), ~0.6 m tall and 0.6 m across: squat ribbed barrel with
/// 20-26 deep ribs, a hooked red-amber central spine on every areole, a ring of yellow fruit on top.
public struct BarrelCactus: RealAsset {
    public static let id = "barrel-cactus"
    public static let summary = "Barrel cactus, ~0.6 m: squat body with 20-26 deep ribs, hooked central spines, yellow fruit ring on top, 3 LODs."
    public static let tags = ["nature", "desert"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 18, distance: 1.2)

    /// Body height and radius (to the rib crests), meters.
    public var height: Float = 0.62
    public var radius: Float = 0.29
    public var ribs: ClosedRange<Int> = 20...26
    /// Vertical spacing of hooked central spines along a rib, meters (a multiple of the 2.5 cm areole rows).
    public var areoleSpacing: Float = 0.05
    public var fruitCount: ClosedRange<Int> = 0...9
    public var lodDistances: [Float] = [6, 18]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let h = rng.vary(height, 0.25), R = rng.vary(radius, 0.12)
        let nr = rng.int(ribs)
        // Barrels lean a little (toward the sun in the wild).
        let leanDir = rng.unitVector()
        let lean = V3(leanDir.x, 0, leanDir.z) * rng.float(0...0.12)
        // Axis profile: radius bulges at mid-height, domes over the top.
        let axisN = 24
        let axis: [V3] = (0...axisN).map { k in
            let t = Float(k) / Float(axisN)
            return V3(0, -0.04 + (h + 0.04) * t, 0) + lean * t * t * h
        }
        let ns = UInt32(truncatingIfNeeded: seed)
        func radiusAt(_ s: Float, _ len: Float) -> Float {
            let t = s / len
            let barrel = 0.86 + 0.14 * sin(.pi * min(1, t * 1.25))
            return R * barrel * CactusMesh.dome(s, len: len, r: R * 0.85)
        }
        let fruits: [(V3, simd_quatf)] = {
            let n = rng.int(fruitCount)
            return (0..<n).map { i in
                let a = Float(i) / Float(max(1, n)) * 2 * .pi + rng.float(-0.3...0.3)
                let p = axis[axisN] + V3(cos(a), 0, sin(a)) * R * rng.float(0.25...0.4) - V3(0, 0.03, 0)
                return (p, simd_quatf(degrees: rng.float(10...30), axis: V3(-sin(a), 0, cos(a))))
            }
        }()

        func level(_ lod: Int) -> Model {
            let perRib = [4, 2, 1][lod], spacing: Float = [0.025, 0.06, 0.15][lod]
            let pts = CactusMesh.resample(catmull(axis, per: 2), spacing: spacing)
            let acc = CactusMesh.arcLengths(pts), len = acc.last ?? h
            var body = CactusMesh.ribbed(pts, radii: acc.map { radiusAt($0, len) }, ribs: nr, depth: [0.2, 0.2, 0.08][lod], perRib: perRib,
                                         tile: 0.2, material: "cactus.barrel")
            body.bakeCavityAO(strength: 1.4, floor: 0.4)
            body.occlusion = zip(body.occlusion, body.positions).map { o, p in o * (0.5 + 0.5 * smoothstep(-0.02, 0.25, p.y)) }
            body.computeTangents()
            var m = Model(name: Self.id, surfaces: [body])
            // Central spines on the rib crests, one per areole (every other areole at LOD1, none at LOD2).
            if lod < 2 {
                var sp = Surface(material: "cactus.spine")
                var srng = SeededRNG(seed: seed &+ 0x5EED)
                let rows = Int(len / areoleSpacing)
                for r in 0..<rows where lod == 0 || r % 2 == 0 {
                    let s = (Float(r) + 0.25) * areoleSpacing   // on every other texture areole (rows 2.5 cm apart)
                    if s > len - 0.02 { continue }
                    // Frame on the axis at arc length s.
                    let f = s / len * Float(pts.count - 1)
                    let i = min(Int(f), pts.count - 2)
                    let c = lerp(pts[i], pts[i + 1], f - Float(i))
                    let t = simd_normalize(pts[i + 1] - pts[i])
                    let rad = radiusAt(s, len)
                    for k in 0..<nr {
                        let a = Float(k) / Float(nr) * 2 * .pi
                        var nrm = simd_normalize(V3(1, 0, 0) - t * t.x)
                        let bin = simd_cross(t, nrm)
                        nrm = nrm * cos(a) + bin * sin(a)
                        let base = c + nrm * (rad * 0.99)
                        let L = srng.float(0.045...0.075) * (s > len - R * 0.6 ? 1.15 : 1)
                        // Out from the body, pointing down, hooked at the tip.
                        let out = simd_normalize(nrm * 0.75 - t * 0.35 + srng.unitVector() * 0.15)
                        let p1 = base + out * L * 0.6
                        let p2 = p1 + simd_normalize(out - t * 0.8) * L * 0.3
                        let p3 = p2 + simd_normalize(-t - out * 0.4) * L * 0.12
                        let path = lod == 0 ? [base - out * 0.004, p1, p2, p3] : [base - out * 0.004, p1, p2]
                        var spine = Prim.tube(path, radii: path.indices.map { lerp(0.0022, 0.0006, Float($0) / Float(path.count - 1)) },
                                              sides: 3, seamTile: 0.05, material: "cactus.spine", capEnd: false)
                        spine.occlusion = spine.positions.map { _ in 0.85 }
                        sp.append(spine)
                    }
                }
                sp.computeTangents()
                m.add(sp)
            }
            // Fruit ring.
            if !fruits.isEmpty && lod < 2 {
                var fr = Surface(material: "fruit.cactus")
                for (p, q) in fruits {
                    var f = Prim.cubeSphere(subdivisions: lod == 0 ? 3 : 1, material: "fruit.cactus") { d in
                        V3(d.x * 0.018, d.y * 0.026 + 0.026, d.z * 0.018) * (1 + 0.04 * Noise.perlin(d * 3, seed: ns))
                    }
                    f.occlusion = f.positions.map { 0.7 + 0.3 * saturate($0.y / 0.05) }
                    fr.append(f, Xform(translation: p, rotation: q))
                }
                fr.computeTangents()
                m.add(fr)
            }
            return m
        }
        return LODModel(levels: [level(0), level(1), level(2)], switchDistances: lodDistances)
    }
}
