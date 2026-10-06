import simd
import Foundation

/// Clipped privet hedge segment (Ligustrum), 1.5 m long, 1.4 m tall, 0.6 m deep: flat sheared top,
/// sides battered in toward the top, thinner skirt with bare woody stems at the base. Tiles along X:
/// the segment spans exactly x = -length/2...length/2, so scenes repeat it with `place(x + i * length, z)`.
public struct PrivetHedge: RealAsset {
    public static let id = "privet-hedge"
    public static let summary = "Clipped privet hedge segment, 1.5 m x 1.4 m x 0.6 m: flat top, tapered sides, bare stems at the base; tiles along X."
    public static let tags = ["prop", "landscaping", "garden", "plant", "foliage", "fence", "outdoor"]
    public static let budget = 13500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 15)

    /// Segment length along X (tiling pitch), height and depth at the widest point, meters.
    public var length: Float = 1.5
    public var height: Float = 1.4
    public var depth: Float = 0.6
    /// Leaf-spray cards per meter of hedge.
    public var spraysPerMeter: Float = 1150
    /// Leaf-mass caps and cards on the two cut ends; turn off when segments always abut.
    public var endFaces = true
    public var leaf: MaterialKey = "leaf.privet"
    public var mass: MaterialKey = "leaf.privet-mass"
    public var wood: MaterialKey = "bark.oak-dry"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: 1), model(seed: seed, detail: 0.4)], switchDistances: [10])
    }

    /// Half-depth of the clipped profile at height y (battered sides, narrow skirt).
    func halfDepth(_ y: Float) -> Float {
        let t = saturate(y / height)
        let batter = depth / 2 * (1 - 0.14 * t)
        let skirt = 0.7 + 0.3 * smoothstep(0.0, 0.25, t)
        return batter * skirt
    }

    /// Profile point for parameter a in 0...1: up the -Z side, across the top, down the +Z side.
    func profile(_ a: Float, inset: Float) -> (p: V2, n: V2) {
        let H = height - inset, yBase: Float = 0.03
        let side = H - yBase, top = 2 * halfDepth(H)
        let total = 2 * side + top
        let s = a * total
        let r: Float = 0.07   // rounded shoulder
        if s < side {
            let y = yBase + s
            let shoulder = smoothstep(H - r, H, y)
            return (V2(-(halfDepth(y) - inset) + shoulder * r * 0.35, y), simd_normalize(V2(-1, 0.14 + shoulder * 1.5)))
        } else if s < side + top {
            let f = (s - side) / top
            let z = -halfDepth(H) + f * top
            return (V2(z * (1 - inset / max(halfDepth(H), 0.01)), H), V2(0, 1))
        } else {
            let y = H - (s - side - top)
            let shoulder = smoothstep(H - r, H, y)
            return (V2(halfDepth(y) - inset - shoulder * r * 0.35, y), simd_normalize(V2(1, 0.14 + shoulder * 1.5)))
        }
    }

    func model(seed: UInt64, detail: Float) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, half = L / 2
        let noiseSeed = rng.float(0...40)
        func bump(_ p: V3) -> Float { Noise.fbm(p * 2.2 + V3(noiseSeed, 0, 0), octaves: 3) * 0.035 }

        // Core: profile swept along X, displaced, with end caps.
        let cols = detail > 0.5 ? 40 : 20, rows = max(4, Int(L * (detail > 0.5 ? 8 : 4)))
        let coreHalf = endFaces ? half - 0.07 : half
        var core = Surface(material: mass)
        var grid: [[UInt32]] = []
        for i in 0...rows {
            let x = -coreHalf + 2 * coreHalf * Float(i) / Float(rows)
            var row: [UInt32] = []
            for j in 0...cols {
                let (q, n) = profile(Float(j) / Float(cols), inset: 0.07)
                var p = V3(x, q.y, q.x)
                p += V3(0, n.y, n.x) * bump(p)
                let k = core.add(p, V3(0, n.y, n.x), V2(x, Float(j) / Float(cols) * 3))
                core.occlusion[Int(k)] = 0.4 + 0.45 * saturate(q.y / height)
                row.append(k)
            }
            grid.append(row)
        }
        for i in 0..<rows { for j in 0..<cols {
            core.quad(grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j])
        }}
        // End caps: fan from the section centroid.
        for (e, sgn) in [(0, Float(-1)), (rows, Float(1))] {
            let x = -coreHalf + 2 * coreHalf * Float(e) / Float(rows)
            let c = core.add(V3(x, height * 0.55, 0), V3(sgn, 0, 0), V2(0, height * 0.55))
            core.occlusion[Int(c)] = 0.45
            for j in 0..<cols {
                let a = grid[e][j], b = grid[e][j + 1]
                let pa = core.positions[Int(a)], pb = core.positions[Int(b)]
                let ka = core.add(pa, V3(sgn, 0, 0), V2(pa.z, pa.y)), kb = core.add(pb, V3(sgn, 0, 0), V2(pb.z, pb.y))
                core.occlusion[Int(ka)] = 0.65; core.occlusion[Int(kb)] = 0.65
                if sgn > 0 { core.tri(c, kb, ka) } else { core.tri(c, ka, kb) }
            }
        }
        core.recomputeNormals(weldSeams: false)
        m.add(core)

        // Leaf sprays over the sides and top.
        var r = rng.fork(1)
        var cards = Surface(material: leaf)
        let n = Int(spraysPerMeter * L * detail)
        let sz: Float = 0.15
        for _ in 0..<n {
            let a = r.float(0...1)
            let (q, n2) = profile(a, inset: r.float(0.0...0.06))
            let x = r.float((-half + sz * 0.3)...(half - sz * 0.3))
            var p = V3(x, q.y, q.x)
            let nn = simd_normalize(V3(r.float(-0.15...0.15), n2.y, n2.x))
            p += nn * bump(p)
            let spot: ShrubKit.Spot = (p, nn, r.float(0.5...1))
            let s = r.float((sz * 0.8)...(sz * 1.15))
            ShrubKit.card(&cards, spot: spot, width: s, height: s, tilt: 0.5, bend: r.float(0.1...0.4), rng: &r, top: height, windScale: 0.5)
        }
        // Keep side cards inside the tile span so repeated segments meet without overlap.
        for i in cards.positions.indices { cards.positions[i].x = min(max(cards.positions[i].x, -half), half) }
        if endFaces {
            let ends = Int(Float(n) * depth * height * 1.2 / (L * (2 * height + depth)))
            for k in 0..<(2 * ends) {
                let sgn: Float = k % 2 == 0 ? -1 : 1
                let y = r.float(0.2...(height - 0.05))
                let z = r.float(-1...1) * halfDepth(y) * 0.92
                let spot: ShrubKit.Spot = (V3(sgn * (half - 0.035), y, z), V3(sgn, 0, 0), r.float(0.4...1))
                let s = r.float((sz * 0.8)...(sz * 1.1))
                ShrubKit.card(&cards, spot: spot, width: s, height: s, tilt: 0.5, bend: r.float(0.1...0.3), rng: &r, top: height, windScale: 0.5)
            }
        }
        m.add(cards)

        // Bare stems in the thin skirt.
        if detail > 0.5 {
            var t = rng.fork(2)
            var stems = Surface(material: wood)
            for _ in 0..<Int(L * 9) {
                let x = t.float((-half + 0.04)...(half - 0.04)), z = t.float(-0.08...0.08)
                let top = V3(x + t.float(-0.08...0.08), t.float(0.35...0.6), z + t.float(-0.12...0.12))
                let pts = catmull([V3(x, 0.002, z), V3(x, 0.12, z) + (top - V3(x, 0, z)) * 0.15, top], per: 3)
                let r0 = t.float(0.008...0.014)
                stems.append(Prim.tube(pts, radii: pts.indices.map { r0 * (1 - 0.5 * Float($0) / Float(pts.count - 1)) }, sides: 5,
                                       seamTile: 0.05, material: wood))
            }
            m.add(stems)
        }
        ShrubKit.finish(&m, height: 0.4, floor: 0.4)
        return ShrubKit.fit(m, size: V3(length, height, depth))
    }
}
