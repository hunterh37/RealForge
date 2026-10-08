import simd
import Foundation

/// Pair of Class 2 natural rubber linemen's gloves (Salisbury/Novax class, 14 in straight cuff, size 10)
/// standing upright on their rolled cuff beads, the way they are set out for an air test: a flared cuff
/// tube narrowing into the flattened palm, four fingers and an angled thumb with thick rounded tips, the
/// two-colour rubber showing black at the rolled bead, and the yellow Class 2 label patch on each cuff.
public struct RubberGloves: RealAsset, RealHandTool {
    public static let id = "rubber-gloves"
    public static let summary = "Pair of Class 2 red rubber insulating gloves standing on their 14 in rolled cuffs."
    public static let tags = ["prop", "tool", "handheld", "utility", "electrical", "ppe", "rubber"]
    public static let budget = 14000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 14, distance: 1.0, studio: true)
    static let gap: Float = 0.075
    /// Cuff of the right glove, where it is pulled on.
    public static let grip = SIMD3<Float>(gap, 0.12, 0)
    /// Middle fingertip of the right glove.
    public static let tip = SIMD3<Float>(gap + 0.006, 0.36, 0)

    /// Outer rubber colour (sRGB hex).
    public var color: UInt32 = 0x8A1C20
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let red: MaterialKey = "rubber.insulating-red:" + String(format: "%06X", color)
        let black: MaterialKey = "rubber.insulating-black"
        var levels: [Model] = []
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let segs = l == 0 ? 28 : 14
            for side: Float in [-1, 1] {
                var r = rng.fork(side > 0 ? 1 : 2)
                let ox = side * Self.gap, lean = r.float(-0.03...0.03)
                // Cuff and palm: lofted sections (width, depth) up the glove.
                let st: [(y: Float, w: Float, d: Float)] = [(0.004, 0.128, 0.078), (0.05, 0.124, 0.074), (0.12, 0.116, 0.066), (0.18, 0.104, 0.054),
                                                            (0.215, 0.096, 0.042), (0.245, 0.098, 0.036), (0.27, 0.1, 0.034), (0.285, 0.094, 0.03)]
                var rings: [[V3]] = []
                for s in st {
                    let c = V3(ox + lean * s.y, s.y, 0)
                    rings.append(Shape2D.superellipse(s.w, s.d, exponent: 2.4, segments: segs).map { c + V3($0.x, 0, $0.y) })
                }
                var body = Prim.loft(rings, capStart: false, capEnd: true, material: red)
                body.computeTangents()
                m.add(body)
                // Rolled bead at the cuff edge.
                m.add(Prim.torus(major: 0.05, minor: 0.0045, segments: segs, sides: 8, material: black),
                      Xform(translation: V3(ox, 0.0045, 0), scale: V3(1.24, 1, 0.74)))
                // Fingers: index to little, slightly spread, thick rubber tips.
                let fl: [Float] = [0.07, 0.078, 0.073, 0.058]
                for f in 0..<4 {
                    let fx = ox + lean * 0.29 + side * (-0.036 + Float(f) * 0.024)
                    let spread = side * (Float(f) - 1.5) * 0.02
                    let base = V3(fx, 0.28, 0)
                    let dir = simd_normalize(V3(spread + r.float(-0.02...0.02), 1, r.float(-0.05...0.05)))
                    let pts = (0...5).map { base + dir * (fl[f] * Float($0) / 5) }
                    let radii: [Float] = (0...5).map { i in 0.0128 - 0.0012 * Float(i) / 5 }
                    m.add(Prim.tube(pts, radii: radii, sides: l == 0 ? 12 : 7, seamTile: 0.04, material: red, capEnd: false))
                    m.add(Prim.superellipsoid(V3(0.0234, 0.022, 0.0234), exponent: 2, subdivisions: l == 0 ? 6 : 3, material: red), Xform(translation: pts[5]))
                }
                // Thumb: from the palm side, angled out and forward.
                let tb = V3(ox + side * 0.04, 0.205, 0.008)
                let td = simd_normalize(V3(side * 0.38, 1, 0.3))
                let tp = (0...5).map { tb + td * (0.075 * Float($0) / 5) }
                m.add(Prim.tube(tp, radii: [0.019, 0.017, 0.0155, 0.0148, 0.0142, 0.014], sides: l == 0 ? 12 : 7, seamTile: 0.04, material: red, capEnd: false))
                m.add(Prim.superellipsoid(V3(0.028, 0.026, 0.028), exponent: 2, subdivisions: l == 0 ? 6 : 3, material: red), Xform(translation: tp[5]))
                // Class 2 label patch on the cuff front.
                if l == 0 {
                    var lab = Prim.roundedBox(V3(0.045, 0.024, 0.001), radius: 0.0004, bevelSegments: 1, material: "plastic.yellow")
                    lab.deform { $0 }
                    m.add(lab, Xform(translation: V3(ox + side * 0.012, 0.045, 0.0382)))
                }
            }
            groundAO(&m, height: 0.1)
            levels.append(m)
        }
        return LODModel(levels: levels, switchDistances: [4])
    }
}
