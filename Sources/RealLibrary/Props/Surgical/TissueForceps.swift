import simd
import Foundation

/// Adson tissue forceps, 4.75 in (120 mm), 1x2 teeth: two stainless leaf-spring tines welded into a
/// rounded back block; broad 9.5 mm thumb grips with transverse serrations, an abrupt shoulder into
/// slender 1.4 mm tips bent slightly toward each other, one tooth on the upper tip meshing between two on
/// the lower. Lies on its lower tine. The tines hinge about the front of the weld (Z axis), the lower
/// mimicking the upper at ratio -1, so "pinched" brings the tips together while the grips stay apart.
/// Story detail: green ID tape round the weld block.
public struct TissueForceps: RealArticulated {
    public static let id = "tissue-forceps"
    public static let summary = "Adson tissue forceps, 4.75 in, 1x2 teeth: two spring tines welded at the back, broad serrated grips and fine toothed tips."
    public static let tags = ["prop", "medical", "surgical", "handheld", "tool", "metal", "articulated"]
    public static let budget = 3_700
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 40, distance: 0.24, studio: true)

    public var length: Float = 0.120
    /// Grip width (m).
    public var gripWidth: Float = 0.0095
    /// Tine thickness at the grip (m).
    public var tineThick: Float = 0.0016
    public var body: MaterialKey = "metal.surgical"
    public var tips: MaterialKey = "metal.surgical-mirror"
    /// ID tape color (sRGB hex); 0 removes it.
    public var tape: UInt32 = 0x2E9E4F
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [2.5])
        let half = length / 2, xb = -half, xw = -half + 0.0105, xt = half
        let t0 = tineThick, yc: Float = 0.006
        let xs: Float = 0.012                 // shoulder
        let s1: Float = 0.07, s2: Float = -0.02
        func thick(_ x: Float) -> Float { x < xs - 0.004 ? t0 : t0 - 0.0005 * min(1, (x - xs + 0.004) / (xt - xs)) }
        // Upper tine center line height above the mid plane.
        func rise(_ x: Float) -> Float {
            let d = x - xw
            let k: Float = 0.004                   // shoulder bend blended over 8 mm
            let a = d * s1, b = (xs - xw) * s1 + (x - xs) * s2
            if x < xs - k { return t0 / 2 + a }
            if x > xs + k { return t0 / 2 + b }
            let u = (x - (xs - k)) / (2 * k), w = u * u * (3 - 2 * u)
            return t0 / 2 + a * (1 - w) + b * w
        }
        func width(_ x: Float) -> Float {
            var w: Float
            if x < -0.02 { w = 0.0074 + (gripWidth - 0.0074) * min(1, (x - xw) / (-0.02 - xw)) }
            else if x < xs - 0.004 { w = gripWidth }
            else if x < xs + 0.006 { let u = (x - (xs - 0.004)) / 0.01; w = gripWidth + (0.0032 - gripWidth) * u * u * (3 - 2 * u) }
            else { w = 0.0032 - (0.0032 - 0.0014) * (x - xs - 0.006) / (xt - xs - 0.006) }
            if x > xt - 0.0012 { let u = (x - (xt - 0.0012)) / 0.0012; w *= sqrt(max(0.06, 1 - u * u)) }
            return w
        }
        // Rest opening each tine turns through to bring the tip faces together.
        let tipGap = rise(xt - 0.0005) - thick(xt) / 2
        let alpha = atan(tipGap / (xt - 0.0005 - xw)) * 180 / .pi
        rig.part("upper", pivot: V3(xw, yc, 0), joint: .hinge(axis: V3(0, 0, 1), -alpha...0, duration: 0.3))
        rig.part("lower", pivot: V3(xw, yc, 0), joint: Joint(.revolute, axis: V3(0, 0, 1), range: 0...alpha, duration: 0.3,
                                                             mimic: .init("upper", ratio: -1)))
        for l in 0..<2 {
            let n = l == 0 ? 40 : 22
            let xsamp: [Float] = (0...n).map { k in
                let u = Float(k) / Float(n)
                return xw - 0.0005 + (xt - xw + 0.0005) * (u * 0.8 + 0.2 * (1 - (1 - u) * (1 - u)))
            }
            for side: Float in [1, -1] {
                let path = xsamp.map { V3($0, yc + side * rise($0), 0) }
                let sides = l == 0 ? 12 : 10
                let tine = SurgKit.loft(path, material: body) { _, i in SurgKit.section(width(xsamp[i]), thick(xsamp[i]), n: sides, exponent: 5) }
                rig.add(tine, to: side > 0 ? "upper" : "lower", lods: l...l)
            }
            // Weld block: both tines fused into one rounded end.
            let blockLen = xw - xb + 0.0006
            let outline = Shape2D.roundedRect(blockLen, 0.0074, radius: 0.0036, segments: l == 0 ? 5 : 2).map { V2($0.x + xb + blockLen / 2, $0.y) }
            rig.base[l].add(SurgKit.plate(outline, y0: yc - t0, y1: yc + t0, bevel: 0.0005, segments: l == 0 ? 2 : 1, material: body))
        }
        // Grip serrations: transverse ridges on the outer face of each grip.
        let g0: Float = -0.036, g1: Float = 0.002, pitch: Float = 0.0011
        for side: Float in [1, -1] {
            var prof: [V2] = [V2(g0, -0.0002)]
            var x = g0
            while x < g1 - pitch / 2 { prof.append(V2(x + pitch * 0.5, 0.00028)); prof.append(V2(x + pitch, 0)); x += pitch }
            prof.append(V2(g1, -0.0002))
            var ridges = SurgKit.profile(prof, z0: -0.0036, z1: 0.0036, bevel: 0, material: body)
            // Lay the strip on the grip face: follow the tine slope.
            ridges.deform { p in V3(p.x, yc + side * (rise(p.x) + t0 / 2 - 0.00005 + p.y), p.z) }
            if side < 0 { ridges = ridges.flipped() }
            rig.add(ridges, to: side > 0 ? "upper" : "lower", lods: 0...0)
        }
        // 1x2 teeth: one on the upper tip, two on the lower, meshing across the tip width.
        let xT = xt - 0.0009
        let topFace = yc + rise(xT) - thick(xT) / 2
        let tilt = simd_quatf(angle: atan(s2), axis: V3(0, 0, 1))
        rig.add(Prim.roundedBox(V3(0.0007, 0.0012, 0.0004), radius: 0.00012, bevelSegments: 1, material: tips),
                Xform(translation: V3(xT, topFace - 0.0003, 0), rotation: tilt), to: "upper", lods: 0...0)
        for z: Float in [-0.00046, 0.00046] {
            rig.add(Prim.roundedBox(V3(0.0007, 0.0012, 0.00036), radius: 0.00012, bevelSegments: 1, material: tips),
                    Xform(translation: V3(xT, 2 * yc - topFace + 0.0003, z), rotation: tilt.inverse), to: "lower", lods: 0...0)
        }
        // ID tape round the weld block, seam slightly lifted.
        if tape != 0 {
            let band = SurgKit.plate(Shape2D.roundedRect(0.005, 0.0078, radius: 0.0012, segments: 2).map { V2($0.x + xw - 0.0045, $0.y) },
                                     y0: yc - t0 - 0.00012, y1: yc + t0 + 0.00012, bevel: 0.0004, segments: 1,
                                     material: "plastic.gloss:" + String(format: "%06X", tape))
            rig.base[0].add(band, Xform.identity.jittered(&rng, deg: 0.2, offset: 0.00003))
        }
        rig.states = [RigState("open"), RigState("pinched", ["upper": -alpha])]
        // Rest on the weld block and the lower grip shoulder.
        let back = V2(xb + 0.002, yc - t0), shoulder = V2(xs, yc - rise(xs) - t0 / 2)
        let lean = atan2(back.y - shoulder.y, shoulder.x - back.x)
        SurgKit.settle(&rig, tilt: Xform(rotation: simd_quatf(angle: lean, axis: V3(0, 0, 1))), aoHeight: 0.006)
        return rig
    }
}
