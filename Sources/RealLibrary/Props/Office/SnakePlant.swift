import simd
import Foundation

/// Snake plant (Sansevieria trifasciata) in a 25 cm matte ceramic cylinder pot: rolled rim, slight foot
/// taper, peat potting mix 3 cm below the rim. 12-18 stiff sword leaves, 40-80 cm, rising in fans from
/// three or four rhizome clumps: each leaf is a closed, slightly thick cross-section that is concave on
/// its face, widest at a third of its height, twisting a little and tapering to a sharp tip.
public struct SnakePlant: RealAsset {
    public static let id = "snake-plant"
    public static let summary = "Snake plant: 12-18 stiff, twisted, concave sword leaves in clumps, potting mix, matte ceramic cylinder pot 25 cm across."
    public static let tags = ["prop", "plant", "decor", "interior", "office"]
    public static let budget = 7_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 12, distance: 1.1, studio: true)

    public var potDiameter: Float = 0.25
    public var potHeight: Float = 0.24
    public var pot: MaterialKey = "ceramic.stoneware:E4E1DA"
    public var leaf: MaterialKey = "leaf.sansevieria"
    public var leafCount = 15
    /// Longest leaf, meters.
    public var leafLength: Float = 0.75
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [5])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = potDiameter / 2, H = potHeight
        // Pot: straight cylinder with a 6 mm foot chamfer and a rounded rim, 9 mm wall.
        let outer: [V2] = [V2(0, 0), V2(R - 0.012, 0), V2(R - 0.004, 0.004), V2(R - 0.002, 0.03), V2(R, H - 0.006)]
        let segs = detail ? 40 : 20
        m.add(Prim.lathe(Profile.shell(outer, wall: 0.009, floor: 0.02, lipSegments: detail ? 4 : 2), segments: segs, seamTile: 0.1, material: pot))
        // Potting mix: slight mound, rough.
        let soilY = H - 0.03
        var soil = Prim.lathe([V2(0, soilY - 0.03), V2(R - 0.009, soilY - 0.03), V2(R - 0.009, soilY - 0.002), V2(R * 0.5, soilY + 0.008), V2(0, soilY + 0.012)],
                              segments: segs, seamTile: 0.1, material: "soil.potting")
        if detail {
            soil = soil.subdivided()
            soil.displace { p, n in n.y > 0.5 ? Noise.fbm(V3(p.x * 40, 0, p.z * 40), octaves: 2) * 0.004 : 0 }
        }
        m.add(soil)

        // Leaves in clumps.
        let clumps = rng.int(3...4)
        var centers: [V2] = []
        for c in 0..<clumps {
            let a = Float(c) / Float(clumps) * 2 * .pi + rng.float(-0.4...0.4)
            centers.append(V2(cos(a), sin(a)) * rng.float(0.025...0.055))
        }
        let rings = detail ? 13 : 6
        for i in 0..<max(1, leafCount) {
            var r = rng.fork(i + 1)
            let c = centers[i % clumps]
            let base = V3(c.x + r.float(-0.012...0.012), soilY - 0.02, c.y + r.float(-0.012...0.012))
            let outDir2 = simd_length(c) > 1e-4 ? simd_normalize(c) : V2(1, 0)
            // Fan within the clump: leaves splay sideways around the clump's outward direction.
            let fanA = atan2(outDir2.y, outDir2.x) + r.float(-1.0...1.0)
            let out = V3(cos(fanA), 0, sin(fanA))
            let inner = i % clumps == 0 && i < clumps * 2
            let L = leafLength * (inner ? r.float(0.85...1.0) : r.float(0.55...0.9))
            let lean = r.float(0.03...0.13), bend = r.float(0.0...0.06)
            let wMax = r.float(0.05...0.075)
            let twist = r.float(-0.7...0.7)
            // Concave face looks roughly back toward the plant's center, with scatter.
            let faceA = fanA + .pi + r.float(-0.9...0.9)
            let f0 = V3(cos(faceA), 0, sin(faceA))
            let u0 = simd_normalize(simd_cross(.up, f0))
            leafSurface(&m, base: base, out: out, length: L, lean: lean, bend: bend, width: wMax, twist: twist,
                        face: f0, across: u0, rings: rings, detail: detail)
        }
        groundAO(&m, height: 0.08, floor: 0.6)
        return m
    }

    func leafSurface(_ m: inout Model, base: V3, out: V3, length L: Float, lean: Float, bend: Float, width wMax: Float, twist: Float,
                     face f0: V3, across u0: V3, rings: Int, detail: Bool) {
        // Cross-section stations across the blade: s in -1...1 on the face, back again on the underside.
        let front: [Float] = detail ? [-1, -0.6, -0.2, 0.2, 0.6, 1] : [-1, 0, 1]
        let back: [Float] = detail ? [0.6, 0.2, -0.2, -0.6] : [0]
        var loops: [[V3]] = []
        for k in 0...rings {
            let t = 1 - pow(1 - Float(k) / Float(rings), 1.25)
            let center = base + V3(0, L * t, 0) + out * (L * lean * t + L * bend * t * t)
            let w = wMax * (0.42 + 0.58 * smoothstep(0, 0.32, t)) * (t < 0.68 ? 1 : pow(max(0, 1 - (t - 0.68) / 0.32), 0.75))
            let thick = (0.0045 - 0.002 * t) * (k == rings ? 0 : 1)
            let cup = w * 0.16 * (1 - 0.4 * t)
            let a = twist * t
            let u = u0 * cos(a) + f0 * sin(a), n = f0 * cos(a) - u0 * sin(a)
            var loop: [V3] = []
            for s in front {
                let e = sqrt(max(0, 1 - s * s))
                loop.append(center + u * (s * w / 2) + n * (-cup * (1 - s * s) + thick / 2 * e))
            }
            for s in back {
                let e = sqrt(max(0, 1 - s * s))
                loop.append(center + u * (s * w / 2) + n * (-cup * (1 - s * s) - thick / 2 * e))
            }
            loops.append(loop)
        }
        var s = Prim.loft(loops, capStart: true, material: leaf)
        // Leaves stand stiff: no wind weight except a hint at the tips.
        s.extra = s.positions.map { V2(0.15 * saturate(($0.y - base.y) / L), 0) }
        m.add(s)
    }
}
