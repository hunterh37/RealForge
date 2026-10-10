import simd
import Foundation

/// Wall-mounted flagpole: a cast bracket holding a 1.9 m aluminum pole at 45 degrees, a gilt ball
/// truck, halyard cleat and a rippled striped flag. Wall plane at z = 0, y = 0 at the bracket foot.
public struct WallFlagpole: RealAsset {
    public static let id = "wall-flagpole"
    public static let summary = "Wall flagpole, 1.9 m at 45 degrees: cast bracket, aluminum pole, gilt ball, halyard cleat, rippled striped flag."
    public static let tags = ["prop", "architecture", "facade", "sign", "metal", "fabric"]
    public static let budget = 7500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 40, elevation: 12, distance: 3.2)

    public var poleLength: Float = 1.9
    public var stripeA: MaterialKey = "fabric.nylon:B22234"
    public var stripeB: MaterialKey = "fabric.nylon:F2F0EA"
    public var canton: MaterialKey = "fabric.nylon:3C3B6E"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let P = poleLength, ang: Float = 45, a = ang * .pi / 180
        let dir = V3(0, sin(a), cos(a))
        let base = V3(0, 0.06, 0.12)
        FA.box(&m, V3(0.1, 0.16, 0.012), V3(0, 0.08, 0.006), "metal.cast-iron", r: 0.004)
        m.add(Prim.extrude([V2(0, 0), V2(0.12, 0.06), V2(0.12, 0.1), V2(0, 0.12)], depth: 0.06, bevel: 0.003, bevelSegments: 1, material: "metal.cast-iron"),
              Xform(translation: V3(0, 0, 0), rotation: FA.q(-90, FA.Y)))
        FA.path(&m, [base - dir * 0.0, base + dir * (P * 0.5), base + dir * P], r: 0.014, "metal.aluminum-brushed", sides: 12)
        m.add(Prim.cylinder(radius: 0.022, height: 0.1, bevel: 0.004, segments: 12, bevelSegments: 1, material: "metal.cast-iron"),
              Xform(translation: base - dir * 0.02, rotation: simd_quatf(from: FA.Y, to: dir)))
        FC.bead(&m, r: 0.026, at: base + dir * (P + 0.012), "metal.brass-aged")
        // Halyard cleat.
        FA.box(&m, V3(0.08, 0.016, 0.02), V3(0, 0.14, 0.03), "metal.aluminum-brushed", r: 0.003)
        FA.rod(&m, base + dir * (P * 0.25), V3(0.0, 0.14, 0.04), r: 0.002, "fabric.webbing", sides: 4)
        // Flag: 13 stripes hung from the pole top and rippled along X, canton in the upper left.
        let L: Float = 0.8, Hf: Float = 0.5, h = Hf / 13, seg = 4
        let fp = base + dir * (P - 0.1)
        for i in 0..<13 {
            let y = fp.y - (Float(i) + 0.5) * h
            for k in 0..<seg {
                let t = (Float(k) + 0.5) / Float(seg), w = L / Float(seg)
                let z = fp.z + sin(t * 4 + Float(i) * 0.12 + rng.float(0...0.05)) * 0.035 * t
                let inCanton = i < 7 && t < 0.4
                FA.box(&m, V3(w + 0.002, h * 0.99, 0.003), V3(0.02 + t * L, y, z), inCanton ? canton : (i % 2 == 0 ? stripeA : stripeB), r: 0.0005)
            }
        }
        for s: Float in [0.1, 0.4] { FA.rod(&m, V3(0.0, fp.y - 0.05 - s * 0.5, fp.z), V3(0.03, fp.y - 0.05 - s * 0.5, fp.z), r: 0.003, "fabric.webbing", sides: 4) }
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
