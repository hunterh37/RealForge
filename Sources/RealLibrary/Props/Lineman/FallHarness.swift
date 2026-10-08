import simd
import Foundation

/// Full body fall arrest harness (linemen's bucket harness, ANSI Z359 class) displayed in its worn shape
/// as on a stand: grey polyester webbing over the shoulders crossing on the chest, the dorsal D ring
/// between the shoulder blades, chest strap with quick-connect buckle, sub-pelvic strap, black leg loops
/// with buckles, shoulder pads, and a shock-absorbing lanyard from the D ring down to the floor with its
/// snap hook. Front is +Z.
public struct FallHarness: RealAsset, RealHandTool {
    public static let id = "fall-harness"
    public static let summary = "Full body fall arrest harness in worn shape: grey webbing, dorsal D ring, chest and leg buckles, lanyard."
    public static let tags = ["prop", "ppe", "handheld", "utility", "fabric"]
    public static let budget = 14000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 12, distance: 1.0, studio: true)
    /// Back of the shoulder straps, where it is picked up and hung.
    public static let grip = SIMD3<Float>(0, 0.74, -0.06)
    /// Dorsal D ring (fall arrest attachment).
    public static let tip = SIMD3<Float>(0, 0.6, -0.125)

    /// Webbing colour (sRGB hex).
    public var webColor: UInt32 = 0x9EA2A6
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let web: MaterialKey = "fabric.webbing:" + String(format: "%06X", webColor)
        let dark: MaterialKey = "fabric.webbing", steel: MaterialKey = "metal.galvanized", blk: MaterialKey = "plastic.black"
        var levels: [Model] = []
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let per = l == 0 ? 4 : 2
            // Flat strap along a path; the strap face follows the torso normal (away from the body axis).
            func strap(_ pts: [V3], _ mat: MaterialKey, w: Float = 0.045, closed: Bool = false) {
                var p = catmull(closed ? pts + [pts[0]] : pts, per: per)
                if closed { p.removeLast() }
                let n = p.count, t: Float = 0.003
                var srf = Surface(material: mat)
                var u: Float = 0
                let ring = n + (closed ? 1 : 0)
                for j in 0..<ring {
                    let i = j % n
                    let a = p[max(0, i - 1)], b = p[min(n - 1, i + 1)]
                    let d = closed ? simd_normalize(p[(i + 1) % n] - p[(i + n - 1) % n]) : simd_normalize(b - a)
                    var nn = V3(p[i].x, 0, p[i].z); nn = simd_length(nn) < 1e-4 ? V3(0, 0, 1) : simd_normalize(nn)
                    let side = simd_normalize(simd_cross(d, nn)), up = simd_normalize(simd_cross(side, d))
                    if j > 0 { u += simd_length(p[i] - p[(j - 1) % n]) }
                    for (k, c) in [V2(-1, -1), V2(1, -1), V2(1, 1), V2(-1, 1)].enumerated() {
                        srf.add(p[i] + side * (c.x * w / 2) + up * (c.y * t / 2), up * c.y, V2(u, Float(k) * w / 3))
                    }
                }
                for j in 0..<(ring - 1) {
                    let o = UInt32(j * 4), q = UInt32((j + 1) * 4)
                    for k in 0..<4 { let k1 = UInt32((k + 1) % 4); srf.quad(o + UInt32(k), o + k1, q + k1, q + UInt32(k)) }
                }
                srf.recomputeNormals(weldSeams: false)
                srf.computeTangents()
                m.add(srf)
            }
            // Shoulder straps: back D ring over the shoulders, crossing on the chest, down to the leg loops.
            for s: Float in [-1, 1] {
                strap([V3(0, 0.6, -0.125), V3(s * 0.06, 0.68, -0.11), V3(s * 0.1, 0.75, -0.04), V3(s * 0.1, 0.76, 0.03),
                       V3(s * 0.07, 0.62, 0.115), V3(0, 0.48, 0.135), V3(-s * 0.08, 0.34, 0.13), V3(-s * 0.12, 0.2, 0.1)], web)
                // Back straps from the D ring down to the sub-pelvic strap.
                strap([V3(0, 0.6, -0.125), V3(s * 0.06, 0.45, -0.13), V3(s * 0.1, 0.28, -0.11), V3(s * 0.12, 0.2, -0.07)], web)
                // Leg loop around the thigh.
                var loop: [V3] = []
                for k in 0..<10 { let a = Float(k) / 10 * 2 * .pi; loop.append(V3(s * 0.09 + 0.075 * cos(a), 0.13 + 0.02 * sin(a) * s, 0.065 * sin(a) + 0.01)) }
                strap(loop, dark, closed: true)
                m.add(Prim.roundedBox(V3(0.05, 0.03, 0.012), radius: 0.004, bevelSegments: 2, material: blk), Xform(translation: V3(s * 0.11, 0.17, 0.085)))
                // Shoulder pad.
                m.add(Prim.superellipsoid(V3(0.075, 0.016, 0.12), exponent: 3, subdivisions: l == 0 ? 6 : 3, material: dark), Xform(translation: V3(s * 0.1, 0.745, -0.005)))
            }
            // Sub-pelvic strap around the back of the seat.
            strap([V3(-0.12, 0.2, 0.1), V3(-0.15, 0.2, 0.0), V3(-0.12, 0.17, -0.08), V3(0, 0.15, -0.12), V3(0.12, 0.17, -0.08), V3(0.15, 0.2, 0.0), V3(0.12, 0.2, 0.1)], dark)
            // Chest strap with quick-connect buckle.
            strap([V3(-0.11, 0.52, 0.11), V3(0, 0.52, 0.14), V3(0.11, 0.52, 0.11)], web, w: 0.03)
            m.add(Prim.roundedBox(V3(0.05, 0.035, 0.014), radius: 0.004, bevelSegments: 2, material: steel), Xform(translation: V3(0, 0.52, 0.145)))
            // Dorsal D ring.
            m.add(Prim.torus(major: 0.026, minor: 0.0045, segments: 24, sides: 8, arc: 1.2 * .pi, material: steel),
                  Xform(translation: V3(0, 0.6, -0.13), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0)) * simd_quatf(angle: -0.1 * .pi, axis: V3(0, 1, 0))))
            m.add(Prim.tube([V3(-0.024, 0.604, -0.13), V3(0.024, 0.604, -0.13)], radii: [0.0045, 0.0045], sides: 8, seamTile: 0.02, material: steel))
            // Lanyard: shock pack hanging from the D ring, webbing to the floor, snap hook.
            let lan: [V3] = [V3(0, 0.58, -0.135), V3(0, 0.45, -0.16), V3(0.02, 0.2, -0.2), V3(0.05, 0.02, -0.24), V3(0.15, 0.012, -0.3), V3(0.27, 0.012, -0.28)]
            strap(lan, "fabric.webbing:C8B020", w: 0.032)
            m.add(Prim.superellipsoid(V3(0.06, 0.14, 0.04), exponent: 3, subdivisions: l == 0 ? 6 : 3, material: blk), Xform(translation: V3(0.0, 0.45, -0.16)))
            m.add(Prim.torus(major: 0.03, minor: 0.005, segments: 20, sides: 8, arc: 1.7 * .pi, material: steel),
                  Xform(translation: V3(0.3, 0.006, -0.28), rotation: simd_quatf(angle: 0.3, axis: V3(0, 1, 0))))
            _ = rng.float()
            groundAO(&m, height: 0.1)
            levels.append(m)
        }
        return LODModel(levels: levels, switchDistances: [5])
    }
}
