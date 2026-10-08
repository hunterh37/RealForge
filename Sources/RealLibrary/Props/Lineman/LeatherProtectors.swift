import simd
import Foundation

/// Pair of 12 in leather glove protectors (Salisbury ILP class) lying flat as they come off the hands:
/// grain cowhide shells with four fingers and a thumb, puffed where the rubber glove filled them, a
/// flared gauntlet cuff faced with orange vinyl, a black webbing cuff strap with its buckle, and work grime. Fingers toward -X.
public struct LeatherProtectors: RealAsset, RealHandTool {
    public static let id = "leather-protectors"
    public static let summary = "Pair of 12 in leather glove protectors lying flat: tan cowhide, gauntlet cuff with orange vinyl and strap."
    public static let tags = ["prop", "tool", "handheld", "utility", "ppe", "leather"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 50, distance: 1.0, studio: true)
    static let x0: Float = -0.15, gap: Float = 0.085
    /// Cuff of the near protector.
    public static let grip = SIMD3<Float>(x0 + 0.24, 0.012, gap)
    /// Middle fingertip of the near protector.
    public static let tip = SIMD3<Float>(x0 + 0.002, 0.01, gap)

    /// Leather colour (sRGB hex).
    public var leatherColor: UInt32 = 0xD6C4A0
    /// Cuff facing colour (sRGB hex).
    public var cuffColor: UInt32 = 0xE8641E
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let leather: MaterialKey = "leather.split-tan:" + String(format: "%06X", leatherColor)
        let vinyl: MaterialKey = "vinyl.dipped-red:" + String(format: "%06X", cuffColor)
        let flat = simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))
        let hand: [V2] = [V2(0.30, -0.07), V2(0.17, -0.052), V2(0.1, -0.048), V2(0.04, -0.046), V2(0.03, -0.04), V2(0.03, -0.03), V2(0.075, -0.025),
                          V2(0.012, -0.022), V2(0.008, -0.012), V2(0.012, -0.003), V2(0.075, -0.001),
                          V2(0.004, 0.001), V2(0.0, 0.011), V2(0.004, 0.021), V2(0.075, 0.023),
                          V2(0.016, 0.025), V2(0.012, 0.034), V2(0.016, 0.043), V2(0.1, 0.046),
                          V2(0.07, 0.064), V2(0.062, 0.074), V2(0.07, 0.082), V2(0.13, 0.066), V2(0.17, 0.054), V2(0.30, 0.072)]
        for (i, s): (Int, Float) in [(0, 1), (1, -1)] {
            var r = rng.fork(i)
            let z0 = s * Self.gap
            let rot = simd_quatf(angle: r.float(-0.06...0.06), axis: V3(0, 1, 0))
            let place = { (p: V3) -> V3 in rot.act(p) + V3(0, 0, z0) }
            // Shell: outline in (x, y) with y -> -z; the second protector is the other hand (mirrored).
            let o = Shape2D.rounded(hand.map { V2(Self.x0 + $0.x, $0.y * s) }.reversedIf(s < 0), radius: 0.005)
            var shell = Prim.extrude(o, depth: 0.018, bevel: 0.0065, bevelSegments: 3, material: leather)
            shell.deform { p in
                // Puff the palm and fingers; flatten the cuff edge.
                let u = (p.x - Self.x0) / 0.3
                let k: Float = u < 0.6 ? 1 : max(0.8, 1 - (u - 0.6) * 0.6)
                return V3(p.x, p.y, p.z * k)
            }
            m.add(shell, Xform(translation: place(V3(0, 0.0095, 0)), rotation: rot * flat))
            // Orange vinyl facing on the gauntlet top.
            let cuff = Shape2D.rounded([V2(0.2, -0.06), V2(0.296, -0.066), V2(0.296, 0.066), V2(0.2, 0.06)].map { V2(Self.x0 + $0.x, $0.y) }, radius: 0.004)
            m.add(Prim.extrude(cuff, depth: 0.0016, bevel: 0.0005, bevelSegments: 1, material: vinyl), Xform(translation: place(V3(0, 0.0182, 0)), rotation: rot * flat))
            // Cuff strap with buckle across the wrist.
            let sx = Self.x0 + 0.185
            m.add(Prim.roundedBox(V3(0.024, 0.002, 0.118), radius: 0.0008, bevelSegments: 1, material: "fabric.webbing"),
                  Xform(translation: place(V3(sx, 0.0192, 0)), rotation: rot))
            let bz = s * 0.03
            m.add(Prim.sweep(Shape2D.roundedRect(0.003, 0.003, radius: 0.0012, segments: 2),
                             along: [V3(-0.014, 0, -0.01), V3(0.014, 0, -0.01), V3(0.014, 0, 0.01), V3(-0.014, 0, 0.01)].map { place(V3(sx, 0.021, bz) + $0) },
                             up: V3(0, 1, 0), closedPath: true, material: "plastic.black"))
        }
        groundAO(&m, height: 0.03)
        return LODModel(m)
    }
}
