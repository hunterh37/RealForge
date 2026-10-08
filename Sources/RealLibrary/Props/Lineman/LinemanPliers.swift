import simd
import Foundation

/// 9 in high-leverage lineman's side-cutting pliers lying flat (Klein D2000-9NE class, 237 mm): two forged
/// jaw halves split along the centre line with the New England nose and side-cutting knives, a hot-riveted
/// joint set close to the knives, bare steel necks, and handles splaying to 58 mm under thick dipped vinyl
/// with a rolled dip edge and fat end bulbs. The pliers lie on the floor, jaws toward -X.
public struct LinemanPliers: RealAsset, RealHandTool {
    public static let id = "lineman-pliers"
    public static let summary = "9 in high-leverage lineman's side-cutting pliers lying flat, polished forged head and dipped vinyl grips."
    public static let tags = ["prop", "tool", "handheld", "utility", "metal"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 48, distance: 0.9, studio: true)
    /// Palm centre on the closed handles.
    public static let grip = SIMD3<Float>(0.065, 0.0065, 0)
    /// Jaw tip (nose).
    public static let tip = SIMD3<Float>(-0.12, 0.0065, 0)

    /// Overall length (m), nose to handle ends.
    public var length: Float = 0.24
    /// Head (jaw) thickness (m).
    public var headThickness: Float = 0.013
    /// Dipped grip colour (sRGB hex); light blue on the classic model.
    public var gripColor: UInt32 = 0x3C78C8
    /// Forged head material.
    public var head: MaterialKey = "metal.hammer-forged"
    /// Ground and polished faces (knives, rivet).
    public var ground: MaterialKey = "metal.tool-ground"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let grip: MaterialKey = "vinyl.dipped-red:" + String(format: "%06X", gripColor)
        let t = headThickness, yc = t / 2, x0: Float = -length / 2
        let flat = simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))   // outline y -> -z, extrude z -> +y
        // Jaw halves (plan outline, y here becomes -z): nose at x0, rivet boss at x0 + 0.075.
        let half: [V2] = [V2(x0, 0.0003), V2(x0, 0.0062), V2(x0 + 0.004, 0.0078), V2(x0 + 0.026, 0.0098), V2(x0 + 0.034, 0.0102),
                          V2(x0 + 0.040, 0.0135), V2(x0 + 0.058, 0.0158), V2(x0 + 0.072, 0.0168), V2(x0 + 0.084, 0.0166),
                          V2(x0 + 0.094, 0.0140), V2(x0 + 0.1, 0.0098), V2(x0 + 0.104, 0.0070), V2(x0 + 0.104, 0.0003)]
        for s: Float in [1, -1] {
            let o = Shape2D.rounded(half.map { V2($0.x, $0.y * s) }.reversedIf(s < 0), radius: 0.0018)
            m.add(Prim.extrude(o, depth: t, bevel: 0.0014, bevelSegments: 2, material: ground),
                  Xform(translation: V3(0, yc, 0), rotation: flat))
            // Ground knife bevel strip on the top face, just ahead of the rivet.
            let k: [V2] = [V2(x0 + 0.045, 0.0004), V2(x0 + 0.066, 0.0004), V2(x0 + 0.064, 0.0042), V2(x0 + 0.047, 0.0040)]
            m.add(Prim.extrude(k.map { V2($0.x, $0.y * s) }.reversedIf(s < 0), depth: 0.0006, bevel: 0.0002, bevelSegments: 1, material: ground),
                  Xform(translation: V3(0, t + 0.0001, 0), rotation: flat))
        }
        // Joint lap: the upper half's boss crossing over, raised a hair above the jaws.
        let rx = x0 + 0.076
        let lap = Shape2D.rounded([V2(rx - 0.013, -0.0165), V2(rx + 0.006, -0.0165), V2(rx + 0.024, 0.006), V2(rx + 0.024, 0.0125),
                                   V2(rx - 0.004, 0.0158), V2(rx - 0.016, 0.004)], radius: 0.006)
        m.add(Prim.extrude(lap, depth: 0.0016, bevel: 0.0006, bevelSegments: 2, material: head),
              Xform(translation: V3(0, t - 0.0004, 0), rotation: flat))
        m.add(Prim.lathe([V2(0, 0), V2(0.0068, 0), V2(0.0066, 0.0006), V2(0.0052, 0.0012), V2(0.003, 0.0016), V2(0, 0.0017)],
                         segments: 24, seamTile: 0.03, material: ground), Xform(translation: V3(rx, t + 0.0010, 0)))
        // Handles: bare steel neck then dipped vinyl, splaying to the ends with a slight inward hook.
        for s: Float in [1, -1] {
            var path: [V3] = []
            for i in 0...14 {
                let u = Float(i) / 14
                let x = x0 + 0.098 + u * (length - 0.098 - 0.006)
                let spread = 0.006 + 0.022 * pow(u, 0.8) + 0.0035 * sin(u * .pi * 1.6) + 0.004 * pow(max(0, u - 0.86) / 0.14, 2)
                path.append(V3(x, yc - 0.0005, s * spread))
            }
            let neck = Array(path[0...2])
            m.add(Prim.sweep(Shape2D.superellipse(0.0075, 0.0105, exponent: 3, segments: 12), along: catmull(neck, per: 3), up: V3(0, 1, 0), material: head))
            let dip = catmull(Array(path[2...]), per: 3)
            let n = dip.count
            let scales: [Float] = (0..<n).map { i in
                let u = Float(i) / Float(n - 1)
                let lip: Float = u < 0.04 ? 0.82 + 4.5 * u : 1
                let bulb: Float = 1 + 0.16 * pow(max(0, u - 0.78) / 0.22, 1.5)
                return lip * bulb * (u > 0.97 ? 0.82 + 0.18 * cos((u - 0.97) / 0.03 * .pi / 2) : 1)
            }
            m.add(Prim.sweep(Shape2D.superellipse(0.0098, 0.0122, exponent: 2.6, segments: 16), along: dip, up: V3(0, 1, 0),
                             scales: scales, material: grip))
            // Dip end cap: rounded bulb.
            let e = dip[n - 1], d = simd_normalize(dip[n - 1] - dip[n - 2])
            var cap = Prim.superellipsoid(V3(0.0118, 0.0102, 0.0118), exponent: 2.2, subdivisions: 6, material: grip)
            cap.deform { $0 }
            m.add(cap, Xform(translation: e - d * 0.001 + V3(0, 0.0004, 0)))
            // Story detail: the dip worn through on the lower handle's end, bare steel showing.
            if s < 0 {
                m.add(Prim.superellipsoid(V3(0.007, 0.004, 0.0075), exponent: 2.4, subdivisions: 4, material: head),
                      Xform(translation: e + d * 0.0035 + V3(0, 0.0005, rng.float(-0.0005...0.0005))))
            }
        }
        groundAO(&m, height: 0.02)
        return LODModel(m)
    }
}

extension Array {
    func reversedIf(_ c: Bool) -> [Element] { c ? Array(reversed()) : self }
}
