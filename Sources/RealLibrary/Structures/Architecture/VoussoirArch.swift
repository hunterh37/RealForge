import simd
import Foundation

/// Voussoir arch surround: rusticated jamb blocks in alternating widths, molded imposts at the
/// springing line, a semicircular ring of chamfered wedge voussoirs and a taller projecting keystone.
/// Back on the wall plane; base at y = 0, opening centered on X.
public struct VoussoirArch: RealAsset {
    public static let id = "voussoir-arch"
    public static let summary = "Voussoir arch surround, 1.2 m opening: rusticated jamb blocks, molded imposts, wedge voussoirs and a projecting keystone."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone"]
    public static let budget = 8_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 22, elevation: 6, distance: 1.0)

    /// Clear opening width (m).
    public var openingWidth: Float = 1.2
    /// Springing height (top of the imposts) above the base (m).
    public var springHeight: Float = 1.8
    /// Voussoir length from intrados to extrados (m).
    public var ringDepth: Float = 0.3
    /// Number of voussoirs including the keystone (odd).
    public var voussoirs = 13
    /// Stone projection from the wall (m); the keystone projects `keyProjection` more.
    public var depth: Float = 0.14
    public var keyProjection: Float = 0.03
    /// Jamb course height and the two alternating block widths (m).
    public var courseHeight: Float = 0.3
    public var jambWidths: (Float, Float) = (0.3, 0.42)
    /// Chamfer at the rusticated arrises (m).
    public var chamfer: Float = 0.016
    /// Rain streak and soot strength.
    public var weathering: Float = 0.5
    public var material: MaterialKey = "stone.sandstone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let r = openingWidth / 2, ys = springHeight
        let tints = ["", ":C4A47A", ":BE9C70", ":CCAE86"]
        let impH: Float = 0.12
        // Jambs.
        let jambTop = ys - impH
        let courses = max(1, Int((jambTop / courseHeight).rounded()))
        let ch = jambTop / Float(courses)
        for side in [Float(-1), 1] {
            for c in 0..<courses {
                var rr = rng.fork(c + (side > 0 ? 50 : 0))
                let w = c % 2 == 0 ? jambWidths.0 : jambWidths.1
                let blk = Prim.extrude(Shape2D.rect(w, ch - 0.01), depth: depth, bevel: chamfer, bevelSegments: 1, material: material + rr.pick(tints))
                m.add(blk, Xform(translation: V3(side * (r + w / 2), ch * (Float(c) + 0.5), depth / 2)))
            }
            // Impost: fascia and cyma, projecting past the jamb face, with returns.
            var ip = ArchProfile()
            ip.step(depth + 0.012); ip.fillet(impH * 0.45); ip.cymaRecta(impH * 0.4, 0.022); ip.fillet(impH * 0.15)
            m.add(ArchTrimKit.returnedRun(ip, length: jambWidths.1 + 0.04, material: material, span: 0.1),
                  Xform(translation: V3(side * (r + jambWidths.1 / 2), jambTop, 0)))
        }
        // Voussoirs on the semicircle, wedge joints radiating from the center.
        let n = max(3, voussoirs | 1)
        let gap: Float = 0.006
        for i in 0..<n {
            var rr = rng.fork(200 + i)
            let isKey = i == n / 2
            let a0 = Float.pi * Float(i) / Float(n), a1 = Float.pi * Float(i + 1) / Float(n)
            let ri = r, ro = r + ringDepth + (isKey ? 0.09 : 0)
            let gi = gap / (2 * ri), go = gap / (2 * ro)
            var o: [V2] = []
            let segs = 4
            for k in 0...segs { let a = a0 + gi + (a1 - a0 - 2 * gi) * Float(k) / Float(segs); o.append(V2(ri * cos(a), ri * sin(a))) }
            for k in 0...segs { let a = a1 - go - (a1 - a0 - 2 * go) * Float(k) / Float(segs); o.append(V2(ro * cos(a), ro * sin(a))) }
            let d = depth + (isKey ? keyProjection : 0)
            let v = Prim.extrude(o.reversed(), depth: d, bevel: chamfer, bevelSegments: 1, material: material + (isKey ? ":D2B48C" : rr.pick(tints)))
            m.add(v, Xform(translation: V3(0, ys, d / 2)))
        }
        // Mortar-colored backing behind the joints.
        var back: [V2] = []
        for k in 0...24 { let a = Float.pi * Float(k) / 24; back.append(V2((r + 0.004) * cos(a), (r + 0.004) * sin(a))) }
        for k in 0...24 { let a = Float.pi * (1 - Float(k) / 24); back.append(V2((r + ringDepth - 0.004) * cos(a), (r + ringDepth - 0.004) * sin(a))) }
        m.add(Prim.extrude(back.reversed(), depth: depth * 0.6, bevel: 0.002, bevelSegments: 1, material: "concrete.smooth:9C9284"),
              Xform(translation: V3(0, ys, depth * 0.3)))
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        groundAO(&m, height: 0.3, floor: 0.6)
        return LODModel(ArchTrimKit.ground(m))
    }
}
