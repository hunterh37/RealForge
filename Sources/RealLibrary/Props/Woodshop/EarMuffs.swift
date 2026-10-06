import simd
import Foundation

/// Passive over-ear hearing protection (NRR 25 dB class), standing on the cup rims with the cushions
/// pressed together by the headband spring: two glossy yellow oval cups (95 x 76 mm, 40 mm deep) with a
/// rim bead and a rating plate, black vinyl foam cushions around a black fabric liner, black yokes on
/// side pivots, sliding height adjusters, two 3.4 mm spring steel headband wires and a stitched vinyl
/// headband pad over the top. Story detail: the pad's vinyl is rubbed lighter where it is carried.
public struct EarMuffs: RealAsset {
    public static let id = "ear-muffs"
    public static let summary = "Over-ear passive hearing protection: yellow oval cups, foam cushions, twin steel headband wires with padded band, sliding height adjusters."
    public static let tags = ["prop", "workshop", "handheld", "plastic", "metal"]
    public static let budget = 9_600
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 38, elevation: 16, distance: 0.62, studio: true)

    /// Cup outline (m): height Y, width Z.
    public var cupSize = V2(0.095, 0.076)
    /// Cup shell depth (m).
    public var cupDepth: Float = 0.040
    /// Cushion thickness (m).
    public var cushion: Float = 0.019
    /// Headband apex height (wire centerline, m).
    public var apex: Float = 0.207
    /// Shell plastic.
    public var shell: MaterialKey = "plastic.helmet:F2B705"
    /// Cushion vinyl.
    public var cushionMaterial: MaterialKey = "leather.black"
    /// Yokes and adjusters.
    public var trim: MaterialKey = "plastic.matte:1D1E20"
    public init() {}

    var yc: Float { cupSize.x / 2 }
    var xCup0: Float { cushion + 0.0012 }

    // MARK: public points

    /// Top of the headband pad (asset space).
    public var headbandTop: V3 { V3(0, apex + 0.0105, 0) }
    /// Hand position on the headband pad.
    public var grip: V3 { V3(0, apex + 0.004, 0) }

    func oval(_ s: Float, _ n: Int) -> [V2] { Shape2D.superellipse(cupSize.x * s, cupSize.y * s, exponent: 2.5, segments: n) }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var levels: [Model] = []
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let n = l == 0 ? 34 : 18
            for side: Float in [1, -1] {
                // Local cup frame: loft along +Y from the cushion face; +Y -> +X (right) or -X (left).
                let q = simd_quatf(angle: -side * .pi / 2, axis: V3(0, 0, 1))
                let X = Xform(translation: V3(side * xCup0, yc, 0), rotation: q)
                // Shell: rim lip, bead, wall, dome.
                let prof: [(Float, Float)] = l == 0
                    ? [(0, 0.97), (0.0015, 1.0), (0.004, 1.025), (0.0075, 0.995), (0.022, 0.965), (0.030, 0.91), (0.035, 0.83), (0.0385, 0.68), (0.040, 0.45)]
                    : [(0, 0.98), (0.004, 1.02), (0.012, 0.99), (0.026, 0.94), (0.035, 0.82), (0.040, 0.45)]
                let rings = prof.map { Prim.ring(oval($0.1, n), y: $0.0 * cupDepth / 0.040) }
                m.add(Prim.loft(rings, capEnd: true, material: shell), X)
                // Molded ring on the dome.
                m.add(Prim.sweep(Shape2D.circle(0.0012, segments: 4), along: oval(0.68, n / 2).map { V3($0.x, 0.0385 * cupDepth / 0.040, -$0.y) }, up: V3(0, 1, 0),
                                 closedPath: true, material: shell), X)
                // Rating plate on the outer face (generic, no text).
                if l == 0 {
                    m.add(Prim.roundedBox(V3(0.024, 0.0008, 0.013), radius: 0.0003, bevelSegments: 1, material: "plastic.matte:24262A"),
                          Xform(translation: V3(0, cupDepth + 0.0002, 0)).then(X))
                    for k in 0..<3 {
                        m.add(Prim.roundedBox(V3(0.0035 - Float(k % 2) * 0.001, 0.0006, 0.009 - Float(k) * 0.002), radius: 0.0002, bevelSegments: 1, material: "plastic.matte:E8E6DF"),
                              Xform(translation: V3(-0.007 + Float(k) * 0.006, cupDepth + 0.0007, 0)).then(X))
                    }
                }
                // Cushion: puffy vinyl ring swept round the rim, fabric liner inside.
                let cpath = oval(0.80, n).map { V3($0.x, -cushion / 2 - 0.0006, -$0.y) }
                let cprof = Shape2D.superellipse(cushion, 0.0175, exponent: 2.6, segments: l == 0 ? 10 : 6)
                m.add(Prim.sweep(cprof, along: cpath, up: V3(0, 1, 0), closedPath: true, material: cushionMaterial), X)
                m.add(Prim.extrude(oval(0.72, n), depth: 0.0012, bevel: 0.0004, bevelSegments: 1, material: "fabric.nylon:1A1A1C"),
                      Xform(translation: V3(0, -0.006, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))).then(X))
                // Cushion seam where the cover meets the backing plate.
                m.add(Prim.extrude(oval(1.0, n), depth: 0.0024, bevel: 0.0006, bevelSegments: 1, material: trim),
                      Xform(translation: V3(0, -0.0006, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))).then(X))

                // Yoke: arch over the cup from the front pivot to the back pivot, plane x = cup middle.
                let xm = side * (xCup0 + cupDepth * 0.5)
                let zy = cupSize.y / 2 + 0.0035, ry = cupSize.x / 2 + 0.0095
                let yokePath = (0...(l == 0 ? 16 : 8)).map { k -> V3 in
                    let a = Float(k) / Float(l == 0 ? 16 : 8) * .pi
                    return V3(xm, yc + sin(a) * ry, cos(a) * zy)
                }
                m.add(Prim.sweep(Shape2D.roundedRect(0.0075, 0.0052, radius: 0.0018, segments: l == 0 ? 2 : 1), along: yokePath, up: V3(1, 0, 0), material: trim))
                for zs: Float in [-1, 1] {
                    m.add(Prim.cylinder(radius: 0.0052, height: 0.007, bevel: 0.0012, segments: 12, bevelSegments: 1, material: trim),
                          Xform(translation: V3(xm, yc, zs * (zy - 0.0035)), rotation: simd_quatf(degrees: zs * 90, axis: V3(1, 0, 0))))
                }
                // Height adjuster block on the yoke top.
                let by = yc + ry + 0.011
                m.add(Prim.roundedBox(V3(0.013, 0.024, 0.030), radius: 0.0035, bevelSegments: l == 0 ? 2 : 1, material: trim), Xform(translation: V3(xm, by, 0)))
                if l == 0 {
                    // Grip grooves on the adjuster faces.
                    for k in 0..<4 {
                        m.add(cuboid(V3(0.0141, 0.0012, 0.022), material: "plastic.matte:2A2B2E"),
                              Xform(translation: V3(xm, by - 0.006 + Float(k) * 0.004, 0)))
                    }
                }
            }

            // Twin spring-steel wires: right adjuster, over the top, left adjuster; tails poke out below.
            let xA = xCup0 + cupDepth * 0.5
            let by0 = yc + cupSize.x / 2 + 0.0095 + 0.011
            let half: [V3] = [V3(xA, by0 - 0.017, 0), V3(xA, by0 + 0.012, 0), V3(xA + 0.010, by0 + 0.032, 0), V3(xA + 0.019, apex - 0.046, 0),
                              V3(xA + 0.012, apex - 0.020, 0), V3(xA * 0.6, apex - 0.004, 0), V3(0, apex, 0)]
            let ctrl = half + half.dropLast().reversed().map { V3(-$0.x, $0.y, 0) }
            let arch = catmull(ctrl, per: l == 0 ? 4 : 2)
            for zs: Float in [-1, 1] {
                let path = arch.map { $0 + V3(0, 0, zs * 0.0092) }
                m.add(Prim.tube(path, radii: path.map { _ in 0.0017 }, sides: l == 0 ? 6 : 4, seamTile: 0.02, material: "metal.chrome", capEnd: false))
            }
            // Wire end caps (plastic) below the adjusters.
            for s: Float in [-1, 1] { for zs: Float in [-1, 1] {
                m.add(Prim.cylinder(radius: 0.0024, height: 0.004, bevel: 0.001, segments: 8, bevelSegments: 1, material: trim),
                      Xform(translation: V3(s * xA, by0 - 0.019, zs * 0.0092)))
            }}
            // Padded headband over the apex, riding on the wires; stitched edges.
            let padPath = arch.filter { abs($0.x) < xA * 0.95 && $0.y > apex - 0.03 }.map { $0 + V3(0, 0.0045, 0) }
            if padPath.count > 2 {
                let padProf = Shape2D.superellipse(0.0105, 0.030, exponent: 3.2, segments: l == 0 ? 12 : 8)
                let sc = padPath.indices.map { i -> Float in let u = Float(i) / Float(padPath.count - 1); return 0.82 + 0.18 * sin(u * .pi) }
                m.add(Prim.sweep(padProf, along: padPath, up: V3(0, 1, 0), scales: sc, material: "leather.black"))
                if l == 0 {
                    // Story detail: carried by the band, the vinyl is rubbed lighter at the top.
                    let worn = padPath.filter { abs($0.x) < 0.016 }.map { $0 + V3(0, 0.0052, 0) }
                    if worn.count > 1 {
                        m.add(Prim.sweep(Shape2D.superellipse(0.0005, 0.014, exponent: 2, segments: 8), along: worn, up: V3(0, 1, 0), scales: worn.indices.map { i in sin((Float(i) + 0.5) / Float(worn.count) * .pi) }, material: "leather.black:34312E"))
                    }
                    for zs: Float in [-1, 1] {
                        let edge = padPath.map { $0 + V3(0, 0.0012, zs * 0.0128) }
                        m.add(stitches(along: edge, normal: { p in simd_normalize(V3(p.x * 0.3, 1, 0)) }, pitch: 0.004, material: "thread.white:6A6A6A"))
                    }
                }
            }
            _ = rng.float(0...1)
            groundAO(&m, height: 0.03, floor: 0.6)
            levels.append(m)
        }
        return LODModel(levels: levels, switchDistances: [1.5])
    }
}
