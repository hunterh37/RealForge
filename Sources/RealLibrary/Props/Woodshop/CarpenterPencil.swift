import simd
import Foundation

/// Flat carpenter pencil lying on its wide face: 170 mm long (sharpened down from 7 in), 12.7 x 6.6 mm
/// rounded-rectangle cedar body in red gloss lacquer, a 4.6 x 1.9 mm rectangular lead. The point is
/// knife-whittled: flat faceted cuts through the paint into the wood, irregular paint edge, the lead
/// shaved to a chisel edge. The square-cut back end shows cedar and lead.
///
/// Tool frame: along +X (point at +X), wide faces up/down (Y), width along Z; `rest` lifts it onto y = 0.
public struct CarpenterPencil: RealAsset {
    public static let id = "carpenter-pencil"
    public static let summary = "Flat carpenter pencil: red-lacquered cedar, knife-sharpened chisel point with exposed rectangular graphite."
    public static let tags = ["prop", "workshop", "tool", "handheld", "wood"]
    public static let budget = 3_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 40, distance: 0.4)

    /// Lacquer material (tint the suffix: red C4241A, yellow E8B416).
    public var lacquer: MaterialKey = "plastic.pencil-lacquer"
    public var wood: MaterialKey = "wood.pencil-cedar"
    public var lead: MaterialKey = "graphite.pencil"
    public init() {}

    static let W: Float = 0.0127, H: Float = 0.0066, back: Float = -0.0835, tipX: Float = 0.0865

    func rest() -> Xform { Xform(translation: V3(-(Self.back + Self.tipX) / 2, Self.H / 2, 0)) }

    /// Chisel tip of the lead (center of the edge), asset space.
    public var tip: V3 { rest().point(V3(Self.tipX, 0, 0)) }
    /// Center of the hand hold, asset space.
    public var grip: V3 { rest().point(V3(0.01, 0, 0)) }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = Self.W, H = Self.H

        // MARK: lacquered body; the paint dips under the wood where the knife cuts start
        let lx: [Float] = [Self.back, Self.back + 0.002, 0.0, 0.040, 0.0575, 0.0605, 0.0622]
        let ls: [(Float, Float)] = [(W, H), (W, H), (W, H), (W, H), (W, H), (W * 0.995, H * 0.86), (W * 0.93, H * 0.66)]
        var body = HTKit.loft(lx.map { V3($0, 0, 0) }, up: V3(0, 1, 0), caps: false, material: lacquer) { i in
            HTKit.section(ls[i].0, ls[i].1, n: 28, exponent: 5)
        }
        body.recomputeNormals(weldSeams: true); body.computeTangents()
        m.add(body)

        // MARK: whittled wood: octagon sections, flat knife facets, slightly irregular per cut
        let wx: [Float] = [0.0560, 0.0598, 0.0640, 0.0680, 0.0720, 0.0760, 0.0792]
        let jit = (0..<8).map { _ in rng.float(-0.00025...0.00025) }
        func wedge(_ x: Float) -> (Float, Float) {
            let hy = x < 0.0595 ? H * 0.985 : H * 0.985 - (H * 0.985 - 0.0026) * min(1, (x - 0.0595) / (0.0792 - 0.0595))
            let wz = x < 0.0655 ? W * 0.985 : W * 0.985 - (W * 0.985 - 0.0058) * min(1, (x - 0.0655) / (0.0792 - 0.0655))
            return (wz, hy)
        }
        let woodS = HTKit.loft(wx.map { V3($0, 0, 0) }, up: V3(0, 1, 0), caps: true, material: wood) { i in
            let (wz, hy) = wedge(wx[i])
            let c = 0.34 + (i > 0 ? jit[i % 8] * 200 : 0) * 0.1
            let pts: [V2] = [V2(wz / 2, -hy * c), V2(wz / 2, hy * c), V2(wz * c, hy / 2), V2(-wz * c, hy / 2),
                             V2(-wz / 2, hy * c), V2(-wz / 2, -hy * c), V2(-wz * c, -hy / 2), V2(wz * c, -hy / 2)]
            return pts.enumerated().map { k, q in q + (i > 1 ? V2(0, jit[k] * (q.y > 0 ? 1 : -1)) : .zero) }
        }
        m.add(HTKit.faceted(woodS))

        // MARK: lead: rectangular core showing at the tip and the back end, chisel point
        let gx: [Float] = [0.0740, 0.0790, 0.0815, 0.0840, Self.tipX]
        let gs: [(Float, Float)] = [(0.0046, 0.0019), (0.0046, 0.0019), (0.0045, 0.0013), (0.0044, 0.0007), (0.0043, 0.00022)]
        let leadS = HTKit.loft(gx.map { V3($0, 0, 0) }, up: V3(0, 1, 0), material: lead) { i in
            HTKit.section(gs[i].0, gs[i].1, n: 12, exponent: 8)
        }
        m.add(HTKit.faceted(leadS))
        // Back end: square-cut cedar face with the lead.
        let face = Prim.extrude(HTKit.section(W - 0.0002, H - 0.0002, n: 28, exponent: 5), depth: 0.0006, bevel: 0.0001, bevelSegments: 1, material: wood)
        m.add(face, Xform(translation: V3(Self.back + 0.0002, 0, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 1, 0))))
        m.add(Prim.roundedBox(V3(0.0007, 0.0019, 0.0046), radius: 0.0002, bevelSegments: 1, material: lead),
              Xform(translation: V3(Self.back - 0.00005, 0, 0)))

        // MARK: printed inch scale along one edge of the top face (1/8 in ticks, numerals), worn at the grip
        let a = W / 2, b = H / 2
        func topY(_ z: Float) -> Float { b * pow(max(0, 1 - pow(min(1, abs(z) / a), 5)), 0.2) + 0.00009 }
        var ink = HTInk(material: "plastic.matte:141414", normal: V3(0, 1, 0)) { q in V3(q.x, topY(q.y), q.y) }
        let x0 = Self.back + 0.006, inch: Float = 0.0254
        for k in 0...40 {
            let x = x0 + Float(k) * inch / 8
            if rng.chance(0.06) { continue }                     // rubbed off
            let len: Float = k % 8 == 0 ? 0.0026 : (k % 4 == 0 ? 0.0019 : 0.0012)
            ink.bar(V2(x, a - 0.0011), V2(x, a - 0.0011 - len), k % 8 == 0 ? 0.00026 : 0.0002)
            if k % 8 == 0 && k > 0 { ink.number(k / 8, center: V2(x + 0.0022, a - 0.0041), u: V2(1, 0), v: V2(0, 1), h: 0.0021, w: 0.00022) }
        }
        ink.bar(V2(x0, a - 0.0011), V2(x0 + 5 * inch, a - 0.0011), 0.00018)
        m.add(ink.finished())
        // Graphite smudges on the lacquer behind the point.
        var smudge = HTInk(material: "plastic.matte:3A3A3D", normal: V3(0, 1, 0)) { q in V3(q.x, topY(q.y) - 0.00002, q.y) }
        for _ in 0..<5 {
            let cx = rng.float(0.035...0.054), cz = rng.float(-0.003...0.002)
            smudge.bar(V2(cx, cz), V2(cx + rng.float(0.002...0.005), cz + rng.float(-0.0008...0.0008)), rng.float(0.0004...0.0009))
        }
        m.add(smudge.finished())

        let x = rest()
        var out = Model(name: Self.id)
        for s in m.surfaces { out.add(s, x) }
        groundAO(&out, height: 0.006, floor: 0.6)
        return LODModel(out)
    }
}
