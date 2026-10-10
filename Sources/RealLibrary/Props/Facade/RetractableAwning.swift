import simd
import Foundation

/// Retractable patio awning: a roller cassette on the wall, two folding arms with elbow joints, a front
/// bar with a hanging valance and striped acrylic fabric that slopes down from the cassette.
/// Wall plane at z = 0; y = 0 is the bottom of the valance.
public struct RetractableAwning: RealAsset {
    public static let id = "retractable-awning"
    public static let summary = "Retractable awning, 3 m wide, 2 m projection: roller cassette, folding scissor arms, striped acrylic fabric and valance."
    public static let tags = ["prop", "architecture", "facade", "trim", "fabric", "metal"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 14, distance: 1.9, studio: true)

    public var width: Float = 3.0
    public var projection: Float = 2.0
    /// Height of the cassette axis above the valance hem (m).
    public var mountHeight: Float = 0.92
    public var valance: Float = 0.2
    public var stripeWidth: Float = 0.12
    public var stripeA: MaterialKey = "fabric.canvas:B4372F"
    public var stripeB: MaterialKey = "fabric.canvas:ECE6D6"
    public var frame: MaterialKey = "metal.powder-white"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, P = projection, top = mountHeight
        let rollR: Float = 0.085
        // Cassette and end caps.
        FA.cylX(&m, r: rollR, h: W + 0.04, at: V3(-W / 2 - 0.02, top, rollR + 0.01), frame, bevel: 0.006, segments: 24)
        for e: Float in [-1, 1] {
            FA.box(&m, V3(0.02, 0.2, 0.12), V3(e * (W / 2 - 0.25), top - 0.02, 0.06), frame, r: 0.004)
        }
        // Front bar.
        let fy: Float = valance + 0.03
        FA.cylX(&m, r: 0.026, h: W + 0.04, at: V3(-W / 2 - 0.02, fy, P), frame, bevel: 0.004, segments: 18)
        // Fabric stripes sloping from cassette to front bar.
        let y0: Float = top - rollR + 0.008, z0: Float = 0.11
        let dz = P - z0, dy = fy - y0
        let len = (dz * dz + dy * dy).squareRoot(), ang = atan2(dy, dz) * 180 / .pi
        let n = max(2, Int((W / stripeWidth).rounded())), sw = W / Float(n)
        for i in 0..<n {
            let x = -W / 2 + sw * (Float(i) + 0.5)
            let mat = i % 2 == 0 ? stripeA : stripeB
            FA.box(&m, V3(sw * 0.995, 0.006, len), V3(x, (y0 + fy) / 2 + 0.005, (z0 + P) / 2), mat, r: 0.002, rot: FA.q(-ang, FA.X))
            FA.box(&m, V3(sw * 0.995, valance, 0.005), V3(x, valance / 2, P + 0.012), mat, r: 0.002)
        }
        // Folding arms: shoulder, elbow, wrist.
        for e: Float in [-1, 1] {
            let x = e * (W / 2 - 0.25)
            let sh = V3(x, top - 0.06, 0.12), el = V3(x, top - 0.34 + rng.float(-0.01...0.01), P * 0.52), wr = V3(x, fy - 0.01, P - 0.03)
            FA.rod(&m, sh, el, r: 0.014, frame)
            FA.rod(&m, el, wr, r: 0.014, frame)
            FA.ball(&m, r: 0.022, at: el, frame)
            FA.ball(&m, r: 0.02, at: sh, frame)
        }
        groundAO(&m, height: 0.1, floor: 0.8)
        return LODModel(FA.centerZ(m))
    }
}
