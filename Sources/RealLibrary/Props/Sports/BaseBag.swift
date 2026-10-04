import simd
import Foundation

/// MLB base bag, 18 in square (2023 size), 4.3 in tall: a pillowed white vinyl-coated canvas cover with
/// a piped top seam, double-stitched along the top edge and down each corner, over a dark rubber bottom
/// pad that shows as a thin band at grade. The lower sides carry infield clay dust from slides.
public struct BaseBag: RealAsset {
    public static let id = "base-bag"
    public static let summary = "MLB 18 in square base: pillowed white vinyl canvas cover with sewn seams over a dark rubber bottom pad, clay dust on the sides."
    public static let tags = ["prop", "sports", "fabric", "rubber"]
    public static let budget = 7000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 28, distance: 1.2, studio: true)

    /// Square side (m), 18 in.
    public var side: Float = 18 * 0.0254
    /// Height at the edge of the cover (m).
    public var height: Float = 0.1
    /// Extra rise of the pillowed top at its centre (m).
    public var crown: Float = 0.012
    /// Cover material key: `fabric.base-dusty` paints clay on the lower sides, `fabric.base` is clean.
    public var cover: MaterialKey = "fabric.base-dusty"
    /// Bottom pad material key.
    public var pad: MaterialKey = "rubber"
    /// Seam thread material key.
    public var thread: MaterialKey = "thread.white"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [6])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let padH: Float = 0.012, a = side / 2, coverH = height - padH + 0.003
        let b = coverH / 2, cy = padH - 0.003 + b, n: Float = 7
        func crownAt(_ x: Float, _ z: Float, _ y: Float) -> Float {
            let fx = 1 - pow(min(1, abs(x) / a), 2.5), fz = 1 - pow(min(1, abs(z) / a), 2.5)
            return crown * fx * fz * smoothstep(0, b, y)
        }
        // Rubber bottom pad, slightly wider than the cover, beveled at grade.
        let padShape = Shape2D.roundedRect(side + 0.008, side + 0.008, radius: 0.03, segments: 4)
        m.add(Prim.extrude(padShape, depth: padH, bevel: 0.004, bevelSegments: 2, material: pad),
              Xform(translation: V3(0, padH / 2, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Cover: pillowed rounded box, flat underneath.
        var shell = Prim.superellipsoid(V3(side, coverH, side), exponent: n, subdivisions: detail ? 16 : 9, material: cover)
        shell.deform { p in
            let y = max(p.y, -b * 0.92)
            return V3(p.x, y + crownAt(p.x, p.z, p.y), p.z)
        }
        // Clay on the lower sides: splat weight under a wavy line (the cover material's clay layer).
        // Plus two cleat scuffs on the top near the edge a runner hits.
        let ph = rng.float(0...6.28), lift = rng.float(0.0...0.25)
        let scuffs = (0..<2).map { _ in V3(rng.float(-a * 0.7...a * 0.7), b, -a * rng.float(0.5...0.8)) }
        shell.paintSplat { p in
            let around = atan2(p.z, p.x)
            let line = -b * lift + b * 0.3 * sin(around * 3 + ph) + b * 0.2 * sin(around * 7 + ph * 2)
            let side = smoothstep(line + b * 0.35, line - b * 0.3, p.y)
            let top = scuffs.reduce(Float(0)) { max($0, exp(-simd_length_squared(V2(p.x - $1.x, (p.z - $1.z) * 0.6)) / (0.045 * 0.045))) }
            return max(side, top * 0.85 * smoothstep(0, b, p.y))
        }
        m.add(shell, Xform(translation: V3(0, cy, 0)))
        // Piped top seam where the top rolls into the sides, with a stitch line just below it.
        let k = pow(Float(0.5), 1 / n)
        let ring = Shape2D.superellipse(side * k, side * k, exponent: n, segments: 120)
        let pipe = ring.map { V3($0.x, cy + b * k + crownAt($0.x, $0.y, b * k) - 0.001, -$0.y) }
        m.add(Prim.sweep(Shape2D.circle(0.0035, segments: 8), along: pipe, up: .up, closedPath: true, material: "fabric.base"))
        let sy: Float = 0.62, sr = pow(1 - pow(sy, n), 1 / n) * 1.004
        let below = Shape2D.superellipse(side * sr, side * sr, exponent: n, segments: 160).map { V3($0.x, cy + b * sy, -$0.y) }
        let out = { (p: V3) -> V3 in simd_normalize(V3(p.x, 0, p.z)) }
        guard detail else { groundAO(&m, height: 0.05, floor: 0.6); return m }
        m.add(stitches(along: below + [below[0]], normal: out, pitch: 0.007, thread: 0.0007, material: thread))
        // Corner seams running down the four vertical corners.
        for (sx, sz) in [(Float(1), Float(1)), (1, -1), (-1, 1), (-1, -1)] {
            let d = simd_normalize(V3(sx, 0, sz))
            let r0: Float = a * pow(Float(2), -1 / n) * Float(2).squareRoot() * 1.004
            let pts = stride(from: Float(0.75), through: -0.8, by: -0.1).map { t -> V3 in
                let r = r0 * pow(1 - pow(abs(t), n), 1 / n)
                return V3(d.x * r, cy + b * t, d.z * r)
            }
            m.add(stitches(along: pts, normal: { _ in d }, pitch: 0.007, thread: 0.0007, material: thread))
        }
        groundAO(&m, height: 0.05, floor: 0.6)
        return m
    }
}
