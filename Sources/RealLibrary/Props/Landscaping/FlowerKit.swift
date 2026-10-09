import simd
import Foundation

/// One flower head. `color` and `center` are hex strings; every other field shapes the bloom.
public struct FlowerStyle: Sendable {
    public var color = "E8334A"
    public var center = "4A3018"
    public var petals = 6
    public var rows = 1
    /// Petal length and width at the base, meters.
    public var length: Float = 0.06
    public var width: Float = 0.02
    /// Tip width as a fraction of `width`.
    public var tipWidth: Float = 0.4
    /// Radians from the head axis at the petal root (0 closed cup, 1.5 flat) and extra bend toward the tip.
    public var lean: Float = 0.9
    public var curl: Float = 0.6
    public var fold: Float = -0.1
    /// Petal outline belly (see `PlantKit.Blade.belly`); 0 keeps a base-wide taper.
    public var belly: Float = 0.7
    public var rowShrink: Float = 0.8
    public var rowLift: Float = 0.3
    public var jitter: Float = 0.12
    /// Center disc radius (0 for none) and height as a fraction of the radius.
    public var centerRadius: Float = 0
    public var centerDome: Float = 0.5
    public init() {}
    public func with(_ edit: (inout Self) -> Void) -> Self { var c = self; edit(&c); return c }
}

/// Growth habit of a flowering plant.
public struct FlowerPlan: Sendable {
    public enum Habit: Sendable { case clump, spike }
    public var habit = Habit.clump
    public var stems = 7...11
    public var height: ClosedRange<Float> = 0.4...0.6
    public var spread: Float = 0.12
    public var lean: ClosedRange<Float> = 0.05...0.2
    public var stemRadius: Float = 0.003
    public var stemLeaves = 3...5
    public var basal = 8...14
    public var leafLength: ClosedRange<Float> = 0.1...0.18
    public var leafWidth: Float = 0.025
    public var leafTip: Float = 0
    public var leafBelly: Float = 0
    public var leafLean: ClosedRange<Float> = 0.6...1.2
    public var leafColor = "4E7A34"
    public var stemColor = "5E7A3A"
    /// 0 heads look up the stem axis, 1 they face outward.
    public var facing: Float = 0.3
    /// Spike habit: florets per stem, where they start along the stem (fraction), cone radius at the base
    /// of the spike and size at the tip as a fraction of the base size.
    public var florets = 10...16
    public var spikeStart: Float = 0.45
    public var spikeRadius: Float = 0.02
    public var spikeTaper: Float = 0.45
    public init() {}
    public func with(_ edit: (inout Self) -> Void) -> Self { var c = self; edit(&c); return c }
}

enum FlowerKit {
    static func lod(_ id: String, _ plan: FlowerPlan, _ style: FlowerStyle, seed: UInt64) -> LODModel {
        LODModel(levels: [model(id, plan, style, seed: seed, detail: true), model(id, plan, style, seed: seed, detail: false)], switchDistances: [8])
    }

