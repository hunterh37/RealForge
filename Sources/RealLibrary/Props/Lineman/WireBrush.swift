import simd
import Foundation

/// Conductor cleaning flat wire brush (MADI double-flat class) lying on its back: a moulded frame holding a
/// steel bristle block that shows on both faces, a neck into a rubber grip with a coloured end cap, and a
/// split ring in the cap's eye for a lanyard. Bristle tufts are jittered and a few are splayed from use.
/// The brush face is -X, the handle +X.
public struct WireBrush: RealAsset, RealHandTool {
    public static let id = "wire-brush"
    public static let summary = "Conductor cleaning flat wire brush: steel bristle pad in a moulded frame, rubber grip handle and hang ring."
    public static let tags = ["prop", "tool", "handheld", "utility", "plastic", "metal"]
    public static let budget = 13000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 42, distance: 0.85, studio: true)
    static let frameW: Float = 0.135, frameD: Float = 0.058, frameH: Float = 0.02, lift: Float = 0.008
    static let x0: Float = -0.165
    /// Middle of the rubber grip.
    public static let grip = SIMD3<Float>(x0 + frameW + 0.11, lift + frameH / 2, 0)
    /// Centre of the bristle face (upper face as it lies).
    public static let tip = SIMD3<Float>(x0 + frameW / 2, lift + frameH + 0.009, 0)

    /// Frame and end cap colour (sRGB hex).
    public var frameColor: UInt32 = 0x86C232
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let frame: MaterialKey = "plastic.yellow:" + String(format: "%06X", frameColor)
        let grip: MaterialKey = "rubber.cordless-grip", steel: MaterialKey = "metal.stainless"
        let W = Self.frameW, D = Self.frameD, H = Self.frameH, y0 = Self.lift, x0 = Self.x0
        let flat = simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))
        var levels: [Model] = []
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let cx = x0 + W / 2
            // Frame: rounded ring of moulded plastic around the bristle block.
            let outer = Shape2D.roundedRect(W, D, radius: 0.01, segments: 4)
            m.add(Prim.extrude(outer, depth: H, bevel: 0.003, bevelSegments: 2, material: frame), Xform(translation: V3(cx, y0 + H / 2, 0), rotation: flat))
            // Bristle blocks (dense base) on both faces.
            let iw = W - 0.014, id = D - 0.014
            for (yy, s) in [(y0 + H, Float(1)), (y0, Float(-1))] {
                m.add(Prim.roundedBox(V3(iw, 0.004, id), radius: 0.0012, bevelSegments: 1, material: steel), Xform(translation: V3(cx, yy + s * 0.0015, 0)))
            }
            // Bottom bristles: one slab (it rests on them); top: tufts.
            m.add(Prim.roundedBox(V3(iw, y0, id), radius: 0.0015, bevelSegments: 1, material: steel), Xform(translation: V3(cx, y0 / 2, 0)))
            let nx = l == 0 ? 22 : 11, nz = l == 0 ? 9 : 5
            for i in 0..<nx { for k in 0..<nz {
                var r = rng.fork(i * 31 + k)
                let fi: Float = Float(i) / Float(nx - 1), fk: Float = Float(k) / Float(nz - 1)
                let jx: Float = r.float(-0.0006...0.0006), jz: Float = r.float(-0.0006...0.0006)
                let px: Float = cx - iw / 2 + 0.003 + (iw - 0.006) * fi + jx
                let pz: Float = -id / 2 + 0.003 + (id - 0.006) * fk + jz
                let h = r.float(0.0075...0.0095)
                let splay = r.chance(0.08) ? r.float(0.2...0.45) : r.float(0...0.08)
                let rot = simd_quatf(angle: splay, axis: simd_normalize(V3(r.float(-1...1), 0, r.float(-1...1)) + V3(0.001, 0, 0)))
                m.add(Prim.cylinder(radius: l == 0 ? 0.0016 : 0.0022, height: h, bevel: 0.0005, segments: 5, bevelSegments: 1, material: steel),
                      Xform(translation: V3(px, y0 + H + 0.003, pz), rotation: rot))
            } }
            // Neck and handle: section lofted from the frame end, rubber grip, cap with eye.
            let hx0 = x0 + W - 0.004
            var path: [V3] = []
            for i in 0...8 { path.append(V3(hx0 + Float(i) / 8 * 0.05, y0 + H / 2, 0)) }
            let sc: [Float] = (0...8).map { i in 1 - 0.35 * sin(Float(i) / 8 * .pi / 2) }
            m.add(Prim.sweep(Shape2D.superellipse(H, 0.04, exponent: 3, segments: 16), along: path, up: V3(0, 1, 0), scales: sc, material: frame))
            var gp: [V3] = []
            for i in 0...10 { gp.append(V3(hx0 + 0.048 + Float(i) / 10 * 0.13, y0 + H / 2, 0)) }
            let gs: [Float] = (0...10).map { i in let u = Float(i) / 10; return 1 + 0.12 * sin(u * .pi) - 0.05 * sin(u * .pi * 3) }
            m.add(Prim.sweep(Shape2D.superellipse(0.021, 0.026, exponent: 2.6, segments: 18), along: gp, up: V3(0, 1, 0), scales: gs, material: grip))
            // End cap with a lanyard eye.
            let ex = hx0 + 0.178
            m.add(Prim.superellipsoid(V3(0.03, 0.022, 0.028), exponent: 2.6, subdivisions: 6, material: frame), Xform(translation: V3(ex + 0.006, y0 + H / 2, 0)))
            m.add(Prim.torus(major: 0.006, minor: 0.0025, segments: 16, sides: 8, material: frame), Xform(translation: V3(ex + 0.024, y0 + H / 2, 0)))
            // Split ring lying on the floor through the eye.
            m.add(Prim.torus(major: 0.013, minor: 0.0013, segments: 28, sides: 6, material: "metal.chrome"),
                  Xform(translation: V3(ex + 0.036, 0.009, 0), rotation: simd_quatf(angle: -0.55, axis: V3(0, 0, 1))))
            groundAO(&m, height: 0.03)
            levels.append(m)
        }
        return LODModel(levels: levels, switchDistances: [1.5])
    }
}
