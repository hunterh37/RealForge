import simd
import Foundation

/// 5-gallon practice bucket of baseballs: tapered white HDPE bucket (30 cm across the rim, 37 cm tall)
/// with three reinforcing rim ribs, a rolled lip and a stacking foot; wire bail in moulded ear lugs,
/// dropped to the front, with a black plastic grip. Filled to the rim with baseballs (heaped a little
/// above it), with a few loose balls on the ground beside it. Balls come from `BaseballMesh`.
public struct BallBucket: RealAsset {
    public static let id = "ball-bucket"
    public static let summary = "5-gallon white plastic bucket filled with baseballs: ribbed rim, wire bail handle with a black grip, a few balls on the ground beside it."
    public static let tags = ["prop", "sports", "plastic", "container"]
    public static let budget = 14000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 25, elevation: 30, distance: 1.4, studio: true)

    /// Bucket height (m).
    public var height: Float = 0.37
    /// Outer radius at the rim (m).
    public var rimRadius: Float = 0.15
    /// Outer radius at the base (m).
    public var baseRadius: Float = 0.131
    /// Loose balls on the ground (0-4).
    public var looseBalls: Int = 3
    /// Bucket material key.
    public var plastic: MaterialKey = "plastic.bucket"
    /// Bail wire material key.
    public var wire: MaterialKey = "metal.steel"
    /// Bail grip material key.
    public var grip: MaterialKey = "plastic.black"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, lod: 0), model(seed: seed, lod: 1)], switchDistances: [5])
    }

    func model(seed: UInt64, lod: Int) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let h = height, rt = rimRadius, rb = baseRadius
        let seg = lod == 0 ? 32 : 24
        func radius(_ y: Float) -> Float { rb + (rt - rb) * y / h }
        // Body: stacking foot, tapered wall, flared rim band, rolled lip; 2.2 mm wall, floor 4 mm up.
        let outer: [V2] = [V2(0, 0.004), V2(rb - 0.012, 0.004), V2(rb - 0.006, 0.0), V2(rb - 0.002, 0.003), V2(rb, 0.012),
                           V2(radius(0.03), 0.03), V2(radius(0.3), 0.3), V2(radius(0.31) + 0.003, 0.312),
                           V2(radius(0.36) + 0.004, 0.358), V2(radius(h) + 0.004, h)]
        var body = Prim.lathe(Profile.shell(outer, wall: 0.0022, floor: 0.006), segments: seg, seamTile: 0.35, material: plastic)
        // Infield clay kicked up the outside of the foot (the material's splat layer).
        let cph = rng.float(0...6.28)
        body.paintSplat { p in
            let a = atan2(p.z, p.x), r = simd_length(V2(p.x, p.z))
            guard r > radius(p.y) - 0.001 else { return 0 }
            let line = 0.035 + 0.025 * sin(a * 2 + cph) + 0.012 * sin(a * 5 + cph * 3)
            return smoothstep(line + 0.02, line - 0.015, p.y)
        }
        m.add(body)
        // Reinforcing ribs on the rim band and the rolled lip.
        for y in [Float(0.322), 0.336, 0.35] {
            m.add(Prim.torus(major: radius(y) + 0.0042, minor: 0.0022, segments: seg, sides: 4, material: plastic), Xform(translation: V3(0, y, 0)))
        }
        m.add(Prim.torus(major: rt + 0.004, minor: 0.0035, segments: seg, sides: 6, material: plastic), Xform(translation: V3(0, h - 0.002, 0)))
        // Ear lugs at +-X with the bail pivots.
        let earY: Float = 0.334, earR = radius(earY) + 0.006
        for s: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.014, 0.036, 0.03), radius: 0.004, bevelSegments: 2, material: plastic),
                  Xform(translation: V3(s * (earR + 0.002), earY, 0)))
        }
        // Bail: semicircle over the bucket, dropped to +Z until it rests against the rim band.
        let bailR = earR + 0.012, drop: Float = 84 * .pi / 180
        let bailRot = simd_quatf(angle: drop, axis: V3(1, 0, 0))
        let n = lod == 0 ? 40 : 18
        var bail: [V3] = [V3(-bailR + 0.006, earY, 0)]
        for k in 0...n {
            let t = Float(k) / Float(n) * .pi
            bail.append(bailRot.act(V3(-cos(t) * bailR, sin(t) * bailR, 0)) + V3(0, earY, 0))
        }
        bail.append(V3(bailR - 0.006, earY, 0))
        m.add(Prim.tube(bail, radii: bail.map { _ in 0.0024 }, sides: 5, seamTile: 0.02, material: wire, capEnd: false))
        // Grip: black plastic sleeve on the middle of the bail, ribbed for fingers.
        let gripPath = (0...8).map { k -> V3 in
            let t = Float.pi / 2 + (Float(k) / 8 - 0.5) * 0.7
            return bailRot.act(V3(-cos(t) * bailR, sin(t) * bailR, 0)) + V3(0, earY, 0)
        }
        m.add(Prim.tube(gripPath, radii: gripPath.indices.map { i in i == 0 || i == 8 ? 0.008 : (i % 2 == 0 ? 0.0105 : 0.0095) },
                        sides: lod == 0 ? 12 : 8, seamTile: 0.04, material: grip, capEnd: true))
        // Balls: a hidden-ish filler layer, a full top layer just below the rim, and a small heap.
        let r = BaseballMesh.radius
        let hideKey: MaterialKey = "leather.baseball", dirty: MaterialKey = "leather.baseball-dirty"
        func layer(_ count: Int, _ y: Float, _ inner: Float, _ seed: Int) -> [V3] {
            var lr = rng.fork(seed)
            let maxR = inner - r - 0.002
            var pts = (0..<count).map { i -> V2 in
                let a = Float(i) / Float(count) * 2 * .pi + lr.float(-0.2...0.2)
                return V2(cos(a), sin(a)) * maxR * (i % 3 == 0 ? 0.3 : 0.85)
            }
            for _ in 0..<300 {
                for i in pts.indices { for j in pts.indices where j > i {
                    let d = pts[j] - pts[i], l = simd_length(d)
                    if l < 2 * r + 0.001 && l > 1e-6 { let push = d / l * (2 * r + 0.001 - l) / 2; pts[i] -= push; pts[j] += push }
                }}
                for i in pts.indices where simd_length(pts[i]) > maxR { pts[i] = simd_normalize(pts[i]) * maxR }
            }
            return pts.map { V3($0.x, y + lr.float(-0.004...0.004), $0.y) }
        }
        func ball(_ p: V3, _ d: BaseballMesh.Detail, _ k: Int) {
            let rot = simd_quatf(angle: rng.float(0...(2 * .pi)), axis: rng.unitVector())
            let key = k % 3 == 1 ? dirty : hideKey
            for s in BaseballMesh.ball(d, radius: r, hide: key) { m.add(s, Xform(translation: p, rotation: rot)) }
        }
        let topY = h - r - 0.008
        if lod == 1 { for (i, p) in layer(6, topY - 0.062, radius(topY - 0.062) - 0.0022, 1).enumerated() { ball(p, .filler, i) } }
        for (i, p) in layer(9, topY, radius(topY) - 0.0022, 2).enumerated() { ball(p, lod == 0 ? .lite : .filler, i) }
        for (i, a) in [Float(0.3), 2.4, 4.4].enumerated() {
            let p = V3(cos(a) * 0.045, topY + 0.05, sin(a) * 0.045)
            ball(p, lod == 0 ? .lite : .filler, i + 1)
        }
        // Loose balls beside the bucket on the +Z / +X side.
        let loose: [V2] = [V2(0.21, 0.13), V2(0.27, 0.05), V2(0.12, 0.24), V2(-0.2, 0.2)]
        for i in 0..<min(4, max(0, looseBalls)) {
            let p = loose[i] + V2(rng.float(-0.015...0.015), rng.float(-0.015...0.015))
            ball(V3(p.x, r, p.y), lod == 0 ? .medium : .lite, i)
        }
        let bb = m.bounds
        m = m.transformed(Xform(translation: V3(-(bb.min.x + bb.max.x) / 2, 0, -(bb.min.z + bb.max.z) / 2)))
        groundAO(&m, height: 0.08, floor: 0.5)
        return m
    }
}