    static func model(_ id: String, _ plan: FlowerPlan, _ style: FlowerStyle, seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: id)
        let stemMat: MaterialKey = "plant.stem:" + plan.stemColor, leafMat: MaterialKey = "leaf.plain:" + plan.leafColor
        let petalMat: MaterialKey = "flower.petal:" + style.color, centerMat: MaterialKey = "plant.stem:" + style.center
        var stems = Surface(material: stemMat), leaves = Surface(material: leafMat)
        var petals = Surface(material: petalMat), centers = Surface(material: centerMat)
        var lr = rng.fork(1)
        for _ in 0..<lr.int(plan.basal) {
            let a = lr.float(0...(2 * .pi)), rr = plan.spread * 0.5 * sqrt(lr.float())
            leaves.append(leaf(V3(cos(a) * rr, 0, sin(a) * rr), yaw: a + lr.float(-0.3...0.3), plan, &lr, detail, scale: 1, lean: lr.float(plan.leafLean), mat: leafMat))
        }
        var sr = rng.fork(2)
        for i in 0..<sr.int(plan.stems) {
            let a = sr.float(0...(2 * .pi)), rr = plan.spread * sqrt(sr.float())
            let base = V3(cos(a) * rr, 0, sin(a) * rr)
            let h = sr.float(plan.height)
            let pts = PlantKit.arc(from: base, height: h, yaw: a, lean: sr.float(plan.lean), bend: sr.float(0...0.15), count: 5)
            stems.append(PlantKit.stem(pts, radius: plan.stemRadius, tipRadius: plan.stemRadius * 0.7, sides: detail ? 5 : 3, weight: V2(0, 0.7),
                                       phase: Float(i) * 0.4, material: stemMat))
            for j in 0..<sr.int(plan.stemLeaves) {
                let t = 0.12 + 0.5 * (Float(j) + sr.float(0...0.8)) / Float(max(1, plan.stemLeaves.upperBound))
                leaves.append(leaf(at(pts, t), yaw: a + Float(j) * 2.4 + sr.float(-0.3...0.3), plan, &sr, detail, scale: 1 - 0.4 * t,
                                   lean: sr.float(plan.leafLean), mat: leafMat))
            }
            let top = pts[pts.count - 1], tan = simd_normalize(top - pts[pts.count - 2])
            let out = V3(cos(a), 0, sin(a))
            switch plan.habit {
            case .clump:
                let n = simd_normalize(simd_mix(tan, out, V3(repeating: plan.facing)))
                head(style, at: top, normal: n, scale: sr.float(0.85...1.1), &sr, detail, &petals, &centers, phase: Float(i) * 0.4)
            case .spike:
                let n = sr.int(plan.florets)
                for k in 0..<n {
                    let f = Float(k) / Float(max(1, n - 1)), t = plan.spikeStart + (1 - plan.spikeStart) * f
                    let fy = Float(k) * 2.4 + sr.float(-0.3...0.3)
                    let o = V3(cos(fy), 0, sin(fy))
                    let c = at(pts, t) + o * plan.spikeRadius * (1 - 0.8 * f)
                    let dir = simd_normalize(simd_mix(tan, o, V3(repeating: max(plan.facing, 0.5))) - V3(0, 0.25 * (1 - f), 0))
                    head(style, at: c, normal: dir, scale: 1 - (1 - plan.spikeTaper) * f, &sr, detail, &petals, &centers, phase: Float(i) * 0.4)
                }
            }
        }
        for s in [stems, leaves, petals, centers] where !s.isEmpty { m.add(s) }
        ShrubKit.finish(&m, height: 0.2, floor: 0.5)
        PlantKit.finish(&m)
        ShrubKit.clampGround(&m)
        return ShrubKit.centered(m)
    }

    /// Point at fraction `t` along a polyline.
    static func at(_ p: [V3], _ t: Float) -> V3 {
        let f = min(max(t, 0), 1) * Float(p.count - 1), i = min(Int(f), p.count - 2)
        return simd_mix(p[i], p[i + 1], V3(repeating: f - Float(i)))
    }

    static func leaf(_ root: V3, yaw: Float, _ plan: FlowerPlan, _ r: inout SeededRNG, _ detail: Bool, scale: Float, lean: Float, mat: MaterialKey) -> Surface {
        var b = PlantKit.Blade()
        b.root = root; b.yaw = yaw
        b.length = r.float(plan.leafLength) * scale; b.width = plan.leafWidth * scale * r.float(0.85...1.15)
        b.lean = lean; b.curl = r.float(0.3...0.9); b.twist = r.float(-0.3...0.3); b.tipWidth = plan.leafTip; b.belly = plan.leafBelly; b.fold = 0.18
        b.segments = detail ? 5 : 3
        b.u = V2(0, b.width); b.v = V2(0, b.length); b.weight = V2(0.1, 0.8); b.ao = V2(0.45, 1)
        return PlantKit.blade(b, material: mat)
    }

    static func head(_ s: FlowerStyle, at c: V3, normal: V3, scale: Float, _ r: inout SeededRNG, _ detail: Bool,
                     _ petals: inout Surface, _ centers: inout Surface, phase: Float) {
        let q = simd_quatf(from: V3(0, 1, 0), to: simd_normalize(normal))
        let spin = r.float(0...(2 * .pi))
        for row in 0..<s.rows {
            let rf = Float(row)
            let k = pow(s.rowShrink, rf)
            for p in 0..<s.petals {
                var b = PlantKit.Blade()
                b.root = V3(0, -0.001 * rf, 0)
                b.yaw = spin + (Float(p) + 0.5 * Float(row % 2)) * 2 * .pi / Float(s.petals) + r.float(-s.jitter...s.jitter)
                b.length = s.length * k * scale * r.float(0.92...1.08)
                b.width = s.width * k * scale
                b.tipWidth = s.tipWidth; b.fold = s.fold; b.belly = s.belly
                b.lean = max(0.05, s.lean - s.rowLift * rf) * r.float(0.9...1.1)
                b.curl = s.curl * r.float(0.8...1.2)
                let tiny = b.length < 0.025
                b.segments = detail ? (tiny ? 2 : 4) : (tiny ? 1 : 2)
                b.u = V2(0, b.width); b.v = V2(0, b.length)
                b.weight = V2(0.8, 0.95); b.phase = phase; b.ao = V2(0.55, 1); b.upNormal = 0.2
                petals.append(PlantKit.blade(b, material: petals.material), Xform(translation: c, rotation: q))
            }
        }
        if s.centerRadius > 0 {
            let R = s.centerRadius * scale
            let d = Prim.superellipsoid(V3(R, R * s.centerDome, R), exponent: 2, subdivisions: detail ? 3 : 1, material: centers.material)
            centers.append(d, Xform(translation: c + q.act(V3(0, 0.002, 0)), rotation: q))
        }
    }

    /// Lathe pot with soil; returns the soil surface height.
    static func pot(_ m: inout Model, top: Float, foot: Float, height H: Float, color: MaterialKey = "ceramic.terracotta", detail: Bool) -> Float {
        let R = top / 2, Rf = foot / 2, rim: Float = 0.04
        let outer: [V2] = [V2(0, 0), V2(Rf - 0.006, 0), V2(Rf, 0.006), V2(R - 0.012, H - rim), V2(R, H - rim + 0.01), V2(R, H - 0.004), V2(R - 0.006, H)]
        m.add(Prim.lathe(Profile.shell(outer, wall: 0.01, floor: 0.02, lipSegments: detail ? 3 : 1), segments: detail ? 36 : 18, seamTile: 0.1, material: color))
        let y = H - 0.035
        m.add(Prim.lathe([V2(0, y - 0.03), V2(R - 0.014, y - 0.03), V2(R - 0.014, y), V2(0, y + 0.006)], segments: detail ? 36 : 18, seamTile: 0.1, material: "soil.potting"))
        return y
    }
}
