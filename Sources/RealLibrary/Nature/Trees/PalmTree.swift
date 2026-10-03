import simd
import Foundation

/// Coconut palm (Cocos nucifera), ~12 m: grey ringed trunk 30-40 cm across with a swollen root bole,
/// leaning 5-14 degrees and curving upright; crown of 12-18 pinnate fronds 4-5 m long whose leaflets hang
/// in a V and whose tips droop with age; bunches of coconuts under the frond bases.
/// Built directly (TreeGenerator has no fronds): trunk tube, folded frond strips on the `leaf.palm` atlas.
public struct PalmTree: RealAsset {
    public static let id = "palm-tree"
    public static let summary = "Coconut palm, ~12 m: leaning ringed trunk, crown of 12-18 drooping pinnate fronds, coconut bunches, 3 LODs."
    public static let tags = ["nature", "tree", "palm", "beach"]
    public static let budget = 16_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 12, distance: 1.05)

    /// Trunk height in meters (crown top sits ~1.5 m higher).
    public var height: Float = 12
    /// Trunk radius at breast height and below the crown, meters.
    public var trunkRadius: Float = 0.18
    public var topRadius: Float = 0.13
    /// Lean from vertical at the base, degrees.
    public var lean: ClosedRange<Float> = 5...14
    /// Full frond length (petiole + leafy blade), meters.
    public var frondLength: Float = 5.2
    public var frondCount: ClosedRange<Int> = 12...18
    public var coconutCount: ClosedRange<Int> = 6...14
    public var lodDistances: [Float] = [16, 45]
    public init() {}

    private struct Detail {
        var trunkSides: Int, trunkStride: Int, frondStride: Int, cross: Int, petioleSides: Int, rachis: Bool, nutSubdiv: Int
    }
    private static let details = [
        Detail(trunkSides: 16, trunkStride: 1, frondStride: 1, cross: 7, petioleSides: 6, rachis: true, nutSubdiv: 4),
        Detail(trunkSides: 9, trunkStride: 2, frondStride: 2, cross: 5, petioleSides: 4, rachis: false, nutSubdiv: 2),
        Detail(trunkSides: 6, trunkStride: 4, frondStride: 4, cross: 3, petioleSides: 3, rachis: false, nutSubdiv: 0),
    ]

    private struct Frond {
        var points: [V3]      // rachis, uniform arc length, petiole first
        var petioleEnd: Int   // index where the leafy blade starts
        var side: V3          // horizontal, perpendicular to the frond's azimuth
        var width: Float      // blade width (texture aspect 0.36 x blade length)
        var fold: Float       // leaflet droop angle at the base of the blade, radians
        var roll: Float       // twist toward the tip, radians
        var phase: Float
        var cell: Int
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let h = rng.vary(height, 0.12)

        // Trunk: lean at the base, curving back toward vertical.
        let leanA = radians(rng.float(lean)), az = rng.float(0...(2 * .pi))
        let ldir = V3(cos(az), 0, sin(az))
        let bend = rng.float(0.5...0.85)
        let n = 48
        var trunk: [V3] = [V3(0, -0.08, 0)]
        let step = (h + 0.08) / Float(n)
        for k in 1...n {
            let t = Float(k) / Float(n)
            let a = leanA * (1 - bend * pow(t, 1.3))
            let wob = V3(Noise.perlin(V3(t * 3, 1, 0), seed: UInt32(truncatingIfNeeded: seed)), 0, Noise.perlin(V3(t * 3, 5, 0), seed: UInt32(truncatingIfNeeded: seed))) * 0.04
            trunk.append(trunk[k - 1] + (ldir * sin(a) + V3(0, cos(a), 0) + wob) * step)
        }
        let top = trunk[n]
        let topDir = simd_normalize(trunk[n] - trunk[n - 2])
        let trunkR: [Float] = trunk.map { p in
            let t = saturate(p.y / h)
            let bole = 0.55 * exp(-max(p.y, 0) / 0.35) + 0.12 * exp(-max(p.y, 0) / 1.5)
            return trunkRadius * (lerp(1, topRadius / trunkRadius, pow(t, 0.8)) + bole)
        }

        // Crown: fronds in phyllotaxis, youngest near vertical, oldest hanging.
        let crownBase = top + topDir * 0.45
        let fc = rng.int(frondCount)
        var fronds: [Frond] = []
        var faz = rng.float(0...(2 * .pi))
        for i in 0..<fc {
            let age = Float(i) / Float(max(1, fc - 1))
            faz += radians(137.5) + rng.float(-0.15...0.15)
            let a = V3(cos(faz), 0, sin(faz))
            let elev = radians(68 - age * 100 + rng.float(-8...8))
            let len = frondLength * rng.vary(1, 0.08) * (i < 2 ? 0.7 : 1)
            let base = crownBase - topDir * (age * 0.55) + a * 0.12
            var d = simd_normalize(a * cos(elev) + V3(0, sin(elev), 0))
            let g = (0.1 + 0.3 * age) * rng.vary(1, 0.2)
            let m = 40
            let ds = len / Float(m)
            var pts = [base]
            for k in 1...m {
                let t = Float(k) / Float(m)
                // Droop grows along the frond (lever arm) and with age.
                d = simd_normalize(d + V3(0, -g * ds * (0.3 + 1.4 * t), 0))
                pts.append(pts[k - 1] + d * ds)
            }
            let side = simd_normalize(simd_cross(V3.up, a))
            let pe = Int(Float(m) * rng.float(0.18...0.24))
            let blade = len * Float(m - pe) / Float(m)
            fronds.append(Frond(points: pts, petioleEnd: pe, side: side, width: 0.36 * blade,
                                fold: radians(i < 2 ? 60 : rng.float(34...52)), roll: radians(rng.float(-25...25)),
                                phase: rng.float(0...6.28), cell: rng.int(0...1)))
        }

        // Coconut bunches under the frond bases.
        var nuts: [(V3, simd_quatf, Float)] = []
        let nc = rng.int(coconutCount)
        let bunches = max(1, nc / 4)
        for b in 0..<bunches {
            let ba = rng.float(0...(2 * .pi)) + Float(b) * 2.1
            let bdir = V3(cos(ba), 0, sin(ba))
            let center = top + topDir * 0.1 + bdir * 0.32 - V3(0, rng.float(0.1...0.35), 0)
            let count = b == bunches - 1 ? nc - (bunches - 1) * (nc / bunches) : nc / bunches
            for k in 0..<count {
                let ka = ba + Float(k - count / 2) * 0.55 + rng.float(-0.2...0.2)
                let p = center + V3(cos(ka), 0, sin(ka)) * rng.float(0.05...0.16) - V3(0, rng.float(0...0.22), 0)
                let q = simd_quatf(degrees: rng.float(-40...40), axis: rng.unitVector()) * simd_quatf(degrees: rng.float(0...360), axis: .up)
                nuts.append((p, q, rng.vary(1, 0.1)))
            }
        }

        let crownCenter = crownBase + V3(0, -0.6, 0)
        func level(_ dt: Detail) -> Model {
            var m = Model(name: Self.id)
            // Trunk.
            let idx = Array(stride(from: 0, to: trunk.count, by: dt.trunkStride)) + ((trunk.count - 1) % dt.trunkStride == 0 ? [] : [trunk.count - 1])
            let tp = idx.map { trunk[$0] }, tr = idx.map { trunkR[$0] }
            let ns = UInt32(truncatingIfNeeded: seed)
            var tube = Prim.tube(tp, radii: tr, sides: dt.trunkSides, seamTile: 0.5, material: "bark.palm",
                                 weights: tp.map { 0.18 * pow(saturate($0.y / h), 2) }, phase: 0, capEnd: false) { a, v in
                // Root bole lobes near the ground.
                let k = exp(-v * 3)
                return 1 + k * 0.12 * (Noise.perlin(V3(cos(a * 2 * .pi) * 2, sin(a * 2 * .pi) * 2, v), seed: ns) + 0.3)
            }
            tube.occlusion = tube.positions.map { p in
                (0.55 + 0.45 * smoothstep(0, 1.2, p.y)) * (1 - 0.4 * smoothstep(h - 1.8, h, p.y))
            }
            m.add(tube)
            // Leaf-base bulb wrapping the frond bases.
            let bulbPts = (0...4).map { k in top - topDir * 0.35 + topDir * (Float(k) / 4 * 0.95) }
            let bulbR: [Float] = [0.95, 1.25, 1.3, 1.1, 0.6].map { $0 * topRadius * 1.15 }
            var bulb = Prim.tube(bulbPts, radii: bulbR, sides: max(6, dt.trunkSides - 2), seamTile: 0.4, material: "leaf.palm-stem",
                                 weights: bulbPts.map { _ in 0.18 }, phase: 0, capEnd: true)
            bulb.occlusion = bulb.positions.map { _ in 0.55 }
            m.add(bulb)

            var leaves = Surface(material: "leaf.palm")
            var stems = Surface(material: "leaf.palm-stem")
            for f in fronds {
                let pts = f.points
                let last = pts.count - 1
                // Petiole.
                let pIdx = Array(stride(from: 0, through: f.petioleEnd, by: max(1, dt.frondStride * 2))) + (f.petioleEnd % max(1, dt.frondStride * 2) == 0 ? [] : [f.petioleEnd])
                let pp = pIdx.map { pts[$0] }
                if pp.count >= 2 {
                    var pet = Prim.tube(pp, radii: pp.indices.map { lerp(0.05, 0.03, Float($0) / Float(pp.count - 1)) }, sides: dt.petioleSides, seamTile: 0.4,
                                        material: "leaf.palm-stem", weights: pp.indices.map { 0.15 + 0.2 * Float($0) / Float(pp.count - 1) }, phase: f.phase, capEnd: false)
                    pet.occlusion = pet.positions.map { saturate(0.5 + 0.5 * smoothstep(0, 1.5, simd_distance($0, crownCenter))) }
                    stems.append(pet)
                }
                // Blade strip.
                let bIdx = Array(stride(from: f.petioleEnd, through: last, by: dt.frondStride)) + ((last - f.petioleEnd) % dt.frondStride == 0 ? [] : [last])
                var s = Surface(material: "leaf.palm")
                let cells = 2
                let u0 = Float(f.cell) / Float(cells), uw = 1 / Float(cells)
                let hw = f.width / 2
                for (r, i) in bIdx.enumerated() {
                    let sv = Float(i - f.petioleEnd) / Float(last - f.petioleEnd)
                    let t = simd_normalize(pts[min(last, i + 1)] - pts[max(0, i - 1)])
                    var side = simd_normalize(f.side - t * simd_dot(f.side, t))
                    var up = simd_cross(t, side)
                    let roll = f.roll * sv * sv
                    let q = simd_quatf(angle: roll, axis: t)
                    side = q.act(side); up = q.act(up)
                    let fold = f.fold + radians(18) * sv
                    let w = 0.35 + 0.65 * sv
                    for j in 0..<dt.cross {
                        let x = Float(j) / Float(dt.cross - 1) * 2 - 1
                        let ax = abs(x)
                        let p = pts[i] + side * (x * hw * cos(fold)) - up * (pow(ax, 1.25) * hw * sin(fold))
                        s.add(p, up, V2(u0 + (x + 1) / 2 * uw, sv), extra: V2(w * (0.75 + 0.25 * ax), f.phase))
                    }
                    if r > 0 {
                        let a0 = UInt32((r - 1) * dt.cross), a1 = UInt32(r * dt.cross)
                        for j in 0..<UInt32(dt.cross - 1) { s.quad(a0 + j, a0 + j + 1, a1 + j + 1, a1 + j) }
                    }
                }
                s.recomputeNormals(weldSeams: false)
                // Soften: blend toward up and the crown-sphere normal so the crown shades as a volume.
                s.normals = zip(s.normals, s.positions).map { nrm, p in
                    let nn = nrm.y < 0 ? -nrm : nrm
                    return simd_normalize(nn * 0.55 + simd_normalize(p - crownCenter) * 0.3 + V3(0, 0.3, 0))
                }
                s.occlusion = s.positions.map { p in
                    let d = simd_distance(p, crownCenter)
                    return saturate(0.5 + 0.5 * smoothstep(0.3, 2.6, d) - 0.15 * saturate(crownCenter.y - p.y))
                }
                leaves.append(s)
                // Rachis ridge along the blade (hero LOD only).
                if dt.rachis {
                    let rp = bIdx.map { pts[$0] }
                    var rach = Prim.tube(rp, radii: rp.indices.map { lerp(0.028, 0.006, Float($0) / Float(rp.count - 1)) }, sides: 4, seamTile: 0.4,
                                         material: "leaf.palm-stem", weights: rp.indices.map { 0.35 + 0.65 * Float($0) / Float(rp.count - 1) }, phase: f.phase, capEnd: false)
                    rach.occlusion = rach.positions.map { saturate(0.55 + 0.45 * smoothstep(0.3, 2.6, simd_distance($0, crownCenter))) }
                    stems.append(rach)
                }
            }
            leaves.computeTangents()
            stems.computeTangents()
            m.add(stems)
            m.add(leaves)
            // Coconuts.
            if dt.nutSubdiv > 0 {
                var nutS = Surface(material: "fruit.coconut")
                for (p, q, sc) in nuts {
                    var c = Prim.cubeSphere(subdivisions: dt.nutSubdiv, material: "fruit.coconut") { d in
                        let ridge = 1 + 0.07 * cos(3 * atan2(d.z, d.x)) * (1 - abs(d.y))
                        return V3(d.x * 0.125 * ridge, d.y * 0.15 - 0.02 * d.y * d.y, d.z * 0.125 * ridge) * sc
                    }
                    c.occlusion = c.positions.map { 0.45 + 0.25 * saturate($0.y / 0.15 + 0.5) }
                    c.extra = c.positions.map { _ in V2(0.2, 0) }
                    nutS.append(c, Xform(translation: p, rotation: q))
                }
                nutS.computeTangents()
                m.add(nutS)
            }
            return m
        }
        var levels = Self.details.map(level)
        // Keep the bounding box roughly centered on the base (lean can push the crown off to one side).
        let bb = levels[0].bounds, c = (bb.min + bb.max) / 2, e = bb.max - bb.min
        let lim = V2(e.x * 0.15, e.z * 0.15)
        let shift = V3(c.x - max(-lim.x, min(lim.x, c.x)), 0, c.z - max(-lim.y, min(lim.y, c.z)))
        if simd_length(shift) > 0 { levels = levels.map { $0.transformed(Xform(translation: -shift)) } }
        return LODModel(levels: levels, switchDistances: lodDistances)
    }
}
